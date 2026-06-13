# Spec — Pluggable nearby-venue provider (TomTom | Goong) selected by env

**Date:** 2026-06-13
**Branch:** feat/implement-quan-detail
**Status:** design (awaiting user review — rev 2)

## Goal

Make the Discovery "nearby quán ăn" backend provider **pluggable behind a single
interface**, switchable by env between **TomTom** (existing) and **Goong** (new). Add
Goong as the new option (driven by `GOONG_API_KEY`) and let Goong's accurate VN venue
**name + address** feed the existing venue-image pipeline. TomTom is **kept**, not removed.

User decisions (brainstorm 2026-06-13):
1. **One interface, two implementations** — TomTom and Goong both satisfy a
   `NearbyProvider` interface; pick one via env (`MAP_PROVIDER`).
2. **List source = the selected provider only** (drop the TomTom+Overpass merge; Overpass
   stays as a no-key/route-absent fallback only).
3. **Images** = use the provider's `name + address` → existing Bing/agentic image pipeline
   (Goong returns no photos of its own).
4. **Key** = user provides `GOONG_API_KEY`.

## Goong API reality (verified — docs.goong.io/rest/place)

- `Place/AutoComplete` — keyword search biased by `location` + `radius` (**radius in km**).
  Returns predictions: `place_id`, `description`, `structured_formatting`. **No coordinates.**
- `Place/Detail?place_id=` — returns `name`, `formatted_address`, `geometry.location{lat,lng}`.
  **No photos, rating, hours, or reviews.**
- **No nearby/"list around a point" endpoint.** Listing nearby = keyword autocomplete
  (food keywords, location-biased) + a Detail call per prediction for coords.

## Architecture

### Backend (Go) — the interface

**New `services/nearby.go`** (shared, no `config` import — keeps services dependency-free):
- Move `NearbyVenue` here (currently in `tomtom.go`). JSON keys unchanged →
  `OsmPlace.fromBackend` parses identically.
- ```go
  type NearbyProvider interface {
      Enabled() bool
      Name() string
      Nearby(ctx context.Context, lat, lng float64, radiusM, limit int) ([]NearbyVenue, error)
  }
  ```
- Factory with env selection:
  ```go
  func NewNearbyProvider(provider, goongKey, tomtomKey string) NearbyProvider {
      goong  := NewGoongClient(goongKey)
      tomtom := NewTomTomClient(tomtomKey)
      switch strings.ToLower(strings.TrimSpace(provider)) {
      case "goong":  return goong
      case "tomtom": return tomtom
      default: // auto: prefer whichever key is configured
          if goong.Enabled()  { return goong }
          if tomtom.Enabled() { return tomtom }
          return goong // non-nil; Enabled()==false → route stays off
      }
  }
  ```

### Backend — providers

**`services/tomtom.go` (kept, minimal change):** add `func (t *TomTomClient) Name() string
{ return "tomtom" }`. Remove only the local `NearbyVenue` definition (moved to nearby.go).
`tomtom_test.go` unchanged.

**New `services/goong.go` — `GoongClient`** (implements `NearbyProvider`):
- `NewGoongClient(apiKey)`, `Enabled()` (key non-empty), `Name()` → "goong".
- `Nearby(...)`:
  1. radiusM → km, capped (≤ 5 km Goong-side).
  2. For each keyword in `goongFoodKeywords` (default `nhà hàng`, `quán ăn`,
     `quán cà phê`, `quán nhậu`, `lẩu nướng`; override via `GOONG_FOOD_KEYWORDS`),
     GET `https://rsapi.goong.io/Place/AutoComplete?api_key=&input=<kw>&location=lat,lng&radius=<km>`.
  3. Collect predictions, dedup by `place_id`, cap total to `limit` (default 30).
  4. For each unique `place_id`, GET `Place/Detail` **concurrently** (bounded workers ~6)
     → `geometry.location`, `name`, `formatted_address`.
  5. Build `NearbyVenue`: `id="goong_"+place_id`, name, lat/lng,
     `amenity` inferred from the matching keyword (`quán cà phê`→cafe, `quán nhậu`→bar,
     else restaurant), `address`=formatted_address, `distance_m`=haversine.
     `cuisine/phone/opening_hours` empty (Goong has none).
  6. **Return ALL venues — NO distance filter** (user decision, see "Live finding"):
     radiusM only biases Goong's AutoComplete (→ km); `distance_m` is used purely to
     sort nearest-first. Count cap = 60 (only bounds the Detail-call fan-out).
  7. Cache by rounded `(lat,lng,radius)`, short TTL (`GOONG_NEARBY_CACHE_TTL`, default 10m).
