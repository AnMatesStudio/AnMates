package handlers

import (
	"context"
	"strconv"
	"strings"
	"time"

	"github.com/anmates/api/internal/httputil"
	"github.com/anmates/api/services"
	"github.com/gofiber/fiber/v2"
)

const placesSearchTimeout = 8 * time.Second

// PlacesSearch proxies Goong Place AutoComplete + Detail for the map search bar,
// keeping the server-side REST GOONG_API_KEY off the client (the client only
// holds the Maptiles key). Registered only when Goong has a key.
type PlacesSearch struct {
	goong *services.GoongClient
}

func NewPlacesSearch(goong *services.GoongClient) *PlacesSearch {
	return &PlacesSearch{goong: goong}
}

// Autocomplete handles GET /api/v1/places/autocomplete?q=&lat=&lng=
// Returns Goong predictions (venue names or addresses), biased toward lat/lng.
func (h *PlacesSearch) Autocomplete(c *fiber.Ctx) error {
	q := strings.TrimSpace(c.Query("q"))
	// Under 2 runes is noise — return an empty (successful) list, not an error.
	if len([]rune(q)) < 2 {
		return httputil.OK(c, fiber.Map{"predictions": []services.GoongPrediction{}})
	}
	lat, _ := strconv.ParseFloat(c.Query("lat"), 64)
	lng, _ := strconv.ParseFloat(c.Query("lng"), 64)

	ctx, cancel := context.WithTimeout(c.UserContext(), placesSearchTimeout)
	defer cancel()

	preds, err := h.goong.Autocomplete(ctx, q, lat, lng)
	if err != nil {
		return httputil.Err(c, fiber.StatusBadGateway, httputil.ErrInternal, "place search failed")
	}
	return httputil.OK(c, fiber.Map{"predictions": preds})
}

// Detail handles GET /api/v1/places/detail?place_id=
// Resolves a prediction to coordinates so the client can fly the map to it.
func (h *PlacesSearch) Detail(c *fiber.Ctx) error {
	pid := strings.TrimSpace(c.Query("place_id"))
	if pid == "" {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "place_id required")
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), placesSearchTimeout)
	defer cancel()

	place, err := h.goong.PlaceDetail(ctx, pid)
	if err != nil {
		return httputil.Err(c, fiber.StatusBadGateway, httputil.ErrInternal, "place detail failed")
	}
	return httputil.OK(c, fiber.Map{"place": place})
}
