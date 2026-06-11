package handlers

import (
	"context"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/anmates/api/internal/httputil"
	"github.com/anmates/api/services"
	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/log"
)

// enrichTimeout bounds the whole agentic crawl (headless Google + page fetches +
// LLM verdict). Generous, but capped so a hung crawl can't pin a request forever.
const enrichTimeout = 85 * time.Second

// VenueEnrich exposes the agentic realtime venue crawl to the detail screen.
//
// Like the image proxy it lives on the PUBLIC router (registered before the JWT
// catch-all): it returns only public web data and the Flutter client renders the
// photos through the image proxy, which can't carry a bearer token. It never
// errors out to the client — a blocked/empty crawl returns is_food_venue=false so
// the client falls back to the keyless Bing thumbnail and shows a placeholder.
type VenueEnrich struct {
	enricher *services.VenueEnricher
}

func NewVenueEnrich(enricher *services.VenueEnricher) *VenueEnrich {
	return &VenueEnrich{enricher: enricher}
}

// Serve handles GET /api/v1/venues/enrich?q=<name>&address=&city=&lat=&lng=.
func (h *VenueEnrich) Serve(c *fiber.Ctx) error {
	name := strings.TrimSpace(c.Query("q"))
	if utf8.RuneCountInString(name) < 2 {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "query too short")
	}

	// Disabled / not configured → empty payload (client keeps the Bing path).
	if h.enricher == nil || !h.enricher.Enabled() {
		return httputil.OK(c, services.EnrichResult{})
	}

	lat, _ := strconv.ParseFloat(strings.TrimSpace(c.Query("lat")), 64)
	lng, _ := strconv.ParseFloat(strings.TrimSpace(c.Query("lng")), 64)

	ctx, cancel := context.WithTimeout(c.UserContext(), enrichTimeout)
	defer cancel()

	res, err := h.enricher.Enrich(ctx, name, strings.TrimSpace(c.Query("address")),
		strings.TrimSpace(c.Query("city")), lat, lng, 6)
	if err != nil {
		// Degrade, never 5xx: the detail screen falls back to the Bing thumbnail.
		log.Warn("venue enrich failed", "venue", name, "err", err)
		return httputil.OK(c, services.EnrichResult{})
	}
	return httputil.OK(c, res)
}
