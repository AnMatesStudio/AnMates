# 2026-06-08 — E2E full-flow re-run + issue catalogue

## TL;DR
Chạy lại toàn bộ luồng thật `node .dev-e2e/e2e_full_flow.js` (dev-login → onboarding →
preferences → location → discovery deck → mutual-like → match → conversation → WS chat
2 chiều → Vibe 0→72 → AI Concierge `ai_venue_card`). **Kết quả: 20/20 PASS.**
Toàn bộ đường đi backend + WebSocket thông suốt end-to-end.

Tuy "all green", khi soi card thật + container state phát hiện **8 issue** về chất
lượng dữ liệu / độ tin cậy / vệ sinh code (test pass vì assertion lỏng + có pause nhân tạo).

## Cách chạy
- Stack docker đang chạy sẵn (db healthy, ai_venue_search healthy, api+web "unhealthy" — xem ISSUE-5).
- `node .dev-e2e/e2e_full_flow.js` — Node built-in fetch+WebSocket, không deps. Repeatable (tự cleanDB 2 user).
- AI Concierge enabled: mode=web-search, trigger=70, warm=60, model qua LM Studio (host).

## Full flow đã verify (20/20)
1. Auth — dev-login 2 user (An `+84900000011`, Bình `+84900000012`) ✓
2. Onboarding — `PATCH /profile/onboarding` ✓×2
3. Preferences — `PATCH /profile/preferences` → `onboarding_done=true` ✓×2
4. Location — `PUT /me/location` (Q1 / Q3) ✓×2
5. Discovery — `GET /matches` → A thấy B, overlap=6 ✓
6. Swipe mutual-like — A like→no match; B like lại→MATCH ✓
7. Conversations — `GET /conversations` cả 2 thấy ✓
8. WebSocket — `/ws/chat/:id?access_token=` connect cả 2 ✓
9. Chat 2 chiều — 72 tin, Vibe leo 0→72, mỗi bên nhận 37 tin của peer ✓
10. Persistence — `GET /matches/:id/messages` → 73 msgs lưu đủ ✓
11. AI Concierge — `ai_venue_card` fire, 2 quán (King BBQ · Subin BBQ) ✓

matchId=`a77ca800-bba3-4c2d-8be2-79b6f8456e77` · An=`a237d91d…` · Bình=`4839a832…`

---

## ISSUES (sau khi chạy E2E)

### 🔴 ISSUE-1 (P1, data correctness) — Venue grounding hỏng ở web-search path: toạ độ mâu thuẫn địa chỉ + `restaurant_id` rỗng
Card thật trả về:
- **Subin BBQ**: `address` = "…Vincom Plaza Thủ Đức, 216 Võ Văn Ngân, Bình Thọ, **Quận Thủ Đức**" (~13 km từ midpoint) nhưng `lat/lng` = `{10.7830, 106.6949}` → đặt **cách midpoint chỉ 184m**. Toạ độ KHÔNG khớp địa chỉ.
- Cả 2 pick có `restaurant_id` = `""` (rỗng) → card không liên kết được với DB; map-pin / booking / re-anchor không có id để tham chiếu.
- **Root cause:** anti-hallucination (`validatePicks` ép id ⊂ candidates + copy facts từ DB) **chỉ áp dụng cho `DBLLMVenueProvider`**. `WebSearchProvider` tin thẳng output LLM structurer → lat/lng có thể bịa, không kiểm chứng.
- **Hệ quả:** `distance_m` sai, pin sai vị trí, user tới nhầm quán. Đây là rủi ro tin cậy lớn nhất cho MVP map.
- **Đề xuất:** geocode lại từng pick qua Nominatim/Goong (lấy lat/lng từ address thật, KHÔNG từ LLM); hoặc cross-check distance(address-geocode, midpoint) và loại pick lệch > radius; gán `restaurant_id` (upsert vào `restaurants` hoặc hash address).
- File: `anmates-api/services/venue_provider.go` (WebSearchProvider), `ai-venue-search/`.

