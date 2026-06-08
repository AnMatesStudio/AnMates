package handlers

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/anmates/api/internal/httputil"
	"github.com/anmates/api/middleware"
	"github.com/anmates/api/models"
	"github.com/anmates/api/services"
	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
)

type Booking struct {
	svc services.BookingServicer
}

func NewBooking(svc services.BookingServicer) *Booking { return &Booking{svc: svc} }

type proposeBookingReq struct {
	RestaurantName    string   `json:"restaurant_name"`
	RestaurantAddress string   `json:"restaurant_address"`
	Lat               *float64 `json:"lat"`
	Lng               *float64 `json:"lng"`
	ScheduledAt       string   `json:"scheduled_at"` // RFC3339
}

// matchID parses + validates the :id path param.
func (b *Booking) matchID(c *fiber.Ctx) (uuid.UUID, error) {
	return uuid.Parse(c.Params("id"))
}

// mapErr turns a service error into the right HTTP response. Returns nil if err is nil.
func mapBookingErr(c *fiber.Ctx, err error) error {
	switch {
	case err == nil:
		return nil
	case errors.Is(err, services.ErrNotMember):
		return httputil.Err(c, fiber.StatusNotFound, httputil.ErrMatchNotFound, "match not found")
	case errors.Is(err, services.ErrNoBooking):
		return httputil.Err(c, fiber.StatusNotFound, httputil.ErrNotFound, "no active booking")
	case errors.Is(err, services.ErrConfirmOwn):
		return httputil.Err(c, fiber.StatusConflict, httputil.ErrConflict, "đợi mate xác nhận giúm nha")
	case errors.Is(err, services.ErrPastSchedule):
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "giờ hẹn phải ở tương lai")
	case errors.Is(err, services.ErrNoVenue):
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "thiếu tên quán")
	default:
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "booking failed")
	}
}

// Propose handles POST /matches/:id/booking.
func (b *Booking) Propose(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	matchID, err := b.matchID(c)
	if err != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid match id")
	}
	var r proposeBookingReq
	if err := c.BodyParser(&r); err != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid body")
	}
	when, perr := time.Parse(time.RFC3339, strings.TrimSpace(r.ScheduledAt))
	if perr != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "scheduled_at must be RFC3339")
	}
	name := strings.TrimSpace(r.RestaurantName)
	if len(name) > 200 {
		name = name[:200]
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	bk, err := b.svc.Propose(ctx, matchID, uid, services.ProposeInput{
		RestaurantName:    name,
		RestaurantAddress: strings.TrimSpace(r.RestaurantAddress),
		Lat:               r.Lat,
		Lng:               r.Lng,
		ScheduledAt:       when,
	})
	if err != nil {
		return mapBookingErr(c, err)
	}
	return c.Status(fiber.StatusCreated).JSON(httputil.SuccessEnvelope{Success: true, Data: bk})
}

// Get handles GET /matches/:id/booking.
func (b *Booking) Get(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	matchID, err := b.matchID(c)
	if err != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid match id")
	}
	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	bk, err := b.svc.Get(ctx, matchID, uid)
	if err != nil {
		return mapBookingErr(c, err)
	}
	return httputil.OK(c, bk)
}

// Confirm handles POST /matches/:id/booking/confirm.
func (b *Booking) Confirm(c *fiber.Ctx) error { return b.act(c, b.svc.Confirm) }

// Cancel handles POST /matches/:id/booking/cancel.
func (b *Booking) Cancel(c *fiber.Ctx) error { return b.act(c, b.svc.Cancel) }

// act runs a no-body member action (confirm/cancel) and renders the result.
func (b *Booking) act(c *fiber.Ctx, fn func(context.Context, uuid.UUID, uuid.UUID) (*models.Booking, error)) error {
	uid := middleware.UserID(c)
	matchID, err := b.matchID(c)
	if err != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid match id")
	}
	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	bk, err := fn(ctx, matchID, uid)
	if err != nil {
		return mapBookingErr(c, err)
	}
	return httputil.OK(c, bk)
}
