package business

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"

	"github.com/hapa-world/hapa/internal/search"
	"github.com/hapa-world/hapa/pkg/cache"
)

type Business struct {
	ID            string     `json:"id"`
	OwnerID       string     `json:"owner_id"`
	Name          string     `json:"name"`
	Slug          string     `json:"slug"`
	Category      string     `json:"category"`
	SubCategory   string     `json:"sub_category,omitempty"`
	Description   string     `json:"description,omitempty"`
	Lat           float64    `json:"lat"`
	Lng           float64    `json:"lng"`
	City          string     `json:"city"`
	Neighbourhood string     `json:"neighbourhood,omitempty"`
	Address       string     `json:"address,omitempty"`
	Phone         string     `json:"phone,omitempty"`
	WhatsApp      string     `json:"whatsapp,omitempty"`
	Website       string     `json:"website,omitempty"`
	CoverURL      string     `json:"cover_url,omitempty"`
	GalleryURLs   []string   `json:"gallery_urls,omitempty"`
	OpeningHours  any        `json:"opening_hours,omitempty"`
	Amenities     []string   `json:"amenities,omitempty"`
	PriceRange    int        `json:"price_range"`
	Tier          string     `json:"tier"`
	IsVerified    bool       `json:"is_verified"`
	RatingAvg     float64    `json:"rating_avg"`
	ReviewCount   int        `json:"review_count"`
	BoostActive             bool              `json:"boost_active"`
	SocialLinks             map[string]string `json:"social_links,omitempty"`
	VerificationRequestedAt *time.Time        `json:"verification_requested_at,omitempty"`
	DistanceM               float64           `json:"distance_m,omitempty"`
	CreatedAt               time.Time         `json:"created_at"`
}

type CreateBusinessReq struct {
	Name         string                 `json:"name"`
	Category     string                 `json:"category"`
	SubCategory  string                 `json:"sub_category"`
	Description  string                 `json:"description"`
	City         string                 `json:"city"`
	Neighbourhood string                `json:"neighbourhood"`
	Address      string                 `json:"address"`
	Lat          float64                `json:"lat"`
	Lng          float64                `json:"lng"`
	Phone        string                 `json:"phone"`
	WhatsApp     string                 `json:"whatsapp"`
	Website      string                 `json:"website"`
	CoverURL     string                 `json:"cover_url"`
	PriceRange   int                    `json:"price_range"`
	OpeningHours map[string]interface{} `json:"opening_hours"`
}

type SearchPlacesReq struct {
	Lat      float64 `json:"lat"`
	Lng      float64 `json:"lng"`
	RadiusM  float64 `json:"radius_m"`
	Category string  `json:"category"`
	Query    string  `json:"query"`
	PriceMax int     `json:"price_max"`
	Limit    int     `json:"limit"`
}

type Service struct {
	db     *pgxpool.Pool
	cache  *redis.Client
	search *search.Client
}

func NewService(db *pgxpool.Pool, cache *redis.Client, search *search.Client) *Service {
	return &Service{db: db, cache: cache, search: search}
}

