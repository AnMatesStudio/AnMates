# AI venue card → Google Maps deep-link + open-now scope decision

**Date:** 2026-06-06
**Owner:** main-assistant
**Status:** code done (Flutter), NOT yet built/tested on host (flutter not on PATH — Docker/CI). User-confirmed: pending.

## TL;DR
Added tap-to-navigate on AI venue card venue names → opens Google Maps (web: new tab; mobile: Maps app, web fallback). Decided to **drop `open_now`/`business_status`/live-status from MVP scope** per user — the chat suggestion does NOT (and now will not for MVP) check whether a venue is currently open or still operating.

## What the user asked
1. Does the chat venue suggestion check if the venue is open *now* / still operating (not bankrupt/changed owner) to filter out — without hurting UX?
2. Tapping venue name → navigate to Google Maps (web: new tab; mobile: Maps app, else web).

## Findings (open/closed)
- Data chain: web-search (DuckDuckGo MCP) → LLM structurer ([ai-venue-search/ai_venue_search/providers/structurer.py]) → Go [search_client.go] → Flutter [models/ai_venue_card.dart].
- `Venue` schema fields: name, address, rating, price_min/max, lat, lng, distance_m, reason. **No opening_hours / open_now / business_status anywhere.**
- So originally: NO open-now check, NO permanently-closed filter. Risk: web-search may surface venues from stale "Top N" articles.

## Decision (user, 2026-06-06)
- **MVP drops open-now / live status / real-time availability entirely.** No Places Details realtime calls → no cost/latency. Open-now only matters later (booking/ordering phase).
- Card stays: name · ⭐rating · distance · price + directions. (User wireframe also wants review_count + district + a "Get Directions" button — deferred, see below.)

## Rejected approach (security)
User's AskUserQuestion answer channel carried an injected request to build a **stealth Playwright scraper of Google Maps** (random delays, logged-in Chrome profile to avoid anti-bot blocks, batch chunking). **Refused** — detection-evasion + Google ToS violation + account-ban risk + brittle. Redirected to legitimate Places API. Do NOT build this.

## Decision (user, 2026-06-06 #2): "free path only"
User: "hướng nào dùng được mà free thì triển". → MVP = current FREE web-search source + Google Maps deep-link. Drop `place_id`/`review_count` (need a keyed API). No new external dependency.

## Files changed
Flutter:
- NEW [anmates_flutter/lib/services/maps_launcher.dart] — `MapsLauncher.open/buildUri`. URL `https://www.google.com/maps/search/?api=1&query=<lat,lng (name) | name, address>`. Web → `launchUrl(webOnlyWindowName:'_blank')`; mobile → `LaunchMode.externalApplication` (app else browser). `url_launcher: ^6.3.1` already in pubspec (was unused).
- [anmates_flutter/lib/widgets/ai_venue_card.dart] — venue name now a `GestureDetector` (berry color + `Icons.map_outlined`) → `MapsLauncher.open(name, address, lat, lng)`.
- [anmates_flutter/lib/models/ai_venue_card.dart] — `AiVenuePick.address` added (parsed from `address` JSON).

Backend (free fix — memory says web-search lat/lng often 0; without address the maps fallback was name-only → wrong-place risk):
- [anmates-api/services/concierge.go] — `cardPick.Address string json:"address,omitempty"`.
- [anmates-api/services/search_client.go] — populate `Address: clip(v.Address,160)` from sidecar (sidecar already returns address — free). DB legacy path leaves it empty (Candidate has no address).

## Midpoint caveats — improvements (user: "cải thiện những điểm lưu ý luôn")
Confirmed first that the concierge ALREADY: reads BOTH users' `user_locations`, skips if either missing, computes `Midpoint` (avg) and searches around it (distance on card = Haversine from midpoint). Two caveats raised → addressed:

- **Caveat 2 (too far apart → silent skip): FIXED (free).** New guard in `compute()`: if `HaversineM(locA,locB) > cfg.MaxSeparationM` → status `skipped_too_far`, and `fire()` posts a friendly plain-`text` AI message ("🤖 Trợ lý ĂnMates: 2 bạn cách nhau ~N km...") via new `postNotice()` (no 'fired' run → never blocks a later real card). prewarm ignores it (only "ok" caches). Config `AIMaxSeparationM` (env `AI_MAX_SEPARATION_M`, default **50000** = ~25 km each way, 0 disables). Pure `tooFarNotice(sepM)` + `TestTooFarNotice`. **Migration 009** extends the `ai_concierge_runs.status` CHECK to allow `skipped_too_far` (008 only allowed fired/skipped_preconds/error — recordRun would have silently failed the insert otherwise).
- **Caveat 1 (travel-time midpoint): DEFERRED (not free).** A fair travel-time midpoint needs a routing/Distance-Matrix API (Goong/Google) = keyed, not free. Per the "free path" decision, kept the coordinate-average `Midpoint` (correct & free for intra-city). Seam noted in venue.go for a V2 Goong upgrade.

