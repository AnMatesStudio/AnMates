# 2026-06-05 — AI Concierge LIVE E2E (web-search) + video evidence

## TL;DR
Ran the **real** AI Concierge flow end-to-end on the local Docker stack and captured a
**video** of user A's Flutter chat receiving a real `ai_venue_card` after the Vibe crossed 70.
Real pipeline: DuckDuckGo MCP web-search → LM Studio `qwen/qwen3.5-9b` structurer → geocode →
Go concierge fires → WebSocket broadcast → Flutter renders the card. **It works.**

Evidence:
- `.dev-e2e/ai-concierge-live-test.webm` (744 KB) — screen-recorded Flutter UI
- `.dev-e2e/ai-card-screenshot.png` — final frame (card visible)
Picks produced (live): **Moo Beef Steak** (1.2km, 150k–400k) + **Sài Gòn Xưa Và Nay** (5.6km),
clean Vietnamese reasons. provider = `mcp+openai`.

## How it was driven (no Firebase OTP, no UI canvas automation)
Flutter web is **CanvasKit** → no DOM text → Playwright can't type/read the canvas. So:
1. **dev deep-link** added to `main.dart` (TEMP): `?dev_match=&dev_phone=` → `AuthService.devLogin`
   (bypasses Firebase via `DEV_MODE=true` + `DEV_BYPASS_SECRET=dev-local-2026`) → opens
   `ChatDetailView` in **live mode** (matchId + currentUserId).
2. **Seed** via `psql` in the `db` container: a `matches(A,B)` row (fixed id
   `11111111-...-111111111111`), `noi_lau_progress(points=69)`, `user_locations` for A & B
   (HCMC District 1 / District 3 → midpoint ~10.783,106.698).
3. **Playwright** (global 1.60, headed) opens user A's deep-link and **records video**; the
   trigger message is sent over the **chat WebSocket as user B** (Node global `WebSocket`),
   crossing points 69→70 → concierge fires → card broadcast to BOTH users → renders in A's UI.
   Script polls `GET /matches/:id/messages` until an `ai_venue_card` row appears, then captures.
Files: `.dev-e2e/e2e_ai_concierge.js`, `.dev-e2e/ids.json`.

## Bugs found & fixed this session
1. **422 from sidecar when matched users have no taste tags** (ROOT CAUSE of first failed run):
   `ConciergeService.moodTags` returns a nil slice → Go marshals `"mood_tags": null` →
   FastAPI `SuggestRequest.mood_tags: List[str]` rejects null → HTTP 422 → concierge run
   status `error`, no card. **Fix:** `WebSearchProvider.Suggest` now coerces `nil → []string{}`
   before marshaling (`anmates-api/services/search_client.go`). This is a real production-relevant
   fix (the sidecar contract is "array, never null"). Rebuilt api → card fires.
2. **Web-search 0 picks when mood query is too narrow + page-fetch 403:** passing specific
   `mood_tags` (e.g. "lẩu","nướng","chill") makes a narrow query; the DDG `fetch_content` of the
   top listicle pages frequently 403s (anti-bot), and the structurer prompt (correctly) refuses
   to use article titles as venue names → returns 0 picks. With **empty mood** (tagless dev users)
   the broader query reliably returns 6 grounded picks. Not a code bug — known web-search
   limitation. Real onboarded users have tags, so consider: broaden/relax query when fetch fails,
   or fall back to snippet-only extraction (MCP_FETCH_TOP_N=0) when fetch 403s.

## Pre-existing DB drift (noted, not fixed)
The running `db` volume's `noi_lau_progress` table has **no `level` column** (migration 001 was
marked applied before `level` was added to the file; runner only applies NEW migrations). Effects:
- `GET /matches/:id/progress` → 500 "query failed" (selects `level`). In chat_detail_view this is
  caught → vibe bar falls back to the passed value (69). **Cosmetic** for the test.
- `ChatService.CheckPaywall` `SELECT level...` errors → returns "not locked" → paywall effectively
  off. Convenient here, but a latent bug. `IncrementPoints`' `SET level=...` is swallowed too.
Fix later: a migration to add `level int NOT NULL DEFAULT 1` (or a clean DB re-create), then
reconcile paywall (level≥3 locks at 30 pts) vs AI trigger (70 pts) — they currently contradict.

## State / cleanup TODO (before commit)
- **REVERT** `anmates_flutter/lib/main.dart` — remove the TEMP dev deep-link block + the two TEMP
  imports (`chat_detail_view`, `auth_service`), restore `home: const SplashScreen()`.
- **KEEP** `anmates-api/services/search_client.go` mood nil→[] fix (legit).
- `.dev-e2e/` is throwaway test scaffolding (gitignore or delete). `ids.json` holds dev JWTs.
- Stack left running: `docker compose` (db, api, ai_venue_search, flutter_web). `docker compose stop` to free RAM.

## Key facts (reusable)
- Dev JWT without Firebase: `POST /api/v1/auth/dev-login {secret,phone,name}` (needs DEV_MODE=true).
- AI trigger: points cross `AI_TRIGGER_POINTS` (70) on a chat message → `MaybeFire(before,after)`.
  Concierge preconds: not already `fired`, both users have `user_locations`. Idempotent (1 fire/match).
- AI card reaches the **sender** too (broadcast excludes AI user id, not the human sender).
- Sidecar live-verified: `STRUCTURER=openai` → LM Studio `qwen/qwen3.5-9b` @ host.docker.internal:1234.
- Verification PENDING user confirmation of the video → migrate to a resolution when confirmed.