// CreateBusiness registers a new business listing
func (s *Service) CreateBusiness(ctx context.Context, ownerID string, req CreateBusinessReq) (*Business, error) {
	slug := generateSlug(req.Name)

	// Normalise category: accept both frontend-friendly and DB enum values
	category := normaliseCategory(req.Category)

	// Resolve city: prefer explicit city name, fall back to nearest from coords
	city := req.City
	if city == "" && req.Lat != 0 && req.Lng != 0 {
		s.db.QueryRow(ctx, `
			SELECT name FROM cities
			ORDER BY ST_Distance(location, ST_SetSRID(ST_Point($2, $1), 4326)::geography)
			LIMIT 1
		`, req.Lat, req.Lng).Scan(&city)
	}
	if city == "" {
		city = "Kampala" // safe default
	}

	// Encode opening hours to JSON
	var hoursJSON []byte
	if len(req.OpeningHours) > 0 {
		hoursJSON, _ = json.Marshal(req.OpeningHours)
	}

	// Use city centre coords if precise GPS not provided
	lat, lng := req.Lat, req.Lng
	if lat == 0 && lng == 0 {
		s.db.QueryRow(ctx, `
			SELECT ST_Y(location::geometry), ST_X(location::geometry) FROM cities WHERE name = $1
		`, city).Scan(&lat, &lng)
	}

	var biz Business
	err := s.db.QueryRow(ctx, `
		INSERT INTO businesses (
			owner_id, name, slug, category, sub_category, description,
			location, city, neighbourhood, address,
			phone, whatsapp, website, cover_url,
			price_range, opening_hours
		)
		VALUES (
			$1, $2, $3, $4::business_category, $5, $6,
			ST_SetSRID(ST_Point($8, $7), 4326)::geography,
			$9, $10, $11,
			$12, $13, $14, $15,
			NULLIF($16, 0), NULLIF($17::text, '')::jsonb
		)
		RETURNING id, owner_id, name, slug, category::text, COALESCE(description,''),
		          ST_Y(location::geometry), ST_X(location::geometry),
		          city, COALESCE(neighbourhood,''), COALESCE(address,''),
		          COALESCE(phone,''), COALESCE(whatsapp,''), COALESCE(website,''),
		          COALESCE(cover_url,''), tier::text, is_verified, rating_avg, review_count, boost_active, created_at
	`,
		ownerID, req.Name, slug, category, req.SubCategory, req.Description,
		lat, lng,
		city, req.Neighbourhood, req.Address,
		req.Phone, req.WhatsApp, req.Website, req.CoverURL,
		req.PriceRange, string(hoursJSON),
	).Scan(
		&biz.ID, &biz.OwnerID, &biz.Name, &biz.Slug, &biz.Category, &biz.Description,
		&biz.Lat, &biz.Lng,
		&biz.City, &biz.Neighbourhood, &biz.Address,
		&biz.Phone, &biz.WhatsApp, &biz.Website,
		&biz.CoverURL, &biz.Tier, &biz.IsVerified, &biz.RatingAvg, &biz.ReviewCount, &biz.BoostActive,
		&biz.CreatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("create business: %w", err)
	}

	go s.search.IndexBusiness(context.Background(), &biz)

	return &biz, nil
}

