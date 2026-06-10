# Discover "HOT QUANH BẠN" via Google Places (New) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Màn Khám phá load quán ăn gần user nhất từ Google Places API (New), bán kính mở rộng dần kiểu Grab, qua Go backend proxy với cache + daily budget guard + fallback OSM.

**Architecture:** Flutter `DiscoverView` gọi `GET /api/v1/venues/nearby` (JWT). Backend có `NearbyProvider` interface với 2 impl: `GooglePlacesProvider` (mặc định khi có `GOOGLE_PLACES_API_KEY`, gọi `places:searchNearby`, mở rộng radius 3km→10km, budget guard 2400/ngày) và `OSMNearbyProvider` (fallback Overpass). Handler cache kết quả 10 phút theo ô vị trí.

**Tech Stack:** Go 1.25 + Fiber, `net/http` (stdlib, no new deps); Flutter (Dart) + `http`; Postgres không đụng tới; spec `docs/specs/2026-06-10-discover-nearby-google-places.md`.

**Defaults (từ spec, chỉnh được):** radius 3000m → 10000m, `minResults=5`, `limit=8`, `dailyBudget=2400` (guard ở 90%), ảnh Google **defer** (PhotoSlot placeholder), fallback OSM **ở Go**.

**Toolchain note (R-003):** chạy Go với `GO111MODULE=on`; build/test trong Docker hoặc `./start.sh`. Flutter binary `/opt/homebrew/bin/flutter`. Web test qua `http://127.0.0.1:54180` (R-001).

---

## File Structure

**Backend (`anmates-api/`):**
- Create `services/nearby_provider.go` — `NearbyVenue` type, `NearbyProvider` interface, `dailyBudget` guard, `ErrBudgetExhausted`, helper `sortNearbyByDistance`.
- Create `services/osm_nearby_provider.go` — `OSMNearbyProvider` (Overpass HTTP).
- Create `services/google_places_provider.go` — `GooglePlacesProvider` (searchNearby + radius expand + budget + fallback).
- Create `services/google_places_provider_test.go` — httptest, no real key.
- Modify `config/config.go` — 5 config keys.
- Modify `handlers/venue.go` — `Nearby` handler + nearby cache + refactor `NewVenue` signature.
- Modify `main.go` — provider wiring + route registration.
- Modify `.env.example` — document `GOOGLE_PLACES_API_KEY`.

**Flutter (`anmates_flutter/`):**
- Create `lib/services/nearby_venue_service.dart` — `NearbyVenue` model + service.
- Create `test/nearby_venue_test.dart` — `NearbyVenue.fromJson` unit test.
- Modify `lib/views/discover/discover_view.dart` — swap nearby source + adapt `_RestaurantRow`/`_matchesGenre`/`_filteredPlaces` to `NearbyVenue`; drop `places_service` import.

**E2E:**
- Modify `.dev-e2e/e2e_full_flow.js` — assert `/venues/nearby`.

---

## Task 1: Config keys

**Files:**
- Modify: `anmates-api/config/config.go:10-45` (struct), `:90-110` (Load)

- [ ] **Step 1: Add struct fields**

In `type Config struct`, after the `AIBudgetMax int` line (currently `:44`), add:

```go
	// Discovery "HOT QUANH BẠN" — Google Places (New) nearby search.
	// GooglePlacesAPIKey empty ⇒ nearby falls back to OSM Overpass (dev w/o key still works).
	GooglePlacesAPIKey string
	NearbyDailyBudget  int // hard cap on Places calls/day (VN billing throttles ~2400)
	NearbyRadiusM      int // initial search radius
	NearbyMaxRadiusM   int // expanded radius when initial returns < NearbyMinResults
	NearbyMinResults   int // expand if fewer than this many venues found
```

- [ ] **Step 2: Parse in Load()**

In `Load()`, after the `c.AIBudgetMax = parseIntOr(...)` line (currently `:110`), add:

```go
	// Discovery nearby (Google Places New).
	c.GooglePlacesAPIKey = os.Getenv("GOOGLE_PLACES_API_KEY")
	c.NearbyDailyBudget = parseIntOr("NEARBY_DAILY_BUDGET", 2400)
	c.NearbyRadiusM = parseIntOr("NEARBY_RADIUS_M", 3000)
	c.NearbyMaxRadiusM = parseIntOr("NEARBY_MAX_RADIUS_M", 10000)
	c.NearbyMinResults = parseIntOr("NEARBY_MIN_RESULTS", 5)
```

- [ ] **Step 3: Build to verify it compiles**

Run: `cd anmates-api && GO111MODULE=on go build ./config/`
Expected: rc=0, no output.

- [ ] **Step 4: Commit**

```bash
git add anmates-api/config/config.go
git commit -m "feat(config): add Google Places nearby config keys"
```

---

## Task 2: NearbyVenue type, NearbyProvider interface, budget guard

**Files:**
- Create: `anmates-api/services/nearby_provider.go`
- Test: covered by Task 4's test file.

- [ ] **Step 1: Write the file**

