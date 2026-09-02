# AnMates — MVP 1 ngày lên k8s on-prem

**Ngày:** 2026-09-01
**Mục tiêu:** Chạy được `api` + `web` trên cụm k8s on-prem sẵn có, qua Cloudflare Tunnel,
trong một ngày làm việc. 1 môi trường production duy nhất — chưa có user thật.
**Thay thế:** bản đầy đủ nhiều tuần ở
`docs/superpowers/specs/2026-08-31-onprem-k8s-replatform-full-reference.md` (giữ làm tài liệu
tham khảo — config HAProxy/Vault/LGTM trong đó vẫn dùng lại được cho các repo infra sau này).

> ⚠️ **Vai trò của file này: RUNBOOK, không phải tự động hoá.** Máy chạy Claude Code không có
> SSH tới PC host và không có kubeconfig của cụm on-prem (chỉ có context `orbstack` local).
> **User tự chạy mọi lệnh `kubectl`/`helm` trên PC host** theo từng bước dưới đây, báo lại
> kết quả/lỗi để Claude Code debug tiếp. Phần Claude Code trực tiếp làm được (không cần cluster):
> sửa code Flutter/Go, viết Helm chart trong repo, viết workflow CI — tất cả nằm trong repo
> `AnMates` và các repo `infra-*`, không cần chạm cluster để viết.

---

## 0. Những gì đổi so với bản full-reference

| Bản full-reference (nhiều tuần) | Bản 1 ngày (hôm nay) | Vì sao cắt được |
|---|---|---|
| MetalLB + ingress-nginx + cert-manager + HAProxy + keepalived + Pi 4 | **cloudflared trỏ thẳng Service** | Không port-forward → không cần lớp edge nào cả. Cloudflare lo TLS |
| Harbor | **GHCR** | Free, không giới hạn 100 MB/layer (Harbor qua Cloudflare Tunnel thì bị chặn ngay ở layer Chromium ~350 MB) |
| Vault + External Secrets | `kubectl create secret` thủ công | Chưa có user thật, rủi ro thấp. Vault vào repo `infra-secrets` sau |
| MinIO + de-Firebase Storage | **Giữ Firebase Storage** | Không đổi luồng upload — xem §3 |
| Redis + bật `ws/redis_hub.go` | **`api` 1 replica**, hub in-memory | Đúng vì chỉ 1 replica; downtime vài giây lúc deploy chấp nhận được |
| namespace `anmates-dev` | Chỉ 1 namespace `anmates` | 1 môi trường production |
| LGTM (Mimir/Loki/Tempo) | `metrics-server` + Cloudflare Analytics + `kubectl logs` | Đủ biết app sống/chết và RAM còn bao nhiêu |
| `ai-venue-search` sidecar | **Tắt** (`AI_SEARCH_URL` rỗng) | Concierge tự disable, chat vẫn chạy. Bật lại khi có repo infra ổn định |
| Firebase Phone OTP | **Email OTP + Tester quick-login** | Xem §3 — phần lớn code đã có sẵn |
| local-path (tạm) | giữ nguyên, nâng Longhorn sau | Đủ cho 1 instance Postgres |

---

## 1. Kiến trúc

**Quyết định 2026-09-01 (đồng bộ với Cline/Jira PI-16): chỉ expose MỘT hostname public
(web). API không có hostname riêng — gọi qua nginx reverse-proxy nội bộ (CoreDNS), đúng kết
luận PI-16 "API giữ internal, chỉ UI ra ngoài".**

