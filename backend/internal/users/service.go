package users

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"

	"github.com/hapa-world/hapa/pkg/middleware"
)

type User struct {
	ID             string    `json:"id"`
	Phone          string    `json:"phone,omitempty"`
	DisplayName    string    `json:"display_name"`
	Username       string    `json:"username,omitempty"`
	AvatarURL      string    `json:"avatar_url,omitempty"`
	Bio            string    `json:"bio,omitempty"`
	UserType       string    `json:"user_type"`
	Tier           string    `json:"tier"`
	CurrentCity    string    `json:"current_city,omitempty"`
	HomeCity       string    `json:"home_city,omitempty"`
	Language       string    `json:"language"`
	InterestTags   []string  `json:"interest_tags"`
	TrustScore     int       `json:"trust_score"`
	IsVerified     bool      `json:"is_verified"`
	FollowerCount  int       `json:"follower_count,omitempty"`
	FollowingCount int       `json:"following_count,omitempty"`
	DistanceM      float64   `json:"distance_m,omitempty"`
	IsFollowing    bool      `json:"is_following"`
	CreatedAt      time.Time `json:"created_at"`
}

type UpdateProfileReq struct {
	DisplayName  string   `json:"display_name"`
	Username     string   `json:"username"`
	Bio          string   `json:"bio"`
	UserType     string   `json:"user_type"`
	HomeCity     string   `json:"home_city"`
	Language     string   `json:"language"`
	InterestTags []string `json:"interest_tags"`
	AvatarURL    string   `json:"avatar_url"`
}

type OnboardingReq struct {
	DisplayName  string   `json:"display_name"`
	UserType     string   `json:"user_type"`
	InterestTags []string `json:"interest_tags"`
	Language     string   `json:"language"`
}

type Service struct {
	db    *pgxpool.Pool
	cache *redis.Client
}

func NewService(db *pgxpool.Pool, cache *redis.Client) *Service {
	return &Service{db: db, cache: cache}
}

func (s *Service) GetProfile(ctx context.Context, userID string) (*User, error) {
	u := &User{}
	err := s.db.QueryRow(ctx, `
		SELECT u.id, COALESCE(u.phone, ''), u.display_name,
		       COALESCE(u.username, ''), COALESCE(u.avatar_url, ''), COALESCE(u.bio, ''),
		       u.user_type::text, u.tier::text,
		       COALESCE(u.current_city, ''), COALESCE(u.home_city, ''),
		       u.language, u.interest_tags, u.trust_score, u.is_verified, u.created_at,
		       (SELECT COUNT(*) FROM user_follows WHERE following_id = u.id) AS followers,
		       (SELECT COUNT(*) FROM user_follows WHERE follower_id = u.id) AS following
		FROM users u WHERE u.id = $1
	`, userID).Scan(
		&u.ID, &u.Phone, &u.DisplayName, &u.Username, &u.AvatarURL, &u.Bio,
		&u.UserType, &u.Tier, &u.CurrentCity, &u.HomeCity,
		&u.Language, &u.InterestTags, &u.TrustScore, &u.IsVerified, &u.CreatedAt,
		&u.FollowerCount, &u.FollowingCount,
	)
	if err != nil {
		return nil, fmt.Errorf("user not found")
	}
	return u, nil
}

func (s *Service) CompleteOnboarding(ctx context.Context, userID string, req OnboardingReq) error {
	_, err := s.db.Exec(ctx, `
		UPDATE users
		SET display_name = $2,
		    user_type = $3::user_type,
		    interest_tags = $4,
		    language = $5,
		    updated_at = NOW()
		WHERE id = $1
	`, userID, req.DisplayName, req.UserType, req.InterestTags, req.Language)
	return err
}

