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

type MealDay struct{ svc *services.MealDayService }

func NewMealDay(svc *services.MealDayService) *MealDay { return &MealDay{svc: svc} }

type mealStatusReq struct {
	Status string `json:"status"`
}

// SetStatus handles POST /matches/:id/booking/status — the member's day-of
// status (on_my_way, running_late_10/20, arrived) for the confirmed meal.
func (h *MealDay) SetStatus(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	id, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid match id")
	}
	var r mealStatusReq
	if err := c.BodyParser(&r); err != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid body")
	}
	if _, ok := services.MealStatuses[r.Status]; !ok {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid status")
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	if err := h.svc.SetStatus(ctx, id, uid, r.Status); err != nil {
		if errors.Is(err, services.ErrNotFound) {
			return httputil.Err(c, fiber.StatusNotFound, httputil.ErrMatchNotFound, "match not found")
		}
		if errors.Is(err, services.ErrNotNow) {
			return httputil.Err(c, fiber.StatusConflict, httputil.ErrConflict, "no confirmed meal around now")
		}
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "status failed")
	}
	return httputil.OK(c, fiber.Map{"status": r.Status})
}

// Status handles GET /matches/:id/booking/status — the day-of status of both
// members (mine + partner) for the latest confirmed booking.
func (h *MealDay) Status(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	id, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid match id")
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	view, err := h.svc.Status(ctx, id, uid)
	if err != nil {
		if errors.Is(err, services.ErrNotFound) {
			return httputil.Err(c, fiber.StatusNotFound, httputil.ErrMatchNotFound, "match not found")
		}
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "query failed")
	}
	return httputil.OK(c, view)
}

// Icebreakers handles GET /matches/:id/icebreakers — shared food interests of
// the two members plus 3 deterministic conversation prompts.
func (h *MealDay) Icebreakers(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	id, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid match id")
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	set, err := h.svc.Icebreakers(ctx, id, uid)
	if err != nil {
		if errors.Is(err, services.ErrNotFound) {
			return httputil.Err(c, fiber.StatusNotFound, httputil.ErrMatchNotFound, "match not found")
		}
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "query failed")
	}
	return httputil.OK(c, set)
}