```go
package services

import (
	"context"
	"errors"
	"sort"
	"sync"
	"time"
)

// ErrBudgetExhausted signals the daily Places call budget is spent; callers
// should fall back to a free source (OSM) for the rest of the day.
var ErrBudgetExhausted = errors.New("nearby: daily places budget exhausted")

// NearbyVenue is one restaurant returned to the Discovery "HOT QUANH BẠN" list.
// Distance is computed server-side (Haversine) from the requesting user.
type NearbyVenue struct {
	Name       string   `json:"name"`
	Lat        float64  `json:"lat"`
	Lng        float64  `json:"lng"`
	DistanceM  int      `json:"distance_m"`
	Rating     *float64 `json:"rating,omitempty"`
	PriceLevel *int     `json:"price_level,omitempty"` // 0..4 (Google PRICE_LEVEL_*), nil if unspecified
	OpenNow    *bool    `json:"open_now,omitempty"`
	Address    string   `json:"address,omitempty"`
	Tags       []string `json:"tags,omitempty"` // Google place `types`, lowercased
}

// NearbyProvider returns venues near loc, nearest-first, capped at limit.
type NearbyProvider interface {
	Nearby(ctx context.Context, loc LatLng, limit int) ([]NearbyVenue, error)
}

// sortNearbyByDistance sorts ascending by DistanceM.
func sortNearbyByDistance(vs []NearbyVenue) {
	sort.Slice(vs, func(i, j int) bool { return vs[i].DistanceM < vs[j].DistanceM })
}

// dailyBudget caps Places calls per day (Asia/Ho_Chi_Minh boundary). Thread-safe.
type dailyBudget struct {
	mu    sync.Mutex
	limit int
	loc   *time.Location
	day   string
	count int
}

func newDailyBudget(limit int) *dailyBudget {
	loc, err := time.LoadLocation("Asia/Ho_Chi_Minh")
	if err != nil {
		loc = time.FixedZone("ICT", 7*3600)
	}
	return &dailyBudget{limit: limit, loc: loc}
}

// allow reports whether another call fits under 90% of today's budget,
// incrementing the counter when it does. Resets at the local day boundary.
func (b *dailyBudget) allow() bool {
	b.mu.Lock()
	defer b.mu.Unlock()
	today := time.Now().In(b.loc).Format("2006-01-02")
	if today != b.day {
		b.day, b.count = today, 0
	}
	if b.count >= (b.limit*9)/10 {
		return false
	}
	b.count++
	return true
}
```

- [ ] **Step 2: Build to verify**

Run: `cd anmates-api && GO111MODULE=on go build ./services/`
Expected: rc=0.

- [ ] **Step 3: Commit**

```bash
git add anmates-api/services/nearby_provider.go
git commit -m "feat(nearby): NearbyVenue type + NearbyProvider interface + daily budget guard"
```

---

## Task 3: OSMNearbyProvider (Overpass fallback)

**Files:**
- Create: `anmates-api/services/osm_nearby_provider.go`

- [ ] **Step 1: Write the file**

```go
package services

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// OSMNearbyProvider queries OpenStreetMap Overpass for nearby eateries.
// Free, keyless — the fallback when Google Places is unavailable or over budget.
type OSMNearbyProvider struct {
	client  *http.Client
	radiusM int
}

func NewOSMNearbyProvider(radiusM int) *OSMNearbyProvider {
	return &OSMNearbyProvider{client: &http.Client{Timeout: 20 * time.Second}, radiusM: radiusM}
}

type overpassResp struct {
	Elements []struct {
		Type   string             `json:"type"`
		Lat    float64            `json:"lat"`
		Lon    float64            `json:"lon"`
		Center *struct {
			Lat float64 `json:"lat"`
			Lon float64 `json:"lon"`
		} `json:"center"`
		Tags map[string]string `json:"tags"`
	} `json:"elements"`
}

func (p *OSMNearbyProvider) Nearby(ctx context.Context, loc LatLng, limit int) ([]NearbyVenue, error) {
	q := fmt.Sprintf(`[out:json][timeout:20];
(
  node["amenity"~"restaurant|cafe|fast_food|bar"]["name"](around:%d,%f,%f);
  way["amenity"~"restaurant|cafe|fast_food|bar"]["name"](around:%d,%f,%f);
);
out center 100;`, p.radiusM, loc.Lat, loc.Lng, p.radiusM, loc.Lat, loc.Lng)

	body := "data=" + url.QueryEscape(q)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost,
		"https://overpass-api.de/api/interpreter", strings.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	res, err := p.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("overpass http %d", res.StatusCode)
	}

	var or overpassResp
	if err := json.NewDecoder(res.Body).Decode(&or); err != nil {
		return nil, err
	}

	out := make([]NearbyVenue, 0, len(or.Elements))
	for _, e := range or.Elements {
		lat, lng := e.Lat, e.Lon
		if e.Center != nil {
			lat, lng = e.Center.Lat, e.Center.Lon
		}
		name := e.Tags["name:vi"]
		if name == "" {
			name = e.Tags["name"]
		}
		if name == "" || (lat == 0 && lng == 0) {
			continue
		}
		v := NearbyVenue{
			Name:      name,
			Lat:       lat,
			Lng:       lng,
			DistanceM: int(HaversineM(loc, LatLng{Lat: lat, Lng: lng})),
			Address:   strings.TrimSpace(e.Tags["addr:housenumber"] + " " + e.Tags["addr:street"]),
		}
		if c := e.Tags["cuisine"]; c != "" {
			v.Tags = []string{strings.ToLower(strings.SplitN(c, ";", 2)[0])}
		} else if a := e.Tags["amenity"]; a != "" {
			v.Tags = []string{a}
		}
		out = append(out, v)
	}

	sortNearbyByDistance(out)
	if limit > 0 && len(out) > limit {
		out = out[:limit]
	}
	return out, nil
}
```

