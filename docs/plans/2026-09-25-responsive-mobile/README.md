# Responsive mobile cho Flutter UI v2 — plan & task specs

**Ngày:** 2026-09-25 · **Phạm vi:** `anmates_flutter/lib/` (UI v2, 12 màn + shell + 2 overlay)
**Người thực thi:** Claude sub agent (task nền tảng + verify) · Hermes local (task 1 file)
**Trạng thái:** rev 2 — **đã thực thi** Phase A–B (theo khuyến nghị D1–D4), push `main`; Phase C: verify prod + máy thật.

> **rev 2 (cùng ngày):** đã cài 5 skill mobile/Flutter UI (§9) và đo lại khi **tắt hẳn scale** (§1.1).
> Kết quả làm plan nhỏ đi nhiều. Không màn nào vỡ layout ở 6 viewport dọc từ 320×568 tới 440×956,
> vì các màn vốn đã cuộn được. Vậy lỗi thật nằm ở cơ chế scale + phần đệm đỉnh cố định + chữ/vùng bấm quá nhỏ
> ngay trong thiết kế. Không cần viết lại layout từng màn. Các task "co giãn art" chuyển sang Phase D
> (chỉ làm khi ảnh chụp chứng minh cần). Bỏ cờ chuyển tiếp: làm trên nhánh riêng, verify xong mới merge.

---

## 1. Nguyên nhân gốc (đã đo, không phải đoán)

Toàn bộ UI v2 là "pixel port" của khung thiết kế **402 × 874**. Để vừa màn thấp hơn,
[`DesignFrame`](../../../anmates_flutter/lib/widgets/v2/design_frame.dart) (commit `3a93fc1`)
**thu nhỏ cả app theo chiều cao**: `k = min(1, chiềuCao / 874)`. Nó chỉ nhìn chiều cao.

Trên web mobile, thanh công cụ của trình duyệt ăn mất chiều cao, nên màn hình nào cũng bị thu nhỏ.
Đã đo bằng widget test chạy trên code hiện tại (render thật, không phải tính tay):

| Viewport | k | Chữ nav 9pt hiện ra | Chữ "Chào buổi tối" 9.5pt | Bề ngang layout "tưởng" có |
|---|---|---|---|---|
| Khung thiết kế 402×874 | 1.000 | 9.0pt | 9.5pt | 402 |
| iPhone 15 · Safari 393×659 | 0.754 | **6.8pt** | **7.2pt** | **521** |
| iPhone 15 Pro Max · Safari 430×740 | 0.847 | 7.6pt | 8.0pt | 508 |
| iPhone SE · Safari 375×548 | 0.627 | **5.6pt** | **6.0pt** | **598** |

Hệ quả, khớp với ảnh chụp trên `app.anmates.site`:

1. **Chữ và nút bé đi 16–37 %**: nút filter 48pt còn 36pt, nhãn nav còn ~7pt, dưới mức tối thiểu 11pt của Apple.
   Bản thân thiết kế đã dùng 9–10.5pt ở vài chỗ nên sau khi scale càng tệ.
2. **Layout tưởng mình rộng 520–600pt**, rộng hơn mọi điện thoại, nên các hàng card
   ngang và hero art được bố trí như trên máy tính bảng.
3. **Khoảng trống lớn ở đỉnh**: các màn đệm cứng `top: 96/100/104`, vốn giả định có notch cao ~60pt.
   Trên Safari web `MediaQuery.padding.top = 0`, nên ~60pt bị bỏ trống. Ảnh chụp cho thấy đúng như vậy:
   pill profile bắt đầu ở ~74pt màn hình ≈ 97pt layout.
4. **Safari co giãn toolbar khi cuộn** → chiều cao đổi → `k` đổi → toàn bộ UI phóng/thu theo khi cuộn.

Test hiện có (7/7 pass) không bắt được lỗi nào ở trên. Lý do: chúng chỉ kiểm tra "không overflow"
và "CTA nằm trong màn", chứ không kiểm tra cỡ chữ hay tap target sau khi scale.

### 1.1 Đo lại khi tắt scale (rev 2)