### 🔴 ISSUE-2 (P1, data correctness) — Tên khu vực sai trong intro ("Xuân Hòa")
- Intro: *"Gặp gỡ chill tại **khu vực Xuân Hòa**…"* nhưng midpoint `{10.78145, 106.69545}` là **trung tâm HCMC** (Bình Thạnh/Q3). "Xuân Hòa" là thị trấn ở **Vĩnh Phúc (miền Bắc)**.
- **Root cause:** reverse-geocode locality sai HOẶC LLM structurer bịa tên khu vực vào intro (không ground vào midpoint thật).
- **Hệ quả:** user đọc thấy địa danh hoàn toàn sai vùng → mất tin tưởng AI.
- **Đề xuất:** lấy tên phường/quận từ reverse-geocode midpoint (Nominatim/Goong) và truyền vào prompt như fact bắt buộc; cấm LLM tự đặt tên khu vực.

### 🟠 ISSUE-3 (P2, UX) — Card chỉ có 2 pick (cap 3), không top-up
- Provider trả 2 quán; không có fallback bù từ seed `restaurants` để đủ 3.
- Web-search variance → đôi khi 0–2 quán. Card mỏng giảm giá trị "gợi ý top-3".
- **Đề xuất:** nếu web-search < 3 → bù bằng DBLLMVenueProvider (seed Q1) cho đủ, đánh dấu nguồn.

### 🟠 ISSUE-4 (P2, reliability) — Sidecar 502 khi prewarm(60)+fire(70) gọi LLM đồng thời
- LM Studio 1 model, tuần tự. Khi 2 request (warm + fire) gần nhau → request thứ 2 timeout → `ai-venue-search http 502` (thấy trong log API). `ai_concierge_runs` ghi row `status=error`.
- E2E chỉ PASS nhờ **pause nhân tạo 25s** sau mốc warm. Chat người thật gửi burst sát ngưỡng 70 sẽ **mất card**.
- **Đề xuất:** concierge/sidecar thêm retry + single-flight queue per-match; hoặc fire dùng lại đúng warm-cache (đã có `takeWarm`) nhưng cần đảm bảo warm xong trước fire (mutex/đợi inflight thay vì bỏ qua).
- File: `services/concierge.go` (`prewarm`/`fire`), `ai-venue-search/`.

### 🟠 ISSUE-5 (P2, ops) — API container vĩnh viễn "unhealthy"
- `docker inspect` → `Status: unhealthy`, `FailingStreak: 301`. Healthcheck = `wget --spider http://localhost:8080/health` nhưng **route `/health` không tồn tại** (log: "Cannot GET /health"; host `curl /healthz` cũng 404). Trong container wget báo "Connection refused".
- **Hệ quả:** false-negative health → che mất downtime thật; phá `depends_on: condition: service_healthy` và readiness trên Cloud Run.
- **Đề xuất:** thêm route `GET /health` (hoặc `/healthz`) trả 200 + sửa healthcheck đúng path; xác minh app bind `0.0.0.0:8080`.
- File: `anmates-api/main.go`, `docker-compose.yml` / `Dockerfile`.

### 🟡 ISSUE-6 (P3, cleanliness) — Dead code paywall
- `services/chat.go CheckPaywall` giờ luôn `return false` (BLOCKER-004 fix) nhưng `handlers/chat.go onIncoming` vẫn giữ nhánh `if locked { return errors.New("chat locked at level 3 — upgrade to continue") }` → nhánh chết + message gây hiểu lầm.
- **Đề xuất:** giữ seam nhưng xoá message lỗi cũ / comment rõ "Phase-2 quota gate ở đây"; hoặc giữ nguyên nếu muốn re-introduce sớm.

