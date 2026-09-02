# 2026-06-11 — Venue image endpoint fixes (401/429/404) + Goong venue-freshen

## TL;DR
User hit a chain of errors loading venue thumbnails/photos on the Discovery detail
screen, then asked how to fix stale OSM venue data. Two deliverables:
1. **Fixed the venue-image proxy** so photos actually load (was 401, then 429, then 404).
   Swapped the image source from DuckDuckGo (now CAPTCHA-blocked server-side) to Bing
   Images.
2. **Added a Goong-backed venue-freshen path** (`GET /api/v1/venues/fresh`) to correct
   stale OpenStreetMap venue names/addresses/hours at detail-open time. User chose Goong
   over Google Places (fits the locked "no Google Maps in VN → Goong" decision).

## Part 1 — Image endpoint error chain (all fixed)

| Error | Root cause | Fix |
|-------|-----------|-----|
| 401 Unauthorized | `api.Use(jwtMW)` in Fiber v2 is a catch-all for ALL `/api/v1*` routes registered *after* it — including the `app.Get("/api/v1/venues/image")` ones at the bottom of main.go | Moved the two `app.Get` image-route registrations to *before* `api.Use(jwtMW)` (main.go ~L194) |
| 429 Too Many Requests | The `/api/v1` group's `rlHandler` (rate limiter, 0.5rps) also catches those `app.Get` routes; a 6-thumbnail list burst trips it | Wrapped `rlHandler` to skip paths with prefix `/api/v1/venues/image` (main.go ~L106) |
| 404 Not Found | Two causes: (a) OSM names carry admin suffixes ("…Phường Hiệp Bình") that over-specify the query; (b) **DDG Lite now returns a bot CAPTCHA page** (`"Unfortunately, bots use DuckDuckGo too"`) when scraped server-side → 0 result pages → 0 images | (a) `prepareVenueSearchQuery` strips `Phường/Quận/TP.` etc + appends "ảnh"; (b) **rewrote `services/venue_image.go` to use Bing Images** instead of DDG Lite page-crawl |

### Bing rewrite (services/venue_image.go)
- One GET to `https://www.bing.com/images/search?q=…` → parse the `murl&quot;:&quot;<url>`
  JSON fragments Bing embeds in results HTML (`murlRe`). No multi-hop page crawl.
- Verified live: `curl` to Bing returns clean direct image URLs for VN venue names.
- Removed all DDG machinery (searchPages/imagesFromPage/parseResultURLs/normalizeResultURL/
  extractImages/absolutizeURL/blockedPageDomains). Kept `prepareVenueSearchQuery` + `isJunkImage`.
- Tests rewritten: `TestParseBingImageURLs`, `…Capped`, `TestPrepareVenueSearchQuery`, `TestIsJunkImage`.

## Part 2 — Goong venue-freshen (new)

**Problem:** Discovery pulls venues live from OSM via Overpass (`places_service.dart:168`).
OSM is community-maintained → stale. Concrete case: OSM says "Tara Coffee" at 23 Đường số 37,
but Google shows the venue there is now "AgriSocial". User asked "fetch latest via google
search?" → answered honestly that scraping Google is blocked/ToS/fragile (same wall as DDG),
and the licensed VN-correct source is **Goong** (their locked architecture choice). User picked Goong.

**Design — freshen at detail-open time (1 Goong call per tap, cached 24h):**
- `services/goong.go` `GoongClient.Freshen(ctx, name, lat, lng)` — two-tier, best-effort, nil-degrading:
  1. **Place AutoComplete** (input=OSM name, location-biased) → **Place Detail**. Anchored to
     the name → same business canonicalized → safe silent override. Accepts only if the detail
     coord is ≤150m from the queried point (`goongMatchRadiusM`) to reject same-name venues elsewhere.
  2. **Reverse Geocode** (`/Geocode?latlng=`) fallback when (1) misses — surfaces a *replacement*
     business / at least corrects the address. Name falls back to formatted_address when Goong
     has no trade name.
  - Returns `FreshVenue{Name,Address,Lat,Lng,Phone,OpeningHours,PlaceID,Source}`; `Source` =
    `goong-autocomplete` | `goong-reverse`.
- `handlers/venue_fresh.go` `VenueFresh.Serve` — `GET /api/v1/venues/fresh?name=&lat=&lng=`,
  returns `{}` (200) when nothing fresher → client keeps OSM.
- `main.go` — registers route on the **authed** group (token-protects Goong quota), only when
  `GOONG_API_KEY` set; logs enabled/disabled.
- `config.go` — `GoongAPIKey` from `os.Getenv("GOONG_API_KEY")`.
- `.env` + `.env.example` — documented `GOONG_API_KEY` (empty = feature off). `env_file: .env`
  in docker-compose already passes it through (no compose edit needed).

