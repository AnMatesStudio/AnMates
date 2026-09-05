# 2026-09-03 — UI v2 bỏ mockup data, load quán thật từ DB

**Status:** code done + verified bằng screenshot thật, **CHƯA user-confirm** → session log (Path B).
Khi user confirm → migrate sang resolution R-010.

## TL;DR

UI v2 (import từ Claude Design, xem R-009) render venue từ 2 bảng hardcode trong
`lib/views/v2/v2_data.dart` (`kPlaces` 6 quán bịa, `kVenues` 6 quán bịa). Bảng
`restaurants` có **34 dòng thật** (16 `seed` + 18 `pipeline`) nhưng **không có endpoint
nào expose nó** — nên feed không thể đọc DB dù muốn.

Đã thêm `GET /api/v1/venues` (đọc thẳng bảng `restaurants`) + service/mapper Flutter,
xoá sạch 2 bảng mock. Feed, ô tìm kiếm, chip lọc khu vực, màn chi tiết giờ 100% từ DB.

## Root cause

Ba route venue đã có đều **không** đọc bảng `restaurants`:

| Route | Nguồn thật |
|-------|-----------|
| `/venues/search` | web-search sidecar (`ai_venue_search`) |
| `/venues/nearby` | TomTom / Goong (provider ngoài), fallback Overpass |
| `/venues/image`, `/venues/enrich` | Foursquare → website og:image |

`services/venue.go` có `VenueEngine.SearchCandidates()` đọc `restaurants` nhưng **chỉ
concierge dùng**, không có handler HTTP. Nên khi port UI v2, không có gì để gọi → design
data được giữ nguyên làm mock.

## Solution

### Backend (mới)

- `anmates-api/services/venue_catalog.go` — `CatalogVenue` + `VenueEngine.ListVenues()`.
  Bounding-box prefilter + Haversine chính xác trong Go (cùng pattern `SearchCandidates`),
  sort gần-nhất khi có toạ độ / sort theo tên khi không.
- `anmates-api/handlers/venue_catalog.go` — `GET /api/v1/venues?lat=&lng=&radius_m=&cuisine=&limit=`
  (**public** — trên group `api` trước `api.Use(jwtMW)`; limit mặc định 60 / max 200, timeout 5s).
- `main.go` — đăng ký route, **luôn bật** (không cần key ngoài nào).

`want_count` = số user distinct có `wishlists.food_category` trùng 1 trong
`restaurants.cuisine_tags`. Đây là **tín hiệu demand duy nhất schema có** — `wishlists`
gắn theo *category*, không gắn theo venue. Bằng 0 → UI hiện `—` (không bịa số).

### Flutter (mới)

- `lib/services/venue_catalog_service.dart` — model `CatalogVenue` + `VenueCatalogService.list()`.
- `lib/views/v2/v2_venue_mapper.dart` — `CatalogVenue` → `Venue`/`Place`:
  `districtLabel()` (Q1→Quận 1, TD→Thủ Đức…), `priceLabel()`, `distanceLabel()`,
  `artForCuisine()` (cuisine_tags → 1 trong 6 render 3D trong `assets/v2/`).
- `V2State` — `loadVenues()` (gọi lúc `V2App` mount), expose
  `venues/places/catalog/venuesLoading/venuesError/areaNames`, thêm `openVenueNamed()`.

### Flutter (sửa)

- `v2_data.dart` — **xoá** `const kPlaces` + `const kVenues`; `Venue.district` (int index)
  → `Venue.area` (String, label quận thật).
- `home_screen.dart` — feed đọc `s.venues`; thêm `_FeedPlaceholder` (loading / lỗi / rỗng
  + nút Thử lại). **Không** fallback về sample rows.
- `filters_screen.dart` — chip khu vực đọc `s.areaNames` (quận có thật trong catalogue).
- `search_overlay.dart` — nhận `venues` từ caller thay vì đọc `kVenues`.
- `detail_screen.dart` — badge `AI CULINARY SUMMARY` → `THÔNG TIN QUÁN` / `VENUE DETAILS`
  (nội dung giờ là cột DB, không phải summary do AI sinh).

## Nguyên tắc đã giữ: không bịa số