```
GitHub push (main)
   |
   v
GHA cloud runner: go vet/test -> flutter analyze/test/build web
   |                docker build+push -> ghcr.io/<owner>/anmates-{api,web}:<sha>
   |                (auth: GITHUB_TOKEN co san, khong can secret rieng)
   v
[thu cong] ssh host -> helm upgrade --install --set image.tag=<sha>
   |
   v
k8s on-prem (1 CP + 2 worker, da dung san)
   |
   +-- cloudflared x2 (outbound-only, ns cloudflare)
   |      <domain>  --> Service web  :80   (DUY NHAT 1 hostname public)
   |
   +-- ns anmates
   |      Deployment web x2  (nginx + Flutter build)
   |         nginx location /        -> serve SPA (khong doi)
   |         nginx location /api/    -> proxy_pass http://anmates-api:8080  (CoreDNS noi bo)
   |         nginx location /ws/     -> proxy_pass + Upgrade/Connection headers (WebSocket)
   |      Deployment api x1  (Go Fiber, KHONG co Service public) --> Deployment postgres:16 (1 pod, khong operator)
   |
   +-- local-path StorageClass
   +-- metrics-server
```

**Vì sao không cần sửa code Dart**: `api_client.dart` build `API_BASE_URL` = chính domain của
web app (không phải rỗng, không phải `api.<domain>`). Cùng origin → browser tự gửi REST lẫn
WebSocket (`wsUrl()` suy `wss://` từ `https://`) về đúng hostname `<domain>`; nginx trong pod
`web` bắt `/api/*` và `/ws/*` rồi proxy nội bộ tới Service `api` qua CoreDNS
(`anmates-api.anmates.svc.cluster.local:8080`). Chỉ đổi `nginx.conf` + giá trị build-arg,
không đụng `lib/services/api_client.dart`.

**Lợi ích phụ**: same-origin → không cần cấu hình CORS nữa; giảm 1 hostname phải quản lý trên
Cloudflare; API hoàn toàn không có bề mặt public trực tiếp.

Bên ngoài cụm (giữ nguyên, không đổi):
- **Firebase Storage** — ảnh onboarding, qua `signInAnonymously()`
- **Goong / TomTom / Foursquare** — API bên ngoài, không đổi

---

## 2. Ngân sách (allocatable 13.90 Gi)

| | Gi |
|---|---|
| local-path + metrics-server + cloudflared ×2 | 0.25 |
| Postgres 1 pod (không operator, không PgBouncer) | 0.60 |
| api ×1 | 0.35 |
| web ×2 | 0.13 |
| **Tổng** | **1.33** → headroom **~12.5 Gi** |

Đĩa: PG 15 GB + linh tinh 5 GB ≈ 20 GB. Không cần gắn thêm disk nếu root disk worker ≥ 40 GB
(kiểm tra ở H0).

---

## 3. Thay đổi code bắt buộc — Auth

### 3.1 Hiện trạng đã rà trong code (không phải suy đoán)

**Backend — đã có sẵn, không cần viết mới:**
- `services/auth.go`: `RequestEmailOTP` / `VerifyEmailOTP` chạy đầy đủ (migration `012_email_otp.sql`)
- `handlers/auth.go`: `DevLogin` — chính là "tester quick login không cần auth", gate bằng
  `cfg.DevMode` + `DevBypassSecret`. Route `/api/v1/auth/dev-login` chỉ đăng ký khi `DEV_MODE=true`

**Frontend — đã viết nhưng MỒ CÔI (không ai gọi tới):**
- `lib/views/auth/email_input_view.dart` + `email_otp_view.dart` — gọi đúng
  `AuthService().requestEmailOtp/verifyEmailOtp`, nhưng không nằm trong luồng điều hướng nào
- `AuthService().devLogin()` (dòng 107) — method đã có, chỉ chưa có nút UI gọi tới

**Đường vào production thật hiện tại** (đã trace):
```
splash_screen.dart --(chưa login)--> OnboardingView --(cuối)--> PhoneInputView (Firebase phone OTP)
```
`PhoneInputView` + `otp_view.dart` là nơi Firebase Auth thực sự nằm trong luồng chạy.

### 3.2 Việc cần làm (nhỏ, vì phần lớn đã có)

1. `onboarding_view.dart` dòng ~73: đổi `PhoneInputView` → `EmailInputView`
2. Thêm nút "Vào thử ngay (tester)" trên `EmailInputView` → gọi `AuthService().devLogin()`
   đã có sẵn. Ẩn sau long-press logo hoặc build flag — không lộ ra UI chính cho user thật
