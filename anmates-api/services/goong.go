package services

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
)

// GoongClient builds the Discovery "nearby" list from Goong (goong.io) — a VN-legal
// alternative to Google Maps. Goong has NO "list around a point" endpoint, so we
// fan out a small set of food keywords through Place/AutoComplete (location-biased),
// then resolve each prediction's coordinates via Place/Detail. Goong returns no
// photos/cuisine/hours, so those fields stay empty and the venue images come from
// the existing image pipeline (driven by the accurate Goong name + address).
//
// It degrades to a zero value (Enabled()==false) when no key is set, letting the
// caller leave the route off so the client falls back to Overpass. Every failure
// path returns an error or empty list — it never panics or fabricates data.
type GoongClient struct {
	apiKey   string
	baseURL  string // "https://rsapi.goong.io"; overridable in tests
	keywords []string
	client   *http.Client
	ttl      time.Duration

	mu    sync.Mutex
	cache map[string]goongCacheEntry
}

type goongCacheEntry struct {
	venues  []NearbyVenue
	expires time.Time
}

const (
	goongBaseURL       = "https://rsapi.goong.io"
	goongTimeout       = 8 * time.Second
	goongDetailWorkers = 6  // bounded concurrency for the per-place Detail calls
	goongDefaultLimit  = 60 // total venues cap (only bounds the Detail-call fan-out)
	goongMaxRadiusKm   = 50 // Goong AutoComplete radius bias is in km (loose bias)
	goongHTTPReadCap   = 1 << 20
)

// goongDefaultKeywords cover restaurant/cafe/bar to mirror the Overpass
// amenity~restaurant|cafe|fast_food|bar filter. Override via GOONG_FOOD_KEYWORDS
// (comma-separated) after live tuning.
var goongDefaultKeywords = []string{"nhà hàng", "quán ăn", "quán cà phê", "quán nhậu", "lẩu nướng"}

func NewGoongClient(apiKey string) *GoongClient {
	keywords := goongDefaultKeywords
	if env := strings.TrimSpace(os.Getenv("GOONG_FOOD_KEYWORDS")); env != "" {
		parsed := make([]string, 0, 8)
		for _, p := range strings.Split(env, ",") {
			if p = strings.TrimSpace(p); p != "" {
				parsed = append(parsed, p)
			}
		}
		if len(parsed) > 0 {
			keywords = parsed
		}
	}

	ttl := 10 * time.Minute // bound API spend; venue lists are near-static
	if env := strings.TrimSpace(os.Getenv("GOONG_NEARBY_CACHE_TTL")); env != "" {
		if d, err := time.ParseDuration(env); err == nil && d >= 0 {
			ttl = d
		}
	}

	return &GoongClient{
		apiKey:   strings.TrimSpace(apiKey),
		baseURL:  goongBaseURL,
		keywords: keywords,
		client:   &http.Client{Timeout: goongTimeout},
		ttl:      ttl,
		cache:    make(map[string]goongCacheEntry),
	}
}

func (g *GoongClient) Enabled() bool { return g != nil && g.apiKey != "" }
func (g *GoongClient) Name() string  { return "goong" }

