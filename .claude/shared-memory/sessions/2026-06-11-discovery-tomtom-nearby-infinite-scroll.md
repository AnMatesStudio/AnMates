# 2026-06-11 — Discovery: image query tweaks + TomTom nearby + infinite scroll

## TL;DR
Follow-up on the venue-photo work (R-007). User: list thumbnails still mismatched; wanted
"Bing → Google Maps name+address → 5 photos, min 1, replace venue if none", plus pull-to-load-more
nearby venues to 5km + a back-to-top button. Also asked for the best self-serve VN map API (Goong
needs a phone-call to activate). Delivered: query-with-address + 5-cap + infinite scroll +
back-to-top, and wired a **TomTom** nearby-POI proxy (fresher VN data than OSM) behind an env key
with graceful Overpass fallback.

## Honest constraint stated to user
"Bing accessing Google Maps to scrape photos" isn't feasible (Maps renders images via dynamic JS +
anti-bot, no static URLs; also conflicts with the locked no-Google-Maps-in-VN decision). Achievable
equivalent shipped instead: search Bing with **name + address** (more specific) + the R-007
relevance filter + category fallback (guarantees ≥1 on-theme image per venue = the "must have image"
requirement).

## Image changes (venue_image.go + Flutter)
- `maxImagesPerQuery` 10 → **5** (user "tối đa 5 tấm"); `candidatePoolSize`=15; fallback still 5.
- Photo search query now **name + address** (was name + ward):
  - `venue_detail_view.dart` `_query(name, address, area)` → prefers address, else area, else name.
  - `discover_view.dart` `_RestaurantRow._imageQuery` + `_VenueResultRow` use address when present.
- "Replace venue if no photo" is satisfied structurally by the R-007 category fallback (every venue
  resolves to ≥1 image), so no venue-skipping/backfill was needed.

## Infinite scroll + back-to-top (discover_view.dart)
- Nearby fetch radius **1500 → 5000m** (`_kNearbyRadiusM`); `getNearby(radiusM: 5000)`.
- Client-side paging: `_visibleCount` starts 6 (`_kPageSize`), `_onScroll` reveals +6 when within
  240px of bottom; resets to 6 on new search/genre/reload. Footer shows a spinner while more remain,
  else "Đã hết quán trong bán kính 5km".
- `ScrollController _scrollCtrl` on the outer SingleChildScrollView; back-to-top `FloatingActionButton.small`
  appears past 400px scroll, `animateTo(0)`. Only the OSM browse path paginates (not web-search results).

## TomTom nearby proxy (NEW — fresher VN POI than OSM)
User picked TomTom/HERE (self-serve free key, no phone call) over Goong/VietMap. Chose **TomTom**.
Server-proxied so the key never reaches the web bundle; **degrades to Overpass** when no key.
- `config.go` — `TomTomAPIKey` from `TOMTOM_API_KEY`.
- `services/tomtom.go` — `TomTomClient.Nearby(ctx,lat,lng,radiusM,limit)` → TomTom
  `search/2/nearbySearch` (categorySet 7315 Restaurant + 9376 Café/Pub, language vi-VN, limit ≤100),
  maps results → `NearbyVenue{id,name,lat,lng,amenity,cuisine,address,phone,distance_m}`;
  `tomtomAmenity` maps classification codes → restaurant/cafe/fast_food/bar. `Enabled()` gate.
- `handlers/venue_nearby.go` — `GET /api/v1/venues/nearby?lat=&lng=&radius=&limit=` (default radius
  5000, max 50000); 502 on failure so the client falls back.
- `main.go` — registers on the **authed** group only when `tomtom.Enabled()` (protects quota); logs
  enabled/disabled.
- Flutter `places_service.dart` — `OsmPlace.fromBackend(json)` + `getNearby` tries
  `/api/v1/venues/nearby` first, uses it when non-empty, else falls back to the existing Overpass
  query. Same `OsmPlace` return type → discover UI unchanged.
- `.env` + `.env.example` — documented `TOMTOM_API_KEY` (empty = Overpass).

## VN map API advice given
Goong/VietMap = best VN-native data but key activation has friction (phone call / business verify).
Self-serve-instant + free alternatives that work in VN: **TomTom** (chosen — Search/Nearby + fresh
POI), HERE, MapTiler (tiles only), Mapbox (best SDK). TomTom also fixes the stale-OSM problem
(Tara Coffee → AgriSocial) since its POI data is fresher than Overpass.

## Verification
- Go `build` + `vet` + services tests GREEN (golang:1.25). `Tara Coffee 23 Đường số 37` and the
  Claris Palace query both → count **5**.
- api rebuilt + restarted (project `anmates`); log: "TomTom nearby disabled (set TOMTOM_API_KEY) —
  client uses Overpass" (no key yet → app unchanged).
- **PENDING (needs user):** a real `TOMTOM_API_KEY` in `.env` + rebuild to live-verify fresher
  nearby data; Flutter **hot restart** to see address-query photos + infinite scroll + back-to-top.

## Follow-up (same day) — TomTom live findings + honest photo/radius

Live-tested with the user's real `TOMTOM_API_KEY`:
- **TomTom hard-caps at 100 results** (`totalResults:100`, `ofs=100` → 0; same for `nearbySearch`
  AND `categorySearch`). In dense HCM the nearest 100 only span ~736m → **5km coverage is
  impossible** with TomTom. `placeById`/`poiDetails` photo endpoints → empty / **403 Forbidden**
  on this key → **TomTom provides no venue photos**.
- **Radius:** kept TomTom (fresh nearest ~100) and fixed the footer from the false "Đã hết quán
  trong bán kính 5km" → honest **"Đã hiển thị {N} quán gần bạn"** (discover_view.dart).
- **Photos:** user chose **honest per-category placeholder over fake stock**. So the R-007
  **category-stock fallback was REMOVED** (`crawlCategory`/`categoryStockQuery`/`containsAny`/
  `rotateByKey`/`fallbackImageCount` deleted; `crawl` now returns empty when no venue-matched photo).
  Venues without a real Bing match → count 0 → the existing `PhotoSlot` gradient+emoji placeholder
  (category-aware via `OsmPlace.emoji`). Verified: Tara Coffee→4 real, Nga Tea→0 (placeholder),
  Claris→1. `maxImagesPerQuery` stays 5.
- Net: list/detail now show ONLY real venue-matched photos; everything else is an honest category
  placeholder. No more wrong/repeated stock images.

## Open follow-ups
- TomTom result→model mapping is built from docs, not live-verified (no key yet). Verify openingHours
  (nearbySearch often omits it) and category→amenity coverage once a key is added.
- Could swap the map TILE source to MapTiler/TomTom too (Discovery has no rendered map yet; only the
  list). Out of scope this session.
- If TomTom proves good, consider also routing the AI-concierge venue grounding + the stale-venue
  problem through it (would supersede the reverted Goong freshen idea).
