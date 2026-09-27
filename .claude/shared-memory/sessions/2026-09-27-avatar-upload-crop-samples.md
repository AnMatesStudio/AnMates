# 2026-09-27 — Ảnh đại diện: tải lên + crop/zoom, hoặc chọn ảnh có sẵn

## TL;DR
Trước: mọi tài khoản dùng chung một ảnh chibi (`A.avatar`), không đổi được. Giờ: Me → bấm avatar (có
badge máy ảnh) → màn **"Ảnh đại diện"** (`V2Screen.avatar`):
- **Tải ảnh lên** (image_picker, giới hạn 2048 px) → bước crop: khung vuông, vòng tròn đánh dấu phần hiển
  thị, kéo để căn, chụm 2 ngón / cuộn chuột / slider / nút −+ để zoom 1×–4× → "Dùng ảnh này" → vẽ 512×512
  PNG → `PUT /api/v1/profile/avatar`.
- **Hoặc chọn ảnh có sẵn**: 11 ảnh (chibi + 10 chân dung `assets/v2/avatars/sample-N.png`) → "Lưu ảnh đại diện"
  → `PUT /profile {avatar_url: "asset:<path>"}`.
- Ảnh mới hiện ở Me, header Khám phá, và **phía đối phương** (thẻ Quẹt, chat, inbox, match sheet — qua
  `MateAvatar`, giờ hiểu `asset:` và đường dẫn tương đối).

## Quyết định: lưu ảnh trong Postgres, KHÔNG dùng Firebase Storage
- Bucket `anmates-studio.firebasestorage.app` trả **412 "A required service account is missing necessary
  permissions"** (kiểm bằng curl 2026-09-27) → mọi upload qua Firebase Storage đang hỏng trên prod.
  ⚠️ **Ảnh chat (`V2State.sendImage` → `StorageService.uploadPhoto`) cũng dùng đường này → nhiều khả năng
  gửi ảnh chat đang hỏng trên prod.** Chưa sửa (ngoài phạm vi) — có thể chuyển sang cùng kiểu lưu DB.
- Theo mẫu `venue_photos` (014): migration **021 `user_avatars`** (1 dòng/user, base64 JPEG, sha256,
  FK users ON DELETE CASCADE). Server **decode + re-encode JPEG q88 trên nền trắng** (bỏ EXIF/GPS, PNG trong
  suốt không thành đen), chỉ nhận JPEG/PNG, mỗi cạnh 64–1024 px, ≤ 2 MiB.
- `users.avatar_url` = `/api/v1/users/<id>/avatar?v=<sha256[:12]>` (tương đối; client ghép `apiBaseUrl`
  qua `ApiClient.mediaUrl`). `GET /users/:id/avatar` public (như ảnh quán: `<img>` không mang token, id là
  UUID). Đúng `?v=` → `immutable` 1 năm; không có/sai `?v=` → `no-cache`; ETag = sha256 → 304.
- `PUT /profile avatar_url` giờ **chỉ nhận**: `""` (về mặc định → NULL), `asset:assets/v2/avatar-chibi.png`,
  `asset:assets/v2/avatars/sample-(1..10).png`, hoặc đường dẫn ảnh của chính mình. **URL ngoài bị 400**
  (trước đây nhận mọi chuỗi → có thể trỏ avatar về host lạ để lấy IP người xem). Client v2 chỉ gửi name/bio
  qua PUT /profile nên không vỡ gì.

## Files changed
- API: `db/migrations/021_user_avatars.sql`, `services/avatar.go` (+test), `handlers/avatar.go` (+test),
  `handlers/user.go` (validate avatar_url), `services/user.go` ("" → NULL), `main.go` (routes),
  `e2e/e2e_avatar_test.go` (E2E-27).
