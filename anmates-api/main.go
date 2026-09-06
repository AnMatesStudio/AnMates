package main

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"runtime"
	"strconv"
	"strings"
	"syscall"
	"time"

	"github.com/anmates/api/config"
	"github.com/anmates/api/db"
	"github.com/anmates/api/handlers"
	"github.com/anmates/api/internal/httputil"
	"github.com/anmates/api/middleware"
	"github.com/anmates/api/services"
	"github.com/anmates/api/ws"
	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/recover"
	"github.com/google/uuid"
)

func main() {
	// Apply GOMAXPROCS from env — Go runtime does not read this automatically.
	// Dockerfile sets GOMAXPROCS=1 for a 1-vCPU Cloud Run instance; override
	// the env var when scaling to more CPUs.
	if s := os.Getenv("GOMAXPROCS"); s != "" {
		if n, err := strconv.Atoi(s); err == nil && n > 0 {
			runtime.GOMAXPROCS(n)
		}
	}

	log := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: logLevel()}))
	slog.SetDefault(log)
	if err := run(log); err != nil {
		log.Error("fatal", "err", err)
		os.Exit(1)
	}
}

func run(log *slog.Logger) error {
	cfg, err := config.Load()
	if err != nil {
		return fmt.Errorf("config: %w", err)
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	pool, err := db.NewPool(ctx, cfg.DatabaseURL, cfg.PGMaxConns, cfg.PGMinConns)
	if err != nil {
		return fmt.Errorf("db pool: %w", err)
	}
	defer pool.Close()

	if err := db.Migrate(ctx, pool); err != nil {
		return fmt.Errorf("migrate: %w", err)
	}
	log.Info("migrations applied")

	// To enable Redis-backed hub for multi-instance deployments:
	// 1. Run: go get github.com/redis/go-redis/v9
	// 2. Remove the build tags from ws/redis_hub.go
	// 3. Replace the line below with: hub, _ := ws.NewRedisHub(cfg.RedisURL)
	hub := ws.NewHub()
	if cfg.RedisURL != "" {
		log.Warn("REDIS_URL set but RedisHub not yet activated — remove build:ignore tag in ws/redis_hub.go to enable")
	}

	app := fiber.New(fiber.Config{
		AppName:               "anmates-api",
		DisableStartupMessage: true,
		ReadTimeout:           15 * time.Second,
		WriteTimeout:          15 * time.Second,
		IdleTimeout:           60 * time.Second,
		BodyLimit:             4 * 1024 * 1024,
		ErrorHandler: func(c *fiber.Ctx, err error) error {
			code := fiber.StatusInternalServerError
			if fe, ok := err.(*fiber.Error); ok {
				code = fe.Code
			}
			return httputil.Err(c, code, httputil.ErrInternal, err.Error())
		},
	})

	app.Use(recover.New())
	// Đặt sau recover.New(): panic được recover thành 500 rồi mới ghi vào
	// http_requests_total, thay vì làm rơi luôn phép đo. Đặt trước cors/logger
	// để bao trọn thời gian xử lý request.
	middleware.Metrics(app, "anmates-api")
	app.Use(cors.New(cors.Config{
		AllowOrigins: cfg.CORSOrigins,
		AllowMethods: "GET,POST,PUT,PATCH,DELETE,OPTIONS",
		AllowHeaders: "Content-Type,Authorization",
	}))
	app.Use(middleware.RequestLogger(log))

	rl := middleware.NewRateLimit(0.5, 5)
	rateLimitOff := os.Getenv("DISABLE_RATE_LIMIT") == "1" || os.Getenv("DISABLE_RATE_LIMIT") == "true"
	if rateLimitOff {
		log.Warn("DISABLE_RATE_LIMIT set — rate limiter is OFF")
	}
	rlHandler := rl.Handler()
	if rateLimitOff {
		rlHandler = func(c *fiber.Ctx) error { return c.Next() }
	}

	fbClient := &http.Client{Timeout: cfg.FirebaseVerifyTimeout}
	authSvc := services.NewAuthService(pool, cfg.JWTSecret, cfg.JWTAccessExpire, cfg.JWTRefreshExpire, cfg.FirebaseWebAPIKey, fbClient)

	// Email OTP (passwordless login alongside phone OTP). Real SMTP when
	// configured; a log-only sender in DEV_MODE so local flows work without
	// credentials; otherwise left disabled (routes not registered).
	var emailSender services.EmailSender
	switch {
	case cfg.SMTPHost != "" && cfg.SMTPUsername != "":
		emailSender = services.NewSMTPSender(cfg.SMTPHost, cfg.SMTPPort, cfg.SMTPUsername, cfg.SMTPPassword, cfg.SMTPFrom, cfg.SMTPFromName)
		log.Info("Email OTP enabled (SMTP)", "host", cfg.SMTPHost, "from", cfg.SMTPFrom)
	case cfg.DevMode:
		emailSender = services.NewLogSender(log)
		log.Warn("Email OTP enabled with LOG sender (DEV_MODE, no SMTP) — codes are written to logs, not emailed")
	default:
		log.Info("Email OTP disabled (set SMTP_HOST + SMTP_USERNAME to enable)")
	}
	if emailSender != nil {
		authSvc.SetEmailOTP(emailSender, services.EmailOTPOptions{
			Expire:         cfg.EmailOTPExpire,
			ResendCooldown: cfg.EmailOTPResendCooldown,
			MaxAttempts:    cfg.EmailOTPMaxAttempts,
		})
	}
	userSvc := services.NewUserService(pool)
	wlSvc := services.NewWishlistService(pool)
	matchSvc := services.NewMatchingService(pool)
	chatSvc := services.NewChatService(pool)
	noiSvc := services.NewNoiLauService(pool)
	locSvc := services.NewLocationService(pool)
	bookingSvc := services.NewBookingService(pool)

	// One engine over the `restaurants` table, shared by the venue catalogue,
	// the free-text /venues/search route and (optionally) the concierge.
	venueEngine := services.NewVenueEngine(pool)

	// AI Concierge — venue source: local `restaurants` table (services.VenueEngine)
	// ranked by an OpenAI-compatible model. AI_BASE_URL set ⇒ enabled;
	// empty ⇒ disabled ⇒ nil seam ⇒ chat behaves exactly as before.
	var concierge handlers.ConciergeFirer
	var conciergeSvc *services.ConciergeService
	if cfg.AIBaseURL != "" {
		aiUserID, perr := uuid.Parse(cfg.AIUserID)
		if perr != nil {
			return fmt.Errorf("AI_USER_ID invalid uuid: %w", perr)
		}

		llm := services.NewOpenAICompatLLM(cfg.AIBaseURL, cfg.AIAPIKey, cfg.AIModel)
		provider := services.NewDBLLMVenueProvider(venueEngine, llm)

		conciergeSvc = services.NewConciergeService(pool, provider, hub,
			services.ConciergeConfig{
				AIUserID:       aiUserID,
				TriggerPoints:  cfg.AITriggerPoints,
				WarmPoints:     cfg.AIWarmPoints,
				CandidateLim:   cfg.AICandidateLimit,
				RadiusM:        cfg.AISearchRadiusM,
				MaxSeparationM: cfg.AIMaxSeparationM,
				BudgetMin:      cfg.AIBudgetMin,
				BudgetMax:      cfg.AIBudgetMax,
				Model:          cfg.AIModel,
			}, log)
		concierge = conciergeSvc
		log.Info("AI Concierge enabled", "mode", "db+llm", "base_url", cfg.AIBaseURL, "trigger_points", cfg.AITriggerPoints, "warm_points", cfg.AIWarmPoints)
	} else {
		log.Info("AI Concierge disabled (set AI_BASE_URL)")
	}

	authH := handlers.NewAuth(authSvc, cfg.DevBypassSecret)
	userH := handlers.NewUser(userSvc)
	wlH := handlers.NewWishlist(wlSvc)
	matchH := handlers.NewMatching(matchSvc)
	chatH := handlers.NewChat(chatSvc, hub, concierge)
	noiH := handlers.NewNoiLau(noiSvc)
	locH := handlers.NewLocation(locSvc)
	bookingH := handlers.NewBooking(bookingSvc)
	jwtMW := middleware.JWT(cfg.JWTSecret)

	app.Get("/health", func(c *fiber.Ctx) error {
		hCtx, hCancel := context.WithTimeout(c.UserContext(), 2*time.Second)
		defer hCancel()
		if err := pool.Ping(hCtx); err != nil {
			return httputil.Err(c, fiber.StatusServiceUnavailable, httputil.ErrInternal, "db down")
		}
		return httputil.OK(c, fiber.Map{"status": "ok"})
	})

	api := app.Group("/api/v1", rlHandler)

	// Auth (public).
	api.Post("/auth/register", authH.Register)
	api.Post("/auth/login", authH.Login)
	api.Post("/auth/phone-verify", authH.PhoneVerify)
	if authSvc.EmailOTPEnabled() {
		api.Post("/auth/email/request-otp", authH.RequestEmailOTP)
		api.Post("/auth/email/verify-otp", authH.VerifyEmailOTP)
		log.Info("email OTP routes registered: POST /api/v1/auth/email/request-otp + /verify-otp")
	}
	api.Post("/auth/refresh", authH.Refresh)
	api.Post("/auth/logout", authH.Logout)
	if cfg.DevMode {
		api.Post("/auth/dev-login", authH.DevLogin)
		log.Warn("DEV_MODE on — /api/v1/auth/dev-login is open (requires DEV_BYPASS_SECRET)")
	}

	// The app's own venue catalogue straight from the restaurants table:
	// GET /api/v1/venues?lat=&lng=&radius_m=&cuisine=&limit=
	// Always on (no external key) — it is the discovery feed's primary and ONLY
	// source. All venue data — including photos (venue_photos blobs served by
	// /venues/:id/photos/:position) — lives in the DB; nothing is fetched from
	// the internet.
	//
	// PUBLIC: browsing the catalogue
	// is what a visitor does before signing in, and the v2 Explore feed is the
	// first screen after onboarding — behind jwtMW it just renders empty. Nothing
	// here is user-scoped; want_count is an aggregate across all users. Registered
	// on the `api` group BEFORE api.Use(jwtMW) below, so it keeps the rate limiter
	// but not the auth requirement.
	venueCatalogH := handlers.NewVenueCatalog(venueEngine)
	api.Get("/venues", venueCatalogH.List)

	// Venue photo bytes, stored in Postgres (see db/migrations/014_venue_photo_
	// blobs.sql) instead of a URL — the data pipeline previously published bare
	// links to its own ngrok tunnel, and every one 404'd once the tunnel closed.
	// Public for the same <img src> reason as the catalogue above.
	venuePhotoH := handlers.NewVenuePhoto(services.NewVenuePhotoStore(pool))
	api.Get("/venues/:id/photos/:position", venuePhotoH.Serve)

	// Authenticated.
	auth := api.Use(jwtMW)
	auth.Get("/profile", userH.GetProfile)
	auth.Put("/profile", userH.UpdateProfile)
	auth.Patch("/profile/onboarding", userH.UpdateOnboarding)
	auth.Patch("/profile/preferences", userH.UpdatePreferences)
	auth.Patch("/profile/complete-onboarding", userH.CompleteOnboarding)

	auth.Put("/me/location", locH.Update)

	auth.Get("/wishlist", wlH.List)
	auth.Post("/wishlist", wlH.Create)
	auth.Delete("/wishlist/:id", wlH.Delete)

	auth.Get("/matches", matchH.List)
	auth.Post("/swipes", matchH.Swipe)
	auth.Post("/swipes/undo", matchH.Undo)
	auth.Get("/conversations", matchH.Conversations)
	auth.Get("/matches/:id/messages", chatH.History)
	auth.Get("/matches/:id/progress", noiH.Get)

	// First Date booking: one member proposes a venue+time, the other confirms.
	auth.Post("/matches/:id/booking", bookingH.Propose)
	auth.Get("/matches/:id/booking", bookingH.Get)
	auth.Post("/matches/:id/booking/confirm", bookingH.Confirm)
	auth.Post("/matches/:id/booking/cancel", bookingH.Cancel)

	// On-demand venue re-suggest with a chosen anchor (midpoint | me | mate).
	// Only when the concierge is enabled; returns a card without posting to chat.
	if conciergeSvc != nil {
		conciergeH := handlers.NewConcierge(chatSvc, conciergeSvc)
		auth.Post("/matches/:id/concierge/suggest", conciergeH.Suggest)
	}

	// Discovery free-text venue search: GET /api/v1/venues/search?q=...&lat=...&lng=...
	// Queries the local restaurants table directly (foldVN matching, geo filter,
	// CardPick response) — no external search service. Always on.
	venueH := handlers.NewVenue(venueEngine)
	auth.Get("/venues/search", venueH.Search)

	// WebSocket chat — auth + upgrade-required check, then the WS handler.
	app.Get("/ws/chat/:matchId", chatH.WSAuth(cfg.JWTSecret), chatH.WebSocket())

	// Graceful shutdown.
	go func() {
		sig := make(chan os.Signal, 1)
		signal.Notify(sig, syscall.SIGINT, syscall.SIGTERM)
		<-sig
		log.Info("shutdown signal received")
		hub.CloseAll()
		shutCtx, shutCancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer shutCancel()
		if err := app.ShutdownWithContext(shutCtx); err != nil {
			log.Error("shutdown", "err", err)
		}
		cancel()
	}()

	log.Info("listening", "port", cfg.Port)
	return app.Listen(":" + cfg.Port)
}

func logLevel() slog.Level {
	switch strings.ToLower(os.Getenv("LOG_LEVEL")) {
	case "debug":
		return slog.LevelDebug
	case "warn", "warning":
		return slog.LevelWarn
	case "error":
		return slog.LevelError
	default:
		return slog.LevelInfo
	}
}
