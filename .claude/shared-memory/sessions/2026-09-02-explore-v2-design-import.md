# 2026-09-02 — Import design mới từ Claude Design → màn Explore v2 (Flutter)

**Status:** code done, static-verified, **đang chạy local ở `http://127.0.0.1:8099`**. PENDING user live-confirm.

## TL;DR

Import project Claude Design `fa249917-433c-4553-b1ae-8909eed150ed` ("Mobile app design planning")
qua tool built-in `DesignSync`, port **frame B1 "Explore · hero 3D collage"** (+ B1.2 Thông báo,
B1.3 Tìm kiếm) sang Flutter thành **màn mới hoàn toàn**, không sửa/override bất kỳ file cũ nào.

## Đường đi tới design (3 lần fail trước khi được)

- MCP `claude_design` / tool `DesignSync` cần design-system authorization; session non-interactive
  không chạy được `/design-login`.
- Đã thử thêm MCP connector `claude-design` → `https://api.anthropic.com/v1/design/mcp`
  (`claude mcp add --transport http --scope user`). Connector này **vẫn 403**
  (`FIRST_PARTY_AUTH_REJECTED` — "/login token carries no Claude Design access").
- **Cái chạy được là tool built-in `DesignSync`**, sau khi user chạy `/design-login` trong
  session Claude Code tương tác (báo `Design-system access authorized.`).
- ⚠️ Gotcha: MCP server chỉ load lúc khởi động session → connector thêm giữa chừng không thấy được.
- ⚠️ Gotcha: `DesignSync.get_file` **cắt ở 256 KiB** (`truncated: true`). PNG asset kéo về đều hỏng.

## Cấu trúc design (để lần sau khỏi dò lại)

- `Canvas.dc.html` **chỉ là bảng index** — pin frame qua `<dc-import name="AnMates" pin-screen="…">`.
  UI thật nằm ở **`AnMates.dc.html`** (1674 dòng: template dòng 9–988, script dòng 989–1672).
- `support.js` = dc-runtime generated (React renderer), **không phải design content** — bỏ qua.
- 12 screen: `onb`(5 step), `home`, `filters`, `detail`, `swipe`, `chat`, `bill`, `rate`, `me`,
  `trust`, `pay`, `local`. Canvas ghi rõ: *"Đã chốt Home C làm Explore duy nhất"* → chọn `home`.
- Bản copy đã lưu ở `plan/design/AnMates.dc.html` (không build vào app).

## Design tokens mới (KHÁC hệ cũ — không merge)

| | Cũ (`design-system.md`, `app_theme.dart`) | Mới (v2) |
|---|---|---|
| Accent | Berry `#B8336A` | **Wisteria `#8B5CF6`** |
| Secondary | Ocean `#534BA8` | Blue `#3B82F0` → `#1F5BE0` |
| Nền | Mint `#F1FFF8` | Aurora 4 lobe + grain, canvas `#F6F4FF` |
| Font | Plus Jakarta + Be Vietnam Pro | **Be Vietnam Pro** toàn bộ |

`design-system.md` vẫn nói palette cũ là FINAL → **chưa đụng tới**, đúng yêu cầu user
"ko sửa và override lại cái cũ". Khi nào chốt v2 làm chuẩn thì mới update file đó.

## Files thêm mới (9 file, ~2.2k dòng — không sửa file cũ nào)