3. Xoá `phone_input_view.dart`, `otp_view.dart`, `auth_error_messages.dart`
4. `pubspec.yaml`: bỏ `firebase_auth_platform_interface`. **Giữ `firebase_auth`** (xem §3.3)
5. `values-prod.yaml`: `DEV_MODE=true` + `DEV_BYPASS_SECRET=<random 32 chars>`

### 3.3 Quyết định đã chốt — Firebase Storage

`storage_service.dart` dùng `FirebaseAuth.instance.signInAnonymously()` để qua rule Firebase
Storage khi user không có phiên Firebase (đúng trường hợp sau khi bỏ phone OTP).

**Quyết định: giữ `firebase_auth` package chỉ cho mục đích này.** Không swap sang MinIO trong
ngày 1 — đúng phạm vi yêu cầu (bỏ Auth/đăng nhập, không phải Storage), và việc này đã có kế
hoạch riêng trong bản full-reference (`services/storage.go` + MinIO). Package `firebase_core` +
`firebase_storage` + `firebase_auth` (chỉ dùng anonymous) ở lại; `firebase_options.dart` giữ
nguyên.

**Hệ quả**: pubspec **không** bỏ hết Firebase — chỉ bỏ 1 package
(`firebase_auth_platform_interface`) và xoá 2 view (`phone_input_view`, `otp_view`).

---

## 4. Chi tiết theo giờ

### H0 · 0:00–0:30 — Tiền đề
- Mua domain → nameserver về Cloudflare → zone `active`
- Cloudflare Zero Trust → Networks → Tunnels → Create tunnel → lưu **tunnel token**
- GitHub → Settings → Developer settings → PAT classic, scope `read:packages`
  (để cluster pull image từ GHCR)
- `kubectl get nodes` → 3 Ready · `lsblk` → xác nhận đủ chỗ (≥40 GB root/worker)
- Tạo `DEV_BYPASS_SECRET` ngẫu nhiên, lưu tạm

### H1 · 0:30–1:30 — Storage + Network + chứng minh đường đi
```bash
# repo infra-storage
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.31/deploy/local-path-storage.yaml
kubectl patch sc local-path -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# repo infra-observability (phần tối thiểu)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# neu cert self-signed trong cluster: them --kubelet-insecure-tls vao args

# repo infra-networking
kubectl create ns cloudflare
kubectl -n cloudflare create secret generic tunnel-token --from-literal=token=<TOKEN>
helm upgrade --install cloudflared ./charts/cloudflared -n cloudflare   # replicas: 2
```
Deploy `hello-world` nginx + Service. Cloudflare dashboard → Public Hostname:
`hello.<domain>` → `http://hello.default.svc.cluster.local:80`

🎯 **Cổng kiểm soát #1** — từ mạng 4G: `https://hello.<domain>` ra trang nginx.
Không xong trong 1 giờ → dừng lại debug, đừng đi tiếp.

### H2 · 1:30–2:15 — Database + seed

**Quyết định 2026-09-02**: không dùng CNPG operator + PgBouncer — quá nặng cho 1 instance,
chưa có user thật, `api` cũng chỉ 1 replica nên không cần connection pooling riêng. Dùng thẳng
1 `Deployment` postgres:16 + PVC — ít YAML hơn, không cần CRD/operator.

```bash
# repo infra-database (= anmates-infra), namespace anmates cần có trước (đẩy sớm từ H3)
kubectl create ns anmates
kubectl -n anmates create secret generic anmates-db-credentials \
  --from-literal=POSTGRES_USER=anmates \
  --from-literal=POSTGRES_PASSWORD=<random-strong-password>

kubectl apply -f environments/onprem/database/postgres.yaml   # Deployment + PVC 15Gi local-path + Service
kubectl -n anmates rollout status deploy/anmates-db
```
Migrations tự chạy khi `api` boot lần đầu (`pg_try_advisory_lock` đã có sẵn, an toàn).
DATABASE_URL cho secret `anmates-api` (H3):
`postgres://anmates:<password>@anmates-db.anmates.svc.cluster.local:5432/anmates?sslmode=disable`

