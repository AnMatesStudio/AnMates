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
)

// enrichTimeout bounds the Foursquare match + website og:image crawl.
const enrichTimeout = 15 * time.Second

// VenueEnrich returns Foursquare-sourced photos for the detail screen.
//
// Only the identity-grounded Foursquare path is used: GPS+name match →
// official website → og:image. Agentic Playwright crawl and Bing web search
// have been removed — both could not be controlled for image quality.
// Returns EnrichResult with images when a website was found, or an empty
// result so the Flutter client shows the emoji placeholder (graceful degrade).
type VenueEnrich struct {
	resolver *services.VenuePhotoResolver
}

func NewVenueEnrich(resolver *services.VenuePhotoResolver) *VenueEnrich {
	return &VenueEnrich{resolver: resolver}
}

// Serve handles GET /api/v1/venues/enrich?q=<name>&lat=<lat>&lng=<lng>.
func (h *VenueEnrich) Serve(c *fiber.Ctx) error {
	name := strings.TrimSpace(c.Query("q"))
	if utf8.RuneCountInString(name) < 2 {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "query too short")
	}

	lat, _ := strconv.ParseFloat(strings.TrimSpace(c.Query("lat")), 64)
	lng, _ := strconv.ParseFloat(strings.TrimSpace(c.Query("lng")), 64)

	ctx, cancel := context.WithTimeout(c.UserContext(), enrichTimeout)
	defer cancel()

	urls := h.resolver.Resolve(ctx, name, lat, lng)
	images := make([]services.EnrichedImage, 0, len(urls))
	for _, u := range urls {
		images = append(images, services.EnrichedImage{URL: u})
	}
	return httputil.OK(c, services.EnrichResult{
		Images:      images,
		IsFoodVenue: len(images) > 0,
	})
}