// Nearby returns up to `limit` food venues near (lat,lng), sorted nearest-first.
// radiusM only biases Goong's keyword AutoComplete (converted to km) — there is NO
// hard distance filter, so every venue Goong surfaces is returned (user choice:
// "all venues, no distance limit"). It returns an error only when no keyword query
// succeeded (network down); an empty-but-successful result (key set, genuinely no
// venues) yields an empty list so the client shows an honest empty state.
func (g *GoongClient) Nearby(ctx context.Context, lat, lng float64, radiusM, limit int, keywords []string) ([]NearbyVenue, error) {
	if !g.Enabled() {
		return nil, fmt.Errorf("goong disabled")
	}
	if limit <= 0 || limit > 200 {
		limit = goongDefaultLimit
	}
	// Personalized keywords (from the user's onboarding tags) take precedence;
	// fall back to the configured default set when none were supplied.
	kws := g.keywords
	if len(keywords) > 0 {
		kws = keywords
	}
	if v, ok := g.cached(lat, lng, radiusM, kws); ok {
		return v, nil
	}

	radiusKm := float64(radiusM) / 1000.0
	if radiusKm > goongMaxRadiusKm {
		radiusKm = goongMaxRadiusKm
	}
	if radiusKm <= 0 {
		radiusKm = 1
	}

	// 1) Fan out keywords through AutoComplete → ordered unique place ids. The
	//    keyword-derived amenity/name of the FIRST keyword that surfaced a place id
	//    is kept as a fallback (the V2 Detail `types` override it when present).
	order := make([]string, 0, limit)
	amenityByID := make(map[string]string)
	nameByID := make(map[string]string)
	anyOK := false
	for _, kw := range kws {
		preds, err := g.autocomplete(ctx, kw, lat, lng, radiusKm)
		if err != nil {
			continue // best-effort per keyword
		}
		anyOK = true
		for _, p := range preds {
			if p.PlaceID == "" {
				continue
			}
			if _, seen := amenityByID[p.PlaceID]; seen {
				continue
			}
			amenityByID[p.PlaceID] = goongAmenityForKeyword(kw)
			nameByID[p.PlaceID] = p.MainText
			order = append(order, p.PlaceID)
			if len(order) >= limit {
				break
			}
		}
		if len(order) >= limit {
			break
		}
	}
	if !anyOK {
		return nil, fmt.Errorf("goong: all autocomplete queries failed")
	}

	// 2) Resolve coordinates per place id (Detail) concurrently, drop out-of-radius.
	venues := make([]NearbyVenue, 0, len(order))
	var mu sync.Mutex
	sem := make(chan struct{}, goongDetailWorkers)
	var wg sync.WaitGroup
	for _, pid := range order {
		wg.Add(1)
		sem <- struct{}{}
		go func(pid string) {
			defer wg.Done()
			defer func() { <-sem }()
			d, err := g.detail(ctx, pid)
			if err != nil {
				return
			}
			if d.Lat == 0 && d.Lng == 0 {
				return // no usable coordinates
			}
			// Return ALL venues Goong surfaced — no distance filter (user choice).
			// Goong's keyword AutoComplete is only loosely location-biased, so the
			// distance is used purely to sort nearest-first, not to drop venues.
			dist := haversineMeters(lat, lng, d.Lat, d.Lng)
			name := strings.TrimSpace(d.Name)
			if name == "" {
				name = strings.TrimSpace(nameByID[pid])
			}
			if name == "" {
				return
			}
			// Prefer the V2 Detail category; fall back to the keyword's amenity.
			amenity := goongAmenityFromTypes(d.Types)
			if amenity == "" {
				amenity = amenityByID[pid]
			}
			v := NearbyVenue{
				ID:        "goong_" + pid,
				Name:      name,
				Lat:       d.Lat,
				Lng:       d.Lng,
				Amenity:   amenity,
				Address:   strings.TrimSpace(d.FormattedAddress),
				DistanceM: int(dist + 0.5),
			}
			mu.Lock()
			venues = append(venues, v)
			mu.Unlock()
		}(pid)
	}
	wg.Wait()

	sort.Slice(venues, func(i, j int) bool { return venues[i].DistanceM < venues[j].DistanceM })
	g.store(lat, lng, radiusM, kws, venues)
	return venues, nil
}

// --- Place search (map search bar) --------------------------------------------

const goongSearchBiasKm = 25 // city-scale bias toward the map center (loose)

// GoongPrediction is a single Place AutoComplete suggestion for the map search
// bar (a venue name OR an address — Goong handles both).
type GoongPrediction struct {
	PlaceID       string `json:"place_id"`
	Description   string `json:"description"`
	MainText      string `json:"main_text"`
	SecondaryText string `json:"secondary_text"`
}

// GoongPlace is a place resolved via Place Detail, with coordinates so the client
// can fly the map camera to it.
type GoongPlace struct {
	PlaceID string  `json:"place_id"`
	Name    string  `json:"name"`
	Address string  `json:"address"`
	Lat     float64 `json:"lat"`
	Lng     float64 `json:"lng"`
}

