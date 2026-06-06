# 2026-06-06 — AI Concierge pre-warm cache + 2-user side-by-side E2E

## TL;DR
Two asks from user:
1. **Latency**: the venue card is slow (web-search ~30–60s). → Added a **pre-warm cache**:
   the concierge starts the expensive `provider.Suggest()` in the background when Vibe
   enters a band *below* the trigger, parks the result in memory, and the eventual fire
   posts it instantly.
2. **Better video**: previous E2E only showed user A's screen + one canned trigger message.
   → New **2-phone side-by-side** Playwright script: An + Bình chat back-and-forth, Vibe
   climbs 58→70, card lands on BOTH phones.

Backend verified GREEN in Docker (golang:1.25-alpine): `go build ./...` + `go vet` clean,
`services` tests 10/10 pass incl. new `TestDecideAction`. (smoke pkg fails = needs live
:8080 server, unrelated.)

**VIDEO RECORDED ✅** (live, this session). `videos/ai-concierge-2users.webm` (~1.3MB, 97s)
— An + Bình side by side, scripted 12-line convo drives Vibe 58→70, real pipeline (DuckDuckGo
MCP + LM Studio qwen3.5-9b) returns real venues, card lands on BOTH phones. Money-shot
screenshots `videos/03_A_full.png` + `03_B_full.png` show the full conversation with correct
mirrored bubble alignment + the AI card (Cơm Niêu Sài Gòn / Nhà Hàng Khoái / Lobster Bay,
"khu vực Xuân Hòa, Quận 3"). Pending user's nod that it's the look they wanted.

## Part 1 — Pre-warm + cache (backend)
Files: `anmates-api/{config/config.go, main.go, services/concierge.go, services/concierge_test.go}`

- **Config** `AI_WARM_POINTS` (env), default = `AITriggerPoints - 10` (floored at 1) →
  `ConciergeConfig.WarmPoints`. Wired in main.go + logged. `0` disables pre-warm.
- **decideAction(before, after, warm, trigger) → actNone|actWarm|actFire** — pure, unit-tested.
  A jump straight past the trigger fires immediately (no warm); entering `[warm, trigger)`
  prefetches. `MaybeFire` is now a 3-way switch dispatching `fire` / `prewarm` goroutines.
- **compute(ctx, matchID) → (mid, intro, picks, cost, status)** — extracted the expensive,
  side-effect-free core (members → both locations → mood → `provider.Suggest`) shared by
  prewarm and fire. `status ∈ {"ok","error","skipped_preconds"}` preserves run-row granularity.
- **prewarm(matchID)** — dedupe guard (`warming` set), skip if cached-fresh or already fired,
  run compute, park result in `warm[matchID]` (in-memory map). Best-effort/silent.
- **takeWarm(matchID)** — consume-once; returns the cached suggestion iff present & within
  `warmTTL` (10 min). On miss, `fire` falls back to `compute` (status quo behaviour).
- **fire(matchID)** — idempotency check → `takeWarm` fast path → else `compute` → persist +
  broadcast. Card content (incl. midpoint) identical whether warm or fresh.
- Cache is **in-memory** (`sync.Mutex` + 2 maps). Fine for single-instance dev; for multi-
  instance prod the DB idempotency row still prevents double-posts, and a cold instance just
  recomputes. (Future: persist warmed picks to a `status='warmed'` run row if needed.)

### Why this is safe
- Pre-warm never persists/broadcasts — only `fire` does, behind the existing unique-index
  idempotency. Worst case prewarm wastes one search call.
- Locations changing between warm and fire → slightly stale midpoint; acceptable (locations
  rarely move mid-chat) and bounded by `warmTTL`.

## Part 2 — 2-user side-by-side video (test scaffolding)
Files: `.dev-e2e/{e2e_two_users.js, docker-compose.e2e.yml, run-e2e.ps1}`

- **Key constraint**: the WS hub `Broadcast` excludes the sender **by user id** (ws/hub.go),
  so a phone never receives its own messages over the socket — only the other person's. And
  two same-origin pages share localStorage, so both dev-logins would clobber to one user.
- **GOTCHA (cost an iteration)**: Flutter web is **CanvasKit** and renders BLANK inside an
  `<iframe>` (first attempt: two iframes in one `setContent` page → both phones white). A
  direct top-level page load renders perfectly. → Use **two separate Playwright pages** (not
  iframes), one per origin, then **hstack the two .webm** into one side-by-side video.
