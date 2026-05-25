package location

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"

	"github.com/hapa-world/hapa/pkg/middleware"
)

func Routes(svc *Service) http.Handler {
	r := chi.NewRouter()
	r.Post("/update", handleUpdateLocation(svc))
	r.Get("/city", handleNearestCity(svc))
	r.Get("/city/{name}", handleCityInfo(svc))
	r.Get("/cities", handleSearchCities(svc))
	return r
}

func handleUpdateLocation(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := middleware.UserIDFromCtx(r.Context())

		var update LocationUpdate
		if err := json.NewDecoder(r.Body).Decode(&update); err != nil {
			http.Error(w, `{"error":"invalid body"}`, http.StatusBadRequest)
			return
		}
		update.UserID = userID

		citySwitch, err := svc.UpdateLocation(r.Context(), update)
		if err != nil {
			http.Error(w, `{"error":"location update failed"}`, http.StatusInternalServerError)
			return
		}

		resp := map[string]any{"ok": true}
		if citySwitch != nil {
			resp["city_switch"] = citySwitch
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}
}

func handleNearestCity(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query()
		lat, _ := strconv.ParseFloat(q.Get("lat"), 64)
		lng, _ := strconv.ParseFloat(q.Get("lng"), 64)

		info, err := svc.NearestCity(r.Context(), lat, lng)
		if err != nil {
			http.Error(w, `{"error":"not found"}`, http.StatusNotFound)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(info)
	}
}

func handleSearchCities(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query().Get("q")
		cities, err := svc.SearchCities(r.Context(), q, 20)
		if err != nil {
			http.Error(w, `{"error":"search failed"}`, http.StatusInternalServerError)
			return
		}
		if cities == nil {
			cities = []CityInfo{}
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{"cities": cities})
	}
}

func handleCityInfo(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		name := chi.URLParam(r, "name")
		info, err := svc.GetCityInfo(r.Context(), name)
		if err != nil {
			http.Error(w, `{"error":"city not found"}`, http.StatusNotFound)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(info)
	}
}
