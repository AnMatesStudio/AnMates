# 2026-09-26 — Home feed "Chưa có quán nào trong khu vực này" dù DB có 50 quán

## TL;DR
User mở app.anmates.site, Home hiện "Chưa có quán nào trong khu vực này" ở cả 2 hàng, request
`/api/v1/venues?limit=60&lat=…&lng=…&radius_m=20000` trả `200 {venues: []}`.
API không lỗi: quán gần nhất cách vị trí đó **83,6 km**, còn feed lọc cứng **20 km**. Đã thêm
fallback phía client — không có quán trong 20 km thì lấy các quán gần nhất ở bất kỳ đâu (vẫn
sort gần → xa, tile hiện khoảng cách thật).

## Root cause
- `V2State.loadVenues()` (`anmates_flutter/lib/views/v2/v2_state.dart`) gọi `/venues` với
  `radius_m=20000` mỗi khi có vị trí thiết bị (radius này có từ b2714c5, 2026-09-05). Không có
  đường lui: rỗng → `_venuesError = 'empty'` → `_FeedPlaceholder`. Nút "Thử lại" gọi lại
  `loadVenues(force: true)` với cùng vị trí đã cache → luôn rỗng.
- Catalogue prod (đo 2026-09-26): 50 quán active, 100 % `source='pipeline'`, chỉ nằm ở TP.HCM,
  Hà Nội, Đà Lạt/Lâm Đồng, Bình Dương, Vũng Tàu, Nha Trang. Toạ độ trong bug (một điểm ở
  miền Tây) cách quán gần nhất 83,6 km (Ốc Hẻm 239/29A, Q6).
- Kiểm chứng trên prod với cùng toạ độ: `radius_m=20000` → total 0; `100000` → 22; không
  radius → 50. Seed cũ (006) cũng chỉ ở Q1/Q3 nên đây không phải do dọn quán dummy (§6
  RUNBOOK_UPDATE_PHOTOS) — ở vị trí đó feed luôn rỗng.
- Màn "Xem tất cả" (`loadMoreAllVenues`) vốn không gửi radius → đã hiện đủ 50 quán; chỉ Home
  bị rỗng.

## Solution
`loadVenues()`: nếu query 20 km rỗng **và** có vị trí → gọi lại `list(lat, lng)` không radius
(giống cách "Xem tất cả" query). Giữ nguyên bounding-box prefilter cho trường hợp thường (có
quán gần), chỉ tốn thêm 1 request khi rỗng. API không đổi ngữ nghĩa `radius_m` (concierge /
search vẫn cần lọc chặt). Catalogue rỗng thật → vẫn `'empty'` như cũ.

## Files changed
- `anmates_flutter/lib/views/v2/v2_state.dart` — fallback trong `loadVenues()` + doc comment.
- `anmates_flutter/test/v2/load_venues_test.dart` (mới) — `V2State` + `VenueCatalogService` +
  `ApiClient` thật; chỉ fake 2 biên ngoài: HTTP (`MockClient`, fixture là row thật từ prod) và
  `GeolocatorPlatform` (toạ độ đúng trong bug). 3 case: fallback, có quán trong radius thì không
  gọi lần 2, catalogue rỗng vẫn là `'empty'`.

## Verification
- TDD: test fallback FAIL trước khi sửa (`venuesError` = `'empty'`), PASS sau khi sửa.
- `flutter test` toàn bộ: 1114/1114 PASS. `flutter analyze`: chỉ 2 info có sẵn ở
  `booking_service.dart` (không đụng tới).
- App thật: `flutter build web --release --dart-define=V2_DEBUG_NAV=true`, serve same-origin
  qua proxy local (chỉ forward GET `/api/v1/venues*` sang prod, mọi `/api` khác trả 401 local),
  Chrome headless (playwright-core, `channel: 'chrome'`) ghim geolocation đúng toạ độ trong bug,
  mở `/?v2screen=home`. Request thật: 20 km → total 0, rồi fallback → total 50. Home hiện Ốc Hẻm
  "83,6 km · 45–130k", Khoai Xiên Nướng "88,5 km", Mơ Nướng "89,1 km" + ảnh thật, hàng "Kèo mở
  tối nay" có card.
- **Chưa commit, chưa deploy prod, chưa user xác nhận.**

## Open follow-ups
- **Hero `locationLabel` sai sẵn (không do fix này):** lấy tên quận đứng đầu bảng chữ cái trong
  danh sách đã tải + chuỗi cứng "trong 3 km" (radius thật là 20 km). Đo: ở trung tâm TP.HCM với
  code cũ cũng hiện "Bình Dương · trong 3 km"; khi feed rỗng hiện "Quận 1 · trong 3 km" (kAreaNames[0]).
  Số to bên dưới (`cravingCount`) là `_catalog.length`, dán nhãn "mates đang thèm ăn tối nay".
- `profile` / `matches` đỏ trong DevTools của user = 401 khi không có phiên đăng nhập (explore
  feed là public, 2 endpoint này cần JWT) — không liên quan lỗi quán.
- Có thể thêm dòng nhỏ "Chưa có quán trong 20 km — đây là quán gần bạn nhất" khi đang ở fallback
  (hiện chỉ có khoảng cách trên từng tile nói điều đó).

## Key facts
- Python python.org trên macOS thiếu CA bundle → `SSL_CERT_FILE=/etc/ssl/cert.pem`.
- Cloudflare trước app.anmates.site chặn UA `Python-urllib/*` (403 challenge HTML); UA tự đặt
  như `anmates-local-verify/1.0` hoặc curl thì qua.
- `package:geolocator/geolocator.dart` re-export `GeolocatorPlatform` → fake location trong test
  bằng `GeolocatorPlatform.instance = <subclass>` không cần thêm dependency.
- http 1.6.0 decode `application/json` không charset bằng UTF-8.

## Update (cùng ngày) — fallback đã bị thay
User chọn "tôn trọng tuyệt đối" khi làm filter bán kính 5–100 km: fallback "quán gần nhất ở bất
kỳ đâu" ở trên **đã bị gỡ**. Feed giờ chỉ hiện quán trong bán kính user chọn; trống thì hiện nút
"Mở rộng bán kính". Test fallback trong `load_venues_test.dart` được viết lại theo hành vi mới.
Xem `sessions/2026-09-26-home-feed-radius-filter.md`.