### 🟡 ISSUE-7 (P3, pre-ship / security) — TEMP dev deep-link còn trong `main.dart` (uncommitted)
- `_resolveHome` + `_DevChatDeepLink` tự `devLogin(secret:'dev-local-2026')` trên web khi URL có `?dev_match=`. Dùng cho video 2-phone.
- Backend prod chặn (DEV_MODE off → dev-login 403) nên rủi ro thấp, NHƯNG code này KHÔNG được lên production.
- **Đề xuất:** revert trước khi merge `feat/ai-concierge-map`→main (đã ghi nhận TODO từ session 2026-06-06).
- File: `anmates_flutter/lib/main.dart`.

### 🟡 ISSUE-8 (P3, UX polish) — Client vibe mirror lệch authoritative
- `chat_detail_view.dart _bumpVibe` cộng +1/tin client-side nhưng bỏ qua **streak bonus (+5)** server-side và `clamp(0,100)` trong khi points server có thể vượt. Meter desync tới khi reload `/progress`.
- **Đề xuất:** chấp nhận (chỉ cosmetic giữa 2 lần load) hoặc lấy `points` từ ACK message thay vì tự +1.

### Phụ — E2E assertion lỏng
- `picks.length > 0` (không phải `>= 3`) và `pts >= target-4` → card xuống cấp (2 quán, hoặc thiếu) vẫn "PASS". Cân nhắc siết khi muốn dùng làm gate chất lượng.

---

## Ưu tiên đề xuất
1. **ISSUE-1 + ISSUE-2** (grounding lat/lng + tên khu vực) — chặn trải nghiệm map MVP, sửa trước.
2. **ISSUE-5** (healthcheck) — nhanh, ảnh hưởng deploy/ops.
3. **ISSUE-4** (502 concurrency) — trước khi có user thật chat nhanh.
4. **ISSUE-3** (top-up 3 quán), **ISSUE-6/7/8** (cleanup pre-merge).

---

# PART 2 (2026-06-08) — Độ phủ E2E vs full user journey + tổng hợp lỗi 1 lần

## Câu hỏi: `e2e_full_flow.js` có cover hết user journey không?
**KHÔNG.** Script chỉ test **spine happy-path ở tầng API + WebSocket** (~8/24 chặng
journey Phase-1), bằng `dev-login` (bỏ qua Firebase OTP + face verify). **Toàn bộ tầng
UI Flutter không được drive** (script thuần Node fetch/WS — 0 screen/widget chạy). Và
~13 chặng journey Phase-1 (theo product-summary) **chưa được build** ở backend (không
có bảng/route) nên không có gì để E2E.

### Ma trận độ phủ (journey Phase-1 → backend / UI / có trong E2E?)
| Chặng journey | Backend route/table | Flutter UI | Trong E2E |
|---|---|---|---|
| Splash | n/a | ✅ | ❌ |
| 3 màn onboarding edu | n/a | ✅ | ❌ |
| Phone + OTP (Firebase) | `/auth/phone-verify` ✅ | ✅ | ❌ (E2E dùng `dev-login` bypass) |
| Face verify (liveness) | ❌ không có | mock UI | ❌ |
| Profile (Screen 08) | `PATCH /profile/onboarding` ✅ | ✅ | ✅ (API) |
| Tastes (food 09) | `PATCH /profile/preferences` ✅ | ✅ | ✅ (API) |
| Vibe / culture prefs | ✅ (preferences/culture_tags) | ✅ | ⚠️ chỉ food, thiếu vibe/culture |
| Photos upload | `complete-onboarding`+`user_photos` ✅ | ✅ | ❌ |
| Discovery Home/search/rails | ❌ không có | mock (`places_service`) | ❌ |
| Restaurant detail | ❌ không có | mock (`place_detail_view`) | ❌ |
| Wishlist | `GET/POST/DELETE /wishlist` ✅ | ✅ | ❌ **(built, chưa test)** |
| Dining swipe deck | `GET /matches` ✅ | ✅ | ✅ |
| Swipe undo / rewind | `POST /swipes/undo` ✅ | ✅ | ❌ **(built, chưa test)** |
| Match | `POST /swipes`→match ✅ | ✅ | ✅ |
| Chat (WS) | `/ws/chat/:id` ✅ | ✅ | ✅ |
| WS typing / read | ✅ (handler) | ? | ❌ |
| History pagination (cursor) | ✅ | ? | ❌ |
| Vibe meter | `noi_lau_progress` ✅ | ✅ | ✅ |
| AI Concierge auto-card | ✅ | ✅ | ✅ |
| Concierge anchor re-roll | `POST /…/concierge/suggest` ✅ | `concierge_service` ✅ | ❌ **(built, chưa test)** |
| "Too far apart" notice | ✅ | ✅ | ❌ |
| GET/PUT /profile (Tab Mình) | ✅ | ✅ | ❌ **(built, chưa test)** |
| Lá thư (Letters) | ❌ không có | ❌ không có | ❌ **(chưa build)** |
| First Date scheduling | ❌ không có | mock (`booking_view` 0 API, `date_scheduling_sheet`) | ❌ **(chưa build)** |
| Selfie xuất phát | ❌ không có | ❌/mock | ❌ **(chưa build)** |
| Live Tracking (ETA) | ❌ không có | mock | ❌ **(chưa build)** |
| Geofence auto check-in | ❌ không có | mock (`review_checkin_sheet`) | ❌ **(chưa build)** |
| Anonymous review | ❌ không có | mock | ❌ **(chưa build)** |
| Trust Score | ❌ không có | mock (`trust_dashboard_view`) | ❌ **(chưa build)** |
| Safety (block/report/pause/cancel/delete/export) | ❌ không có | ❌/partial | ❌ **(chưa build)** |
| Refresh / Logout | `/auth/refresh`,`/auth/logout` ✅ | ✅ | ❌ |
| /health | ✅ | n/a | ❌ |

