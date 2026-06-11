---
id: R-007
title: Venue photo proxy — Bing Images source + 401/429/404/502 fixes + relevance filter + category stock fallback + swipe gallery
tags: [venue-image, bing-images, go-backend, fiber-routing, rate-limit, image-proxy, relevance, category-fallback, flutter, gallery, web-search, docker]
platforms: [backend, web, android, ios]
severity: major
status: confirmed
date_resolved: 2026-06-11
confirmed_by: user
related_sessions: [sessions/2026-06-11-venue-image-routing-bing-and-goong-freshen.md]
related_blockers: []
---

# R-007: Venue photo proxy — Bing source, routing/rate fixes, relevance filter, category fallback, swipe gallery

## TL;DR
The Discovery venue-detail hero photo broke through a chain of errors (401 → 429 → 404 → 502)
and then showed *wrong/irrelevant* photos for venues Bing has no images of. Fixed by: (1) moving
the public image routes before the JWT middleware + exempting them from the rate limiter; (2)
switching the image source from DuckDuckGo (now CAPTCHA-blocked) to **Bing Images** parsing `murl`;
(3) **validating reachability** of each candidate so dead URLs never reach the gallery; (4) a
**relevance filter** that keeps only images whose Bing title/desc/page-URL mention a distinctive
venue token; (5) a **category stock fallback** when no real photo matches; plus a touch+mouse
swipeable hero gallery.

## Symptoms
- `GET /api/v1/venues/image?q=...` → **401 Unauthorized**
- then `{"error":{"code":"RATE_LIMITED"}}` **429 Too Many Requests**
- then **404 Not Found** for every venue
- then some gallery pages **502 Bad Gateway** (e.g. `...&i=4`)
- then *wrong* photos: an irrelevant/NSFW image for "Trung tâm Hội nghị – Tiệc cưới Claris Palace"
- finally (after relevance filter) a **blank hero** for venues Bing has no photos of

## Root Cause
- **401:** In Fiber v2, `api.Use(jwtMW)` is a catch-all for ALL `/api/v1*` routes registered
  *after* it — including `app.Get("/api/v1/venues/image")` registered on the root `app`. The image
  routes were at the bottom of `main.go`, after the JWT middleware.
- **429:** The `/api/v1` group's rate limiter (`rlHandler`, 0.5 rps / burst 5) also catches those
  `app.Get` routes; a list/gallery burst of thumbnails trips it instantly.
- **404:** Two causes — (a) OSM POI names carry admin suffixes ("…Phường Hiệp Bình") that
  over-specify the query; (b) **DuckDuckGo Lite now serves a bot CAPTCHA page** server-side
  (`"Unfortunately, bots use DuckDuckGo too"`) → 0 results → 404 for every query.
- **502:** Many Bing `murl` URLs are dead / hotlink-protected; the proxy fetch fails → 502, and
  `Count` was counting these unservable URLs so blank gallery pages rendered.
- **Wrong photos:** Bing returns unrelated junk (Philippine flags, "Chat Us On WhatsApp", World
  Cup) for a venue it has *no* images of, and validation only checked reachability, not relevance.

## Solution

### Steps
1. Move the two image-route registrations (`/api/v1/venues/image`, `/api/v1/venues/images`) AND
   the `venueImageH` init to BEFORE `auth := api.Use(jwtMW)` in `main.go`.
2. Wrap `rlHandler` to `c.Next()` (skip) for paths with prefix `/api/v1/venues/image`.
3. Rewrite `services/venue_image.go` to use **Bing Images**: one GET to
   `https://www.bing.com/images/search?q=...`, parse the per-result `m="{…}"` JSON blob
   (entity-encoded; `"`→`&quot;`) for `murl` + `t`/`desc`/`purl`.
4. **Reachability validation:** over-fetch `candidatePoolSize=30`, probe each concurrently
   (`imageProbeWorkers=6`, ranged `GET bytes=0-1023`, 4 s timeout, require 200/206 + `image/*`),
   keep first `maxImagesPerQuery=10` reachable in Bing rank order.
