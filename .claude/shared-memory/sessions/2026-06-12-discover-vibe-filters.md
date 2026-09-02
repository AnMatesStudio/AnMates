# Discover vibe chips → real multi-select filters (live-verified by screenshot)

**Date:** 2026-06-12 · **Owner:** main-assistant · **Status:** code done + live-verified via browser screenshots, PENDING explicit user "ok"

## TL;DR
User (after confirming the Discovery screen looks good) asked: "làm cho các filter (máy lạnh, vỉa hè, etc.) này hoạt động." The vibe chips (❄️ Máy lạnh / 🌿 Vỉa hè / 🔇 Khuất hẻm / ✨ Sang chảnh / 🌙 Ngồi khuya) were **visual-only toggles** (`_activeVibes` pre-selected 'Máy lạnh' but never filtered). Made them functional multi-select (union) filters over OSM ambiance tags + name/cuisine/amenity heuristics.

## Context / why heuristic
OSM tags ambiance sparsely in VN, so a strict tag-only filter would empty the list. Each vibe therefore combines whatever real OSM tags exist with name/cuisine/amenity fallbacks. Default changed to **no vibe selected** so the initial list stays the full nearby browse (matches what the user already liked); tapping a chip narrows.

## Solution
**`anmates_flutter/lib/services/places_service.dart`** — `OsmPlace` gains 3 optional fields parsed from OSM tags: `airConditioning` (air_conditioning), `outdoorSeating` (outdoor_seating), `stars`. Added to constructor, `fromJson` (Overpass), and carried through `mergeFill`. `fromBackend` (TomTom) leaves them null. Additive → existing call sites/tests unaffected.

**`anmates_flutter/lib/views/discover/discover_view.dart`**
- Import `../../utils/opening_hours.dart` (reuse `parseOpeningHours` for late-night).
- `_activeVibes` default `{}` (was `{'❄️ Máy lạnh'}`).
- `_filteredPlaces`: new union filter — keep a venue if it matches ANY active vibe.
- NEW `_matchesVibe(OsmPlace, vibe)`:
  - **Máy lạnh**: air_conditioning=yes → true; =no/outdoor only → false; else amenity restaurant|cafe, buffet/coffee/japanese/korean.
  - **Vỉa hè**: outdoor_seating yes/only → true; air_conditioning=yes → false; else fast_food, street_food, name ốc/nướng/bún/phở/bánh/vỉa hè/lề đường.
  - **Khuất hẻm**: name/addr contains hẻm/ngõ/ngách/kiệt, or addr matches `\d+/\d+` (alley-style numbering).
  - **Sang chảnh**: stars set → true; else cuisine french/japanese/sushi/steak/italian/fine_dining, name fine/luxury/sang/rooftop/sky/lounge/signature/premium.
  - **Ngồi khuya**: `_opensLate(openingHours)` (parseOpeningHours probed at 23:00 → isOpen; 24/7 counts) → true; else amenity bar, name khuya/đêm/night/24h/24/24/bar/pub/beer.
- NEW `_opensLate(hours)` reuses the existing OSM hours parser at a 23:00 probe; unknown hours → false (honest).
- Vibe chip `onTap` now also resets `_visibleCount = _kPageSize` (re-page on filter change).
- Empty-state copy is filter-aware ("Không có quán hợp vibe này quanh đây — thử bỏ bớt filter").
- "nearest" 🔥 marker gated on `_activeVibes.isEmpty` too.

## Verification (live + static)
- Rebuilt `flutter_web` image (compiles clean) + restarted; drove **host Chrome via Playwright** (`.dev-e2e/shots/shot_vibe.js`), dev session + geolocation HCMC D1, captured 4 states:
  - **01_all** — no chip active, full list (Lotteria, Cung Đình Rex, Cafe Highlands).
  - **02_viahe** — Vỉa hè → fast-food/street only (Lotteria branches, KFC).
  - **03_ngoikhuya** — Ngồi khuya → bars + open-late (Quán Bar Saigon Saigon, Quán Bar Trung Tâm, Nhà Hàng Alibaba "Đang mở").
  - **04_sangchanh** — Sang chảnh → upscale (Cà Phê The Refinery, Mimi Ultra Lounge, Alibaba).
  - Screenshots copied to `C:\AnM\AnMates\screenshots\0*.png` (originals in `.dev-e2e/shots/`).