- [ ] **Step 2: Build to verify**

Run: `cd anmates-api && GO111MODULE=on go build ./services/`
Expected: rc=0.

- [ ] **Step 3: Commit**

```bash
git add anmates-api/services/osm_nearby_provider.go
git commit -m "feat(nearby): OSM Overpass fallback provider"
```

---

## Task 4: GooglePlacesProvider (TDD)

**Files:**
- Create: `anmates-api/services/google_places_provider.go`
- Test: `anmates-api/services/google_places_provider_test.go`

- [ ] **Step 1: Write the failing test**

`anmates-api/services/google_places_provider_test.go`:

```go
package services

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

// stubFallback records whether the fallback was used.
type stubFallback struct{ called bool }

func (s *stubFallback) Nearby(ctx context.Context, loc LatLng, limit int) ([]NearbyVenue, error) {
	s.called = true
	return []NearbyVenue{{Name: "OSM Fallback", Lat: 10.77, Lng: 106.70, DistanceM: 1}}, nil
}

func newTestServer(t *testing.T, places []map[string]any) *httptest.Server {
	t.Helper()
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("X-Goog-Api-Key") == "" {
			t.Errorf("missing X-Goog-Api-Key header")
		}
		if r.Header.Get("X-Goog-FieldMask") == "" {
			t.Errorf("missing X-Goog-FieldMask header")
		}
		_ = json.NewEncoder(w).Encode(map[string]any{"places": places})
	}))
}

func TestGooglePlacesNearby_ParsesAndSorts(t *testing.T) {
	srv := newTestServer(t, []map[string]any{
		{
			"displayName":         map[string]any{"text": "Quán Xa"},
			"location":            map[string]any{"latitude": 10.80, "longitude": 106.70},
			"formattedAddress":    "123 Far St",
			"rating":              4.2,
			"priceLevel":          "PRICE_LEVEL_MODERATE",
			"currentOpeningHours": map[string]any{"openNow": true},
			"types":               []string{"restaurant", "korean_restaurant"},
		},
		{
			"displayName": map[string]any{"text": "Quán Gần"},
			"location":    map[string]any{"latitude": 10.7701, "longitude": 106.7001},
			"types":       []string{"cafe"},
		},
	})
	defer srv.Close()

	p := NewGooglePlacesProvider("KEY", &stubFallback{}, 3000, 10000, 5)
	p.baseURL = srv.URL

	got, err := p.Nearby(context.Background(), LatLng{Lat: 10.77, Lng: 106.70}, 8)
	if err != nil {
		t.Fatalf("Nearby err: %v", err)
	}
	if len(got) != 2 {
		t.Fatalf("want 2 venues, got %d", len(got))
	}
	if got[0].Name != "Quán Gần" {
		t.Errorf("want nearest first 'Quán Gần', got %q", got[0].Name)
	}
	if got[1].PriceLevel == nil || *got[1].PriceLevel != 2 {
		t.Errorf("want priceLevel 2 for moderate, got %v", got[1].PriceLevel)
	}
	if got[1].OpenNow == nil || !*got[1].OpenNow {
		t.Errorf("want openNow true")
	}
}

func TestGooglePlacesNearby_BudgetExhaustedFallsBack(t *testing.T) {
	srv := newTestServer(t, nil)
	defer srv.Close()

	fb := &stubFallback{}
	p := NewGooglePlacesProvider("KEY", fb, 3000, 10000, 5)
	p.baseURL = srv.URL
	p.budget.count = p.budget.limit // force over budget

	got, err := p.Nearby(context.Background(), LatLng{Lat: 10.77, Lng: 106.70}, 8)
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	if !fb.called {
		t.Errorf("expected fallback to be used when budget exhausted")
	}
	if len(got) != 1 || got[0].Name != "OSM Fallback" {
		t.Errorf("want fallback result, got %v", got)
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd anmates-api && GO111MODULE=on go test ./services/ -run TestGooglePlaces -v`
Expected: FAIL — `undefined: NewGooglePlacesProvider`.

- [ ] **Step 3: Write the implementation**

`anmates-api/services/google_places_provider.go`:

```go
package services

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"
)

const placesNearbyURL = "https://places.googleapis.com/v1/places:searchNearby"

// nearbyFieldMask keeps the request at the Places "Pro" SKU (no Atmosphere/Enterprise
// fields) to control cost. See spec §7.
const nearbyFieldMask = "places.id,places.displayName,places.location," +
	"places.formattedAddress,places.rating,places.priceLevel," +
	"places.currentOpeningHours.openNow,places.types,places.photos.name"

var priceLevelMap = map[string]int{
	"PRICE_LEVEL_FREE":           0,
	"PRICE_LEVEL_INEXPENSIVE":    1,
	"PRICE_LEVEL_MODERATE":       2,
	"PRICE_LEVEL_EXPENSIVE":      3,
	"PRICE_LEVEL_VERY_EXPENSIVE": 4,
}

// GooglePlacesProvider queries Google Places API (New) searchNearby, expanding the
// radius once if too few results, with a daily call budget and an OSM fallback.
type GooglePlacesProvider struct {
	apiKey     string
	baseURL    string
	client     *http.Client
	fallback   NearbyProvider
	budget     *dailyBudget
	radiusM    int
	maxRadiusM int
	minResults int
}

func NewGooglePlacesProvider(apiKey string, fallback NearbyProvider, radiusM, maxRadiusM, minResults int) *GooglePlacesProvider {
	return &GooglePlacesProvider{
		apiKey:     apiKey,
		baseURL:    placesNearbyURL,
		client:     &http.Client{Timeout: 15 * time.Second},
		fallback:   fallback,
		budget:     newDailyBudget(2400), // overwritten by main.go via NewGooglePlacesProviderBudget
		radiusM:    radiusM,
		maxRadiusM: maxRadiusM,
		minResults: minResults,
	}
}

// Nearby tries Google first (with radius expansion), falling back to OSM on any
// error or when the daily budget is exhausted.
func (p *GooglePlacesProvider) Nearby(ctx context.Context, loc LatLng, limit int) ([]NearbyVenue, error) {
	venues, err := p.searchOnce(ctx, loc, limit, p.radiusM)
	if err != nil {
		return p.fallback.Nearby(ctx, loc, limit)
	}
	if len(venues) < p.minResults {
		if more, err2 := p.searchOnce(ctx, loc, limit, p.maxRadiusM); err2 == nil && len(more) > len(venues) {
			venues = more
		}
	}
	if len(venues) == 0 {
		return p.fallback.Nearby(ctx, loc, limit)
	}
	return venues, nil
}

type placesNearbyReq struct {
	IncludedTypes       []string `json:"includedTypes"`
	MaxResultCount      int      `json:"maxResultCount"`
	RankPreference      string   `json:"rankPreference"`
	LocationRestriction struct {
		Circle struct {
			Center struct {
				Latitude  float64 `json:"latitude"`
				Longitude float64 `json:"longitude"`
			} `json:"center"`
			Radius float64 `json:"radius"`
		} `json:"circle"`
	} `json:"locationRestriction"`
}

type placesNearbyResp struct {
	Places []struct {
		DisplayName struct {
			Text string `json:"text"`
		} `json:"displayName"`
		Location struct {
			Latitude  float64 `json:"latitude"`
			Longitude float64 `json:"longitude"`
		} `json:"location"`
		FormattedAddress    string   `json:"formattedAddress"`
		Rating              *float64 `json:"rating"`
		PriceLevel          string   `json:"priceLevel"`
		CurrentOpeningHours *struct {
			OpenNow *bool `json:"openNow"`
		} `json:"currentOpeningHours"`
		Types []string `json:"types"`
	} `json:"places"`
}

func (p *GooglePlacesProvider) searchOnce(ctx context.Context, loc LatLng, limit, radiusM int) ([]NearbyVenue, error) {
	if !p.budget.allow() {
		return nil, ErrBudgetExhausted
	}

	maxCount := limit
	if maxCount > 20 {
		maxCount = 20
	}
	var reqBody placesNearbyReq
	reqBody.IncludedTypes = []string{"restaurant", "cafe"}
	reqBody.MaxResultCount = maxCount
	reqBody.RankPreference = "DISTANCE"
	reqBody.LocationRestriction.Circle.Center.Latitude = loc.Lat
	reqBody.LocationRestriction.Circle.Center.Longitude = loc.Lng
	reqBody.LocationRestriction.Circle.Radius = float64(radiusM)

	buf, err := json.Marshal(reqBody)
	if err != nil {
		return nil, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, p.baseURL, bytes.NewReader(buf))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Goog-Api-Key", p.apiKey)
	req.Header.Set("X-Goog-FieldMask", nearbyFieldMask)

	res, err := p.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("places searchNearby http %d", res.StatusCode)
	}

	var pr placesNearbyResp
	if err := json.NewDecoder(res.Body).Decode(&pr); err != nil {
		return nil, err
	}

	out := make([]NearbyVenue, 0, len(pr.Places))
	for _, pl := range pr.Places {
		if pl.DisplayName.Text == "" {
			continue
		}
		v := NearbyVenue{
			Name:      pl.DisplayName.Text,
			Lat:       pl.Location.Latitude,
			Lng:       pl.Location.Longitude,
			DistanceM: int(HaversineM(loc, LatLng{Lat: pl.Location.Latitude, Lng: pl.Location.Longitude})),
			Rating:    pl.Rating,
			Address:   pl.FormattedAddress,
		}
		if lvl, ok := priceLevelMap[pl.PriceLevel]; ok {
			v.PriceLevel = &lvl
		}
		if pl.CurrentOpeningHours != nil && pl.CurrentOpeningHours.OpenNow != nil {
			v.OpenNow = pl.CurrentOpeningHours.OpenNow
		}
		for _, t := range pl.Types {
			v.Tags = append(v.Tags, strings.ToLower(t))
		}
		out = append(out, v)
	}

	sortNearbyByDistance(out)
	if limit > 0 && len(out) > limit {
		out = out[:limit]
	}
	return out, nil
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd anmates-api && GO111MODULE=on go test ./services/ -run TestGooglePlaces -v`
Expected: PASS (both tests).

