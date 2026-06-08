# 2026-06-07 — E2E test: full flow từ đầu → 2 user chat + tính năng khung chat

## TL;DR
Test **toàn bộ luồng từ đầu** (dev-login → onboarding → preferences → location →
discovery deck → mutual-like swipe → match → conversation → WebSocket chat → Vibe
climb → AI Concierge venue card) bằng một script Node API+WS mới
(`.dev-e2e/e2e_full_flow.js`, dùng `fetch`/`WebSocket` built-in của Node 24).
**16/16 bước flow chính PASS.** Phát hiện + xử lý 2 lỗi môi trường và 1 **mâu thuẫn
thiết kế** chặn AI Concierge trigger tự nhiên.

## Cách test
- Stack đã chạy sẵn (docker compose). Script tự dev-login 2 user
  (`+84900000011` An, `+84900000012` Bình), clean state, rồi chạy tuần tự từng bước,
  in PASS/FAIL. Repeatable.
- Chạy: `node .dev-e2e/e2e_full_flow.js` (env: `MSG_TARGET`, `PHONE_A/B`, `DEV_SECRET`).

## Kết quả PASS (luồng thật, không mock)
1. Auth — dev-login 2 user ✓
2. Onboarding — `PATCH /profile/onboarding` ✓ (2 user)
3. Preferences — `PATCH /profile/preferences` (6 food_tags chung) → `onboarding_done=true` ✓
4. Location — `PUT /me/location` ✓ (Q1 / Q3)
5. Discovery — `GET /matches` → A thấy B trong deck, **overlap=6** ✓
6. Mutual-like — A like B → `matched=false`; B like lại → **MATCH tạo** ✓
7. Conversations — `GET /conversations` → cả 2 thấy cuộc trò chuyện ✓
8. Realtime — WebSocket `/ws/chat/:id?access_token=` connect cả 2 ✓
9. Chat 2 chiều — gửi tin qua WS, cả 2 nhận tin của nhau, Vibe +1/tin ✓
10. Persistence — `GET /matches/:id/messages` lưu đủ tin ✓
11. **AI Concierge `ai_venue_card`** — khi Vibe vượt 70, sidecar web-search + LM Studio
    structurer trả về **3 quán thật** (King BBQ / The Chill Buffet / Subin BBQ) khớp gu
    lau/bbq/spicy/chill + midpoint + toạ độ + giá; broadcast qua hub về cả 2 phone ✓

## Lỗi phát hiện + xử lý

### BUG-A (môi trường) — container API chạy image STALE
- API container đang chạy image build **trước** khi thêm `010_swipes.sql` + code
  mutual-like. `docker compose up -d` (không `--build`) tái dùng image cũ → bảng
  `swipes` không tồn tại, route/logic swipe sai bản.
- **Fix:** `docker compose build api && docker compose up -d api`. Migration chạy
  qua `//go:embed migrations/*.sql` lúc khởi động → 010 được apply.
- **Bài học:** sau khi đổi code Go / thêm migration phải **rebuild image**, không chỉ restart.

### BUG-B (data) — pgdata volume cũ thiếu cột `level`
- `noi_lau_progress` trong volume local thiếu cột `level`. Nguyên nhân: volume tạo
  2026-05-25 đã apply một migration lịch sử `003_noi_lau_drop_level.sql` (DROP level)
  — file này **không còn trong repo** (003 hiện tại là `003_onboarding.sql`). Vì
  `schema_migrations` đã ghi nhận nó, runner không bao giờ tái tạo cột.
- Hậu quả: `createMatch` (`INSERT noi_lau_progress (match_id,points,level)`),
  `CheckPaywall` (`SELECT level`), `IncrementPoints` (`UPDATE … SET level`),
  `noi_lau.Get` (`SELECT points,level,…`) đều cần `level` → **match creation 500**
  ("swipe failed"). Cả luồng match đứng.
- **Fix (giữ data):** `ALTER TABLE noi_lau_progress ADD COLUMN IF NOT EXISTS level int NOT NULL DEFAULT 1;`
  → khớp lại với `001_initial.sql` hiện tại. DB mới (prod/CI/volume fresh) KHÔNG bị —
  chỉ volume local cũ. Có thể reset volume thay vì ALTER nếu muốn sạch.

