# Current Task

**Status (2026-06-11) — Email OTP added as a 2nd auth option (alongside phone OTP, no captcha; code done, pending live verify):** User asked for a login path without Firebase phone-OTP's reCAPTCHA → decision: **keep phone OTP, ADD passwordless email OTP** (Gmail SMTP). Backend mints a 6-digit code, emails it, verifies, upserts a user by email, issues the existing JWT pair — no Firebase, no captcha; anti-abuse via 60s per-email cooldown + 5 max attempts + 10m expiry + global rate limiter. **Backend (additive, phone flow untouched):** migration `012_email_otp.sql` (`email_otps`), NEW `services/email.go` (`EmailSender`/`SMTPSender` net/smtp auto-STARTTLS+PLAIN for Gmail 587 + App Password / `LogSender` dev fallback), `services/auth.go` `SetEmailOTP`+`EmailOTPEnabled`+`RequestEmailOTP`/`VerifyEmailOTP`/`upsertEmailUser`, `ErrRateLimited`, `AuthServicer` ext, `handlers/auth.go` 2 handlers (request=200-always to avoid email enumeration, 429 cooldown; verify=401→IssueTokens), `config.go` `SMTP_*`+`EMAIL_OTP_*`, `main.go` sender wiring (real SMTP when `SMTP_HOST`+`SMTP_USERNAME`; else `LogSender` in DEV_MODE; else routes disabled). **Flutter (additive):** `auth_service.dart` `requestEmailOtp`/`verifyEmailOtp`; NEW `email_input_view.dart` + `email_otp_view.dart` (6-box + keypad, same UX as phone `OtpView`); `phone_input_view.dart` got "Đăng nhập bằng email" button. **Verified:** go build/vet/test GREEN (golang:1.25) + flutter analyze clean. **Follow-ups done same day:** (a) **Branded HTML email** — `services/email.go` Send now sends multipart/alternative (text+HTML) + RFC2047-encoded UTF-8 Subject/From; `services/auth.go` `emailOTPHTML()` table-based inline-styled brand template (berry gradient, OTP pill). (b) **CI/CD** — `cd.go-api.yml` (prod) + `ci.go-api.yml` deploy-dev inject `SMTP_HOST`/`SMTP_USERNAME` (GH **vars**, host defaults smtp.gmail.com) + `SMTP_PASSWORD` (GH **secret**) via `--set-env-vars` (gcloud replaces whole env set → must list them). (c) **golangci-lint CI fix** — 11 issues → 0 (main.go if-else→switch, auth.go `max`→`upper`; + pre-existing venue_image/venue.go httpNoBody/errcheck/importShadow); verified `golangci-lint run` v2.12.2 → 0 issues. Image source stays **Bing** (user declined Google — server-side Google scrape would hit DDG-style CAPTCHA). **CONFIRMED:** local SMTP works (user received real OTP email). **PENDING:** full round-trip (email→code→app) visual confirm + fresh OTP to preview HTML + create GH SMTP vars/secret + commit/push branch. When round-trip confirmed → R-008/next (tags email-otp/auth/smtp/passwordless; R-007 now taken by the venue-image pipeline). See sessions/2026-06-11-email-otp-auth-option.md.

---

**Status (2026-06-11) — Venue image proxy fixed (401→429→404 chain) + Goong venue-freshen added:** User's Discovery detail screen couldn't load venue photos. Fixed a 3-error chain: (401) the image routes `app.Get("/api/v1/venues/image")` sat AFTER `api.Use(jwtMW)` — in Fiber v2 that catch-all JWT middleware also guards `app`-level `/api/v1*` routes registered after it → moved registrations BEFORE `api.Use(jwtMW)`; (429) the `/api/v1` group rate limiter caught them too → wrapped `rlHandler` to skip `/api/v1/venues/image*`; (404) **DDG Lite now serves a bot-CAPTCHA when scraped server-side** + OSM admin suffixes over-specified the query → **rewrote `services/venue_image.go` from DDG page-crawl to Bing Images** (parse `murl` JSON from results HTML) + `prepareVenueSearchQuery` strips `Phường/Quận/TP.` & appends "ảnh". **Image fix user-confirmed working** (screenshot: Tara Coffee detail w/ 6-photo hero gallery). Then user asked to fix STALE OSM venue data (OSM "Tara Coffee" → reality "AgriSocial" per Google) — chose **Goong** (fits locked "no Google Maps in VN" decision) over Google Places. Added freshen-at-detail-open: `services/goong.go` `GoongClient.Freshen` (tier1 autocomplete-by-name→detail w/ ≤150m guard; tier2 reverse-geocode fallback; 24h cache; nil-degrades), `handlers/venue_fresh.go` `GET /api/v1/venues/fresh` (authed, `{}` when no hit), `config.GoongAPIKey`, `.env`/`.env.example` `GOONG_API_KEY`. Flutter: `venue_fresh_service.dart` + `venue_detail_view.dart` (mutable `_d`, `withFresh`, `_freshen()` in initState, re-fetches photos if name changes). **Verified:** Go build/vet GREEN + services tests pass (golang:1.25). **PENDING (blocked on user):** real `GOONG_API_KEY` to live-verify freshen (route disabled until set → app behaves as before). ⚠️ Caveat: Goong has no Google-style nearby-POI search → may not surface an outright replacement name as well as Google Places would. See sessions/2026-06-11-venue-image-routing-bing-and-goong-freshen.md.

