package auth

import (
	"context"
	"crypto/rand"
	"fmt"
	"math/big"
	"net/http"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
	"golang.org/x/crypto/bcrypt"

	"github.com/hapa-world/hapa/pkg/cache"
	"github.com/hapa-world/hapa/pkg/config"
)

type Service struct {
	db     *pgxpool.Pool
	cache  *redis.Client
	cfg    *config.Config
}

func NewService(db *pgxpool.Pool, cache *redis.Client, cfg *config.Config) *Service {
	return &Service{db: db, cache: cache, cfg: cfg}
}

// SendOTP generates and sends a one-time password. Returns the code so callers
// can include it in dev-mode responses. In production it's sent via SMS only.
func (s *Service) SendOTP(ctx context.Context, phone string) (string, error) {
	code, err := generateOTP()
	if err != nil {
		return "", fmt.Errorf("generate otp: %w", err)
	}

	_, err = s.db.Exec(ctx, `
		INSERT INTO otp_verifications (phone, code, expires_at)
		VALUES ($1, $2, $3)
	`, phone, code, time.Now().Add(time.Duration(s.cfg.OTPExpirySecs)*time.Second))
	if err != nil {
		return "", fmt.Errorf("store otp: %w", err)
	}

	if s.cfg.ATUsername != "" && s.cfg.ATAPIKey != "" {
		if err := s.sendSMSViaAT(phone, fmt.Sprintf("Your Hapa code is: %s", code)); err != nil {
			fmt.Printf("[WARN] SMS failed for %s: %v\n", phone, err)
		}
	} else {
		fmt.Printf("[DEV] OTP for %s: %s\n", phone, code)
	}

	return code, nil
}

func (s *Service) sendSMSViaAT(phone, message string) error {
	data := fmt.Sprintf("username=%s&to=%s&message=%s&from=Hapa",
		s.cfg.ATUsername, phone, message)
	req, err := http.NewRequest("POST",
		"https://api.africastalking.com/version1/messaging",
		strings.NewReader(data))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("apiKey", s.cfg.ATAPIKey)
	req.Header.Set("Accept", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 400 {
		return fmt.Errorf("AT API returned %d", resp.StatusCode)
	}
	return nil
}

// VerifyOTP confirms the OTP and returns (userID, isNewUser, error)
func (s *Service) VerifyOTP(ctx context.Context, phone, code string) (string, bool, error) {
	var otpID string
	err := s.db.QueryRow(ctx, `
		UPDATE otp_verifications
		SET used = TRUE
		WHERE phone = $1 AND code = $2 AND expires_at > NOW() AND used = FALSE
		RETURNING id
	`, phone, code).Scan(&otpID)
	if err != nil {
		return "", false, fmt.Errorf("invalid or expired otp")
	}

	// Check if user exists
	var userID string
	isNew := false
	err = s.db.QueryRow(ctx, `
		SELECT id FROM users WHERE phone = $1
	`, phone).Scan(&userID)
	if err != nil {
		// Create new user
		err = s.db.QueryRow(ctx, `
			INSERT INTO users (phone) VALUES ($1) RETURNING id
		`, phone).Scan(&userID)
		if err != nil {
			return "", false, fmt.Errorf("create user: %w", err)
		}
		isNew = true
	}

	return userID, isNew, nil
}

// DevLogin creates or fetches a user for the given phone without OTP verification.
// Only intended for non-production environments.
func (s *Service) DevLogin(ctx context.Context, phone string) (userID string, isNew bool, err error) {
	err = s.db.QueryRow(ctx, `SELECT id FROM users WHERE phone = $1`, phone).Scan(&userID)
	if err != nil {
		err = s.db.QueryRow(ctx, `INSERT INTO users (phone) VALUES ($1) RETURNING id`, phone).Scan(&userID)
		if err != nil {
			return "", false, fmt.Errorf("dev login: create user: %w", err)
		}
		isNew = true
	}
	return userID, isNew, nil
}

// IssueTokens generates an access + refresh token pair
func (s *Service) IssueTokens(ctx context.Context, userID, userType string) (accessToken, refreshToken string, err error) {
	now := time.Now()

	claims := jwt.MapClaims{
		"user_id":   userID,
		"user_type": userType,
		"iat":       now.Unix(),
		"exp":       now.Add(15 * time.Minute).Unix(),
	}

	access, err := jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString([]byte(s.cfg.JWTSecret))
	if err != nil {
		return "", "", fmt.Errorf("sign access token: %w", err)
	}

	refreshClaims := jwt.MapClaims{
		"user_id": userID,
		"type":    "refresh",
		"iat":     now.Unix(),
		"exp":     now.Add(30 * 24 * time.Hour).Unix(),
	}

	refresh, err := jwt.NewWithClaims(jwt.SigningMethodHS256, refreshClaims).SignedString([]byte(s.cfg.JWTSecret))
	if err != nil {
		return "", "", fmt.Errorf("sign refresh token: %w", err)
	}

	// Store refresh token in Redis
	key := cache.UserSessionKey(userID)
	if err := s.cache.Set(ctx, key, refresh, 30*24*time.Hour).Err(); err != nil {
		return "", "", fmt.Errorf("cache refresh token: %w", err)
	}

	return access, refresh, nil
}

// RefreshAccess validates a refresh token and returns a new access token
func (s *Service) RefreshAccess(ctx context.Context, refreshToken string) (string, error) {
	claims := jwt.MapClaims{}
	parsed, err := jwt.ParseWithClaims(refreshToken, claims, func(t *jwt.Token) (any, error) {
		return []byte(s.cfg.JWTSecret), nil
	})
	if err != nil || !parsed.Valid {
		return "", fmt.Errorf("invalid refresh token")
	}

	userID, ok := claims["user_id"].(string)
	if !ok {
		return "", fmt.Errorf("invalid claims")
	}

	// Validate against Redis
	stored, err := s.cache.Get(ctx, cache.UserSessionKey(userID)).Result()
	if err != nil || stored != refreshToken {
		return "", fmt.Errorf("refresh token revoked")
	}

	newClaims := jwt.MapClaims{
		"user_id": userID,
		"iat":     time.Now().Unix(),
		"exp":     time.Now().Add(15 * time.Minute).Unix(),
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, newClaims).SignedString([]byte(s.cfg.JWTSecret))
}

// Logout revokes the refresh token
func (s *Service) Logout(ctx context.Context, userID string) error {
	return s.cache.Del(ctx, cache.UserSessionKey(userID)).Err()
}

func generateOTP() (string, error) {
	n, err := rand.Int(rand.Reader, big.NewInt(1000000))
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%06d", n.Int64()), nil
}

// hashPassword returns a bcrypt hash (used for optional email+password auth)
func hashPassword(password string) (string, error) {
	b, err := bcrypt.GenerateFromPassword([]byte(password), 12)
	return string(b), err
}

func checkPassword(hash, password string) bool {
	return bcrypt.CompareHashAndPassword([]byte(hash), []byte(password)) == nil
}