// MyBusinesses returns all businesses owned by the given user
func (s *Service) MyBusinesses(ctx context.Context, ownerID string) ([]*Business, error) {
	rows, err := s.db.Query(ctx, `
		SELECT id, owner_id, name, slug, category::text, COALESCE(description,''),
		       ST_Y(location::geometry), ST_X(location::geometry),
		       city, COALESCE(neighbourhood,''), COALESCE(address,''),
		       COALESCE(phone,''), COALESCE(whatsapp,''), COALESCE(website,''),
		       COALESCE(cover_url,''), tier::text, is_verified, rating_avg, review_count, boost_active, created_at
		FROM businesses
		WHERE owner_id = $1 AND is_active = TRUE
		ORDER BY created_at DESC
	`, ownerID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []*Business
	for rows.Next() {
		var b Business
		if err := rows.Scan(
			&b.ID, &b.OwnerID, &b.Name, &b.Slug, &b.Category, &b.Description,
			&b.Lat, &b.Lng,
			&b.City, &b.Neighbourhood, &b.Address,
			&b.Phone, &b.WhatsApp, &b.Website,
			&b.CoverURL, &b.Tier, &b.IsVerified, &b.RatingAvg, &b.ReviewCount, &b.BoostActive,
			&b.CreatedAt,
		); err == nil {
			out = append(out, &b)
		}
	}
	if out == nil {
		out = []*Business{}
	}
	return out, nil
}

// normaliseCategory maps frontend-friendly category names to DB enum values
func normaliseCategory(c string) string {
	m := map[string]string{
		"restaurant": "food_dining", "cafe": "food_dining", "bar": "food_dining",
		"coffee": "food_dining", "food": "food_dining",
		"hotel": "accommodation", "lodge": "accommodation", "hostel": "accommodation",
		"shop": "retail", "retail": "retail", "supermarket": "retail", "market": "agriculture_markets",
		"salon": "beauty_grooming", "spa": "beauty_grooming", "barber": "beauty_grooming",
		"gym": "health_wellness", "clinic": "health_wellness", "pharmacy": "health_wellness",
		"health": "health_wellness",
		"entertainment": "entertainment",
		"education": "education", "school": "education",
		"services": "professional_services", "professional_services": "professional_services",
		"tech": "technology", "technology": "technology",
		"arts": "arts_culture", "culture": "arts_culture", "arts_culture": "arts_culture",
		"events": "events_venues", "venue": "events_venues", "events_venues": "events_venues",
		"faith": "faith_community", "church": "faith_community", "mosque": "faith_community",
		"food_dining": "food_dining", "accommodation": "accommodation",
		"beauty_grooming": "beauty_grooming", "agriculture_markets": "agriculture_markets",
	}
	if v, ok := m[c]; ok {
		return v
	}
	return "other"
}

// SearchPlaces returns businesses near coordinates matching filters
func (s *Service) SearchPlaces(ctx context.Context, req SearchPlacesReq) ([]*Business, error) {
	if req.RadiusM <= 0 {
		req.RadiusM = 2000
	}
	if req.Limit <= 0 || req.Limit > 50 {
		req.Limit = 20
	}

	// Cache key
	cacheKey := fmt.Sprintf("places:%.4f:%.4f:%s:%.0f", req.Lat, req.Lng, req.Category, req.RadiusM)
	var cached []*Business
	if err := cache.GetJSON(ctx, s.cache, cacheKey, &cached); err == nil && req.Query == "" {
		return cached, nil
	}

	query := `
		SELECT
			b.id, b.name, b.category::text, b.sub_category, b.description,
			ST_Y(b.location::geometry) AS lat, ST_X(b.location::geometry) AS lng,
			b.city, b.neighbourhood, b.address, b.phone, b.whatsapp, b.website,
			b.cover_url, b.gallery_urls, b.amenities, COALESCE(b.price_range, 0),
			b.tier::text, b.is_verified, b.rating_avg, b.review_count,
			ST_Distance(b.location, ST_SetSRID(ST_Point($2, $1), 4326)::geography) AS distance_m,
			b.created_at
		FROM businesses b
		WHERE ST_DWithin(b.location, ST_SetSRID(ST_Point($2, $1), 4326)::geography, $3)
		  AND b.is_active = TRUE
	`
	args := []any{req.Lat, req.Lng, req.RadiusM}
	argIdx := 4

	if req.Category != "" {
		query += fmt.Sprintf(" AND b.category = $%d::business_category", argIdx)
		args = append(args, req.Category)
		argIdx++
	}
	if req.PriceMax > 0 {
		query += fmt.Sprintf(" AND b.price_range <= $%d", argIdx)
		args = append(args, req.PriceMax)
		argIdx++
	}

	// Ranking: blend distance (40%) + rating (40%) + tier boost (20%)
	query += fmt.Sprintf(`
		ORDER BY
			(1.0 - LEAST(distance_m / $3, 1.0)) * 0.40 +
			(b.rating_avg / 5.0) * 0.40 +
			CASE b.tier WHEN 'pro' THEN 0.20 WHEN 'growth' THEN 0.10 ELSE 0 END
		DESC
		LIMIT $%d
	`, argIdx)
	args = append(args, req.Limit)

	rows, err := s.db.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("search places: %w", err)
	}
	defer rows.Close()

	var businesses []*Business
	for rows.Next() {
		b := &Business{}
		err := rows.Scan(
			&b.ID, &b.Name, &b.Category, &b.SubCategory, &b.Description,
			&b.Lat, &b.Lng, &b.City, &b.Neighbourhood, &b.Address,
			&b.Phone, &b.WhatsApp, &b.Website, &b.CoverURL, &b.GalleryURLs,
			&b.Amenities, &b.PriceRange, &b.Tier, &b.IsVerified,
			&b.RatingAvg, &b.ReviewCount, &b.DistanceM, &b.CreatedAt,
		)
		if err != nil {
			continue
		}
		businesses = append(businesses, b)
	}

	// Cache for 5 minutes (no query filter only)
	if req.Query == "" {
		cache.SetJSON(ctx, s.cache, cacheKey, businesses, 5*time.Minute)
	}

	return businesses, nil
}

