package location

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"

	"github.com/hapa-world/hapa/pkg/cache"
)

const (
	cityConfirmPings    = 3      // consecutive pings required to confirm city switch
	pingIntervalSecs    = 90     // max ping interval while app is open
	bgPingIntervalMins  = 15     // background ping interval
	locationPurgeDays   = 90     // purge location history after N days
)

type LocationUpdate struct {
	UserID       string  `json:"user_id"`
	Lat          float64 `json:"lat"`
	Lng          float64 `json:"lng"`
	AccuracyM    float64 `json:"accuracy_m"`
	IsBackground bool    `json:"is_background"`
}

type CityInfo struct {
	Name         string   `json:"name"`
	Country      string   `json:"country"`
	CountryCode  string   `json:"country_code"`
	Timezone     string   `json:"timezone"`
	Languages    []string `json:"languages"`
	Currency     string   `json:"currency"`
	IsLaunched   bool     `json:"is_launched"`
	Lat          float64  `json:"lat"`
	Lng          float64  `json:"lng"`
}

type Service struct {
	db    *pgxpool.Pool
	cache *redis.Client
}

func NewService(db *pgxpool.Pool, cache *redis.Client) *Service {
	return &Service{db: db, cache: cache}
}

// UpdateLocation records a location ping and checks for city switch
func (s *Service) UpdateLocation(ctx context.Context, update LocationUpdate) (*CitySwitch, error) {
	// Skip noisy pings (accuracy worse than 500m)
	if update.AccuracyM > 500 {
		return nil, nil
	}

	// Store location record
	_, err := s.db.Exec(ctx, `
		INSERT INTO user_locations (user_id, location, accuracy_m)
		VALUES ($1, ST_SetSRID(ST_Point($3, $2), 4326)::geography, $4)
	`, update.UserID, update.Lat, update.Lng, update.AccuracyM)
	if err != nil {
		return nil, fmt.Errorf("store location: %w", err)
	}

	// Check for city switch
	return s.checkCitySwitch(ctx, update)
}

type CitySwitch struct {
	PreviousCity string   `json:"previous_city"`
	NewCity      string   `json:"new_city"`
	CityInfo     CityInfo `json:"city_info"`
}

func (s *Service) checkCitySwitch(ctx context.Context, update LocationUpdate) (*CitySwitch, error) {
	// Detect current city from coordinates
	var detectedCity string
	err := s.db.QueryRow(ctx, `
		SELECT name FROM cities
		ORDER BY ST_Distance(location, ST_SetSRID(ST_Point($2, $1), 4326)::geography)
		LIMIT 1
	`, update.Lat, update.Lng).Scan(&detectedCity)
	if err != nil {
		return nil, nil // no nearby city found
	}

	// Get user's stored city
	currentCity, _ := s.cache.Get(ctx, cache.UserCityKey(update.UserID)).Result()

	if detectedCity == currentCity {
		// Same city — reset ping counter
		s.cache.Del(ctx, cache.CitySwitchPingKey(update.UserID, detectedCity))
		return nil, nil
	}

	// Different city — increment ping counter
	pingKey := cache.CitySwitchPingKey(update.UserID, detectedCity)
	count, _ := s.cache.Incr(ctx, pingKey).Result()
	s.cache.Expire(ctx, pingKey, 2*time.Hour)

	// Require 3 consecutive pings to confirm city switch (avoids false triggers in transit)
	if count < cityConfirmPings {
		return nil, nil
	}

	// Confirmed city switch
	if err := s.confirmCitySwitch(ctx, update.UserID, detectedCity); err != nil {
		return nil, err
	}

	cityInfo, _ := s.GetCityInfo(ctx, detectedCity)

	slog.Info("city switch confirmed",
		"user_id", update.UserID,
		"from", currentCity,
		"to", detectedCity,
	)

	return &CitySwitch{
		PreviousCity: currentCity,
		NewCity:      detectedCity,
		CityInfo:     cityInfo,
	}, nil
}

func (s *Service) confirmCitySwitch(ctx context.Context, userID, newCity string) error {
	_, err := s.db.Exec(ctx, `
		UPDATE users SET current_city = $2 WHERE id = $1
	`, userID, newCity)
	if err != nil {
		return err
	}

	s.cache.Set(ctx, cache.UserCityKey(userID), newCity, 0)
	return nil
}

// GetCityInfo returns metadata for a city
func (s *Service) GetCityInfo(ctx context.Context, city string) (CityInfo, error) {
	var info CityInfo
	err := s.db.QueryRow(ctx, `
		SELECT name, country, country_code, timezone, languages, currency, is_launched,
		       ST_Y(location::geometry), ST_X(location::geometry)
		FROM cities WHERE name = $1
	`, city).Scan(
		&info.Name, &info.Country, &info.CountryCode,
		&info.Timezone, &info.Languages, &info.Currency, &info.IsLaunched,
		&info.Lat, &info.Lng,
	)
	return info, err
}

// NearestCity returns the closest city to coordinates
func (s *Service) NearestCity(ctx context.Context, lat, lng float64) (CityInfo, error) {
	var info CityInfo
	err := s.db.QueryRow(ctx, `
		SELECT name, country, country_code, timezone, languages, currency, is_launched,
		       ST_Y(location::geometry), ST_X(location::geometry),
		       ST_Distance(location, ST_SetSRID(ST_Point($2, $1), 4326)::geography) AS dist
		FROM cities
		ORDER BY dist
		LIMIT 1
	`, lat, lng).Scan(
		&info.Name, &info.Country, &info.CountryCode,
		&info.Timezone, &info.Languages, &info.Currency, &info.IsLaunched,
		&info.Lat, &info.Lng, nil,
	)
	return info, err
}

// SearchCities returns cities matching the query prefix
func (s *Service) SearchCities(ctx context.Context, q string, limit int) ([]CityInfo, error) {
	rows, err := s.db.Query(ctx, `
		SELECT name, country, country_code, timezone, languages, currency, is_launched,
		       ST_Y(location::geometry), ST_X(location::geometry)
		FROM cities
		WHERE name ILIKE $1 || '%'
		ORDER BY is_launched DESC, name
		LIMIT $2
	`, q, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var cities []CityInfo
	for rows.Next() {
		var c CityInfo
		if err := rows.Scan(&c.Name, &c.Country, &c.CountryCode,
			&c.Timezone, &c.Languages, &c.Currency, &c.IsLaunched,
			&c.Lat, &c.Lng); err == nil {
			cities = append(cities, c)
		}
	}
	return cities, nil
}

// PurgOldLocations removes location history older than 90 days
func (s *Service) PurgeOldLocations(ctx context.Context) error {
	result, err := s.db.Exec(ctx, `
		DELETE FROM user_locations WHERE recorded_at < NOW() - INTERVAL '90 days'
	`)
	if err != nil {
		return err
	}
	slog.Info("purged old location records", "deleted", result.RowsAffected())
	return nil
}