// Autocomplete returns Goong predictions for a free-text query, biased toward
// (lat,lng) when a non-zero anchor is given (the map center). Used by the map
// search bar to find a quán or address.
func (g *GoongClient) Autocomplete(ctx context.Context, query string, lat, lng float64) ([]GoongPrediction, error) {
	if !g.Enabled() {
		return nil, fmt.Errorf("goong disabled")
	}
	query = strings.TrimSpace(query)
	if query == "" {
		return nil, nil
	}
	radiusKm := 0.0
	if lat != 0 || lng != 0 {
		radiusKm = goongSearchBiasKm
	}
	preds, err := g.autocomplete(ctx, query, lat, lng, radiusKm)
	if err != nil {
		return nil, err
	}
	out := make([]GoongPrediction, 0, len(preds))
	for _, p := range preds {
		if p.PlaceID == "" {
			continue
		}
		out = append(out, GoongPrediction{
			PlaceID:       p.PlaceID,
			Description:   p.Description,
			MainText:      p.MainText,
			SecondaryText: p.SecondaryText,
		})
	}
	return out, nil
}

// PlaceDetail resolves a prediction's place_id to a place with coordinates.
func (g *GoongClient) PlaceDetail(ctx context.Context, placeID string) (GoongPlace, error) {
	if !g.Enabled() {
		return GoongPlace{}, fmt.Errorf("goong disabled")
	}
	if strings.TrimSpace(placeID) == "" {
		return GoongPlace{}, fmt.Errorf("place_id required")
	}
	d, err := g.detail(ctx, placeID)
	if err != nil {
		return GoongPlace{}, err
	}
	return GoongPlace{
		PlaceID: d.PlaceID,
		Name:    d.Name,
		Address: d.FormattedAddress,
		Lat:     d.Lat,
		Lng:     d.Lng,
	}, nil
}

// --- HTTP calls ---------------------------------------------------------------

func (g *GoongClient) autocomplete(ctx context.Context, keyword string, lat, lng, radiusKm float64) ([]goongPrediction, error) {
	q := url.Values{
		"api_key": {g.apiKey},
		"input":   {keyword},
	}
	// Location bias is optional: omit it when no anchor is known so a free-text
	// search (map search bar) isn't pinned to Null Island (0,0).
	if lat != 0 || lng != 0 {
		q.Set("location", fmt.Sprintf("%f,%f", lat, lng))
		if radiusKm > 0 {
			q.Set("radius", strconv.FormatFloat(radiusKm, 'f', 1, 64))
		}
	}
	body, err := g.get(ctx, "/v2/place/autocomplete", q)
	if err != nil {
		return nil, err
	}
	return parseGoongAutocomplete(body)
}

func (g *GoongClient) detail(ctx context.Context, placeID string) (goongDetail, error) {
	q := url.Values{"api_key": {g.apiKey}, "place_id": {placeID}}
	body, err := g.get(ctx, "/v2/place/detail", q)
	if err != nil {
		return goongDetail{}, err
	}
	return parseGoongDetail(body)
}

func (g *GoongClient) get(ctx context.Context, path string, q url.Values) ([]byte, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, g.baseURL+path+"?"+q.Encode(), http.NoBody)
	if err != nil {
		return nil, err
	}
	resp, err := g.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close() //nolint:errcheck // response body close; error unrecoverable
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("goong status %d", resp.StatusCode)
	}
	return io.ReadAll(io.LimitReader(resp.Body, goongHTTPReadCap))
}

// --- pure parsing (unit-tested) -----------------------------------------------

type goongPrediction struct {
	PlaceID       string
	MainText      string
	SecondaryText string
	Description   string
}

type goongDetail struct {
	PlaceID          string
	Name             string
	FormattedAddress string
	Lat              float64
	Lng              float64
	Types            []string // Goong V2 category hints, e.g. ["restaurant"]
}

