---
id: R-009
title: Import Claude Design "Mobile app design planning" → port toàn bộ 19 màn thành v2, user duyệt, xoá sạch UI v1
tags: [flutter, design-import, claude-design, ui-migration, v2, delete-old-ui, ios-frame, aurora-gradient, vibe-check, onboarding, google-fonts, negative-margin, phone-frame, viewport-meta]
platforms: [web, android, ios]
severity: major
status: confirmed
date_resolved: 2026-09-02
confirmed_by: user
related_sessions: [sessions/2026-09-02-explore-v2-design-import.md]
related_blockers: []
---

# R-009: Import Claude Design → port 19/19 màn thành `lib/views/v2/` → user duyệt → xoá sạch UI v1

## TL;DR
Design mới trên Claude Design (project `fa249917-433c-4553-b1ae-8909eed150ed`, "Mobile app
design planning") được pull qua tool built-in `DesignSync` + export `.zip` thủ công (asset >256KB
bị `get_file` cắt), port thành **19/19 canvas frame** vào `lib/views/v2/` (Flutter, không phải
web). Sau khi user xem trên `flutter run -t lib/main_v2.dart`/build web và duyệt, toàn bộ UI v1
(`lib/views/*` trừ `v2/`, `lib/widgets/*` trừ `v2/`, `lib/theme/app_theme.dart`, 3 thư mục asset
cũ) bị xoá; `lib/main.dart` viết lại làm entry point duy nhất trỏ vào `V2App`.

## Symptoms (không phải bug — đây là yêu cầu tính năng + review)
N/A — đây là resolution cho một tính năng lớn (import design + xoá UI cũ), không phải fix bug.
Ghi lại vì tốn nhiều vòng lặp, có state quan trọng cho việc tiếp tục port hoặc rollback.

## Root Cause (bối cảnh kỹ thuật, không phải "nguyên nhân lỗi")
Không áp dụng theo nghĩa root-cause-of-bug. Bối cảnh: user có sẵn app Flutter production
(anmates_flutter) với UI v1 (Berry/Ocean palette, Plus Jakarta Sans) đã ship, cùng lúc thiết kế
UI mới (v2: Wisteria/aurora gradient, Be Vietnam Pro) trên Claude Design. Yêu cầu: import design
mới, giữ v1 chạy song song để review, rồi xoá v1 khi duyệt xong.

## Solution

### Steps — Phase 1: Import design (xem chi tiết đầy đủ ở session log)
1. Pull qua tool built-in `DesignSync` (KHÔNG dùng MCP connector `claude_design` — connector đó
   luôn 403 `FIRST_PARTY_AUTH_REJECTED` dù đã add + user `/design-login`). User phải chạy
   `/design-login` trong session **tương tác** (không phải headless/SDK) — sau đó `DesignSync`
   dùng chung credential đó.
2. `Canvas.dc.html` chỉ là bảng index (`<dc-import pin-screen="...">`) — UI thật nằm ở
   `AnMates.dc.html` (template dòng 9–988, script/state dòng 989+).
3. `DesignSync.get_file` cắt binary ở **256 KiB** — `hotpot.png`/`bbq.png` (>700KB) bị hỏng.
   Giải pháp cuối: user tự export **Project HTML → Download (.zip)** từ Claude Design UI, chứa
   asset nguyên bản. Đường vòng qua "Send to Claude Code" hoặc PNG-export không đủ (mất giá trị
   gốc / vẫn bị cắt).
4. Port 19 frame theo 5 flow (A Onboarding 5 màn, B Explore+Detail, C Filters+Swipe+Local,
   D Chat+Bill+Rate, E Me+Trust+Pay) thành Flutter widget thật — không dùng WebView.

