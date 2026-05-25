package feed

import (
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/hapa-world/hapa/pkg/middleware"
)

// postDTO matches the mobile Post.fromJson field names exactly
type postDTO struct {
	ID              string     `json:"id"`
	UserID          string     `json:"user_id"`
	UserDisplayName string     `json:"user_display_name"`
	UserAvatarURL   *string    `json:"user_avatar_url,omitempty"`
	PostType        string     `json:"post_type"`
	Body            string     `json:"body"`
	MediaURL        *string    `json:"media_url,omitempty"`
	MediaURLs       []string   `json:"media_urls"`
	Lat             float64    `json:"lat"`
	Lng             float64    `json:"lng"`
	City            string     `json:"city"`
	Neighbourhood   string     `json:"neighbourhood,omitempty"`
	DistanceM       float64    `json:"distance_m"`
	BeenHereCount   int        `json:"been_here_count"`
	LikeCount       int        `json:"like_count"`
	CommentCount    int        `json:"comment_count"`
	PulseCount      int        `json:"pulse_count"`
	BusinessID      *string    `json:"business_id,omitempty"`
	BusinessName    *string    `json:"business_name,omitempty"`
	IsFlash         bool       `json:"is_flash"`
	FlashExpiresAt  *time.Time `json:"flash_expires_at,omitempty"`
	CreatedAt       time.Time  `json:"created_at"`
}

func toDTO(item *FeedItem) postDTO {
	d := postDTO{
		ID:            item.ID,
		UserID:        item.UserID,
		PostType:      item.PostType,
		Body:          item.Content,
		MediaURLs:     item.MediaURLs,
		Lat:           item.Lat,
		Lng:           item.Lng,
		City:          item.City,
		Neighbourhood: item.Neighbourhood,
		DistanceM:     item.DistanceM,
		BeenHereCount: item.BeenHereCount,
		LikeCount:     item.LikeCount,
		CommentCount:  item.CommentCount,
		IsFlash:       item.PostType == "flash",
		FlashExpiresAt: item.ExpiresAt,
		CreatedAt:     item.CreatedAt,
	}
	if item.Author != nil {
		d.UserDisplayName = item.Author.DisplayName
		d.UserAvatarURL = item.Author.AvatarURL
	}
	if len(item.MediaURLs) > 0 {
		d.MediaURL = &item.MediaURLs[0]
	}
	if item.BusinessSummary != nil {
		d.BusinessID = item.BusinessID
		d.BusinessName = &item.BusinessSummary.Name
	}
	return d
}

func toDTOs(items []*FeedItem) []postDTO {
	if items == nil {
		return []postDTO{}
	}
	out := make([]postDTO, len(items))
	for i, item := range items {
		out[i] = toDTO(item)
	}
	return out
}

func Routes(svc *Service) http.Handler {
	r := chi.NewRouter()
	r.Get("/", handleGetFeed(svc))
	r.Get("/flash", handleGetFlashFeed(svc))
	return r
}

func handleGetFeed(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query()
		lat, _ := strconv.ParseFloat(q.Get("lat"), 64)
		lng, _ := strconv.ParseFloat(q.Get("lng"), 64)
		radiusM, _ := strconv.ParseFloat(q.Get("radius"), 64)

		if lat == 0 || lng == 0 {
			writeError(w, http.StatusBadRequest, "lat and lng required")
			return
		}

		userID := middleware.UserIDFromCtx(r.Context())
		page, _ := strconv.Atoi(q.Get("page"))

		items, err := svc.GetFeed(r.Context(), FeedRequest{
			Lat:     lat,
			Lng:     lng,
			RadiusM: radiusM,
			UserID:  userID,
			Page:    page,
		})
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to load feed")
			return
		}

		posts := toDTOs(items)
		writeJSON(w, http.StatusOK, map[string]any{
			"posts":    posts,
			"count":    len(posts),
			"location": map[string]float64{"lat": lat, "lng": lng},
		})
	}
}

func handleGetFlashFeed(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query()
		lat, _ := strconv.ParseFloat(q.Get("lat"), 64)
		lng, _ := strconv.ParseFloat(q.Get("lng"), 64)
		radiusM, _ := strconv.ParseFloat(q.Get("radius"), 64)
		if radiusM <= 0 {
			radiusM = 3000
		}

		items, err := svc.GetFlashFeed(r.Context(), lat, lng, radiusM)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to load flash feed")
			return
		}

		writeJSON(w, http.StatusOK, map[string]any{"posts": toDTOs(items), "count": len(items)})
	}
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}