- Không có `rating` → hiện `—`, không đoán điểm.
- Không có giá → dòng "Khoảng giá" đỏ (`AppColorsV2.alert`) ghi "chưa có giá".
- Không có `address` / `rating` → **bỏ hẳn dòng đó**, không điền chữ thay thế.
- `want_count` = 0 → `—`. `cravingCount` giờ = số quán thật trong catalogue (34), trước hardcode `'14'`.
  (Cập nhật cuối session: `wishlists` đã có 9 row / 4 user → `openTables` hiện **46**, khớp
  đúng `sum(want_count)` query thẳng DB. Số trên UI là thật, không phải hardcode.)
- Catalogue rỗng / lỗi → feed nói rõ, không hiện quán mẫu.

## Files changed

**Go:** `services/venue_catalog.go` (new), `handlers/venue_catalog.go` (new), `main.go`
**Dart:** `services/venue_catalog_service.dart` (new), `views/v2/v2_venue_mapper.dart` (new),
`test/venue_catalog_test.dart` (new), `views/v2/v2_data.dart`, `views/v2/v2_state.dart`,
`views/v2/v2_app.dart`, `views/v2/screens/{home,filters,detail}_screen.dart`,
`widgets/v2/search_overlay.dart`

## Verification (đã chạy thật)

- Go: `go build` + `go vet` GREEN · **golangci-lint v2.12.2 → 0 issues**
- Dart: `flutter analyze` → 8 info (đúng bằng baseline trước session, 0 cái mới)
- `flutter test` → **38/38 pass** (22 cũ + 16 mới)
- API thật: `GET /api/v1/venues?limit=3` trả đúng UTF-8 tiếng Việt;
  `?lat=10.7769&lng=106.7009&radius_m=3000` sort đúng khoảng cách (11m → 420m);
  `?cuisine=lau` → 7 quán
- Browser (Playwright, 420×900): app gọi
  `200 /api/v1/venues?limit=60 → 34 venues`, feed render **Bánh Mì Huỳnh Hoa ★4.5 45–75k**,
  **Bánh Xèo 46A ★4.5 70–130k**, **Bún Bò Giáo Toàn ★4.6 50–90k** — khớp 100% với row DB.
  Màn chi tiết hiện đúng `address` thật "26 Lê Thị Riêng, P.Bến Thành".
- Screenshot: `scratchpad/shots4/{feed_2,detail}.png`

**Bug do test bắt được:** `priceLabel()` ban đầu ra `65k–120k`; format design là `65–120k`
(k chỉ gắn cuối band). Đã sửa implementation.

## ⚠️ Bug đã tự gây ra rồi sửa: route đặt sau JWT → feed rỗng

**Triệu chứng user báo:** *"sao không thấy data gì hết vậy?"*

**Root cause:** lần đầu đăng ký `auth.Get("/venues", ...)` — tức **sau** `auth := api.Use(jwtMW)`.
UI v2 **không có luồng login nào** (`AuthService.devLogin` có định nghĩa nhưng không nơi nào
gọi; `main.dart` → thẳng `V2App`). Browser thật không có token → `401 UNAUTHORIZED` → feed rỗng.

**Tại sao verify lần đầu không bắt được:** script Playwright **tự seed access token** vào
localStorage trước khi chụp → chỉ chứng minh được đường đi khi ĐÃ đăng nhập, không phản ánh
người dùng thật. **Bài học: luôn probe API bằng session KHÔNG token trước khi báo done.**

**Fix:** chuyển sang `api.Get("/venues", ...)` đặt **trước** `api.Use(jwtMW)` → public nhưng
vẫn qua rate limiter. Hợp lệ vì: (a) `/venues/image` + `/venues/enrich` đã public sẵn cùng lý
do; (b) không có gì user-scoped — `want_count` là aggregate toàn bộ user.

**Verified sau fix:** `/venues` không token → **200, 34 quán** (cả trực tiếp :8080 lẫn qua nginx
:54180); `/profile`, `/wishlist`, `/matches` không token → vẫn **401** (không regression).
Browser sạch (không seed token) render đủ feed — `shots5/feed_no_token.png`.

## Key facts / gotchas cho session sau