Tạm cho `DesignFrame` trả `k = 1` (qua một `--dart-define`), rồi pump 12 màn + 5 bước onboarding ở 7 viewport,
bật semantics, với dữ liệu rỗng như trong test. Sau khi đo đã revert, `git diff` sạch.

| Kiểm tra | Kết quả |
|---|---|
| Overflow / exception | **0** ở 320×568, 360×640, 375×553, 393×668, 402×874, 440×956. Xoay ngang 844×390: chỉ `onb3` (14px) và `onb4` (23px) |
| Chữ < 11pt | Giống nhau ở **mọi** viewport, nên đây là cỡ chữ của thiết kế chứ không phải lỗi layout: nhãn nav 9, VI/EN 10.5, "Chào buổi tối" 9.5, stat label 10.5, "THÔNG TIN QUÁN" 9.5, eyebrow 10.5, mini-stat Me 10 |
| Vùng bấm < 44pt (`iOSTapTargetGuideline`) | 2–14 mỗi màn, cũng giống nhau ở mọi viewport: VI/EN (~25pt cao) trên mọi màn, nút back ‹ (38–40), chip ở Filters (tới 14 cái), sao/tag ở Rate, link "Đã có tài khoản? Đăng nhập" (19pt cao) |
| Kiểm chứng bộ kiểm | Guideline tap báo fail đúng khi thử một nút 20×20. Cỡ chữ đo được 9.5 chứ không phải 6.0, chứng tỏ scale đã tắt thật |

**Chưa đo được:** dữ liệu thật (card quán, thẻ mate), khi đó có thể overflow ở chỗ khác. Chồng lấn
`Stack/Positioned` không sinh lỗi nên cũng không bắt được. Cả hai cần T01 (seed dữ liệu) và T05 (ảnh chụp).

## 2. Hướng xử lý

**Bỏ scale theo chiều cao. Các màn vốn đã reflow được (§1.1), chỉ cần sửa cho đúng:**

- **Chữ:** cỡ cố định theo pt, không bao giờ nhân hệ số. Tôn trọng `textScaler` của người dùng
  (kẹp tối đa 1.3×). Sàn cỡ chữ theo quyết định D2.
- **Đỉnh:** `V2Layout.contentTop(context) = safeTop + 56` thay cho mọi hằng `96/100/104`
  (toggle ngôn ngữ ở `safeTop + 8`, vùng bấm cao 48).
- **Đáy:** `navClearance(context)` (đã có) là nguồn duy nhất; ẩn nav khi bàn phím mở.
- **Vùng bấm ≥ 48×48** (`V2Layout.minTap = 48`). Skill `ui-ux-pro-max` nêu: iOS 44pt, Android 48dp,
  và đừng dùng một số cho mọi nền tảng. Nhưng một bundle web chạy cả hai, nên lấy 48 là phủ được cả hai.
  **Chỉ nới vùng bấm, giữ nguyên hình vẽ.** Test chạy cả `iOSTapTargetGuideline` lẫn `androidTapTargetGuideline`.
- **Rộng > 480** (tablet native, điện thoại xoay ngang): cột nội dung giữa màn, `maxWidth 480`,
  **và ghi đè `MediaQuery.size` thành bề ngang của cột**. Nếu không, `MediaQuery.sizeOf` (vd. bong bóng chat
  `width * 0.74`) sẽ tính theo cửa sổ thay vì cột (skill `flutter-build-responsive-layout`).
  Desktop web giữ khung điện thoại, nhưng **chỉ khi** `width > 600 && height >= 700`.
- **Xoay ngang được hỗ trợ, không khoá hướng** (skill `flutter-adaptive-ui`). Chỉ onb3/onb4 cần sửa. Khi màn
  rất thấp (`height < 500`), nav thu gọn chỉ còn icon, để 96pt nav không chiếm 1/4 màn.
- **Art theo bề ngang** (`V2Layout.unit`, `width/402` kẹp `[0.85, 1.1]`) **chỉ dùng khi ảnh chụp cho thấy
  cần** (Phase D). Không làm trước.
