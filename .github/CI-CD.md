# CI/CD — GitHub Actions

Pipeline cho AnMates monorepo (Flutter web + Go Fiber API → GCP).

Liên quan: ticket [TECH-2](https://anmatesstudio.atlassian.net/browse/TECH-2), resolution [R-002](../.claude/shared-memory/resolutions/R-002-deploy-flutter-firebase-go-cloudrun.md).

---

## Tổng quan

| Workflow | Trigger | Job chính | Deploy đến |
|---|---|---|---|
| [`ci.flutter-web.yml`](workflows/ci.flutter-web.yml) | PR → `main`, path `anmates_flutter/**` | analyze, test, build web, **deploy preview channel** | `pr-N` preview URL (7d expiry) |
| [`ci.go-api.yml`](workflows/ci.go-api.yml) | PR → `main`, path `anmates-api/**` | gofmt, vet, build, test, docker build (no push) | — |
| [`cd.flutter-web.yml`](workflows/cd.flutter-web.yml) | push `main`, path `anmates_flutter/**` | analyze, test, build web, deploy | `https://anmates-studio.web.app` |
| [`cd.go-api.yml`](workflows/cd.go-api.yml) | push `main`, path `anmates-api/**` | vet, test, docker build + push, Cloud Run deploy, smoke check, auto-rollback | `https://anmates-api-492509819332.asia-southeast1.run.app` |

> Naming convention: `<lifecycle>.<service>-<platform>.yml`. Xem [WORKFLOW-ARCHITECTURE.md](WORKFLOW-ARCHITECTURE.md) cho rationale + migration plan khi add Android/iOS.

Mọi workflow đều có **path filter** — không lãng phí runner minutes khi đổi file ngoài scope.

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

### Bước 3 (optional): Repo variables

Vào `Settings → Secrets and variables → Actions → Variables → New repository variable`:

| Variable name | Default value | Mục đích |
|---|---|---|
| `API_BASE_URL` | `https://anmates-api-492509819332.asia-southeast1.run.app` | Override khi đổi Cloud Run URL |

### Bước 4: Branch protection cho `main`

Vào `Settings → Branches → Add rule` cho `main`:
- ✅ Require a pull request before merging
- ✅ Require status checks to pass before merging — chọn `Analyze + Test + Build web`, `Lint + Test`, `Docker build (no push)`
- ✅ Require branches to be up to date before merging
- ✅ Do not allow bypassing the above settings

---

## Workflow flow

### PR mở ra (CI)

```
┌── PR opened/updated ──┐
│                        │
├─ anmates_flutter/** ──→ ci.flutter-web.yml
│   ├─ flutter analyze
│   ├─ flutter test
│   ├─ flutter build web (artifact)
│   └─ deploy preview channel pr-N → comment URL on PR
│
└─ anmates-api/** ──────→ ci.go-api.yml
    ├─ gofmt -l
    ├─ go vet
    ├─ go test -race
    └─ docker build (verify Dockerfile)
```

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

### CI Flutter báo `Skipped: deploy preview channel` ở fork PR
→ Đây là chủ ý — fork PR không có quyền access secrets vì lý do bảo mật. Maintainer phải approve hoặc rebase trong repo.

### `gcloud builds submit` fail: `This tool can only stream logs if you are Viewer/Owner`
→ Đây là lý do `cd.go-api.yml` **không dùng** `gcloud builds submit`. Cloud Build mặc định stream log về terminal, và việc đó đòi identity gọi phải là Viewer/Owner của project. SA `github-actions@` theo least-privilege không có `roles/viewer`, nên build submit OK nhưng gcloud không tail được log → exit 1 (dù build có thể đã chạy xong). **Giải pháp đang dùng:** build image thẳng trên GitHub runner bằng `docker build` + `docker push` (nhanh hơn, rẻ hơn, ít quyền hơn). Nếu vì lý do nào đó bạn buộc phải dùng Cloud Build, thêm flag `--suppress-logs` (hoặc cấp SA `roles/viewer` — không khuyến khích).

---

## Future improvements

- [ ] Add Slack/Discord notification trên deploy success/fail
- [ ] Add visual regression (Percy/Chromatic) cho Flutter web
- [ ] Migrate secrets sang Google Secret Manager (audit log tốt hơn)
- [ ] Cache Docker layers giữa CI runs (đã có `cache-from: gha`)
- [ ] Add E2E test job chạy Playwright sau preview deploy