- Every failure path returns `error` → handler 502 → client null → Overpass fallback.
  Never panics, never fabricates.

**`handlers/venue_nearby.go`:** take `services.NearbyProvider` instead of
`*services.TomTomClient`. Body unchanged.

**`config/config.go`:** keep `TomTomAPIKey`; add `GoongAPIKey = os.Getenv("GOONG_API_KEY")`
and `MapProvider = os.Getenv("MAP_PROVIDER")` (`goong` | `tomtom` | "" = auto).

**`main.go`:** replace the TomTom-specific block (~L294–303) with the factory:
```go
nearby := services.NewNearbyProvider(cfg.MapProvider, cfg.GoongAPIKey, cfg.TomTomAPIKey)
if nearby.Enabled() {
    auth.Get("/venues/nearby", handlers.NewVenueNearby(nearby).Serve)
    log.Info("Nearby provider enabled: " + nearby.Name())
} else {
    log.Info("Nearby provider disabled (set GOONG_API_KEY or TOMTOM_API_KEY) — client uses Overpass")
}
```

### Flutter

**`services/places_service.dart`** — `getNearby`:
- Call **only** `_getNearbyFromApi` (backend `/venues/nearby`, now provider-agnostic).
- Remove the concurrent Overpass fetch + `mergeNearbyPlaces` call.
- Keep `_getFromOverpass` as the **null-fallback only**: `_getNearbyFromApi` returns `null`
  when the route is absent/errored (no provider key) → use Overpass; a non-null list (even
  empty) is the authoritative provider result. Dev-without-key still works; production
  (key set) is 100% the selected provider.
- `mergeNearbyPlaces`/`mergeFill` stay (still covered by `places_merge_test`) but unused
  by `getNearby`.

**Images — no code change.** `VenueThumbnail` already queries `venueImageQuery(p, area)` =
`name + shortVenueAddress(p.address)` ([discover_view.dart:30]). List now provider-sourced
→ query is accurate → sharper Bing/agentic results. Update the stale TomTom comment on
`venueImageQuery`.

### CI / env

- `.env` / `.env.example`: keep `TOMTOM_API_KEY`; add `GOONG_API_KEY=`, `MAP_PROVIDER=`
  (and optional `GOONG_FOOD_KEYWORDS`, `GOONG_NEARBY_CACHE_TTL`).
- `.github/workflows/cd.go-api.yml` + `ci.go-api.yml`: keep the TomTom `--set-env-vars`;
  add `GOONG_API_KEY=${{ secrets.GOONG_API_KEY }}` and `MAP_PROVIDER=${{ vars.MAP_PROVIDER }}`.
- `.github/CI-CD.md`: add a Goong row (keep TomTom) + document `MAP_PROVIDER`.

## Live finding (2026-06-13) + user decision

Live probe against the real key (origin = Quận 1, 5 food keywords): Goong AutoComplete
matches the keyword against POI **names** with only loose location bias, so a generic
search ("quán ăn") returns places literally *named* "Quán ăn"/"Nhà Hàng", scattered
3–7 km away — **0 within 1.5 km, ~4–13 within ~5 km**. Real restaurants (real names like
"Phở Hòa") never match a generic keyword, and Goong has no nearby/category endpoint, so
there is no better call. Overpass returns 60+ real tagged venues in the same area.

Presented this to the user. **Decision: pure Goong, return ALL venues, no distance
limit** — accept the data-quality tradeoff. So the radius filter was removed; the list
is whatever Goong surfaces for the keywords, sorted nearest-first. (Overpass remains the
no-key/route-absent fallback only.) End-to-end live run through the Go client: 13 venues,
nearest "Lẩu Nướng TuBi" 1612 m, amenity inference correct.

## Known tradeoffs (apply when Goong is the selected provider)