0. **Route venue công khai vs. auth:** catalogue quán là dữ liệu duyệt công khai → đặt trên
   group `api` TRƯỚC `api.Use(jwtMW)`. Đặt sau = 401 = feed rỗng, vì UI v2 chưa có login.
1. **Máy Windows này KHÔNG có Go và KHÔNG có Flutter trên PATH.** Verify qua Docker:
   - Go: `docker run --rm -v "$(pwd)/anmates-api:/src" -v anmates_gomod:/go/pkg/mod -v anmates-gocache:/root/.cache/go-build -w /src golang:1.25 sh -c "go build ./... && go vet ./..."`
   - Flutter: `docker run --rm -v "$(pwd)/anmates_flutter:/app" -w /app ghcr.io/cirruslabs/flutter:stable sh -c "flutter pub get && flutter analyze --no-pub && flutter test"`
   - **Phải chạy `flutter pub get` mỗi lần** — pub cache nằm trong container, container mới là mất.
   - Prefix `MSYS_NO_PATHCONV=1` khi dùng Git Bash, nếu không Docker mangle đường dẫn.
2. **`COMPOSE_PATH_SEPARATOR=":"` HỎNG trên Windows** — đụng ký tự ổ đĩa `C:`. Dùng nhiều
   cờ `-f` thay vì biến `COMPOSE_FILE`.
3. **Package name Dart là `anmates`**, không phải `anmates_flutter` → import test là
   `package:anmates/...`.
4. **Playwright + Flutter web:** `shared_preferences_web` 2.4.3 lưu localStorage prefix
   `flutter.` và **JSON-encode value**. Muốn seed login phải
   `localStorage.setItem('flutter.access_token', JSON.stringify(token))` — set chuỗi thô
   thì app đọc không ra → 401.
5. UI v2 render bằng canvas → Playwright không select được text, phải click theo toạ độ.
   Ở khung 420×900: CTA welcome ~(210, 578), CTA onboarding ~(210, 813/817),
   tab "Khám phá" ~(68, 843).

## Kiến trúc (user cung cấp cuối session)

Có **2 compose project** chạy song song:
- `anmates` — db-1 (postgres:16-alpine, host **55432**), api-1, ai_venue_search-1, flutter_web-1
- `data_pipeline` — `anm-serving-db` (postgis/postgis:17-3.5, host **5433**)

`data_pipeline` là nơi **thêm data + sync về DB anmates** → giải thích 18 row
`restaurants.source='pipeline'` và migration chưa commit `db/migrations/013_pipeline_source.sql`.
Vậy số quán trong feed sẽ tăng theo pipeline mà không cần đụng code Flutter/Go.

## Phần 2 (cùng ngày) — Ảnh quán thật (lưu bytes trong DB, không dùng URL)

User yêu cầu review cách lưu ảnh, đổi từ URL sang mã hoá base64 lưu thẳng DB.

**Root cause ảnh chết:** publish.py (Data_Pipeline) rewrite path local
(`thumbnails\record-1-0.jpg`) thành URL qua ngrok tunnel của máy chạy pipeline —
tunnel đóng là chết hết. Đã sửa tận gốc: đọc bytes ảnh NGAY LÚC publish (khi file còn đọc
được), base64-encode, lưu cùng row — thay vì lưu link tới 1 máy sẽ tắt.

**Data_Pipeline (KHÔNG phải git repo — sửa trên đĩa, không có gì để commit):**
- `serving/schema.sql`: `foodrec.media_assets` thêm cột `data_base64, mime_type,
  byte_size, sha256` (ALTER TABLE IF NOT EXISTS, idempotent).
- `serving/publish.py`: `_encode_image()` đọc file thumbnail thật, base64-encode,
  sha256 digest; `_frames()` giờ inline bytes thay vì chỉ build URL.
- `serving/sync_anmates.py`: `SELECT_PUBLISHED` thêm `photo_blobs` (json_agg các frame có
  base64); `upsert()` đổi sang `RETURNING id` để lấy UUID phía AnMates; `sync_photos()` mới
  — upsert vào bảng `venue_photos` bên AnMates bằng chính UUID vừa nhận.
- Đã CHẠY THẬT: `python -m serving.publish` → 119/128 frame có bytes (9 file gốc bị thiếu
  trên đĩa, publish.py tự fallback về URL-only cho đúng 9 cái đó, không crash);
  `python -m serving.sync_anmates` → "Synced 17 venue(s), 0 skipped, 0 hidden, 119 photo(s)
  stored across 17 venue(s)."