### Phase 2: 3 bug thật bắt được qua golden-render test (không phải cosmetic)
| Bug | Nguyên nhân | Fix |
|---|---|---|
| Crash ở Profile "quán đã đi" | `Container(margin: EdgeInsets.only(left: -44))` — Flutter cấm margin âm (`margin.isNonNegative`) | `Stack` + `Positioned` step 74px thay vì margin âm |
| Crash ở lưới gu món | `ListView(padding: left: 24 + shift)` với shift âm — `padding.isNonNegative` | Ban đầu: `Transform.translate`. **Sau đó user báo chip bị cắt mép** → đổi hẳn sang shift dương `[0,46,0,62]` (lệch design có chủ đích, xem R-009 §Gotchas) |
| Overflow AI Smart Split title | Font fallback rộng hơn Be Vietnam Pro khi offline | `Expanded` + `TextOverflow.ellipsis` |
| Nút Quẹt bị nav kính che, không kéo được | `navClearance` tính thiếu — `SafeArea` trong `GlassNavBar` + khung desktop `padding.bottom=34` không cộng dồn đúng | Helper `navClearance(context) = 96 + MediaQuery.paddingOf(context).bottom`, áp cho mọi màn có control ở đáy (swipe/chat/bill/rate/local/trust/filters) |
| Responsive vỡ trên desktop browser | `web/index.html` **thiếu hẳn `<meta name="viewport">`** → browser dùng layout viewport mặc định 980px rồi scale | Thêm 1 dòng viewport meta (ảnh hưởng cả v1 lúc đó — chấp nhận được vì bug thật) |
| Không crop thành khung điện thoại trên desktop | Chưa có `_webFrameBuilder` cho v2 | Copy pattern từ `main.dart` v1 (đã có sẵn cho app cũ), artboard đổi thành 402×874 đúng design, sửa luôn lỗi kế thừa từ v1 (`Size(frameW, 900)` hardcode bất kể `frameH` đã clamp thấp hơn) |

### Phase 3: User duyệt → xoá UI v1 (yêu cầu: "giữ lại phần nào có thể sử dụng tiếp")
Nguyên tắc phân loại: services/models/utils là business logic UI-agnostic (đã verify bằng grep:
**0 file** trong `lib/services|models|utils` import bất cứ gì từ `lib/views|widgets`) → giữ.
Mọi thứ trong `lib/views/*` (trừ `v2/`) và `lib/widgets/*` (trừ `v2/`) chỉ được import bởi
chính v1 views khác → xoá sạch, không mồ côi.

**Đã xoá** (`git rm -rf`, force qua 2 file có uncommitted edit từ session trước — nội dung đã
lưu trong `sessions/2026-09-02-admin-password-login-remove-phone-otp.md`):
- `lib/views/{auth,booking,chat,discover,map,match,onboarding,place_detail,profile,sheets,splash,trust}/`
  + `lib/views/main_tab_view.dart`
- `lib/widgets/{ai_venue_card,anm_logo,anm_widgets,horoscope_icons,open_now_badge,venue_thumbnail}.dart`
- `lib/theme/app_theme.dart` (kéo theo `ThemeNotifier` — class rỗng "kept for compatibility")
- `lib/main_v2.dart` (gộp nội dung vào `main.dart`, không cần entry point riêng nữa)
- `assets/{food,avatars,icons}/` — verify bằng grep repo-wide: chỉ được dùng bởi
  `onboarding_view.dart`/`photo_upload_view.dart` (đã xoá), không nơi nào khác đụng tới
- `integration_test/app_test.dart` — test nguyên flow splash→onboarding→auth→main-tabs của v1,
  không còn màn nào để test

**Đã giữ nguyên** (đúng yêu cầu "phần dùng tiếp được cho v2"):
- `lib/services/*` (18 file — auth, booking, chat_socket, concierge, location, map_navigation,
  maps_launcher, match, onboarding_draft, places_search, places, profile, storage,
  venue_enrich/image/reviews/search, wishlist)
- `lib/models/*`, `lib/utils/*`, `lib/firebase_options.dart`
- `lib/theme/app_theme_v2.dart`, `lib/views/v2/*`, `lib/widgets/v2/*`, `test/v2/*`
- `test/{places_merge,session_persistence,opening_hours}_test.dart` (test service thuần, không
  đụng UI)

### Code changes
| File | Change |
|------|--------|
| `lib/main.dart` | Viết lại hoàn toàn: entry point duy nhất, Firebase init giữ nguyên, bỏ dev deep-link (gắn với `ChatDetailView` đã xoá), `home: V2App()`, `_webFrameBuilder` port từ v1 (402×874, glow Wisteria) |
| `pubspec.yaml` | `assets:` chỉ còn `- assets/v2/` |
| `test/widget_test.dart` | Viết lại: smoke test `AnMatesApp` mới, assert `'Ăn Mates'` (chữ ở màn Welcome) |
| `test/ai_venue_card_test.dart` | Bỏ 2 test render `AiVenueCard` widget (đã xoá) + import `widgets/ai_venue_card.dart` + `services/concierge_service.dart` (hết dùng); giữ 4 test `AiVenueCardContent.tryParse` (model thuần) |
| `lib/views/v2/v2_data.dart` | `kTasteRowShifts` đổi `[0,-46,0,-62]` → `[0,46,0,62]` (xem Gotchas) |

