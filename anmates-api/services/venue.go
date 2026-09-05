package services

import (
	"context"
	"math"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// LatLng is a WGS84 coordinate.
type LatLng struct {
	Lat float64 `json:"lat"`
	Lng float64 `json:"lng"`
}

// Candidate is a restaurant row enriched with its distance from a reference point.
// Venue fields come straight from the DB — the LLM only ever selects by ID, never
// authors these values (see docs/specs anti-hallucination rule).
type Candidate struct {
	ID        uuid.UUID `json:"restaurant_id"`
	Name      string    `json:"name"`
	Lat       float64   `json:"lat"`
	Lng       float64   `json:"lng"`
	Cuisine   []string  `json:"cuisine_tags"`
	PriceMin  *int      `json:"price_min,omitempty"`
	PriceMax  *int      `json:"price_max,omitempty"`
	Rating    *float64  `json:"rating,omitempty"`
	DistanceM int       `json:"distance_m"`
}

// VenueEngine does geo math + candidate search over the restaurants table.
type VenueEngine struct {
	pool *pgxpool.Pool
}

func NewVenueEngine(pool *pgxpool.Pool) *VenueEngine { return &VenueEngine{pool: pool} }

const earthRadiusM = 6371000.0

// HaversineM returns the great-circle distance in metres between two coordinates.
func HaversineM(a, b LatLng) float64 {
	lat1 := a.Lat * math.Pi / 180
	lat2 := b.Lat * math.Pi / 180
	dLat := (b.Lat - a.Lat) * math.Pi / 180
	dLng := (b.Lng - a.Lng) * math.Pi / 180
	h := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(lat1)*math.Cos(lat2)*math.Sin(dLng/2)*math.Sin(dLng/2)
	return 2 * earthRadiusM * math.Asin(math.Min(1, math.Sqrt(h)))
}

// Midpoint returns the average of two coordinates. For intra-city distances the
// simple mean is within metres of the true geographic midpoint — adequate for the
// MVP slice.
func Midpoint(a, b LatLng) LatLng {
	return LatLng{Lat: (a.Lat + b.Lat) / 2, Lng: (a.Lng + b.Lng) / 2}
}

// SearchCandidates returns active venues within radiusM of mid whose price band
// overlaps [budgetMin, budgetMax], nearest first, capped at limit.
func (e *VenueEngine) SearchCandidates(ctx context.Context, mid LatLng, budgetMin, budgetMax, radiusM, limit int) ([]Candidate, error) {
	// Bounding-box prefilter (cheap, index-friendly), exact Haversine filter in Go.
	dLat := float64(radiusM) / 111320.0
	cosLat := math.Cos(mid.Lat * math.Pi / 180)
	if cosLat < 0.01 {
		cosLat = 0.01
	}
	dLng := float64(radiusM) / (111320.0 * cosLat)

	rows, err := e.pool.Query(ctx, `
		SELECT id, name, lat, lng, cuisine_tags, price_min, price_max, rating
		FROM restaurants
		WHERE status = 'active'
		  AND lat BETWEEN $1 AND $2
		  AND lng BETWEEN $3 AND $4
		  AND (price_min IS NULL OR price_min <= $6)
		  AND (price_max IS NULL OR price_max >= $5)
	`, mid.Lat-dLat, mid.Lat+dLat, mid.Lng-dLng, mid.Lng+dLng, budgetMin, budgetMax)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]Candidate, 0, 32)
	for rows.Next() {
		var c Candidate
		if err := rows.Scan(&c.ID, &c.Name, &c.Lat, &c.Lng, &c.Cuisine, &c.PriceMin, &c.PriceMax, &c.Rating); err != nil {
			return nil, err
		}
		d := HaversineM(mid, LatLng{Lat: c.Lat, Lng: c.Lng})
		if d > float64(radiusM) {
			continue
		}
		c.DistanceM = int(d)
		out = append(out, c)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	// Nearest first.
	sortCandidatesByDistance(out)
	if limit > 0 && len(out) > limit {
		out = out[:limit]
	}
	return out, nil
}

func sortCandidatesByDistance(cs []Candidate) {
	for i := 1; i < len(cs); i++ {
		for j := i; j > 0 && cs[j].DistanceM < cs[j-1].DistanceM; j-- {
			cs[j], cs[j-1] = cs[j-1], cs[j]
		}
	}
}
