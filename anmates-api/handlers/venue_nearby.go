package handlers

import (
	"context"
	"strconv"
	"time"

	"github.com/anmates/api/internal/httputil"
	"github.com/anmates/api/middleware"
	"github.com/anmates/api/models"
	"github.com/anmates/api/services"
	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
)

const (
	nearbyTimeout       = 8 * time.Second
	nearbyDefaultRadius = 5000
	nearbyMaxRadius     = 50000
)

// ProfileLookup is the slice of the user service VenueNearby needs to personalize
// the venue keywords from the caller's onboarding tags.
type ProfileLookup interface {
	GetProfile(ctx context.Context, userID uuid.UUID) (*models.User, error)
}

// VenueNearby serves fresher-than-OSM nearby food venues via a pluggable provider
// (TomTom or Goong, chosen by env MAP_PROVIDER), so the API key stays server-side.
// Registered only when the selected provider is enabled; the Flutter client falls
// back to Overpass when this route is absent or errors. When a profile lookup is
// available it derives personalized search keywords from the caller's onboarding
// food/vibe/culture tags (Goong uses them; TomTom ignores them).
type VenueNearby struct {
	provider services.NearbyProvider
	profiles ProfileLookup
}

func NewVenueNearby(provider services.NearbyProvider, profiles ProfileLookup) *VenueNearby {
	return &VenueNearby{provider: provider, profiles: profiles}
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

	keywords := h.personalKeywords(ctx, c)

	venues, err := h.provider.Nearby(ctx, lat, lng, radius, limit, keywords)
	if err != nil {
		// Let the client degrade to its Overpass fallback.
		return httputil.Err(c, fiber.StatusBadGateway, httputil.ErrInternal, "nearby lookup failed")
	}
	return httputil.OK(c, fiber.Map{"venues": venues})
}

// personalKeywords maps the authenticated user's onboarding food/vibe/culture tags
// to Goong search keywords. Best-effort: any miss (no profile lookup, no user, DB
// error, or no tags) returns nil so the provider falls back to its default set.
func (h *VenueNearby) personalKeywords(ctx context.Context, c *fiber.Ctx) []string {
	if h.profiles == nil {
		return nil
	}
	uid := middleware.UserID(c)
	if uid == uuid.Nil {
		return nil
	}
	user, err := h.profiles.GetProfile(ctx, uid)
	if err != nil || user == nil {
		return nil
	}
	return services.FoodKeywordsFromOnboarding(user.FoodTags, user.VibeTags, user.CultureTags)
}
