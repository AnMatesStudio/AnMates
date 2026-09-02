# Session: Venue web-search thumbnails + Chi tiết quán detail screen (12.1)

**Date:** 2026-06-10
**Owner:** main-assistant
**Status:** Completed (code-only; backend `go build`/`vet`/`test` GREEN, `flutter analyze` clean on changed files) — **pending live user verify**

## Goal (from user)
1. "search hình thumb-nail của quán đó trên web và render vào list quán" — fetch a real
   web photo per venue and render it into the Discovery list (replace the `📸` placeholder).
2. "khi click vào quán ở list bên dưới thì show 12.1_ChiTietQuan, nhớ implement UI luôn" —
   tapping a list row opens a venue-detail screen built to the `12.1_ChiTietQuan.png` design.

## TL;DR
- New **public, un-rate-limited Go image-proxy** `GET /api/v1/venues/image?q=<name>` that does a
  **keyless DuckDuckGo image search server-side** and streams the photo bytes back (browser-cached
  24h). Flutter renders it straight with `Image.network` — no CORS/token headaches because it only
  ever talks to our own origin.
- New reusable **`VenueThumbnail`** Flutter widget (loads photo, falls back to the existing
  `PhotoSlot` gradient on loading / 404 / error).
- New **`VenueDetailView`** (Screen 12.1) — light-theme hero + venue facts + social-proof + match
  card + sticky "＋ Wishlist / Tìm Mate ăn cùng" bar. Tapping any Discovery row now opens it
  (previously opened Google Maps).

## Files changed / added
### Backend (anmates-api)
- **NEW `services/venue_image.go`** — `ImageSearcher`: `ResolveURL(ctx, q)` → DDG `vqd` page scrape
  then `i.js` JSON parse; in-memory cache (24h hit / 30min miss). Pure parse fns `parseVQD`,
  `parseFirstImageURL` (prefers `thumbnail` over full `image`). Exported `ImageBrowserUA`.
- **NEW `handlers/venue_image.go`** — `VenueImage.Serve`: validates `q`, resolves URL, proxies the
  remote bytes (5 MiB cap, `image/*` content-type, `Cache-Control: public, max-age=86400`). Returns
  400 (short q) / 404 (no photo) / 502 (upstream fail) so the client falls back to a placeholder.
- **NEW `services/venue_image_test.go`** — table tests for `parseVQD` + `parseFirstImageURL`.
- **`main.go`** — `app.Get("/api/v1/venues/image", venueImageH.Serve)` registered on the **root app**
  (not the `/api/v1` rate-limited group, not behind `jwtMW`). Always on, independent of AI sidecar.

### Frontend (anmates_flutter)
- **`services/api_client.dart`** — `static String imageUrl(String query)` → absolute proxy URL.
- **NEW `widgets/venue_thumbnail.dart`** — `VenueThumbnail` (query/width/height/radius/fit/placeholder);
  `Image.network` + `loadingBuilder`/`frameBuilder` fade-in + `errorBuilder` → `PhotoSlot`.
- **NEW `views/discover/venue_detail_view.dart`** — `VenueDetailData` view-model with
  `.fromOsm(...)` and `.fromResult(...)` factories + `VenueDetailView` screen.
- **`views/discover/discover_view.dart`** — both `_RestaurantRow` (OSM) and `_VenueResultRow`
  (web-search) now render `VenueThumbnail` and `Navigator.push(VenueDetailView(...))` on tap; rows
  gained `area` + `greetingName` params; `_imageArea` getter ("Gần bạn" → "TP.HCM"); dropped the
  now-unused `maps_launcher` import (MapsLauncher now lives in the detail view's directions button).

## Design fidelity vs. honesty (12.1)
OSM/web-search venues lack rating / review-count / price / a curated description, so to avoid
presenting fake precise stats as real:
- Meta row shows only **real** segments (⭐rating + price only when the web-search result actually
  has them; otherwise just the distance). OSM rows → distance only.
- Social-proof banner copy softened from "15 người…" to **"Nhiều người quanh đây cũng đang thèm
  quán này"** (no fabricated count).
- "VỀ QUÁN" description = web-search reason if present, else composed from real address / hours /
  phone, else a soft generic line.
- Match card uses the **signed-in user's name** ("Hợp gu {name}") instead of a hardcoded "Vy"; the
  `%` is a **deterministic placeholder heuristic** (`82 + hash%16`) with checks derived from real
  signals (near / open / first tag). Clearly marked `// placeholder … until the real vibe-match
  backend lands`.
- Taste chips derived from the venue's cuisine/amenity tags.

## CTAs wired
- **＋ Wishlist** (and top-bar ♥) → `WishlistService().add(name, category)` where category is mapped
  to backend AllowedCategories (cafe/lau/bbq/pho/bun/com/other) from the venue tags; snackbar + saved
  state.
- **Tìm Mate ăn cùng** → `Navigator.push(SwipeView())` (Ăn Match flow).
- Top-bar near_me icon → `MapsLauncher.open(...)` (directions).

## Verification done
- Go (golang:1.25 container, fresh mod cache volume): `go build ./...` **BUILD_OK**,
  `go vet ./services ./handlers` clean, `go test ./services ./handlers` **ok** (incl. new
  parse tests).
- `flutter analyze` (C:\src\flutter) on the 4 changed/added Flutter files → **No issues found**.

## Verification PENDING (user)
1. `./start.sh` (rebuilds api image with the new endpoint) → open Discovery at
   http://127.0.0.1:54180 → confirm real photos render in "HOT QUANH BẠN"; tap a row → 12.1 screen.
2. Confirm "＋ Wishlist" persists (appears in Wishlist tab) and "Tìm Mate ăn cùng" opens SwipeView.

## Known limitations / follow-ups
- **DuckDuckGo may block datacenter IPs** → on Cloud Run the proxy can return 404 and rows keep the
  placeholder (graceful). Works from a residential dev machine. If prod coverage matters, swap the
  resolver for a keyed image API (Bing/SerpAPI) or precompute photos at ingest.
- Image relevance is best-effort (first DDG image result for "name + area"); occasionally generic.
- Match `%` + social-proof are placeholder UI until the vibe-match backend exists.
- When user confirms → migrate to **R-007** (this + the location-aware ranking session may pair up).
