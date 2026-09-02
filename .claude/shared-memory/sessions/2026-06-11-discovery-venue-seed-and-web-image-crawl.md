# Session: Discovery exact-venue search seed + web-page image crawl

**Date:** 2026-06-11
**Owner:** main-assistant
**Status:** Completed (code-only; Go build/vet/test GREEN, sidecar pytest GREEN, `flutter analyze` clean; network chain validated end-to-end for the named venue) — **pending live user verify**

## Goal (from user)
1. "làm cho thanh search trong discovery trả về được quán **'lẩu bò giáo toàn'**" — the
   exact-named venue search must reliably return that quán.
2. "lấy hình ảnh bằng cách search các trang web vào cào hình về để show trong chi tiết" —
   get the photos by searching the web and **scraping images off the pages**, shown in detail.

## Root-cause findings (verified with live geocoder/search probes)
- **OSM/Photon/Nominatim do NOT have "Lẩu Bò Giáo Toàn".** Photon returns unrelated POIs
  (matches on "giáo"/"bò" → Phú Giáo etc.), Nominatim returns nothing. So a "geocode the
  venue name" seed can't place it — and the `_enrich_coords` 6 km radius guard zeroes its
  coords. The venue can only surface via **web-search → LLM structurer**, which is
  probabilistic (already documented 2026-06-08 QA: "EXACT named-venue search UNRELIABLE…
  returned the exact quán once, else other venues").
- **DuckDuckGo `i.js` image search is blocked from this network** (`If this error persists…`)
  and **Bing image search mangles the Vietnamese multi-word name into noise** (matches
  "E10 xăng", "Sony ZV-E10", "Letter L", Rubik notation). Generic image-search engines are
  unusable for this obscure venue.
- **DuckDuckGo Lite *web* search works** and returns the venue's blog/review pages
  (mia.vn, ghiensaigon.com, riviu.vn, vnexpress…). **mia.vn exposes `og:image` + content
  photos literally named `lau-bo-giao-toan-*.jpg`**, and those URLs serve real JPEG bytes
  (103 KB / 260 KB) with our desktop UA. → crawling the venue's own web pages is both what
  the user asked ("cào hình về") and far more reliable than image search.

## Part 1 — deterministic query-seed (sidecar)
**File: `ai-venue-search/ai_venue_search/service.py`**
- `suggest()` free-text path (`req.query`) now:
  - wraps the structurer call so an LLM failure on a *search* (not concierge) degrades to
    empty picks instead of a 502 — the seed is the safety net.
  - after enrich, injects a **deterministic seed card** for the typed name when it
    *looks like a venue name* (`_looks_like_venue_name`: ≥2 words or ≥8 chars — bare dishes
    like "phở" are left to the structurer) **and** no structured pick already matches it
    (`_name_matches`: substring or ≥(n−1) token overlap). Seed is `_titlecase`d
    ("lẩu bò giáo toàn" → "Lẩu Bò Giáo Toàn"), `reason="Quán bạn vừa tìm"`.
  - seed coords are **0/0 unless** we know the user's location AND a geocode lands inside
    the meet-in-the-middle radius (avoids a wrong far-away pin; card still shows w/o a pin).
  - geocode is only attempted when the seed is actually needed (no waste when the LLM
    already nailed it).
- New pure helpers `_looks_like_venue_name`, `_titlecase`, `_norm_name`, `_name_matches`.
- `_ensure_query_venue` is a pure static assembler (prepend seed, trim to `limit`).
- **NEW `tests/test_query_seed.py`** — 6 tests over the pure helpers + assembler.

Net effect: searching the exact name **always** returns a card for it (first), regardless
of LLM availability/relevance; dish/genre searches are unchanged; concierge path untouched.

## Part 2 — web-page image crawl + multi-image gallery
**Backend (anmates-api):**
- **`services/venue_image.go` — resolver rewritten** from DDG image-search to a web-page
  crawl: `ResolveURLs(q)` = DDG-Lite web search (`POST lite.duckduckgo.com/lite/`) →
  `parseResultURLs` (unwraps `/l/?uddg=`, skips social/shopping/maps domains) → fetch top
  pages → `extractImages` (og:image first, then `<img src|data-src …>.jpg/png/webp`,
  absolutized vs the page, junk-filtered: logo/icon/avatar/banner/ads/sprite/placeholder).
  Returns up to 6 photos (≤4/page), cached 24 h (30 min on miss). `ResolveURL`/`ResolveURLAt`
  added; byte-proxy unchanged.
- **`handlers/venue_image.go`** — `Serve` accepts `i` (gallery index → `ResolveURLAt`);
  new **`Count`** → `GET /api/v1/venues/images?q=` returns `{count}` (JSON envelope).
- **`main.go`** — registered `app.Get("/api/v1/venues/images", venueImageH.Count)`.
- **`services/venue_image_test.go` — replaced** (old parseVQD/parseFirstImageURL tests
  gone): `normalizeResultURL`, `parseResultURLs`, `extractImages` (+attr-order variant),
  `isJunkImage`, `absolutizeURL`.

**Frontend (anmates_flutter):**
- `services/api_client.dart` — `imageUrl(query, {index})` appends `&i=`.
- **NEW `services/venue_image_service.dart`** — `count(query)` (→ 0 on error).
- `widgets/venue_thumbnail.dart` — `index` param, passed to `imageUrl`.
- `views/discover/venue_detail_view.dart` — hero is now a **swipeable `PageView` gallery**
  (`_imageCount` from the count endpoint; dot indicators; falls back to a single image when
  count ≤ 1; scrim wrapped in `IgnorePointer` so swipe works).

## Verification done
- Go (golang:1.25, mod-cache vol): `go build ./...` **BUILD_OK**, `go vet ./services ./handlers`
  **VET_OK**, `go test ./services ./handlers` **ok** (incl. new parse tests).
- Sidecar (python:3.12-slim): `pytest tests/test_query_seed.py tests/test_build_query.py`
  → **12 passed**.
- `flutter analyze` on the 5 changed Dart files → **No issues found**.
- Network chain (curl, our UA) for "Lẩu Bò Giáo Toàn": DDG-Lite → mia.vn → og:image +
  `lau-bo-giao-toan-*.jpg`; both image URLs return **HTTP 200 image/jpeg** (103 KB / 260 KB).

## Verification PENDING (user)
1. `./start.sh` (rebuilds api + sidecar) → Discovery at http://127.0.0.1:54180 → search
   **"lẩu bò giáo toàn"** → confirm the quán card appears (first), tap → 12.1 detail with a
   **swipeable photo gallery** of real venue images.
2. Confirm dish search (e.g. "lẩu dê") still returns multiple venues (seed suppressed).

## Known limitations / follow-ups
- Seed coords are 0/0 for venues OSM can't place (most obscure quán) → the card shows but
  the detail map-pin/directions are inactive for it (photos + facts still show).
- Image relevance depends on the venue having crawlable blog pages; login-walled/JS-only
  sites (facebook, some review sites returning 0 bytes) are skipped → fewer/zero photos →
  graceful placeholder.
- DDG-Lite could rate-limit/block from datacenter IPs (Cloud Run) like the old image path;
  works from the dev machine. If prod coverage matters, add a keyed search/image fallback.
- When user confirms → migrate to **R-007** (pairs with the 2026-06-10 location-aware
  ranking + thumbnails/detail sessions — all Discovery web-search work).
