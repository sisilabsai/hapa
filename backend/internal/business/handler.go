package business

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"

	"github.com/hapa-world/hapa/pkg/middleware"
)

func contains(s, substr string) bool { return strings.Contains(s, substr) }


// PlacesRoutes — public-facing place discovery
func PlacesRoutes(svc *Service) http.Handler {
	r := chi.NewRouter()
	r.Get("/", handleSearchPlaces(svc))
	r.Get("/{id}", handleGetBusiness(svc))
	r.Get("/boosts", handleActiveBoosts(svc))
	return r
}

// Routes — authenticated business management
func Routes(svc *Service) http.Handler {
	r := chi.NewRouter()
	r.Get("/search", handleSearchBusinesses(svc))
	r.Post("/", handleCreateBusiness(svc))
	r.Get("/mine", handleMyBusinesses(svc))
	r.Get("/{id}/manage", handleGetOwnerBusiness(svc))
	r.Put("/{id}", handleUpdateBusiness(svc))
	r.Get("/{id}/analytics", handleBusinessAnalytics(svc))
	r.Get("/{id}/reviews", handleBusinessReviews(svc))
	r.Post("/{id}/reviews/{reviewId}/reply", handleReviewReply(svc))
	r.Get("/{id}/menu", handleGetMenuItems(svc))
	r.Post("/{id}/menu", handleCreateMenuItem(svc))
	r.Put("/{id}/menu/{itemId}", handleUpdateMenuItem(svc))
	r.Delete("/{id}/menu/{itemId}", handleDeleteMenuItem(svc))
	r.Post("/{id}/verify", handleRequestVerification(svc))
	r.Post("/{id}/boost", handleCreateBoost(svc))
	return r
}

func handleSearchBusinesses(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query()
		lat, _ := strconv.ParseFloat(q.Get("lat"), 64)
		lng, _ := strconv.ParseFloat(q.Get("lng"), 64)
		radiusM, _ := strconv.ParseFloat(q.Get("radius"), 64)
		priceMax, _ := strconv.Atoi(q.Get("price_max"))

		businesses, err := svc.SearchPlaces(r.Context(), SearchPlacesReq{
			Lat:      lat,
			Lng:      lng,
			RadiusM:  radiusM,
			Category: q.Get("category"),
			Query:    q.Get("q"),
			PriceMax: priceMax,
		})
		if err != nil || businesses == nil {
			businesses = []*Business{}
		}

		writeJSON(w, http.StatusOK, map[string]any{
			"businesses": businesses,
			"count":      len(businesses),
		})
	}
}

func handleSearchPlaces(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query()
		lat, _ := strconv.ParseFloat(q.Get("lat"), 64)
		lng, _ := strconv.ParseFloat(q.Get("lng"), 64)
		radiusM, _ := strconv.ParseFloat(q.Get("radius"), 64)
		priceMax, _ := strconv.Atoi(q.Get("price_max"))

		businesses, err := svc.SearchPlaces(r.Context(), SearchPlacesReq{
			Lat:      lat,
			Lng:      lng,
			RadiusM:  radiusM,
			Category: q.Get("category"),
			Query:    q.Get("q"),
			PriceMax: priceMax,
		})
		if err != nil {
			writeError(w, http.StatusInternalServerError, "search failed")
			return
		}

		writeJSON(w, http.StatusOK, map[string]any{
			"places": businesses,
			"count":  len(businesses),
		})
	}
}

func handleGetBusiness(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id := chi.URLParam(r, "id")
		biz, err := svc.GetBusiness(r.Context(), id)
		if err != nil {
			writeError(w, http.StatusNotFound, "business not found")
			return
		}
		writeJSON(w, http.StatusOK, biz)
	}
}

func handleActiveBoosts(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query()
		lat, _ := strconv.ParseFloat(q.Get("lat"), 64)
		lng, _ := strconv.ParseFloat(q.Get("lng"), 64)
		radius, _ := strconv.ParseFloat(q.Get("radius"), 64)
		if radius <= 0 {
			radius = 2000
		}

		boosts, err := svc.ActiveBoostsNear(r.Context(), lat, lng, radius)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to load boosts")
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"boosts": boosts})
	}
}

func handleCreateBusiness(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ownerID := middleware.UserIDFromCtx(r.Context())

		var req CreateBusinessReq
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeError(w, http.StatusBadRequest, "invalid request body")
			return
		}

		biz, err := svc.CreateBusiness(r.Context(), ownerID, req)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to create business")
			return
		}

		writeJSON(w, http.StatusCreated, biz)
	}
}

func handleMyBusinesses(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ownerID := middleware.UserIDFromCtx(r.Context())
		businesses, err := svc.MyBusinesses(r.Context(), ownerID)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to fetch businesses")
			return
		}
		if businesses == nil {
			businesses = []*Business{}
		}
		writeJSON(w, http.StatusOK, map[string]any{"businesses": businesses})
	}
}

func handleGetOwnerBusiness(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ownerID := middleware.UserIDFromCtx(r.Context())
		if ownerID == "" {
			writeError(w, http.StatusUnauthorized, "unauthorized")
			return
		}
		id := chi.URLParam(r, "id")
		biz, err := svc.GetBusinessForOwner(r.Context(), id, ownerID)
		if err != nil {
			status := http.StatusInternalServerError
			if err.Error() == "no rows in result set" || contains(err.Error(), "no rows") {
				status = http.StatusNotFound
			}
			writeError(w, status, err.Error())
			return
		}
		writeJSON(w, http.StatusOK, biz)
	}
}