### ⚠️ MÂU THUẪN THIẾT KẾ (cần quyết định product) — paywall lv3 chặn trigger Concierge 70
- `CheckPaywall` khoá chat khi `level >= 3`. `NoiLauThresholds=[0,10,30,60,100]` +
  `LevelForPoints(30)=3` ⇒ chat **khoá cứng ở 30 điểm** ("chat locked at level 3 —
  upgrade to continue").
- Nhưng AI Concierge + "First Date" mở ở **70 điểm** (`AI_TRIGGER_POINTS=70`, UI
  "mở khi vibe ≥ 70"). ⇒ **không thể chat tự nhiên tới 70** vì bị khoá ở 30 →
  Concierge **không bao giờ tự fire** qua chat thật. Test #9 dừng đúng ở points=30.
- Mâu thuẫn với LOCKED Phase-1 decision "MVP FREE (no paywall)" + cơ chế vibe≥70.
- Để verify được AI card phải seed thủ công points=69, level=1 rồi gửi 1 tin vượt
  ngưỡng (đã làm → card fire OK). Đây là lý do e2e cũ phải seed điểm.
- **Đề xuất fix (1 trong):** (a) bỏ hẳn hard-lock level-3 cho MVP free (đúng Phase-1);
  (b) nâng ngưỡng khoá > 70; (c) tách "paywall" khỏi "level" Nồi Lẩu. → raise BLOCKER-004.

## Hạn chế đã biết (không phải lỗi)
- Venue web-search: `restaurant_id` rỗng (không ground vào DB), đôi khi quán xa
  (Subin BBQ ~10km / Thủ Đức) hoặc `address` lẫn text rác ("36,163 likes…"). Đã ghi
  nhận ở session 2026-06-04. UI card hiển thị theo `name` nên vẫn render OK.

## Files
- `.dev-e2e/e2e_full_flow.js` (mới) — script test API+WS toàn flow.
- Live env: rebuild image `anmates-api`; `ALTER TABLE noi_lau_progress ADD level` trên DB local.
- KHÔNG sửa source code production (mâu thuẫn paywall để user quyết).

## Xem trên UI thật (Flutter web)
- Match đang ở 70đ kèm card: deep-link 2 phone (port 54180 + 54181 riêng localStorage):
  - An:  `http://127.0.0.1:54180/?dev_match=<matchId>&dev_phone=%2B84900000011&dev_mate=Bình`
  - Bình:`http://127.0.0.1:54181/?dev_match=<matchId>&dev_phone=%2B84900000012&dev_mate=An`
- Hoặc chạy `.dev-e2e/run-e2e.ps1` để quay video 2-user (cần seed điểm vì mâu thuẫn trên).

## Update 2026-06-08 — paywall removed (BLOCKER-004 fix) → E2E 20/20 GREEN
User: "hiện tại làm để test thị trường" → chọn MVP FREE (option a). `CheckPaywall`
(`services/chat.go`) đổi thành luôn `return false` (bỏ hard-lock level-3). Rebuild
image. Chạy lại `e2e_full_flow.js`: **20/20 PASS** — Vibe leo 0→72 tự nhiên (không
còn kẹt 30), AI `ai_venue_card` fire end-to-end (King BBQ · Subin BBQ).
- 1 lần đầu sau fix bị FAIL ở bước 11 vì sidecar **502**: prewarm(60đ)+fire(70đ) gọi
  LM Studio (1 model, tuần tự) gần như đồng thời khi gửi 72 tin @90ms → request 2
  timeout. Xác nhận generation vẫn OK bằng test seed 69→70 (1 tin) → card fire.
  Đã thêm pause 25s sau mốc warm trong e2e (mô phỏng nhịp chat thật phút/tin) → GREEN.

## Open follow-ups
- [ ] User confirm + verify UI Flutter trực quan (mở deep-link 54180/54181 — render card/quick-reply/Vibe bar). Khi confirm → migrate sang resolution R-NNN.
- [ ] Cân nhắc reset pgdata volume local cho sạch (loại migration phantom 003_drop) thay vì ALTER.
- [ ] (robustness, optional) sidecar/concierge thêm retry/queue để tránh 502 khi warm+fire trùng (chỉ ảnh hưởng burst, không phải chat thật).
- [ ] Phase-2: re-introduce quota gate tại CheckPaywall (consumer quotas, NEVER token meters).
