package recommendation

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
)

// RecommendationSet holds a scored set of recommendations for a user
type RecommendationSet struct {
	UserID    string              `json:"user_id"`
	City      string              `json:"city"`
	Feeds     []FeedWeight        `json:"feed_weights"`
	Places    []PlaceScore        `json:"places"`
	People    []PersonScore       `json:"people"`
	Creators  []CreatorScore      `json:"creators"`
	UpdatedAt time.Time           `json:"updated_at"`
}

type FeedWeight struct {
	InterestTag string  `json:"interest_tag"`
	Weight      float64 `json:"weight"`
}

type PlaceScore struct {
	BusinessID string  `json:"business_id"`
	Score      float64 `json:"score"`
	Reason     string  `json:"reason"`
}

type PersonScore struct {
	UserID string  `json:"user_id"`
	Score  float64 `json:"score"`
}

type CreatorScore struct {
	CreatorID string  `json:"creator_id"`
	Score     float64 `json:"score"`
}

type Service struct {
	db    *pgxpool.Pool
	cache *redis.Client
}

func NewService(db *pgxpool.Pool, cache *redis.Client) *Service {
	return &Service{db: db, cache: cache}
}

// GetRecommendations returns personalised recommendations for a user
// In production this would call a Python ML service; here we use heuristics
func (s *Service) GetRecommendations(ctx context.Context, userID string) (*RecommendationSet, error) {
	// Check cache (refreshed every 6 hours by the ML pipeline)
	cacheKey := fmt.Sprintf("recs:%s", userID)
	if b, err := s.cache.Get(ctx, cacheKey).Bytes(); err == nil {
		var recs RecommendationSet
		if err := json.Unmarshal(b, &recs); err == nil {
			return &recs, nil
		}
	}

	// Fallback: build simple heuristic recommendations
	recs, err := s.buildHeuristicRecs(ctx, userID)
	if err != nil {
		return nil, err
	}

	// Cache for 6 hours
	if b, err := json.Marshal(recs); err == nil {
		s.cache.Set(ctx, cacheKey, b, 6*time.Hour)
	}

	return recs, nil
}

func (s *Service) buildHeuristicRecs(ctx context.Context, userID string) (*RecommendationSet, error) {
	var city string
	var interestTags []string
	s.db.QueryRow(ctx, `SELECT current_city, interest_tags FROM users WHERE id = $1`, userID).
		Scan(&city, &interestTags)

	// Build feed weights from user's interest tags
	weights := make([]FeedWeight, 0, len(interestTags))
	baseWeight := 1.0 / float64(len(interestTags)+1)
	for _, tag := range interestTags {
		weights = append(weights, FeedWeight{InterestTag: tag, Weight: baseWeight})
	}

	// Get top nearby businesses in user's interest categories
	var places []PlaceScore
	rows, _ := s.db.Query(ctx, `
		SELECT id FROM businesses
		WHERE city = $1 AND is_active = TRUE
		ORDER BY rating_avg DESC
		LIMIT 10
	`, city)
	if rows != nil {
		defer rows.Close()
		for rows.Next() {
			var id string
			if rows.Scan(&id) == nil {
				places = append(places, PlaceScore{BusinessID: id, Score: 0.8, Reason: "highly rated nearby"})
			}
		}
	}

	return &RecommendationSet{
		UserID:    userID,
		City:      city,
		Feeds:     weights,
		Places:    places,
		UpdatedAt: time.Now(),
	}, nil
}

// RecordInteraction records a user-content interaction for the ML pipeline
func (s *Service) RecordInteraction(ctx context.Context, userID, contentID, interactionType string) {
	// Publish to a stream that the Python ML service consumes
	event := map[string]any{
		"user_id":    userID,
		"content_id": contentID,
		"type":       interactionType,
		"ts":         time.Now().Unix(),
	}
	b, _ := json.Marshal(event)
	s.cache.LPush(ctx, "ml:interactions", b)
}