- `flutter analyze lib/views/discover/discover_view.dart lib/services/places_service.dart` → 0 errors/warnings (5 pre-existing `curly_braces` infos in the untouched `emoji` getter).
- `flutter test test/places_merge_test.dart` → 4/4 PASS (OsmPlace additions don't break merge/dedup).

## Env notes (how the live run was set up — reusable)
- Stack: `AI_SEARCH_URL="" docker compose up -d flutter_web` brings up db→ollama→ai_venue_search→api→flutter_web (api enrich disabled → detail uses fast Bing gallery). ollama_pull NOT triggered (no 2GB model download).
- The prebuilt **api image was stale** (served `/venues/image` behind JWT). Current source registers it public (main.go:235 before jwt group at :249) → **rebuilt api** to restore public image proxy (else `Image.network` thumbnails 401 → placeholders). Worth a redeploy check on any stale environment.
- Web image bakes `localhost:8080`; DEV_MODE=true + DEV_BYPASS_SECRET=dev-local-2026 enable `/api/v1/auth/dev-login`. Splash re-validates onboarding_done via getProfile, so the dev user's DB `onboarding_done` was set true (UPDATE users … WHERE phone='+84999000001').
- CanvasKit (no DOM) → chips tapped by coordinate (414×896 viewport, vibe rows ~y=376/428).

## Open follow-ups
- Heuristics are best-effort (OSM ambiance coverage is thin); could sharpen "Máy lạnh"/"Khuất hẻm" once richer source data exists.
- Genre cards (Lẩu/Nướng/Cafe) were already wired (`_matchesGenre`); untouched.
- When user confirms → fold into the next resolution (likely R-008 venue-discovery bundle), tags: discover, vibe-filter, osm, overpass, flutter.

## Follow-up fix (same day) — Lotteria mis-bucketed as "Vỉa hè"
User: "tại sao lotteria lại là vỉa hè". Root cause: `_matchesVibe` Vỉa hè mapped `amenity == 'fast_food'` → true, but OSM tags A/C international chains (Lotteria/KFC/McDonald's…) as fast_food too → they wrongly matched street-food. Fix: added `_indoorChains` denylist + `_isIndoorChain(name)`; Vỉa hè now early-returns false for chains (and air_conditioning=yes); Máy lạnh early-returns true for chains. Non-chain `fast_food` (local stalls) still count as Vỉa hè. Verified LIVE (had to `--force-recreate` flutter_web — a plain `up -d` kept the old container): **05_viahe_fixed.png** = Vỉa hè now Cửa Hàng Fresh Donuts / Phở Số 1 Hà Nội / Thức Ăn Dinh Dưỡng (no Lotteria); **06_maylanh.png** = Máy lạnh now includes Lotteria + Cung Đình Rex + Cafe Highlands. `flutter analyze discover_view.dart` → No issues found. Gotcha noted: image-request network log is unreliable for asserting list membership (responses land after reset → false positives); trust screenshots. Deploy gotcha: `docker compose up -d --force-recreate --no-deps flutter_web` after a rebuild.

## Follow-up 2 (same day) — Discovery thumbnails blank ("sao ba quán đầu không có hình")
The 3 Vỉa-hè venues showed empty thumbnail slots. Diagnosis: NOT a bug — backend returns photos (count=5, real 86–128KB JPEGs for all three). Real cause = the image cache is OFF (`VENUE_IMAGE_CACHE_TTL=0`, set by the enrichment realtime work), so every thumbnail does a COLD live Bing scrape; measured **11.8s** cold vs **0.36s** cached for the same query. The venues were freshly revealed by the filter tap → not loaded yet when captured.
Fixes:
1. **.env `VENUE_IMAGE_CACHE_TTL=10m`** — repeat thumbnail fetches now ~0.36s (33×). Only affects the keyless Bing image path (`services/venue_image.go` ImageSearcher); the agentic detail-screen enrichment stays realtime/uncached.
2. **`widgets/venue_thumbnail.dart`** loading visual moved `loadingBuilder` → `frameBuilder(frame == null)`. KEY insight: `loadingBuilder`'s `progress` stays null while the server holds the connection (no bytes yet during the scrape) → it returned the (opacity-0) child → blank slot identical to "no photo". `frame == null` covers the entire pending+decode window → shows a berry `CircularProgressIndicator` over the PhotoSlot, so loading reads as loading. (First white-spinner attempt was invisible on PhotoSlot's pale wisteria→mint gradient → switched to `AppColors.berry`.)
Verified: cache 11.8s→0.36s (curl timing); **10_spinner.png** (berry spinners in the slots) → **11_after.png** (Lotteria/Cung Đình Rex/Cafe Highlands photos loaded); `flutter analyze venue_thumbnail.dart` → No issues found.
Open perf item: first-ever cold scrape is ~10s+ (partly the concurrent reachability-probe in venue_image.go) — cache only helps repeats; spinner makes the wait legible. Could pre-warm or trim the probe later.

## Follow-up 3 (same day) — Backfill opening_hours from TomTom ("bổ sung thêm từ nguồn khác")
2 bars showed no Đang-mở badge because OSM lacks their `opening_hours` (confirmed via Overpass: Alibaba has `Mo-Su 09:00-00:00`, the 2 bars = NONE). User asked to add another source.
**Key finding — every keyless web-text source is blocked from this environment:** Bing web scrape returns 0 `b_algo` (the existing `/venues/reviews` endpoint returns empty even for Pizza 4P's); the sidecar crawl (`/enrich`) returns 0 pages locally (Google headless CAPTCHA + Bing httpx empty; ollama model not loaded anyway). Only the Bing **images** scrape works. So mirroring `venue_reviews.go` for hours would return nothing.
**Realistic source = TomTom** (already integrated, VN-legal, not Google Maps). `tomtom.go` had an `OpeningHours` field but never requested/parsed it. Implemented (Go-only): `Nearby` now sends `openingHours=nextSevenDays`, parses `poi.openingHours.timeRanges`, and `tomtomHoursToOSM()` converts to an OSM-style string ("Mo 09:00-22:00; …", overnight bars → wrap "21:00-04:00"). Flows through the existing `/venues/nearby → OsmPlace.fromBackend → mergeNearbyPlaces/mergeFill`, so the list badge backfills with **no Flutter change**. Empty → "" (no fabricated badge).
Verified: go build/vet GREEN, `tomtom_test.go` 6/6 PASS, golangci-lint v2.12.2 → 0 issues.
**Blocker for live demo:** `TOMTOM_API_KEY` is empty locally (a GH deploy secret, still pending creation). Feature activates the instant a free key is in `.env` → restart api. Coverage caveat: TomTom may not have tiny bars → those stay honestly badgeless. If user pastes a key I can verify live + screenshot.
