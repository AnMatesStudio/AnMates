package handlers

import (
	"context"
	"errors"
	"time"

	"github.com/anmates/api/internal/httputil"
	"github.com/anmates/api/middleware"
	"github.com/anmates/api/services"
	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
)

// ConciergeSuggester is the on-demand re-anchor seam (implemented by
// *services.ConciergeService). Lets a user re-run the venue suggestion centered on
// the midpoint, their own location, or their mate's — e.g. "A picks up B, eat near B".
type ConciergeSuggester interface {
	SuggestForUser(ctx context.Context, matchID, requesterID uuid.UUID, anchor string) (services.CardContent, error)
}

type Concierge struct {
	chat      services.ChatServicer
	suggester ConciergeSuggester
}

func NewConcierge(chat services.ChatServicer, suggester ConciergeSuggester) *Concierge {
	return &Concierge{chat: chat, suggester: suggester}
}

type suggestReq struct {
	Anchor string `json:"anchor"` // "midpoint" (default) | "me" | "mate"
}

// Suggest re-runs the venue suggestion for a chosen anchor and returns the card
// WITHOUT posting it to chat — a private per-user re-roll. The user shares a pick
// via a normal chat message when they decide.
func (h *Concierge) Suggest(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	matchID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid match id")
	}
	var body suggestReq
	if err := c.BodyParser(&body); err != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid body")
	}

	// Generous: the provider chains web-search + structuring + geocoding.
	ctx, cancel := context.WithTimeout(c.UserContext(), 80*time.Second)
	defer cancel()

	if !h.chat.IsMember(ctx, matchID, uid) {
		return httputil.Err(c, fiber.StatusNotFound, httputil.ErrMatchNotFound, "match not found")
	}

	content, err := h.suggester.SuggestForUser(ctx, matchID, uid, body.Anchor)
	if err != nil {
		switch {
		case errors.Is(err, services.ErrBadAnchor):
			return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "anchor must be midpoint, me, or mate")
		case errors.Is(err, services.ErrNoLocation):
			return httputil.Err(c, fiber.StatusConflict, httputil.ErrValidation, "location not available yet")
		default:
			return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "suggest failed")
		}
	}
	return httputil.OK(c, content)
}