- Flutter: `lib/widgets/v2/avatar_cropper.dart` (`CropFrame`, `AvatarCropController`, `AvatarCropper`,
  `renderCrop`, `decodeForCrop`), `lib/views/v2/screens/avatar_screen.dart`, `v2_state.dart`
  (`myAvatarUrl`, `chooseAvatarSample`, `uploadAvatarCrop`, `pickAvatarPhoto`, `avatarPickerForTest`),
  `v2_kit.dart` (`avatarSourceOf`, `AvatarImage`, `MateAvatar` hiểu `asset:`/tương đối), `v2_data.dart`
  (`kAvatarSamples`), `services/profile_service.dart`, `services/api_client.dart` (`mediaUrl`),
  `screens/me_screen.dart`, `screens/home_screen.dart`, `v2_app.dart`, `widgets/v2/filter_parts.dart`
  (reset tuỳ chọn).
- Test: `test/v2/avatar_crop_test.dart` (8), `test/v2/avatar_test.dart` (11), matrix pinned CTA.
- E2E UI: `tool/e2e/ui_avatar.js` (UI-25) — chờ `flt-semantics-placeholder` thay vì sleep cố định (boot
  chậm khi Firebase SDK tải từ gstatic → lần chạy đầu bị lỡ semantics).

## Verification
- Go unit (services/handlers) xanh; **Go e2e 21/21** trên stack docker local (DEV_MODE, override tạm
  ở scratchpad), gồm E2E-27.
- Flutter: 19 test mới (RED → GREEN), 3 mutation đều bị bắt; full **1489/1489**; analyze chỉ 2 info cũ.
- UI thật local (build web → API docker :8080, Chrome headless, ảnh thật 576×1024): **9/9 PASS** ×4 lần —
  chọn ảnh 4 → `asset:…/sample-3.png`; upload + zoom + kéo → JPEG 512×512 ở `/users/<id>/avatar?v=…`, toast,
  ảnh ở Me + header Khám phá; tài khoản B thấy ảnh A trên thẻ Quẹt. Không page error.

## Deploy prod (cùng ngày)
- `754eccb` → CI `36309144278` xanh (Flutter Web + Go API) → CD `36309307181` xanh (09:26:04Z).
- `main.dart.js` 09:24:45Z (BYPASS) có `avatar-cropper`; `GET /users/<uuid lạ>/avatar` → 404 (bảng 021 đã có,
  không 500); `PUT /profile/avatar` không token → 401.
- UI thật trên app.anmates.site với tài khoản thử đăng ký qua API (không gửi email): Me → avatar → 11 ảnh →
  ảnh 6 → Lưu → `asset:…/sample-5.png` ✓; Tải ảnh lên → crop, phóng to, kéo → Dùng ảnh này →
  `/api/v1/users/<id>/avatar?v=16f5e774f5e1` ✓, toast, ảnh hiện ở Me ✓. Không page error.
- ⚠️ Các lệnh API sau đó của script (tải JPEG, thử URL ngoài, **DELETE /profile dọn dẹp**) bị **429** do rate
  limiter per-IP (0.5 rps, burst 5; có vẻ per-pod — 8 GET liên tiếp: lúc qua hết, lúc 1 cái 429).
  → **Tài khoản thử còn trên prod**: id `7bcc9f7c-0b9f-4b91-9b91-1891a3c48bc6`, tên "QA Avatar",
  email `qa-avatar-<ts>@example.com` (chưa xác minh → không hiện trong deck ai). Script không lưu email/token
  nên không tự xoá được; cần user duyệt xoá qua DB (kubectl + psql) hoặc tự xoá.
  Bài học: lưu credential dọn dẹp TRƯỚC khi chạy, và chờ/thử lại khi 429.

## Open follow-ups
- Xoá tài khoản thử "QA Avatar" trên prod (xem trên).
- Rate limiter chặn cả luồng UI bình thường khi nhiều request dồn (Me gọi 5+ API cùng lúc; deck 10 avatar).
- Ảnh chat qua Firebase Storage (412) — xem trên.
- Ảnh đã tải lên vẫn giữ trong `user_avatars` khi chuyển sang ảnh có sẵn; UI chưa có ô "ảnh đã tải" để quay lại.
- Rate limiter per-IP 0.5 rps/burst 5 phủ cả `/api/v1` (kể cả ảnh) — prod chưa thấy 429, nên kiểm cấu hình.