Schema xác nhận chỉ 11 bảng: `users, wishlists, matches, messages, noi_lau_progress,
refresh_tokens, user_photos, restaurants, user_locations, ai_concierge_runs, swipes`.
→ Không có `letters, bookings, reviews, trust_events, check_ins, blocks, reports, iap_waitlist`.

---

## 🧾 TỔNG HỢP LỖI 1 LẦN (consolidated)

### A. AI Concierge — chất lượng dữ liệu (chạy ra card nhưng dữ liệu sai)
- **A1 = ISSUE-1 🔴** Toạ độ venue bịa / mâu thuẫn địa chỉ + `restaurant_id` rỗng (anti-hallucination chỉ ở DB path).
- **A2 = ISSUE-2 🔴** Tên khu vực sai trong intro ("Xuân Hòa" cho midpoint HCMC).
- **A3 = ISSUE-3 🟠** Card chỉ 2 quán (cap 3), không top-up từ seed DB.

### B. Độ tin cậy / vận hành
- **B1 = ISSUE-4 🟠** Sidecar 502 khi prewarm(60)+fire(70) trùng (E2E che bằng pause 25s).
- **B2 = ISSUE-5 🟠** API container "unhealthy" — `/health` có CODE nhưng healthcheck Docker vẫn fail (FailingStreak 301; wget "connection refused" trong container → có thể bind addr / image wget). Cần xác minh lại bind `0.0.0.0` + healthcheck path.

### C. Vệ sinh code / pre-merge
- **C1 = ISSUE-6 🟡** Dead code paywall ("chat locked at level 3").
- **C2 = ISSUE-7 🟡** TEMP dev deep-link trong `main.dart` (revert trước merge).
- **C3 = ISSUE-8 🟡** Client vibe mirror lệch authoritative.

### D. Khoảng trống ĐỘ PHỦ E2E (đã build nhưng E2E không chạm) 🟠
- **D1** UI Flutter **0%** được E2E — script thuần API/WS. Không có test widget/integration nào drive splash→onboarding→swipe→chat trên UI thật.
- **D2** Auth thật (Firebase OTP `phone-verify`, refresh, logout) bị bypass bằng `dev-login`.
- **D3** Endpoint đã build nhưng E2E bỏ: **wishlist CRUD**, **swipes/undo**, **GET/PUT /profile**, **complete-onboarding + photos**, **vibe/culture prefs**, **concierge anchor re-roll**, **WS typing/read**, **history pagination**, **too-far notice**.

