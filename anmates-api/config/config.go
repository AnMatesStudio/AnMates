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

	// TomTom Search — fresher VN POI data than OSM/Overpass for the Discovery
	// "nearby" list. When TOMTOM_API_KEY is set the /venues/nearby proxy serves
	// TomTom results; otherwise the Flutter client falls back to Overpass.
	TomTomAPIKey string

	// Email OTP (passwordless login via emailed code). When SMTPHost+SMTPUsername
	// are set the email-OTP endpoints deliver real mail; otherwise the codes are
	// logged (dev only). Gmail: SMTP_HOST=smtp.gmail.com, SMTP_PORT=587,
	// SMTP_USERNAME=<you>@gmail.com, SMTP_PASSWORD=<16-char App Password>.
	SMTPHost              string
	SMTPPort              int
	SMTPUsername          string
	SMTPPassword          string
	SMTPFrom              string // From address; defaults to SMTPUsername
	SMTPFromName          string // optional display name (e.g. "ĂnMates")
	EmailOTPExpire        time.Duration
	EmailOTPResendCooldown time.Duration
	EmailOTPMaxAttempts   int

	// AI Concierge. Two interchangeable data sources select venues:
	//   AISearchURL set ⇒ web-search path (ai-venue-search Python service does
	//     MCP web-search + structuring; no DB/map ingest). Preferred.
	//   else AIBaseURL set ⇒ legacy DB+LLM path (restaurants table + OpenAI-compat
	//     model ranks by id). Kept as a fallback.
	// Both empty ⇒ concierge disabled (no card posted); the rest of the app runs.
	// See docs/specs/ai-concierge-chat-spec.md.
	AISearchURL      string // ai-venue-search service base URL (e.g. http://host.docker.internal:8090)
	AIBaseURL        string
	AIAPIKey         string
	AIModel          string
	AIUserID         string // fixed system user id seeded in migration 008
	AITriggerPoints  int    // Vibe points that fire the concierge (default 70)
	AIWarmPoints     int    // Vibe at which to PREFETCH+cache the card so the fire is instant (default trigger-10)
	AICandidateLimit int    // max venues passed to the model
	AISearchRadiusM  int    // search radius around the midpoint, metres
	AIMaxSeparationM int    // if the 2 users are farther apart than this, skip + warn (0 disables)
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
	c.TomTomAPIKey = os.Getenv("TOMTOM_API_KEY")

	// Email OTP.
	c.SMTPHost = os.Getenv("SMTP_HOST")
	c.SMTPPort = parseIntOr("SMTP_PORT", 587)
	c.SMTPUsername = os.Getenv("SMTP_USERNAME")
	c.SMTPPassword = os.Getenv("SMTP_PASSWORD")
	c.SMTPFrom = getOr("SMTP_FROM", c.SMTPUsername)
	c.SMTPFromName = getOr("SMTP_FROM_NAME", "ĂnMates")
	emailExp, err := time.ParseDuration(getOr("EMAIL_OTP_EXPIRE", "10m"))
	if err != nil {
		return nil, fmt.Errorf("EMAIL_OTP_EXPIRE: %w", err)
	}
	c.EmailOTPExpire = emailExp
	emailCooldown, err := time.ParseDuration(getOr("EMAIL_OTP_RESEND_COOLDOWN", "60s"))
	if err != nil {
		return nil, fmt.Errorf("EMAIL_OTP_RESEND_COOLDOWN: %w", err)
	}
	c.EmailOTPResendCooldown = emailCooldown
	c.EmailOTPMaxAttempts = parseIntOr("EMAIL_OTP_MAX_ATTEMPTS", 5)

	// AI Concierge. AISearchURL preferred; AIBaseURL is the legacy DB+LLM fallback.
	c.AISearchURL = os.Getenv("AI_SEARCH_URL")
	c.AIBaseURL = os.Getenv("AI_BASE_URL")
	c.AIAPIKey = os.Getenv("AI_API_KEY")
	c.AIModel = getOr("AI_MODEL", "qwen2.5-7b-instruct")
	c.AIUserID = getOr("AI_USER_ID", "00000000-0000-0000-0000-0000000000a1")
	c.AITriggerPoints = parseIntOr("AI_TRIGGER_POINTS", 70)
	// Pre-warm a few points before the trigger so the (slow) web-search runs in the
	// background and the card is cached, ready to post the instant Vibe hits the trigger.
	warmDefault := c.AITriggerPoints - 10
	if warmDefault < 1 {
		warmDefault = 1
	}
	c.AIWarmPoints = parseIntOr("AI_WARM_POINTS", warmDefault)
	c.AICandidateLimit = parseIntOr("AI_CANDIDATE_LIMIT", 12)
	c.AISearchRadiusM = parseIntOr("AI_SEARCH_RADIUS_M", 4000)
	// Beyond ~50 km apart (≈25 km each way) a "meet in the middle" meal is impractical
	// and the midpoint tends to land between cities → warn instead of suggesting.
	c.AIMaxSeparationM = parseIntOr("AI_MAX_SEPARATION_M", 50000)
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