**AnMates API (anmates-api):**
- `db/migrations/014_venue_photo_blobs.sql` (mới) — bảng `venue_photos` (restaurant_id,
  position, data_base64, mime_type, byte_size, sha256, source_url); unique trên
  (restaurant_id, position) và (restaurant_id, sha256) để dedup khi pipeline chạy lại.
- `services/venue_photo_store.go` (mới) — `Put/Get/CountsFor`; sniff MIME thật bằng
  `http.DetectContentType` (không tin content-type client gửi); cap 3MB/ảnh.
- `handlers/venue_photo.go` (mới) — `GET /api/v1/venues/:id/photos/:position`, public,
  ETag = sha256 (content-addressed → immutable cache header hợp lệ thật, không phải đoán).
- `services/venue_catalog.go` — `CatalogVenue.Photos []string` (URL chết) → `PhotoCount int`
  (đếm từ `venue_photos`); client tự build URL từ id+index, không nhận URL từ server.
- **Đã tự áp dụng bài học phần 1**: route ảnh đăng ký PUBLIC (`api.Get`, không phải
  `auth.Get`) NGAY TỪ ĐẦU lần này — không lặp lại lỗi 401.

**Flutter:**
- `ApiClient.venuePhotoUrl(id, position)` — helper build URL, cùng pattern
  `imageUrl`/`imageProxyUrl` có sẵn.
- `venue_catalog_service.dart`: `CatalogVenue.photoUrls` build từ `photo_count`.
- `v2_venue_mapper.dart`: `Venue.photoUrl`/`Place.photoUrl` = `photoUrls.first` hoặc null.
- `widgets/v2/food_art.dart`: `VenuePhotoOrFallback` — `Image.network` khi có ảnh thật
  (JPEG thật, không phải PNG trong suốt nên KHÔNG dùng hiệu ứng đổ bóng của `FoodArt`),
  fallback về render 3D khi không có ảnh hoặc load lỗi (`errorBuilder`).
- Đã nối vào: `home_screen.dart` (tile + card), `detail_screen.dart` (hero full-bleed,
  bỏ hẳn `FloatingArt` khi có ảnh thật).
- Badge "AI CULINARY SUMMARY" (đã đổi tên phần 1) giữ nguyên.

**Verified:** golangci-lint 0 issues · flutter analyze 8 info (baseline) · flutter test
44/44 · ảnh thật tải được (144KB JPEG, xem đúng là ảnh bún bò Huế từ TikTok) · ETag/304 hoạt
động đúng · slot không tồn tại → 404 đúng · qua nginx không token → 200 (route public đúng
ngay từ đầu). Screenshot: `shots4/detail.png`, `shots_photos/{feed_with_photos,detail_maybe_photo}.png`.

## Phần 3 (cùng ngày) — "Xoá hết data mockup, data giả đi, lấy data thật thôi"

User yêu cầu quét sạch TOÀN BỘ app, không chỉ venue. Trước khi làm liên quan tới 3 cơ chế
game hoá không có thật (Vibe-Check %, Trust Score gating, AI bill-split) — đã hỏi user qua
AskUserQuestion, chọn **"Xoá mô phỏng, không gate gì hết"** (không giữ demo, không xây
backend mới cho 3 thứ này).

### Phát hiện: 2 service Flutter ĐÃ VIẾT XONG, ĐẦY ĐỦ, chưa từng được gọi

`services/match_service.dart` (MatchCandidate/getCandidates/swipe/getConversations/
getHistory) và `services/booking_service.dart` (propose/current/confirm/cancel) — cả hai
production-ready, có sẵn từ trước, nhưng **0 nơi trong views/widgets gọi tới** — bị bỏ rơi
khi UI v1→v2 (R-009). `services/chat_socket.dart` (WebSocket thật, connect/sendText/
dispose) — cũng vậy, orphaned. Việc này biến "xây tính năng chat/match/booking thật" thành
"nối lại dây đã có sẵn", không phải viết mới từ đầu.

### Backend (nhỏ, có lý do): thêm age/food_tags/vibe_tags vào candidate