**Seed tối thiểu** — không `pg_dump` từ Supabase (Discovery fetch quán live từ Goong API,
không phải từ DB, nên không cần data quán). Chỉ cần 1 tester account có sẵn:
```sql
-- seed.sql — chạy 1 lần sau khi migrations xong
INSERT INTO users (id, email, password_hash, name, onboarding_done, food_tags, vibe_tags, culture_tags)
VALUES ('00000000-0000-0000-0000-0000000000a1', 'tester@anmates.local', '',
        'Tester', true, '{bun,pho}', '{cafe}', '{}')
ON CONFLICT (id) DO NOTHING;

INSERT INTO wishlists (user_id, food_name, food_category)
VALUES ('00000000-0000-0000-0000-0000000000a1', 'Bún bò Huế', 'bun')
ON CONFLICT DO NOTHING;
```
(Tài khoản tester thật sự dùng để test thì bấm nút "Vào thử ngay" — tự tạo qua `DevLogin`,
không cần seed. `seed.sql` chỉ để có sẵn 1 profile xem nhanh mà không cần bấm gì.)

🎯 **Cổng kiểm soát #2**: `psql` vào được, `CREATE EXTENSION pgcrypto` OK.

### H3 · 2:15–3:45 — Code Auth (§3.2) + Helm chart app
Sửa code theo §3.2 (5 việc nhỏ).

Trong repo `AnMates` → `deploy/charts/anmates/`:
```
templates/{api,web}-{deployment,service}.yaml
values-prod.yaml
```
Điểm phải đúng:
- `image.repository: ghcr.io/<owner>/anmates-api` (+ `-web`), tag qua `--set`
- `imagePullSecrets: ghcr-pull`
- Probe: `/health` cho cả liveness + readiness
- `api.replicas: 1` — hub WS in-memory vẫn đúng khi chỉ 1 replica
- **`api` Service: `type: ClusterIP`, KHÔNG có Ingress/cloudflared route riêng** (§1)
- Env đè hardcode Cloud Run trong Dockerfile: `GOMAXPROCS=2`, `GOMEMLIMIT=1500MiB`
- `DEV_MODE=true`, `DEV_BYPASS_SECRET=<từ H0>`

`anmates_flutter/nginx.conf` thêm 2 block (Service name giả định `anmates-api`, sửa theo tên
thật trong chart):
```nginx
location /api/ {
    proxy_pass http://anmates-api.anmates.svc.cluster.local:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $remote_addr;
}
location /ws/ {
    proxy_pass http://anmates-api.anmates.svc.cluster.local:8080;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_read_timeout 3600s;   # chat giữ kết nối lâu
}
```

```bash
# ns anmates đã tạo ở H2 — lệnh dưới idempotent, bỏ qua nếu đã có
kubectl create ns anmates --dry-run=client -o yaml | kubectl apply -f -
kubectl -n anmates create secret docker-registry ghcr-pull \
  --docker-server=ghcr.io --docker-username=<gh-user> --docker-password=<PAT>
kubectl -n anmates create secret generic anmates-api \
  --from-literal=DATABASE_URL=... --from-literal=JWT_SECRET=... \
  --from-literal=FIREBASE_WEB_API_KEY=... --from-literal=GOONG_API_KEY=... \
  --from-literal=FOURSQUARE_KEY=... --from-literal=SMTP_PASSWORD=... \
  --from-literal=DEV_BYPASS_SECRET=...
```

