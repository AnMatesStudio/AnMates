package handlers

import (
	"context"
	"time"

	"github.com/anmates/api/internal/httputil"
	"github.com/anmates/api/middleware"
	"github.com/anmates/api/services"
	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
)

type Matching struct {
	svc services.MatchingServicer
}

func NewMatching(svc services.MatchingServicer) *Matching { return &Matching{svc: svc} }

func (m *Matching) List(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	candidates, err := m.svc.ListCandidates(ctx, uid)
	if err != nil {
		return httputil.Err(c,fiber.StatusInternalServerError, httputil.ErrInternal, "query failed")
	}
	return httputil.OK(c,candidates)
}

type swipeReq struct {
	TargetID string `json:"target_id"`
	Liked    bool   `json:"liked"`
}

// Swipe records a like/pass on another user. On a reciprocated like it creates
// (or returns) the match — response: {matched: bool, match: Match|null}.
func (m *Matching) Swipe(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	var r swipeReq
	if err := c.BodyParser(&r); err != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid body")
	}
	target, err := uuid.Parse(r.TargetID)
	if err != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid target_id")
	}
	if target == uid {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "cannot swipe self")
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	res, err := m.svc.Swipe(ctx, uid, target, r.Liked)
	if err != nil {
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "swipe failed")
	}
	return httputil.OK(c, res)
}

// Undo removes the caller's most recent swipe (rewind).
func (m *Matching) Undo(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	if err := m.svc.Undo(ctx, uid); err != nil {
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "undo failed")
	}
	return httputil.OK(c, fiber.Map{"undone": true})
}

func (m *Matching) Conversations(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	convs, err := m.svc.Conversations(ctx, uid)
	if err != nil {
		return httputil.Err(c,fiber.StatusInternalServerError, httputil.ErrInternal, "query failed")
	}
	return httputil.OK(c,convs)
}
