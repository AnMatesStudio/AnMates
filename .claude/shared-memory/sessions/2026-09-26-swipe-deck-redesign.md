# 2026-09-26 — Màn Quẹt theo mockup: deck kéo được, popup hợp gu, hồ sơ mẫu khi không có ứng viên

## TL;DR
Triển khai mockup Quẹt (artifact "AnMates Quẹt") lên Flutter: chồng thẻ kéo phải = mời, trái = bỏ qua
(dấu "MỜI ĂN"/"BỎ QUA", thẻ sau ló mép), nút hoàn tác / ✕ / "Gửi lời mời đi ăn", bộ đếm "i / N", popup
"Hợp gu rồi!" khi lời mời được đáp lại (Nhắn tin chốt kèo → chat thật). Dữ liệu thật từ `/matches`.

## Quyết định của user (AskUserQuestion)
"Thật, trống thì hiện dummy": khi `/matches` rỗng HOẶC 401 (chưa đăng nhập) → deck 10 hồ sơ mẫu
`kSampleMates`, gắn nhãn "Dữ liệu mẫu" ở header + từng thẻ + banner giải thích; mời hồ sơ mẫu KHÔNG gọi
API (lời nhắn "Hồ sơ mẫu: lời mời … không được gửi đi"); 4 hồ sơ `kSampleInvitesBack` mở popup ghi "HỒ SƠ
MẪU" + "không có cuộc trò chuyện thật". Lỗi server (≠401) → màn lỗi + Thử lại, không hiện mẫu.
Trường mockup không có dữ liệu thật (quận, khoảng cách, "Đang thèm", gợi ý quán) → ẩn.

## Code
- `v2_state.dart`: deck = `_candidates` (thật) hoặc `_samples`; `deck`, `deckTotal`, `deckPosition`,
  `deckFinished`, `isSampleDeck`, `sampleBecauseSignedOut`, `matchReveal`/`matchRevealIsSample`,
  `canUndo`/`undoSwipe` (POST /swipes/undo — chỉ cho bỏ qua / lời mời chưa đáp: API undo xoá dòng swipe
  nhưng GIỮ match), `openMatchChat` (load messages → connect socket → booking, như luồng cũ), `dismissMatch`,
  `restartSampleDeck`. Mời thật: bỏ thẻ ngay (optimistic), lỗi thì trả thẻ về đầu. `go()` đóng popup.
  Bỏ `_mateIdx` (thẻ trên cùng luôn là phần tử đầu).
- `v2_data.dart`: `Mate.avatarUrl`, `kSampleMates`, `kSampleInvitesBack`.
- `v2_mate_mapper.dart`: ảnh thẻ = món cùng thích trước; `tasteLabel` (lau→Lẩu…), `tasteArt` (null cho
  tag không phải món), `initialsOf`, `avatarColorFor`. `v2_kit.dart`: `MateAvatar` (ảnh thật / chữ cái).
- `screens/swipe_screen.dart` viết lại: `_Deck` (AnimationController khởi tạo trong initState — `late final`
  lười từng bị tạo lần đầu trong dispose), header + banner + thẻ cuộn chung trong `CustomScrollView`
  (`SliverFillRemaining(hasScrollBody:false)` + minHeight thẻ), hàng nút ghim dưới; `_CardBack` không có chữ
  (thẻ sau bị scale → chữ < 11pt).
- `widgets/v2/match_sheet.dart` (mới), mount ở Stack V2App.

## Tests
- `swipe_deck_test.dart` (9) + `swipe_screen_test.dart` (4): TDD RED (stub) → GREEN. `support/fake_match_api.dart`
  giả /matches, /swipes, /swipes/undo đúng shape JSON.
- Bẫy: ticker bắt đầu đếm ở frame sau `forward()` → test phải pump() rồi mới pump(Duration).
- Matrix thêm `swipe-samples` (pinned "Gửi lời mời đi ăn"), `swipe-match`, `swipe-done`; full 1433/1433.

## Verify local
Build web, chưa đăng nhập → 401 → deck mẫu + banner đăng nhập; kéo phải hiện "MỜI ĂN"; mời Minh Anh → popup
"HỒ SƠ MẪU · Hợp gu rồi!". (Vuốt nhanh về trái khi thả = bỏ qua — đúng thiết kế fling.)

## Open
- Chưa thử luồng match thật end-to-end trên prod (cần 2 tài khoản đã onboarding cùng mời nhau).

## Deploy prod
`43cf3df` + `802e91b` → CI `36236434022` + CD `36236580328` xanh (10:42:57Z). Prod qua onboarding → tab Quẹt:
`GET /matches` 401 → deck 10 hồ sơ mẫu + banner đăng nhập + "1 / 10"; mời → popup "HỒ SƠ MẪU · Hợp gu rồi!";
không có request /swipes nào; không page error.