- [ ] **Step 5: Vet + commit**

```bash
cd anmates-api && GO111MODULE=on go vet ./services/
git add anmates-api/services/google_places_provider.go anmates-api/services/google_places_provider_test.go
git commit -m "feat(nearby): GooglePlacesProvider with radius expansion + budget + fallback (TDD)"
```

> **Note for executor:** `NewGooglePlacesProvider` hardcodes budget 2400 internally. Task 6 sets the real budget from config by assigning `p.budget = newDailyBudget(cfg.NearbyDailyBudget)` is NOT possible (unexported). Instead, Task 6 uses the constructor as-is for default 2400; if a non-default budget is needed, add an exported setter in this task: append below the constructor:
>
> ```go
> // WithDailyBudget overrides the default daily Places-call cap.
> func (p *GooglePlacesProvider) WithDailyBudget(limit int) *GooglePlacesProvider {
> 	p.budget = newDailyBudget(limit)
> 	return p
> }
> ```
> Include this setter now (add to the commit) so Task 6 can wire `cfg.NearbyDailyBudget`.

---

## Task 5: Nearby handler + cache + NewVenue refactor

**Files:**
- Modify: `anmates-api/handlers/venue.go`

- [ ] **Step 1: Refactor the Venue struct + constructor**

Replace the `Venue` struct and `NewVenue` (currently `:31-42`) with:

```go
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
```

- [ ] **Step 2: Add the nearby cache entry type**

After `type venueCacheEntry struct {...}` (currently `:25-28`), add:

```go
type nearbyCacheEntry struct {
	venues  []services.NearbyVenue
	expires time.Time
}
```

- [ ] **Step 3: Add the Nearby handler + cache helpers**

Append to the end of `handlers/venue.go`:

```go
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
```

- [ ] **Step 4: Build to verify**

Run: `cd anmates-api && GO111MODULE=on go build ./handlers/`
Expected: FAIL — `main.go` still calls old `NewVenue(webSearchProvider)`. That's fixed in Task 6. To verify the handler package alone compiles in isolation is not possible (it's used by main); proceed to Task 6 then build the whole module.

- [ ] **Step 5: Commit**

```bash
git add anmates-api/handlers/venue.go
git commit -m "feat(nearby): GET /venues/nearby handler + cache + NewVenue refactor"
```

---

## Task 6: main.go wiring + route

**Files:**
- Modify: `anmates-api/main.go:124-160` (provider construction), `:228-233` (route registration)

- [ ] **Step 1: Construct the nearby provider**

After the AI Concierge block (right after the `} else { log.Info("AI Concierge disabled...") }` at `:158-160`), add:

```go
	// Discovery "HOT QUANH BẠN" nearby provider. Google Places (New) when keyed,
	// else OSM Overpass. Google wraps OSM as its over-budget / error fallback.
	osmNearby := services.NewOSMNearbyProvider(cfg.NearbyMaxRadiusM)
	var nearbyProvider services.NearbyProvider = osmNearby
	if cfg.GooglePlacesAPIKey != "" {
		nearbyProvider = services.NewGooglePlacesProvider(
			cfg.GooglePlacesAPIKey, osmNearby,
			cfg.NearbyRadiusM, cfg.NearbyMaxRadiusM, cfg.NearbyMinResults,
		).WithDailyBudget(cfg.NearbyDailyBudget)
		log.Info("Discovery nearby: Google Places (New)", "radius_m", cfg.NearbyRadiusM, "daily_budget", cfg.NearbyDailyBudget)
	} else {
		log.Info("Discovery nearby: OSM Overpass (no GOOGLE_PLACES_API_KEY)")
	}
```

- [ ] **Step 2: Update the route registration block**

Replace the `/venues/search` block (currently `:228-233`) with:

```go
	// Discovery venues. /venues/nearby always available (Google→OSM fallback);
	// /venues/search only when the web-search sidecar is configured.
	venueH := handlers.NewVenue(webSearchProvider, nearbyProvider)
	auth.Get("/venues/nearby", venueH.Nearby)
	if webSearchProvider != nil {
		auth.Get("/venues/search", venueH.Search)
	}
```

- [ ] **Step 3: Build the whole module**

Run: `cd anmates-api && GO111MODULE=on go build ./... && GO111MODULE=on go vet ./...`
Expected: rc=0, no output.

- [ ] **Step 4: Run all service tests**

Run: `cd anmates-api && GO111MODULE=on go test ./services/ ./handlers/ -v`
Expected: PASS (incl. TestGooglePlaces*).

- [ ] **Step 5: Commit**

```bash
git add anmates-api/main.go
git commit -m "feat(nearby): wire nearby provider + register GET /venues/nearby"
```

---

## Task 7: Document env var

**Files:**
- Modify: `anmates-api/.env.example`

- [ ] **Step 1: Append documentation**

Add to the end of `anmates-api/.env.example`:

```bash
# ── Discovery "HOT QUANH BẠN" nearby (Google Places API New) ──────────────────
# Optional. When unset, nearby falls back to OSM Overpass (free, keyless).
# Billing account country VN throttles Places to ~2400 req/day — NEARBY_DAILY_BUDGET
# guards at 90% and falls back to OSM. Key must be IP-restricted to the server.
# GOOGLE_PLACES_API_KEY=AIza...
# NEARBY_DAILY_BUDGET=2400
# NEARBY_RADIUS_M=3000
# NEARBY_MAX_RADIUS_M=10000
# NEARBY_MIN_RESULTS=5
```

- [ ] **Step 2: Commit**

```bash
git add anmates-api/.env.example
git commit -m "docs(env): document GOOGLE_PLACES_API_KEY + nearby tuning"
```

---

## Task 8: Flutter NearbyVenue model + service (TDD)

**Files:**
- Create: `anmates_flutter/lib/services/nearby_venue_service.dart`
- Test: `anmates_flutter/test/nearby_venue_test.dart`

- [ ] **Step 1: Write the failing test**

`anmates_flutter/test/nearby_venue_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:anmates_flutter/services/nearby_venue_service.dart';

void main() {
  test('NearbyVenue.fromJson parses fields + derives label/emoji', () {
    final v = NearbyVenue.fromJson({
      'name': 'Quán Gần',
      'lat': 10.77,
      'lng': 106.70,
      'distance_m': 420,
      'rating': 4.3,
      'open_now': true,
      'address': '12 Lê Lợi',
      'tags': ['cafe'],
    });
    expect(v.name, 'Quán Gần');
    expect(v.distanceM, 420);
    expect(v.distanceLabel, '420m');
    expect(v.rating, 4.3);
    expect(v.openNow, true);
    expect(v.emoji, '☕');
  });

  test('distanceLabel switches to km past 1000m', () {
    final v = NearbyVenue.fromJson({'name': 'X', 'lat': 1, 'lng': 1, 'distance_m': 1200});
    expect(v.distanceLabel, '1.2km');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `/opt/homebrew/bin/flutter test test/nearby_venue_test.dart` (from `anmates_flutter/`)
Expected: FAIL — `nearby_venue_service.dart` not found / `NearbyVenue` undefined.

- [ ] **Step 3: Write the implementation**

`anmates_flutter/lib/services/nearby_venue_service.dart`:

```dart
/// Discovery "HOT QUANH BẠN" nearby venues.
/// Mirrors services.NearbyVenue JSON from the Go backend (/api/v1/venues/nearby).

import 'api_client.dart';

class NearbyVenue {
  final String name;
  final double lat;
  final double lng;
  final int distanceM;
  final double? rating;
  final int? priceLevel; // 0..4
  final bool? openNow;
  final String address;
  final List<String> tags;

  const NearbyVenue({
    required this.name,
    required this.lat,
    required this.lng,
    required this.distanceM,
    this.rating,
    this.priceLevel,
    this.openNow,
    this.address = '',
    this.tags = const [],
  });

