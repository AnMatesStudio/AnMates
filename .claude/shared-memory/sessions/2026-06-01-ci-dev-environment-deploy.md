# Session 2026-06-01 — CI deploy lên GitHub Environment `dev`

**Owner:** main-assistant
**Status:** done (code + docs written) — verification pending (chưa chạy CI thật)
**Branch:** TECH-7

## TL;DR

Thêm 1 GitHub Environment **`dev`** làm deploy target cho **CI** (chạy trên PR), để dev/reviewer test branch trực tiếp trên URL thật trước khi merge:
- Web: `https://dev-anmates-studio.web.app`
- API: `https://anmates-api-492509819332.asia-southeast1.run.app` (Cloud Run `anmates-api`, chia sẻ với prod — transitional)

`ci.flutter-web.yml` + `ci.go-api.yml` giờ có job `deploy-dev` (same-repo PR only) trỏ `environment: { name: dev }`. `cd.*` giữ nguyên (vẫn ENV inject chung với dev) — sẽ tách production sau.

## Quyết định (user-chosen)

- **1 environment duy nhất `dev`** (không phải `dev-web`/`dev-api`). User chọn qua AskUserQuestion. Mỗi job vẫn set `url:` riêng trên cùng env `dev`. Lý do + alternative ghi trong WORKFLOW-ARCHITECTURE.md § "Why one dev env".
- Dev deploy nằm trong `ci.*` (không tạo `cd.*` mới) vì trigger là `pull_request`. Vẫn giữ separation: deploy KHÔNG phải required check; required gate là các job test/build không cần secret (chạy cả trên fork).

## Files changed

| File | Thay đổi |
|------|----------|
| `.github/workflows/ci.flutter-web.yml` | Rewrite: build web `--dart-define=API_BASE_URL` (dev Cloud Run); job `preview-deploy` → `deploy-dev` với `environment: {name: dev, url: dev-anmates-studio.web.app}`, same-repo guard giữ nguyên; artifact name → `github.run_id`; comment PR đổi prefix → `🚀 **Dev deployed**` |
| `.github/workflows/ci.go-api.yml` | Rewrite: thêm job `deploy-dev` (WIF auth → docker build+push `:dev-<sha>` → `gcloud run deploy --set-env-vars ENV=dev` lên shared `anmates-api` → smoke `/health`), same-repo only; `docker-build` (no-push) giữ làm required gate chạy mọi PR |
| `.github/CI-CD.md` | Bảng overview + bảng Environments mới; Bước 4 tạo env `dev` (UI + gh CLI); Bước 5 branch protection (KHÔNG để deploy làm required check); sơ đồ flow PR; 3 troubleshooting mới |
| `.github/WORKFLOW-ARCHITECTURE.md` | Section mới "Dev environment (transitional)": rationale bend principle 1, rủi ro shared infra, kế hoạch split production (Cloud Run `anmates-api-prod` + Cloud SQL + Secret Manager + env-scoped secrets), lý do 1 env; cập nhật Phase 1 note |

## ⚠️ Setup thủ công cần làm (chưa làm được trong session — máy không có `gh`)

1. **Tạo GitHub Environment `dev`** (bắt buộc, nếu không job deploy lỗi `Value 'dev' is not valid`):
   - UI: `Settings → Environments → New environment → dev` (KHÔNG set required reviewers, KHÔNG giới hạn branch).
   - hoặc: `gh api --method PUT "repos/<owner>/<repo>/environments/dev"`
2. **Firebase Hosting site `dev-anmates-studio`** phải tồn tại (target `dev` apply tới site này). Nếu chưa có: `firebase hosting:sites:create dev-anmates-studio --project anmates-studio`.
3. Secrets repo (`GCP_WIF_PROVIDER`, `GCP_SA_EMAIL`, `DATABASE_URL`, `JWT_SECRET`, `FIREBASE_WEB_API_KEY`) — đã có từ TECH-2, dev xài chung.

## Rủi ro đã biết (transitional)

- `dev` và production **chung 1 Cloud Run `anmates-api` + 1 DB**. Same-repo PR đổi backend → deploy đè 100% traffic lên service chung (prod chạy code PR tới lần deploy kế). 2 PR backend mở cùng lúc đè nhau.
- Chấp nhận vì pre-MVP, team nhỏ. Là lý do chính để làm "Future split" (Cloud Run prod riêng + Cloud SQL + Secret Manager) ghi trong WORKFLOW-ARCHITECTURE.md.

## Verification (pending)

- [ ] Tạo env `dev` + site `dev-anmates-studio`
- [ ] Mở PR đổi `anmates_flutter/**` → CI deploy → comment dev URL → mở `dev-anmates-studio.web.app` test OK
- [ ] Mở PR đổi `anmates-api/**` → CI deploy Cloud Run dev → `/health` 200
- [ ] Confirm fork PR chỉ chạy test/build (skip deploy)

Khi user confirm chạy thật OK → migrate session này thành resolution (Path A).

## Update 2026-06-01 (cùng ngày) — gộp env production

Theo yêu cầu user: gộp `production-web` + `production-api` → **1 env `production`** (mirror cách `dev` gộp 1).
- `cd.flutter-web.yml` + `cd.go-api.yml`: `environment.name` → `production` (url giữ riêng mỗi job).
- Docs: CI-CD.md (bảng env, Bước 4 tạo cả `dev`+`production` + cmd xoá env cũ), WORKFLOW-ARCHITECTURE.md (§ "One env per tier" thay § "Why one dev env"; Phase 4 = điểm split per-platform).
- ⚠️ Cần tạo env `production` trên repo + xoá `production-web`/`production-api`.
  - **`gh.exe` CÓ cài** tại `C:\Program Files\GitHub CLI\gh.exe` nhưng **chưa `auth login`** (không trên PATH; không có `GH_TOKEN`; Git Credential Manager không có token GitHub). `gh auth login` là interactive → không chạy được trong môi trường agent.
  - ⇒ Assistant **không tự xoá env được**. User phải: chạy `gh auth login` 1 lần (hoặc set `GH_TOKEN`) rồi chạy lệnh delete, hoặc xoá qua UI `Settings → Environments`.

## ✅ Update 2026-06-01 — env setup DONE (user-confirmed)

User đã tạo env `dev` + `production` và xoá `production-web`/`production-api` qua GitHub UI (xác nhận bằng screenshot: repo giờ chỉ còn 2 env `dev`, `production`). IDE warning `Value 'dev'/'production' is not valid` sẽ tự hết.

## Open follow-ups

- ~~Tạo env `dev` + `production`; xoá env cũ~~ ✅ DONE (user, 2026-06-01).
- Tạo Firebase site `dev-anmates-studio` nếu chưa có (`firebase hosting:sites:create dev-anmates-studio --project anmates-studio`).
- Mở 1 PR thử để verify luồng deploy CI → dev thực sự chạy (chưa test). Khi OK → migrate session này thành resolution.
- Future: tách production tier (xem WORKFLOW-ARCHITECTURE.md § "Future split").
- Cân nhắc job-level concurrency `cancel-in-progress: false` cho `deploy-dev` nếu việc hủy deploy giữa chừng gây vấn đề (hiện workflow-level cancel có thể cắt deploy đang chạy).