- Quyết định layout dựa trên kích thước có sẵn (`MediaQuery.sizeOf` / `LayoutBuilder`), **không bao giờ**
  dựa trên loại máy hay `Platform.isIOS` (cả 3 skill Flutter đều nói vậy).

**Không dùng cờ chuyển tiếp.** Bỏ scale không làm vỡ màn nào (§1.1), nên làm luôn trên nhánh
`fix/responsive-mobile` rồi verify đủ Phase C trước khi merge. Cách này đơn giản hơn cờ `scaleToFrame` ở rev 1.

## 3. Ma trận thiết bị

Kích thước **logic** (pt trên iOS, dp trên Android), dọc. "Viewport web" là vùng Flutter thật sự nhận
được trong trình duyệt, lúc toolbar đang mở rộng. Android dp phụ thuộc cài đặt "Display size"
nên số liệu Android là giá trị mặc định điển hình (≈). Dòng đánh ★ nằm trong test matrix (§3.3).

### 3.1 iPhone

| Máy | Logic (app) | Safe top/bottom | Viewport Safari (≈) | Ghi chú |
|---|---|---|---|---|
| iPhone SE 1st gen | 320×568 | 20/0 | 320×460 | Sàn tuyệt đối, chỉ cần "không vỡ" ★ |
| iPhone SE 2/3, 8 | 375×667 | 20/0 | **375×553** ★ | Viewport web thấp nhất thực tế |
| iPhone 12/13 mini | 360×780 | 50/34 | 360×630 | |
| iPhone X/XS/11 Pro | 375×812 | 44/34 | 375×635 | |
| iPhone XR/11, XS Max/11 Pro Max | 414×896 | 48/34 | 414×715 | Còn nhiều ở VN |
| iPhone 12/13/14, 16e | 390×844 | 47/34 | 390×664 ★ | |
| iPhone 14 Pro/15/15 Pro/16 | 393×852 | 59/34 | **393×668** ★ | **Máy trong ảnh chụp** (đo từ screenshot) |
| iPhone 16 Pro / 17 / 17 Pro | 402×874 | 62/34 | 402×690 | Đúng khung thiết kế ★ |
| iPhone Air | 420×912 | 62/34 | 420×728 | |
| iPhone 12/13 Pro Max, 14 Plus | 428×926 | 47/34 | 428×746 | |
| iPhone 14 Pro Max/15 Plus/15 Pro Max/16 Plus | 430×932 | 59/34 | 430×750 ★ | |
| iPhone 16 Pro Max / 17 Pro Max | 440×956 | 62/34 | 440×772 ★ | Rộng nhất |

### 3.2 Android (thị trường VN: Samsung A, Oppo A/Reno, Xiaomi Redmi Note, vivo)

| Nhóm máy | Logic (≈ dp) | Viewport Chrome (≈) | Ghi chú |
|---|---|---|---|
| Máy rẻ HD+ (Galaxy A0x/A1x, Oppo A1x, Redmi A) | 360×800 | 360×680 ★ | Phổ biến nhất ở phân khúc thấp |
| Máy cũ 16:9 | 360×640 | 360×560 ★ | Sàn Android |
| Galaxy S21–S24, A3x/A5x | 360–384×780–832 | 384×710 | |
| Xiaomi Redmi Note 12/13, Poco | 393×873 | 393×760 | |
| Pixel 7/8/9 | 412×915 | 412×800 ★ | |
| Galaxy Z Fold (màn ngoài) | 344×882 | 344×760 ★ | **Hẹp nhất** trong nhóm máy mới |
| Galaxy Z Fold (mở) | ~673×841 | ~673×730 | Đi nhánh `maxWidth 480` |
| Galaxy Z Flip (mở) | ~412×1004 | ~412×890 | Cao nhất |

### 3.3 Test matrix (dùng trong test và ảnh chụp)

14 viewport, chọn để phủ biên + các nhóm đông người dùng nhất:

| id | size | safe top/bottom | lý do |
|---|---|---|---|
| `floor-320` | 320×568 | 20/0 | sàn tuyệt đối |
| `fold-cover` | 344×882 | 24/16 | hẹp nhất máy mới |
| `android-16x9` | 360×560 | 0/0 | Chrome, máy cũ, rất thấp |
| `android-hd` | 360×680 | 0/0 | Chrome, máy phổ thông |
| `se-safari` | 375×553 | 0/0 | Safari thấp nhất |
| `se-app` | 375×667 | 20/0 | app native / PWA |
| `iphone14-safari` | 390×664 | 0/0 | Safari |
| `iphone15-safari` | 393×668 | 0/0 | **case của ảnh chụp** |
| `iphone15-app` | 393×852 | 59/34 | native / PWA |
| `design-frame` | 402×874 | 62/34 | khung gốc, phải giống thiết kế nhất |
| `pixel` | 412×800 | 0/0 | Chrome |
| `promax-safari` | 430×750 | 0/0 | |
| `widest` | 440×956 | 62/34 | rộng nhất |
| `landscape` | 844×390 | 0/0 | xoay ngang, chỉ cần không vỡ |

Thêm **text scale 1.3×** cho `se-safari`, `iphone15-safari` và `widest`.

### 3.4 Breakpoint

| Lớp | Bề ngang | Khác biệt |
|---|---|---|
| `xs` | < 360 | lề ngang 14 thay vì 18; hero art ở mức `unit` sàn 0.85 |
| `sm` | 360–389 | |
| `md` | 390–429 | lớp của khung thiết kế (402) |
| `lg` | ≥ 430 | `unit` tới trần 1.1 |
| "thấp" | chiều cao < 700 | (Phase D) hero thu gọn nếu ảnh chụp cho thấy cần |
| "rất thấp" | chiều cao < 500 | nav chỉ còn icon (xoay ngang) |
| rộng | > 480 | cột giữa, `maxWidth 480` |

## 4. Tiêu chí hoàn thành (test phải kiểm được)

Với mỗi màn × mỗi viewport ở §3.3, **có seed dữ liệu** (quán, mate), semantics bật:

1. **Không overflow**: không có `RenderFlex overflowed` hay exception nào.
2. **Cỡ chữ hiển thị ≥ sàn D2**. Đo `fontSize × textScale × transform` của từng `RenderParagraph` đang
   hiện trên màn. Emoji, ký hiệu (`★ ‹ › ✕`) và hero number ≥ 40pt được miễn.
3. **Vùng bấm ≥ 48×48**: cả `iOSTapTargetGuideline` lẫn `androidTapTargetGuideline`.
   (Bắt buộc gọi `tester.ensureSemantics()`. Không có nó, guideline luôn pass. Đã tự kiểm lỗi này ở §1.1.)
4. **Hành động ghim ở đáy nằm trọn trong màn**: CTA các bước onboarding, 2 nút swipe, composer chat.
5. **Không có gì nằm dưới nav**: phần tử cuối của màn cuộn được phải cuộn lên trên `navClearance`.
6. **Ở `design-frame`** trông giống thiết kế gốc. Người kiểm so ảnh chụp với `plan/mobile-app-design-planning v2`.

Ngoài test: ảnh chụp Playwright (WebKit cho iPhone, Chromium cho Android) của 12 màn × 14 viewport.
Người kiểm phải **mở và xem** từng ảnh. Sau đó kiểm trên máy thật qua tunnel (T92).

## 5. Quyết định cần chốt trước Phase B

| # | Câu hỏi | Khuyến nghị | Nếu chọn khác |
|---|---|---|---|
| D1 | Bỏ hẳn scale theo chiều cao? | **Bỏ.** §1.1 cho thấy bỏ đi không làm vỡ màn nào | Giữ scale nhưng kẹp `k ≥ 0.9`: chỉ đỡ một nửa, Safari vẫn co giãn khi cuộn |
| D2 | Sàn cỡ chữ? | **Nhãn/meta ≥ 11pt** (mức Caption 2 của Apple): nav 9→11, meta 10.5→11.5, badge 9/9.5→11. Body giữ 12–13.5 như thiết kế | `ui-ux-pro-max` khuyên body ≥ 16px trên web mobile. Làm vậy là **thiết kế lại** type scale (mọi pill và card cao thêm), nên tách thành việc riêng nếu muốn |
| D3 | Xoay ngang / tablet? | **Hỗ trợ xoay ngang** (sửa onb3/onb4, nav thu gọn khi thấp) + **cột giữa 480** cho màn rộng | Khoá dọc: các skill khuyên không làm, Android lớn buộc phải hỗ trợ cả hai hướng |
| D4 | Vùng bấm 44 hay 48? | **48** (phủ cả iOS 44pt và Android 48dp; chỉ nới vùng bấm, giữ hình) | 44: đủ cho iOS, Android vẫn fail guideline |

