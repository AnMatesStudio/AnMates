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

	// AI Concierge (OpenAI-compatible LLM backend — LM Studio in dev, hosted in prod).
	// See docs/specs/ai-concierge-chat-spec.md. When AIBaseURL is empty the concierge
	// is disabled (no card is posted) — the rest of the app still runs.
	AIBaseURL        string
	AIAPIKey         string
	AIModel          string
	AIUserID         string // fixed system user id seeded in migration 008
	AITriggerPoints  int    // Vibe points that fire the concierge (default 70)
	AICandidateLimit int    // max venues passed to the model
	AISearchRadiusM  int    // search radius around the midpoint, metres
	AIBudgetMin      int    // default shared budget band (VND) until user prefs exist
	AIBudgetMax      int
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

	// AI Concierge. AIBaseURL empty ⇒ disabled.
	c.AIBaseURL = os.Getenv("AI_BASE_URL")
	c.AIAPIKey = os.Getenv("AI_API_KEY")
	c.AIModel = getOr("AI_MODEL", "qwen2.5-7b-instruct")
	c.AIUserID = getOr("AI_USER_ID", "00000000-0000-0000-0000-0000000000a1")
	c.AITriggerPoints = parseIntOr("AI_TRIGGER_POINTS", 70)
	c.AICandidateLimit = parseIntOr("AI_CANDIDATE_LIMIT", 12)
	c.AISearchRadiusM = parseIntOr("AI_SEARCH_RADIUS_M", 4000)
	c.AIBudgetMin = parseIntOr("AI_DEFAULT_BUDGET_MIN", 80000)
	c.AIBudgetMax = parseIntOr("AI_DEFAULT_BUDGET_MAX", 150000)

	return c, nil
}

// parseIntOr reads an int env var, falling back to def on missing/invalid.
func parseIntOr(key string, def int) int {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return def
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
