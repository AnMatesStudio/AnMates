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

// Accept creates a match between the caller and the target user (:id = other user's id).
func (m *Matching) Accept(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	other, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return httputil.Err(c,fiber.StatusBadRequest, httputil.ErrValidation, "invalid user id")
	}
	if other == uid {
		return httputil.Err(c,fiber.StatusBadRequest, httputil.ErrValidation, "cannot match self")
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	match, err := m.svc.AcceptMatch(ctx, uid, other)
	if err != nil {
		return httputil.Err(c,fiber.StatusInternalServerError, httputil.ErrInternal, "accept match failed")
	}
	return c.Status(fiber.StatusCreated).JSON(httputil.SuccessEnvelope{Success: true, Data: match})
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
