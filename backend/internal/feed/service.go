package feed

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"

	"github.com/hapa-world/hapa/pkg/cache"
	"github.com/hapa-world/hapa/pkg/geo"
)

const (
	DefaultRadius    = 5000   // 5km default feed radius
	MaxRadius        = 25000  // 25km maximum
	FeedPageSize     = 20
	FeedCacheTTL     = 5 * time.Minute
	FlashFeedTTL     = 60 * time.Second
)

type FeedItem struct {
	ID               string    `json:"id"`
	UserID           string    `json:"user_id"`
	PostType         string    `json:"post_type"`
	Content          string    `json:"content"`
	MediaURLs        []string  `json:"media_urls"`
	Lat              float64   `json:"lat"`
	Lng              float64   `json:"lng"`
	City             string    `json:"city"`
	Neighbourhood    string    `json:"neighbourhood"`
	BusinessID       *string   `json:"business_id,omitempty"`
	InterestTags     []string  `json:"interest_tags"`
	DistanceM        float64   `json:"distance_m"`
	BeenHereCount    int       `json:"been_here_count"`
	LikeCount        int       `json:"like_count"`
	CommentCount     int       `json:"comment_count"`
	ExpiresAt        *time.Time `json:"expires_at,omitempty"`
	Author           *Author   `json:"author"`
	BusinessSummary  *BusinessSummary `json:"business,omitempty"`
	CreatedAt        time.Time `json:"created_at"`
}

type Author struct {
	ID          string  `json:"id"`
	DisplayName string  `json:"display_name"`
	AvatarURL   *string `json:"avatar_url,omitempty"`
	IsVerified  bool    `json:"is_verified"`
	TrustScore  int     `json:"trust_score"`
}

type BusinessSummary struct {
	ID        string  `json:"id"`
	Name      string  `json:"name"`
	Category  string  `json:"category"`
	CoverURL  *string `json:"cover_url,omitempty"`
	RatingAvg float64 `json:"rating_avg"`
}

type FeedRequest struct {
	Lat        float64  `json:"lat"`
	Lng        float64  `json:"lng"`
	RadiusM    float64  `json:"radius_m"`
	UserID     string   `json:"user_id"`
	PostTypes  []string `json:"post_types"`
	Page       int      `json:"page"`
}

type Service struct {
	db    *pgxpool.Pool
	cache *redis.Client
}

func NewService(db *pgxpool.Pool, cache *redis.Client) *Service {
	return &Service{db: db, cache: cache}
}

// GetFeed returns location-ranked feed items for a user
func (s *Service) GetFeed(ctx context.Context, req FeedRequest) ([]*FeedItem, error) {
	if req.RadiusM <= 0 || req.RadiusM > MaxRadius {
		req.RadiusM = DefaultRadius
	}
	page := req.Page
	if page < 1 {
		page = 1
	}
	offset := (page - 1) * FeedPageSize

	// Check Redis cache first (only cache page 1)
	cacheKey := fmt.Sprintf("%s:u:%s:p:%d", cache.FeedKey(req.Lat, req.Lng), req.UserID, page)
	if cached, err := s.cache.Get(ctx, cacheKey).Bytes(); err == nil {
		var items []*FeedItem
		if err := json.Unmarshal(cached, &items); err == nil {
			return items, nil
		}
	}

	rows, err := s.db.Query(ctx, `
		WITH feed AS (
			SELECT
				p.id,
				p.user_id,
				p.post_type::text,
				p.content,
				p.media_urls,
				ST_Y(p.location::geometry) AS lat,
				ST_X(p.location::geometry) AS lng,
				p.city,
				p.neighbourhood,
				p.business_id::text,
				p.interest_tags,
				ST_Distance(p.location, ST_Point($2, $1)::geography) AS distance_m,
				p.been_here_count,
				p.like_count,
				p.comment_count,
				p.expires_at,
				p.created_at,
				-- Ranking score: 40% proximity, 35% recency, 25% engagement
				(
					(1.0 - LEAST(ST_Distance(p.location, ST_Point($2, $1)::geography) / $3, 1.0)) * 0.40 +
					(EXTRACT(EPOCH FROM (NOW() - p.created_at)) / -172800 + 1) * 0.35 +
					(LN(GREATEST(p.been_here_count + p.like_count + 1, 1)) / 10.0) * 0.25
				) AS rank_score
			FROM posts p
			WHERE ST_DWithin(p.location, ST_Point($2, $1)::geography, $3)
			  AND p.moderation_status = 'approved'
			  AND (p.expires_at IS NULL OR p.expires_at > NOW())
			  AND p.created_at > NOW() - INTERVAL '48 hours'
		)
		SELECT
			f.*,
			u.display_name, u.avatar_url, u.is_verified, u.trust_score,
			b.name AS biz_name, b.category::text AS biz_category,
			b.cover_url AS biz_cover, b.rating_avg AS biz_rating
		FROM feed f
		JOIN users u ON u.id = f.user_id
		LEFT JOIN businesses b ON b.id = f.business_id::uuid
		ORDER BY rank_score DESC
		LIMIT $4 OFFSET $5
	`, req.Lat, req.Lng, req.RadiusM, FeedPageSize, offset)
	if err != nil {
		return nil, fmt.Errorf("query feed: %w", err)
	}
	defer rows.Close()

	var items []*FeedItem
	for rows.Next() {
		item := &FeedItem{Author: &Author{}}
		var bizName, bizCategory *string
		var bizCover *string
		var bizRating *float64

		err := rows.Scan(
			&item.ID, &item.UserID, &item.PostType, &item.Content,
			&item.MediaURLs, &item.Lat, &item.Lng, &item.City, &item.Neighbourhood,
			&item.BusinessID, &item.InterestTags, &item.DistanceM,
			&item.BeenHereCount, &item.LikeCount, &item.CommentCount,
			&item.ExpiresAt, &item.CreatedAt, nil, // rank_score
			&item.Author.DisplayName, &item.Author.AvatarURL,
			&item.Author.IsVerified, &item.Author.TrustScore,
			&bizName, &bizCategory, &bizCover, &bizRating,
		)
		if err != nil {
			continue
		}
		item.Author.ID = item.UserID

		if bizName != nil {
			item.BusinessSummary = &BusinessSummary{
				Name:     *bizName,
				Category: deref(bizCategory),
				CoverURL: bizCover,
			}
			if bizRating != nil {
				item.BusinessSummary.RatingAvg = *bizRating
			}
			if item.BusinessID != nil {
				item.BusinessSummary.ID = *item.BusinessID
			}
		}

		items = append(items, item)
	}

	// Cache the result
	if b, err := json.Marshal(items); err == nil {
		s.cache.Set(ctx, cacheKey, b, FeedCacheTTL)
	}

	return items, nil
}

