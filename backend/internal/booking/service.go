package booking

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"

	"github.com/hapa-world/hapa/internal/payment"
	"github.com/hapa-world/hapa/pkg/middleware"
)

type Booking struct {
	ID           string    `json:"id"`
	UserID       string    `json:"user_id"`
	BusinessID   string    `json:"business_id"`
	ServiceName  string    `json:"service_name,omitempty"`
	Quantity     int       `json:"quantity"`
	PriceUSD     float64   `json:"price_usd,omitempty"`
	Notes        string    `json:"notes,omitempty"`
	BookingDate  time.Time `json:"booking_date"`
	Status       string    `json:"status"`
	CreatedAt    time.Time `json:"created_at"`
}

type CreateBookingReq struct {
	BusinessID  string    `json:"business_id"`
	ServiceName string    `json:"service_name"`
	Quantity    int       `json:"quantity"`
	PriceUSD    float64   `json:"price_usd"`
	Notes       string    `json:"notes"`
	BookingDate time.Time `json:"booking_date"`
	PostID      string    `json:"post_id,omitempty"`    // attribution
	CreatorID   string    `json:"creator_id,omitempty"` // creator attribution
}

type Service struct {
	db    *pgxpool.Pool
	cache *redis.Client
}

func NewService(db *pgxpool.Pool, cache *redis.Client) *Service {
	return &Service{db: db, cache: cache}
}

func (s *Service) CreateBooking(ctx context.Context, userID string, req CreateBookingReq) (*Booking, error) {
	var b Booking
	err := s.db.QueryRow(ctx, `
		INSERT INTO bookings (user_id, business_id, post_id, creator_id, service_name, quantity, price_usd, notes, booking_date)
		VALUES ($1, $2,
		        NULLIF($3, '')::uuid, NULLIF($4, '')::uuid,
		        $5, $6, $7, $8, $9)
		RETURNING id, user_id, business_id, service_name, quantity, price_usd, notes, booking_date, status::text, created_at
	`,
		userID, req.BusinessID, req.PostID, req.CreatorID,
		req.ServiceName, req.Quantity, req.PriceUSD, req.Notes, req.BookingDate,
	).Scan(
		&b.ID, &b.UserID, &b.BusinessID, &b.ServiceName,
		&b.Quantity, &b.PriceUSD, &b.Notes, &b.BookingDate, &b.Status, &b.CreatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("create booking: %w", err)
	}
	return &b, nil
}

func (s *Service) GetUserBookings(ctx context.Context, userID string) ([]*Booking, error) {
	rows, err := s.db.Query(ctx, `
		SELECT b.id, b.user_id, b.business_id, b.service_name, b.quantity,
		       b.price_usd, b.notes, b.booking_date, b.status::text, b.created_at
		FROM bookings b
		WHERE b.user_id = $1
		ORDER BY b.created_at DESC
		LIMIT 50
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var bookings []*Booking
	for rows.Next() {
		b := &Booking{}
		if err := rows.Scan(&b.ID, &b.UserID, &b.BusinessID, &b.ServiceName,
			&b.Quantity, &b.PriceUSD, &b.Notes, &b.BookingDate, &b.Status, &b.CreatedAt); err == nil {
			bookings = append(bookings, b)
		}
	}
	return bookings, nil
}

func (s *Service) ConfirmBooking(ctx context.Context, bookingID, businessOwnerID string) error {
	_, err := s.db.Exec(ctx, `
		UPDATE bookings b
		SET status = 'confirmed', confirmed_at = NOW()
		FROM businesses biz
		WHERE b.id = $1 AND b.business_id = biz.id AND biz.owner_id = $2
	`, bookingID, businessOwnerID)
	return err
}

func Routes(svc *Service, pay *payment.Service) http.Handler {
	r := chi.NewRouter()
	r.Post("/", handleCreateBooking(svc))
	r.Get("/", handleGetBookings(svc))
	r.Post("/{id}/confirm", handleConfirmBooking(svc))
	r.Post("/{id}/pay", handlePay(pay))
	return r
}

func handleCreateBooking(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.UserIDFromCtx(r.Context())
		var req CreateBookingReq
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, `{"error":"invalid body"}`, http.StatusBadRequest)
			return
		}
		b, err := svc.CreateBooking(r.Context(), userID, req)
		if err != nil {
			http.Error(w, `{"error":"booking failed"}`, http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(b)
	}
}

func handleGetBookings(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.UserIDFromCtx(r.Context())
		bookings, _ := svc.GetUserBookings(r.Context(), userID)
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{"bookings": bookings})
	}
}

func handleConfirmBooking(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.UserIDFromCtx(r.Context())
		id := chi.URLParam(r, "id")
		svc.ConfirmBooking(r.Context(), id, userID)
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"message": "confirmed"})
	}
}

func handlePay(pay *payment.Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// TODO: integrate Flutterwave payment flow
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{"message": "payment initiated"})
	}
}
