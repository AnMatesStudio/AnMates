---
id: R-002
title: Deploy Flutter Web lên Firebase Hosting + Go Fiber API lên Cloud Run (GCP)
tags: [flutter, firebase, go-backend, cloud-run, gcp, deploy, hosting, api-base-url]
platforms: [web, backend]
severity: major
status: confirmed
date_resolved: 2026-05-26
confirmed_by: user
related_sessions: []
related_blockers: []
---

# R-002: Deploy Flutter Web lên Firebase Hosting + Go Fiber API lên Cloud Run (GCP)

## TL;DR

Flutter Web build ra `build/web` deploy lên Firebase Hosting (project `anmates-studio`). Go Fiber API (có sẵn Dockerfile) deploy lên Cloud Run region `asia-southeast1`. Lỗi phổ biến: `firebase.json` trỏ sai thư mục `public` thay vì `build/web`, và Flutter gọi `localhost:8080` do chưa cập nhật `defaultValue` trong `String.fromEnvironment`.

## Symptoms

- Sau `firebase deploy --only hosting` — app trắng hoặc không load vì `firebase.json` có `"public": "public"` (thư mục placeholder rỗng).
- Flutter gọi `http://localhost:8080/api/auth/phone-verify` dù đã deploy lên Firebase Hosting — do `String.fromEnvironment` fallback về `localhost:8080`.

## Root Cause

1. `firebase init hosting` tạo thư mục `public/` mặc định, không tự detect `build/web`.
2. `String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080')` — nếu build không truyền `--dart-define`, defaultValue được bake in lúc compile. Old builds vẫn gọi localhost dù đã thay code.

## Solution

### Phần 1 — Flutter Web → Firebase Hosting

**Bước 1: Cài Firebase CLI**
```powershell
npm install -g firebase-tools
firebase login
```

**Bước 2: Sửa `firebase.json`** — đổi `public` sang `build/web`:
```json
{
  "hosting": {
    "public": "build/web",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "rewrites": [{ "source": "**", "destination": "/index.html" }]
  }
}
```

**Bước 3: Build + Deploy**
```powershell
cd anmates_flutter
flutter build web --release --base-href /
firebase deploy --only hosting
```

URL sau deploy: `https://anmates-studio.web.app`

---

### Phần 2 — Go Fiber API → Cloud Run

**Prerequisites:** `gcloud` CLI cài sẵn, đã `gcloud auth login`, project set `anmates-studio`.

**Bước 1: Enable services + tạo Artifact Registry**
```powershell
gcloud services enable run.googleapis.com artifactregistry.googleapis.com
gcloud artifacts repositories create anmates-api `
  --repository-format=docker `
  --location=asia-southeast1
```

**Bước 2: Build + Push image**
```powershell
cd anmates-api
gcloud builds submit --tag asia-southeast1-docker.pkg.dev/anmates-studio/anmates-api/api:latest
```

**Bước 3: Deploy lên Cloud Run**
```powershell
gcloud run deploy anmates-api `
  --image asia-southeast1-docker.pkg.dev/anmates-studio/anmates-api/api:latest `
  --platform managed `
  --region asia-southeast1 `
  --allow-unauthenticated `
  --port 8080 `
  --timeout 3600 `
  --set-env-vars "DATABASE_URL=<supabase-or-cloud-sql-url>" `
  --set-env-vars "JWT_SECRET=<min-32-chars>" `
  --set-env-vars "FIREBASE_WEB_API_KEY=<firebase-web-api-key>" `
  --set-env-vars "ENV=production"
```

`--timeout 3600` bắt buộc vì app có WebSocket (`/ws/chat/:matchId`).

URL sau deploy: `https://anmates-api-492509819332.asia-southeast1.run.app`

---

### Phần 3 — Fix Flutter gọi localhost thay vì Cloud Run URL

Cập nhật `defaultValue` trong **2 file**:

### Code changes
| File | Change |
|------|--------|
| `anmates_flutter/lib/services/api_client.dart` | `defaultValue: 'http://localhost:8080'` → `defaultValue: 'https://anmates-api-492509819332.asia-southeast1.run.app'` |
| `anmates_flutter/lib/services/auth_service.dart` | `defaultValue: 'http://localhost:8080'` → `defaultValue: 'https://anmates-api-492509819332.asia-southeast1.run.app'` |

Sau đó rebuild + redeploy Flutter (xem Phần 1 Bước 3). Mở tab incognito để tránh browser cache.

> **Lưu ý dev local:** để dev vẫn dùng localhost, truyền flag lúc chạy:
> ```powershell
> flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8080
> ```

---

### Database (Postgres)

Dùng **Supabase** (free, region Singapore) thay Cloud SQL để tiết kiệm chi phí:
1. Vào supabase.com → New project → Region: Southeast Asia
2. Settings → Database → Connection string → URI
3. Paste vào `DATABASE_URL` env var của Cloud Run

## Verification

- Flutter app tại `https://anmates-studio.web.app` load thành công
- Phone OTP flow gọi `https://anmates-api-492509819332.asia-southeast1.run.app/api/auth/phone-verify` (không còn localhost)
- Cloud Run URL trả về từ: `gcloud run deploy` output

## Why this fix works (for future-Claude)

`String.fromEnvironment` được resolve **lúc compile**, không phải runtime. Nên dù đổi code rồi nhưng nếu không rebuild thì binary vẫn chứa giá trị cũ. Phải đổi `defaultValue` (thay vì chỉ dùng `--dart-define`) để production build không cần flag đặc biệt.

## Gotchas / Related issues

- `firebase.json` trong repo có 2 section: `flutter` (Firebase SDK config) và `hosting` — chỉ `hosting.public` cần đổi.
- Go Fiber dùng `fasthttp` — **không tương thích** với Vercel serverless (cần `net/http`). Cloud Run là lựa chọn đúng.
- CORS đã được cấu hình trong `main.go` với `Access-Control-Allow-Origin: *` — không cần thêm gì.
- Firebase Phone Auth: domain `anmates-studio.web.app` tự động có trong Authorized Domains — không cần add thủ công (khác với custom domain).
- Xem R-001 cho vấn đề Firebase Phone OTP trên web localhost.

## References

- Related resolution: [R-001 Firebase Phone OTP](R-001-firebase-phone-otp-web-127001.md)
- Cloud Run WebSocket docs: https://cloud.google.com/run/docs/triggering/websockets