**Flutter wiring:**
- `services/venue_fresh_service.dart` `VenueFreshService.freshen()` → `FreshVenue` model;
  returns null on disabled/miss/error.
- `views/discover/venue_detail_view.dart`:
  - `VenueDetailData.withFresh(FreshVenue)` — overrides only non-empty fresh fields; re-points
    `imageQuery` at the new name when it changes.
  - `_d` made mutable (`late VenueDetailData _d`); `initState` calls `_freshen()` → setState
    replaces `_d`; if the name changed, resets + refetches the hero photo gallery.

## Files changed
- `anmates-api/main.go` (route order, rl exemption, freshen route)
- `anmates-api/config/config.go` (GoongAPIKey)
- `anmates-api/services/venue_image.go` (DDG→Bing rewrite)
- `anmates-api/services/venue_image_test.go` (rewritten)
- `anmates-api/services/goong.go` (NEW)
- `anmates-api/services/goong_test.go` (NEW)
- `anmates-api/handlers/venue_fresh.go` (NEW)
- `anmates_flutter/lib/services/venue_fresh_service.dart` (NEW)
- `anmates_flutter/lib/views/discover/venue_detail_view.dart` (mutable _d + freshen)
- `.env`, `.env.example` (GOONG_API_KEY)

## ⚠️ Part 2 REVERTED (same session, user request: "revert lại ko dùng Goong API nữa")
User decided not to use Goong after all. All Part-2 Goong code removed: deleted
`services/goong.go`, `services/goong_test.go`, `handlers/venue_fresh.go`,
`services/venue_fresh_service.dart`; reverted `config.go` (GoongAPIKey), `main.go`
(freshen route), `venue_detail_view.dart` (back to `_d => widget.data`, no freshen),
`.env` + `.env.example` (GOONG_API_KEY). Verified clean via grep (no goong/freshen
refs left in any .go/.dart except the pre-existing `// V2` comment in venue.go).
Static-only verify — Docker Desktop had stopped, so no recompile run; revert is pure
removal of just-added code so prior green state is restored.
**Part 1 (Bing image fix) KEPT** — confirmed working. Stale-OSM-data problem remains
OPEN/unsolved (no fresh-data provider wired). If revisited: options were Goong (now
rejected), Google Places (conflicts with locked no-Google-Maps decision), or crowdsource.

## Part 3 — Gallery polish + relevance/reachability hardening (follow-up, same day)

User asked to (a) show more photos with left/right swipe, then (b) fix two quality bugs:
broken photos (502) and **wrong photos** for a venue Bing has no images of.

**Gallery UX (`venue_detail_view.dart`):**
- Hero `PageView` wrapped in `ScrollConfiguration` adding `PointerDeviceKind.mouse` to
  `dragDevices` → swipe by touch (mobile) AND mouse-drag (Flutter web). No arrow buttons
  (tried, then removed per user). Dots indicator kept. Needs `import 'package:flutter/gestures.dart'`.

**`services/venue_image.go` — two server-side gates so Count only reports good photos:**
1. **Reachability validation** — cap raised 6→`maxImagesPerQuery=10`; over-fetch
   `candidatePoolSize=30` candidates, then `validate()` probes each concurrently
   (`imageProbeWorkers=6`, ranged `GET bytes=0-1023`, `imageProbeTimeout=4s`) requiring 200/206
   + `Content-Type: image/*`. Keeps the first 10 reachable in Bing rank order. Kills the **502s**
   (dead / hotlink-protected `murl`s) — Count no longer counts unservable photos.
2. **Relevance filter** — root cause of WRONG photos: Bing returns unrelated junk (Philippine
   flags, "Chat Us On WhatsApp", World Cup) for venues it has no images of, and validation only
   checks reachability. Now parse the full Bing `m="{…}"` JSON blob per result (`parseBingImages`
   → `murl` + `t`/`desc`/`purl` haystack), and `filterRelevantImages` keeps only images whose
   haystack contains a **distinctive venue token** (`significantTokens`: name minus admin suffix
   minus `venueStopwords` generic VN words like trung/tâm/hội/nghị/tiệc/cưới/nhà/hàng/quán/ảnh →
   leaves brand tokens like "claris","palace","tara"). No distinctive token (fully generic name)
   ⇒ can't judge ⇒ keep all. Empty result ⇒ `Count`=0 ⇒ client renders the emoji placeholder
   (honest) instead of a misleading/NSFW photo.
   - Crawl now receives the RAW venue query (area included) and computes prepared query +
     tokens internally; `ResolveURLs` no longer pre-applies `prepareVenueSearchQuery`.
   - Removed old `murlRe` + `parseBingImageURLs`; tests rewritten: `TestParseBingImages`,
     `TestSignificantTokens`, `TestFilterRelevantImages` (+ kept Prepare/Junk).

