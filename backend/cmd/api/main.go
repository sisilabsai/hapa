package main

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	chimiddleware "github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	"github.com/go-chi/httprate"

	"github.com/hapa-world/hapa/internal/ai"
	"github.com/hapa-world/hapa/internal/auth"
	"github.com/hapa-world/hapa/internal/booking"
	"github.com/hapa-world/hapa/internal/circles"
	"github.com/hapa-world/hapa/internal/media"
	"github.com/hapa-world/hapa/internal/business"
	"github.com/hapa-world/hapa/internal/content"
	"github.com/hapa-world/hapa/internal/creator"
	"github.com/hapa-world/hapa/internal/feed"
	"github.com/hapa-world/hapa/internal/location"
	"github.com/hapa-world/hapa/internal/moderation"
	"github.com/hapa-world/hapa/internal/notification"
	"github.com/hapa-world/hapa/internal/payment"
	"github.com/hapa-world/hapa/internal/recommendation"
	"github.com/hapa-world/hapa/internal/search"
	"github.com/hapa-world/hapa/internal/users"
	"github.com/hapa-world/hapa/pkg/cache"
	"github.com/hapa-world/hapa/pkg/config"
	"github.com/hapa-world/hapa/pkg/db"
	pkgmiddleware "github.com/hapa-world/hapa/pkg/middleware"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))
	slog.SetDefault(logger)

	cfg := config.Load()

	// ── Database ─────────────────────────────────────────────────────────
	pool, err := db.Connect(cfg.DatabaseURL)
	if err != nil {
		slog.Error("failed to connect to database", "error", err)
		os.Exit(1)
	}
	defer pool.Close()

	// ── Cache ─────────────────────────────────────────────────────────────
	redisClient := cache.Connect(cfg.RedisURL)
	defer redisClient.Close()

	// ── Search ────────────────────────────────────────────────────────────
	searchClient := search.NewClient(cfg.MeiliURL, cfg.MeiliMasterKey)

	// ── Domain services ───────────────────────────────────────────────────
	authSvc := auth.NewService(pool, redisClient, cfg)
	userSvc := users.NewService(pool, redisClient)
	locationSvc := location.NewService(pool, redisClient)
	contentSvc := content.NewService(pool, redisClient, searchClient)
	feedSvc := feed.NewService(pool, redisClient)
	businessSvc := business.NewService(pool, redisClient, searchClient)
	creatorSvc := creator.NewService(pool, redisClient)
	bookingSvc := booking.NewService(pool, redisClient)
	circlesSvc := circles.NewService(pool)
	moderationSvc := moderation.NewService(pool, cfg)
	notifSvc := notification.NewService(pool, redisClient, cfg)
	paymentSvc := payment.NewService(cfg)
	recommendationSvc := recommendation.NewService(pool, redisClient)
	_ = recommendationSvc
	aiSvc := ai.New(cfg.DeepSeekAPIKey)

	// ── HTTP Router ───────────────────────────────────────────────────────
	r := chi.NewRouter()

	r.Use(chimiddleware.RequestID)
	r.Use(chimiddleware.RealIP)
	r.Use(chimiddleware.Logger)
	r.Use(chimiddleware.Recoverer)
	r.Use(chimiddleware.Compress(5))
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   cfg.AllowedOrigins,
		AllowedMethods:   []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-Request-ID"},
		ExposedHeaders:   []string{"X-Request-ID"},
		AllowCredentials: true,
		MaxAge:           300,
	}))
	r.Use(httprate.LimitByIP(100, time.Minute))

	authMw := pkgmiddleware.Auth(cfg.JWTSecret)

	// ── Routes ────────────────────────────────────────────────────────────
	r.Get("/health", healthHandler(pool, redisClient))
	r.Handle("/uploads/*", media.StaticHandler())

	r.Route("/v1", func(r chi.Router) {
		// Public routes
		r.Mount("/auth", auth.Routes(authSvc))
		r.Get("/guide/{city}", content.GuideHandler(contentSvc, aiSvc))

		// Protected routes
		r.Group(func(r chi.Router) {
			r.Use(authMw)

			r.Mount("/users", users.Routes(userSvc))
			r.Mount("/feed", feed.Routes(feedSvc))
			r.Mount("/posts", content.Routes(contentSvc, moderationSvc))
				r.Post("/media", media.Handler(cfg))
			r.Mount("/places", business.PlacesRoutes(businessSvc))
			r.Mount("/businesses", business.Routes(businessSvc))
			r.Mount("/creators", creator.Routes(creatorSvc))
			r.Mount("/bookings", booking.Routes(bookingSvc, paymentSvc))
			r.Mount("/circles", circles.Routes(circlesSvc))
			r.Mount("/notifications", notification.Routes(notifSvc))
			r.Mount("/location", location.Routes(locationSvc))
			r.Mount("/search", search.Routes(searchClient))
			r.Mount("/ai", content.AIRoutes(contentSvc, aiSvc))
		})

		// WebSocket endpoint (auth via query param)
		r.Get("/ws", notification.WebSocketHandler(notifSvc, cfg.JWTSecret))
	})

	srv := &http.Server{
		Addr:         fmt.Sprintf(":%s", cfg.Port),
		Handler:      r,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// ── Graceful shutdown ─────────────────────────────────────────────────
	done := make(chan os.Signal, 1)
	signal.Notify(done, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		slog.Info("Hapa API starting", "port", cfg.Port, "env", cfg.Env)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("server error", "error", err)
			os.Exit(1)
		}
	}()

	<-done
	slog.Info("shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		slog.Error("server shutdown error", "error", err)
	}

	slog.Info("server stopped")
}

func healthHandler(pool db.Pool, redis cache.Client) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx := r.Context()

		if err := pool.Ping(ctx); err != nil {
			http.Error(w, `{"status":"unhealthy","db":"down"}`, http.StatusServiceUnavailable)
			return
		}

		if err := redis.Ping(ctx).Err(); err != nil {
			http.Error(w, `{"status":"unhealthy","cache":"down"}`, http.StatusServiceUnavailable)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, `{"status":"healthy","service":"hapa-api","version":"1.0.0"}`)
	}
}