- `lib/theme/app_theme_v2.dart` — `AppColorsV2` / `AppGradientsV2` / `AppShadowsV2` / `AppTextV2`
- `lib/views/explore_v2/explore_v2_data.dart` — seed data + `T(vi, en)` song ngữ + `FoodAssets`
- `lib/views/explore_v2/explore_v2_view.dart` — màn Explore
- `lib/widgets/v2/aurora_background.dart` — 4 radial lobe (ellipse qua matrix squash) + grain
- `lib/widgets/v2/food_art.dart` — `FoodArt` + `FloatingArt` (`@keyframes amFloat`)
- `lib/widgets/v2/glass_nav_bar.dart` — nav kính, 4 glyph vẽ tay bằng Canvas
- `lib/widgets/v2/notifications_sheet.dart` — sheet Liquid Glass (B1.2)
- `lib/widgets/v2/search_overlay.dart` — overlay blur + TextField thật (B1.3)
- `lib/main_v2.dart` — entry riêng: `flutter run -t lib/main_v2.dart`
- `test/v2/explore_v2_render_test.dart` — render check ở 402×874

`main.dart`, `app_theme.dart`, `pubspec.yaml` **không đổi** (asset dùng lại `assets/food/`,
`assets/avatars/` đã đăng ký sẵn).

## Verification (đã chạy)

- `flutter analyze` → **0 issue** trên file v2; 9 issue còn lại đều là file cũ (pre-existing).
- `flutter test` → **24/24 pass** (trước là 23, +1 test mới).
- `flutter build web -t lib/main_v2.dart` → **build release OK** (26.4s).
- Render golden ở 402×874 đã soi mắt: aurora, wash, pill, hero 4 món, CTA gradient,
  stat card, nav kính 4 icon — đúng bố cục design.
- **Chưa test trên device/browser thật với font + ảnh thật.**

## Update cùng ngày — đã fix 2 điểm + chạy local

**1. Asset 3D: lấy được 4/6 + grain.** Ngưỡng 256 KiB là cắt **per-file**, không phải chặn hết:
`ramen`(223KB) `coffee`(153KB) `burger`(222KB) `beer`(190KB) `grain`(144KB) đều về **nguyên vẹn**
(verify header PNG + chunk IEND + `sips` đọc được, đều `hasAlpha: yes`). Chỉ `hotpot` + `bbq`
vượt ngưỡng → vẫn hỏng. Đã lưu `assets/food/v2_*.png` (thư mục đã đăng ký sẵn → **pubspec không đổi**).
- Hero collage giờ dùng **đúng 4 món design yêu cầu** (burger/ramen/beer/coffee) — full cutout.
- `kFoodArtIsCutout` (cờ global) → thay bằng **`FoodArtRef(path, cutout:)` per-asset**; hotpot/bbq
  fallback `lau.png`/`nuong.png` với `cutout: false` nên bị clip bo góc, 4 món kia thả bóng.
- Grain giả bằng `CustomPainter` **đã bỏ**, dùng ảnh thật tile 120×120 qua `ExactAssetImage(scale:)`.
- 🐛 **Bug phát hiện khi soi golden:** `BoxShadow` đổ bóng theo **hình chữ nhật của widget**, không
  theo alpha → mỗi PNG trong suốt bị slab xám phía sau. CSS `drop-shadow()` thì bám silhouette.
  Fix: `_DropShadowImage` trong `food_art.dart` — vẽ bản sao ảnh tô `ColorFilter.mode(srcATop)` +
  `ImageFiltered(blur)` rồi đặt ảnh thật đè lên. Soi lại golden: bóng đã đúng.

**2. Palette conflict: đã ghi vào `design-system.md` (additive, không override).**
Thêm banner cảnh báo ngay dưới H1 + section mới "Hệ v2 — Explore direction" ở cuối file:
token v2, bảng typography, nền aurora, và 3 gotcha khi code. **Không sửa/xoá dòng nào của hệ v1** —
hệ v1 vẫn nguyên vẹn là chuẩn của toàn app. Điểm dễ nhầm nhất đã ghi rõ: **Wisteria v1 = `#C490D1`
(nhạt, chỉ fill vibe meter), Wisteria v2 = `#8B5CF6` (token nhấn chính)** — cùng tên, khác giá trị.

**3. Đang chạy local** để user xem: build release web → serve `http://127.0.0.1:8099`
(`python3 -m http.server 8099`, docroot ở scratchpad, **không đụng `build/web`** của repo).