### E. Khoảng trống PHẠM VI (journey Phase-1 chưa build — không phải bug, là scope) ⚪
- **E1** Lá thư (Letters) — 0 backend, 0 UI.
- **E2** First Date scheduling / booking — chỉ mock UI, 0 backend (`bookings` table không có).
- **E3** Selfie xuất phát · Live Tracking · Geofence auto check-in — chưa build.
- **E4** Anonymous review (T+30) — chỉ mock sheet, 0 backend.
- **E5** Trust Score (đo + dashboard) — chỉ mock UI, 0 backend (`trust_events` không có).
- **E6** Safety: block / report / pause / cancel / delete + data export — chưa build.
- **E7** Discovery Home / search / restaurant detail — mock (`places_service`), 0 backend.

# PART 3 (2026-06-08) — FIX nhóm A+B (user chọn "1") + verify live

User chọn fix nhóm **A (AI Concierge data quality)** + **B (reliability/ops)**. Đã sửa
A1, A2, B2 (A3 cải thiện gián tiếp). **Không** đụng Go/Dart — chỉ Python sidecar +
docker-compose. Re-run E2E full-flow → **20/20 PASS** + card đã đúng.

## Thay đổi
- **B2 — healthcheck** (`docker-compose.yml`): `wget http://localhost:8080/health` →
  `http://127.0.0.1:8080/health`. Root cause: busybox wget resolve `localhost`→IPv6
  `::1`, Go server chỉ listen IPv4 → "connection refused" → container kẹt "unhealthy"
  (FailingStreak 301). `/health` route vẫn luôn tồn tại + 200. **Verify:** recreate api
  → `State.Health.Status = healthy`.
- **A2 — tên khu vực sai** (`service.py` + `structurer.py`):
  - Bỏ prepend `"Khu vực điểm giữa: {area}"` vào context model (OSM/Photon **lẫn
    Nominatim** đều trả `district="Phường Xuân Hòa, Thủ Đức"` cho midpoint trung tâm
    HCMC — dữ liệu OSM sai/hậu cải-cách-phường-2025, không sửa được phía mình).
  - System prompt thêm rule: intro TUYỆT ĐỐI không nêu tên phường/quận/khu vực cụ thể,
    chỉ nói "nằm giữa 2 bạn". `area` vẫn dùng cho search query (King BBQ central chứng
    minh search OK).
  - **Verify:** intro mới = *"Gợi ý 3 quán BBQ/Lẩu chill giữa 2 bạn…"* — hết "Xuân Hòa".
- **A1 — toạ độ venue bịa / mâu thuẫn địa chỉ** (`service.py`):
  - Radius guard động: `_accept_radius_km(radius_m) = max(6km, radius_m/1000*1.5)` thay
    cho hằng `_MAX_GEO_KM=60` cứng. Geocode rơi ngoài bán kính → **drop (lat/lng=0)**,
    không ship toạ độ giả gần midpoint.
  - Khi có street address: **chỉ tin street** — hit trong bán kính = quán; hit ngoài bán
    kính = quán ngoài vùng → 0,0 (KHÔNG fallback sang fuzzy name match, vốn là gốc lỗi
    "Subin BBQ Thủ Đức bị ghim 184m"). Name fallback chỉ dùng khi KHÔNG có địa chỉ.
  - **Verify (card thật):** 3 quán đều in-area — King BBQ 1.10km, PandaBBQ 1.96km, Mini
    Candy 2.85km (≤6km), `distance_m` khớp toạ độ. Quán Thủ Đức kiểu Subin nay sẽ →0,0.
- **A3:** không sửa riêng nhưng run này ra đủ 3 quán.
- **Test mới:** `ai-venue-search/tests/test_geocode_radius.py` (6 case offline,
  monkeypatch `forward_geocode`): far-street→drop, far-street-không-fallback-name,
  near-street→keep, no-address-name-trong-bán-kính→keep, no-address-xa→drop,
  `_accept_radius_km` scaling. **`pytest tests/` = 11 passed** (Docker python:3.12).

