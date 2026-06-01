---
id: R-004
title: Screen 11 "Hoàn tất" crash + validation mismatch + culture_tags missing — full onboarding submit fix
tags: [flutter, firebase, web-dev, onboarding, storage, culture-tags, validation, loading-overlay]
platforms: [web]
severity: blocker
status: confirmed
date_resolved: 2026-06-01
confirmed_by: user
related_sessions: [sessions/2026-06-01-screen11-submit-null-check-cors.md]
related_blockers: []
---

# R-004: Screen 11 "Hoàn tất" crash + validation mismatch + culture_tags missing — full onboarding submit fix

## TL;DR

Bấm "Hoàn tất" ở Screen 11 luôn crash với snackbar **"Gửi hồ sơ thất bại: Null check operator
used on a null value"** — không có request nào tới Firebase Storage. Root cause: `web/index.html`
pre-load thủ công `firebase-app.js` + `firebase-auth.js` và set `window.firebase_core`, khiến
`firebase_core_web` bỏ qua việc inject toàn bộ SDK còn lại — bao gồm `firebase-storage`. Fix:
thêm `firebase-storage.js` vào block pre-load. Cùng session còn phát hiện 3 vấn đề liên quan:
food/vibe validation không khớp backend, `culture_tags` chưa được lưu, và thiếu loading UX.

## Symptoms

```
Snackbar: "Gửi hồ sơ thất bại: Null check operator used on a null value"
DevTools Console:
  TypeError: Cannot read properties of undefined (reading 'getStorage')
    at qF.gfu (main.dart.js:52860:30)
    at qF.ac6 (main.dart.js:52877:51)
    ...
DevTools Network: KHÔNG CÓ request nào tới firebasestorage.googleapis.com
```

Sau khi fix Storage JS, lỗi tiếp theo: `"food_tags must have between 5 and 10 items"` (backend
validation cũ) và `culture_tags` không được gửi.

## Root Cause

### Bug 1 (blocker): Firebase Storage JS SDK không được load trên web

`web/index.html` có đoạn pre-load Firebase JS SDK thủ công (workaround từ R-001 cho TrustedTypes):

```html
<script type="module">
  import * as firebaseCore from ".../12.13.0/firebase-app.js";
  import * as firebaseAuth from ".../12.13.0/firebase-auth.js";
  window.firebase_core = firebaseCore;   // ← đây là trigger
  window.firebase_auth = firebaseAuth;
</script>
```

