# 2026-06-13 — Map search bar + "chính chủ" venue photos (Foursquare C + agentic B)

Two features on top of the new "Bản đồ" tab. Code done + static-verified; pending
live in-app confirm.

## 1) Map search bar (find a quán or address)
- **Backend proxy** (Goong REST key stays server-side): `services/goong.go` gained
  exported `Autocomplete(ctx,query,lat,lng)` + `PlaceDetail(ctx,placeID)` + types
  `GoongPrediction`/`GoongPlace`; private `autocomplete` now omits location/radius
  when lat==0&&lng==0 (no Null-Island bias). NEW `handlers/places_search.go`
  (`/api/v1/places/autocomplete`, `/api/v1/places/detail`) under `auth`; `main.go`
  registers them only when `GoongAPIKey != ""`.
- **Flutter**: NEW `services/places_search_service.dart` (`PlacePrediction`,
  `PlaceLocation`, autocomplete+detail, never-throws). `map_view.dart` got a search
  field + debounced predictions dropdown; tap a prediction → Place Detail → fly
  camera (zoom 16) + drop a distinct **ocean `_SearchedPin`** + reuse the existing
  card→`VenueDetailView` flow (searched place wrapped as an `OsmPlace`).
- Verified: go build/vet RC=0; flutter analyze clean; flutter build web GREEN.

## 2) Venue photos — "chính chủ" via Foursquare (C) + agentic (B) + improved Bing (A)
**Problem (user):** Goong data is correct but thumbnails showed garbage ("Kem
Pinocchio"→puppet, "Quán nhậu"→a bird). Root cause: name-token-only Bing relevance
— generic names returned EVERYTHING; famous-word names matched the wrong subject.
**Goong has NO photos** (detail = name/address/coords only — verified live).

**How we know a photo is the venue's own (provenance ladder):** only a source that
*associates* the photo to the place by GPS+identity is trustworthy. Foursquare
**photos = PAID** (new Places API: "no API credits remaining"), but Foursquare free
**search returns the venue's official `website`** → crawl THAT domain's og:image =
genuinely the venue's own photo. (Verified: The Coffee House→thecoffeehouse.com→
og:image on their own minio CDN; Pizza 4P's likewise.)

**Resolver chain** (NEW `services/venue_photo.go` `VenuePhotoResolver.Resolve`,
cached 30m):
1. **C — Foursquare** (`services/foursquare.go` `FoursquareClient.Match`): free
   `/places/search` (Bearer + `X-Places-Api-Version: 2025-06-17`), pick nearest
   result within **250m** sharing a name token (≤40m co-location waives token) →
   official `website` → fetch HTML → `extractSocialImages` (og:image/twitter:image/
   image_src) → absolutize + **SSRF-guard** (`IsPublicHTTPImageURL`) + reachability
   `validate`. Identity-grounded "chính chủ".
2. **B — agentic enrich** (existing sidecar Playwright+LLM) — only when
   `allowAgentic` (detail hero; NEVER the list — too slow for 60 tiles).
3. **A — improved Bing** (`venue_image.go` `filterRelevantImages` rewritten): drop
   `nonFoodSourceMarkers` (wiki/imdb/fandom/stock/video → kills Pinocchio); generic
   names now REQUIRE a `foodContextMarkers` hit instead of accepting everything
   (kills the bird); else → honest on-theme **category** photo (never garbage).

**Wiring:** `handlers/venue_image.go` now holds `*VenuePhotoResolver` (was
`*ImageSearcher`); `?q=&lat=&lng=&i=` → `ResolveAt(...,allowAgentic=false)`; `Count`
same. `config.FoursquareKey` ← `FOURSQUARE_KEY`; `main.go` builds the resolver
(Foursquare + enricher + Bing). **Flutter**: `ApiClient.imageUrl` +
`VenueThumbnail` + `VenueImageService.count` gained `lat`/`lng`; passed at every
call site with coords (discover list rows, web-search rows, map card, detail hero).
Coords absent (e.g. a search result with lat=0) → Bing-only path (unchanged).

**Latency/quota guard:** agentic B never runs on the list; Foursquare is 1 search +
1 website fetch per venue, cached 30m, only when coords present.

**Config/CI:** `.env.example` `FOURSQUARE_KEY` documented; `.github/CI-CD.md` secrets
table; `cd.go-api.yml` + `ci.go-api.yml` inject `FOURSQUARE_KEY` as a GH **secret**
(empty-safe). `.env` already has the user's key.

**Verified:** go build/vet RC=0; flutter analyze clean (6 files); live chain probe
(Foursquare search→website→og:image) returns real venue-owned photos.

## PENDING (user)
- Create GH secret `FOURSQUARE_KEY` (for deploy). `./start.sh` → open a venue with a
  known brand (Highlands/Coffee House/Pizza 4P's) → confirm its REAL photo; open a
  generic "Quán nhậu" → confirm on-theme placeholder (no more garbage). Then → R-008.
- Note: small no-website quán → Foursquare gives no site → falls to improved Bing /
  category placeholder (honest, by design). Detail hero still gets agentic B.

## Follow-ups
- Could add Foursquare-website as priority-1 INSIDE the detail enrich handler too
  (currently detail does B-first via /venues/enrich, then C/A via /venues/image).
- No widget/unit tests for the resolver yet (network-dependent).