## Còn lại (chưa làm trong session này)
- **A1 phụ:** `restaurant_id` vẫn rỗng (web-search path không ground vào DB) — limitation
  cố hữu, cần DB ingest, để sau.
- **B1 (502 concurrency)** — chưa làm (nhóm B nhưng ưu tiên thấp hơn; E2E pause 25s vẫn che).
- Nhóm C (dead paywall, temp deep-link, vibe drift) + D (mở rộng coverage) + E (scope) — chưa.

## Trạng thái
Fix A1/A2/B2 **automated-verified (E2E 20/20 + card đúng + container healthy + 11 unit
test)** nhưng **chưa user-confirm trực quan trên UI Flutter**. Khi user confirm → migrate
sang resolution R-006.

## PART 4 (2026-06-08) — Live test "địa chỉ hiện tại" của user (VPN off) + VIDEO
User tắt VPN, yêu cầu test vị trí thật + quay video. IP-geo (ipinfo/ip-api) → **HCMC
~10.82,106.63** (Gò Vấp/Tân Bình, FPT). Parametrize `e2e_two_users.js` để seed location
qua env (LAT_A/LNG_A/LAT_B/LNG_B, default = vị trí user; B lệch ~400m → midpoint ngay khu user).

**Probe sidecar /suggest (10.823,106.6296):** 1 quán — The Chill BBQ Tây Thạnh (Tân Phú)
1.45km, grounded đúng, intro "giữa 2 bạn".

**Video 2-phone (Playwright + ffmpeg hstack):** chat live 12 dòng → Vibe 70 → card fire
trên cả 2 phone. Card (midpoint 10.82175,106.6314):
- **BBQ Garden** (108/4 Nguyễn Văn Khối, Gò Vấp) → geocode đúng, **3.5km, pin in-area ✓**
- Motsunabe Rakutenchi (Lê Thánh Tôn, Quận 1 ~7km) → **lat/lng=0** (không pin giả ✓)
- Pachi Pachi ("Phố Mạc Đĩnh Chi", mơ hồ) → **lat/lng=0** (không pin giả ✓)
→ **A1 verified thực địa:** quán gần user ghim đúng, quán xa/mơ hồ →0,0 (hết bịa toạ độ
near-midpoint). **A2:** intro không tên khu vực sai.
Output: `videos/ai-concierge-2users.webm` (~1.5MB,94s), `videos/02_{A,B}_card.png`.

**🆕 ISSUE-9 (P3, UI nit) — card hiển thị "0m" cho quán lat/lng=0.** Hệ quả cosmetic của
A1 (toạ độ→0 → distance 0 → "0m" thay vì ẩn). Fix: Flutter `ai_venue_card` ẩn distance khi
`lat==0 && lng==0`. Gộp vào nhóm C. File: `anmates_flutter/lib/widgets/ai_venue_card.dart`.

---

## Kết luận (PART 2)
E2E hiện tại = **"core matchmaking + chat + AI concierge happy-path smoke test (API/WS)"**,
KHÔNG phải full-journey E2E. Đủ để gác regression cho phần lõi đã build, nhưng:
- Cần bổ sung test cho **nhóm D** (đã build, chưa cover) — chi phí thấp, giá trị cao.
- **Nhóm E** là quyết định sản phẩm (build tiếp hay cắt scope MVP) — E2E không thể cover tới khi build.
- Muốn "full e2e user journey" thật sự cần thêm **UI/integration test** (Flutter integration_test hoặc Playwright trên web build) cho nhóm D1/D2.

## Files
- `.dev-e2e/e2e_full_flow.js` (đã có) — script test, 20/20 PASS.
- Không sửa source production trong session này (chỉ catalog issue).

## Open follow-ups
- [ ] User chọn issue nào fix trước (gợi ý: ISSUE-1/2/5).
- [ ] Khi fix xong + user confirm → migrate sang resolution R-NNN.
