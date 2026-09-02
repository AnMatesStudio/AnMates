# CI/CD — GitHub Actions

> ⚠️ **TÀI LIỆU CŨ (thời GCP: Cloud Run + Firebase Hosting).** Không còn khớp
> thực tế: các workflow `cd.*.yml`, `ci.go-api.yml`, `ci.flutter-web.yml`,
> `ci-build-push.yml` mô tả bên dưới **đã bị xoá**. Từ 2026-09-02 toàn bộ CI nằm
> trong **một file duy nhất** [`workflows/ci.yml`](workflows/ci.yml): 2 lane song
> song (api/web), PR thì build không push, push `main` thì push image lên **GHCR**,
> deploy là bước **thủ công** bằng `helm upgrade` trên host.
> Nguồn đúng: [`docs/plans/2026-09-01-mvp-1day-onprem-k8s.md`](../docs/plans/2026-09-01-mvp-1day-onprem-k8s.md).
> Giữ file này làm tham chiếu lịch sử cho đường lùi GCP.

Pipeline cho AnMates monorepo (Flutter web + Go Fiber API → GCP).

Liên quan: ticket [TECH-2](https://anmatesstudio.atlassian.net/browse/TECH-2), resolution [R-002](../.claude/shared-memory/resolutions/R-002-deploy-flutter-firebase-go-cloudrun.md).

---

## Tổng quan

| Workflow | Trigger | Job chính | Deploy đến |
|---|---|---|---|
| [`ci.flutter-web.yml`](workflows/ci.flutter-web.yml) | PR → `main`, path `anmates_flutter/**` | analyze, test, build web, **deploy → `dev`** | `https://dev-anmates-studio.web.app` (env `dev`) |
| [`ci.go-api.yml`](workflows/ci.go-api.yml) | PR → `main`, path `anmates-api/**` | lint, build, test, docker build (gate), **deploy → `dev`** | `https://anmates-api-...run.app` (env `dev`, shared Cloud Run) |
| [`cd.flutter-web.yml`](workflows/cd.flutter-web.yml) | push `main`, path `anmates_flutter/**` | analyze, test, build web, deploy | `https://anmates-studio.web.app` (env `production`) |
| [`cd.go-api.yml`](workflows/cd.go-api.yml) | push `main`, path `anmates-api/**` | vet, test, docker build + push, Cloud Run deploy, smoke check, auto-rollback | `https://anmates-api-492509819332.asia-southeast1.run.app` (env `production`) |

> Naming convention: `<lifecycle>.<service>-<platform>.yml`. Xem [WORKFLOW-ARCHITECTURE.md](WORKFLOW-ARCHITECTURE.md) cho rationale + migration plan khi add Android/iOS.

Mọi workflow đều có **path filter** — không lãng phí runner minutes khi đổi file ngoài scope.

### Môi trường (GitHub Environments)

| Environment | Dùng bởi | URL | Mục đích |
|---|---|---|---|
| `dev` | `ci.*` (trên PR) | web: `https://dev-anmates-studio.web.app` · api: shared Cloud Run | Test branch/PR trực tiếp trên URL thật trước khi merge |
| `production` | `cd.flutter-web.yml` + `cd.go-api.yml` | web: `https://anmates-studio.web.app` · api: `https://anmates-api-...run.app` | Live sau khi merge `main` |

> Cả web lẫn api dùng chung **1 env `production`** (mirror cách `dev` gộp 1 env). Mỗi `cd.*` job set `url:` riêng trên cùng env. Tách thành `production-web`/`production-api` chỉ khi cần protection rule per-platform riêng (xem WORKFLOW-ARCHITECTURE.md).

> **Lưu ý transitional:** `dev` và production **đang dùng chung 1 Cloud Run `anmates-api` + 1 DB**. Mỗi same-repo PR có thay đổi backend sẽ **deploy đè 100% traffic** lên service chung này. Đây là trạng thái tạm thời — kế hoạch tách production (Cloud Run mới + Cloud SQL + Secret Manager) ghi trong [WORKFLOW-ARCHITECTURE.md](WORKFLOW-ARCHITECTURE.md) § "Dev environment (transitional)".

---

## One-time setup (bạn chạy 1 lần)

### Bước 1: Bootstrap Workload Identity Federation (WIF)

WIF cho phép GitHub Actions impersonate một service account GCP mà **không cần** lưu JSON key tĩnh trong repo.

```bash
# Login as a GCP user with Owner role on project anmates-studio
gcloud auth login

# Chạy script
bash ./scripts/setup-wif.sh
```

Script là idempotent (chạy lại an toàn). Output cuối in ra 2 giá trị để bạn paste vào GitHub Secrets.

### Bước 2: Add GitHub repo secrets

Vào `Settings → Secrets and variables → Actions → New repository secret` và add:

| Secret name | Source | Mục đích |
|---|---|---|
| `GCP_WIF_PROVIDER` | Output của `setup-wif.sh` | OIDC provider name (dạng `projects/N/locations/global/workloadIdentityPools/.../providers/...`) |
| `GCP_SA_EMAIL` | Output của `setup-wif.sh` | `github-actions@anmates-studio.iam.gserviceaccount.com` |
| `DATABASE_URL` | Supabase project settings | Postgres connection string |
| `JWT_SECRET` | Generated locally (min 32 chars) | JWT signing key |
| `FIREBASE_WEB_API_KEY` | Firebase Console → Project settings → General | Web API key |
| `GOONG_API_KEY` *(optional)* | [account.goong.io](https://account.goong.io) (free key) | Discovery `/venues/nearby` provider (VN-legal Google-Maps alt). Dùng khi `MAP_PROVIDER=goong` hoặc auto. Bỏ trống = client fallback Overpass |
| `GOONG_MAPTILES_KEY` *(optional)* | [account.goong.io](https://account.goong.io) → **Maptiles Key** (khác `GOONG_API_KEY`) | Render bản đồ tương tác tab "Bản đồ" (Goong Map Tiles). Inject vào Flutter web build qua `--dart-define` ở `ci/cd.flutter-web.yml`. Bỏ trống = bản đồ trống (build vẫn pass) |
| `TOMTOM_API_KEY` *(optional)* | [developer.tomtom.com](https://developer.tomtom.com) (free key) | Discovery `/venues/nearby` provider thay thế (dùng khi `MAP_PROVIDER=tomtom`). Bỏ trống = không dùng TomTom |
| `FOURSQUARE_KEY` *(optional)* | [foursquare.com/developers](https://foursquare.com/developers) (free **search** tier) | Nguồn ảnh "chính chủ": match quán theo tên+toạ độ → website chính thức → og:image. Chỉ dùng `/places/search` (free); `/photos` tính phí. Bỏ trống = dùng Bing + ảnh category |
| `SMTP_PASSWORD` *(optional)* | Gmail App Password (Account → Security → App passwords) | Email OTP gửi mã thật. Bỏ trống = email OTP chỉ bật trong DEV_MODE |

### Bước 3 (optional): Repo variables

Vào `Settings → Secrets and variables → Actions → Variables → New repository variable`:

| Variable name | Default value | Mục đích |
|---|---|---|
| `API_BASE_URL` | `https://anmates-api-492509819332.asia-southeast1.run.app` | Override khi đổi Cloud Run URL |
| `MAP_PROVIDER` *(optional)* | *(trống = auto)* | Chọn nguồn Discovery nearby: `goong` \| `tomtom` \| trống (auto: ưu tiên Goong nếu có key) |

### Bước 4: Tạo GitHub Environments `dev` + `production`

Workflows deploy vào 2 environment: **`dev`** (`ci.*` trên PR) và **`production`** (`cd.*` trên push `main`). Phải tạo trước, nếu không job deploy lỗi `Value '<name>' is not valid`.

> ⚠️ Trước đây dùng `production-web` + `production-api` (2 env). Đã gộp thành **1 env `production`** (giống cách `dev` gộp 1). Sau khi tạo `production`, có thể xoá 2 env cũ trong `Settings → Environments`.

**Cách 1 — UI:** `Settings → Environments → New environment` → tạo lần lượt `dev` và `production` → Configure.
- KHÔNG set required reviewers (giai đoạn này auto-deploy, không cần approve).
- KHÔNG giới hạn deployment branches.

**Cách 2 — CLI (`gh`):**
```bash
repo=$(gh repo view --json nameWithOwner -q .nameWithOwner)
gh api --method PUT "repos/$repo/environments/dev"
gh api --method PUT "repos/$repo/environments/production"
# (tuỳ chọn) dọn env cũ:
# gh api --method DELETE "repos/$repo/environments/production-web"
# gh api --method DELETE "repos/$repo/environments/production-api"
```

> Environment-scoped secrets là **tuỳ chọn** ở giai đoạn này — cả `dev` lẫn `production` đang xài chung repo-level secrets (`DATABASE_URL`, `JWT_SECRET`, ...) và chung hạ tầng (1 Cloud Run + 1 DB). Khi tách production riêng (xem WORKFLOW-ARCHITECTURE.md), chuyển secret prod vào env `production` và để secret dev riêng trong env `dev`.

### Bước 5: Branch protection cho `main`

Vào `Settings → Branches → Add rule` cho `main`:
- ✅ Require a pull request before merging
- ✅ Require status checks to pass before merging — chọn `Analyze + Test + Build web`, `Lint + Test`, `Docker build (no push)`
  - ⚠️ **KHÔNG** chọn `Deploy → dev (...)` làm required check — deploy phụ thuộc secrets/hạ tầng ngoài, dễ flaky; gate phải là các job test/build không cần secret (chạy được cả trên fork PR).
- ✅ Require branches to be up to date before merging
- ✅ Do not allow bypassing the above settings

---

## Workflow flow

### PR mở ra (CI → deploy `dev`)

```
┌── PR opened/updated ──┐
│                        │
├─ anmates_flutter/** ──→ ci.flutter-web.yml
│   ├─ flutter analyze
│   ├─ flutter test
│   ├─ flutter build web (--dart-define API_BASE_URL, artifact)
│   └─ [same-repo PR] deploy → env dev (dev-anmates-studio.web.app)
│         └─ comment dev URL on PR
│
└─ anmates-api/** ──────→ ci.go-api.yml
    ├─ golangci-lint
    ├─ go build + go test -race
    ├─ docker build (verify Dockerfile — required gate, no secrets)
    └─ [same-repo PR] deploy → env dev (shared Cloud Run anmates-api)
          ├─ docker build + push :dev-<sha>
          ├─ gcloud run deploy --set-env-vars ENV=dev
          └─ curl /health smoke check
```

> Fork PR: chỉ chạy các job test/build (không deploy) vì không có quyền access secrets — đúng chủ ý bảo mật.

### PR merged → main (CD)

```
┌── push to main ──┐
│                   │
├─ anmates_flutter/** ──→ cd.flutter-web.yml
│   ├─ build web (with API_BASE_URL)
│   ├─ firebase deploy --only hosting
│   └─ curl smoke check https://anmates-studio.web.app
│
└─ anmates-api/** ──────→ cd.go-api.yml
    ├─ capture previous revision name
    ├─ docker build + docker push → Artifact Registry (on the runner, not Cloud Build)
    ├─ gcloud run deploy --revision-suffix sha-XXXXXXX
    ├─ curl smoke check /health (6 attempts × 10s)
    └─ if smoke fails → auto-rollback traffic to previous revision
```

---

## Rollback procedures

### Cloud Run (Go API)

CD workflow tự rollback nếu smoke check fail. Nếu cần rollback thủ công sau đó:

```bash
# Xem revisions
gcloud run revisions list --service=anmates-api --region=asia-southeast1

# Rollback 100% traffic về revision cũ
gcloud run services update-traffic anmates-api \
  --region=asia-southeast1 \
  --to-revisions=anmates-api-sha-ABC1234=100
```

### Firebase Hosting (Flutter web)

Firebase giữ history mọi release:

```bash
cd anmates_flutter
firebase hosting:releases:list --project anmates-studio
firebase hosting:rollback --project anmates-studio
```

Hoặc qua Firebase Console → Hosting → Release history → "Rollback".

---

## Idempotency notes

- **Cloud Run deploy**: `gcloud run deploy` tự tạo revision mới mỗi lần. `--revision-suffix sha-XXX` giúp truy ngược commit.
- **Firebase Hosting deploy**: Tạo release mới mỗi lần, không ghi đè.
- **Artifact Registry**: Image push với tag `:${SHA}` immutable, `:latest` di động (move tag).
- **WIF setup script**: Mọi step dùng `describe || create`, chạy lại không break gì.

---

## Troubleshooting

### `Permission 'iam.serviceAccounts.getAccessToken' denied`
→ Repo của bạn không khớp với attribute condition của WIF provider. Check `setup-wif.sh` config: `GITHUB_ORG` và `GITHUB_REPO` phải khớp với GitHub repo thật. Re-run script để update.

### `firebase deploy` fail với `403 Forbidden`
→ Service account thiếu role `roles/firebasehosting.admin`. Re-run `setup-wif.sh`.

### Cloud Run revision deploy thành công nhưng `/health` trả về 502/503
→ Container crash khi startup. Xem logs:
```bash
gcloud run services logs read anmates-api --region=asia-southeast1 --limit=50
```
Thường do thiếu env vars (`DATABASE_URL`/`JWT_SECRET`). Check GitHub secrets được set đúng.

### CI báo `Skipped: Deploy → dev (...)` ở fork PR
→ Đây là chủ ý — fork PR không có quyền access secrets vì lý do bảo mật. Maintainer phải approve hoặc rebase trong repo để branch deploy lên `dev`.

### Job deploy lỗi `Value 'dev' is not valid` / `Environment 'dev' not found`
→ Chưa tạo GitHub Environment `dev`. Xem [One-time setup Bước 4](#bước-4-tạo-github-environment-dev). Lỗi này cũng hiện trong VS Code (GitHub Actions extension) như một warning cho tới khi env được tạo trên repo.

### Hai PR cùng đổi backend → đè nhau trên `dev`
→ Đúng như thiết kế hiện tại: `dev` và production **share 1 Cloud Run**. PR deploy sau ghi đè revision của PR trước (100% traffic). `concurrency: cancel-in-progress` serialize trong cùng 1 PR, nhưng **khác PR thì không**. Nếu cần test song song nhiều PR → đó là tín hiệu nên tách dev service riêng (xem WORKFLOW-ARCHITECTURE.md § "Dev environment (transitional)").

### `gcloud builds submit` fail: `This tool can only stream logs if you are Viewer/Owner`
→ Đây là lý do `cd.go-api.yml` **không dùng** `gcloud builds submit`. Cloud Build mặc định stream log về terminal, và việc đó đòi identity gọi phải là Viewer/Owner của project. SA `github-actions@` theo least-privilege không có `roles/viewer`, nên build submit OK nhưng gcloud không tail được log → exit 1 (dù build có thể đã chạy xong). **Giải pháp đang dùng:** build image thẳng trên GitHub runner bằng `docker build` + `docker push` (nhanh hơn, rẻ hơn, ít quyền hơn). Nếu vì lý do nào đó bạn buộc phải dùng Cloud Build, thêm flag `--suppress-logs` (hoặc cấp SA `roles/viewer` — không khuyến khích).

---

## Future improvements

- [ ] Add Slack/Discord notification trên deploy success/fail
- [ ] Add visual regression (Percy/Chromatic) cho Flutter web
- [ ] Migrate secrets sang Google Secret Manager (audit log tốt hơn)
- [ ] Cache Docker layers giữa CI runs (đã có `cache-from: gha`)
- [ ] Add E2E test job chạy Playwright sau preview deploy