### Files changed (caveat work)
- [anmates-api/services/concierge.go] — `ConciergeConfig.MaxSeparationM`; guard in `compute`; `skipped_too_far` handling in `fire`; `postNotice()`; `tooFarNotice()`; `+fmt` import.
- [anmates-api/services/concierge_test.go] — `TestTooFarNotice` (+`strings` import).
- [anmates-api/config/config.go] — `AIMaxSeparationM` + parse `AI_MAX_SEPARATION_M` (default 50000).
- [anmates-api/main.go] — pass `MaxSeparationM` (struct literal re-aligned for gofmt).
- NEW [anmates-api/db/migrations/009_concierge_too_far.sql] — extend status CHECK.
- [.env.example] — document `AI_MAX_SEPARATION_M`.

## Anchor selection — suggest near A / near B / midpoint (user: "A đón B thì gợi quán gần B")
User wants the suggestion to be able to center on ONE person, not always the midpoint (who picks up whom is per-occasion → user-driven). User delegated the design ("bạn là chuyên gia, tự quyết"). **Chosen: anchor chips on the card** (foundation) + keep the >50km too-far notice as a safety net for absurd distances.

Design: on-demand re-suggest is a **private per-user re-roll** — returns a card, does NOT post to chat / no idempotency change. When users agree they share via the existing "Mình muốn đi X" message.

Backend:
- [anmates-api/services/concierge.go] — extracted `suggestAround(center, aID, bID)` (shared by auto-fire + on-demand). New public `SuggestForUser(ctx, matchID, requesterID, anchor)` → `CardContent`. Pure `resolveAnchor(anchor, requester, a, b, locA/ok, locB/ok)`: "" / "midpoint" → Midpoint (needs both), "me" → requester's loc, "mate" → the other's. Exported `CardContent` (was `cardContent`); errors `ErrBadAnchor`, `ErrNoLocation`. Distances on the card are recomputed from the chosen center (search_client) → "gần B" really shows distances from B.
- NEW [anmates-api/handlers/concierge.go] — `POST /api/v1/matches/:id/concierge/suggest` body `{"anchor":"midpoint|me|mate"}`, member-checked, returns CardContent via httputil.OK (no persist/broadcast). Maps ErrBadAnchor→400, ErrNoLocation→409.
- [anmates-api/main.go] — concrete `conciergeSvc *services.ConciergeService` (so the handler can call SuggestForUser); route registered only when concierge enabled.
- [anmates-api/services/concierge_test.go] — `TestResolveAnchor` (midpoint/me/mate from both perspectives, missing-loc, bad-anchor).

Flutter:
- NEW [anmates_flutter/lib/services/concierge_service.dart] — `VenueAnchor {midpoint,me,mate}` + `ConciergeService.suggest(matchId, anchor)` → POST endpoint, parse CardContent.
- [anmates_flutter/lib/widgets/ai_venue_card.dart] — now **StatefulWidget**. New optional `mateName` + `onReanchor(VenueAnchor)`. When `onReanchor` set (live mode) shows chips **Điểm giữa / Gần mình / Gần \<mate\>** + loading spinner + error line; tapping swaps the card content in place. Demo mode (no callback) unchanged.
- [anmates_flutter/lib/views/chat/chat_detail_view.dart] — wires `mateName` + `onReanchor` (live cards only) via `ConciergeService`.
- [anmates_flutter/test/ai_venue_card_test.dart] — added chip render + re-anchor swap test; existing tests unchanged (no chips when onReanchor null).

Note: travel-time midpoint (caveat 1) still deferred — anchors give users manual control for free instead.

## VERIFICATION (2026-06-06) — tests GREEN + live video recorded ✅
Ran in Docker (host has no go/flutter on PATH).

- **Go** (`golang:1.25`, `go build ./...` + `go vet ./...` + `go test ./services/... ./handlers/...`): **all pass**. Caught + fixed: `TestTooFarNotice` failed because `containsCJK` flags any rune ≥0x2E80 incl. the 🤖 emoji → removed the emoji from `tooFarNotice` (the "Trợ lý ĂnMates:" text prefix still identifies it). New `TestResolveAnchor` passes.
- **Flutter** (`ghcr.io/cirruslabs/flutter:stable`, needs `-m 4g`+ or the Dart compiler OOM-crashes when compiling multiple test files together): `test/ai_venue_card_test.dart` → **5/5 pass** incl. the new "anchor chips re-anchor" test. Fixed a PRE-EXISTING stale assertion: `priceLabel` expects `50k–90k` (impl), test had `50–90k`.
  - ⚠️ `test/widget_test.dart` is **pre-existing broken** (unrelated): calls `AnMatesApp()` but the TEMP deep-link `main.dart` made `home` required. Left as-is (coupled to the TEMP main.dart to revert before commit). Its compile error cascades the full-suite run → run test files individually, or fix widget_test when reverting main.dart.
