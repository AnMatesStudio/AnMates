# 2026-09-26 — Filter bán kính tìm quán 5–100 km trên Home (tôn trọng tuyệt đối)

## TL;DR
User ở xa TP (vd một điểm ở miền Tây, quán gần nhất 83,6 km) tự chọn bán kính cho feed Home: nút
"Trong 20 km ▾" dưới tiêu đề feed → sheet kính có slider 5–100 km (bước 5 km) + "Áp dụng".
Lựa chọn được lưu (SharedPreferences) qua các phiên. **Tôn trọng tuyệt đối (quyết định B của
user)**: không có quán trong bán kính → feed trống + nút "Mở rộng bán kính" (mở sheet); đã ở
100 km thì nút thành "Xem tất cả quán". **Thay thế fallback "quán gần nhất ở bất kỳ đâu"** của
bản sửa sáng cùng ngày (`sessions/2026-09-26-home-feed-empty-outside-catalogue-cities.md`).

## Quyết định đã chốt với user
- A: nút + sheet trên Home, slider liên tục (bước 5 km) — không đặt vào màn "Lọc bể match"
  (màn đó lọc mates, CTA sang Quẹt, filter ở đó chưa nối API).
- B: tôn trọng tuyệt đối, feed trống + "Mở rộng bán kính" — không tự lấy quán ngoài bán kính.
- Mặc định 20 km; "Xem tất cả" + ô tìm kiếm giữ nguyên (không radius); API không đổi.

## Solution
- `v2_state.dart`: `kRadiusMin/Max/Step/DefaultKm` (5/100/5/20); `_keepRadiusKm` kẹp + snap
  bước 5 (giá trị lưu từ build khác có thể lệch); `radiusKm`, `feedRadiusKm` (bán kính feed
  đang hiện đã lọc, null = không có vị trí), `radiusSheetOpen`, `locationUnavailable`;
  `setRadiusKm()` lưu pref `venue_radius_km` rồi `loadVenues(force: true)`; `_restoreRadius()`
  đọc 1 lần (pick trong phiên thắng giá trị cũ, kể cả khi đang await). `loadVenues()`: bỏ
  fallback, dùng `_venuesSeq` — request mới nhất thắng (đổi bán kính khi request cũ còn bay
  thì response cũ bị bỏ). `locationLabel`: "· trong {feedRadiusKm} km" thay "3 km" viết cứng.
  `go()` đóng sheet. `seedVenues(rows, {radiusKm})` + `_venuesError='empty'` khi rỗng.
- `widgets/v2/radius_sheet.dart` (mới): kính/scrim như NotificationsSheet, bám đáy trên nav;
  giá trị giữ local khi kéo, chỉ gửi khi "Áp dụng"; nội dung cuộn được, nút luôn trong màn;
  `semanticFormatterCallback` → "100 km"; overlayRadius 24 → slider cao 48.