## 6. Các phase và thứ tự phụ thuộc (rev 2)

```
Phase A — Đo & công cụ (Claude sub agent)
  T02 V2Layout ──► T03 bỏ scale + cột 480 ──► T01 matrix test (seed data) ──► danh sách lỗi thật
  T04 deep-link debug (Hermes) ──► T05 chụp ảnh: "baseline" (main) và "noscale" (nhánh sau T03)

Phase B — Sửa lỗi đã đo được (nhánh fix/responsive-mobile)
  B1 đỉnh theo safe area (Hermes, 1 file/phiên): T20 · T30 · T40 · T41 · T42 · T43 · T44–T49 · T15 · T16
  B2 sàn cỡ chữ (Hermes): T10 → rồi các dòng chữ nhỏ trong T23 · T40 · T41 · T42 · T46 · T14
  B3 vùng bấm 48 (T12 Hermes, T14 Hermes, T18 Claude cho phần còn lại theo output test)
  B4 xoay ngang + nav thu gọn (T17 Claude) · T11 main.dart (Hermes) · T13 nav (Hermes)

Phase C — Verify (Claude)
  T91 matrix xanh + xem ảnh ──► T92 máy thật qua tunnel ──► merge

Phase D — Chỉ làm nếu ảnh chụp ở Phase C cho thấy cần (art co giãn theo bề ngang)
  T21 hero home · T22 hàng card · T31 art onboarding · T60 portrait swipe / header detail
```

Phase B1 và B2 trên cùng một file thì gộp vào **một** phiên Hermes (spec đã gộp sẵn theo file, ví dụ T40 làm
cả đỉnh lẫn chữ). Thứ tự trong home: T20 → T23.

