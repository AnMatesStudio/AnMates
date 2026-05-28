package config

import (
	"fmt"
	"os"
	"strconv"
	"time"
)

type Config struct {
	DatabaseURL           string
	JWTSecret             []byte
	JWTAccessExpire       time.Duration
	JWTRefreshExpire      time.Duration
	Port                  string
	Env                   string
	FirebaseWebAPIKey     string
	FirebaseVerifyTimeout time.Duration
	DevMode               bool
	DevBypassSecret       string
	PGMaxConns            int32
	PGMinConns            int32
	CORSOrigins           string
	RedisURL              string // optional; when set the WebSocket hub uses Redis pub/sub
}

func Load() (*Config, error) {
	c := &Config{
		DatabaseURL:       os.Getenv("DATABASE_URL"),
		JWTSecret:         []byte(os.Getenv("JWT_SECRET")),
		Port:              getOr("PORT", "8080"),
		Env:               getOr("ENV", "production"),
		FirebaseWebAPIKey: os.Getenv("FIREBASE_WEB_API_KEY"),
		DevMode:           os.Getenv("DEV_MODE") == "true" || os.Getenv("DEV_MODE") == "1",
		DevBypassSecret:   os.Getenv("DEV_BYPASS_SECRET"),
		CORSOrigins:       getOr("CORS_ORIGINS", "*"),
	}
	if c.DatabaseURL == "" {
		return nil, fmt.Errorf("DATABASE_URL is required")
	}
	if len(c.JWTSecret) < 32 {
		return nil, fmt.Errorf("JWT_SECRET must be at least 32 bytes (got %d)", len(c.JWTSecret))
	}

	access, err := time.ParseDuration(getOr("JWT_ACCESS_EXPIRE", "15m"))
	if err != nil {
		return nil, fmt.Errorf("JWT_ACCESS_EXPIRE: %w", err)
	}
	c.JWTAccessExpire = access

	refresh, err := time.ParseDuration(getOr("JWT_REFRESH_EXPIRE", "168h"))
	if err != nil {
		return nil, fmt.Errorf("JWT_REFRESH_EXPIRE: %w", err)
	}
	c.JWTRefreshExpire = refresh

	fbTimeout, err := time.ParseDuration(getOr("FIREBASE_VERIFY_TIMEOUT", "5s"))
	if err != nil {
		return nil, fmt.Errorf("FIREBASE_VERIFY_TIMEOUT: %w", err)
	}
	c.FirebaseVerifyTimeout = fbTimeout

	// 4 max / 1 min is right for a 1-vCPU instance — 1 CPU runs one goroutine
	// at a time, excess connections only waste Postgres RAM. Raise PG_MAX_CONNS
	// when scaling to more CPUs (rule of thumb: 4 × vCPU count).
	c.PGMaxConns = int32(parseInt32(getOr("PG_MAX_CONNS", "4")))
	c.PGMinConns = int32(parseInt32(getOr("PG_MIN_CONNS", "1")))
	c.RedisURL = os.Getenv("REDIS_URL")

	return c, nil
}

func getOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func parseInt32(s string) int {
	v, err := strconv.Atoi(s)
	if err != nil || v < 1 {
		return 1
	}
	return v
}
