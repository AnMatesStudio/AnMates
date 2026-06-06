# Current Task

**Status (2026-06-07) — Prod CD gaps fixed (pre-merge):** Before merging `feat/ai-concierge-map`→main, fixed 2 deploy gaps that would break AI Concierge on prod: (1) `cd.go-api.yml` prod deploy was missing `AI_SEARCH_URL` (Cloud Run `--set-env-vars` replaces env → would disable Concierge) — added it mirroring dev; (2) `ai-venue-search/` had no `cd.*` → created `cd.ai-venue-search.yml` (push main → Cloud Run 8090). ⚠️ Not yet run in GH Actions; verify repo var `AI_SEARCH_URL`. Flutter Android/iOS still have no CD by design. See sessions/2026-06-07-prod-cd-gaps-ai-search-url-sidecar.md.

---

**Status (2026-06-06) — Mutual-like + wishlist CRUD (follow-ups resolved):** On top of the swipe→match→chat flow below, resolved all open items. **Mutual-like gate:** new `010_swipes.sql` + `swipes` table; `AcceptMatch`→`Swipe(like/pass)` (match created only on reciprocated like) + `Undo` (rewind); routes `/matches/:id/accept`→`POST /swipes` + `/swipes/undo`; `ListCandidates` excludes already-swiped. **Wishlist real:** new `wishlist_service.dart` + `WishlistView` rewritten mock→CRUD (list/add-sheet/delete). **Matching interest set** = food_tags ∪ wishlist food_name ∪ wishlist food_category (3 disjoint vocabularies), threshold raised back to **≥2**. Flutter `swipe_view` mutual-like UX + rewind restored; `smoke_test` moved to /swipes. **Verified:** Docker go build/vet rc=0 (incl smoke), `go test ./services` ok; **matching SQL validated LIVE on Postgres 16** (`.dev-e2e/matching_sql_check.sql`). ⚠️ Flutter not analyzed on host — verify via `./start.sh`. **TODO (user):** 2 real-OTP users, onboard with ≥2 shared food tags (or both wishlist same category), Ăn Match → both swipe right → chat. See sessions/2026-06-06-real-swipe-match-chat-flow.md (Part 2).

---

**Status (2026-06-06) — Real swipe→match→chat flow:** Wired the mate-discovery flow end-to-end for real phone-OTP users. Bottom tab 4 "Mình"→**"Ăn Match"** (opens `SwipeView`); profile now reached via avatar tap on Khám phá (+back button added). `SwipeView` rewritten mock→real (loads candidates + currentUserId, swipe-right/♥ → `acceptMatch` → `MatchView` → "Hello" → live `ChatDetailView(matchId)`; loading/error/empty states). **BLOCKER fixed:** matching scored on `wishlists` (never written by app → empty deck) → switched `ListCandidates` + `AcceptMatch` to **`users.food_tags` Jaccard**, threshold ≥1 shared tag, so 2 onboarded users are matchable immediately. Accept stays one-sided+instant. **Verified:** Docker go build/vet rc=0, `go test ./services` ok (smoke needs live :8080). ⚠️ Flutter NOT analyzed on host (no PATH) — verify via `./start.sh`. **TODO (user):** create 2 users via real OTP, onboard with ≥1 common food tag, test Ăn Match → swipe → chat at http://127.0.0.1:54180. See sessions/2026-06-06-real-swipe-match-chat-flow.md.

---

**Status (2026-06-06):** AI Concierge **pre-warm cache** + **2-user side-by-side E2E** done (code, build/test GREEN; video not recorded yet). Latency fix: `AI_WARM_POINTS` (default trigger−10=60) → concierge prefetches the slow web-search in background when Vibe enters `[warm,trigger)`, caches in-memory (10min TTL), `fire` posts instantly via `takeWarm` (falls back to fresh `compute` on miss). Pure `decideAction` + extracted `compute` (status ok/error/skipped) keep run-row granularity; idempotency unchanged. New 2-phone video tooling in `.dev-e2e/` (2nd flutter_web port 54181 for distinct localStorage; `e2e_two_users.js` drives An↔Bình chat 58→70, card on both phones, reload for full-history shot; `run-e2e.ps1`). Verified Docker golang:1.25: build+vet clean, services 10/10 (new TestDecideAction). **TODO (user):** run `.dev-e2e\run-e2e.ps1` w/ LM Studio up to record the video; revert `main.dart` TEMP deep-link before commit. See sessions/2026-06-06-ai-concierge-prewarm-2user-e2e.md.