### H4 · 3:45–4:30 — CI workflow → GHCR
`.github/workflows/ci-build-push.yml`:
```yaml
on: { push: { branches: [main] } }
permissions: { contents: read, packages: write }
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: cd anmates-api && go vet ./... && go test $(go list ./... | grep -v /smoke$)
      - uses: subosito/flutter-action@v2
      - run: cd anmates_flutter && flutter pub get && flutter analyze --no-fatal-infos && flutter test
      - uses: docker/login-action@v3
        with: { registry: ghcr.io, username: ${{ github.actor }}, password: ${{ secrets.GITHUB_TOKEN }} }
      - uses: docker/build-push-action@v6      # api
        with:
          context: ./anmates-api
          push: true
          tags: ghcr.io/${{ github.repository_owner }}/anmates-api:${{ github.sha }}
      - uses: docker/build-push-action@v6      # web
        with:
          context: ./anmates_flutter
          push: true
          build-args: |
            API_BASE_URL=https://<domain>
            GOONG_MAPTILES_KEY=${{ secrets.GOONG_MAPTILES_KEY }}
          tags: ghcr.io/${{ github.repository_owner }}/anmates-web:${{ github.sha }}
      - run: echo "::notice::helm upgrade --install anmates ./deploy/charts/anmates -n anmates -f values-prod.yaml --set image.tag=${{ github.sha }}"
```
Chỉ 1 GH secret: `GOONG_MAPTILES_KEY`. Registry auth dùng `GITHUB_TOKEN` sẵn có.

### H5 · 4:30–5:15 — Deploy + health check
```bash
helm upgrade --install anmates ./deploy/charts/anmates \
  -n anmates -f values-prod.yaml --set image.tag=<SHA> --atomic --wait --timeout 10m

kubectl -n anmates get pods
kubectl -n anmates logs -l app=api --tail=50
kubectl top pods -n anmates

kubectl -n anmates exec -it deploy/anmates-api -- psql "$DATABASE_URL" -f /seed.sql   # hoac chay tay tu host
```
Cloudflare → thêm **1** Public Hostname: `<domain>` → Service `web`. **Không tạo
`api.<domain>`** — API chỉ truy cập được qua nginx proxy nội bộ (§1).

### H6 · 5:15–6:15 — Verify E2E
🎯 **Cổng kiểm soát cuối** — từ mạng 4G:
- `https://<domain>` load Flutter web
- `https://<domain>/api/v1/health` → 200 (qua nginx proxy, không có hostname `api.<domain>` riêng)
- Bấm "Vào thử ngay" → `DevLogin` tạo tài khoản, vào thẳng app
- Đăng ký qua Email OTP thật (email nhận được code)
- WebSocket chat gửi/nhận qua 2 replica web (không ảnh hưởng vì chat qua api 1 replica)
- Upload ảnh onboarding → Firebase Storage vẫn nhận

### H6:15–8:00 — Đệm
~1h45 dự phòng — thực tế sẽ dùng vào cloudflared config, probe timeout, hoặc build lỗi lần đầu.

---

## 5. Rủi ro chấp nhận có ý thức

| | |
|---|---|
| 🔴 Không backup | Làm ngay trong tuần: `pg_dump` CronJob → đĩa host, rồi offsite |
| 🟠 "Tester quick login" mở trong production | Ẩn sau gesture, `DEV_BYPASS_SECRET` random dài. Tắt (`DEV_MODE=false`) ngay khi có user thật |
| 🟠 `api` 1 replica → downtime vài giây lúc deploy | Chấp nhận, chưa có user thật |
| 🟠 local-path → PVC ghim vào node | Node đó chết là PG kẹt. `infra-storage` đổi Longhorn sau |
| 🟠 Secret trần trong k8s + GH secrets | `infra-secrets` (Vault) làm sau |
| 🟡 Vẫn phụ thuộc Firebase Storage (không phải Auth) | Đúng chủ đích đã chốt ở §3.3 |

## 6. Lộ trình sau ngày 1 (theo thứ tự giá trị)

1. `pg_dump` CronJob + đẩy offsite — rủi ro cao nhất còn lại
2. `infra-observability`: Loki + Grafana (bỏ Mimir/Tempo lúc đầu)
3. `infra-storage`: local-path → Longhorn
4. `infra-secrets`: Vault + ESO, tắt `DEV_MODE`
5. Redis + bật `ws/redis_hub.go` → 2 replica `api`, rolling update không downtime
6. `ai-venue-search` (Ollama trên host + repo riêng)
7. De-Firebase Storage: `services/storage.go` + MinIO (theo bản full-reference §10.3)
