# 2026-09-25 — Plan responsive mobile cho Flutter UI v2 (chỉ plan, chưa code)

## TL;DR
User báo UI Flutter trên `app.anmates.site` (iPhone Safari) "không responsive". Đo được nguyên nhân gốc,
viết plan + 31 task nhỏ (26 file spec) để giao cho Claude sub agent và Hermes local:
`docs/plans/2026-09-25-responsive-mobile/` (README + `tasks/`). Chưa sửa dòng code nào trong `lib/`.

## Root cause (đã đo)
`DesignFrame` (commit 3a93fc1) scale CẢ app theo `k = height / 874`. Trên web mobile, toolbar trình duyệt
ăn chiều cao → k ≈ 0.63–0.85 → chữ/nút nhỏ đi 16–37 % (nav label 9pt → 6.8pt ở iPhone 15 Safari 393×659),
layout tưởng rộng 508–598pt. Thêm: padding đỉnh cố định 96/100/104 giả định notch ~60pt, nhưng Safari web
`padding.top = 0` → dải trống ~60pt. Số đo bằng widget test probe tạm (đã xoá), bảng ở README §1.

## Hướng xử lý
Bỏ scale theo chiều cao; chữ pt cố định (sàn 11pt), art scale theo bề ngang `V2Layout.unit` [0.85, 1.1],
dọc thì cuộn, `contentTop = safeTop + 52`. Chuyển đổi qua cờ `scaleToFrame` (mặc định true) → lật ở T90.

## Môi trường (key facts)
- Flutter SDK ở `C:\src\flutter\bin\flutter.bat` (không có trên PATH của bash).
- `.dart_tool/package_config.json` được sinh trong Docker (đường dẫn `/root/.pub-cache`, `/sdks/flutter`) →
  `flutter test` trên Windows lỗi compile. Đã chạy `flutter pub get` trên máy: `pubspec.lock` không đổi,
  nhưng `macos/Flutter/GeneratedPluginRegistrant.swift` được sinh lại (trước đó có sửa đổi local, giờ khớp HEAD).
- Baseline `flutter test test/v2`: 7/7 pass.
- Hermes: `%LOCALAPPDATA%\hermes\bin\hermes`, model `qwen3.8-27b` qua `custom:llama-mtp` 127.0.0.1:8080.
  Phải truyền `--in <dir>`, nếu không nó chạy ở `C:\Users\Admin`.
- Mọi anchor "Find" trong spec T04–T43 đã được kiểm máy (script) là khớp code hiện tại.

## Verification
Chỉ là plan. Chưa có gì để verify trên UI.

## Open follow-ups
- User chốt D1/D2/D3 (README §5), rồi chạy Phase 0 (T02 → T03 → T01, T04 → T05).

---

## Thực thi (cùng ngày, rev 2) — đã code, push `main`

- Cài 5 skill (flutter-build-responsive-layout, flutter-fix-layout-issues, flutter-add-widget-test,
  flutter-adaptive-ui, ui-ux-pro-max) vào `.claude/skills/`, đọc hết trước khi cài.
- Đo lại khi tắt scale: 0 overflow ở mọi viewport dọc → bỏ hẳn `DesignFrame` scale (README §1.1).
- Hermes (qwen3.8-27b local) làm 23 task 1-file (T02 lib, T04, T10–T16, T20, T23, T30, T40–T50):
  23/23 PASS theo bộ chấm độc lập (`scratchpad/hermes_runner.py`: replacement có trong file, find block
  biến mất, analyze sạch, không sửa file lạ), ~40–60s/task (T12 520s). 1 lỗi do spec: import thừa ở detail.
- Claude sub agent: T03 (bỏ scale), T01 (matrix test 1110 test), T05 (script chụp ảnh). Sub agent thứ 2
  (T17/T18) chết vì hết quota → main assistant tự làm: tràn text-scale 1.3 ở home, onb3/onb4 xoay ngang
  (header vào vùng cuộn), vùng bấm 48 (`V2TapTarget` mới trong v2_kit), composer chat không nằm dưới nav.
- Sửa bộ kiểm tap-target: bỏ qua node bị mép scroll view cắt (so rect toàn cục với mép viewport; semantics
  lấy từ `renderViews.first.owner`, root pipeline owner không có semantics). Chứng minh vẫn fail khi làm
  hỏng thật (link onboarding 325×19).
- Kết quả: `flutter analyze --no-fatal-infos` 0 error/warning (2 info có sẵn ở booking_service), `flutter test`
  1110/1110. Ảnh local (`screenshots/responsive/phaseB`) đã xem.
- Còn nợ: Phase D (art co giãn) chưa cần; T92 máy thật; Firebase `identitytoolkit` trả 403 "api key suspended"
  (sub agent thấy trong network log, không liên quan đợt này).

## Verify trên prod (https://app.anmates.site, commit 8a55075)

CI xanh → CD `helm upgrade` + smoke xanh (53s). Playwright (WebKit cho iPhone, Chromium cho Android/ngang), đi
onboarding → Home → các tab, đo bằng semantics tree của Flutter:

| Phần tử | iPhone 15 Safari trước → sau | SE Safari trước → sau |
|---|---|---|
| VI/EN | 24×19 → 48×48 | 20×16 → 48×48 |
| CTA "Gom kèo tối nay" | cao 43 → 56 | 35 → 56 |
| Ô tìm kiếm | cao 37 → 48 | 30 → 48 |
| Link "Đăng nhập" | cao 15 → 48 | 12 → 48 |

**Bẫy cache CDN (có từ trước) — ĐÃ SỬA (dd3550e, baf235c):** `main.dart.js` / `flutter_bootstrap.js` được phục vụ
`Cache-Control: public, max-age=7200` và Cloudflare cache chúng (cf-cache-status HIT), trong khi `index.html`
là no-store. Sau deploy, lần đo đầu tiên trả **y hệt bản cũ** (Age 7153s) — người dùng có thể chạy code cũ tới
2 tiếng sau mỗi deploy. Hướng sửa: nginx `no-cache` cho 2 file đó (hoặc tên file có hash), hoặc purge CF trong CD.

Chưa làm: nav chỉ-icon khi màn rất thấp (T17 phần 2; ngang 844×390 nav vẫn cao ~72pt); T92 máy thật; Phase D.

### Sửa cache (dd3550e → baf235c)

nginx: `location ~ ^/(main.dart.js|flutter_bootstrap.js|flutter.js|flutter_service_worker.js|version.json|manifest.json)$`
→ `Cache-Control: private, no-cache` (ảnh/font/canvaskit giữ 2h). Lần 1 dùng `no-cache` trơn: edge revalidate đúng
(REVALIDATED) nhưng **Cloudflare ghi đè header gửi browser thành `max-age=1800`** (Browser Cache TTL của zone) →
thêm `private`. Đo prod: flutter.js `private, no-cache` + BYPASS, revalidate 304/0B. Test local bằng image
Dockerfile.prebuilt (lưu ý: checkout Windows làm `10-upstream-env.envsh` thành CRLF → container chết exit 127;
chỉ là môi trường local, CI build Linux LF).

Chuyển tiếp 1 lần: main.dart.js/flutter_bootstrap.js/service worker lưu ở edge lúc 09:11 GMT dưới header cũ sẽ còn
tới ~11:11 GMT; muốn nhanh hơn phải Purge trong Cloudflare dashboard (repo không có API token).
