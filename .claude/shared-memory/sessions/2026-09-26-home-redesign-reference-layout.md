# 2026-09-26 — Thiết kế lại Home (Explore) theo layout tham chiếu, giữ màu v2 + glass nav

## TL;DR
User đưa 1 ảnh tham chiếu (app "bukas": header vị trí + avatar, lời chào, search, ô danh mục,
2 hàng card "See all →", bottom nav) và yêu cầu Home AnMates theo layout đó, giữ màu gốc v2 và
thanh điều hướng dưới. Design bounded trình bày trong chat, user duyệt "implement và push".

## Quyết định (đã duyệt)
- Header: "📍 Trong {r} km ⌄" (chưa có vị trí → "Chưa bật vị trí"), dòng phụ "Tìm quán ngon quanh
  bạn"; bấm → sheet bán kính (thay nút "Trong X km" cũ). Phải: chuông + avatar (→ Tôi).
- Lời chào theo giờ: `greetingFor(hour)` sáng 5–10 / trưa 11–12 / chiều 13–17 / tối; kèm tên /profile.
- Search full-width, icon tune ở đuôi → màn "Lọc bể match" (giữ lối vào duy nhất của màn đó).
- Ô danh mục `kFeedCategories` (Tất cả, Lẩu, Nướng, Mì phở, Hải sản, Cà phê, Tráng miệng — bỏ Bia hơi vì
  0 quán có tag bia/bar), ảnh 3D có sẵn, ô chọn nền wisteria. Lọc thật phía client trên danh sách đã
  tải (đã cắt theo bán kính); tiêu đề "Quán {món} gần bạn". Danh mục trống mà vẫn có quán trong bán
  kính → "Không có quán {món} nào trong X km" + "Xem tất cả món".
- 2 hàng card kiểu tham chiếu: ảnh trên, khung trắng: tên (+ ★ chỉ khi có rating — prod 0/50 có
  rating nên bỏ "Top rated"), 📍 quận + ➤ khoảng cách. "Quán gần bạn" + "Kèo mở tối nay", pill
  "Xem tất cả →".
- Bỏ: hero 3D "N mates đang thèm" (thực chất là số quán), 2 thẻ số liệu, CTA "Gom kèo tối nay"
  (trùng tab Quẹt). Giữ thẻ "Tìm Local Mates" (lối vào duy nhất màn Local).
- Gộp đề xuất cũ: khi chưa có vị trí, bấm header hoặc Áp dụng sẽ hỏi lại vị trí
  (`_resolveDeviceLocation(retry:)`) — không cần reload sau khi cho phép trong trình duyệt.

## Code
- `v2_data.dart`: `FeedCategory` + `kFeedCategories` (thay `kCategories`).
- `v2_state.dart`: `_feedCategory`, `homeVenues`, `setFeedCategory`, `sectionTitle` theo danh mục,
  `openRadiusSheet`, `locationHeadline`, `greetingLine`, `greetingFor`; `loadVenues(retryLocation:)`;
  bỏ `locationLabel`/`cravingCount`/`openTables`/`_district` (chỉ hero/số liệu dùng).
- `screens/home_screen.dart` viết lại: `_Header`, `_SearchBar`, `_CategoryTiles`, `_SectionHeader`,
  `_VenueRow`/`_VenueCard`; giữ `FeedWashPainter`, `_NotifButton`, `_FeedPlaceholder` (+ nhánh
  danh mục), `_LocalMatesCard`.

## Tests
- `home_feed_test.dart` (5): lọc danh mục + tiêu đề, lời chào theo giờ (bảng biên), hỏi lại vị trí khi
  Áp dụng / khi bấm header, vẫn không có vị trí thì giữ feed. TDD RED (stub) → GREEN.
- `home_screen_test.dart` (3 widget): ô danh mục lọc + đổi tiêu đề, danh mục trống → "Xem tất cả món",
  card có quận + km. `radius_filter_test` đổi sang header.
- Bẫy gặp: (1) test cũ bấm nút empty-state nằm dưới glass nav "ăn may" vị trí → thêm `tapInFeed`
  (`ensureVisible` trước khi tap); (2) ô danh mục thứ 6 nằm ngoài màn → finder `skipOffstage: false`
  + ensureVisible; (3) matrix bắt vùng bấm search chỉ cao 20pt → Row `crossAxisAlignment.stretch`.
- Full suite 1250/1250, matrix 1156/1156, analyze chỉ 2 info sẵn có (booking_service).

## Verify (build local, proxy GET /venues → prod)
Chrome headless: feed đầy (ghim trung tâm TP.HCM) → header "Trong 20 km", "Chào buổi chiều!", danh mục,
card "Quận 1 · 420 m"; bấm Lẩu → "Quán lẩu gần bạn" chỉ còn quán lẩu; không quyền vị trí → "Chưa bật
vị trí", card không km; 320 px: sau khi rút chữ header không còn bị cắt ("Quanh bạn · trong…" cũ bị cắt
mất số km). Không page error.
