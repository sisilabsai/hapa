package notification

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"

	"github.com/hapa-world/hapa/pkg/cache"
	"github.com/hapa-world/hapa/pkg/config"
	"github.com/hapa-world/hapa/pkg/middleware"
)

type Notification struct {
	ID        string         `json:"id"`
	UserID    string         `json:"user_id"`
	Type      string         `json:"type"`
	Title     string         `json:"title"`
	Body      string         `json:"body"`
	Data      map[string]any `json:"data,omitempty"`
	IsRead    bool           `json:"is_read"`
	CreatedAt time.Time      `json:"created_at"`
}

type Service struct {
	db    *pgxpool.Pool
	cache *redis.Client
	cfg   *config.Config
}

func NewService(db *pgxpool.Pool, cache *redis.Client, cfg *config.Config) *Service {
	return &Service{db: db, cache: cache, cfg: cfg}
}

// Send creates and queues a notification for delivery
func (s *Service) Send(ctx context.Context, userID, notifType, title, body string, data map[string]any) error {
	dataJSON, _ := json.Marshal(data)

	_, err := s.db.Exec(ctx, `
		INSERT INTO notifications (user_id, type, title, body, data, sent_at)
		VALUES ($1, $2::notification_type, $3, $4, $5, NOW())
	`, userID, notifType, title, body, string(dataJSON))
	if err != nil {
		return fmt.Errorf("store notification: %w", err)
	}

	// Push to user's Redis queue for real-time delivery
	payload, _ := json.Marshal(map[string]any{
		"type": notifType, "title": title, "body": body, "data": data,
	})
	s.cache.LPush(ctx, cache.NotifQueueKey(userID), payload)
	s.cache.Expire(ctx, cache.NotifQueueKey(userID), 24*time.Hour)

	return nil
}

// SendCitySwitch fires when a user lands in a new city
func (s *Service) SendCitySwitch(ctx context.Context, userID, city string) {
	s.Send(ctx, userID, "city_switch",
		fmt.Sprintf("Welcome to %s", city),
		fmt.Sprintf("Hapa is showing you what's happening in %s right now.", city),
		map[string]any{"city": city},
	)
}

// GetAll returns all notifications for a user (read + unread)
func (s *Service) GetAll(ctx context.Context, userID string, limit int) ([]*Notification, error) {
	rows, err := s.db.Query(ctx, `
		SELECT id, user_id, type::text, title, body, data::text, is_read, created_at
		FROM notifications
		WHERE user_id = $1
		ORDER BY created_at DESC
		LIMIT $2
	`, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var notifs []*Notification
	for rows.Next() {
		n := &Notification{}
		var dataStr string
		if err := rows.Scan(&n.ID, &n.UserID, &n.Type, &n.Title, &n.Body, &dataStr, &n.IsRead, &n.CreatedAt); err == nil {
			json.Unmarshal([]byte(dataStr), &n.Data)
			notifs = append(notifs, n)
		}
	}
	return notifs, nil
}

// UnreadCount returns the number of unread notifications
func (s *Service) UnreadCount(ctx context.Context, userID string) (int, error) {
	var count int
	err := s.db.QueryRow(ctx, `SELECT COUNT(*) FROM notifications WHERE user_id = $1 AND is_read = FALSE`, userID).Scan(&count)
	return count, err
}

// GetUnread returns unread notifications for a user
func (s *Service) GetUnread(ctx context.Context, userID string, limit int) ([]*Notification, error) {
	rows, err := s.db.Query(ctx, `
		SELECT id, user_id, type::text, title, body, data::text, is_read, created_at
		FROM notifications
		WHERE user_id = $1 AND is_read = FALSE
		ORDER BY created_at DESC
		LIMIT $2
	`, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var notifs []*Notification
	for rows.Next() {
		n := &Notification{}
		var dataStr string
		if err := rows.Scan(&n.ID, &n.UserID, &n.Type, &n.Title, &n.Body, &dataStr, &n.IsRead, &n.CreatedAt); err == nil {
			json.Unmarshal([]byte(dataStr), &n.Data)
			notifs = append(notifs, n)
		}
	}
	return notifs, nil
}

// MarkRead marks notifications as read
func (s *Service) MarkRead(ctx context.Context, userID string, ids []string) error {
	if len(ids) == 0 {
		_, err := s.db.Exec(ctx, `UPDATE notifications SET is_read = TRUE WHERE user_id = $1`, userID)
		return err
	}
	_, err := s.db.Exec(ctx, `UPDATE notifications SET is_read = TRUE WHERE user_id = $1 AND id = ANY($2)`, userID, ids)
	return err
}

// WebSocketHandler handles real-time notification delivery
func WebSocketHandler(svc *Service, jwtSecret string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// TODO: upgrade to WebSocket via Ably SDK or nhooyr.io/websocket
		// For now, return SSE (Server-Sent Events) as a simpler alternative
		userID := middleware.UserIDFromCtx(r.Context())
		if userID == "" {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}

		w.Header().Set("Content-Type", "text/event-stream")
		w.Header().Set("Cache-Control", "no-cache")
		w.Header().Set("Connection", "keep-alive")

		flusher, ok := w.(http.Flusher)
		if !ok {
			http.Error(w, "streaming not supported", http.StatusInternalServerError)
			return
		}

		ctx := r.Context()
		ticker := time.NewTicker(5 * time.Second)
		defer ticker.Stop()

		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				// Poll Redis queue for new notifications
				items, _ := svc.cache.LRange(ctx, cache.NotifQueueKey(userID), 0, -1).Result()
				if len(items) > 0 {
					svc.cache.Del(ctx, cache.NotifQueueKey(userID))
					for _, item := range items {
						fmt.Fprintf(w, "data: %s\n\n", item)
					}
					flusher.Flush()
				}
				fmt.Fprintf(w, ": heartbeat\n\n")
				flusher.Flush()
			}
		}
	}
}

// Routes — notification HTTP handlers
func Routes(svc *Service) http.Handler {
	r := chi.NewRouter()
	r.Get("/", handleGetNotifications(svc))
	r.Get("/count", handleUnreadCount(svc))
	r.Post("/read", handleMarkRead(svc))
	return r
}

func handleGetNotifications(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.UserIDFromCtx(r.Context())
		notifs, err := svc.GetAll(r.Context(), userID, 60)
		if err != nil || notifs == nil {
			notifs = []*Notification{}
		}
		unread := 0
		for _, n := range notifs {
			if !n.IsRead {
				unread++
			}
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{"notifications": notifs, "unread_count": unread})
	}
}

func handleUnreadCount(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.UserIDFromCtx(r.Context())
		count, _ := svc.UnreadCount(r.Context(), userID)
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]int{"count": count})
	}
}

func handleMarkRead(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.UserIDFromCtx(r.Context())
		var req struct {
			IDs []string `json:"ids"`
		}
		json.NewDecoder(r.Body).Decode(&req)
		svc.MarkRead(r.Context(), userID, req.IDs)
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"message": "marked read"})
	}
}