**✅ RESOLVED → R-007 (2026-06-11):** Goong part REVERTED (user). Image pipeline finished + user-confirmed: Bing source, 401/429/404 routing/rate fixes, **502 fix** (concurrent reachability probe of candidates — dead/hotlink URLs dropped so Count only reports servable photos), **relevance filter** (parse Bing per-result `t`/`desc`/`purl`, keep only images whose haystack mentions a distinctive venue token via `significantTokens`/`venueStopwords` — kills wrong/NSFW photos), **category stock fallback** (`crawlCategory`/`categoryStockQuery`: when no real photo, generic on-theme query e.g. "nhà hàng tiệc cưới sang trọng", cap 5, skips relevance), and a touch+mouse swipeable hero gallery. Cap 6→10. See resolutions/R-007-venue-image-bing-relevance-fallback.md.

---

**Status (2026-06-11) — Discovery: reliable exact-venue search + web-page image crawl (code done, pending live verify):** User: search bar must reliably return the quán **"lẩu bò giáo toàn"** + get its photos by scraping web pages, shown in detail. Findings (live-probed): OSM/Photon/Nominatim don't have this venue; DDG `i.js` + Bing *image* search are blocked/mangle the VN name → unusable; but DDG-Lite *web* search + crawling `og:image`/content `<img>` off the venue's blog pages (mia.vn → `lau-bo-giao-toan-*.jpg`, real 200 image/jpeg) works great. **Part 1 (sidecar `service.py`):** free-text `/search` now degrades a structurer/LLM failure to empty picks (not 502) AND injects a **deterministic seed card** for the typed name when it looks like a venue name (≥2 words/≥8 chars; bare dishes left to the LLM) and no structured pick matches it — so exact-name search ALWAYS returns the quán regardless of LLM availability/relevance. New `tests/test_query_seed.py`. **Part 2 (`services/venue_image.go` rewritten):** resolver = DDG-Lite web search → crawl top pages → og:image + content imgs (absolutized, junk-filtered), ≤6/venue, 24h cache; handler `Serve` gained `i` index + new `Count` (`GET /api/v1/venues/images?q=`→{count}); Flutter detail hero is now a swipeable `PageView` gallery (count via new `venue_image_service.dart`, `VenueThumbnail` index param). **Verified:** go build/vet/test GREEN, sidecar pytest 12/12, flutter analyze clean, network chain end-to-end for the named venue. **PENDING:** live `./start.sh` → search "lẩu bò giáo toàn" returns the card + tap → 12.1 with photo gallery. When confirmed → R-007. See sessions/2026-06-11-discovery-venue-seed-and-web-image-crawl.md.

---

**Status (2026-06-10) — FEATURE Discovery venue thumbnails + Chi tiết quán (12.1) detail screen (code done, pending live verify):** User: "search hình thumbnail của quán trên web và render vào list quán" + "click vào quán → show 12.1_ChiTietQuan, implement UI luôn". Done full-stack. (1) Thumbnails: NEW public, un-rate-limited Go endpoint `GET /api/v1/venues/image?q=` does **keyless DuckDuckGo image search server-side** (`services/venue_image.go` vqd page→i.js JSON, 24h cache; `handlers/venue_image.go` proxies photo bytes w/ Cache-Control 24h so Flutter `Image.network` needs no CORS/token; registered on root `app` in main.go, NOT the rl group/jwt). Flutter `VenueThumbnail` widget (fade-in + `PhotoSlot` fallback) replaces `📸` in both Discovery rows. (2) Detail: NEW `views/discover/venue_detail_view.dart` `VenueDetailView` + `VenueDetailData.fromOsm/.fromResult`; tapping any Discovery row opens it (was Google Maps). Hero photo + tag/title/meta + social-proof + VỀ QUÁN + taste chips + "Hợp gu {name}:%" card + sticky "＋ Wishlist / Tìm Mate ăn cùng" bar. Honesty: only real meta segments shown, fake count/% softened/placeholdered. CTAs: Wishlist→WishlistService.add, Tìm Mate→SwipeView, near_me→MapsLauncher. **Verified:** go build/vet/test GREEN (golang:1.25 + new `services/venue_image_test.go`), `flutter analyze` clean on changed files. **PENDING:** live `./start.sh` (rebuilds api) → confirm photos render + 12.1 opens at http://127.0.0.1:54180. Limitation: DDG may block datacenter IPs on Cloud Run → graceful placeholder there. When confirmed → R-007. See sessions/2026-06-10-venue-thumbnails-and-detail-screen.md.