func (s *Service) UpdateProfile(ctx context.Context, userID string, req UpdateProfileReq) error {
	_, err := s.db.Exec(ctx, `
		UPDATE users
		SET display_name = COALESCE(NULLIF($2, ''), display_name),
		    username = COALESCE(NULLIF($3, ''), username),
		    bio = COALESCE(NULLIF($4, ''), bio),
		    user_type = COALESCE(NULLIF($5, '')::user_type, user_type),
		    home_city = COALESCE(NULLIF($6, ''), home_city),
		    language = COALESCE(NULLIF($7, ''), language),
		    interest_tags = CASE WHEN array_length($8::text[], 1) > 0 THEN $8 ELSE interest_tags END,
		    avatar_url = COALESCE(NULLIF($9, ''), avatar_url),
		    updated_at = NOW()
		WHERE id = $1
	`, userID, req.DisplayName, req.Username, req.Bio, req.UserType,
		req.HomeCity, req.Language, req.InterestTags, req.AvatarURL)
	return err
}

func (s *Service) Follow(ctx context.Context, followerID, followingID string) error {
	_, err := s.db.Exec(ctx, `
		INSERT INTO user_follows (follower_id, following_id) VALUES ($1, $2)
		ON CONFLICT DO NOTHING
	`, followerID, followingID)
	return err
}

func (s *Service) Unfollow(ctx context.Context, followerID, followingID string) error {
	_, err := s.db.Exec(ctx, `
		DELETE FROM user_follows WHERE follower_id = $1 AND following_id = $2
	`, followerID, followingID)
	return err
}

func (s *Service) SearchUsers(ctx context.Context, query, requestingUserID string, limit int) ([]*User, error) {
	q := "%" + query + "%"
	rows, err := s.db.Query(ctx, `
		SELECT u.id, u.display_name, COALESCE(u.avatar_url, ''), COALESCE(u.bio, ''),
		       u.user_type::text, COALESCE(u.current_city, ''), u.trust_score, u.is_verified,
		       u.interest_tags,
		       EXISTS(SELECT 1 FROM user_follows WHERE follower_id = $2 AND following_id = u.id) AS is_following
		FROM users u
		WHERE u.id != $2
		  AND (u.display_name ILIKE $1 OR u.username ILIKE $1 OR u.bio ILIKE $1)
		  AND NOT EXISTS (SELECT 1 FROM user_blocks WHERE blocker_id = $2 AND blocked_id = u.id)
		ORDER BY u.trust_score DESC
		LIMIT $3
	`, q, requestingUserID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var users []*User
	for rows.Next() {
		u := &User{}
		if err := rows.Scan(&u.ID, &u.DisplayName, &u.AvatarURL, &u.Bio,
			&u.UserType, &u.CurrentCity, &u.TrustScore, &u.IsVerified,
			&u.InterestTags, &u.IsFollowing); err == nil {
			users = append(users, u)
		}
	}
	return users, nil
}

func (s *Service) DiscoverPeopleNearby(ctx context.Context, lat, lng float64, userID string, limit int) ([]*User, error) {
	rows, err := s.db.Query(ctx, `
		SELECT u.id, u.display_name, u.avatar_url, u.bio,
		       u.user_type::text, u.current_city, u.trust_score, u.is_verified,
		       u.interest_tags,
		       ST_Distance(MAX(ul.location), ST_SetSRID(ST_Point($2, $1), 4326)::geography) AS distance_m,
		       EXISTS(SELECT 1 FROM user_follows WHERE follower_id = $3 AND following_id = u.id) AS is_following
		FROM users u
		JOIN user_locations ul ON ul.user_id = u.id
		WHERE u.id != $3
		  AND u.privacy_mode = 'discoverable'
		  AND ST_DWithin(ul.location, ST_SetSRID(ST_Point($2, $1), 4326)::geography, 5000)
		  AND ul.recorded_at > NOW() - INTERVAL '2 hours'
		  AND NOT EXISTS (SELECT 1 FROM user_blocks WHERE blocker_id = $3 AND blocked_id = u.id)
		GROUP BY u.id
		ORDER BY distance_m ASC
		LIMIT $4
	`, lat, lng, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var people []*User
	for rows.Next() {
		u := &User{}
		if err := rows.Scan(&u.ID, &u.DisplayName, &u.AvatarURL, &u.Bio,
			&u.UserType, &u.CurrentCity, &u.TrustScore, &u.IsVerified,
			&u.InterestTags, &u.DistanceM, &u.IsFollowing); err == nil {
			people = append(people, u)
		}
	}
	return people, nil
}

// ── HTTP Routes ────────────────────────────────────────────────────────────────

func Routes(svc *Service) http.Handler {
	r := chi.NewRouter()
	r.Get("/me", handleGetMe(svc))
	r.Put("/me", handleUpdateProfile(svc))
	r.Post("/me/onboarding", handleCompleteOnboarding(svc))
	r.Get("/search", handleSearchUsers(svc))
	r.Get("/nearby", handleDiscover(svc))
	r.Get("/{id}", handleGetUser(svc))
	r.Post("/{id}/follow", handleFollow(svc))
	r.Delete("/{id}/follow", handleUnfollow(svc))
	return r
}

func handleGetMe(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.UserIDFromCtx(r.Context())
		u, err := svc.GetProfile(r.Context(), userID)
		if err != nil {
			writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
			return
		}
		writeJSON(w, http.StatusOK, u)
	}
}

func handleUpdateProfile(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.UserIDFromCtx(r.Context())
		var req UpdateProfileReq
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid body"})
			return
		}
		if err := svc.UpdateProfile(r.Context(), userID, req); err != nil {
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "update failed"})
			return
		}
		writeJSON(w, http.StatusOK, map[string]string{"message": "profile updated"})
	}
}