| Task | Việc | File | Người làm | Phase | Phụ thuộc |
|---|---|---|---|---|---|
| [T02](tasks/T02-v2-layout.md) | Helper `V2Layout` + unit test | `lib/theme/v2_layout.dart`, test | Claude | A | — |
| [T03](tasks/T03-remove-scaling.md) | Bỏ scale theo chiều cao, cột 480 + ghi đè `MediaQuery.size`, xoá 2 test scale | `design_frame.dart`, `v2_data.dart`, `onboarding_small_screen_test.dart` | Claude | A | T02 |
| [T01](tasks/T01-test-harness.md) | Viewport matrix + test responsive (seed data) | `test/v2/...` | Claude | A | T03 |
| [T04](tasks/T04-debug-deeplink.md) | `?v2screen=` khi build debug | `v2_state.dart` | Hermes | A | — |
| [T05](tasks/T05-screenshot-grid.md) | Script chụp 12 màn × 14 viewport | `scripts/responsive-shots.mjs` | Claude | A | T04 |
| [T10](tasks/T10-theme-floors.md) | Sàn cỡ chữ trong token | `app_theme_v2.dart` | Hermes | B2 | D2 |
| [T11](tasks/T11-main-text-scale.md) | Kẹp text scale + nhánh desktop web | `main.dart` | Hermes | B4 | — |
| [T12](tasks/T12-v2-kit.md) | `navClearance`, vùng bấm 48 cho back button / chip | `v2_kit.dart` | Hermes | B3 | T02 |
| [T13](tasks/T13-glass-nav.md) | Nhãn nav không xuống dòng, lề hẹp | `glass_nav_bar.dart` | Hermes | B4 | T02, T10 |
| [T14](tasks/T14-shell.md) | Nút ngôn ngữ 48, ẩn nav khi có bàn phím | `v2_app.dart` | Hermes | B3 | T02 |
| [T15](tasks/T15-notifications-sheet.md) | Sheet theo safe area | `notifications_sheet.dart` | Hermes | B1 | T02 |
| [T16](tasks/T16-search-overlay.md) | Lề overlay | `search_overlay.dart` | Hermes | B1 | T02 |
| [T17](tasks/T17-landscape.md) | onb3/onb4 xoay ngang + nav chỉ icon khi `height < 500` | `onboarding_screen.dart`, `glass_nav_bar.dart` | Claude | B4 | T13, T30 |
| [T18](tasks/T18-tap-targets-rest.md) | Vùng bấm còn lại (chip Filters, sao/tag Rate, link onboarding…) theo output test | nhiều file | Claude | B3 | T01, T12 |
| [T20](tasks/T20-home-top.md) | Home: đỉnh + nền wash | `home_screen.dart` | Hermes | B1 | T02 |
| [T23](tasks/T23-home-small-text.md) | Home: chữ nhỏ + stat card + "Xem tất cả" | `home_screen.dart` | Hermes | B2 | T20 |
| [T30](tasks/T30-onboarding-top.md) | Onboarding: đỉnh/đáy 5 bước | `onboarding_screen.dart` | Hermes | B1 | T02 |
| [T40](tasks/T40-swipe.md) | Swipe: đỉnh + chữ | `swipe_screen.dart` | Hermes | B1+B2 | T02 |
| [T41](tasks/T41-detail.md) | Detail: nút back, bỏ trick ±96, chữ | `detail_screen.dart` | Hermes | B1+B2 | T02 |
| [T42](tasks/T42-me.md) | Me: header theo safe area, sticker, chữ | `me_screen.dart` | Hermes | B1+B2 | T02 |
| [T43](tasks/T43-chat.md) | Chat: đỉnh + composer khi có bàn phím | `chat_screen.dart` | Hermes | B1 | T02, T14 |
| [T44–T49](tasks/T44-49-simple-screens.md) | Filters, Rate, Bill, Pay, Trust, Local | 6 file, **mỗi file 1 phiên** | Hermes | B1 | T02 |
| [T91](tasks/T91-full-verify.md) | Verify đầy đủ + xem ảnh | — | Claude (`qa`) | C | Phase B |
| [T92](tasks/T92-real-device.md) | iPhone Safari + Android Chrome + PWA thật | — | Claude + user | C | T91 |
| [T21](tasks/T21-home-hero.md) | Home: hero co giãn | `home_screen.dart` | Hermes | D | ảnh chụp |
| [T22](tasks/T22-home-rows.md) | Home: 2 hàng card ngang | `home_screen.dart` | Hermes | D | ảnh chụp |
| [T31](tasks/T31-onboarding-hero.md) | Onboarding: art hero | `onboarding_screen.dart` | Hermes | D | ảnh chụp |
| [T60](tasks/T60-art-if-needed.md) | Portrait swipe, header/art detail | 2 file | Hermes | D | ảnh chụp |

## 7. Cách giao việc

### 7.1 Claude sub agent

Dùng agent `coder` / `qa` của repo ([.claude/agents/](../../../.claude/agents/)), hoặc `general-purpose`.
Prompt = đường dẫn file spec + câu "làm đúng spec, chạy các lệnh verify ở cuối spec, dán output thật".
Hai sub agent Claude có thể chạy song song với `isolation: "worktree"`, miễn là không cùng sửa một file.

### 7.2 Hermes (local, `qwen3.8-27b`)

Các quy tắc lấy từ những lần đã đo với local model trên máy này (`~/.claude/CLAUDE.md`):

- **Một file, một phiên.** Spec chỉ rõ class/hàm, đoạn code cần tìm và code thay vào.
- **Prompt một dòng, trỏ tới file spec.** Không dán spec nhiều dòng vào argv.
- **Luôn truyền `--in`.** Không có nó, Hermes chạy ở `C:\Users\Admin`: log trong `_hermes_pw_test`
  cho thấy nó từng ghi file ra đó.
- **Chạy tuần tự**, vì chỉ có một GPU. Chạy song song chỉ làm cả hai chậm đi.