5. **Relevance filter:** `significantTokens(name)` = venue name minus admin suffix minus generic
   `venueStopwords` (trung/tâm/hội/nghị/tiệc/cưới/nhà/hàng/quán/cà/phê/ảnh…) → brand tokens
   ("claris","palace","tara"). Keep an image only if its haystack (title+desc+purl, lowercased)
   contains a token. No distinctive token ⇒ keep all (can't judge).
6. **Category stock fallback:** when relevance+reachability yields 0, `crawlCategory` re-queries
   Bing with a generic on-theme query from `categoryStockQuery(name)` (skips relevance filter,
   still validates), capped `fallbackImageCount=5`. So the hero is never blank.
7. **Flutter hero gallery:** `PageView` wrapped in `ScrollConfiguration` adding
   `PointerDeviceKind.mouse` to `dragDevices` → swipe by touch (mobile) + mouse-drag (web);
   dots indicator; count from `/venues/images?q=`.

### Code changes
| File | Change |
|------|--------|
| `anmates-api/main.go` | image routes moved before `api.Use(jwtMW)`; `rlHandler` skips `/api/v1/venues/image*` |
| `anmates-api/services/venue_image.go` | DDG→Bing; `parseBingImages` (murl+t/desc/purl); `validate`/`reachableImage`; `significantTokens`/`filterRelevantImages`; `crawlCategory`/`categoryStockQuery`/`containsAny`; `prepareVenueSearchQuery` (strip admin suffix + " ảnh") |
| `anmates-api/handlers/venue_image.go` | proxies bytes with browser UA + same-origin Referer (anti-hotlink); `Serve` (per-index), `Count` (JSON) |
| `anmates-api/services/venue_image_test.go` | tests: ParseBingImages, SignificantTokens, FilterRelevantImages, CategoryStockQuery, PrepareVenueSearchQuery, IsJunkImage |
| `anmates_flutter/lib/views/discover/venue_detail_view.dart` | swipeable hero (touch+mouse), dots; `import 'package:flutter/gestures.dart'` |
| `anmates_flutter/lib/widgets/venue_thumbnail.dart` | `Image.network(ApiClient.imageUrl(query,index:i))`, placeholder on 404/error |

## Verification
- Tara Coffee → `count:10`, indices 0/3/4/7/9 all 200 image bytes (incl. i=4 which was 502).
- Claris Palace → relevance 0 ⇒ category fallback `count:5` (wedding-hall stock), i=0/2/4 → 200.
- `go build ./...` + `go test ./services` green in `golang:1.25` container.
- User confirmed the gallery works (Tara Coffee 6+ photo hero screenshot) and asked to persist.

## Why this fix works (for future-Claude)
Fiber v2 middleware is positional: `group.Use(mw)` applies to every later `/prefix*` request,
even routes registered on the root `app`. Register public routes (and rate-limit exemptions)
*before* the auth middleware. For images, Bing embeds direct URLs as `murl` inside an HTML-entity-
encoded JSON `m="{…}"` per result — that same blob also carries `t`/`desc`/`purl`, which is the
only cheap server-side relevance signal (token overlap with the venue's brand words). Reachability
must be probed because search engines list many dead/hotlink-protected images; relevance must be
checked because search engines return *plausible-looking junk* for queries they can't satisfy.

## Gotchas / Related issues
- **Trade-off:** strict relevance can drop real photos of obscure venues whose Bing title doesn't
  echo the name → those fall through to category stock. Showing a category photo is the user-chosen
  behavior; a wrong/real-looking photo was judged worse than an on-theme stock one.
- **Possible follow-up:** an "ảnh minh hoạ" badge when the category fallback is in use, so users
  aren't misled the stock photo is the actual venue.
- **DuckDuckGo Lite is dead for server-side scraping** (CAPTCHA) — don't revert to it.
- **Stale OSM venue data** (OSM says "Tara Coffee" but the address is now "AgriSocial") is a
  *separate* unsolved problem; the Goong freshen feature for it was built then reverted (no
  fresh-data provider currently wired).
- **Docker on this machine:** the PowerShell tool's CWD is `anmates-api/`, which has its OWN
  `docker-compose.yml`. A bare `docker compose …` there spins up a SECOND broken project
  `anmates-api` (empty pgdata, `${DB_PASS}` not interpolated → db unhealthy). The real stack is
  project **`anmates`** (started by `start.sh`, files `docker-compose.yml:docker-compose.host-ollama.yml`).
  Rebuild the API explicitly:
  `docker compose -p anmates --project-directory <root> -f docker-compose.yml -f docker-compose.host-ollama.yml build api`
  then `… up -d --no-deps api`.

## References
- Related session: [sessions/2026-06-11-venue-image-routing-bing-and-goong-freshen.md](../sessions/2026-06-11-venue-image-routing-bing-and-goong-freshen.md)
- Bing Images endpoint: `https://www.bing.com/images/search?q=<query>` (keyless; `murl` JSON in HTML)