// GetBusiness returns full business details by ID
func (s *Service) GetBusiness(ctx context.Context, id string) (*Business, error) {
	cacheKey := cache.BusinessKey(id)
	var biz Business
	if err := cache.GetJSON(ctx, s.cache, cacheKey, &biz); err == nil {
		return &biz, nil
	}

	err := s.db.QueryRow(ctx, `
		SELECT
			b.id, b.owner_id, b.name, b.slug, b.category::text, b.sub_category, b.description,
			ST_Y(b.location::geometry), ST_X(b.location::geometry),
			b.city, b.neighbourhood, b.address, b.phone, b.whatsapp, b.website,
			b.cover_url, b.gallery_urls, b.opening_hours::text, b.amenities, COALESCE(b.price_range, 0),
			b.tier::text, b.is_verified, b.rating_avg, b.review_count, b.created_at
		FROM businesses b WHERE b.id = $1 AND b.is_active = TRUE
	`, id).Scan(
		&biz.ID, &biz.OwnerID, &biz.Name, &biz.Slug, &biz.Category,
		&biz.SubCategory, &biz.Description, &biz.Lat, &biz.Lng,
		&biz.City, &biz.Neighbourhood, &biz.Address, &biz.Phone,
		&biz.WhatsApp, &biz.Website, &biz.CoverURL, &biz.GalleryURLs,
		&biz.OpeningHours, &biz.Amenities, &biz.PriceRange,
		&biz.Tier, &biz.IsVerified, &biz.RatingAvg, &biz.ReviewCount, &biz.CreatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("business not found")
	}

	cache.SetJSON(ctx, s.cache, cacheKey, &biz, 10*time.Minute)
	return &biz, nil
}

// SendBoost creates a Hapa Boost campaign
func (s *Service) CreateBoost(ctx context.Context, businessID, ownerID string, req BoostReq) error {
	_, err := s.db.Exec(ctx, `
		INSERT INTO boosts (business_id, title, description, offer_text, radius_m, location, starts_at, ends_at, budget_usd)
		SELECT $1, $2, $3, $4, $5,
		       b.location,
		       NOW(), NOW() + ($6::text || ' hours')::interval,
		       $7
		FROM businesses b WHERE b.id = $1 AND b.owner_id = $8
	`, businessID, req.Title, req.Description, req.OfferText, req.RadiusM,
		req.DurationHours, req.BudgetUSD, ownerID,
	)
	return err
}

type BoostReq struct {
	Title         string  `json:"title"`
	Description   string  `json:"description"`
	OfferText     string  `json:"offer_text"`
	RadiusM       int     `json:"radius_m"`
	DurationHours int     `json:"duration_hours"`
	BudgetUSD     float64 `json:"budget_usd"`
}

// ActiveBoostsNear returns active Hapa Boost campaigns near coordinates
func (s *Service) ActiveBoostsNear(ctx context.Context, lat, lng, radiusM float64) ([]map[string]any, error) {
	rows, err := s.db.Query(ctx, `
		SELECT bo.id, bo.title, bo.offer_text, bo.ends_at,
		       b.name AS business_name, b.category::text, b.cover_url,
		       ST_Distance(bo.location, ST_SetSRID(ST_Point($2, $1), 4326)::geography) AS distance_m
		FROM boosts bo
		JOIN businesses b ON b.id = bo.business_id
		WHERE bo.is_active = TRUE
		  AND bo.ends_at > NOW()
		  AND ST_DWithin(bo.location, ST_SetSRID(ST_Point($2, $1), 4326)::geography, $3)
		ORDER BY distance_m ASC
		LIMIT 10
	`, lat, lng, radiusM)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var boosts []map[string]any
	for rows.Next() {
		var id, title, offerText, bizName, category string
		var coverURL *string
		var endsAt time.Time
		var distanceM float64
		if err := rows.Scan(&id, &title, &offerText, &endsAt, &bizName, &category, &coverURL, &distanceM); err != nil {
			continue
		}
		boosts = append(boosts, map[string]any{
			"id": id, "title": title, "offer_text": offerText,
			"ends_at": endsAt, "business_name": bizName,
			"category": category, "cover_url": coverURL, "distance_m": distanceM,
		})
	}
	return boosts, nil
}