```powershell
$F = 'C:\AnM\AnMatesStudio\AnMates\anmates_flutter'
$T = 'C:\AnM\AnMatesStudio\AnMates\docs\plans\2026-09-25-responsive-mobile\tasks'
hermes --in $F --usage-file "$env:TEMP\hermes-T20.json" -z "Read the task spec $T\T20-home-top.md and apply it exactly. Edit only the one file it names. When done, run the self-check command in the spec and paste its real output."
```

**Người gọi (Claude hoặc bạn) tự verify.** Báo cáo của Hermes là tín hiệu kém tin cậy nhất: local
model từng báo xong trong khi chưa sửa gì. Sau mỗi phiên, chạy:

```powershell
git -C $F diff --stat                      # đúng 1 file, đúng file trong spec
C:\src\flutter\bin\flutter.bat analyze <file>
C:\src\flutter\bin\flutter.bat test test/v2 --plain-name "<screen> @"
```

Nếu sai file hoặc analyze lỗi, `git checkout -- <file>` rồi chạy lại một lần. Sai lần hai thì
giao task đó cho Claude sub agent.

> Lưu ý hiệu năng: Hermes đang trỏ `custom:llama-mtp` (`127.0.0.1:8080`). Theo số đo ngày 2026-09-06,
> MTP **chậm hơn 29 %** trên GPU này so với Ollama thường. Nên cân nhắc trỏ về Ollama `11434` cho đợt này.

## 8. Rủi ro

| Rủi ro | Giảm thiểu |
|---|---|
| Hermes sửa lan sang file khác | `git diff --stat` sau mỗi phiên, revert ngay |
| Bỏ scale làm vỡ màn khi có dữ liệu thật (§1.1 đo với dữ liệu rỗng) | T01 seed dữ liệu; làm trên nhánh, merge sau Phase C |
| `google_fonts` tải font qua mạng trong test → cỡ chữ đo lệch | Chỉ đo `fontSize` khai báo × scale, không đo pixel glyph |
| Flutter web không đọc `env(safe-area-inset-*)` → PWA standalone bị đè status bar | Kiểm ở T92, sửa trong `web/index.html` nếu cần |
| Thiết kế ở `design-frame` bị lệch sau khi đổi | T91 so ảnh `design-frame` với thiết kế gốc |

## 9. Skill đã cài (rev 2)

Cài ở cấp project (`AnMates/.claude/skills/`, lock ở `AnMates/skills-lock.json`). Nội dung đã đọc hết trước khi cài,
và bản cài được so khớp byte với bản đã đọc. Không skill nào gọi mạng. `ui-ux-pro-max` có script Python,
nhưng chỉ tìm kiếm trong file CSV có sẵn.

| Skill | Nguồn | Dùng cho |
|---|---|---|
| `flutter-build-responsive-layout` | `flutter/agent-plugins` (team Flutter chính thức) | quy tắc `MediaQuery.sizeOf`/`LayoutBuilder`, không khoá hướng, ràng buộc maxWidth |
| `flutter-fix-layout-issues` | `flutter/agent-plugins` | quy trình sửa overflow / unbounded (Phase B, T17, T18) |
| `flutter-add-widget-test` | `flutter/agent-plugins` | T01 |
| `flutter-adaptive-ui` | `madteacher/mad-agents-skills` | breakpoint, xoay ngang, giữ state khi resize, tài liệu constraints |
| `ui-ux-pro-max` | `nextlevelbuilder/ui-ux-pro-max-skill` | checklist mobile: vùng bấm 44/48, safe area, Dynamic Type, cỡ chữ |

Claude sub agent chạy trong repo sẽ tự thấy các skill này. **Hermes thì không**: nó có thư mục skill riêng,
và nhét thêm skill vào ngữ cảnh 27B local chỉ làm chậm. Các quy tắc cần thiết đã được viết thẳng vào từng spec.

Những thay đổi so với rev 1 nhờ skill + số đo: vùng bấm 44 → **48**; bắt buộc `ensureSemantics` trong test;
ghi đè `MediaQuery.size` trong cột 480; hỗ trợ xoay ngang thật (T17); bỏ cờ chuyển tiếp; art-scaling xuống Phase D.