`models.MatchCandidate` + `services/matching.go ListCandidates`: SELECT thêm
`date_part('year', age(u.birth_date))::int AS age`, `u.food_tags`, `u.vibe_tags` — đều
là cột CÓ SẴN trên `users`, trước đây chỉ chưa được SELECT ra. golangci-lint 0 issues.

### Đã xoá khỏi `v2_data.dart` (528 → 313 dòng)

`kMates` (3 người bịa), `kPrompts/kReplies/kMine` (kịch bản chat giả), `kBill` (số tiền
share bịa), `kTrustLog` (lịch sử điểm bịa), `kLocals` (3 "local guide" bịa), `kVisited` +
`kMyReviews` (4 lượt ghé + 3 review dài bịa), `NotifV2`/`kNotifs` (6 thông báo bịa).
`kRecentSearches` → rỗng (trước hardcode 4 từ khoá). `kTiers` GIỮ (đây là bảng giá gói
subscription — config/copy, không phải "data giả" về một thực thể), nhưng xoá câu chữ
nhắc tới Gating/Trust Booster/Vibe-Check nhanh (cơ chế đã xoá).

### Nối thật

- **Swipe/Mates** (`swipe_screen.dart`): `GET /api/v1/matches` thật (thuật toán overlap
  wishlist có sẵn, không phải mock). Bỏ pill Trust, bỏ badge "urgency" ("Cần ăn trong 1H"),
  bỏ câu "dining intent" bịa → thay bằng `overlap_foods` thật ("CÙNG THÍCH: lẩu thái, bun,
  lau"). `match %` giờ = `score` thật từ SQL overlap, không phải số random.
- **Chat** (`chat_screen.dart`, viết lại hoàn toàn): xoá `_VibeGauge`/`_BoilPainter`
  (gauge sôi giả), `_CelebrateSheet`/`_VibeMatchBadge` (popup ăn mừng giả), `_IceBreaker`
  (câu hỏi phá băng kịch bản sẵn). Transcript đọc `GET /matches/:id/messages` thật; composer
  gửi qua `ChatSocket` thật (WebSocket, không phải REST — không có endpoint gửi tin nhắn
  qua REST, chỉ có `/ws/chat/:matchId`).
- **Bill → Booking** (`bill_screen.dart`, đổi mục đích hoàn toàn): "AI Smart Split" (OCR +
  chia bill + VietQR — không cái nào có backend, DB không có cột tiền nào) → màn Booking thật
  đọc `GET /matches/:id/booking` (đã build sẵn, chưa từng nối).
- **Trust** (`trust_screen.dart`, viết lại): bỏ dial/lịch sử/nút `simulateFlake` (nút giả
  lập tăng giảm điểm — literally chỉ là đồ chơi demo) → panel "Chưa được theo dõi".

### Xoá sạch tham chiếu còn sót (grep xác nhận 0 kết quả)

`me_screen.dart`: "Yuna" hardcode (2 chỗ — cả home_screen lẫn me_screen dùng tên này làm
tên NGƯỜI DÙNG HIỆN TẠI, không phải mate) → `s.profileName` thật từ `GET /profile`
(`V2State.loadProfile()` mới, gọi cùng lúc `loadVenues()`/`loadCandidates()` khi app mount).
`TrustRingPainter`/`s.trust` (dial giả) → bỏ. `_VisitedDeck`/`_ReviewCard` (4+3 mục bịa)
→ 1 dòng honest-empty mỗi mục. `filters_screen.dart`: bỏ hẳn `_TrustToggle` ("chỉ mates
Trust ≥ 90" — không có gì để lọc); `filterCta` giờ đếm `_candidates.length` thật thay vì
số 9/14 hardcode. `home_screen.dart`: stat card thứ 2 ("Trust Score": số bịa) → đổi thành
số ứng viên match thật. `notifications_sheet.dart` (viết lại): 6 thông báo bịa → sheet
kính mờ giữ nguyên, nội dung thành "Chưa có thông báo nào". `local_screen.dart` (viết
lại): 3 local guide bịa → "Tính năng đang phát triển". `search_overlay.dart`: chip
"gần đây" ẩn hẳn khi rỗng thay vì hiện header không có gì bên dưới.

### Bug tự phát hiện qua test thật (Playwright, không phải giả định)

Sau khi wiring xong, seed 1 reciprocal like thật trong DB (2 user dev,
wishlist trùng "lẩu thái"+"bún bò huế" → `overlap_count=4`), bấm "Gửi lời mời đi ăn"
thật trên browser → `POST /swipes` trả `matched:true` → chat mở ra nhưng **header hiện
"—"** thay vì tên đối phương. Nguyên nhân: `inviteMate()` gọi `_removeCandidate()` (xoá
khỏi swipe deck) TRƯỚC khi lưu lại tên người vừa match, nên `mate` getter (đọc từ
`_candidates`) trả về placeholder rỗng. Fix: thêm `_activeMate` (chụp lại info NGAY lúc
match, trước khi xoá khỏi deck) + getter `chatPartner` riêng cho chat/bill/rate (khác với
`mate` — dùng cho swipe deck). Đã sửa + rebuild + chạy lại đúng luồng → tên hiện đúng.

**Verified full loop thật (không giả lập gì):**
1. `GET /matches` → 1 candidate thật (age=28, food_tags/vibe_tags thật, overlap_foods thật,
   score=0.667 → 67% hợp gu)
2. Bấm mời → `POST /swipes` → `{matched:true, match:{id:...}}` thật, ghi vào bảng `matches`
3. Chat mở, header đúng tên đối phương, `GET /matches/:id/messages` → `[]` thật (chưa có gì)
4. Gõ tin nhắn thật, gửi qua WebSocket → verify lại bằng `GET /matches/:id/messages` sau đó
   → **tin nhắn đã lưu thật trong DB**, không phải chỉ hiện optimistic ở client
5. `GET /matches/:id/booking` → 404 "no active booking" (thật, `BookingService.current()`
   xử lý 404 = null đúng theo thiết kế)

golangci-lint 0 issues · flutter analyze 8 info (baseline, không cái mới) · flutter test
**50/50** (thêm `match_candidate_test.dart` mới cho `mateFromCandidate`/`MatchCandidate`).

**Đã dọn data test:** xoá match/message/swipe/wishlist test tạo ra trong session (users
+84999000001/+84999000002 quay về trạng thái trước session, trừ food_tags/vibe_tags/
birth_date của +84999000002 — giữ lại vì đó là profile fields hợp lệ, không phải rác test).

**Lưu ý phụ (không phải bug của session này):** user +84999000002 có tên lưu trong DB bị
lỗi encoding từ trước (`B\xef\xbf\xbdnh` — U+FFFD thay cho 1 ký tự, khả năng "Bình" bị hỏng
dấu từ một lần test cũ qua curl/bash không xử lý UTF-8 đúng). Không phải lỗi do code phần
này gây ra — dữ liệu đã hỏng sẵn trong DB dev trước khi session này bắt đầu.

## Open follow-ups (cố ý chưa làm — ngoài phạm vi "xoá data giả")

- **Ảnh quán thật cho các venue KHÔNG qua pipeline** (16 dòng `source=seed`): vẫn dùng
  render 3D theo cuisine — seed data chưa từng có ảnh, không phải lỗi.
- **Notifications/Local Mates/My Reviews/Visited/Trust Score**: chỉ có honest-empty state,
  CHƯA xây backend thật (không nằm trong yêu cầu "xoá data giả" — đó là xây tính năng mới).
- **Bill/Split thật** (OCR, chia theo món, VietQR): không có schema nào hỗ trợ — bỏ hẳn,
  thay bằng màn Booking (venue+giờ hẹn thật). Muốn có bill thật cần thiết kế bảng mới.
- Filter khu vực/giá/vibe mới chỉ đổi nguồn chip; **chưa nối vào query** — bấm chưa lọc feed
  (tồn tại từ phần 1, chưa đụng tới ở phần 3).
- `V2State._district` vẫn cứng = 0 → `locationLabel` lấy quận đầu bảng chữ cái, chưa phải
  quận thật của user.
- Reconnect `ChatSocket` khi rời rồi quay lại màn chat (`go()`) — đã thêm logic cơ bản
  nhưng CHƯA test kỹ trường hợp mất mạng giữa chừng.


## Phần 4 (cùng ngày) — Deploy public qua Cloudflare Tunnel + fix bake-in + search thật

User yêu cầu deploy public. `cloudflared` đã cài qua winget nhưng chưa `tunnel login` (không
có `~/.cloudflared/cert.pem`) → dùng Quick Tunnel (không cần login, URL ngẫu nhiên
`*.trycloudflare.com`, sống theo tiến trình). Trước khi mở, hỏi user qua AskUserQuestion về
việc có nên khoá `DEV_MODE`/dev-login lại không (đang mở, public thì ai cũng mint được JWT) —
user chọn **giữ nguyên vì còn đang dev, muốn login đơn giản**.

**Bug do chính session này gây ra:** mở tunnel xong, user báo "Không thấy quán nào — DB có
data mà". Root cause: web bundle bị bake cứng `API_BASE_URL` — không phải 1 chỗ mà **3 lớp**:
1. Tôi tự tay truyền `API_BASE_URL=http://127.0.0.1:8080` làm build-arg suốt cả ngày hôm nay
   (thói quen từ lúc mới bắt đầu session), vô tình undo lại quyết định kiến trúc
   "domain-agnostic web build" mà session 2026-09-02 đã cố tình làm.
2. Kể cả sau khi `unset` biến đó trong shell, file `.env` của project có sẵn
   `API_BASE_URL=http://localhost:8080` (rác cũ) — Docker Compose tự nạp `.env` và ưu tiên
   giá trị đó hơn cả default rỗng trong `docker-compose.yml`.
3. `Dockerfile` của `anmates_flutter` cũng có `ARG API_BASE_URL=http://localhost:8080` làm
   default riêng — áp dụng nếu ai đó build thẳng bằng `docker build` không qua compose.

Trên máy dev thì `127.0.0.1`/`localhost` tình cờ đúng (test từ chính máy đó), nhưng trên điện
thoại thật của user thì rỗng — mọi API call thất bại âm thầm → feed rỗng.

**Fix cả 3 lớp về rỗng** (đúng ý đồ đã ghi trong `auth_service.dart`: rỗng → runtime fallback
`Uri.base.origin`, gọi đúng origin đang phục vụ trang, dù là localhost, LAN IP, hay tunnel):
`.env`, `docker-compose.yml` (`${API_BASE_URL:-}` thay vì `:-http://127.0.0.1:8080`),
`anmates_flutter/Dockerfile` (`ARG API_BASE_URL=`). Verify bằng Playwright trỏ THẲNG vào URL
tunnel thật (không phải 127.0.0.1) — trước fix: 3 request bay nhầm về `localhost:8080` bị
CORS/loopback chặn; sau fix: `GET /api/v1/venues` trả 200 đúng origin tunnel.

Đã lưu memory riêng: `verify-from-real-external-origin.md` — bài học "khi expose ra domain
khác, phải test TỪ chính domain đó, không chỉ test từ máy dev".

**Search thật (yêu cầu tiếp theo):** thêm `GET /api/v1/venues?q=` — server-side, không dấu
tiếng Việt (`foldVN`: NFD-decompose bỏ combining mark + fold đ/Đ→d, dùng
`golang.org/x/text/unicode/norm` có sẵn indirect trong go.mod, không cần extension Postgres
nào). Khớp cả tên lẫn địa chỉ. `search_overlay.dart` đổi từ lọc client-side (chỉ trong 60 dòng
đã tải) sang gọi API thật, debounce 300ms từ 3 ký tự trở lên; kết quả hiện ảnh thật qua
`VenuePhotoOrFallback` thay vì luôn render 3D.

**Verified:** unit test `TestFoldVN`/`TestMatchesQuery` (11 case) PASS · golangci-lint 0
issues · flutter analyze 8 info (baseline) · flutter test 50/50 · search qua API thật:
"bun bo" (không dấu) → đúng 2 quán Bún Bò, "lẩu" (có dấu) → đúng 4 quán, "nguyen du" → đúng
Gogi House Nguyễn Du (khớp địa chỉ) · qua Playwright gõ chữ thật trong UI → xác nhận gọi đúng
`GET /venues?q=bun+bo` → count=2 · search + feed đều xác nhận chạy đúng qua tunnel Cloudflare
thật, không chỉ localhost.
