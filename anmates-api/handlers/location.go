package handlers

import (
	"context"
	"time"

	"github.com/anmates/api/internal/httputil"
	"github.com/anmates/api/middleware"
	"github.com/anmates/api/services"
	"github.com/gofiber/fiber/v2"
)

type Location struct {
	svc *services.LocationService
}

func NewLocation(svc *services.LocationService) *Location { return &Location{svc: svc} }

type locationUpdateReq struct {
	Lat      *float64 `json:"lat"`
	Lng      *float64 `json:"lng"`
	District string   `json:"district"`
}

// Update upserts the caller's last-known location (PUT /api/v1/me/location).
func (h *Location) Update(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	var r locationUpdateReq
	if err := c.BodyParser(&r); err != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid body")
	}
	if r.Lat == nil || r.Lng == nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "lat/lng required")
	}
	if *r.Lat < -90 || *r.Lat > 90 || *r.Lng < -180 || *r.Lng > 180 {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "lat/lng out of range")
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), 10*time.Second)
	defer cancel()

	if err := h.svc.Upsert(ctx, uid, *r.Lat, *r.Lng, r.District); err != nil {
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "save failed")
	}
	return httputil.OK(c, fiber.Map{"ok": true})
}