---

**Status (2026-06-04):** AI Concierge venue source SWAPPED map/DB → **MCP web-search**, sidecar LIVE-VERIFIED in Docker. `ai-venue-search/` (FastAPI) wired into `docker-compose.yml` (service `ai_venue_search`:8090, healthcheck, host-gateway); api gets `AI_SEARCH_URL=http://ai_venue_search:8090`. **FREE, no keys**: DuckDuckGo MCP search + Nominatim reverse-geocode + structurer chain Pollinations→LM Studio (FallbackStructurer; Pollinations anon 429s → LM Studio qwen3.5-9b w/ strict json_schema carries it). `POST /suggest` confirmed 200 w/ concrete VN venue names. Go side: `VenueProvider` interface + `WebSearchProvider`(web) / `DBLLMVenueProvider`(legacy fallback). **Run:** `./start.sh` or `docker compose up --build`. ⚠️ Go build still unverified on host (no Go PATH — covered by httptest + Docker build). Limitation: web-search → lat/lng often 0 (weak map pins), names not 100% grounded. Tip: `STRUCTURER=openai` makes LM Studio primary (skips Pollinations 429). See sessions/2026-06-04-ai-concierge-mcp-websearch.md.

---

## Previous status

**Status:** AI Concierge chat slice IMPLEMENTED (code complete) — ⚠️ NOT YET built/tested locally (Go+Flutter toolchains not on host PATH; build via Docker `start.sh` / CI). Flutter chat view still a MOCK (card shown from sample data; WS delivery is the remaining seam).
**Verification pending (user/Docker):** `docker compose` build, `go test ./...`, `go vet`, `flutter analyze`, `flutter test`. Live E2E needs LM Studio at `AI_BASE_URL=http://host.docker.internal:1234/v1` + a model (Qwen2.5-14B suits RTX 5080 16GB). Then: 2 users + match + push locations + chat until points≥70 → expect `ai_venue_card` from "Trợ lý ĂnMates" with 3 seeded venues, once.
**✅ WebSocket wired (2026-06-04):** `chat_socket.dart` + live `chat_detail_view` (matchId → load history+progress, connect WS, render real `ai_venue_card`, send over socket) + `chat_list_view` loads real conversations. Demo mode preserved when matchId null.
**LM Studio (RTX 5080) — RESOLVED:** qwen3.5-9b is a reasoning model → LM Studio puts JSON in `reasoning_content` (content empty). Fixed in `llm.go`: fallback to reasoning_content + max_tokens=2000. Verified end-to-end: clean Vietnamese, 1.3s, correct budget filter + anti-hallucination. **9b now preferred.** Dev `.env`: `AI_BASE_URL=http://host.docker.internal:1234/v1`, `AI_MODEL=qwen/qwen3.5-9b`. (vl-7b also works via content path; CJK guard still in place.)
**Next seam:** replace seed venues with Goong ingest; add `user_prefs_budget`; investigate qwen3.5-9b empty-content (try disabling reasoning / non-strict json). Still pending: run `go test`/`flutter analyze`/`flutter test` in Docker/CI; full live E2E.

---

## Previous status

**Status:** SPEC ready (spec-driven) — awaiting go-ahead to implement AI Concierge chat slice.
**Owner:** main-assistant
**Started at:** 2026-06-03
**Last updated:** 2026-06-03
**Active spec:** `docs/specs/ai-concierge-chat-spec.md` — vertical slice: Vibe `points>=70` → Claude agent posts top-3 seeded venues as `ai_venue_card` in chat. ⚠️ **Google Maps PROHIBITED in VN** → data/routing = **Goong**; render = OSM tiles. Locked: trigger 70, app pushes location (user_locations), seed restaurants for slice, Haiku agent behind LLMClient interface. Migrations 006-008. **Steps 1-4+6-8 implementable WITHOUT keys (fake LLM); live E2E needs ANTHROPIC_API_KEY.** Prereq from user: Anthropic API key (+ later Goong key). Implementation not started.