// ── New types ──────────────────────────────────────────────────────────────────

type UpdateBusinessReq struct {
	Name          string                 `json:"name"`
	Category      string                 `json:"category"`
	SubCategory   string                 `json:"sub_category"`
	Description   string                 `json:"description"`
	Address       string                 `json:"address"`
	Neighbourhood string                 `json:"neighbourhood"`
	Phone         string                 `json:"phone"`
	WhatsApp      string                 `json:"whatsapp"`
	Website       string                 `json:"website"`
	CoverURL      string                 `json:"cover_url"`
	GalleryURLs   []string               `json:"gallery_urls"`
	PriceRange    int                    `json:"price_range"`
	OpeningHours  map[string]interface{} `json:"opening_hours"`
	Amenities     []string               `json:"amenities"`
	SocialLinks   map[string]string      `json:"social_links"`
}

type MenuItem struct {
	ID          string    `json:"id"`
	BusinessID  string    `json:"business_id"`
	Category    string    `json:"category"`
	Name        string    `json:"name"`
	Description string    `json:"description,omitempty"`
	Price       float64   `json:"price"`
	Currency    string    `json:"currency"`
	IsAvailable bool      `json:"is_available"`
	ImageURL    string    `json:"image_url,omitempty"`
	SortOrder   int       `json:"sort_order"`
	CreatedAt   time.Time `json:"created_at"`
}

type MenuItemReq struct {
	Category    string  `json:"category"`
	Name        string  `json:"name"`
	Description string  `json:"description"`
	Price       float64 `json:"price"`
	Currency    string  `json:"currency"`
	IsAvailable bool    `json:"is_available"`
	ImageURL    string  `json:"image_url"`
	SortOrder   int     `json:"sort_order"`
}

type BusinessReview struct {
	ID            string       `json:"id"`
	UserID        string       `json:"user_id"`
	DisplayName   string       `json:"display_name"`
	AvatarURL     string       `json:"avatar_url,omitempty"`
	Content       string       `json:"content"`
	Rating        int          `json:"rating"`
	LikeCount     int          `json:"like_count"`
	BeenHereCount int          `json:"been_here_count"`
	CreatedAt     time.Time    `json:"created_at"`
	OwnerReply    *ReviewReply `json:"owner_reply,omitempty"`
}

type ReviewReply struct {
	ID        string    `json:"id"`
	Content   string    `json:"content"`
	CreatedAt time.Time `json:"created_at"`
}

type BusinessAnalytics struct {
	TotalReviews          int     `json:"total_reviews"`
	RatingAvg             float64 `json:"rating_avg"`
	TotalMenuItems        int     `json:"total_menu_items"`
	DaysListed            int     `json:"days_listed"`
	IsVerified            bool    `json:"is_verified"`
	VerificationRequested bool    `json:"verification_requested"`
}

// ── New service methods ────────────────────────────────────────────────────────