`firebase_core_web` ([firebase_core_web.dart:179](file:///Users/thanhit/.pub-cache/hosted/pub.dev/firebase_core_web-2.24.1/lib/src/firebase_core_web.dart#L179)):
```dart
if (globalContext.getProperty('firebase_core'.toJS) != null) {
  return; // ← skip tất cả script injection khi window.firebase_core đã set
}
```

→ `window.firebase_storage` không bao giờ được inject → `firebase_storage_web` gọi
`storage_interop.getStorage(...)` (bind tới `@JS('firebase_storage')`) trên `undefined` → JS
TypeError → Dart bọc thành "Null check operator used on a null value" qua `_flutterfire_internals`
`_testException(null)`: `final e = objectException! as JSError` → `null!`.

**Dấu hiệu đặc trưng:** không có request mạng nào tới `firebasestorage.googleapis.com` trước khi lỗi.

### Bug 2: food_tags validation backend ≠ Flutter UI
Backend `user.go:175` validation: `food_tags must have between 5 and 10 items`.
Flutter `onboarding_draft.dart`: `minFood=2, maxFood=5`. Không khớp.

### Bug 3: culture_tags chưa được lưu end-to-end
`_draft.culture` được thu thập ở Screen 10 nhưng:
- `profile_service.dart` không gửi `culture_tags` trong body
- Backend struct `completeOnboardingReq` không có field
- `services.OnboardingInput` không có field
- SQL UPDATE không lưu column
- DB không có column `culture_tags`

### Bug 4: Không có loading UX khi submit
User bấm "Hoàn tất" → không có feedback trong khi upload ảnh + API call.

## Solution

### Bug 1 — Thêm firebase-storage vào pre-load block

**File:** [anmates_flutter/web/index.html](../../anmates_flutter/web/index.html)

```html
<script type="module">
  import * as firebaseCore    from "https://www.gstatic.com/firebasejs/12.13.0/firebase-app.js";
  import * as firebaseAuth    from "https://www.gstatic.com/firebasejs/12.13.0/firebase-auth.js";
  import * as firebaseStorage from "https://www.gstatic.com/firebasejs/12.13.0/firebase-storage.js";
  window.firebase_core    = firebaseCore;
  window.firebase_auth    = firebaseAuth;
  window.firebase_storage = firebaseStorage;
</script>
```

**⚠️ REBUILD REQUIRED** — `index.html` là build-time. Hot-restart (`R`) không đủ. Phải:
- Docker: `docker compose up --build`
- flutter run: `q` rồi `flutter run` lại
- Sau đó **Cmd+Shift+R** (hard-refresh) để xoá cache

**Quy tắc chung:** Mỗi khi thêm Firebase product mới (Firestore, Analytics, Functions, ...) vào
app web, phải thêm cả module JS tương ứng vào block pre-load này.

### Bug 2 — Đồng bộ food validation Flutter ↔ backend

Quyết định: đưa backend về 2–5 (theo UI design intent):

| File | Thay đổi |
|------|---------|
| `anmates-api/handlers/user.go:175` | `< 5 \|\| > 10` → `< 2 \|\| > 5`; message → "between 2 and 5 items" |
| `anmates_flutter/lib/services/onboarding_draft.dart` | `minFood=2, maxFood=5` (giữ nguyên) |

### Bug 3 — culture_tags full-stack

**Steps:**
1. DB migration [anmates-api/db/migrations/005_culture_tags.sql](../../anmates-api/db/migrations/005_culture_tags.sql):
   ```sql
   ALTER TABLE users ADD COLUMN IF NOT EXISTS culture_tags text[] NOT NULL DEFAULT '{}';
   ```
2. Chạy migration: `psql $DATABASE_URL -f db/migrations/005_culture_tags.sql`

| File | Thay đổi |
|------|---------|
| `anmates-api/models/models.go` | Thêm `CultureTags []string \`json:"culture_tags"\`` |
| `anmates-api/services/user.go` | Thêm vào `userColumns`, `scanUser`, `OnboardingInput`, nil-guard, SQL `$8=culture_tags` (avatar → `$9`) |
| `anmates-api/handlers/user.go` | Thêm field `CultureTags`, validation `1–3`, pass vào service |
| `anmates_flutter/lib/services/profile_service.dart` | Thêm param `cultureTags`, gửi `culture_tags` trong body |
| `anmates_flutter/lib/views/onboarding/photo_upload_view.dart` | Truyền `cultureTags: _draft.culture.toList()` |

**Cùng lúc sửa vibe/culture UI bounds:**
- `minCulture=1, maxCulture=3` (multi-select, trước là radio single-select)
- `minVibe=1, maxVibe=3` (trước là `2,5`)
- Backend `vibe_tags`: `< 2 \|\| > 5` → `< 1 \|\| > 3`
- Bottom bar: `{culture+vibe}/{maxCulture+maxVibe}` = `{tổng}/6 đã chọn`

### Bug 4 — Loading overlay

Thêm `_UploadingOverlay` widget (Stack over Scaffold body, hiện khi `_submitting=true`):
- Nền tối mờ `rgba(0,0,0,0.45)` + card trắng bo góc
- `CircularProgressIndicator` berry + "Đang gửi hồ sơ..." + "Vui lòng không tắt ứng dụng"
- Chặn tất cả gesture trong khi submit

## Verification

User chạy `http://127.0.0.1:54180`, hoàn thành onboarding Screens 08→09→10→11, bấm "Hoàn tất":
- Loading overlay xuất hiện ngay lập tức
- Ảnh upload thành công lên Firebase Storage (`user_photos/{uid}/main_*.jpg`)
- API `PATCH /api/v1/profile/complete-onboarding` trả 200
- Chuyển sang màn hình tiếp theo
- DB lưu `food_tags`, `vibe_tags`, `culture_tags`, `avatar_url`, `onboarding_done=true`

## Why this fix works (for future-Claude)

Khi `window.firebase_core` được set thủ công trong `index.html`, `firebase_core_web` hiểu là
"host app đã lo việc load SDK" và **skip toàn bộ script injection** cho mọi service (auth, storage,
firestore, ...). Nếu bất kỳ service nào thiếu module JS → Dart interop gọi hàm trên `undefined` →
JS TypeError → flutterfire bọc thành "Null check operator" (vì `_testException` dùng `null!`).

Dấu hiệu phân biệt với các nguyên nhân khác:
- **Không có request mạng nào** → SDK chưa load (bug này)
- **Có 403 request** → rules/auth denied
- **Có CORS-blocked request** → CORS issue
- **Có request thành công nhưng Dart lỗi** → parse/interop issue

## Gotchas / Related issues

1. **Version phải khớp:** tất cả modules trong pre-load block phải cùng version (hiện `12.13.0`).
   Khi upgrade FlutterFire packages, kiểm tra `firebase_core_web` version →
   `lib/src/firebase_sdk_version.dart` → `supportedFirebaseJsSdkVersion` → cập nhật version
   trong `index.html`.

2. **Mỗi Firebase product thêm mới = thêm 1 dòng import:** Firestore → `firebase-firestore.js` +
   `window.firebase_firestore`; Functions → `firebase-functions.js` + `window.firebase_functions`; v.v.

3. **Cloud Run thiếu endpoint `complete-onboarding`:** Production Cloud Run vẫn là code cũ (404).
   `start.sh` override `API_BASE_URL` về local nên dev không thấy. Cần deploy backend mới trước
   khi ship production.

4. **GCS bucket CORS** (cài đặt nhưng không cần thiết cho upload): Upload qua
   `firebasestorage.googleapis.com/v0/b/.../o` tự trả `access-control-allow-origin: *`. Bucket
   CORS chỉ cần cho download trực tiếp qua `storage.googleapis.com`. File `storage.cors.json` đã
   tạo và apply là harmless.

## References

- `firebase_core_web` skip-injection logic: `firebase_core_web-2.24.1/lib/src/firebase_core_web.dart:179`
- `firebase_storage_web` interop binding: `firebase_storage_web-3.11.7/lib/src/interop/storage_interop.dart:8` (`@JS('firebase_storage')`)
- `_flutterfire_internals` null-crash: `_flutterfire_internals-1.3.59/lib/_flutterfire_internals.dart:94`
- Related session: [sessions/2026-06-01-screen11-submit-null-check-cors.md](../sessions/2026-06-01-screen11-submit-null-check-cors.md)
- Related: [[R-001-firebase-phone-otp-web-127001]] (same `index.html` pre-load pattern origin)