- **Fewer venues** (~5–10/keyword, capped ~30) vs Overpass's 60+.
- **No cuisine / OSM ambiance tags** → vibe chips (Máy lạnh / Vỉa hè / Khuất hẻm /
  Sang chảnh / Ngồi khuya) fall back to **name heuristics only** (weaker). **Open-now
  badge** is dark on the list (Goong has no hours; TomTom's hours path is per-provider).
- **API budget:** ~1 autocomplete + up to N Detail calls per keyword per location;
  mitigated by cache + caps. Goong free-tier limits apply.
- (TomTom keeps its richer fields — cuisine, phone, hours — when it's the selected provider.)

## Testing

- `services/goong_test.go`: pure JSON parsing (autocomplete + detail), amenity inference,
  dedup, distance filter/sort, via `httptest`.
- `services/nearby_test.go`: factory selection (`goong`/`tomtom`/auto/none) by env + keys.
- `tomtom_test.go` stays green (only the `NearbyVenue` move + new `Name()`).
- Go build + vet + `golangci-lint` (v2.12.2) → 0 issues; `flutter analyze` clean.
- **Live verify (user):** set `GOONG_API_KEY` (and optionally `MAP_PROVIDER=goong`) →
  `./start.sh` → Discovery shows Goong-sourced quán with photos resolved via name+address.

## Rev 3 (2026-06-13) — personalized keywords from onboarding + Goong V2

After the user saw the live list was thin/generic ("Nhà Hàng", "Quán ăn"), root cause
reconfirmed: generic category keywords only match POI *names*. Fix = derive keywords
from the user's **onboarding tags** (food/vibe/culture), which decode to **dish names**
— and dish names DO appear in real venue names, so they surface real venues.

- **`services/food_keywords.go` (new):** `FoodKeywordsFromOnboarding(food, vibe, culture)`
  maps the playful onboarding slang keys (fwb/ons/419/bx/ox/kr/jp/street/fancy/…) to real
  VN search terms (quán nhậu, trà sữa, bún, bò nướng, lẩu bò, ốc, hải sản, sushi, ramen,
  ăn vặt, nhà hàng…), deduped + capped at 8 (bounds the per-keyword API fan-out). Dietary/
  generic tags (no_onion/yolo/chill/explore) map to nothing → caller uses defaults.
- **Personalization is backend-derived, zero Flutter change:** `/venues/nearby` is authed,
  so `handlers/venue_nearby.go` reads the caller's tags via `ProfileLookup.GetProfile`
  (UserService), maps them, and passes them to `provider.Nearby(..., keywords)`. Best-
  effort: no profile/tags → nil → default keywords.
- **`NearbyProvider.Nearby` gained a `keywords []string` param.** Goong uses them (override
  default set; cache key now includes the keywords so users don't collide); TomTom ignores
  them (queries by category).
- **Goong V2 endpoints:** `/v2/place/autocomplete` + `/v2/place/detail` (same response
  shapes as v1; verified live). V2 Detail adds a `types` array → `goongAmenityFromTypes`
  sets amenity from the real category (cafe/bar/fast_food/restaurant), falling back to the
  keyword's amenity when types are absent.
- **Live result (real key, Quận 1, sample beef+seafood+spicy+Korean+street user):** keywords
  `[bò nướng, lẩu bò, ốc, hải sản, lẩu thái, mì cay, quán hàn, gà hàn quốc]` → **14 venues,
  mostly REAL named** (Lẩu bò Bé Ba, Bò nướng tảng 5S, Lẩu bò Đức Hiến, Lẩu Thái Hào Ký,
  Ốc…) vs the old 4 generic. Minor noise possible (a non-food POI can match a dish token).
- Tests: `food_keywords_test.go` (mapping/dedup/cap), `goong_test.go` (+`types`→amenity,
  V2 paths, keyword param, types-precedence). Go build/vet/test + golangci-lint v2.12.2 → 0.

## Out of scope

- Goong-powered search-bar autocomplete (typed search still uses the web-search path).
- Goong Directions / Distance-Matrix midpoint (venue.go V2 note — untouched).
- Restoring cuisine/hours from another source when Goong is selected (badge degradation
  accepted).
