package handlers

import (
	"context"
	"time"

	"github.com/anmates/api/internal/httputil"
	"github.com/anmates/api/middleware"
	"github.com/anmates/api/services"
	"github.com/gofiber/fiber/v2"
)

// Bots serves the demo chat bots: one call gives the caller a conversation
// with each of them, so the inbox can be tried without a second real account.
type Bots struct {
	bots  *services.BotService
	match services.MatchingServicer
}

func NewBots(bots *services.BotService, match services.MatchingServicer) *Bots {
	return &Bots{bots: bots, match: match}
}

// Start matches the caller with every bot (idempotent) and returns the inbox.
func (b *Bots) Start(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()
	if err := b.bots.Start(ctx, uid); err != nil {
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "start bots failed")
	}
	convs, err := b.match.Conversations(ctx, uid)
	if err != nil {
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "query failed")
	}
	return httputil.OK(c, convs)
}