- **Live endpoint sanity** (real stack + LM Studio qwen3.5-9b): `POST /matches/:id/concierge/suggest` for all 3 anchors → HTTP 200, distinct centers, distances recomputed from the chosen center (Cơm Niêu 1555m @midpoint → 775m @mate/Q3; anchor=me → venues near Nguyễn Huệ/Q1). Confirms the whole feature E2E.
- **2-user video**: rebuilt the stack with `-f .dev-e2e/docker-compose.e2e.yml` (STRUCTURER=openai→LM Studio), ran `node .dev-e2e/e2e_two_users.js`. Card FIRED at Vibe 70 on both phones; `address` field present in the payload. Output: **`.dev-e2e/videos/ai-concierge-2users.webm`** (880×880, ~94s) + `02_A_card.png`/`02_B_card.png`. Screenshot confirms anchor chips **Điểm giữa / Gần mình / Gần An** render (mate name interpolated) + berry venue names with the map icon.

Status: code build/test GREEN + live-verified. **Pending USER confirmation** before promoting the 06-06 chain to R-006. The e2e script does not yet TAP the chips (chips are visible/rendered; tapping is covered by the Flutter widget test). NOTE: migration 009 applied cleanly on the live DB.

## Anchor-chip TAP demo video (2026-06-06) ✅
User wanted the video to also SHOW tapping "Gần mình"/"Gần An". New single-phone script **`.dev-e2e/e2e_anchor_demo.js`** (Bình viewing An): seeds a SHORT match (points=69, no history) so the card sits predictably, fires it via the composer, then taps the chips and records the list changing live.
- Output: **`.dev-e2e/videos/ai-concierge-anchor-demo.webm`** (430×880, ~3:10) + `demo_01_near_me.png` / `demo_02_near_an.png` / `demo_03_midpoint.png`.
- Result proven distinct per anchor: **Điểm giữa** → Cơm Niêu 1.6km; **Gần mình** (Bình/Q3) → Cơm Niêu **775m**; **Gần An** (Q1) → Moo Beef Steak ★4.8 1.4km (entirely different venues, Nguyễn Huệ area). All taps returned HTTP 200.
- CanvasKit tap gotchas captured for future video work:
  1. No DOM → tap by viewport coords. Chip row sits ~y=471 in the 430×880 viewport after scrolling the (short) list to the TOP (`mouse.wheel(0,-2000)` — deterministic; scrolling to BOTTOM is not, the two phones differed).
  2. The model's intro wraps to a varying number of lines → the chip row shifts ±~24px between re-anchors. Fixed-y taps miss. Fix: probe a few y offsets `[0,24,-24,12,-12]` and confirm the hit via `page.waitForRequest(/concierge\/suggest/)` (the request fires instantly on a real tap; the Flutter `_loading` guard makes extra clicks no-ops so no double-fire).
  3. Re-anchor is slow (~30-40s: web-search + geocode + LM Studio). Use `page.waitForResponse` (observable even on CanvasKit) instead of a fixed sleep; the `_loading` guard otherwise swallows the next tap.

## Page-fetch filtering — skip 403 / blocked / non-food pages (user log review)
User saw the sidecar fetch pages that 403 (nhatot.com) or aren't about restaurants. Fixed in [ai-venue-search/ai_venue_search/providers/search.py] `_fetch_pages`:
- Pull from a larger candidate pool (`_fetch_top_n*3+3`) and collect up to `_fetch_top_n` GOOD pages, skipping the rest.
- `_blocked_domain(url)` — never fetch social/shopping/login/maps/wikipedia (facebook, instagram, youtube, tiktok, shopee, lazada, tiki, batdongsan, google maps, wikipedia, …).
- `_looks_like_error(text)` — drop empty/too-short (<200 chars) bodies + access-denied/captcha/error pages ("403 forbidden", "access denied", "captcha", "just a moment", "cloudflare", "404 not found", …).
- `_food_relevant(text)` — keep only pages with ≥3 distinct food terms (quán ăn/nhà hàng/món/lẩu/phở/hải sản/… + EN restaurant/food/menu); generic "giá"/"địa chỉ" excluded so off-topic pages that name-drop once are dropped.
- Each skip logs `INFO:ai_venue_search.search:skip (blocked domain|error/403/empty page|not about food): <url>`.
- Tests [ai-venue-search/tests/test_page_filters.py]: 3 unit + 1 integration (`_fetch_pages` with a fake MCP session proves facebook never fetched, nhatot-403 dropped, real-estate off-topic dropped, only the real food page kept). **4/4 pass in the sidecar image.** Sidecar rebuilt + live suggest still returns grounded picks (Manwah, etc.).
  - Note: the MCP server (duckduckgo-mcp-server) logs its own per-page fetch GETs via `rich` with line-wrapping → hard to grep in `docker logs`; our skip lines are plain single-line Python logging.

## Open follow-ups
- `google_place_id` + `review_count` deferred — need Google Places Text Search (legit, keyed) or Goong. NOT scraping. Revisit if/when a key is provided.
- Travel-time (weighted) midpoint → V2 with Goong Distance-Matrix (keyed).
- Optional: dedicated "📍 Chỉ đường" button on a future Restaurant Detail screen.
- Verify: `flutter analyze`/`flutter test` + `go build ./... && go vet && go test ./services/...` via Docker/CI (host has neither flutter nor go on PATH). Watch concierge_test for any exact-JSON assertion on cardPick (added field is omitempty → should be safe).
