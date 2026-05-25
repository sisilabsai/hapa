package cache

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
)

// Client wraps redis.Client for a cleaner interface
type Client interface {
	Ping(ctx context.Context) *redis.StatusCmd
	Close() error
	Get(ctx context.Context, key string) *redis.StringCmd
	Set(ctx context.Context, key string, value any, expiration time.Duration) *redis.StatusCmd
	Del(ctx context.Context, keys ...string) *redis.IntCmd
	Incr(ctx context.Context, key string) *redis.IntCmd
	Expire(ctx context.Context, key string, expiration time.Duration) *redis.BoolCmd
	ZAdd(ctx context.Context, key string, members ...redis.Z) *redis.IntCmd
	ZRange(ctx context.Context, key string, start, stop int64) *redis.StringSliceCmd
	HSet(ctx context.Context, key string, values ...any) *redis.IntCmd
	HGet(ctx context.Context, key, field string) *redis.StringCmd
	LPush(ctx context.Context, key string, values ...any) *redis.IntCmd
	LRange(ctx context.Context, key string, start, stop int64) *redis.StringSliceCmd
	SAdd(ctx context.Context, key string, members ...any) *redis.IntCmd
	SIsMember(ctx context.Context, key string, member any) *redis.BoolCmd
	Publish(ctx context.Context, channel string, message any) *redis.IntCmd
}

func Connect(redisURL string) *redis.Client {
	opts, err := redis.ParseURL(redisURL)
	if err != nil {
		// Fallback to default
		opts = &redis.Options{Addr: "localhost:6379"}
	}

	client := redis.NewClient(opts)
	return client
}

// Helpers for JSON-encoded cache values

func SetJSON(ctx context.Context, c Client, key string, value any, ttl time.Duration) error {
	b, err := json.Marshal(value)
	if err != nil {
		return fmt.Errorf("marshal: %w", err)
	}
	return c.Set(ctx, key, b, ttl).Err()
}

func GetJSON(ctx context.Context, c Client, key string, dest any) error {
	b, err := c.Get(ctx, key).Bytes()
	if err != nil {
		return err
	}
	return json.Unmarshal(b, dest)
}

// Key builders — consistent naming across services

func FeedKey(lat, lng float64) string {
	// GeoHash-level bucket — ~1.2km × 0.6km cells
	return fmt.Sprintf("feed:%.3f:%.3f", lat, lng)
}

func UserSessionKey(userID string) string {
	return fmt.Sprintf("session:%s", userID)
}

func UserCityKey(userID string) string {
	return fmt.Sprintf("user_city:%s", userID)
}

func CitySwitchPingKey(userID, city string) string {
	return fmt.Sprintf("city_ping:%s:%s", userID, city)
}

func BusinessKey(businessID string) string {
	return fmt.Sprintf("business:%s", businessID)
}

func PostCountKey(postID, countType string) string {
	return fmt.Sprintf("count:%s:%s", countType, postID)
}

func NotifQueueKey(userID string) string {
	return fmt.Sprintf("notif_queue:%s", userID)
}