func handleUpdateBusiness(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ownerID := middleware.UserIDFromCtx(r.Context())
		if ownerID == "" {
			writeError(w, http.StatusUnauthorized, "unauthorized")
			return
		}
		id := chi.URLParam(r, "id")

		var req UpdateBusinessReq
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeError(w, http.StatusBadRequest, "invalid request body")
			return
		}

		biz, err := svc.UpdateBusiness(r.Context(), id, ownerID, req)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to update business")
			return
		}
		writeJSON(w, http.StatusOK, biz)
	}
}

func handleBusinessAnalytics(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ownerID := middleware.UserIDFromCtx(r.Context())
		if ownerID == "" {
			writeError(w, http.StatusUnauthorized, "unauthorized")
			return
		}
		id := chi.URLParam(r, "id")
		analytics, err := svc.GetBusinessAnalytics(r.Context(), id)
		if err != nil {
			writeError(w, http.StatusNotFound, err.Error())
			return
		}
		writeJSON(w, http.StatusOK, analytics)
	}
}

func handleBusinessReviews(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ownerID := middleware.UserIDFromCtx(r.Context())
		if ownerID == "" {
			writeError(w, http.StatusUnauthorized, "unauthorized")
			return
		}
		id := chi.URLParam(r, "id")
		page, _ := strconv.Atoi(r.URL.Query().Get("page"))

		reviews, err := svc.GetBusinessReviews(r.Context(), id, page)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to fetch reviews")
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"reviews": reviews})
	}
}

func handleReviewReply(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ownerID := middleware.UserIDFromCtx(r.Context())
		if ownerID == "" {
			writeError(w, http.StatusUnauthorized, "unauthorized")
			return
		}
		businessID := chi.URLParam(r, "id")
		reviewID := chi.URLParam(r, "reviewId")

		var body struct {
			Content string `json:"content"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.Content == "" {
			writeError(w, http.StatusBadRequest, "content is required")
			return
		}

		if err := svc.ReplyToReview(r.Context(), businessID, reviewID, body.Content); err != nil {
			writeError(w, http.StatusBadRequest, err.Error())
			return
		}
		writeJSON(w, http.StatusOK, map[string]string{"message": "reply posted"})
	}
}

func handleGetMenuItems(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		id := chi.URLParam(r, "id")
		items, err := svc.GetMenuItems(r.Context(), id)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to fetch menu")
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"items": items})
	}
}

func handleCreateMenuItem(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ownerID := middleware.UserIDFromCtx(r.Context())
		if ownerID == "" {
			writeError(w, http.StatusUnauthorized, "unauthorized")
			return
		}
		businessID := chi.URLParam(r, "id")

		var req MenuItemReq
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeError(w, http.StatusBadRequest, "invalid request body")
			return
		}

		item, err := svc.CreateMenuItem(r.Context(), businessID, req)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to create menu item")
			return
		}
		writeJSON(w, http.StatusCreated, item)
	}
}

func handleUpdateMenuItem(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ownerID := middleware.UserIDFromCtx(r.Context())
		if ownerID == "" {
			writeError(w, http.StatusUnauthorized, "unauthorized")
			return
		}
		businessID := chi.URLParam(r, "id")
		itemID := chi.URLParam(r, "itemId")

		var req MenuItemReq
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeError(w, http.StatusBadRequest, "invalid request body")
			return
		}

		item, err := svc.UpdateMenuItem(r.Context(), businessID, itemID, req)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to update menu item")
			return
		}
		writeJSON(w, http.StatusOK, item)
	}
}

func handleDeleteMenuItem(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ownerID := middleware.UserIDFromCtx(r.Context())
		if ownerID == "" {
			writeError(w, http.StatusUnauthorized, "unauthorized")
			return
		}
		businessID := chi.URLParam(r, "id")
		itemID := chi.URLParam(r, "itemId")

		if err := svc.DeleteMenuItem(r.Context(), businessID, itemID); err != nil {
			writeError(w, http.StatusNotFound, "menu item not found")
			return
		}
		writeJSON(w, http.StatusOK, map[string]string{"message": "deleted"})
	}
}

func handleRequestVerification(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ownerID := middleware.UserIDFromCtx(r.Context())
		if ownerID == "" {
			writeError(w, http.StatusUnauthorized, "unauthorized")
			return
		}
		businessID := chi.URLParam(r, "id")

		if err := svc.RequestVerification(r.Context(), businessID, ownerID); err != nil {
			writeError(w, http.StatusBadRequest, err.Error())
			return
		}
		writeJSON(w, http.StatusOK, map[string]string{"message": "verification requested"})
	}
}

func handleCreateBoost(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ownerID := middleware.UserIDFromCtx(r.Context())
		businessID := chi.URLParam(r, "id")

		var req BoostReq
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeError(w, http.StatusBadRequest, "invalid request body")
			return
		}

		if err := svc.CreateBoost(r.Context(), businessID, ownerID, req); err != nil {
			writeError(w, http.StatusInternalServerError, "failed to create boost")
			return
		}

		writeJSON(w, http.StatusCreated, map[string]string{"message": "boost created"})
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