**Verify sau khi fix:** analyze 0 lỗi trên file v2 (9 issue còn lại pre-existing),
test 24/24, `flutter build web -t lib/main_v2.dart` OK (40.6s), 3 asset v2 trả HTTP 200 qua server.

## Update 2 — fix responsive + phone frame trên desktop

**🐛 Root cause responsive: `web/index.html` THIẾU HẲN `<meta name="viewport">`.**
Không có tag này, browser (và DevTools device emulation) dùng layout viewport mặc định **980px**
rồi scale trang xuống → Flutter view không bao giờ lấp đầy chiều cao thật, để lại khoảng trắng
dưới đáy. Tag này vốn có sẵn trong template Flutter chuẩn, ở repo này đã bị bỏ đi lúc nào đó.

⚠️ **Đây là file dùng chung với v1** — đã thêm 1 dòng meta (additive, không xoá gì).
**Bug này ảnh hưởng cả v1 trên mobile thật**, nên fix là đúng cho cả hai; nhưng nghĩa là
rendering của v1 trên mobile CŨNG đổi (từ zoom-out sai → đúng). Nếu user muốn v1 y nguyên
như cũ thì revert dòng 25 của `web/index.html`.

**Phone frame trên desktop** (user báo "truy cập bằng laptop nó ko crop thành mobile giống v1"):
thêm `_webFrameBuilder` vào `lib/main_v2.dart` — copy cách làm của `main.dart` v1 nhưng dùng
artboard riêng của design **402 × 874** (v1 dùng 430) và glow Wisteria thay Berry.
Dưới 600px (điện thoại thật) render edge-to-edge, không đụng vào.
🐛 Sửa luôn một lỗi của bản v1 khi port: v1 hardcode `size: Size(frameW, 900)` trong `MediaQuery`
bất kể `frameH` đã clamp 600–900 → app tưởng mình cao 900 trong khi hộp có thể chỉ 600.
Bản v2 truyền đúng `frameH`.

**Verify:** render lại ở 390×844 — **0 overflow**, lấp đầy đủ 844px. analyze 0 lỗi trên file v2,
test 24/24, build web OK, server trả đúng meta viewport.

## Update 3 — implement 100% (19/19 frame) + bundle design đầy đủ

User đã export **Project HTML .zip** → `plan/mobile-app-design-planning v2/project/`. Đủ 9 asset
(hotpot 728×596 + bbq 734×668 — 2 file trước bị `get_file` cắt — cùng foursome.png mới), `ios-frame.jsx`,
`support.js`. Design HTML **khớp 100%** bản pull cuối (diff rỗng).

**Restructure**: bỏ `lib/views/explore_v2/` (1 màn) → `lib/views/v2/` đa màn hình.
- `v2_data.dart` — toàn bộ bảng seed của design (places, mates, venues, budgets, tastes, orbits,
  bill, trust log, locals, tiers, visited, reviews, notifs) + helper song ngữ `T(vi, en)`
- `v2_state.dart` — `ChangeNotifier` port 1:1 `Component.state` + `renderVals()`: ngưỡng Vibe
  (express 45 / chuẩn 70), gating Trust < 85, bảng sao→điểm, split theo món/chia đều
- `v2_app.dart` — shell: aurora + toggle VI/EN + `AnimatedSwitcher` + glass nav + 2 overlay
- `v2_kit.dart` — chip / CTA / back / sheet / eyebrow dùng chung
- `screens/` — 12 file, phủ **19/19 canvas frame**
- Asset thật vào `assets/v2/` (2.8 MB), pubspec thêm **1 dòng** `- assets/v2/`

**Verify**: render golden **cả 17 frame** ở 402×874, soi từng ảnh. analyze 0 lỗi trên file v2,
test 24/24, build web OK.

