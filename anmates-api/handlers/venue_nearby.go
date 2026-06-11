package handlers

import (
	"context"
	"strconv"
	"time"

	"github.com/anmates/api/internal/httputil"
	"github.com/anmates/api/services"
	"github.com/gofiber/fiber/v2"
)

const (
	nearbyTimeout       = 8 * time.Second
	nearbyDefaultRadius = 5000
	nearbyMaxRadius     = 50000
)

// VenueNearby serves fresher-than-OSM nearby food venues via the TomTom Search
// proxy, so the API key stays server-side. Registered only when TomTom is
// enabled; the Flutter client falls back to Overpass when this route is absent
// or errors.
type VenueNearby struct {
	tomtom *services.TomTomClient
}

func NewVenueNearby(tomtom *services.TomTomClient) *VenueNearby {
	return &VenueNearby{tomtom: tomtom}
}

// Serve handles GET /api/v1/venues/nearby?lat=&lng=&radius=&limit=
func (h *VenueNearby) Serve(c *fiber.Ctx) error {
	lat, err1 := strconv.ParseFloat(c.Query("lat"), 64)
	lng, err2 := strconv.ParseFloat(c.Query("lng"), 64)
	if err1 != nil || err2 != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "lat/lng required")
	}

	radius := nearbyDefaultRadius
	if v, err := strconv.Atoi(c.Query("radius")); err == nil && v > 0 {
		radius = v
	}
	if radius > nearbyMaxRadius {
		radius = nearbyMaxRadius
	}
	limit := 0 // 0 → client default cap
	if v, err := strconv.Atoi(c.Query("limit")); err == nil && v > 0 {
		limit = v
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), nearbyTimeout)
	defer cancel()

	venues, err := h.tomtom.Nearby(ctx, lat, lng, radius, limit)
	if err != nil {
		// Let the client degrade to its Overpass fallback.
		return httputil.Err(c, fiber.StatusBadGateway, httputil.ErrInternal, "nearby lookup failed")
	}
	return httputil.OK(c, fiber.Map{"venues": venues})
}
