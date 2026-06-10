package handlers

import (
	"context"
	"math"
	"strconv"
	"strings"
	"sync"
	"time"
	"unicode/utf8"

	"github.com/anmates/api/internal/httputil"
	"github.com/anmates/api/services"
	"github.com/gofiber/fiber/v2"
)

const (
	venueCacheTTL  = 10 * time.Minute
	venueSearchTO  = 60 * time.Second
	defaultRadiusM = 4000
	defaultLimit   = 6
	maxLimit       = 10
)

type venueCacheEntry struct {
	picks   []services.CardPick
	expires time.Time
}

type nearbyCacheEntry struct {
	venues  []services.NearbyVenue
	expires time.Time
}

// Venue handler: GET /api/v1/venues/search and /api/v1/venues/nearby
type Venue struct {
	provider    *services.WebSearchProvider // nil ⇒ /venues/search disabled
	nearby      services.NearbyProvider     // always set
	mu          sync.Mutex
	cache       map[string]venueCacheEntry
	nearbyMu    sync.Mutex
	nearbyCache map[string]nearbyCacheEntry
}

func NewVenue(provider *services.WebSearchProvider, nearby services.NearbyProvider) *Venue {
	return &Venue{
		provider:    provider,
		nearby:      nearby,
		cache:       make(map[string]venueCacheEntry),
		nearbyCache: make(map[string]nearbyCacheEntry),
	}
}

// cacheKey combines query + rounded lat/lng so nearby requests share a result
// while different locations get distinct entries.
func venueCacheKey(q string, lat, lng float64) string {
	rLat := math.Round(lat*1000) / 1000
	rLng := math.Round(lng*1000) / 1000
	return strings.ToLower(q) + "|" + strconv.FormatFloat(rLat, 'f', 3, 64) + "|" + strconv.FormatFloat(rLng, 'f', 3, 64)
}

func (h *Venue) get(key string) ([]services.CardPick, bool) {
	h.mu.Lock()
	defer h.mu.Unlock()
	e, ok := h.cache[key]
	if !ok || time.Now().After(e.expires) {
		delete(h.cache, key)
		return nil, false
	}
	return e.picks, true
}

func (h *Venue) set(key string, picks []services.CardPick) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.cache[key] = venueCacheEntry{picks: picks, expires: time.Now().Add(venueCacheTTL)}
}

func (h *Venue) Search(c *fiber.Ctx) error {
	q := strings.TrimSpace(c.Query("q"))
	if utf8.RuneCountInString(q) < 2 {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "query too short")
	}

	lat, _ := strconv.ParseFloat(c.Query("lat", "0"), 64)
	lng, _ := strconv.ParseFloat(c.Query("lng", "0"), 64)

	radiusM := defaultRadiusM
	if rm, err := strconv.Atoi(c.Query("radius_m", "")); err == nil && rm > 0 {
		radiusM = rm
	}

	limit := defaultLimit
	if lim, err := strconv.Atoi(c.Query("limit", "")); err == nil && lim > 0 {
		if lim > maxLimit {
			lim = maxLimit
		}
		limit = lim
	}

	key := venueCacheKey(q, lat, lng)
	if picks, ok := h.get(key); ok {
		return httputil.OK(c, picks)
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), venueSearchTO)
	defer cancel()

	loc := services.LatLng{Lat: lat, Lng: lng}
	picks, err := h.provider.SearchText(ctx, q, loc, radiusM, limit)
	if err != nil {
		return httputil.Err(c, fiber.StatusBadGateway, httputil.ErrInternal, "search failed")
	}

	h.set(key, picks)
	return httputil.OK(c, picks)
}

func (h *Venue) getNearby(key string) ([]services.NearbyVenue, bool) {
	h.nearbyMu.Lock()
	defer h.nearbyMu.Unlock()
	e, ok := h.nearbyCache[key]
	if !ok || time.Now().After(e.expires) {
		delete(h.nearbyCache, key)
		return nil, false
	}
	return e.venues, true
}

func (h *Venue) setNearby(key string, venues []services.NearbyVenue) {
	h.nearbyMu.Lock()
	defer h.nearbyMu.Unlock()
	h.nearbyCache[key] = nearbyCacheEntry{venues: venues, expires: time.Now().Add(venueCacheTTL)}
}

// Nearby returns restaurants near the caller, nearest-first.
// GET /api/v1/venues/nearby?lat=&lng=&limit=
func (h *Venue) Nearby(c *fiber.Ctx) error {
	lat, err1 := strconv.ParseFloat(c.Query("lat", ""), 64)
	lng, err2 := strconv.ParseFloat(c.Query("lng", ""), 64)
	if err1 != nil || err2 != nil || (lat == 0 && lng == 0) {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "lat/lng required")
	}

	limit := defaultLimit
	if lim, err := strconv.Atoi(c.Query("limit", "")); err == nil && lim > 0 {
		if lim > maxLimit {
			lim = maxLimit
		}
		limit = lim
	}

	key := venueCacheKey("nearby", lat, lng)
	if v, ok := h.getNearby(key); ok {
		return httputil.OK(c, v)
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), venueSearchTO)
	defer cancel()

	venues, err := h.nearby.Nearby(ctx, services.LatLng{Lat: lat, Lng: lng}, limit)
	if err != nil {
		return httputil.Err(c, fiber.StatusBadGateway, httputil.ErrInternal, "nearby failed")
	}

	h.setNearby(key, venues)
	return httputil.OK(c, venues)
}
