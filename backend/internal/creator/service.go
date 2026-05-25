package creator

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"

	"github.com/hapa-world/hapa/pkg/middleware"
)

type Creator struct {
	ID              string     `json:"id"`
	UserID          string     `json:"user_id"`
	City            string     `json:"city"`
	ContentFocus    string     `json:"content_focus"`
	Tier            string     `json:"tier"`
	Status          string     `json:"status"`
	Bio             string     `json:"bio,omitempty"`
	TotalReach      int        `json:"total_reach"`
	EngagementScore float64    `json:"engagement_score"`
	BeenHereTotal   int        `json:"been_here_total"`
	MonthlyEarnings float64    `json:"monthly_earnings"`
	AppliedAt       time.Time  `json:"applied_at"`
	ApprovedAt      *time.Time `json:"approved_at,omitempty"`
	// Joined from users
	DisplayName   string  `json:"display_name"`
	AvatarURL     *string `json:"avatar_url,omitempty"`
	FollowerCount int     `json:"follower_count"`
	PostCount     int     `json:"post_count"`
	IsFollowing   bool    `json:"is_following"`
}

type ApplyReq struct {
	City          string   `json:"city"`
	ContentFocus  string   `json:"content_focus"`
	Bio           string   `json:"bio"`
	PortfolioURLs []string `json:"portfolio_urls"`
}

type Service struct {
	db    *pgxpool.Pool
	cache *redis.Client
}

func NewService(db *pgxpool.Pool, cache *redis.Client) *Service {
	return &Service{db: db, cache: cache}
}

func (s *Service) Apply(ctx context.Context, userID string, req ApplyReq) error {
	_, err := s.db.Exec(ctx, `
		INSERT INTO creators (user_id, city, content_focus, bio, portfolio_urls)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (user_id) DO NOTHING
	`, userID, req.City, req.ContentFocus, req.Bio, req.PortfolioURLs)
	return err
}

func (s *Service) GetCreatorProfile(ctx context.Context, userID, requestingUserID string) (*Creator, error) {
	c := &Creator{}

	// Try the full creator profile first.
	err := s.db.QueryRow(ctx, `
		SELECT c.id, c.user_id, c.city, c.content_focus, c.tier::text, c.status::text,
		       c.bio, c.total_reach, c.engagement_score, c.been_here_total,
		       c.monthly_earnings, c.applied_at, c.approved_at,
		       u.display_name, u.avatar_url,
		       (SELECT COUNT(*) FROM user_follows WHERE following_id = c.user_id) AS follower_count,
		       (SELECT COUNT(*) FROM posts WHERE user_id = c.user_id ) AS post_count,
		       EXISTS(SELECT 1 FROM user_follows WHERE follower_id = $2 AND following_id = c.user_id) AS is_following
		FROM creators c
		JOIN users u ON u.id = c.user_id
		WHERE c.user_id = $1
	`, userID, requestingUserID).Scan(
		&c.ID, &c.UserID, &c.City, &c.ContentFocus, &c.Tier, &c.Status,
		&c.Bio, &c.TotalReach, &c.EngagementScore, &c.BeenHereTotal,
		&c.MonthlyEarnings, &c.AppliedAt, &c.ApprovedAt,
		&c.DisplayName, &c.AvatarURL,
		&c.FollowerCount, &c.PostCount, &c.IsFollowing,
	)
	if err == nil {
		return c, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		slog.Error("GetCreatorProfile query failed", "error", err, "userID", userID)
		return nil, err
	}

	// User exists but has no creator profile — return a basic public profile.
	var avatarURL *string
	err = s.db.QueryRow(ctx, `
		SELECT u.id, COALESCE(u.display_name, 'Hapa User'), u.avatar_url,
		       COALESCE(u.bio, ''), COALESCE(u.current_city, ''),
		       (SELECT COUNT(*) FROM user_follows WHERE following_id = u.id),
		       (SELECT COUNT(*) FROM posts WHERE user_id = u.id ),
		       EXISTS(SELECT 1 FROM user_follows WHERE follower_id = $2 AND following_id = u.id)
		FROM users u
		WHERE u.id = $1
	`, userID, requestingUserID).Scan(
		&c.UserID, &c.DisplayName, &avatarURL,
		&c.Bio, &c.City,
		&c.FollowerCount, &c.PostCount, &c.IsFollowing,
	)
	if err != nil {
		slog.Error("GetCreatorProfile user fallback failed", "error", err, "userID", userID)
		return nil, err
	}
	c.AvatarURL = avatarURL
	c.Tier = "rising_voice"
	c.Status = "pending"
	c.AppliedAt = time.Now()
	return c, nil
}

func (s *Service) DiscoverCreators(ctx context.Context, city, focus string, limit int) ([]*Creator, error) {
	rows, err := s.db.Query(ctx, `
		SELECT c.id, c.user_id, c.city, c.content_focus, c.tier::text,
		       c.total_reach, c.engagement_score, c.been_here_total,
		       u.display_name, u.avatar_url
		FROM creators c
		JOIN users u ON u.id = c.user_id
		WHERE c.city = $1
		  AND c.status = 'approved'
		  AND ($2 = '' OR c.content_focus ILIKE '%' || $2 || '%')
		ORDER BY c.tier DESC, c.engagement_score DESC
		LIMIT $3
	`, city, focus, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var creators []*Creator
	for rows.Next() {
		c := &Creator{}
		if err := rows.Scan(&c.ID, &c.UserID, &c.City, &c.ContentFocus, &c.Tier,
			&c.TotalReach, &c.EngagementScore, &c.BeenHereTotal,
			&c.DisplayName, &c.AvatarURL); err == nil {
			creators = append(creators, c)
		}
	}
	return creators, nil
}

func Routes(svc *Service) http.Handler {
	r := chi.NewRouter()
	r.Post("/apply", handleApply(svc))
	r.Get("/me", handleMyCreatorProfile(svc))
	r.Get("/discover", handleDiscover(svc))
	r.Get("/{userId}", handleGetCreator(svc))
	return r
}

func handleApply(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.UserIDFromCtx(r.Context())
		var req ApplyReq
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, `{"error":"invalid body"}`, http.StatusBadRequest)
			return
		}
		if err := svc.Apply(r.Context(), userID, req); err != nil {
			http.Error(w, `{"error":"application failed"}`, http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(map[string]string{"message": "application submitted — we review within 48 hours"})
	}
}

func handleMyCreatorProfile(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.UserIDFromCtx(r.Context())
		c, err := svc.GetCreatorProfile(r.Context(), userID, userID)
		if err != nil {
			http.Error(w, `{"error":"creator profile not found"}`, http.StatusNotFound)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(c)
	}
}

func handleDiscover(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query()
		city := q.Get("city")
		focus := q.Get("focus")
		creators, _ := svc.DiscoverCreators(r.Context(), city, focus, 20)
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{"creators": creators})
	}
}

func handleGetCreator(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		targetUserID := chi.URLParam(r, "userId")
		requestingUserID := middleware.UserIDFromCtx(r.Context())
		c, err := svc.GetCreatorProfile(r.Context(), targetUserID, requestingUserID)
		if err != nil {
			http.Error(w, `{"error":"not found"}`, http.StatusNotFound)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(c)
	}
}
