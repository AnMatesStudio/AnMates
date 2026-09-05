package services

import (
	"context"
	"math"
	"sort"
	"strings"
	"unicode"

	"github.com/google/uuid"
	"golang.org/x/text/unicode/norm"
)

// CatalogVenue is a full `restaurants` row as served to the client by
// GET /api/v1/venues. Unlike Candidate (concierge-internal, trimmed for the LLM)
// this carries the presentation fields the discovery UI needs — address,
// district, photos — so the Flutter feed can render straight from the DB
// instead of a hardcoded table.
type CatalogVenue struct {
	ID        uuid.UUID `json:"id"`
	Name      string    `json:"name"`
	Address   *string   `json:"address,omitempty"`
	District  *string   `json:"district,omitempty"`
	Lat       float64   `json:"lat"`
	Lng       float64   `json:"lng"`
	Cuisine   []string  `json:"cuisine_tags"`
	PriceMin  *int      `json:"price_min,omitempty"`
	PriceMax  *int      `json:"price_max,omitempty"`
	Rating    *float64  `json:"rating,omitempty"`
	// PhotoCount is how many images this venue has in venue_photos (the actual
	// bytes, see db/migrations/014_venue_photo_blobs.sql) — never a URL. The
	// client builds gallery URLs itself as /api/v1/venues/{id}/photos/{i} for
	// i in [0, PhotoCount). restaurants.photos (a bare URL array) is not read
	// here: it recorded where an image came from, and every value it has ever
	// held pointed at the data pipeline's own ngrok tunnel, which is gone.
	PhotoCount int      `json:"photo_count"`
	Source     string   `json:"source"`
	DistanceM *int      `json:"distance_m,omitempty"`
	// WantCount is the number of distinct users whose wishlist holds a food
	// category matching one of this venue's cuisine tags — the only real
	// "demand" signal the schema carries (wishlists are category-scoped, not
	// venue-scoped). 0 means nobody has wished for this venue's food yet.
	WantCount int `json:"want_count"`
}

// CatalogQuery filters a venue listing. A zero Center means "no geo filter" —
// the whole active catalogue is returned, name-sorted, and DistanceM is nil.
type CatalogQuery struct {
	Center  LatLng
	RadiusM int
	Cuisine string
	// Query is free-text over name/address (e.g. the discovery search box).
	// Matched diacritic- and case-insensitively (foldVN), so "bun bo" finds
	// "Bún Bò Giáo Toàn" without the user typing Vietnamese tones.
	Query string
	Limit int
}

func (q CatalogQuery) hasCenter() bool { return q.Center.Lat != 0 || q.Center.Lng != 0 }