---

## Previous task (archived)

**Status:** delivered (pending review) — Meetup & Dining Map master plan authored.
**Owner:** main-assistant
**Started at:** 2026-06-03
**Last updated:** 2026-06-03
**Goal:** Design a complete map-based meetup planning experience (find → evaluate → agree → book → meet a restaurant for matched users). Output: `docs/meetup-map-master-plan.md` (18 sections, Mermaid). Key decisions: pragmatic-incremental Riverpod for new `map/restaurants/booking` features only; flutter_map+OSM/Overpass for MVP with Mapbox (Directions/Matrix) as V2 upgrade; map becomes a core MVP surface (supersedes prior "no full map in Phase 1"). New backend: PostGIS + `restaurants/venue_suggestions/bookings/user_locations/favorite_restaurants/meetup_recommendations/location_sessions` tables + APIs. Doc-only, no code written. See sessions/2026-06-03-meetup-map-master-plan.md. ⚠️ Pending: user/team review + verify Cloud SQL PostGIS availability before MAP-R-1.

---

## Previous task (archived)

**Status:** done — CI→dev deploy running. R-005 written.
**Owner:** main-assistant
**Started at:** 2026-06-01
**Last updated:** 2026-06-01
**Goal:** CI deploy lên GitHub Environment `dev` để test branch/PR trên URL thật. `ci.flutter-web.yml` + `ci.go-api.yml` thêm job `deploy-dev` (same-repo PR only) → `environment: dev` (web: dev-anmates-studio.web.app, api: shared Cloud Run anmates-api ENV=dev, API_BASE_URL chung). `cd.*` giữ nguyên — tách production (Cloud Run riêng + Cloud SQL + Secret Manager) là follow-up tương lai. User chọn **1 env `dev`**. ⚠️ Setup thủ công còn lại: tạo env `dev`, tạo Firebase site `dev-anmates-studio`. See sessions/2026-06-01-ci-dev-environment-deploy.md.
**Jira:** TECH-7 (current branch)

---

## Previous task (archived)

**Status:** done — onboarding flow 08→09→10→11 fully working. R-004 written.
**Goal:** Refactor onboarding submit flow: Screens 08/09 store to client draft (no API), NEW Screen 10 photo upload (Firebase Storage), "Hoàn tất" validates all 3 + one-shot `PATCH /profile/complete-onboarding`, Screen 11 GETs profile (nickname+avatar). New `user_photos` table. See sessions/2026-05-31-onboarding-flow-refactor-screen08-09-10-11.md + R-004.

---

## Previous task (archived)

**Status:** done — UI confirmed by user, nav bug fixed, R-003 written.
**Goal:** Implement post-OTP onboarding: Screen 08 (Thông Tin Cá Nhân, 3/5) + Screen 09 (Gú Ẩm Thực, 4/5). See R-003 + sessions/2026-05-31-screen08-ui-polish.md.
**Jira:** TECH-7 (Screen 08) in epic TECH-6 (Auth & Profile UI/UX)

---

## Previous task (archived)

**Status:** in-progress (FE-UI-007 ✅ Screen 03 in-review — next: FE-UI-008 Screen 04)
**Owner:** main-assistant
**Started at:** 2026-05-26
**Last updated:** 2026-05-28
**Jira:** SCRUM-13 (FE-UI-007) In Progress | SCRUM-7 (FE-UI-001 audit) In Progress
**Goal:** Refactor TOÀN BỘ UI Flutter app (`anmates_flutter/`) khớp 24 design HTML mới nhất (`plan/lastest/design/`) + animation spec chi tiết trong `design-system.md`. Phased delivery (8 phases). This session covers **Phase 0 (Foundation) + Phase 1 (Onboarding screens 01-07)**.

## Most recent progress (2026-05-27)