**Live verify (project `anmates`, api rebuilt + `up -d --no-deps api`):**
- `Tara Coffee …` → count 10, indices 0/3/4/7/9 all 200 image bytes (incl. i=4 which was 502).
- `Trung tâm Hội nghị – Tiệc cưới Claris Palace …` → count **0**, i=0 → 404 → placeholder.
- `go build` + `go test ./services` green in golang:1.25 container.

**⚠️ Docker gotcha (this machine):** the PowerShell tool's CWD is `anmates-api/`, which has its
OWN `docker-compose.yml`. A bare `docker compose …` there spins up a SECOND project `anmates-api`
with an empty pgdata → db fails ("POSTGRES_PASSWORD not specified", `${DB_PASS}` not interpolated).
The REAL stack is project **`anmates`** (started by `start.sh`, compose files
`docker-compose.yml:docker-compose.host-ollama.yml`, volume `anmates_pgdata`). Always target it
explicitly: `docker compose -p anmates --project-directory <root> -f docker-compose.yml -f
docker-compose.host-ollama.yml … && … up -d --no-deps api`. Cleaned up the stray `anmates-api`
containers (left its empty `anmates-api_pgdata` volume; harmless, `docker volume rm` to drop).

## Part 4 — Category stock fallback (user chose "ảnh theo loại quán")

After Part 3, venues Bing has no photos of showed a blank/placeholder hero. Asked the user
(AskUserQuestion) how to handle it; they picked **category stock fallback** over a nicer
placeholder or relaxing relevance.

**`services/venue_image.go` — backend fallback (no Flutter change needed):**
- In `crawl`, after relevance + reachability yields `len(urls)==0` → call `crawlCategory`.
- `crawlCategory` does a second Bing search using a **generic on-theme query**
  (`categoryStockQuery`), **skips the relevance filter** (query is intentionally generic),
  still validates reachability, caps at `fallbackImageCount=5`.
- `categoryStockQuery(name)` keyword-maps the venue name → query:
  tiệc cưới/hội nghị/palace ⇒ "nhà hàng tiệc cưới sang trọng"; cà phê/coffee/trà sữa ⇒
  "quán cà phê đẹp"; lẩu/nướng/bbq/korean/sushi ⇒ "nhà hàng lẩu nướng"; bar/beer/pub ⇒
  "quán bar pub đẹp"; phở/bún/cơm/quán ăn/nhà hàng ⇒ "nhà hàng món việt"; default ⇒
  "nhà hàng quán ăn đẹp". (`containsAny` helper; verified these queries return attractive,
  on-theme VN photos.) Cached under the venue key like any other result.
- Fallback photos are NOT the real venue — acceptable per user's explicit choice. Real-venue
  matches always win (fallback only when relevance count is 0). Test: `TestCategoryStockQuery`.

**Live verify:** Claris Palace → count **5** (wedding-hall stock), i=0/2/4 all 200 image bytes;
Tara Coffee still → 10 real photos (fallback not triggered). build+tests green.

**Possible follow-up (not done):** a subtle "ảnh minh hoạ" badge when showing fallback photos,
so users aren't misled they're the actual venue. Flag if the swap feels confusing in use.

## Verification
- Image fix: **user-confirmed working** (screenshot shows Tara Coffee detail with a 6-photo
  hero gallery rendering). Parts 3-4 verified server-side; **awaiting user reload-confirm** that
  Claris Palace now shows on-theme wedding-hall stock photos + Tara shows 10 clean swipeable real photos.
- Go build/vet/test: running in Docker at session write time — see final report.
- **PENDING (blocked on user):** a real `GOONG_API_KEY` to live-verify the freshen path. Until
  then the route is disabled and the app behaves exactly as before (OSM only).

## Open follow-ups / honest caveats
- **Goong cannot do Google-style nearby-POI search.** Tier-1 (autocomplete-by-name) won't
  surface an outright *replacement* (Tara Coffee→AgriSocial); only tier-2 (reverse geocode)
  might, and its "name" is often just the address. If reliably detecting replacements matters,
  Google Places Nearby Search is the only solid source — but it conflicts with the locked
  "no Google Maps in VN" decision. Flag to user after they test with a key.
- List thumbnails still show stale OSM names (freshen is detail-only, to spare Goong quota).
- Could add a subtle "đã cập nhật từ Goong / quán có thể đã đổi" badge when `Source=goong-reverse`
  and the name changed, so a silent swap isn't confusing.
- When confirmed working → migrate to a resolution (R-007).
