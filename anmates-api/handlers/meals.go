package handlers

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/anmates/api/internal/httputil"
	"github.com/anmates/api/middleware"
	"github.com/anmates/api/services"
	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
)

type Meals struct{ svc services.MealServicer }

func NewMeals(svc services.MealServicer) *Meals { return &Meals{svc: svc} }

type rateReq struct {
	Stars int    `json:"stars"`
	Note  string `json:"note"`
}

// SubmitRating handles POST /matches/:id/rating
func (m *Meals) SubmitRating(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	id, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid match id")
	}
	var r rateReq
	if err := c.BodyParser(&r); err != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid body")
	}
	if r.Stars < 1 || r.Stars > 5 {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "stars must be 1..5")
	}
	r.Note = strings.TrimSpace(r.Note)
	if len([]rune(r.Note)) > 500 {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "note too long (max 500)")
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	if err := m.svc.SubmitRating(ctx, id, uid, r.Stars, r.Note); err != nil {
		if errors.Is(err, services.ErrNotFound) {
			return httputil.Err(c, fiber.StatusNotFound, httputil.ErrMatchNotFound, "match not found")
		}
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "rating failed")
	}
	return httputil.OK(c, fiber.Map{"saved": true})
}

// GetRating handles GET /matches/:id/rating
func (m *Meals) GetRating(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	id, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid match id")
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	view, err := m.svc.GetRating(ctx, id, uid)
	if err != nil {
		if errors.Is(err, services.ErrNotFound) {
			return httputil.Err(c, fiber.StatusNotFound, httputil.ErrMatchNotFound, "match not found")
		}
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "query failed")
	}
	return httputil.OK(c, view)
}

// Stats handles GET /profile/stats
func (m *Meals) Stats(c *fiber.Ctx) error {
	uid := middleware.UserID(c)

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	st, err := m.svc.Stats(ctx, uid)
	if err != nil {
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "query failed")
	}
	return httputil.OK(c, st)
}
