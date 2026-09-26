# 2026-09-26 — Quẹt: dấu LIKE/NOPE kiểu Tinder, avatar minh hoạ cho hồ sơ mẫu, "Nhắn tin" cho cả hồ sơ mẫu

## TL;DR
Yêu cầu của user: "Chữ Bỏ qua bắt chước style Tinder và chữ English. Cho avatar user generate AI. Chỗ UI hợp gu thêm
nút nhắn tin". Higgsfield còn 0 credit → user chốt (AskUserQuestion) "Tôi tự vẽ avatar minh hoạ": 10 avatar flat
illustration vẽ bằng SVG tham số, bundle PNG trong app, không tốn phí, không phải ảnh người thật.

## Thay đổi
- **Dấu trên thẻ** (`swipe_screen.dart`): luôn là tiếng Anh kiểu Tinder, không phụ thuộc VI/EN: `LIKE` xanh
  `#1FCB6E` nghiêng −0.34 rad bên trái (kéo phải), `NOPE` đỏ `#FF4458` nghiêng +0.34 bên phải (kéo trái); viền 5,
  không nền, chữ 38 w900 letterSpacing 3.
- **Avatar**: `assets/v2/avatars/sample-1..10.png` (288 px, ~25 KB), sinh bằng một script Python tạo SVG tham số
  (9 kiểu tóc, 6 kiểu áo, kính/khuyên tai/kẹp tóc/râu, 3 tông da) + render bằng Playwright. Script nằm ở scratchpad
  của phiên (tạm), KHÔNG có trong repo — muốn sửa avatar thì vẽ lại hoặc đưa generator vào `tool/`. `Mate.avatarAsset`;
  `MateAvatar(asset:)` ưu tiên ảnh thật (url) → asset → chữ cái đầu. Dùng ở thẻ, popup hợp gu, header chat.
- **Popup hợp gu** (`match_sheet.dart`): luôn có "Nhắn tin chốt kèo" (CTA chính) + "Quẹt tiếp". Hồ sơ mẫu ghi
  "Hồ sơ mẫu: tin nhắn chỉ nằm trên máy bạn, không được gửi đi."
- **Chat mẫu** (`v2_state.dart`): `openMatchChat()` với hồ sơ mẫu → màn chat, `isSampleChat = true`, KHÔNG load
  messages, KHÔNG mở WebSocket, KHÔNG load booking; `sendRealMessage` thêm tin vào `_sampleMessages` cục bộ.
  `messages` getter trả về `({text, mine})` cho cả hai chế độ. `chatSub` dùng `tasteLabel` (lau → Lẩu).
  Match thật (trong `inviteMate`) reset `_sampleChat` — nếu không, chat mẫu → đăng nhập → match thật → "Quẹt tiếp"
  → tab Tin nhắn sẽ mở chat thật ở chế độ mẫu và tin nhắn không được gửi (bắt được khi review trước commit).
- **Màn chat** (`chat_screen.dart`): header dùng `MateAvatar` (trước là ảnh món ăn); chat mẫu có banner "Hồ sơ mẫu:
  … không được gửi đi và không ai trả lời.", ẩn hàng "Đặt bàn cho bữa ăn này" và chấm online xanh.

## Tests
- `swipe_deck_test.dart`: avatar của cả 10 hồ sơ mẫu nằm trong bundle (`rootBundle.load` > 1000 B); Nhắn tin với
  hồ sơ mẫu → chat, `isSampleChat`, tin nhắn cục bộ, API chỉ nhận `GET /api/v1/matches`.
- `swipe_screen_test.dart`: qua shell thật: mời → Nhắn tin chốt kèo → banner "Hồ sơ mẫu", không hàng đặt bàn,
  không chấm online, gửi tin hiện trên màn.
- RED trước (avatar null, Nhắn tin mẫu không rời Quẹt, chấm online còn) → GREEN. Mutation: hiện lại hàng đặt bàn /
  bỏ banner / tắt nhánh mẫu trong `openMatchChat` → đều fail.
- `swipe_deck_test.dart`: match thật sau chat mẫu → tab Tin nhắn là chat thật (RED: `isSampleChat` true → GREEN).
- Matrix thêm `swipe-match-sample`, `chat-sample` (ghim TextField). Full 1556/1556; analyze chỉ 2 info có sẵn
  (`booking_service.dart`).

## Verify local
Build `--dart-define=V2_DEBUG_NAV=true` (chỉ bản chụp local; `?v2screen=swipe` chỉ hoạt động khi có define này),
proxy chỉ chuyển GET /venues lên prod, mọi /api khác 401 local. Kéo phải → LIKE, kéo trái → NOPE, mời Minh Anh →
popup có avatar + Nhắn tin chốt kèo → chat mẫu, gửi "Tối nay đi lẩu không?" hiện bong bóng; request chỉ có
profile/matches/venues lúc tải, không có /messages hay /ws; không page error.

## Bẫy gặp
- `dart format` format lại cả chat_screen.dart (+213/−119) vì codebase không theo dart format → áp edit lên bản
  HEAD, không format.
- `flutter build web` lỗi `Couldn't resolve the package 'url_launcher_web'`: `.dart_tool/flutter_build`
  còn web_plugin_registrant cũ (url_launcher không có trong pubspec) → xoá `.dart_tool/flutter_build` rồi build lại.

## Open
- Chưa commit/deploy (chờ user).