- **Solution**: `docker-compose.e2e.yml` maps a **second host port** (54181→80) to the same
  flutter_web container → An on `127.0.0.1:54180`, Bình on `:54181` = distinct origins =
  separate localStorage = distinct identities. Two pages in one Playwright context (each
  records its own webm via the TEMP `?dev_match&dev_phone` deep-link still in `main.dart`),
  combined with a **dockerized `linuxserver/ffmpeg`** hstack (no native ffmpeg on host).
- **Script** (`e2e_two_users.js`): dev-logins both users → seeds match/progress(58)/locations
  via `docker compose exec db psql` → drives a 12-line scripted convo over each user's raw WS
  (4s pacing) → Vibe 58→70 (prewarm at 60, fire at 70) → polls for the `ai_venue_card` →
  **reloads both phones** so each renders the FULL history (both sides + card, correct bubble
  alignment) for the money shot. Output: `.dev-e2e/videos/*.webm` + 01_ready/02_card_live/03_full.
- **Runbook** `run-e2e.ps1`: `up -d` with the override + `STRUCTURER=openai`, wait for health,
  run the node script. One command from repo root.

## How to record the video (user)
```powershell
# Docker Desktop running; LM Studio with qwen/qwen3.5-9b loaded at :1234
powershell -ExecutionPolicy Bypass -File .dev-e2e\run-e2e.ps1
# → .dev-e2e/videos/  (webm + 3 screenshots)
```
Pacing/points are tuned so the card appears right as Vibe hits 70. With pre-warm, the search
runs during the 10-message climb from 60→70 (~40s) so the fire is (near-)instant.

## Verification status
- Backend build/vet/unit: ✅ GREEN (Docker golang:1.25-alpine).
- Live 2-phone video: ✅ RECORDED — `videos/ai-concierge-2users.webm` + `03_A_full.png`/
  `03_B_full.png`. Card fired on both phones via the real DDG-MCP + qwen3.5-9b pipeline.
- Pre-warm "instant fire" not separately measured (perf-only; functional path unchanged and
  unit-tested). The card appeared right after pt 70 in the run.

## "Peer messages don't show" — NOT an app bug (diagnosed 2026-06-06)
User reported: in the video, An's phone didn't show An's messages to Bình and vice-versa.
**Root cause = TEST ARTIFACT, not an app/backend bug.** Verified with a focused repro
(`_repro.js`, since deleted): opened Bình's phone, sent ONE message as An over a raw WS →
Bình's UI rendered it live as a left bubble. So live peer delivery works (client.go:84
`hub.Broadcast(matchID, c.userID, out)` excludes only the SENDER by user id; the AI card
reaching both phones already proved the receive path).

Why the video looked one-sided: the script injects each line over a **raw WS authed as that
user** (not the phone's composer). The hub excludes the sender → a live-sent message lands
only on the OTHER phone, and the sending phone never optimistically appends it (that only
happens when a human types in the composer, which Playwright can't drive on a CanvasKit
canvas). So each phone showed the peer's messages but not the ones "it" sent.

**Fix v1 (seeded history):** pre-seed all but the last 2 lines as history + short live tail.
Works but the convo isn't "typed live."

**Fix v2 (FINAL — real typing, what user asked: "clear hết, chat qua lại cho giống thật"):**
clear all messages, seed points `70 − len(SCRIPT)`, then **type each line into the real
Flutter composer** — `page.mouse.click(190,850)` (composer input) → `keyboard.type` →
`keyboard.press('Enter')`. This drives the genuine send path: the sender's phone appends the
bubble OPTIMISTICALLY (right) and the peer receives it over the socket (left), so BOTH phones
show a true two-sided conversation as it's typed — no history, no reload. KEY ENABLER:
Flutter web puts a hidden DOM input on the focused TextField, so Playwright keyboard events
reach it; Playwright's default chromium anti-throttling flags keep the background tab
rendering so both videos stay live. Verified: DB shows 12 alternating An/Bình messages +
the `ai_venue_card`; card fired at pt 70. `videos/ai-concierge-2users.webm` re-recorded.
Still no production code changed.

Composer tap point for the 430×880 viewport: **(190, 850)**. Reusable for any Flutter-web
chat E2E that needs to send a real message through the canvas composer.

## Open follow-ups
- Record the 2-user video; confirm card lands on both phones + bubble alignment after reload.
- Known web-search limit (carried over): narrow mood queries + page-fetch 403 → 0 picks.
  Tagless dev users dodge it; real users may need broaden-on-fetch-fail or snippet-only mode.
- `main.dart` TEMP deep-link + `.dev-e2e/` are dev scaffolding — revert/gitignore before commit.
- DB drift: `noi_lau_progress.level` missing on the old volume → use a fresh volume for the demo.
