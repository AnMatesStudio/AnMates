package services

import (
	"context"
	"math"
	"strings"
)

// NearbyVenue is the normalized venue shape returned to the Flutter client. JSON
// keys mirror what OsmPlace.fromBackend reads, so the UI model is unchanged across
// providers (TomTom, Goong). Fields a given provider can't supply stay empty.
type NearbyVenue struct {
	ID           string  `json:"id"`
	Name         string  `json:"name"`
	Lat          float64 `json:"lat"`
	Lng          float64 `json:"lng"`
	Amenity      string  `json:"amenity"`
	Cuisine      string  `json:"cuisine,omitempty"`
	Address      string  `json:"address,omitempty"`
	Phone        string  `json:"phone,omitempty"`
	OpeningHours string  `json:"opening_hours,omitempty"`
	DistanceM    int     `json:"distance_m"`
}

// NearbyProvider abstracts a nearby-food-venue source so the /venues/nearby route
// can be backed by either TomTom or Goong, chosen by env (MAP_PROVIDER). An
// unconfigured implementation reports Enabled()==false, letting main.go leave the
// route off so the Flutter client falls back to Overpass.
type NearbyProvider interface {
	Enabled() bool
	Name() string
	Nearby(ctx context.Context, lat, lng float64, radiusM, limit int) ([]NearbyVenue, error)
}

// NewNearbyProvider picks the provider named by `provider` (case/space-insensitive):
// "goong" or "tomtom". When empty it auto-selects whichever key is configured,
// preferring Goong. It always returns a non-nil provider; an unconfigured one
// reports Enabled()==false so the caller leaves the route off.
func NewNearbyProvider(provider, goongKey, tomtomKey string) NearbyProvider {
	goong := NewGoongClient(goongKey)
	tomtom := NewTomTomClient(tomtomKey)
	switch strings.ToLower(strings.TrimSpace(provider)) {
	case "goong":
		return goong
	case "tomtom":
		return tomtom
	default: // auto: prefer whichever key is configured, Goong first
		if goong.Enabled() {
			return goong
		}
		if tomtom.Enabled() {
			return tomtom
		}
		return goong // disabled, but non-nil → route stays off
	}
}

// haversineMeters returns the great-circle distance in metres between two
// lat/lng points. Used to rank/filter venues whose coordinates come from a
// provider that doesn't return a distance of its own (Goong).
func haversineMeters(lat1, lng1, lat2, lng2 float64) float64 {
	const r = 6371000.0
	dLat := (lat2 - lat1) * math.Pi / 180
	dLng := (lng2 - lng1) * math.Pi / 180
	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(lat1*math.Pi/180)*math.Cos(lat2*math.Pi/180)*
			math.Sin(dLng/2)*math.Sin(dLng/2)
	return 2 * r * math.Asin(math.Sqrt(a))
}
