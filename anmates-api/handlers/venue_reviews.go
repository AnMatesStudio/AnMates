package handlers

import (
	"context"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/anmates/api/internal/httputil"
	"github.com/anmates/api/services"
	"github.com/gofiber/fiber/v2"
)

const reviewRequestTimeout = 10 * time.Second

// VenueReviews serves best-effort, keyless community review signal (rating +
// count + a few snippets) for a venue, scraped from Bing web results. JSON
// envelope; the Flutter detail screen merges it onto the venue card. Never hits
// Google Maps (prohibited in VN).
type VenueReviews struct {
	searcher *services.ReviewSearcher
}

func NewVenueReviews(searcher *services.ReviewSearcher) *VenueReviews {
	return &VenueReviews{searcher: searcher}
}

// Reviews handles GET /api/v1/venues/reviews?q=<name + address>.
func (h *VenueReviews) Reviews(c *fiber.Ctx) error {
	q := strings.TrimSpace(c.Query("q"))
	if utf8.RuneCountInString(q) < 2 {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "query too short")
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), reviewRequestTimeout)
	defer cancel()

	info := h.searcher.Resolve(ctx, q)
	return httputil.OK(c, info)
}
