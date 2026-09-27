# 2026-09-27 — Lọc quán (venue filter) tách khỏi Match filter

## TL;DR
Icon lọc (tune) trên thanh tìm kiếm Khám phá trước đây mở **Match filter** (lọc mates: bán kính người,
khu vực, giá, vibe sống) — sai chỗ: Khám phá là feed quán. User yêu cầu: filter ở đó phải lọc **quán ăn**,
tìm mates có filter riêng.
- Khám phá → icon tune → màn mới **"Lọc quán"** (`V2Screen.venueFilter`): Khoảng cách (chính bán kính feed
  5–200 km), Món ăn (đồng bộ ô danh mục), Khu vực / Quận (quận của quán trong bán kính), Khoảng giá / người
  (chip nhiều lựa chọn). Nút "Xem N quán phù hợp" ghim đáy, đếm sống. Icon tune có badge số bộ lọc đang bật.
- Quẹt → nút tune mới (góc phải header) → **Match filter** (`V2Screen.matchFilter`, logic cũ giữ nguyên).
- Cả hai màn có nút back (về Khám phá / Quẹt) và CTA ghim đáy.

## Quy tắc lọc (chốt trong code, không hỏi user)
- **Giá**: tier `<50k`, `50–150k`, `150–350k`, `>350k`; quán khớp khi dải `price_min–price_max` chạm tier
  (biên thuộc cả hai tier). Chỉ có một đầu giá ("từ 45k") → coi dải là đúng giá đó. **Quán không có giá bị ẩn
  khi đã chọn mức giá** (khác Match filter, nơi người thiếu dữ liệu vẫn hiện) — lọc quán theo giá là lời hứa.
  Nhiều tier = hợp (OR). `venueInPriceTier()` ở `v2_venue_mapper.dart`.
- **Khu vực**: lưu theo *tên* (`Set<String>`), không theo index — đổi bán kính ngay trên màn lọc sẽ tải lại
  catalogue và danh sách quận đổi. Quận đã chọn mà bán kính mới không còn vẫn hiện để bỏ chọn. Không có chip
  "Chưa rõ". Quán không có quận bị ẩn khi đã chọn khu vực.
- **Món**: chính `_feedCategory` (single-select) — chọn trong màn lọc = chọn ô danh mục trên Khám phá.
- **Bán kính**: chính `_radiusKm` của header "Trong X km" (lưu SharedPreferences); kéo xong mới gọi
  `setRadiusKm` (1 request). "Đặt lại" KHÔNG reset bán kính (nó là "đang nhìn ở đâu", có control riêng).
- Không có lọc rating: prod 0/51 quán có `rating`.
- Lọc phía client trên `homeVenues` (tối đa 60 quán của feed). **Chưa áp cho "Xem tất cả"** (danh sách phân
  trang từ server) — cần API `district`/`price` nếu muốn.
- Feed rỗng vì bộ lọc → "Không có quán nào khớp bộ lọc" + "Xoá bộ lọc".

## Files changed
- `anmates_flutter/lib/views/v2/v2_state.dart` — enum `filters` → `venueFilter` + `matchFilter`; `_venueAreas`,
  `_venuePrices`, `homeVenues`/`_venueMatches`, `venueAreaNames`, `venueFilterCount`, `matchFilterCount`,
  `venueFilterCta`, `toggleVenueArea`, `toggleVenuePrice`, `resetVenueFilters`.
- `lib/views/v2/v2_venue_mapper.dart` — `venueInPriceTier`.
- `lib/views/v2/screens/venue_filter_screen.dart` (mới), `screens/filters_screen.dart` → `match_filter_screen.dart`
  (`MatchFilterScreen`, back → Quẹt).
- `lib/widgets/v2/area_picker.dart` (tách từ `_AreaSection` cũ, dùng chung), `lib/widgets/v2/filter_parts.dart`
  (`FilterLayout` CTA ghim đáy, `FilterHeader`, `FilterCountBadge`).
- `lib/views/v2/screens/home_screen.dart` (tune → venueFilter + badge, empty state), `screens/swipe_screen.dart`
  (nút lọc mates), `v2_app.dart`.
- Test: `test/v2/venue_filter_test.dart` (12), `test/v2/responsive_matrix_test.dart` (pinned CTA 2 màn lọc).
- E2E: `tool/e2e/ui_venue_filter.js` (UI-24, chạy được cả local lẫn prod, không cần đăng nhập);
  `ui_match_radius.js`/`ui_flows_round3.js` đổi `?v2screen=filters` → `matchFilter`. `docs/e2e-test-cases.md`.

## Verification
- TDD: 12 test mới RED → GREEN; 3 mutation (tune → matchFilter, giá "từ X" mở vô hạn, bỏ quận đã chọn) đều bị bắt.
- Full Flutter: 1419/1419 (baseline 1339). `flutter analyze`: chỉ 2 info cũ ở booking_service.
- UI thật (build web local → API prod, Chrome headless ghim vị trí Nhà hát TP, 20 km): 13/13 PASS —
  29 quán → Quận 1: 6 → >350k: 3; badge 2; Đặt lại về 29; Quẹt → Match filter → back. Không page error.
- Prod: xem mục Deploy bên dưới.

## Open follow-ups
- Tiêu đề Quẹt: dòng phụ "Quẹt theo gu ăn, không theo ngoại hình" xuống 2 dòng ở 402 px vì thêm nút lọc.
- "Xem tất cả" chưa theo bộ lọc quán.
- Khu vực trong Match filter vẫn lấy từ quận của *quán* (hành vi cũ, không đổi).
