package circles

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"

	"github.com/hapa-world/hapa/pkg/middleware"
)

func Routes(svc *Service) http.Handler {
	r := chi.NewRouter()
	r.Get("/", handleDiscover(svc))
	r.Get("/mine", handleMine(svc))
	r.Post("/", handleCreate(svc))
	r.Get("/{id}", handleGet(svc))
	r.Post("/{id}/join", handleJoin(svc))
	r.Delete("/{id}/join", handleLeave(svc))
	r.Get("/{id}/posts", handlePosts(svc))
	return r
}

func handleDiscover(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.UserIDFromCtx(r.Context())
		city := r.URL.Query().Get("city")
		limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
		offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))

		circles, err := svc.DiscoverCircles(r.Context(), city, userID, limit, offset)
		if err != nil {
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "could not load circles"})
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"circles": circles, "count": len(circles)})
	}
}

func handleMine(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.UserIDFromCtx(r.Context())
		circles, err := svc.MyCircles(r.Context(), userID)
		if err != nil {
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "could not load circles"})
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"circles": circles})
	}
}

func handleGet(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.UserIDFromCtx(r.Context())
		id := chi.URLParam(r, "id")
		circle, err := svc.GetCircle(r.Context(), id, userID)
		if err != nil {
			writeJSON(w, http.StatusNotFound, map[string]string{"error": "circle not found"})
			return
		}
		writeJSON(w, http.StatusOK, circle)
	}
}

func handleCreate(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.UserIDFromCtx(r.Context())
		var req CreateCircleReq
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid body"})
			return
		}
		if req.Name == "" || req.City == "" {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": "name and city required"})
			return
		}
		circle, err := svc.CreateCircle(r.Context(), req, userID)
		if err != nil {
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "could not create circle"})
			return
		}
		writeJSON(w, http.StatusCreated, circle)
	}
}

func handleJoin(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.UserIDFromCtx(r.Context())
		id := chi.URLParam(r, "id")
		if err := svc.JoinCircle(r.Context(), id, userID); err != nil {
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "could not join"})
			return
		}
		writeJSON(w, http.StatusOK, map[string]string{"ok": "true"})
	}
}

func handleLeave(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.UserIDFromCtx(r.Context())
		id := chi.URLParam(r, "id")
		if err := svc.LeaveCircle(r.Context(), id, userID); err != nil {
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "could not leave"})
			return
		}
		writeJSON(w, http.StatusOK, map[string]string{"ok": "true"})
	}
}

func handlePosts(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.UserIDFromCtx(r.Context())
		id := chi.URLParam(r, "id")
		limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
		offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))

		posts, err := svc.CirclePosts(r.Context(), id, userID, limit, offset)
		if err != nil {
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "could not load posts"})
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"posts": posts})
	}
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}
