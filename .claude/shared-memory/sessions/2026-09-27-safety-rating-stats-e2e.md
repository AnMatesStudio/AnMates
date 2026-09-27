# 2026-09-27 — Bỏ ghép / Chặn / Báo cáo, đánh giá bữa ăn, số liệu trang Tôi + bộ E2E

**TL;DR** — Review UI v2 cho thấy app gặp người lạ nhưng không có unmatch/block/report; màn Rate không lưu
gì; trang Tôi hardcode "24 bữa đã ăn". Đã thêm API + UI cho cả ba, cùng bộ E2E `anmates-api/e2e/`.
Code do Hermes (qwen3.8-27b local) viết theo spec 1 file/lần; main assistant chấm độc lập.
Status: **chưa được user xác nhận** (Path B).

## API mới (migration 018_safety_meals.sql: user_blocks, user_reports, meal_ratings)
- `DELETE /matches/:id` — bỏ ghép, xoá cho cả hai (messages/booking/rating cascade).
- `POST /blocks {user_id}` (201, idempotent) · `GET /blocks` · `DELETE /blocks/:userId`. Chặn = xoá match +
  swipes hai chiều; `ListCandidates` và điều kiện match trong `Swipe` loại cặp có block.
- `POST /reports {user_id, reason, note≤500}` — reason ∈ spam, harassment, fake_profile, no_show, inappropriate, other.
- `POST/GET /matches/:id/rating` — 1..5 sao, riêng tư tới khi cả hai cùng rate (`both_rated`).
- `GET /profile/stats` → `{meals: booking confirmed/completed, matches}`.

## Flutter
- `lib/services/safety_service.dart` (mới); V2State: `submitRate` gọi API thật, `loadStats`,
  `unmatchActive / blockActivePartner / reportActivePartner`; chat header có menu ⋮ (Bỏ ghép · Chặn · Báo cáo);
  trang Tôi hiện số thật, "–" khi chưa có (review chưa có bảng → "–").

## Verification
- E2E `go test ./e2e/` 8/8 (E2E10–14 FAIL trước khi làm → chứng minh test bắt được lỗi); smoke + unit + `go vet ./...` xanh.
- E2E11 bắt được bug thật của Hermes: SQL raw string bắt đầu bằng `` `\ `` → 500 lúc chạy dù build/vet xanh.
- Flutter analyze sạch; full test 1202/1202.
- App thật (web build, Playwright): mở chat → ⋮ → Chặn → Đồng ý → về Inbox rỗng + snackbar; API xác nhận block + mất hội thoại.
- **Chưa kiểm tra bằng UI**: Bỏ ghép, Báo cáo, gửi rating, số liệu trang Tôi (chỉ đã qua E2E API / thấy `/profile/stats` 200).

## Gotchas
- Cổng 8080 trên host là llama-server (Hermes) — `/health` của nó cũng trả 200. Chạy test trong network
  `anmates_default` (`http://api:8080`), hoặc proxy ra 18080 cho web build.
- Deep link `?v2screen=inbox` (V2_DEBUG_NAV) không load hội thoại — bấm tab "Tin nhắn".

## Open follow-ups
- ~~Dialog/snackbar theo Material mặc định; snackbar đè nav bar~~ — xong ở đợt 2.
- ~~Màn Rate chưa hiện rating của mate~~ — xong ở đợt 2.
- ~~Chưa có danh sách đã chặn~~ — xong ở đợt 2 (trang Tôi).
- Test case catalogue: `docs/e2e-test-cases.md`.

## Đợt 2 (cùng ngày) — "Continue improve app"
- **Màn Rate trước đó không vào được** (không có `go(V2Screen.rate)` nào): thêm nút "Đánh giá bữa ăn" ở màn Lịch hẹn khi booking confirmed/completed.
- Màn Rate hiện "<mate> đã rate ★…" khi cả hai đã rate; CTA đổi thành "Cả hai đã rate · bấm để sửa" (trước đó mâu thuẫn "chờ mate rate lại").
- Trang Tôi: danh sách "Đã chặn" + Bỏ chặn (có hỏi lại). Tải lại stats/blocked mỗi lần vào tab Tôi.
- `showV2Confirm` / `showV2Toast` trong v2_kit: dialog theo theme v2, toast nổi TRÊN nav bar (trước bị đè).
- Kiểm chứng: Flutter 1202/1202, analyze lib chỉ còn 2 info cũ ở booking_service.dart; **UI thật 10/10** bằng
  `anmates_flutter/tool/e2e/ui_flows.js` (unblock, rate, report, unmatch đều đối chiếu API/DB).
- Còn lại: tag "Đúng giờ / Dễ nói chuyện…" ở màn Rate chưa lưu (chỉ lưu số sao).

## Đợt 3 (cùng ngày) — "Làm hết rồi commit 1 lần"
- **Lỗ hổng lớn nhất đã sửa: onboarding v2 không lưu gì** → tài khoản mới không bao giờ vào bộ bài quẹt của ai
  (deck chỉ lấy `onboarding_done = TRUE`). Nay sau đăng nhập/đăng ký gửi khẩu vị qua `PATCH /profile/preferences`.
- Migration 019: `users.price_tier`, bảng `notifications` + trigger (match, tin nhắn — gộp 1 chưa đọc/match,
  booking đề xuất/xác nhận/huỷ, rating). API mới: `/profile/match-prefs`, `DELETE /profile`, `/profile/trust`,
  `/profile/history`, `/locals`, `/notifications`, `/notifications/read`; `GET /matches` thêm `district`, `price_tier`.
- Flutter: sheet Sửa hồ sơ (tên, bio, vibe, chi tiêu); bộ lọc lọc thật (không chọn = tất cả, người chưa khai báo
  vẫn hiện); xoá tài khoản; thông báo + badge chuông (trước đó chấm đỏ luôn hiện) + chạm mở chat; Trust Score thật;
  Quán đã đi / Review thật; Local Mates + mời; ảnh trong chat; tag màn Rate được lưu vào note.
- Trust Score = clamp(80 + 4·bữa + 2·rating ≥4★ nhận + −20·người báo bùng hẹn − 10·người báo quấy rối/giả mạo, 0..100).
- Kiểm chứng: Go e2e 14/14 (E2E-15..20 FAIL trước khi làm), smoke/unit/vet xanh; Flutter 1202/1202; UI thật
  20/20 (`tool/e2e/ui_flows_round3.js`) + hồi quy đợt 2 10/10.
- KHÔNG làm (cần hạ tầng ngoài): thanh toán gói (merchant MoMo/VNPay/Store billing), OCR chia bill, push FCM
  (cần server key + service worker) — thông báo hiện là in-app, app tự cập nhật mỗi 30 giây.
- Chưa kiểm bằng UI: upload ảnh thật lên Firebase Storage (tránh ghi vào bucket production khi test); bong bóng ảnh
  đã kiểm bằng tin nhắn ảnh chèn qua DB.
- Còn thiếu nhỏ: icon lọc (tune) ở Explore không có nhãn accessibility.