// GetBusinessForOwner returns full business details for the owner edit page.
func (s *Service) GetBusinessForOwner(ctx context.Context, id, ownerID string) (*Business, error) {
	var biz Business
	var hoursText, socialText string

	err := s.db.QueryRow(ctx, `
		SELECT
			b.id, b.owner_id, b.name, b.slug, b.category::text, COALESCE(b.sub_category,''),
			COALESCE(b.description,''),
			ST_Y(b.location::geometry), ST_X(b.location::geometry),
			b.city, COALESCE(b.neighbourhood,''), COALESCE(b.address,''),
			COALESCE(b.phone,''), COALESCE(b.whatsapp,''), COALESCE(b.website,''),
			COALESCE(b.cover_url,''), COALESCE(b.gallery_urls, ARRAY[]::text[]), COALESCE(b.amenities, ARRAY[]::text[]),
			COALESCE(b.opening_hours::text, ''), COALESCE(b.social_links::text, ''),
			COALESCE(b.price_range, 0), b.tier::text, b.is_verified, b.rating_avg, b.review_count,
			b.boost_active, b.verification_requested_at, b.created_at
		FROM businesses b
		WHERE b.id = $1 AND b.owner_id = $2
	`, id, ownerID).Scan(
		&biz.ID, &biz.OwnerID, &biz.Name, &biz.Slug, &biz.Category, &biz.SubCategory,
		&biz.Description, &biz.Lat, &biz.Lng,
		&biz.City, &biz.Neighbourhood, &biz.Address,
		&biz.Phone, &biz.WhatsApp, &biz.Website,
		&biz.CoverURL, &biz.GalleryURLs, &biz.Amenities,
		&hoursText, &socialText,
		&biz.PriceRange, &biz.Tier, &biz.IsVerified, &biz.RatingAvg, &biz.ReviewCount,
		&biz.BoostActive, &biz.VerificationRequestedAt, &biz.CreatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("get business for owner: %w", err)
	}

	if hoursText != "" && hoursText != "{}" {
		var hours map[string]interface{}
		if err := json.Unmarshal([]byte(hoursText), &hours); err == nil {
			biz.OpeningHours = hours
		}
	}
	if socialText != "" && socialText != "{}" {
		var links map[string]string
		if err := json.Unmarshal([]byte(socialText), &links); err == nil {
			biz.SocialLinks = links
		}
	}

	return &biz, nil
}

// UpdateBusiness updates all editable fields for a business owned by ownerID.
func (s *Service) UpdateBusiness(ctx context.Context, id, ownerID string, req UpdateBusinessReq) (*Business, error) {
	var hoursJSON, socialJSON []byte
	if len(req.OpeningHours) > 0 {
		hoursJSON, _ = json.Marshal(req.OpeningHours)
	}
	if len(req.SocialLinks) > 0 {
		socialJSON, _ = json.Marshal(req.SocialLinks)
	}

	amenities := req.Amenities
	if amenities == nil {
		amenities = []string{}
	}
	gallery := req.GalleryURLs
	if gallery == nil {
		gallery = []string{}
	}

	category := normaliseCategory(req.Category)

	var biz Business
	err := s.db.QueryRow(ctx, `
		UPDATE businesses SET
			name = $3,
			category = $4::business_category,
			sub_category = $5,
			description = $6,
			address = $7,
			neighbourhood = $8,
			phone = $9,
			whatsapp = $10,
			website = $11,
			cover_url = $12,
			gallery_urls = $13,
			price_range = NULLIF($14, 0),
			opening_hours = NULLIF($15::text, '')::jsonb,
			amenities = $16,
			social_links = NULLIF($17::text, '')::jsonb,
			updated_at = NOW()
		WHERE id = $1 AND owner_id = $2
		RETURNING id, owner_id, name, slug, category::text, COALESCE(sub_category,''),
		          COALESCE(description,''),
		          ST_Y(location::geometry), ST_X(location::geometry),
		          city, COALESCE(neighbourhood,''), COALESCE(address,''),
		          COALESCE(phone,''), COALESCE(whatsapp,''), COALESCE(website,''),
		          COALESCE(cover_url,''), tier::text, is_verified, rating_avg, review_count, boost_active, created_at
	`,
		id, ownerID,
		req.Name, category, req.SubCategory, req.Description,
		req.Address, req.Neighbourhood, req.Phone, req.WhatsApp, req.Website,
		req.CoverURL, gallery, req.PriceRange,
		string(hoursJSON), amenities, string(socialJSON),
	).Scan(
		&biz.ID, &biz.OwnerID, &biz.Name, &biz.Slug, &biz.Category, &biz.SubCategory,
		&biz.Description, &biz.Lat, &biz.Lng,
		&biz.City, &biz.Neighbourhood, &biz.Address,
		&biz.Phone, &biz.WhatsApp, &biz.Website,
		&biz.CoverURL, &biz.Tier, &biz.IsVerified, &biz.RatingAvg, &biz.ReviewCount,
		&biz.BoostActive, &biz.CreatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("update business: %w", err)
	}

	// Invalidate cache
	s.cache.Del(ctx, cache.BusinessKey(id))

	return &biz, nil
}