// ListVenues returns active venues from the restaurants table. When the query
// carries a centre it filters by radius (bounding-box prefilter + exact
// Haversine) and sorts nearest-first; otherwise it sorts by name so the feed is
// stable across reloads.
func (e *VenueEngine) ListVenues(ctx context.Context, q CatalogQuery) ([]CatalogVenue, error) {
	const cols = `r.id, r.name, r.address, r.district, r.lat, r.lng, r.cuisine_tags,
	              r.price_min, r.price_max, r.rating, r.source,
	              (SELECT count(DISTINCT w.user_id) FROM wishlists w
	                WHERE w.food_category = ANY(r.cuisine_tags)) AS want_count,
	              (SELECT count(*) FROM venue_photos p
	                WHERE p.restaurant_id = r.id) AS photo_count`

	var (
		sql  string
		args []any
	)
	if q.hasCenter() && q.RadiusM > 0 {
		dLat := float64(q.RadiusM) / 111320.0
		cosLat := math.Cos(q.Center.Lat * math.Pi / 180)
		if cosLat < 0.01 {
			cosLat = 0.01
		}
		dLng := float64(q.RadiusM) / (111320.0 * cosLat)
		sql = `SELECT ` + cols + ` FROM restaurants r
		       WHERE r.status = 'active'
		         AND r.lat BETWEEN $1 AND $2
		         AND r.lng BETWEEN $3 AND $4`
		args = []any{
			q.Center.Lat - dLat, q.Center.Lat + dLat,
			q.Center.Lng - dLng, q.Center.Lng + dLng,
		}
	} else {
		sql = `SELECT ` + cols + ` FROM restaurants r WHERE r.status = 'active'`
	}

	rows, err := e.pool.Query(ctx, sql, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	cuisine := strings.ToLower(strings.TrimSpace(q.Cuisine))
	query := foldVN(strings.TrimSpace(q.Query))
	out := make([]CatalogVenue, 0, 64)
	for rows.Next() {
		var v CatalogVenue
		if err := rows.Scan(&v.ID, &v.Name, &v.Address, &v.District, &v.Lat, &v.Lng,
			&v.Cuisine, &v.PriceMin, &v.PriceMax, &v.Rating, &v.Source,
			&v.WantCount, &v.PhotoCount); err != nil {
			return nil, err
		}
		if cuisine != "" && !hasCuisineTag(v.Cuisine, cuisine) {
			continue
		}
		if query != "" && !matchesQuery(v, query) {
			continue
		}
		if q.hasCenter() {
			d := int(HaversineM(q.Center, LatLng{Lat: v.Lat, Lng: v.Lng}))
			if q.RadiusM > 0 && d > q.RadiusM {
				continue
			}
			v.DistanceM = &d
		}
		out = append(out, v)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	if q.hasCenter() {
		sort.SliceStable(out, func(i, j int) bool { return *out[i].DistanceM < *out[j].DistanceM })
	} else {
		sort.SliceStable(out, func(i, j int) bool { return out[i].Name < out[j].Name })
	}
	if q.Limit > 0 && len(out) > q.Limit {
		out = out[:q.Limit]
	}
	return out, nil
}

func hasCuisineTag(tags []string, want string) bool {
	for _, t := range tags {
		if strings.EqualFold(strings.TrimSpace(t), want) {
			return true
		}
	}
	return false
}

// foldVN lowercases and strips Vietnamese diacritics (NFD-decompose, drop
// combining marks, fold đ/Đ to d) so "bun bo" matches "Bún Bò" — mirrors
// Data_Pipeline's own fold() in serving/sync_anmates.py, same reasoning: a
// user typing without tone marks should still find the venue.
func foldVN(s string) string {
	s = strings.ToLower(s)
	s = strings.ReplaceAll(s, "đ", "d")
	var b strings.Builder
	for _, r := range norm.NFD.String(s) {
		if unicode.Is(unicode.Mn, r) {
			continue
		}
		b.WriteRune(r)
	}
	return b.String()
}

// matchesQuery reports whether the venue's name or address contains the
// (already-folded) search query.
func matchesQuery(v CatalogVenue, foldedQuery string) bool {
	if strings.Contains(foldVN(v.Name), foldedQuery) {
		return true
	}
	if v.Address != nil && strings.Contains(foldVN(*v.Address), foldedQuery) {
		return true
	}
	return false
}

// SearchVenues is the free-text Discovery search backed entirely by the local
// `restaurants` table (GET /api/v1/venues/search). It reuses ListVenues —
// diacritic-insensitive foldVN matching over name/address, optional radius
// filter around `center` (zero center = no geo filter), nearest-first when
// centred, name-sorted otherwise — and projects rows onto CardPick, the JSON
// shape the concierge cards and the Flutter discovery client both consume.
// `reason` is generated from DB facts (cuisine tags); nothing is hallucinated.
func (e *VenueEngine) SearchVenues(ctx context.Context, query string, center LatLng, radiusM, limit int) ([]CardPick, error) {
	venues, err := e.ListVenues(ctx, CatalogQuery{
		Center:  center,
		RadiusM: radiusM,
		Query:   query,
		Limit:   limit,
	})
	if err != nil {
		return nil, err
	}
	picks := make([]CardPick, 0, len(venues))
	for _, v := range venues {
		var addr string
		if v.Address != nil {
			addr = clip(*v.Address, 160)
		}
		d := 0
		if v.DistanceM != nil {
			d = *v.DistanceM
		}
		picks = append(picks, CardPick{
			RestaurantID: v.ID.String(),
			Name:         clip(v.Name, 80),
			Address:      addr,
			Rating:       v.Rating,
			PriceMin:     v.PriceMin,
			PriceMax:     v.PriceMax,
			Lat:          v.Lat,
			Lng:          v.Lng,
			DistanceM:    d,
			Reason:       catalogReason(v),
		})
	}
	return picks, nil
}

// catalogReason builds a short user-facing line from DB facts only: cuisine
// tags when present, a generic catalogue note otherwise.
func catalogReason(v CatalogVenue) string {
	tags := make([]string, 0, len(v.Cuisine))
	for _, t := range v.Cuisine {
		if t = strings.TrimSpace(t); t != "" {
			tags = append(tags, t)
		}
	}
	if len(tags) == 0 {
		return "Có sẵn trong danh mục ĂnMates"
	}
	return clip("Phục vụ: "+strings.Join(tags, ", "), 80)
}
