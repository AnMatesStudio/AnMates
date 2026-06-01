---
id: R-005
title: CI deploy lên GitHub Environment `dev` — PR testing trực tiếp tại dev-anmates-studio.web.app
tags: [flutter, go-backend, deploy, hosting, cloud-run, firebase, gcp, github-actions, ci-cd, web-dev]
platforms: [web, backend]
severity: major
status: confirmed
date_resolved: 2026-06-01
confirmed_by: user
related_sessions: [sessions/2026-06-01-ci-dev-environment-deploy.md]
related_blockers: []
---

# R-005: CI deploy lên GitHub Environment `dev` — PR testing trực tiếp tại dev-anmates-studio.web.app

## TL;DR

Thêm GitHub Environment `dev` làm deploy target cho CI (chạy trên PR), để reviewer/dev test branch trực tiếp tại `https://dev-anmates-studio.web.app` (Flutter web baked với dev Cloud Run API) trước khi merge. `cd.*` workflows giữ nguyên deploy lên env `production`. Cả 2 tầng dùng 1 env duy nhất (`dev` / `production`) thay vì split per-platform.

## Symptoms (before)

- PR đổi Flutter/Go code → chỉ biết "CI xanh" nhưng không test được trên URL thật trước merge
- Phải deploy thủ công hoặc chạy local để review UI/API
- `cd.*` dùng `production-web` + `production-api` (2 env riêng) gây inconsistency với `dev` (1 env)

## Root Cause

CI workflows (`ci.flutter-web.yml`, `ci.go-api.yml`) chưa có bước deploy — chỉ test + build (no push). Không có GitHub Environment `dev` để deploy vào.

## Solution

### Steps

1. **Tạo GitHub Environments** — vào `Settings → Environments`:
   - Tạo `dev` (không set reviewers, không giới hạn branch)
   - Tạo `production` (không set reviewers — hiện tại pre-MVP)
   - Xoá `production-web` và `production-api` (cũ)

2. **Update `ci.flutter-web.yml`** — thêm job `deploy-dev` sau `analyze-test-build`:
   - Build web với `--dart-define=API_BASE_URL=https://anmates-api-492509819332.asia-southeast1.run.app`
   - `environment: { name: dev, url: https://dev-anmates-studio.web.app }`
   - WIF auth → Firebase CLI → `firebase deploy --only hosting:dev`
   - Comment URL + API lên PR (prefix `🚀 **Dev deployed**`)
   - Guard: `if: github.event.pull_request.head.repo.full_name == github.repository` (skip fork PR)

3. **Update `ci.go-api.yml`** — thêm job `deploy-dev` sau `lint-test`:
   - WIF auth → docker build+push `:dev-<sha>` → `gcloud run deploy --set-env-vars ENV=dev` lên shared `anmates-api`
   - Smoke check `curl /health`
   - `environment: { name: dev, url: https://anmates-api-...run.app }`
   - Guard same-repo only

4. **Update `cd.flutter-web.yml` + `cd.go-api.yml`** — đổi `production-web`/`production-api` → `production`

5. **Apply CORS lên Firebase Storage** (đã có `dev-anmates-studio.web.app` trong origins):
   ```powershell
   gsutil cors set anmates_flutter/storage.cors.json gs://anmates-studio.firebasestorage.app
   ```

### Code changes

| File | Change |
|------|--------|
| `.github/workflows/ci.flutter-web.yml` | Rewrite: thêm job `deploy-dev`, build `--dart-define API_BASE_URL`, artifact name → `github.run_id`, comment PR |
| `.github/workflows/ci.go-api.yml` | Rewrite: thêm job `deploy-dev` (docker build+push+deploy Cloud Run+smoke), `docker-build` giữ làm required gate |
| `.github/workflows/cd.flutter-web.yml` | `environment.name`: `production-web` → `production` |
| `.github/workflows/cd.go-api.yml` | `environment.name`: `production-api` → `production` |
| `.github/CI-CD.md` | Bảng overview, bảng Environments, Bước 4+5 setup, sơ đồ flow PR, troubleshooting |
| `.github/WORKFLOW-ARCHITECTURE.md` | Section "Dev environment (transitional)" + "One env per tier" + Phase 4 |
| `anmates_flutter/storage.cors.json` | `https://dev-anmates-studio.web.app` đã có sẵn, apply lên GCS bucket |

## Verification

User mở PR, CI chạy job `deploy-dev` trên cả `ci.flutter-web.yml` và `ci.go-api.yml`. Luồng deploy chạy thành công, user xác nhận `https://dev-anmates-studio.web.app` accessible với code của PR.

## Why this fix works (for future-Claude)

- `deploy-dev` nằm trong `ci.*` (không phải `cd.*`) vì trigger là `pull_request` — đúng với naming convention (`lifecycle.service-platform.yml`). Deploy không phải required check → không block fork PR.
- `--dart-define=API_BASE_URL` bake URL vào Flutter bundle lúc compile → web build gọi đúng dev API (baked in, không phải runtime).
- `env_vars_update_strategy: merge` (nếu dùng deploy-cloudrun action) hoặc `--set-env-vars` ghi đè chỉ `ENV=dev` + bắt buộc 3 secrets; các env var khác trên Cloud Run được giữ nguyên.
- `firebase target:apply hosting dev dev-anmates-studio` map target name `dev` → site `dev-anmates-studio` trước khi `firebase deploy --only hosting:dev`.

## Gotchas / Related issues

1. **Hai PR backend mở cùng lúc đè nhau:** `dev` và `production` đang dùng chung 1 Cloud Run `anmates-api` + 1 DB (transitional). Mỗi PR backend deploy đè 100% traffic. Kế hoạch tách: Cloud Run `anmates-api-prod` riêng + Cloud SQL cho production — xem WORKFLOW-ARCHITECTURE.md § "Future split".

2. **Fork PR bị skip deploy:** Đúng chủ ý — fork không có quyền access secrets. Guard `github.event.pull_request.head.repo.full_name == github.repository`.

3. **Firebase site `dev-anmates-studio` phải tồn tại** trước khi deploy:
   ```bash
   firebase hosting:sites:create dev-anmates-studio --project anmates-studio
   ```

4. **`gh.exe` có cài** tại `C:\Program Files\GitHub CLI\gh.exe` nhưng không trên PATH. Dùng full path khi cần: `& "C:\Program Files\GitHub CLI\gh.exe" <command>`.

5. **GCS CORS** cho `dev-anmates-studio.web.app` — đã có trong `storage.cors.json` và đã apply lên bucket. Nếu add origin mới, re-run `gsutil cors set`.

## References

- Related session: [sessions/2026-06-01-ci-dev-environment-deploy.md](../sessions/2026-06-01-ci-dev-environment-deploy.md)
- Related: [[R-002-deploy-flutter-firebase-go-cloudrun]] (initial deploy setup)
- WORKFLOW-ARCHITECTURE.md § "Dev environment (transitional)": `.github/WORKFLOW-ARCHITECTURE.md`
- CI-CD.md setup guide: `.github/CI-CD.md`