---

**Status (2026-06-10) — Containerize the LLM → ALL services now in Docker (config-only, pending live verify):** User asked "modify start.sh to run all services in docker". Finding: app services (db/api/ai_venue_search/flutter_web) were already fully dockerized via `docker compose`; the ONLY host dependency left was the venue-search structurer LLM (`LLM_BASE_URL=host.docker.internal:1234`, LM Studio on host). User chose **Containerize the LLM**. Added bundled **`ollama`** service (`ollama/ollama:latest`, OpenAI API `:11434/v1`, `ollama` named volume, healthcheck) + one-shot **`ollama_pull`** (pulls `${OLLAMA_MODEL:-qwen2.5:3b}` ~2GB, idempotent). Repointed sidecar: `STRUCTURER` pollinations→**openai**, `LLM_BASE_URL`→`http://ollama:11434/v1`, `LLM_MODEL`→`${OLLAMA_MODEL}`, +`depends_on ollama`. New **`docker-compose.gpu.yml`** opt-in NVIDIA override (kept out of base so CPU-only `up` never fails). `start.sh`: COMPOSE_FILE select (`OLLAMA_GPU=1` merges gpu), exports `OLLAMA_MODEL`, step-8b model-pull wait, banner shows Ollama URL. **No Python edits** — sidecar's `_lm_studio` json_schema path already speaks Ollama's OpenAI shape. Static-verified: `compose config -q` (base+gpu merge) ✓, interpolation resolves ✓, `bash -n start.sh` ✓. **PENDING:** live `./start.sh` (first run pulls image+model) + confirm Ollama honors strict `response_format: json_schema` (fallback: `OLLAMA_MODEL=qwen2.5:7b` or `STRUCTURER=pollinations`). When confirmed → R-007. See sessions/2026-06-10-dockerize-llm-ollama.md.

---

