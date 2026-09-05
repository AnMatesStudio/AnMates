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
	catalogTimeout      = 5 * time.Second
	catalogDefaultLimit = 60
	catalogMaxLimit     = 200
)

// VenueCatalog serves the app's own venue table: GET /api/v1/venues.
//
// This is the DB-backed source for the discovery feed and the search box
// (via ?q=). All venue data lives in the restaurants table — no external
// search service exists anymore.
type VenueCatalog struct {
	engine *services.VenueEngine
}

func NewVenueCatalog(engine *services.VenueEngine) *VenueCatalog {
	return &VenueCatalog{engine: engine}
}

func (h *VenueCatalog) List(c *fiber.Ctx) error {
	lat, _ := strconv.ParseFloat(c.Query("lat", "0"), 64)
	lng, _ := strconv.ParseFloat(c.Query("lng", "0"), 64)

	radiusM := 0
	if r, err := strconv.Atoi(c.Query("radius_m", "")); err == nil && r > 0 {
		radiusM = r
	}

	limit := catalogDefaultLimit
	if l, err := strconv.Atoi(c.Query("limit", "")); err == nil && l > 0 {
		limit = min(l, catalogMaxLimit)
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), catalogTimeout)
	defer cancel()

	venues, err := h.engine.ListVenues(ctx, services.CatalogQuery{
		Center:  services.LatLng{Lat: lat, Lng: lng},
		RadiusM: radiusM,
		Cuisine: c.Query("cuisine", ""),
		Query:   c.Query("q", ""),
		Limit:   limit,
	})
	if err != nil {
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "venue listing failed")
	}

	return httputil.OK(c, fiber.Map{"venues": venues, "count": len(venues)})
}