func parseGoongAutocomplete(body []byte) ([]goongPrediction, error) {
	var raw struct {
		Predictions []struct {
			PlaceID              string `json:"place_id"`
			Description          string `json:"description"`
			StructuredFormatting struct {
				MainText      string `json:"main_text"`
				SecondaryText string `json:"secondary_text"`
			} `json:"structured_formatting"`
		} `json:"predictions"`
	}
	if err := json.Unmarshal(body, &raw); err != nil {
		return nil, err
	}
	out := make([]goongPrediction, 0, len(raw.Predictions))
	for _, p := range raw.Predictions {
		out = append(out, goongPrediction{
			PlaceID:       p.PlaceID,
			MainText:      p.StructuredFormatting.MainText,
			SecondaryText: p.StructuredFormatting.SecondaryText,
			Description:   p.Description,
		})
	}
	return out, nil
}

func parseGoongDetail(body []byte) (goongDetail, error) {
	var raw struct {
		Result struct {
			PlaceID          string `json:"place_id"`
			Name             string `json:"name"`
			FormattedAddress string `json:"formatted_address"`
			Types            []string `json:"types"`
			Geometry         struct {
				Location struct {
					Lat float64 `json:"lat"`
					Lng float64 `json:"lng"`
				} `json:"location"`
			} `json:"geometry"`
		} `json:"result"`
	}
	if err := json.Unmarshal(body, &raw); err != nil {
		return goongDetail{}, err
	}
	return goongDetail{
		PlaceID:          raw.Result.PlaceID,
		Name:             raw.Result.Name,
		FormattedAddress: raw.Result.FormattedAddress,
		Lat:              raw.Result.Geometry.Location.Lat,
		Lng:              raw.Result.Geometry.Location.Lng,
		Types:            raw.Result.Types,
	}, nil
}

// goongAmenityFromTypes maps Goong V2 Place `types` to the OSM amenity value the
// Flutter model understands. Returns "" when types are absent or non-food, so the
// caller can fall back to the keyword that surfaced the place.
func goongAmenityFromTypes(types []string) string {
	for _, ty := range types {
		switch strings.ToLower(strings.TrimSpace(ty)) {
		case "cafe", "coffee_shop":
			return "cafe"
		case "bar", "night_club", "pub":
			return "bar"
		case "meal_takeaway", "fast_food":
			return "fast_food"
		}
	}
	// A generic food type still means "restaurant"; check after the specific ones.
	for _, ty := range types {
		switch strings.ToLower(strings.TrimSpace(ty)) {
		case "restaurant", "food", "meal_delivery":
			return "restaurant"
		}
	}
	return ""
}

// goongAmenityForKeyword maps the food keyword that surfaced a place to the OSM
// amenity value the Flutter model understands (restaurant/cafe/bar).
func goongAmenityForKeyword(keyword string) string {
	k := strings.ToLower(keyword)
	switch {
	case containsAny(k, "cà phê", "ca phe", "cafe", "café", "coffee", "trà sữa", "tra sua", "trà", "tea"):
		return "cafe"
	case containsAny(k, "nhậu", "nhau", "bar", "bia", "beer", "pub", "lounge"):
		return "bar"
	default:
		return "restaurant"
	}
}

// --- cache --------------------------------------------------------------------

// cacheKey includes the effective keywords so per-user personalized lists never
// collide (user A's "lẩu dê" results must not be served to user B).
func (g *GoongClient) cacheKey(lat, lng float64, radiusM int, keywords []string) string {
	return fmt.Sprintf("%.3f,%.3f,%d|%s", lat, lng, radiusM, strings.Join(keywords, ","))
}

func (g *GoongClient) cached(lat, lng float64, radiusM int, keywords []string) ([]NearbyVenue, bool) {
	if g.ttl <= 0 {
		return nil, false
	}
	g.mu.Lock()
	defer g.mu.Unlock()
	e, ok := g.cache[g.cacheKey(lat, lng, radiusM, keywords)]
	if !ok || time.Now().After(e.expires) {
		return nil, false
	}
	return e.venues, true
}

func (g *GoongClient) store(lat, lng float64, radiusM int, keywords []string, venues []NearbyVenue) {
	// Never cache an empty result: a transient outage must not pin a location to
	// "no venues" — the next request re-resolves.
	if g.ttl <= 0 || len(venues) == 0 {
		return
	}
	g.mu.Lock()
	g.cache[g.cacheKey(lat, lng, radiusM, keywords)] = goongCacheEntry{venues: venues, expires: time.Now().Add(g.ttl)}
	g.mu.Unlock()
}