## Verification
- `flutter analyze` → 0 lỗi (8 `info` còn lại pre-existing trong `services/`, không liên quan)
- `flutter test -j 1` → **22/22 pass** (⚠️ `flutter test` mặc định KHÔNG dùng `-j 1` làm mất
  2 file test trong chế độ song song — xem Gotchas, không phải do session này gây ra)
- `flutter build web --release` (target mặc định `lib/main.dart`) → build thành công, serve
  local, browser mở lên đúng UI v2, asset `assets/v2/*` trả HTTP 200
- User tự soi từng màn trên `flutter run -t lib/main_v2.dart` + desktop browser, báo đúng 2 bug
  (lưới gu món hàng 2/4, màn Quẹt không kéo được + nút bị che) → cả hai đã fix và user confirm
  bằng cách yêu cầu bước tiếp theo (xoá UI cũ) — tức đã duyệt UI v2.

## Why this fix works (for future-Claude)
- **Layer tách bạch = xoá an toàn.** Trước khi xoá bất cứ file UI nào, luôn `grep -rn` xem
  `services/models/utils` có import ngược từ `views/widgets` không. Nếu **0 kết quả**, xoá
  views/widgets không bao giờ làm gãy backend layer — đây chính xác là lý do lần xoá 20+ file
  này build/test đều xanh ngay lần đầu.
- **`git rm` từ chối xoá file có local modification chưa commit** — đây là tính năng an toàn,
  không phải lỗi. Dùng `-f` chỉ khi chắc chắn nội dung uncommitted đó đã có nơi khác lưu lại
  (ở đây: đã có trong `sessions/2026-09-02-admin-password-login-remove-phone-otp.md`) và đích
  đến cuối cùng của thay đổi đó là xoá toàn bộ file — không phải mất công vô tình.
- **`flutter test` (không có `-j`) có thể silently drop cả file test khi chạy song song** trong
  môi trường sandbox này — không liên quan gì tới code, đã tái hiện trên test service thuần
  (`session_persistence_test`, `opening_hours_test`) không hề bị đụng trong session này.
  **Luôn verify bằng `-j 1` nếu tổng số test "có vẻ đúng" nhưng danh sách file thấy thiếu.**

## Gotchas / Related issues
- **Lệch design có chủ đích ở lưới gu món (A4).** Design gốc dùng `margin-left: -46px/-62px`
  cho hàng 2/4 để chip so le, nhưng điều đó kéo chip đầu tràn khỏi mép trái — không đọc được,
  không bấm được. Đã đổi dấu thành dương (`+46/+62`, đẩy phải) để giữ hiệu ứng so le mà không
  cắt chip nào. Nếu sau này đối chiếu lại design gốc thấy "sai" hướng lệch — đây là quyết định
  có ý thức, không phải lỗi port.
- **`hotpot.png`/`bbq.png` gốc từ `get_file` vẫn hỏng** cho tới khi user export `.zip` thủ công.
  Nếu tương lai cần asset mới từ cùng design project qua `DesignSync`, kiểm tra `truncated` field
  trong response — nếu `true` và file >256KB, phải xin `.zip` thay vì cố gọi lại `get_file`.
- **Web app giờ chỉ có 1 entry point** (`lib/main.dart`). `flutter run -t lib/main_v2.dart` vẫn
  từng dùng để dev riêng v2 lúc còn song song v1 — file đó đã bị xoá, giờ `flutter run` mặc định
  (không cần `-t`) là đủ.
- **Naming còn mang hậu tố `_v2`** (`AppColorsV2`, `V2App`, `V2State`, thư mục `views/v2/`,
  `widgets/v2/`) dù giờ là UI duy nhất — **cố ý chưa rename** vì đó là refactor riêng, rủi ro
  cao hơn (đụng 15+ file), không nằm trong yêu cầu "xoá UI cũ" của user. Nếu user muốn dọn tên
  sau này, làm thành task riêng.
- `pubspec.yaml` dependencies (firebase_auth, image_picker, flutter_map, vector_map_tiles,
  geolocator...) **chưa được audit/prune** — vẫn được `services/` còn lại sử dụng, build thành
  công xác nhận không có gì thừa gây lỗi, nhưng chưa kiểm tra có dependency nào chỉ v1 UI dùng
  mà giờ services cũng không cần nữa (out of scope cho lần dọn này).

## References
- Session gốc: [sessions/2026-09-02-explore-v2-design-import.md](../sessions/2026-09-02-explore-v2-design-import.md)
- Design system doc (đã update thêm section "Hệ v2"): `design-system.md`
- Design project: Claude Design `fa249917-433c-4553-b1ae-8909eed150ed` ("Mobile app design planning")