// GetBusinessAnalytics returns analytics data for a business.
func (s *Service) GetBusinessAnalytics(ctx context.Context, id string) (*BusinessAnalytics, error) {
	var a BusinessAnalytics
	var createdAt time.Time
	var verReqAt *time.Time

	err := s.db.QueryRow(ctx, `
		SELECT
			b.review_count,
			b.rating_avg,
			b.is_verified,
			b.verification_requested_at,
			b.created_at,
			(SELECT COUNT(*) FROM business_menu_items WHERE business_id = b.id) AS menu_count
		FROM businesses b
		WHERE b.id = $1
	`, id).Scan(
		&a.TotalReviews, &a.RatingAvg, &a.IsVerified,
		&verReqAt, &createdAt, &a.TotalMenuItems,
	)
	if err != nil {
		return nil, fmt.Errorf("analytics not found")
	}

	a.VerificationRequested = verReqAt != nil
	a.DaysListed = int(time.Since(createdAt).Hours() / 24)
	return &a, nil
}

// GetBusinessReviews returns paginated reviews for a business.
func (s *Service) GetBusinessReviews(ctx context.Context, businessID string, page int) ([]*BusinessReview, error) {
	if page < 1 {
		page = 1
	}
	offset := (page - 1) * 20

	rows, err := s.db.Query(ctx, `
		SELECT
			p.id, p.user_id,
			COALESCE(u.display_name, 'Anonymous') AS display_name,
			COALESCE(u.avatar_url, '') AS avatar_url,
			COALESCE(p.content, '') AS content,
			COALESCE(p.rating, 0) AS rating,
			COALESCE(p.like_count, 0) AS like_count,
			COALESCE(p.been_here_count, 0) AS been_here_count,
			p.created_at,
			brr.id, brr.content, brr.created_at
		FROM posts p
		JOIN users u ON u.id = p.user_id
		LEFT JOIN business_review_replies brr ON brr.post_id = p.id
		WHERE p.business_id = $1
		  AND p.post_type = 'review'
		  AND p.moderation_status = 'approved'
		ORDER BY p.created_at DESC
		LIMIT 20 OFFSET $2
	`, businessID, offset)
	if err != nil {
		return nil, fmt.Errorf("get reviews: %w", err)
	}
	defer rows.Close()

	var reviews []*BusinessReview
	for rows.Next() {
		r := &BusinessReview{}
		var replyID, replyContent *string
		var replyCreatedAt *time.Time
		if err := rows.Scan(
			&r.ID, &r.UserID, &r.DisplayName, &r.AvatarURL,
			&r.Content, &r.Rating, &r.LikeCount, &r.BeenHereCount, &r.CreatedAt,
			&replyID, &replyContent, &replyCreatedAt,
		); err != nil {
			continue
		}
		if replyID != nil {
			r.OwnerReply = &ReviewReply{
				ID:        *replyID,
				Content:   *replyContent,
				CreatedAt: *replyCreatedAt,
			}
		}
		reviews = append(reviews, r)
	}
	if reviews == nil {
		reviews = []*BusinessReview{}
	}
	return reviews, nil
}

// ReplyToReview upserts an owner reply on a review post.
func (s *Service) ReplyToReview(ctx context.Context, businessID, postID, content string) error {
	// Verify the post belongs to this business
	var count int
	err := s.db.QueryRow(ctx, `
		SELECT COUNT(*) FROM posts WHERE id = $1 AND business_id = $2 AND post_type = 'review'
	`, postID, businessID).Scan(&count)
	if err != nil || count == 0 {
		return fmt.Errorf("review not found or does not belong to this business")
	}

	_, err = s.db.Exec(ctx, `
		INSERT INTO business_review_replies (post_id, business_id, content)
		VALUES ($1, $2, $3)
		ON CONFLICT (post_id) DO UPDATE SET content = EXCLUDED.content
	`, postID, businessID, content)
	return err
}

