package auth

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
)

func Routes(svc *Service) http.Handler {
	r := chi.NewRouter()
	r.Post("/send-otp", handleSendOTP(svc))
	r.Post("/verify-otp", handleVerifyOTP(svc))
	r.Post("/refresh", handleRefresh(svc))
	r.Post("/logout", handleLogout(svc))
	r.Post("/dev-login", handleDevLogin(svc))
	return r
}

type sendOTPReq struct {
	Phone string `json:"phone"`
}

func handleSendOTP(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req sendOTPReq
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Phone == "" {
			writeError(w, http.StatusBadRequest, "phone number required")
			return
		}

		code, err := svc.SendOTP(r.Context(), req.Phone)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to send otp")
			return
		}

		resp := map[string]any{
			"message": "OTP sent",
			"phone":   req.Phone,
		}
		// Expose code in non-production environments so devs can test without SMS
		if svc.cfg.Env != "production" {
			resp["dev_code"] = code
		}
		writeJSON(w, http.StatusOK, resp)
	}
}

type verifyOTPReq struct {
	Phone string `json:"phone"`
	Code  string `json:"code"`
}

func handleVerifyOTP(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req verifyOTPReq
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeError(w, http.StatusBadRequest, "invalid request")
			return
		}

		userID, isNew, err := svc.VerifyOTP(r.Context(), req.Phone, req.Code)
		if err != nil {
			writeError(w, http.StatusUnauthorized, "invalid or expired OTP")
			return
		}

		access, refresh, err := svc.IssueTokens(r.Context(), userID, "member")
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to issue tokens")
			return
		}

		writeJSON(w, http.StatusOK, map[string]any{
			"access_token":  access,
			"refresh_token": refresh,
			"user_id":       userID,
			"is_new_user":   isNew,
		})
	}
}

type refreshReq struct {
	RefreshToken string `json:"refresh_token"`
}

func handleRefresh(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req refreshReq
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeError(w, http.StatusBadRequest, "invalid request")
			return
		}

		access, err := svc.RefreshAccess(r.Context(), req.RefreshToken)
		if err != nil {
			writeError(w, http.StatusUnauthorized, "invalid refresh token")
			return
		}

		writeJSON(w, http.StatusOK, map[string]any{"access_token": access})
	}
}

func handleLogout(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// Extract userID from token (best-effort, no auth middleware here)
		var req struct {
			UserID string `json:"user_id"`
		}
		json.NewDecoder(r.Body).Decode(&req)

		if req.UserID != "" {
			svc.Logout(r.Context(), req.UserID)
		}

		writeJSON(w, http.StatusOK, map[string]any{"message": "logged out"})
	}
}

func handleDevLogin(svc *Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if svc.cfg.Env == "production" {
			writeError(w, http.StatusForbidden, "not available in production")
			return
		}
		var req struct {
			Phone string `json:"phone"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Phone == "" {
			req.Phone = "+256000000000"
		}

		userID, _, err := svc.DevLogin(r.Context(), req.Phone)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "dev login failed")
			return
		}

		access, refresh, err := svc.IssueTokens(r.Context(), userID, "member")
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to issue tokens")
			return
		}

		writeJSON(w, http.StatusOK, map[string]any{
			"access_token":  access,
			"refresh_token": refresh,
			"user_id":       userID,
			"is_new_user":   false,
		})
	}
}

// helpers

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}
