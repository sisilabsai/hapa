package config

import (
	"os"
	"strings"
)

type Config struct {
	Env            string
	Port           string
	DatabaseURL    string
	RedisURL       string
	MeiliURL       string
	MeiliMasterKey string
	JWTSecret      string
	ClaudeAPIKey   string
	DeepSeekAPIKey string
	MapboxToken    string
	FlutterwaveKey string
	PaystackKey    string
	AllowedOrigins []string
	OTPExpirySecs  int
	ATUsername     string
	ATAPIKey       string
}

func Load() *Config {
	defaultOrigins := "http://localhost:3000,http://localhost:8080"
	if getEnv("ENV", "development") == "development" {
		defaultOrigins = "*"
	}
	origins := strings.Split(getEnv("ALLOWED_ORIGINS", defaultOrigins), ",")

	return &Config{
		Env:            getEnv("ENV", "development"),
		Port:           getEnv("PORT", "8080"),
		DatabaseURL:    getEnv("DATABASE_URL", "postgres://hapa:hapa_secret@localhost:5432/hapa?sslmode=disable"),
		RedisURL:       getEnv("REDIS_URL", "redis://localhost:6379"),
		MeiliURL:       getEnv("MEILI_URL", "http://localhost:7700"),
		MeiliMasterKey: getEnv("MEILI_MASTER_KEY", "hapa_meili_master_key"),
		JWTSecret:      getEnv("JWT_SECRET", "hapa_jwt_secret_change_in_production"),
		ClaudeAPIKey:   getEnv("CLAUDE_API_KEY", ""),
		DeepSeekAPIKey: getEnv("DEEPSEEK_API_KEY", ""),
		MapboxToken:    getEnv("MAPBOX_TOKEN", ""),
		FlutterwaveKey: getEnv("FLUTTERWAVE_SECRET_KEY", ""),
		PaystackKey:    getEnv("PAYSTACK_SECRET_KEY", ""),
		AllowedOrigins: origins,
		OTPExpirySecs:  300,
		ATUsername:     getEnv("AT_USERNAME", ""),
		ATAPIKey:       getEnv("AT_API_KEY", ""),
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