func handleCompleteOnboarding(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.UserIDFromCtx(r.Context())
		var req OnboardingReq
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid body"})
			return
		}
		if err := svc.CompleteOnboarding(r.Context(), userID, req); err != nil {
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "onboarding failed"})
			return
		}
		writeJSON(w, http.StatusOK, map[string]string{"message": "onboarding complete"})
	}
}

func handleGetUser(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id := chi.URLParam(r, "id")
		u, err := svc.GetProfile(r.Context(), id)
		if err != nil {
			writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
			return
		}
		u.Phone = "" // scrub private field
		writeJSON(w, http.StatusOK, u)
	}
}

func handleFollow(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		followerID := middleware.UserIDFromCtx(r.Context())
		followingID := chi.URLParam(r, "id")
		svc.Follow(r.Context(), followerID, followingID)
		writeJSON(w, http.StatusOK, map[string]string{"message": "following"})
	}
}

func handleUnfollow(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		followerID := middleware.UserIDFromCtx(r.Context())
		followingID := chi.URLParam(r, "id")
		svc.Unfollow(r.Context(), followerID, followingID)
		writeJSON(w, http.StatusOK, map[string]string{"message": "unfollowed"})
	}
}

func handleDiscover(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query()
		lat, _ := strconv.ParseFloat(q.Get("lat"), 64)
		lng, _ := strconv.ParseFloat(q.Get("lng"), 64)
		userID, _ := r.Context().Value("userID").(string)

		people, err := svc.DiscoverPeopleNearby(r.Context(), lat, lng, userID, 50)
		if err != nil || people == nil {
			people = []*User{}
		}
		writeJSON(w, http.StatusOK, map[string]any{"users": people})
	}
}

func handleSearchUsers(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query().Get("q")
		if len(q) < 2 {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "query too short"})
			return
		}
		userID := middleware.UserIDFromCtx(r.Context())
		users, err := svc.SearchUsers(r.Context(), q, userID, 30)
		if err != nil || users == nil {
			users = []*User{}
		}
		writeJSON(w, http.StatusOK, map[string]any{"users": users})
	}
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}