// GetMenuItems returns all menu items for a business.
func (s *Service) GetMenuItems(ctx context.Context, businessID string) ([]*MenuItem, error) {
	rows, err := s.db.Query(ctx, `
		SELECT id, business_id, category, name, COALESCE(description,''),
		       price, currency, is_available, COALESCE(image_url,''), sort_order, created_at
		FROM business_menu_items
		WHERE business_id = $1
		ORDER BY sort_order, created_at
	`, businessID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []*MenuItem
	for rows.Next() {
		m := &MenuItem{}
		if err := rows.Scan(
			&m.ID, &m.BusinessID, &m.Category, &m.Name, &m.Description,
			&m.Price, &m.Currency, &m.IsAvailable, &m.ImageURL, &m.SortOrder, &m.CreatedAt,
		); err == nil {
			items = append(items, m)
		}
	}
	if items == nil {
		items = []*MenuItem{}
	}
	return items, nil
}

// CreateMenuItem inserts a new menu item.
func (s *Service) CreateMenuItem(ctx context.Context, businessID string, req MenuItemReq) (*MenuItem, error) {
	currency := req.Currency
	if currency == "" {
		currency = "UGX"
	}
	var m MenuItem
	err := s.db.QueryRow(ctx, `
		INSERT INTO business_menu_items (business_id, category, name, description, price, currency, is_available, image_url, sort_order)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		RETURNING id, business_id, category, name, COALESCE(description,''),
		          price, currency, is_available, COALESCE(image_url,''), sort_order, created_at
	`, businessID, req.Category, req.Name, req.Description, req.Price,
		currency, req.IsAvailable, req.ImageURL, req.SortOrder,
	).Scan(
		&m.ID, &m.BusinessID, &m.Category, &m.Name, &m.Description,
		&m.Price, &m.Currency, &m.IsAvailable, &m.ImageURL, &m.SortOrder, &m.CreatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("create menu item: %w", err)
	}
	return &m, nil
}

// UpdateMenuItem updates an existing menu item.
func (s *Service) UpdateMenuItem(ctx context.Context, businessID, itemID string, req MenuItemReq) (*MenuItem, error) {
	var m MenuItem
	err := s.db.QueryRow(ctx, `
		UPDATE business_menu_items
		SET category = $3, name = $4, description = $5, price = $6,
		    currency = $7, is_available = $8, image_url = $9, sort_order = $10
		WHERE id = $1 AND business_id = $2
		RETURNING id, business_id, category, name, COALESCE(description,''),
		          price, currency, is_available, COALESCE(image_url,''), sort_order, created_at
	`, itemID, businessID,
		req.Category, req.Name, req.Description, req.Price,
		req.Currency, req.IsAvailable, req.ImageURL, req.SortOrder,
	).Scan(
		&m.ID, &m.BusinessID, &m.Category, &m.Name, &m.Description,
		&m.Price, &m.Currency, &m.IsAvailable, &m.ImageURL, &m.SortOrder, &m.CreatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("update menu item: %w", err)
	}
	return &m, nil
}

// DeleteMenuItem removes a menu item.
func (s *Service) DeleteMenuItem(ctx context.Context, businessID, itemID string) error {
	result, err := s.db.Exec(ctx, `
		DELETE FROM business_menu_items WHERE id = $1 AND business_id = $2
	`, itemID, businessID)
	if err != nil {
		return err
	}
	if result.RowsAffected() == 0 {
		return fmt.Errorf("menu item not found")
	}
	return nil
}

// RequestVerification sets the verification_requested_at timestamp if not already set.
func (s *Service) RequestVerification(ctx context.Context, businessID, ownerID string) error {
	result, err := s.db.Exec(ctx, `
		UPDATE businesses
		SET verification_requested_at = NOW()
		WHERE id = $1 AND owner_id = $2 AND verification_requested_at IS NULL
	`, businessID, ownerID)
	if err != nil {
		return err
	}
	if result.RowsAffected() == 0 {
		return fmt.Errorf("verification already requested or business not found")
	}
	return nil
}

func generateSlug(name string) string {
	// Simple slug: lowercase, replace spaces with hyphens, limit length
	slug := ""
	for _, c := range name {
		if c >= 'a' && c <= 'z' {
			slug += string(c)
		} else if c >= 'A' && c <= 'Z' {
			slug += string(c + 32)
		} else if c == ' ' || c == '-' {
			slug += "-"
		}
	}
	if len(slug) > 60 {
		slug = slug[:60]
	}
	return slug + "-" + fmt.Sprintf("%d", time.Now().Unix()%100000)
}