- `home_screen.dart`: `_RadiusPill`; `_FeedPlaceholder` 4 trạng thái bằng switch
  (lỗi → Thử lại; không vị trí → "Chưa có quán nào" + Thử lại; trống < 100 km → "Không có quán
  nào trong X km" + Mở rộng bán kính; trống ở 100 km → Xem tất cả quán); nút dùng `V2TapTarget`.
- `v2_app.dart`: mount `RadiusSheet` trong Stack overlay.

## Tests
- `test/v2/support/fake_venue_api.dart` (mới): fake `GET /venues` lọc theo `distance_m` như
  handler thật, `hold` giữ response theo `radius_m`; `FixedLocation`/`NoLocation`
  (GeolocatorPlatform); fixture row thật prod (Ốc Hẻm, Khoai Xiên, Ba-Bát HN) + 1 row bịa gần.
- `load_venues_test.dart` (viết lại, 8 test) + `radius_filter_test.dart` (4 widget test qua
  `V2AppBody` thật): TDD RED (stub API → fail đúng lý do) → GREEN. Mutation thật: bỏ guard seq
  → test race fail; bỏ kẹp khi restore → test "saved radius outside" fail.
- Responsive matrix thêm `radius` (68 test, gồm pinned "Áp dụng") + `home-empty` (51 test).
- Full suite 1242/1242; analyze chỉ 2 info sẵn có ở booking_service.dart.

## Verification app thật
Build web release (`V2_DEBUG_NAV=true`), proxy local chỉ forward GET `/api/v1/venues*` lên
prod, Chrome headless ghim geolocation đúng điểm trong bug: 20 km → total 0 (feed trống + Mở rộng bán kính)
→ slider 100 km (`aria-valuetext` "100 km") → Áp dụng → `radius_m=100000` → total 22, tile Ốc Hẻm
83,6 km… → reload trang → request đầu `radius_m=100000`, nút "Trong 100 km" (pref sống qua
reload). Không page error.

## Gotchas (driver)
- Flutter web: bấm `flt-semantics-placeholder` để có DOM semantics; cuộn bằng wheel TRƯỚC khi
  bật semantics (sau đó DOM semantics nuốt wheel).
- `locator.click()` của Playwright tự cuộn DOM semantics → Flutter scroll lệch → "intercepts
  pointer events"; click chuột thật tại tâm bounding box node thì được.
- Slider web = `<input type="range">`; ArrowRight liên tiếp không delay bị gộp → chờ ~150 ms/phím.

## Open follow-ups
- Tên khu vực trên hero vẫn sai sẵn ("Chưa rõ"/"Bình Dương" = quận đầu bảng chữ cái của list).
- Ở 390×844, nút "Mở rộng bán kính" của hàng thứ 2 nằm dưới nav cho tới khi cuộn (feed vốn
  cuộn dưới nav kính — đúng thiết kế).

## Deploy prod (cùng ngày)
- Commit `4302d65` feat(web) + `d3da776` docs, push main. CI `36217992114` xanh (Go API + Flutter
  Web) → CD `36218141377` xanh (helm upgrade + smoke web → api), xong 04:33:39Z.
- Prod `main.dart.js` last-modified 04:32:09Z, chứa `venue_radius_km`, `cf-cache-status: BYPASS`.
- Chạy thật trên app.anmates.site (onboarding "CÙNG ĂN THÔI" → "Đăng nhập" vào Explore, Chrome
  headless ghim đúng điểm trong bug): 20 km → total 0, hiện "Không có quán nào trong 20 km" +
  "Mở rộng bán kính"; kéo 100 km → Áp dụng → total 22, tile Ốc Hẻm / Khoai Xiên Nướng. Không page error.
- Test fixture dùng điểm bịa `farLat/farLng` (10.0, 105.5): repo PUBLIC, toạ độ trong bug là vị trí
  thiết bị của user — không commit toạ độ đó ở bất kỳ đâu.

## Phát hiện khi verify prod: font icon bị Cloudflare cache bản cũ (CHƯA sửa, chờ user)
- Nút "Trong X km" trên prod mất icon place + mũi tên. `MaterialIcons-Regular.otf` (tên cố định,
  nội dung là subset tree-shake theo icon đang dùng) được nginx gắn `public, max-age=7200`
  (regex static asset). Edge: HIT, age 5725, last-modified 25/09 10:06, 8800 B; origin (cache-bust
  `?cb=`, MISS): 9144 B, 04:32:11 = đúng bản build mới. Tự hết khi edge hết TTL (≤2h sau lần cache),
  nhưng browser đã tải font cũ còn giữ thêm tới 2h.
- Cùng họ R-010 / bản sửa 2026-09-25 (entry JS `private, no-cache`) — font/manifest chưa được bao.
- Đề xuất: thêm `assets/fonts/*.otf`, `assets/packages/**.ttf`, `assets/FontManifest.json`,
  `assets/AssetManifest.*` vào nhóm `private, no-cache` (304 rẻ nhờ ETag); hoặc purge Cloudflare
  trong CD sau helm upgrade (cần API token làm secret).
