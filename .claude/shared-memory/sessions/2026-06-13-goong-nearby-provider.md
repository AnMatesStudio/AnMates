# 2026-06-13 — Goong nearby provider: pluggable interface + pure-Goong + onboarding-personalized keywords + V2

## TL;DR
User: switch Discovery "quán ăn" list to Goong + find images via API. Built across 3 rounds:
1. **Pluggable `NearbyProvider`** (TomTom | Goong by env `MAP_PROVIDER`) + new `GoongClient`.
2. **Pure Goong, no distance filter** (return ALL venues) — user choice after live finding
   that Goong AutoComplete can't do a real proximity list.
3. **Personalized keywords from onboarding** (food/vibe/culture tags → dish keywords) +
   **Goong API V2** endpoints + V2 `types`→amenity. This surfaces REAL named venues
   (Lẩu bò Bé Ba, Bò nướng tảng 5S…) instead of generic "Nhà Hàng" placeholders.
Go build/vet/test GREEN, golangci-lint v2.12.2 **0 issues**, flutter analyze clean, live
e2e through the Go client OK. **Pending:** user `./start.sh` + confirm Discovery in-app.

## Why Goong needed personalization
- Goong has only `place/autocomplete` (keyword, name-matched, loose location bias) +
  `place/detail`. **No nearby/category endpoint, no photos.**
- Generic category keywords ("nhà hàng", "quán ăn") only match venues literally NAMED that
  → live list was ~4–13 generic placeholders, 3–7km out (user saw this, asked why < TomTom).
- **Dish keywords** ("phở", "lẩu bò", "ốc") DO appear in real venue names → derive them
  from the user's onboarding taste tags. Live test: beef+seafood+spicy+Korean+street user
  → 14 venues, mostly real named. Big win.

## Architecture (final)
- **`services/nearby.go`:** `NearbyVenue` + `NearbyProvider` interface
  (`Enabled`/`Name`/`Nearby(ctx,lat,lng,radiusM,limit,keywords)`) + `NewNearbyProvider`
  factory (explicit goong/tomtom, else auto: Goong-if-key else TomTom) + `haversineMeters`.
- **`services/goong.go`:** `GoongClient`. `Nearby` fans out keywords (personalized, else
  `goongDefaultKeywords`/`GOONG_FOOD_KEYWORDS`) through **V2** `/v2/place/autocomplete`,
  dedups place_ids, fetches `/v2/place/detail` concurrently (6 workers), **returns ALL
  venues, NO distance filter** (distance only sorts), cap 60, cache keyed by
  lat/lng/radius+keywords (`GOONG_NEARBY_CACHE_TTL`, default 10m). Amenity from V2 `types`
  (`goongAmenityFromTypes`) with keyword fallback (`goongAmenityForKeyword`).
- **`services/food_keywords.go`:** `FoodKeywordsFromOnboarding(food,vibe,culture)` maps
  onboarding slang keys → VN dish keywords (deduped, capped 8). Mapping table = the decode
  of the playful tags (fwb→quán nhậu/bia, ons→trà sữa, 419→bún, bx→bò nướng/lẩu bò,
  ox→ốc/hải sản, kr→quán hàn/gà hàn quốc, jp→sushi/ramen, street→ăn vặt/vỉa hè, fancy→
  nhà hàng/buffet, …; no_onion/yolo/chill/explore→nothing).
- **`services/tomtom.go`:** kept; added `Name()`; `Nearby` gained ignored `keywords` arg;
  `NearbyVenue` moved to nearby.go.
- **`handlers/venue_nearby.go`:** takes `NearbyProvider` + a `ProfileLookup` (UserService).
  `personalKeywords` reads the JWT user's food/vibe/culture tags → FoodKeywordsFromOnboarding
  → passes to `Nearby`. Best-effort nil on any miss → default keywords. **Zero Flutter change.**
- **`config.go`/`main.go`:** `MapProvider`+`GoongAPIKey` (kept `TomTomAPIKey`); factory wired;
  `NewVenueNearby(provider, userSvc)`.
- **Flutter `places_service.dart`:** `getNearby` calls only the backend provider; Overpass is
  null-fallback only (route absent/no key). Image thumbnails unchanged — ride on the now
  Goong-accurate name+address (`venueImageQuery`).
- **Env/CI:** `.env`(MAP_PROVIDER=goong+key), `.env.example`, `cd/ci.go-api.yml` (+MAP_PROVIDER
  var +GOONG_API_KEY secret, kept TomTom), `CI-CD.md`.

## Goong API facts (live-verified with the real key)
- V1 `Place/AutoComplete`+`Place/Detail` AND V2 `v2/place/autocomplete`+`v2/place/detail`
  both 200. **Same predictions/result shapes**; V2 detail adds `types` (e.g. ["restaurant"]),
  `compound{commune,province}`, `plus_code`, `url`. No photos anywhere. Radius bias in **km**.
- AutoComplete predictions have place_id + structured_formatting but **no coords** → Detail
  per place needed.

## Verification
- `GO111MODULE=on` required (shell default off). go build/vet GREEN; `go test ./services
  ./handlers ./middleware` GREEN. New/updated tests: nearby_test (factory ×7 + haversine),
  goong_test (autocomplete/detail parsers incl. types, amenity-from-types, V2-path Nearby
  flow w/ keyword param + types precedence + no-filter + dedup + sort), food_keywords_test
  (mapping/dedup/cap — cap test caught a real overshoot bug, fixed).
- golangci-lint v2.12.2 (Docker) → **0 issues**.
- flutter analyze changed files: 0 new (5 pre-existing infos in untouched `emoji` getter);
  places_merge_test 4/4.
- **Live e2e** through Go client (throwaway tests, deleted): pure-Goong all-venues run (13,
  nearest 1612m); personalized V2 run (14 real named venues, amenity resolved).
- smoke/ fails (needs live :8080) — unrelated.

## Pending (user)
`./start.sh` (MAP_PROVIDER=goong + key in .env) → onboard a user with food/vibe/culture tags
→ open Discovery → confirm the list is now personalized + real-named + thumbnails resolve.
When confirmed → resolution (R-008/next). NB: a user with NO onboarding tags still gets the
default keyword list (generic). Possible follow-up: use Goong for the search bar; trim noise
(non-food POIs matching a dish token).

## Key facts
- Personalization is automatic from the JWT user — no client change, no query param.
- `MAP_PROVIDER=tomtom` forces TomTom (ignores keywords, real category nearby); empty=auto.
- Spec: `docs/specs/2026-06-13-goong-discovery-nearby.md` (rev 3).
