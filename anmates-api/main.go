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
	app.Use(cors.New(cors.Config{
		AllowOrigins: cfg.CORSOrigins,
		AllowMethods: "GET,POST,PUT,DELETE,OPTIONS",
		AllowHeaders: "Content-Type,Authorization",
	}))
	app.Use(middleware.RequestLogger(log))

	rl := middleware.NewRateLimit(0.5, 5)
	rateLimitOff := os.Getenv("DISABLE_RATE_LIMIT") == "1" || os.Getenv("DISABLE_RATE_LIMIT") == "true"
	if rateLimitOff {
		log.Warn("DISABLE_RATE_LIMIT set — rate limiter is OFF")
	}
	rlHandler := func(c *fiber.Ctx) error { return c.Next() }
	if !rateLimitOff {
		rlHandler = rl.Handler()
	}

	fbClient := &http.Client{Timeout: cfg.FirebaseVerifyTimeout}
	authSvc := services.NewAuthService(pool, cfg.JWTSecret, cfg.JWTAccessExpire, cfg.JWTRefreshExpire, cfg.FirebaseWebAPIKey, fbClient)
	userSvc := services.NewUserService(pool)
	wlSvc := services.NewWishlistService(pool)
	matchSvc := services.NewMatchingService(pool)
	chatSvc := services.NewChatService(pool)
	noiSvc := services.NewNoiLauService(pool)

	authH := handlers.NewAuth(authSvc, cfg.DevBypassSecret)
	userH := handlers.NewUser(userSvc)
	wlH := handlers.NewWishlist(wlSvc)
	matchH := handlers.NewMatching(matchSvc)
	chatH := handlers.NewChat(chatSvc, hub)
	noiH := handlers.NewNoiLau(noiSvc)
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
	api.Post("/auth/refresh", authH.Refresh)
	api.Post("/auth/logout", authH.Logout)
	if cfg.DevMode {
		api.Post("/auth/dev-login", authH.DevLogin)
		log.Warn("DEV_MODE on — /api/v1/auth/dev-login is open (requires DEV_BYPASS_SECRET)")
	}

	// Authenticated.
	auth := api.Use(jwtMW)
	auth.Get("/profile", userH.GetProfile)
	auth.Put("/profile", userH.UpdateProfile)

	auth.Get("/wishlist", wlH.List)
	auth.Post("/wishlist", wlH.Create)
	auth.Delete("/wishlist/:id", wlH.Delete)

	auth.Get("/matches", matchH.List)
	auth.Post("/matches/:id/accept", matchH.Accept)
	auth.Get("/conversations", matchH.Conversations)
	auth.Get("/matches/:id/messages", chatH.History)
	auth.Get("/matches/:id/progress", noiH.Get)

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