**Status (2026-06-08) — FEATURE First Date / Booking (nhóm E #1) done full-stack:** User chọn build First Date trước. Backend: migration `011_bookings` (1 active booking/match, partial unique index), `services/booking.go` (Propose replace-active / Get / Confirm chỉ non-proposer / Cancel + validateProposal pure-tested), `BookingServicer`, `handlers/booking.go`, 4 routes `POST/GET /matches/:id/booking` + `/confirm` + `/cancel`. Flutter: `booking_service.dart`, `booking_view.dart` rewrite mock→real (calendar động theo tháng hiện tại, load existing, banner propose/confirm/cancel, CTA propose thật), wire chat "Chốt First Date"→BookingView (venue từ AI card gần nhất). Verify: go build+vet+test ok, **e2e_full_flow 31/31** (step 13: propose/confirm-own-409/confirm/cancel), flutter build OK, **booking UI smoke PASS** (tap CTA→BookingView→propose→DB row). Defer: chat broadcast khi confirm, voucher/check-in (cần Live Tracking + Trust). Nhóm E còn: Trust Score, Lá thư, Safety, Selfie/Tracking/Check-in/Review.

---

**Status (2026-06-08) — "Làm hết" nhóm C+D done:** **C1** bỏ message paywall chết (handlers/chat.go, seam giữ cho Phase-2). **C2** dev deep-link trong main.dart gate sau `_devDeepLinkEnabled` (kDebugMode||localhost) → inert ở prod, vẫn chạy dev/e2e (hết rủi ro "revert before ship"). **D** e2e_full_flow.js +step 12: profile GET/PUT, wishlist CRUD, swipe+undo → **e2e 26/26** (was 20). Verify: Go+Dart build OK, go vet+test ok, e2e 26/26, D1 deep-link vẫn PASS. **Defer:** A1-`restaurant_id` (web-search không ground DB; chưa có consumer — cần booking/DB-ingest trước), **nhóm E** (letters/booking/tracking/checkin/review/trust/safety) = 6-8 feature lớn + phụ thuộc product open-questions → cần build từng cái, KHÔNG làm 1 lượt; chờ user chọn feature ưu tiên.

---

**Status (2026-06-08) — "Làm tất cả": ISSUE-9 + B1 + D1 + R-006 done (+ live Thủ Đức test):** Sau khi fix A1/A2/B2: (1) live test "địa chỉ hiện tại" — IP-geo trả Gò Vấp sai (vị trí ISP), geocode đúng "Đường số 2, Phường Thủ Đức"=10.8383,106.7497 → card ra toàn quán Thủ Đức (King BBQ Buffet/Sumo Yakiniku/Buffet Sống Sắc), video quay lại OK; (2) **ISSUE-9** distanceLabel ẩn "0m" khi lat/lng=0 (rebuild flutter_web xác nhận trực quan); (3) **B1** ConciergeService.fire chờ prewarm in-flight (channel) → hết 502, verify SETTLE_MS=0 card vẫn fire 20/20; (4) **D1** thêm `.dev-e2e/e2e_card_buttons.js` (Playwright tap "Gợi ý cho Mate"→assert WS send) PASS; (5) **R-006** viết (A1/A2/B2, user-confirmed). Verify: pytest 11, go vet+test ok, e2e 20/20, D1 PASS. Còn lại (chưa làm): A1-restaurant_id (cần DB ingest), nhóm C khác (C1 dead paywall, C2 temp deep-link), nhóm D mở rộng (auth thật/wishlist/swipe-undo/profile), nhóm E (scope chưa build).

---

**Status (2026-06-08) — E2E coverage audit + FIX nhóm A+B (AI Concierge data quality + ops):** Đánh giá độ phủ `e2e_full_flow.js`: chỉ cover ~8/24 chặng journey ở tầng API/WS (UI Flutter 0%, auth thật bypass bằng dev-login, nhiều endpoint built-but-untested, ~13 chặng Phase-1 chưa build) — xem ma trận + tổng hợp 8 issue (A/B/C/D/E) trong sessions/2026-06-08-e2e-full-flow-issues.md. User chọn fix **nhóm A+B**: **A2** intro hết nêu tên khu vực sai ("Xuân Hòa" do OSM/Nominatim đều trả district sai cho midpoint trung tâm HCM) — bỏ prepend area + prompt cấm nêu phường/quận; **A1** toạ độ venue: radius guard động (≤6km) + chỉ tin street-address, quán ngoài vùng→lat/lng=0 (hết lỗi Subin BBQ Thủ Đức ghim 184m); **B2** api container "unhealthy"→healthy (healthcheck localhost→127.0.0.1, busybox wget IPv6 vs Go IPv4). Verify: pytest 11 passed, rebuild sidecar + api healthy, E2E 20/20, card thật 3 quán in-area (1.10/1.96/2.85km) dist khớp, intro "giữa 2 bạn". Chỉ sửa Python sidecar + docker-compose (không Go/Dart). ⚠️ Chưa user-confirm UI Flutter trực quan → R-006 khi confirm. Còn lại: A1-restaurant_id, B1 (502), nhóm C/D/E.

---

**Status (2026-06-08) — E2E full-flow GREEN + paywall removed cho MVP market test:** Theo chỉ đạo "làm để test thị trường" → bỏ paywall (MVP free). `services/chat.go CheckPaywall` → luôn `return false` (gỡ hard-lock level-3, BLOCKER-004 resolved). Rebuild image → **E2E full-flow `.dev-e2e/e2e_full_flow.js` 20/20 PASS**: dev-login → onboarding → preferences → location → deck(overlap=6) → mutual-like → match → conversations → WS 2 chiều → Vibe leo **0→72 tự nhiên** (không còn kẹt 30) → **AI Concierge `ai_venue_card` fire end-to-end** (King BBQ · Subin BBQ, web-search + LM Studio). ⚠️ Pending user confirm + chưa verify UI Flutter trực quan (mới API+WS). NB sidecar 502 nếu warm(60)+fire(70) gọi LLM đồng thời (chỉ khi gửi burst <1s; chat thật cách phút → OK). See sessions/2026-06-07-e2e-full-flow-test-2users-chat.md.

**Status (2026-06-07) — E2E full-flow test (từ đầu → 2 user chat + AI card):** Test toàn bộ luồng thật bằng script Node API+WS mới `.dev-e2e/e2e_full_flow.js`: dev-login → onboarding → preferences → location → discovery deck (overlap=6) → mutual-like swipe → match → conversations → WebSocket 2 chiều → Vibe climb → **AI Concierge `ai_venue_card` fire end-to-end** (3 quán thật từ web-search + LM Studio). **16/16 bước flow chính PASS.** Phát hiện+xử lý 3 vấn đề: (A env) API container chạy image STALE thiếu `010_swipes` → `docker compose build api`; (B data) pgdata volume local thiếu cột `noi_lau_progress.level` (do migration phantom cũ `003_noi_lau_drop_level.sql` đã bỏ khỏi repo) → match creation 500 → `ALTER TABLE … ADD COLUMN level`; (C ⚠️ design) **paywall hard-lock level-3 (30đ) chặn Concierge trigger (70đ)** → raise BLOCKER-004, cần user quyết. Không sửa source production. See sessions/2026-06-07-e2e-full-flow-test-2users-chat.md.

---

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