Onboarding screen 02 "Chọn quán" refactored end-to-end: polaroid cards with real cartoon PNG illustrations (Lẩu/Cafe chill/Đồ nướng/Ăn vặt), tightly-stacked layout, full animation suite (staggered entry + ambient float + hover lift + press), responsive sizing for iPhone SE through 14, swipe enabled on touch + mouse + trackpad + stylus. ~400 lines of dead CustomPainter code removed. Visual confirmation pending. See [sessions/2026-05-26-onboard-02-chon-quan-polaroid-cards.md](sessions/2026-05-26-onboard-02-chon-quan-polaroid-cards.md) for full multi-iteration log.

**Blocked on user decision:** how to interpret the `food_card.png` re-crop request (food-art-only vs whole-polaroid + Flutter chrome refactor).

## Scope (this session)

- **Phase 0** — Foundation primitives + theme extension + assets
  - Brand primitives: `AppButton` (Primary/Secondary/Outline/Danger/Ghost), `AppChip` (Filter/Tag/Mood/State), `AppCard` (Restaurant/Mate/Booking), `AppInput` (Text/Phone/OTP/Search), `Avatar` (with optional TrustBadge ring), `VibeRing` (0–100 circular), `TrustBadge` (Perfect/Trusted/Limited), `AppLoader` (3 modes: splash / overlay / top-bar), `Sparkle` (twinkle SVG)
  - Theme extension: spacing tokens, semantic colors, reduce-motion provider, haptic helper
  - Assets folder skeleton: `assets/sparkles/` (CustomPainter fallback if no SVG)
- **Phase 1** — Onboarding (Screens 01–07)
  - 01 Splash (full animation timeline)
  - 02/03/04 Onboard carousel (3 educational screens with hero animations)
  - 05 Đăng nhập (phone + Apple ID — keep existing Firebase wiring)
  - 06 OTP (6-digit auto-advance — keep existing Firebase wiring)
  - 07 Face verify (liveness mock — UI only, no real ML)

## Out of scope (next sessions)

- Phase 2 (08, 09a, 10a — profile setup)
- Phase 3 (09b, 10b, 11 — discovery)
- Phase 4 (12, 13 — match)
- Phase 5 (14, 15, 16, 17 — chat + booking)
- Phase 6 (18-22 — kèo/letter/tracking/review)
- Phase 7 (23, 24 — tab Mình + trust)
- N1-N7 screens (no design yet — design-team blocker)
- Phase 2 IAP screens (25-28)
- Backend Go changes

## Acceptance criteria (this session)

- [ ] Phase 0 primitives in `lib/widgets/anm/` — all 9 primitives implemented + exported from a barrel file
- [ ] Theme extended with spacing/semantic tokens; reduce-motion + haptic helpers in `lib/services/`
- [ ] `pubspec.yaml` updated (`flutter_svg` added; `lottie` only if needed)
- [ ] Phase 1 screens 01-07 rewritten end-to-end matching reference HTML + design-system.md animation timelines
- [ ] Existing Firebase OTP wiring preserved (no regression on R-001 fix)
- [ ] Vietnamese diacritics render OK on all copy
- [ ] Hit targets ≥44×44px on every tappable element
- [ ] Reduce-motion mode covers all animated screens
- [ ] `flutter analyze` clean (0 errors, ≤5 warnings)
- [ ] `flutter test` passes (existing tests must continue to pass; no new tests required this session)
- [ ] QA report saved to `qa-reports/2026-05-26-phase-0-1.md`

## Key references

- HTML designs: `plan/lastest/design/01 _ Splash.html` … `07 _ Face verify.html` + `Brand system.html` (READ FIRST) + `Logo studies.html`
- Animation timelines: `.claude/shared-memory/design-system.md` lines ~200–700 (AppLoader, Sparkle, Splash, Onboard 02/03/04, Auth 05/06/07)
- Existing legacy code to REPLACE: `lib/views/splash/splash_screen.dart`, `lib/views/onboarding/onboarding_view.dart`, `lib/views/auth/auth_view.dart`, `lib/views/auth/phone_input_view.dart`, `lib/views/auth/otp_view.dart`
- Brand tokens (LOCKED — do not invent new shades): `lib/theme/app_theme.dart` `AppColors`
- Firebase OTP code (must keep wiring): `auth_error_messages.dart`, services hitting Firebase Phone Auth

## Loop policy

Max 3 coder→qa cycles for Phase 1. If still failing after 3, mark blocked and escalate to user.