  factory NearbyVenue.fromJson(Map<String, dynamic> j) => NearbyVenue(
        name: (j['name'] as String?) ?? '',
        lat: (j['lat'] as num?)?.toDouble() ?? 0.0,
        lng: (j['lng'] as num?)?.toDouble() ?? 0.0,
        distanceM: (j['distance_m'] as num?)?.toInt() ?? 0,
        rating: (j['rating'] as num?)?.toDouble(),
        priceLevel: (j['price_level'] as num?)?.toInt(),
        openNow: j['open_now'] as bool?,
        address: (j['address'] as String?) ?? '',
        tags: ((j['tags'] as List<dynamic>?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );

  /// "420m" under 1km, "1.2km" beyond. Empty when distance unknown (0).
  String get distanceLabel {
    if (distanceM <= 0) return '';
    return distanceM < 1000
        ? '${distanceM}m'
        : '${(distanceM / 1000).toStringAsFixed(1)}km';
  }

  String get emoji {
    final t = tags.join(' ').toLowerCase();
    if (t.contains('cafe') || t.contains('coffee') || t.contains('tea')) return '☕';
    if (t.contains('korean') || t.contains('bbq')) return '🥘';
    if (t.contains('japanese') || t.contains('sushi') || t.contains('ramen')) return '🍣';
    if (t.contains('pizza') || t.contains('italian')) return '🍕';
    if (t.contains('seafood')) return '🦐';
    if (t.contains('bar')) return '🍺';
    if (t.contains('fast_food') || t.contains('burger')) return '🍔';
    return '🍽️';
  }

  /// Display tags (max 2), cleaned of underscores.
  List<String> get displayTags {
    if (tags.isEmpty) return ['Ẩm thực'];
    return tags.take(2).map((t) => t.replaceAll('_', ' ')).toList();
  }
}

class NearbyVenueService {
  Future<List<NearbyVenue>> getNearby(double lat, double lng,
      {int limit = 8}) async {
    final data = await ApiClient()
        .get('/api/v1/venues/nearby?lat=$lat&lng=$lng&limit=$limit');
    if (data == null) return [];
    return (data as List)
        .map((e) => NearbyVenue.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `/opt/homebrew/bin/flutter test test/nearby_venue_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add anmates_flutter/lib/services/nearby_venue_service.dart anmates_flutter/test/nearby_venue_test.dart
git commit -m "feat(discover): NearbyVenue model + service (TDD)"
```

---

## Task 9: Wire DiscoverView to /venues/nearby

**Files:**
- Modify: `anmates_flutter/lib/views/discover/discover_view.dart`

Adapts the nearby list from `OsmPlace` (direct Overpass) to `NearbyVenue` (backend). The search path (`VenueSearchService`/`_VenueResultRow`) is untouched.

- [ ] **Step 1: Swap imports**

Replace `import '../../services/places_service.dart';` with:

```dart
import '../../services/nearby_venue_service.dart';
```

(Keep `location_service.dart`, `maps_launcher.dart`, `venue_search_service.dart`, `profile_service.dart`.)

- [ ] **Step 2: Change the state field type**

Replace `List<OsmPlace> _places = [];` with:

```dart
  List<NearbyVenue> _places = [];
```

- [ ] **Step 3: Update `_loadNearby` to call the service**

Replace the `final places = await PlacesService().getNearby(lat, lng);` line and the subsequent `places.sort(...)` block with:

```dart
      final places = await NearbyVenueService().getNearby(lat, lng);
      if (!mounted) return;

      places.sort((a, b) => a.distanceM.compareTo(b.distanceM));
```

(The rest of `_loadNearby` — setState of `_userLat/_userLng/_usingFallbackLocation/_places/_loadingPlaces`, reverse-geocode call — stays as-is.)

- [ ] **Step 4: Update `_filteredPlaces` getter + `_matchesGenre`**

Replace the `List<OsmPlace> get _filteredPlaces` body's search-filter block and the `_matchesGenre` signature to use `NearbyVenue`:

```dart
  List<NearbyVenue> get _filteredPlaces {
    var list = _places;

    if (_activeGenre != null) {
      list = list.where((p) => _matchesGenre(p, _activeGenre!)).toList();
    }

    if (_searchQuery.isNotEmpty) {
      list = list.where((p) {
        final name = p.name.toLowerCase();
        final tags = p.tags.join(' ').toLowerCase();
        return name.contains(_searchQuery) || tags.contains(_searchQuery);
      }).toList();
    }

    return list;
  }

  bool _matchesGenre(NearbyVenue p, String genre) {
    final t = p.tags.join(' ').toLowerCase();
    final n = p.name.toLowerCase();
    switch (genre) {
      case 'Lẩu sùng sục':
        return t.contains('hotpot') || t.contains('lau') || n.contains('lẩu');
      case 'Nướng xì xèo':
        return t.contains('barbecue') ||
            t.contains('bbq') ||
            t.contains('korean') ||
            t.contains('grill') ||
            n.contains('nướng');
      case 'Cafe chill':
        return t.contains('cafe') || t.contains('coffee') || t.contains('tea');
      case 'Ăn vặt phố':
        return t.contains('fast_food') || n.contains('ăn vặt');
      default:
        return true;
    }
  }
```

- [ ] **Step 5: Update `_RestaurantRow` to take `NearbyVenue`**

In `class _RestaurantRow`, change `final OsmPlace place;` to `final NearbyVenue place;`. Replace its `_tagLine` getter and the `_hoursLabel` getter with:

```dart
  String get _tagLine {
    final tags = widget.place.displayTags.join(' · ');
    final dist = widget.place.distanceLabel;
    final base = '${widget.place.emoji} $tags';
    return dist.isEmpty ? base : '$base · $dist';
  }

  String? get _ratingLabel {
    final r = widget.place.rating;
    if (r == null) return null;
    return '⭐ ${r.toStringAsFixed(1)}';
  }

  bool get _openNow => widget.place.openNow == true;
```

Then in `_RestaurantRow.build`, replace the `if (_hoursLabel != null) ...[ ... ]` block with an open-now + rating chip row:

```dart
                    if (_openNow || _ratingLabel != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (_openNow)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.ocean.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text('Đang mở',
                                  style: AppTextStyles.mono(
                                    size: 9,
                                    weight: FontWeight.w600,
                                    color: AppColors.ocean,
                                    letterSpacing: 0.3,
                                  )),
                            ),
                          if (_openNow && _ratingLabel != null)
                            const SizedBox(width: 6),
                          if (_ratingLabel != null)
                            Text(_ratingLabel!,
                                style: AppTextStyles.body(
                                    size: 11, color: AppColors.ink50)),
                        ],
                      ),
                    ],
```

(The `MapsLauncher.open(name:, address:, lat:, lng:)` tap handler still works — `NearbyVenue` has `name/address/lat/lng`.)

- [ ] **Step 6: Analyze**

Run: `cd anmates_flutter && /opt/homebrew/bin/flutter analyze lib/views/discover/discover_view.dart lib/services/nearby_venue_service.dart`
Expected: 0 errors. (Pre-existing `info` lints elsewhere are fine.)

- [ ] **Step 7: Build web to confirm**

Run: `cd anmates_flutter && /opt/homebrew/bin/flutter build web --release`
Expected: build succeeds.

- [ ] **Step 8: Commit**

```bash
git add anmates_flutter/lib/views/discover/discover_view.dart
git commit -m "feat(discover): load HOT QUANH BẠN from /venues/nearby + rating/open-now"
```

---

## Task 10: E2E assertion

**Files:**
- Modify: `.dev-e2e/e2e_full_flow.js`

- [ ] **Step 1: Add a nearby assertion step**

Find the location step that sets the user's lat/lng (search for `/me/location`). After it, add a step that calls `/venues/nearby` and asserts non-empty + ascending distance:

```javascript
  // Step N: Discovery nearby venues (Google Places → OSM fallback).
  {
    const r = await api(`/venues/nearby?lat=10.7769&lng=106.7009&limit=8`, 'GET', null, tokenA);
    assert(Array.isArray(r) && r.length >= 1, 'nearby returns >=1 venue');
    for (let i = 1; i < r.length; i++) {
      assert(r[i].distance_m >= r[i - 1].distance_m, 'nearby sorted by distance asc');
    }
    console.log(`  ✓ nearby: ${r.length} venues, nearest ${r[0].name} (${r[0].distance_m}m)`);
  }
```

(Adapt `api(...)`, `assert(...)`, `tokenA` to the helpers already used in this file — match their existing signatures.)

- [ ] **Step 2: Run E2E (needs the stack up)**

Run: `cd .. && ./start.sh` then `node .dev-e2e/e2e_full_flow.js`
Expected: all steps PASS including the new nearby assertion (uses OSM if no `GOOGLE_PLACES_API_KEY` — still returns venues).

- [ ] **Step 3: Commit**

```bash
git add .dev-e2e/e2e_full_flow.js
git commit -m "test(e2e): assert /venues/nearby returns sorted venues"
```

---

## Self-Review

**Spec coverage:**
- §3 data flow → Tasks 4,5,6,8,9 ✓
- §4.1 config → Task 1 ✓
- §4.2 NearbyVenue + interface → Task 2 ✓
- §4.3 GooglePlacesProvider (field mask, radius expand, budget) → Task 4 ✓
- §4.4 OSM fallback in Go → Task 3 ✓
- §4.5 handler + cache → Task 5 ✓
- §4.6 main.go route (unconditional) → Task 6 ✓
- §5 Flutter service + discover swap + rating/openNow → Tasks 8,9 ✓
- §6 env/secrets → Task 7 ✓ (Secret Manager / cd.go-api.yml prod wiring deferred — operational, noted below)
- §8 error/fallback matrix → Tasks 4 (budget/error→fallback), 5 (502), 9 (UI error state pre-exists) ✓
- §9 testing → Tasks 4 (Go httptest), 8 (Flutter), 9 (analyze/build), 10 (e2e) ✓

**Gaps intentionally deferred (operational, not code):** prod Secret Manager + `cd.go-api.yml --set-env-vars GOOGLE_PLACES_API_KEY` — add when promoting to prod (mirror `AI_SEARCH_URL` pattern). Photo resolution (spec §10 YAGNI). These are NOT blockers for dev/feature completion.

**Type consistency:** Go `NearbyVenue`/`NearbyProvider`/`LatLng`/`HaversineM` consistent across Tasks 2–6. `NewVenue(provider, nearby)` updated in Task 5 and called with that signature in Task 6. `WithDailyBudget` defined in Task 4 note, used in Task 6. Dart `NearbyVenue` fields match Go JSON tags (`distance_m`, `price_level`, `open_now`). `_RestaurantRow.place` type changed to `NearbyVenue` in Task 9 with matching getters.

**Placeholder scan:** none — all steps have concrete code/commands.