**3 bug thật bắt được nhờ render (không phải lỗi cosmetic):**
1. `Container(margin: EdgeInsets.only(left: -44))` ở `_VisitedDeck` → **crash**
   (`margin.isNonNegative` assertion). Flutter cấm margin âm. Fix: `Stack` + `Positioned`
   step 74px thay vì margin âm.
2. `ListView(padding: EdgeInsets.only(left: 24 + shift))` với shift −46/−62 → **crash**
   (`padding.isNonNegative`). Fix: `Transform.translate` cho cả row, cho chip chạy tràn mép trái
   đúng như `margin-left` âm của design.
3. Row tiêu đề `AI Smart Split` overflow 24px → `Expanded` + ellipsis.

**1 sai lệch design bắt được:** màn onboarding A1–A4 dùng **gradient blob riêng**
(`96% 58% at 50% 88%` xanh đậm dưới, cyan trái, tím phải-trên) khác hẳn gradient shell.
Ban đầu tôi tái dùng shell → blob nhạt toẹt. Đã tách `AuroraBlob` với đúng 4 lobe của design.

## Update 4 — 2 bug user báo khi dùng thật

**Bug A · lưới gu món (onboarding A4), hàng 2 và 4.** Đo lại geometry: chip đầu hàng 2 ở
`x=-22`, hàng 4 ở `x=-38` — **khớp đúng design** (`margin-left:-46px/-62px`). Nhưng design cố ý
kéo chip tràn khỏi mép trái → chip đầu bị cắt đôi, không đọc và không bấm được.
**Quyết định: lệch design có chủ đích** — đổi `kTasteRowShifts` từ `[0,-46,0,-62]` sang
`[0,46,0,62]` (đẩy phải thay vì kéo trái). Vẫn so le đúng ý đồ "never lines up into columns",
nhưng không chip nào bị cắt. Đo lại: `24 / 70 / 24 / 86`, tất cả ≥ 0.

**Bug B · màn Quẹt không kéo lên xuống được, nút bị nav che.**
Root cause: `navClearance` bị tính thiếu — `GlassNavBar` bọc `SafeArea`, mà khung desktop set
`padding.bottom = 34`, nên nav cao hơn 34px so với padding-bottom 84 mà màn hình chừa.
Fix: thêm helper `navClearance(context) = 96 + MediaQuery.paddingOf(context).bottom` vào `v2_kit`,
áp cho **swipe, chat, bill, rate, local, trust, filters**. (Home + Me cố ý cuộn *dưới* kính — đó là
mục đích của blur — nên giữ nguyên.)
🐛 Lần fix đầu tôi bọc `Column` có `Spacer()` trong `SingleChildScrollView` → crash
`RenderFlex children have non-zero flex but incoming height constraints are unbounded`.
Fix đúng: **pin hàng nút ra ngoài vùng cuộn** (`Column` → `Expanded(scroll card)` + action row),
card cuộn trong phần còn lại, nút luôn nằm trên nav.

**Verify** (test viết riêng, mount shell với đúng inset khung desktop top 44 / bottom 34):
CTA bottom `724.5` < nav top `791.0` ✓ · kéo dọc không throw ✓ · 4/4 chip đầu hàng ≥ 0 ✓ ·
analyze 0 lỗi trên file v2 · test 24/24 · build web OK.

## Nợ kỹ thuật còn lại

1. Icon chuông / search / lock / receipt / send dùng Material icon thay SVG path của design
   (4 glyph nav + bubble thì đã vẽ tay bằng Canvas cho khớp).
2. `foursome.png` có trong bundle nhưng design hiện không dùng ở frame nào — chưa wire.
3. Bàn phím iOS giả của B1.3 thay bằng `TextField` + bàn phím hệ thống thật.
4. **UI v1 chưa xoá** — chờ user review v2 xong mới xoá theo yêu cầu.

## NEXT

User chạy `flutter run -t lib/main_v2.dart -d chrome` (hoặc device) → xem thật → confirm →
migrate session này thành `R-NNN`.