// GetFlashFeed returns only time-sensitive Flash posts near the user
func (s *Service) GetFlashFeed(ctx context.Context, lat, lng, radiusM float64) ([]*FeedItem, error) {
	_ = geo.BucketKey(lat, lng) // for logging

	rows, err := s.db.Query(ctx, `
		SELECT
			p.id, p.user_id, p.content, p.media_urls,
			ST_Y(p.location::geometry) AS lat, ST_X(p.location::geometry) AS lng,
			p.city, p.neighbourhood, p.pulse_count, p.expires_at, p.created_at,
			p.business_id::text,
			ST_Distance(p.location, ST_Point($2, $1)::geography) AS distance_m,
			u.display_name, u.avatar_url, u.is_verified,
			b.name AS biz_name, b.category::text AS biz_category, b.cover_url AS biz_cover
		FROM posts p
		JOIN users u ON u.id = p.user_id
		LEFT JOIN businesses b ON b.id = p.business_id
		WHERE p.post_type = 'flash'
		  AND p.expires_at > NOW()
		  AND p.moderation_status = 'approved'
		  AND ST_DWithin(p.location, ST_Point($2, $1)::geography, $3)
		ORDER BY p.pulse_count DESC, p.created_at DESC
		LIMIT 20
	`, lat, lng, radiusM)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []*FeedItem
	for rows.Next() {
		item := &FeedItem{Author: &Author{}, PostType: "flash"}
		var bizID *string
		var bizName, bizCategory, bizCover *string
		err := rows.Scan(
			&item.ID, &item.UserID, &item.Content, &item.MediaURLs,
			&item.Lat, &item.Lng, &item.City, &item.Neighbourhood,
			&item.CommentCount, // pulse_count → CommentCount (existing convention)
			&item.ExpiresAt, &item.CreatedAt,
			&bizID, &item.DistanceM,
			&item.Author.DisplayName, &item.Author.AvatarURL, &item.Author.IsVerified,
			&bizName, &bizCategory, &bizCover,
		)
		if err != nil {
			continue
		}
		item.BusinessID = bizID
		if bizName != nil {
			item.BusinessSummary = &BusinessSummary{
				Name:     *bizName,
				Category: deref(bizCategory),
				CoverURL: bizCover,
			}
			if bizID != nil {
				item.BusinessSummary.ID = *bizID
			}
		}
		items = append(items, item)
	}

	return items, nil
}

// InvalidateUserFeed clears the feed cache for a user's current location
func (s *Service) InvalidateUserFeed(ctx context.Context, userID string, lat, lng float64) {
	key := fmt.Sprintf("%s:u:%s", cache.FeedKey(lat, lng), userID)
	s.cache.Del(ctx, key)
}

func deref(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}
