# AnMates — Re-platform lên Kubernetes on-prem

**Ngày:** 2026-08-31
**Trạng thái:** Design đã duyệt — sẵn sàng viết implementation plan
**Tác giả:** Claude + Thanh Nguyen (7 vòng brainstorm)

---

## 0. Tóm tắt điều hành

Chuyển toàn bộ AnMates từ Firebase Hosting + Cloud Run + Supabase sang một cụm Kubernetes
on-prem chạy trên **một máy PC duy nhất** (KVM/libvirt), với Raspberry Pi 4 làm node edge thứ hai.
Giữ nguyên GitHub + GitHub Actions. Loại bỏ hoàn toàn phụ thuộc Firebase (Auth + Storage).

**Mục tiêu vận hành:** ~50 RPS ở giai đoạn beta MVP. Không phải hệ thống HA thật —
máy vật lý là SPOF; giá trị nằm ở quyền kiểm soát, chi phí cloud = 0, và học vận hành on-prem.

### Quyết định đã khoá

| Hạng mục | Quyết định |
|---|---|
| Cluster | **MVP**: 1 control-plane (4 GB / 2 vCPU) + 2 worker (8 GB / 4 vCPU) trên KVM, giữ mạng `10.10.10.0/24`. Worker #3 thêm khi bật observability đầy đủ (§3.2) |
| Edge | Cloudflare → HAProxy ×2 (Pi 4 + VM bridge) + VIP keepalived → MetalLB → ingress-nginx |
| Đường public | IP thật + Cloudflare proxy, origin port `8443`; Cloudflare Tunnel làm dự phòng |
| Registry | **Harbor** (Trivy bật, retention 5 tag/repo) |
| Secrets | **HashiCorp Vault chạy container trên host**, không trong k8s |
| CI/CD | GHA cloud runner (test) + self-hosted runner trên host (build + `helm upgrade`) |
| GHA secrets | **Zero** — xác thực Vault bằng GitHub OIDC |
| Storage | Longhorn `replica: 1` + MinIO (thay Firebase Storage) |
| Database | CloudNativePG + PgBouncer |
| Auth | **Email OTP** (SMTP) — bỏ hẳn Firebase Phone OTP |
| LLM | Ollama **native trên host** với GPU, không passthrough |
| Observability | Grafana LGTM: Mimir + Loki + Tempo + Alloy + Grafana |
| Môi trường | 2 namespace: `anmates` (prod) + `anmates-dev` |

---

## 1. Hiện trạng (điểm xuất phát)

| Thành phần | Hiện tại |
|---|---|
| UI | Flutter web → Firebase Hosting (`anmates-studio.web.app`) |
| API | Go Fiber → Cloud Run `asia-southeast1`, image ở Artifact Registry |
| AI sidecar | Python `ai-venue-search` → Cloud Run (prod dùng Pollinations); local dùng Ollama + Playwright/Chromium |
| DB | **Supabase** Postgres (`DATABASE_URL` là GH secret) |
| Storage | Flutter upload **thẳng** lên Firebase Storage (`lib/services/storage_service.dart`) |
| Auth | Firebase Phone OTP → Go verify qua identitytoolkit REST (chỉ cần Web API Key) |
| CI/CD | 7 workflow GH Actions, deploy qua WIF vào GCP |

### Chi tiết kỹ thuật quan trọng đã xác minh trong code

- `db/migrate.go` **đã có `pg_try_advisory_lock`** → nhiều replica boot đồng thời an toàn.
- Migrations chỉ cần extension **`pgcrypto`**. **Không dùng PostGIS** (PostGIS chỉ nằm trong
  `docs/meetup-map-master-plan.md`, chưa hiện thực) → image Postgres mặc định là đủ.
- `ws/redis_hub.go` tồn tại nhưng bị `//go:build ignore` → hub hiện **in-memory** → API
  hiện chỉ chạy đúng với **1 replica**.
- `models.User` đã có `Email` + `PasswordHash`; `FirebaseUID` nullable.
- Email OTP đã hiện thực đầy đủ (migration `012_email_otp.sql`, `services/email.go`,
  `handlers/auth.go`) — chỉ cần nâng lên thành đường đăng nhập chính.
- `storage_service.dart` dùng hack `signInAnonymously()` để lách Firebase Storage rules khi
  người dùng đăng nhập bằng email OTP → sẽ biến mất cùng Firebase.
- `API_BASE_URL` và `GOONG_MAPTILES_KEY` được nhúng lúc **compile** qua `--dart-define`
  → dev và prod hiện cần **hai image khác nhau**.

---

## 2. Kiến trúc đích

```
                                 Internet
                                    |
                   +----------------v-----------------+
                   | Cloudflare  (DNS, WAF, DDoS)     |  proxied
                   | user luon thay https://...:443   |
                   +----------------+-----------------+
                                    | origin :8443  (ne ISP chan 443)
                   +----------------v-----------------+
                   | Router ISP  <public-ip>          |
                   | forward 8443 -> 192.168.1.240    |
                   +----------------+-----------------+
                                    |
              +=====================v======================+
              |  VIP 192.168.1.240  (keepalived / VRRP)    |
              +--------------------+-----------------------+
              | HAProxy 1 - Pi 4   | HAProxy 2 - VM bridge |
              | .241  MASTER 110   | .242  BACKUP 100      |
              | phan cung RIENG    | tren PC host          |
              +====================+=======================+
                                    | -> 10.10.10.200:443
 ===================================v==================================
  PC host - Ubuntu 26.04 - Ultra 7 265K (20 nhan) - 32GB - RTX 5060 Ti 16GB
  +-- router/NAT gateway 10.10.10.1 - nftables - br0 (cho HAProxy2)
  +-- Ollama NATIVE + CUDA :11434            <- GPU khong passthrough
  +-- Vault container (systemd) :8200        <- doc lap voi cluster
  +-- GitHub self-hosted runner (--ephemeral) + buildx + helm
  +-- KVM/libvirt - net 10.10.10.0/24 (GIU NGUYEN)
       +--------------------------------------------------------------+
       | k8s - 1 control-plane (2GB) + 3 worker (8GB)                  |
       |                                                               |
       | MetalLB VIP 10.10.10.200 -> ingress-nginx (LoadBalancer)      |
       | cert-manager (DNS-01) - Longhorn (replica 1) - ESO            |
       | Harbor (registry)                                             |
       | Observability: Mimir + Loki + Tempo + Alloy + Grafana         |
       |                                                               |
       | ns anmates (prod):        ns anmates-dev:                     |
       |   web x2                    web x1                            |
       |   api x2 -> Redis           api x1 -> Redis                   |
       |   ai-venue-search x1        ai-venue-search x1                |
       |   CNPG + PgBouncer          CNPG (khong backup)               |
       |   MinIO (dung chung, bucket rieng)                            |
       +--------------------------------------------------------------+
                        ai-venue-search --> host Ollama 10.10.10.1:11434
```

---

## 3. Phân bổ tài nguyên

### 3.1 RAM — 32 GB, không overcommit

Không bao giờ overcommit RAM: node chạy etcd và Postgres mà bị host swap là hỏng dữ liệu.
KSM + virtio-balloon **nên bật** (thường thu lại 1.5–3 GB nhờ các VM Ubuntu giống nhau)
nhưng **không được tính vào ngân sách**.

**Layout MVP (giai đoạn hiện tại):**

| | vCPU | GB |
|---|---|---|
| Ubuntu + libvirt + nftables | — | 1.20 |
| Ollama native (weights nằm trong 16 GB VRAM) | — | 1.50 |
| CI runner (`docker build COPY` + `helm`) — điển hình 1.5 GB, `systemd MemoryMax=2G` mượn phần dôi từ slack | — | 1.50 |
| Vault container | — | 0.25 |
| HAProxy2 VM | 2 | 0.50 |
| slack / page cache cho đĩa VM | — | 1.05 |
| **control-plane × 1** | 2 | **4.00** |
| **worker × 2** | 4 / node | **16.00** |
| **Tổng dùng** | 12 vCPU trên 20 nhân — **không overcommit CPU** | **26.00** |
| **Dôi ra trên host** | | **6.00** |

**Allocatable cho workload:** mỗi node tốn ~1.05 Gi (OS + kubelet + CNI + Longhorn agent +
Alloy) → `2 × (8 − 1.05)` = **13.90 Gi**.

Control-plane 4 GB là rộng rãi (apiserver + etcd + cm/sched/kubelet + OS ≈ 1.5–1.8 Gi) —
không cần theo dõi sát như phương án 2 GB đã cân nhắc trước đó.

### 3.2 Ngân sách workload — theo phase

Với 2 worker, ngân sách **vừa cho phần lõi nhưng chật khi bật observability đầy đủ**.
Đây là điều cần biết trước, không phải phát hiện lúc pod bị `Pending`.

| Nhóm | Chi tiết | Gi |
|---|---|---|
| Platform | Longhorn 2×0.35 · ingress-nginx ×2 0.30 · MetalLB 0.10 · cert-manager 0.15 · ESO 0.15 · kube-state-metrics 0.15 | **1.55** |
| Registry | Harbor (core, portal, jobservice, registry, redis, pg, trivy) | **1.80** |
| Data | CNPG operator 0.20 · PG prod 1.50 · PgBouncer 0.10 · PG dev 0.50 · MinIO 1.00 · Redis ×2 0.35 | **3.65** |
| `anmates` | api ×2 0.70 · web ×2 0.14 · ai-venue-search 1.50 | **2.34** |
| `anmates-dev` | api ×1 0.35 · web ×1 0.07 · **ai-venue-search `replicas: 0`** | **0.42** |
| Observability P8a | Mimir 1.80 · Loki 0.50 · Alloy 3×0.15 · Grafana 0.25 | **3.00** |
| Observability P8b | Tempo | **0.50** |

| Mốc | Tổng | Headroom (trên 13.90 Gi) | |
|---|---|---|---|
| **P0–P7** (lõi, chưa observability) | 9.76 | **4.14 Gi** | ✅ thoải mái |
| **+ P8a** (metrics + logs) | 12.76 | **1.14 Gi** | ⚠️ mỏng |
| **+ P8b** (traces) | 13.26 | **0.64 Gi** | ❌ quá mỏng |

#### Khi nào thêm worker thứ 3

**Điều kiện kích hoạt không phải là số user, mà là bật observability đầy đủ (P8a/P8b).**

Host còn **dôi 6 GB** → thêm worker #3 là thao tác **tạo thêm một VM**, không phải reshape
lại cụm đang chạy. Ba lựa chọn khi tới P8:

| Lựa chọn | Thu về | Đánh đổi |
|---|---|---|
| **Thêm worker #3 (5–6 GB)** ⭐ | +3.95–4.95 Gi | Dùng nốt phần dôi của host; cần thêm ~60 GB đĩa |
| Đổi Mimir → VictoriaMetrics single | +0.80 Gi | Vẫn PromQL, chỉ thay datasource — nhưng lệch khỏi chuẩn LGTM đã chọn |
| Hoãn P8b (traces) | +0.50 Gi | Chỉ trì hoãn, không giải quyết |

`anmates-dev` chạy `ai-venue-search` với `replicas: 0`, scale tay lên 1 khi cần test
tính năng AI (Chromium + Playwright tốn 1.2 Gi — quá đắt để nằm không ở giai đoạn MVP).
Bật thường trực tốn 1.20 Gi và làm P8a chỉ còn 0 headroom.

### 3.3 Đĩa — **dưới 200 GB trống** (ràng buộc siết nhất sau RAM)

Ba điều chỉnh bắt buộc do ràng buộc này:

1. **Longhorn `replicaCount: 1`.** Trên một NVMe vật lý duy nhất, 2 replica chỉ chống được
   hỏng đĩa *ảo*, không chống được hỏng NVMe thật. Bảo vệ thật = CNPG backup → MinIO → **offsite**.
2. **Retention observability 7 ngày** ở MVP (nâng lên 14–30 ngày khi thêm worker #3 và đĩa).
3. **Harbor giữ 5 tag/repo + GC hằng tuần.** Đây là mục quan trọng nhất: image
   `ai-venue-search` chứa Chromium ~2 GB. May mắn là `ai-venue-search/Dockerfile` đã cài
   Playwright **trước** khi `COPY` code → layer nặng được chia sẻ giữa các tag, 10 tag chỉ
   tốn ≈ 2 GB base + 10 × ~50 MB.

| PVC | Size (replica 1) |
|---|---|
| MinIO (Loki/Mimir blocks 7d + ảnh user + PG backup) | 40 GB |
| Harbor (image layers, dev + prod) | 30 GB |
| PG prod | 15 GB |
| PG dev | 8 GB |
| Grafana + linh tinh | 7 GB |
| **Tổng Longhorn** | **100 GB** |

**Bố trí đĩa vật lý:** mỗi worker gắn một đĩa thứ hai **60 GB** (tổng 120 GB dung lượng
Longhorn cho 100 GB PVC — dư biên để scheduler còn chỗ đặt volume). Dùng **qcow2 thin
provisioning**: dung lượng cấp phát ≠ dung lượng chiếm thật, nên 2 × 60 GB chỉ tốn đúng
phần đang dùng.

**Kế toán đĩa:**

| | GB |
|---|---|
| Longhorn data disk (2 × 60, thin) | 120 |
| VM root mới: HAProxy2 8 | 8 |
| Thu hồi: 2 CP VM bị loại (3 CP → 1 CP) | −50 |
| **Net cấp phát mới** | **≈ 78** |

Còn biên khá rộng trong ngân sách < 200 GB. `disk usage > 75%` vẫn phải là alert nghiêm trọng.

> ⚠️ Khi thêm worker #3 ở P8, cần thêm ~25 GB root + ~60 GB data disk. Kiểm tra đĩa còn
> trống **trước** khi bật observability, không phải trong lúc bật.

**Kiểm tra bắt buộc ở P0:** `lsblk`, `df -h`, `virsh vol-list`.

---

## 4. Mạng & tầng Edge

### 4.1 Vì sao kiến trúc này

Ràng buộc: **ISP chặn inbound 80/443**. Cloudflare khi bật proxy chấp nhận origin ở port khác:
HTTPS `443, 2053, 2083, 2087, 2096, 8443` · HTTP `80, 8080, 8880, 2052, 2082, 2086, 2095`.
Ta dùng **8443**. User vẫn luôn gõ `https://anmates.vn` (Cloudflare nghe :443); chỉ chặng
Cloudflare → nhà đi cổng 8443.

Lợi ích: public IP thật · URL sạch · WAF + chống DDoS miễn phí · **IP nhà không lộ ra Internet**.

### 4.2 HAProxy chạy L7, không phải TCP passthrough

Nếu chỉ passthrough TCP thì tầng edge gần như vô nghĩa (MetalLB đã tự lo failover node).
Chạy `mode http` để nó thật sự có giá trị: health-check, trang bảo trì, lọc IP, log, tách
routing khỏi cluster.

**Cert ở HAProxy: Cloudflare Origin CA** — miễn phí, hạn **15 năm**, cấp một lần rồi thôi.
Không phải đồng bộ cert từ cluster xuống 2 node edge. Cloudflare chạy **Full (strict)**.
cert-manager + Let's Encrypt (DNS-01) vẫn giữ nhưng chỉ phục vụ hostname **nội bộ**
(Harbor, Grafana, Longhorn UI).

Cert Origin CA không được trình duyệt tin — đúng thiết kế, vì nó chỉ nằm giữa Cloudflare
và origin. Truy cập LAN dùng cert LE trên ingress.

### 4.3 keepalived — Pi làm MASTER

| Node | Priority | State |
|---|---|---|
| Pi 4 (`192.168.1.241`) | 110 | MASTER |
| HAProxy2 VM (`192.168.1.242`) | 100 | BACKUP |

**Pi làm MASTER vì nó độc lập với PC host.** Sự cố thường gặp nhất là host reboot (update
kernel, đổi VM, cúp điện) — lúc đó HAProxy2 chết theo, Pi giữ VIP và serve **trang bảo trì**
thay vì để user thấy lỗi 52x của Cloudflare. Đó chính xác là hành vi mong muốn.

`vrrp_script chk_haproxy`: `killall -0 haproxy`, `interval 2`, `weight -20` → VIP chuyển
khi haproxy chết cục bộ.

> VRRP dùng multicast `224.0.0.18`. Vài switch/AP dân dụng chặn multicast → nếu VIP không
> chuyển được, đổi sang `unicast_peer`.

### 4.4 Định tuyến tới MetalLB VIP

HAProxy nằm ở LAN `192.168.1.0/24`, MetalLB VIP ở `10.10.10.0/24` sau lưng PC host:

| Node | Cách tới `10.10.10.200` |
|---|---|
| HAProxy2 (VM) | **Dual-homed**: NIC1 `br0` → LAN, NIC2 → libvirt net `10.10.10.0/24`. Tới thẳng. |
| Pi 4 | Static route: `ip route add 10.10.10.0/24 via 192.168.1.50` |

PC host nftables phải cho forward và **không SNAT** → giữ nguyên client IP.

### 4.5 Chuỗi client IP thật

```
User IP
  -> Cloudflare            (dat CF-Connecting-IP)
  -> HAProxy               (doc CF-Connecting-IP, ghi X-Forwarded-For)
  -> ingress-nginx         (use-forwarded-headers, proxy-real-ip-cidr = .241,.242)
  -> app
```

ingress-nginx: `externalTrafficPolicy: Local` + ≥2 replica trải node.

### 4.6 Đường dự phòng

`cloudflared` vẫn deploy trong cluster, trỏ vào VIP `10.10.10.200`. Nếu port-forward hỏng /
ISP đổi chính sách / CGNAT → bật record tunnel trên Cloudflare là chuyển đường ngay, không
cần sửa gì ở nhà.

**Kiểm tra CGNAT ở P5** (nếu WAN hiện `100.64.x.x`–`100.127.x.x` thì port-forward bất khả thi
→ dùng tunnel, hoặc VPS + WireGuard):

```bash
curl -s ifconfig.me                    # IP cong cong that
# so voi IP WAN tren trang admin router
sudo nc -l -p 8443                     # tren host
nc -vz <public-ip> 8443                # tu mang 4G
```

---

## 5. Secrets — Vault trên host

### 5.1 Vì sao trên host, không trong k8s

**Kho secret không nên phụ thuộc vào thứ mà nó dùng để bootstrap.**

| | Trên host (chọn) | Trong k8s |
|---|---|---|
| RAM | 0.25 GB | 0.75 Gi (raft 3 replica) |
| Phụ thuộc vòng | không — cluster chết vẫn deploy lại được | có: Vault cần Longhorn cần cluster; ESO cần Vault |
| Unseal | 1 lần sau host reboot | sau mỗi lần cluster/node restart |

Chạy container qua systemd, storage backend `file` trên đĩa host, listen `10.10.10.1:8200`.

### 5.2 GitHub Actions zero-secret — xác thực bằng OIDC

Self-hosted runner **vẫn nhận được OIDC token** của GitHub. Workflow không chứa `secrets.*` nào:

```yaml
permissions:
  id-token: write          # thu duy nhat can
env:
  VAULT_ADDR: http://10.10.10.1:8200
  REGISTRY: harbor.anmates.vn      # vars, khong phai secrets
```

```bash
JWT=$(curl -s "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=vault" \
      -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" | jq -r .value)
export VAULT_TOKEN=$(vault write -field=token auth/jwt/login role=anmates-ci jwt="$JWT")
```

Vault khoá chặt bằng `bound_claims` (repository + ref), `token_ttl 20m`.
→ **Không có credential dài hạn ở bất cứ đâu.** Repo bị lộ cũng không lấy được gì.

### 5.3 Ba đường tiêu thụ secret

| Ai | Auth method | Lấy gì |
|---|---|---|
| CI runner | **JWT/OIDC** (per-job, 20 phút) | Harbor creds, kubeconfig token |
| ESO trong cluster | **Kubernetes auth** (Vault gọi ngược TokenReview tới apiserver) | Toàn bộ secret app → sinh k8s `Secret` |
| Người vận hành | userpass + MFA | vận hành thủ công |

### 5.4 Cache trên runner

**Vault Agent** chạy systemd trên host: auto-auth (AppRole, `secret_id` response-wrapped,
chỉ root đọc) + template render ra **tmpfs** `/run/anmates/`, bật `cache` để không round-trip
mỗi lần. Runner chỉ đọc file.

### 5.5 Layout KV v2

```
anmates/prod/api      JWT_SECRET, SMTP_*, GOONG_API_KEY, GOONG_MAPTILES_KEY,
                      TOMTOM_API_KEY, FOURSQUARE_KEY
anmates/prod/minio    ACCESS_KEY, SECRET_KEY
anmates/prod/db       (CNPG tu sinh, dong bo nguoc len Vault)
anmates/dev/...       tuong tu
platform/harbor       robot account cho CI
platform/cloudflare   API token cho cert-manager DNS-01 + DDNS
```

### 5.6 Runbook unseal

Host reboot → Vault sealed → ESO ngừng sync. **App đang chạy vẫn sống** (k8s `Secret` đã tồn
tại trên etcd); chỉ pod mới / đổi secret bị kẹt. Unseal thủ công, key giữ offline
(password manager). Không tự động hoá unseal bằng file trên host trừ khi chấp nhận đánh đổi.

---

## 6. Cluster platform

| Thành phần | Cấu hình |
|---|---|
| MetalLB | L2 mode, pool `10.10.10.200-10.10.10.220` |
| ingress-nginx | `type: LoadBalancer` → VIP `.200`, `externalTrafficPolicy: Local`, 2 replica, `use-forwarded-headers`, `proxy-real-ip-cidr` = IP 2 node HAProxy |
| cert-manager | ClusterIssuer Let's Encrypt **DNS-01 qua Cloudflare** (HTTP-01 không dùng được vì port 80 bị chặn) — chỉ cấp cho hostname nội bộ |
| Longhorn | `replicaCount: 1`, disk thứ hai trên mỗi worker |
| Harbor | Trivy bật, retention 5 tag/repo, GC hằng tuần (cron), hostname `harbor.anmates.vn` → VIP |
| ESO | `ClusterSecretStore` → Vault trên host |

Cả LAN lẫn public đi chung một đường vào (`VIP .200`) → khi debug chỉ cần một lệnh
`curl -H 'Host: api.anmates.vn' https://10.10.10.200` từ host là đi **đúng** đường prod.

---

## 7. Data plane

| Thành phần | Cấu hình |
|---|---|
| **CloudNativePG** | 1 instance/môi trường. Prod: barman backup → MinIO, PITR. Dev: không backup. Chỉ cần `pgcrypto`. |
| **PgBouncer** | Transaction pooling. Ở 50 RPS chưa bắt buộc (≈150 QPS) nhưng rẻ (0.1 Gi) và đúng chuẩn khi api có nhiều replica. |
| **MinIO** | Dùng chung, bucket riêng: `anmates-photos`, `anmates-photos-dev`, `anmates-backups`, `loki`, `mimir`, `tempo`. |
| **Redis** | Một instance/môi trường, phục vụ WS hub (bắt buộc để api chạy 2 replica). |

---

## 8. Hai môi trường

Một Helm chart, hai values file.

| | `anmates` (prod) | `anmates-dev` |
|---|---|---|
| Host | `anmates.vn` · `api.anmates.vn` | `dev.anmates.vn` · `api-dev.anmates.vn` |
| Trigger | push `main` → `cd.helm.yml` | PR mở/cập nhật → `ci.*.yml` (giữ mô hình R-005) |
| Replicas | api 2 · web 2 · ai 1 | api 1 · web 1 · ai 1 |
| Vault path | `anmates/prod/*` | `anmates/dev/*` |
| PG | CNPG riêng + backup | CNPG riêng, không backup |
| MinIO bucket | `anmates-photos` | `anmates-photos-dev` |

Ba thứ **bắt buộc** với ngân sách RAM này:

- **`ResourceQuota`** mỗi namespace — dev không được lấn prod
- **`PriorityClass`**: prod `1000` / dev `100` → khi node bí RAM, kubelet evict dev trước
- **`NetworkPolicy`** default-deny, chặn ngang giữa hai namespace

---

## 9. CI/CD

```
git push
 |
 +-- GHA cloud runner  (mien phi, 16GB)
 |     go vet + go test + govulncheck
 |     flutter analyze + flutter test
 |     flutter build web --release        <- KHONG con secret nao (xem 10.1)
 |     pytest (ai-venue-search)
 |     trivy fs
 |     upload artifact: build/web, api binary
 |
 +-- job deploy - runs-on: [self-hosted, anmates-host]
       vault login (OIDC)  -> Harbor creds + kubeconfig
       download artifact   -> docker build (chi COPY) -> push harbor
       helm upgrade --install anmates deploy/charts/anmates -n anmates \
            -f values.prod.yaml --set image.tag=$SHA --atomic --wait --timeout 10m
       smoke: curl https://api.anmates.vn/health
```

`--atomic` tự rollback khi fail. Thủ công: `helm rollback anmates <rev>`.

### Bảo mật bắt buộc

Runner chạy trên chính máy gateway — máy đặc quyền nhất trong hệ thống:

- Job deploy **chỉ chạy trên `push` vào `main`**
- **Không bao giờ** dùng `pull_request_target`
- PR từ fork **không** chạy build
- Runner mode `--ephemeral`
- GitHub Environment `production` có **required reviewer**
- `systemd MemoryMax=2G` cho runner service

### Không dùng GitOps — bù lại bằng gì

Không có Argo CD → cluster có thể drift âm thầm khi ai đó `kubectl` bằng tay.
Bù: chart trong git là nguồn sự thật + cron `helm diff` hằng đêm cảnh báo lệch.

---

## 10. Thay đổi code bắt buộc

### 10.1 Flutter — runtime config (quan trọng nhất)

**Vấn đề hiện tại:** `API_BASE_URL` và `GOONG_MAPTILES_KEY` nhúng lúc compile qua
`--dart-define` → (a) dev và prod cần **hai image khác nhau**, không promote được;
(b) `flutter build web` phải chạy trên host runner với secret → tốn 4 GB RAM.

**Giải pháp:** nginx sinh `/config.js` từ env lúc container khởi động; Flutter đọc
`window.APP_CONFIG` (fallback `String.fromEnvironment` cho dev local).

| | Trước | Sau |
|---|---|---|
| Flutter build | trên host runner, đỉnh 4 GB | **trên GHA cloud runner** (miễn phí, 16 GB) |
| Secret lúc build | có (`GOONG_MAPTILES_KEY`) | **không có** |
| Image | 1 image / môi trường | **1 image chạy cả dev lẫn prod** |
| Host runner | build Flutter + Go + docker | tải artifact → `docker build COPY` → `helm` → ~1.5 GB |

Đây là nguồn của 2.5 GB RAM đã được tái phân bổ cho worker node.

**File**: mới `lib/config.dart`; sửa `lib/services/api_client.dart`, `lib/views/map/map_view.dart`
(`kGoongMaptilesKey`), `web/index.html`, `anmates_flutter/Dockerfile` + entrypoint nginx.

### 10.2 Bỏ Firebase — Auth

**Quyết định: bỏ đăng nhập bằng SĐT, thay hoàn toàn bằng Email OTP.**

Go:
- Gỡ `VerifyFirebaseToken` (`services/auth.go`), handler `/auth/firebase` (`handlers/auth.go`),
  config `FIREBASE_WEB_API_KEY`
- Email OTP thành đường đăng nhập chính (hiện chỉ bật khi có `SMTP_HOST` + `SMTP_USERNAME`,
  hoặc trong `DEV_MODE`)
- Giữ cột `users.firebase_uid` (nullable) cho row cũ; giữ `users.phone` như trường hồ sơ tuỳ chọn
- Migration mới: partial unique index trên `email WHERE email IS NOT NULL`

Flutter:
- `phone_input_view.dart` / `otp_view.dart` / `auth_service.dart` → email OTP
- Xoá `lib/firebase_options.dart`, `Firebase.initializeApp` trong `main.dart`,
  script tag firebase trong `web/index.html`
- `pubspec.yaml` bỏ `firebase_core`, `firebase_auth`, `firebase_auth_platform_interface`,
  `firebase_storage`

**Hệ quả dữ liệu:** row `users` chỉ có `phone`, không có `email` sẽ không đăng nhập được nữa.
Đếm số row đó ở P4 rồi quyết (ở quy mô beta nhiều khả năng chỉ là vài tài khoản test).

**Lợi ích phụ:** R-001 (gotcha `127.0.0.1` vs `localhost` do reCAPTCHA) **hết hiệu lực**.

### 10.3 Bỏ Firebase — Storage → MinIO

Go:
- Mới `services/storage.go` dùng `minio-go/v7`
- Mới `handlers/upload.go`: `POST /api/v1/uploads/photo` (multipart, JWT-gated) → lưu MinIO →
  trả URL `https://cdn.anmates.vn/...`

Flutter:
- Viết lại `lib/services/storage_service.dart`: upload qua API thay vì Firebase Storage.
  Xoá hack `signInAnonymously()`.

Di trú: script liệt kê object trên Firebase Storage → tải về → upload MinIO →
`UPDATE users.avatar_url` + `UPDATE user_photos.url`.

### 10.4 WebSocket hub → Redis

Bật `ws/redis_hub.go` (gỡ `//go:build ignore`), `go get github.com/redis/go-redis/v9`,
wire `cfg.RedisURL`. **Bắt buộc** để api chạy 2 replica — nếu không thì kẹt 1 replica,
mất rolling update không downtime.

### 10.5 AI sidecar → Ollama trên host

`LLM_BASE_URL=http://10.10.10.1:11434/v1` qua `Service` + `Endpoints` tĩnh trỏ IP host.

Lý do không passthrough GPU: VFIO sẽ *lấy mất* GPU của host, và fragile với card 50-series.
Repo đã có tiền lệ `docker-compose.host-ollama.yml`. Đánh đổi: có một dependency ngoài k8s
— ghi rõ trong runbook.

### 10.6 Dockerfile Go

Bỏ `ENV GOMAXPROCS=1 GOMEMLIMIT=900MiB` hardcode (đó là tuning cho Cloud Run 1 vCPU / 1 GB)
→ set qua k8s env theo resource limit thật.

### 10.7 Repo

- Thêm `deploy/charts/anmates` (umbrella: api, web, ai-venue-search) + `deploy/charts/platform`
- Workflow mới `cd.helm.yml`
- Xoá `firebase.json`, `.firebaserc`, và 3 workflow `cd.*` cũ

---

## 11. Observability — Grafana LGTM

| Tín hiệu | Công cụ | RAM | Ghi chú |
|---|---|---|---|
| Metrics | **Mimir** monolithic → MinIO | 1.80 Gi | Nếu quá nặng, đổi vmsingle chỉ là thay datasource (PromQL giữ nguyên) |
| Logs | **Loki** SingleBinary → MinIO | 0.50 Gi | |
| Traces | **Tempo** single-binary → MinIO | 0.50 Gi | **P8b** — cần instrument code trước |
| Agent | **Alloy** DaemonSet (4 node) + binary trên Pi / HAProxy2 / host | 0.15/node | arm64 có sẵn cho Pi |
| Dashboard + Alert | **Grafana** (dùng Grafana Alerting, **bỏ Alertmanager**) | 0.25 Gi | bớt một component |

> **Không dùng OpenSearch cho logs.** JVM heap 2 Gi + off-heap ≈ 3–4 Gi, gấp **6–8× Loki**.
> Với 20.85 Gi allocatable thì một mình nó ăn 1/5 cluster. Loki cũng tích hợp thẳng Grafana
> và dùng chung MinIO đã có.

### 11.1 HAProxy — cả hai node

- **Metrics**: HAProxy có Prometheus exporter **built-in**, không cần sidecar:
  ```
  frontend fe_metrics
      bind 0.0.0.0:8405
      http-request use-service prometheus-exporter if { path /metrics }
  ```
  Alloy scrape qua `static_configs` (target ngoài cluster). Dashboard Grafana **ID 12693**.
- **Logs**: HAProxy → rsyslog → Alloy tail → Loki. Log format có timing đầy đủ
  `%Tq/%Tw/%Tc/%Tr/%Ta` + `CF-Ray` + `CF-Connecting-IP` → truy được một request từ
  Cloudflare xuống tận pod.
- **keepalived**: `keepalived_exporter` → alert khi VIP flap hoặc không node nào giữ VIP.
- **node_exporter** trên Pi, HAProxy2 và PC host.
- **`nvidia_gpu_exporter`** trên host → VRAM/utilization của Ollama.

### 11.2 Cluster

kube-state-metrics + node_exporter + cAdvisor. Longhorn, CNPG, ingress-nginx, MinIO, Harbor
đều expose Prometheus sẵn — chỉ cần scrape config, không tốn thêm pod.

### 11.3 Traces (P8b) — cần sửa code

Go Fiber và sidecar Python hiện **chưa có instrumentation nào**. Traces không phải việc
"cài thêm chart":

- Go: `otelfiber` middleware + OTLP exporter → Tempo
- Python: `opentelemetry-instrumentation-fastapi`
- HAProxy: `unique-id-format` sinh `X-Request-ID`, app log kèm → correlate log ↔ trace

### 11.4 Alert tối thiểu (Grafana → Telegram)

| Alert | Ngưỡng |
|---|---|
| **Node memory** | > 90% — quan trọng nhất với ngân sách này |
| **Disk usage** | > 75% — quan trọng nhất với ràng buộc < 200 GB |
| kube-apiserver RSS | > 800 Mi (CP chỉ có 2 GB) |
| VIP không ai giữ / flap | ngay lập tức |
| HAProxy backend down | > 30s |
| ingress 5xx rate | > 1% |
| CNPG backup fail | ngay lập tức |
| Vault sealed | ngay lập tức |
| Cert hết hạn | < 14 ngày |
| Ollama không phản hồi | > 60s |

---

## 12. Di trú dữ liệu

| Bước | Nội dung |
|---|---|
| **DB** | `pg_dump` từ **Supabase** → restore vào CNPG. *(Supabase MCP connector chưa authorize trong session này → dùng connection string thủ công.)* |
| **Ảnh** | Liệt kê object Firebase Storage → tải → upload MinIO → `UPDATE users.avatar_url`, `UPDATE user_photos.url` |
| **User** | Đếm row có `phone` nhưng không có `email` → quyết định (liên hệ thủ công / chấp nhận mất) |
| **Verify** | So số row từng bảng giữa Supabase và CNPG trước khi cutover |

---

## 13. Lộ trình

Mỗi phase tự đứng được; rollback luôn khả dĩ vì **Cloud Run vẫn chạy song song đến P7**.

| P | Nội dung | Xong khi |
|---|---|---|
| **P0** | Host: kiểm tra `lsblk`/`df -h`; `br0` cho HAProxy2; reshape VM (3 CP → 1 CP 2 GB, 2 worker → 3 worker 8 GB); disk thứ hai cho Longhorn; Ollama CUDA; nftables nền; bật KSM + ballooning; **etcd snapshot cron → MinIO** | 4 node Ready · `ollama` chạy trên GPU · snapshot etcd chạy được |
| **P1** | MetalLB (VIP `.200`) + ingress-nginx (LoadBalancer) + cert-manager DNS-01 + Longhorn (replica 1) | `curl` từ host vào VIP ra app test, cert LE hợp lệ |
| **P2** | Vault container trên host + ESO + seed secrets + Vault Agent | `ExternalSecret` sinh ra k8s `Secret` |
| **P3** | Harbor (retention + GC) + self-hosted runner + Helm chart + luồng OIDC | push commit → image vào Harbor → deploy tự động |
| **P4** | CNPG + PgBouncer + MinIO + Redis; `pg_dump` Supabase → restore; đếm user không có email | số row khớp Supabase |
| **P5** | Chẩn đoán CGNAT/port; Pi + HAProxy2 + VIP keepalived; router forward 8443; Cloudflare DNS + Origin CA; DDNS nếu IP động; cloudflared làm dự phòng | `https://anmates.vn` live — **song song Cloud Run** |
| **P6** | Code: runtime config Flutter · de-Firebase auth · MinIO upload · Redis WS hub · Ollama endpoint · Dockerfile; migrate ảnh | login email OTP + upload chạy on-prem |
| **P7** | Cutover DNS · tắt Cloud Run + Firebase Hosting + Artifact Registry · dọn workflow cũ | cloud bill = 0 |
| **P8a** | Observability: Mimir + Loki + Alloy + Grafana + dashboard + alert | dashboard HAProxy + cluster + GPU chạy |
| **P8b** | Traces: Tempo + `otelfiber` + OTel Python + correlate qua `X-Request-ID` | trace đi hết Cloudflare → HAProxy → ingress → api → PG |
| **P9** | Backup offsite + DR runbook | **restore thử thành công từ backup** |

---

## 14. Rủi ro

| # | Rủi ro | Mức | Xử lý |
|---|---|---|---|
| 1 | **PC host là SPOF nặng** — gánh hypervisor + gateway + Ollama + CI runner + Vault | 🔴 | Backup CNPG + etcd → MinIO → **offsite** là bắt buộc (P9), không phải tuỳ chọn |
| 2 | **1 control-plane**: hỏng đĩa CP VM = mất cả cluster | 🔴 | etcd snapshot mỗi 6h → MinIO → offsite; snapshot qcow2 trước mỗi lần nâng cấp k8s; chart trong git dựng lại được. *Lưu ý: CP chết KHÔNG làm app chết — kubelet/kube-proxy/ingress vẫn chạy, chỉ mất deploy/scale/self-heal* |
| 3 | **CP 2 GB sát trần** | 🟠 | Alert RSS apiserver > 800 Mi; nếu OOM lấy 0.5 GB từ một worker |
| 4 | **Đĩa < 200 GB** | 🔴 | Longhorn replica 1 · retention 14d · Harbor 5 tag + GC tuần · alert disk > 75% |
| 5 | **HA pair không chống được host chết** — HAProxy2 nằm trên chính host đó | 🟠 | Giá trị thật = bảo trì không downtime + Pi giữ VIP serve trang bảo trì. Ghi rõ trong runbook, đừng kỳ vọng nhầm |
| 6 | **Runner tự host trên máy gateway** = chạy code trên máy đặc quyền nhất | 🔴 | §9 — ephemeral, chỉ `push main`, không `pull_request_target`, Environment có reviewer |
| 7 | **Không có GitOps** → drift âm thầm | 🟠 | Chart trong git là nguồn sự thật + cron `helm diff` hằng đêm |
| 8 | **Vault sealed sau host reboot** | 🟠 | App đang chạy vẫn sống; chỉ pod mới/đổi secret kẹt. Runbook unseal, key offline |
| 9 | **CGNAT** → port-forward bất khả thi | 🟠 | Chẩn đoán ở P5. Nếu CGNAT: dùng cloudflared (đã có sẵn) hoặc VPS + WireGuard |
| 10 | **Mở public IP** = mạng nhà thành mục tiêu | 🟠 | Forward đúng 1 port · `policy drop` mặc định · **không bao giờ lộ 6443/22** · HAProxy lọc dải Cloudflare · NetworkPolicy |
| 11 | VRRP multicast bị switch/AP chặn | 🟡 | Đổi `unicast_peer` |
| 12 | Pi chạy thẻ SD → hỏng dần | 🟡 | Boot USB SSD, hoặc tối thiểu `log2ram` |
| 13 | Origin CA cert không được trình duyệt tin | 🟡 | Đúng thiết kế — chỉ đi qua Cloudflare. LAN dùng cert LE trên ingress |
| 14 | Điều khoản ISP thường cấm chạy server trên gói dân dụng | 🟡 | Kiểm tra hợp đồng trước khi coi là production |
| 15 | **Ảnh quán scrape realtime** — miss lạnh 11.8s (changelog 2026-06-12) | 🟡 | Ở 50 RPS chịu được (~11 concurrent). Nên chuyển sang MinIO + CDN cache ở P6 để tránh dồn cục |
| 16 | AI sidecar trần ~1–2 RPS/replica | 🟢 | Concierge chỉ kích hoạt khi match (`AI_TRIGGER_POINTS=70`) ≈ < 0.5 RPS — 1 replica dư |
| 17 | Upload bandwidth nhà | 🟢 | 50 RPS × 30 KB ≈ 12 Mbps — mọi gói FTTH đều dư |
| 18 | Mất đăng nhập bằng SĐT | 🟢 | Quyết định đã chốt. Đếm row bị ảnh hưởng ở P4 |
| 19 | Cloudflare free: body limit 100 MB | 🟢 | Ảnh avatar dư sức |
| 20 | RAM headroom chỉ 5.89 Gi | 🟠 | Mọi chart thêm vào sau phải tính RAM trước. Alert node memory > 90% |
| 21 | **Pipeline ảnh quán đang dở nhắm vào Firebase Storage** — trùng với thứ design này gỡ bỏ | 🟠 | Build thẳng vào MinIO ngay từ đầu (§15.1). Chưa viết code nên chi phí đổi ≈ 0 |

---

## 15. Giao thoa với công việc đang dở

### 15.1 Ảnh quán "chính chủ" — XUNG ĐỘT phải giải trước khi build

`current-task.md` (2026-06-14) ghi một hướng **đã quyết nhưng chưa build**: scrape panel
Google Maps bằng Playwright từ **IP residential** → tải bytes → **upload Firebase Storage** →
lưu `{goong_id, firebase_urls, source, fetched_at}` vào Postgres (migration `venue_photos` mới),
cache **vĩnh viễn**.

**Xung đột:** design này **bỏ hẳn Firebase Storage** (§10.3). Nếu build theo kế hoạch cũ rồi
mới re-platform thì phải di trú lại toàn bộ ảnh quán lần thứ hai.

**Giải quyết:** vì phần đó **chưa viết dòng code nào**, hãy build thẳng vào **MinIO** ngay từ
đầu. Thay đổi so với kế hoạch 2026-06-14 rất nhỏ — chỉ là đích upload:

| | Kế hoạch cũ | Sửa thành |
|---|---|---|
| Đích upload | Firebase Storage | **MinIO** (bucket `anmates-venue-photos`) |
| Cột trong DB | `firebase_urls` | `photo_urls` (trỏ `cdn.anmates.vn/...`) |
| Client upload | Firebase SDK | `services/storage.go` (minio-go) — **cùng service với §10.3** |

Phần còn lại (sidecar `GoogleMapsCrawler`, `POST /api/v1/venues/photos/ingest`,
SSRF-guard, migration `venue_photos`, fallback Bing/agentic theo R-007) giữ nguyên.

### 15.2 Lợi ích ngoài dự kiến: on-prem **là** IP residential

R-008 và session 2026-06-11 đã chứng minh: scrape Google Maps từ **IP datacenter** (Cloud Run)
→ dính CAPTCHA; từ **IP residential** → không CAPTCHA/consent/sorry.

Kế hoạch cũ vì thế phải chạy scrape **thủ công ở nhà**, production chỉ đọc DB — một quy trình
hai nhịp khó chịu. Sau khi re-platform, **cluster production nằm ngay tại nhà trên đường FTTH
dân dụng** → job ingest chạy được **trực tiếp trong cluster** như một `CronJob`, không cần
nhịp thủ công nào.

Đây là lợi ích không nằm trong mục tiêu ban đầu của việc re-platform, nhưng nó gỡ đúng nút
thắt vận hành của tính năng ảnh quán.

> ⚠️ Đánh đổi không đổi: rủi ro ToS/bản quyền khi re-host ảnh vẫn là **rủi ro kinh doanh
> user đã chấp nhận** (ghi trong R-008). Re-platform không làm nó nhẹ đi.

### 15.3 Nên làm trước P0

Feature "Bản đồ" Goong + tìm kiếm + ảnh Foursquare **code xong nhưng chưa được user confirm
in-app**. Nên `./start.sh` xác nhận trước, để không re-platform trên một nhánh còn treo.

---

## 16. Câu hỏi mở

| Câu hỏi | Chặn phase nào | Ghi chú |
|---|---|---|
| Dung lượng NVMe trống thực tế | P0 | Nếu < 150 GB → MinIO 40 GB + retention 7 ngày |
| CGNAT hay public IP thật? Port nào mở? | P5 | Nếu CGNAT → cloudflared hoặc VPS + WireGuard |
| Số row `users` có `phone` nhưng không `email` | P4 | Quyết định liên hệ thủ công hay chấp nhận mất |
| IP công cộng tĩnh hay động? | P5 | Nếu động → DDNS CronJob cập nhật A record qua Cloudflare API |
| Tên miền cụ thể | P5 | Spec dùng `anmates.vn` làm placeholder nhất quán |

---

## Phụ lục — quy ước giá trị mẫu

Mọi IP, hostname và tên repo trong các phụ lục dưới đây là **giá trị mẫu**, phải thay bằng
giá trị thật khi hiện thực:

| Mẫu | Ý nghĩa |
|---|---|
| `anmates.vn` | tên miền sẽ mua (§16) |
| `192.168.1.240 / .241 / .242` | VIP · Pi 4 · HAProxy2 trên LAN |
| `192.168.1.50` | IP LAN của PC host |
| `10.10.10.1` | PC host trên mạng libvirt (Ollama, Vault) |
| `10.10.10.11` | IP control-plane (apiserver) |
| `10.10.10.200` | MetalLB VIP của ingress-nginx |
| `enp3s0` | NIC LAN của PC host |
| `<owner>/AnMates` | đường dẫn repo GitHub |

---

## Phụ lục A — HAProxy (giống nhau trên cả hai node)

```
global
    log /dev/log local0
    maxconn 20000
    tune.ssl.default-dh-param 2048

defaults
    mode http
    log global
    option httplog
    option forwardfor
    timeout connect 5s
    timeout client  60s
    timeout server  60s
    # WebSocket chat can timeout dai
    timeout tunnel  3600s

frontend fe_https
    bind 192.168.1.240:8443 ssl crt /etc/haproxy/certs/anmates-origin.pem
    # chi nhan traffic tu dai Cloudflare - chan scan thang vao IP nha
    tcp-request connection reject if !{ src -f /etc/haproxy/cloudflare-ips.lst }
    http-request set-header X-Forwarded-Proto https
    http-request set-header X-Forwarded-For %[req.hdr(CF-Connecting-IP)]
    unique-id-format %{+X}o\ %ci:%cp_%fi:%fp_%Ts_%rt:%pid
    http-request set-header X-Request-ID %[unique-id]
    default_backend be_ingress

backend be_ingress
    option httpchk GET /healthz
    http-check expect status 200
    server ingress 10.10.10.200:443 ssl verify none check inter 2s fall 3 rise 2
    # cluster chet -> trang bao tri ĂnMates, khong phai loi 52x cua Cloudflare
    errorfile 503 /etc/haproxy/errors/503-maintenance.http

frontend fe_metrics
    bind 0.0.0.0:8405
    http-request use-service prometheus-exporter if { path /metrics }
    no log
```

## Phụ lục B — keepalived (Pi 4 = MASTER)

```
vrrp_script chk_haproxy {
    script "/usr/bin/killall -0 haproxy"
    interval 2
    weight -20
    fall 2
    rise 2
}

vrrp_instance VI_ANMATES {
    state MASTER              # HAProxy2: BACKUP
    interface eth0
    virtual_router_id 51
    priority 110              # HAProxy2: 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass <tu Vault>
    }
    virtual_ipaddress {
        192.168.1.240/24
    }
    track_script {
        chk_haproxy
    }
    # bo comment neu switch/AP chan multicast 224.0.0.18
    # unicast_src_ip 192.168.1.241
    # unicast_peer { 192.168.1.242 }
}
```

## Phụ lục C — nftables trên PC host

```
table inet filter {
  chain forward {
    type filter hook forward priority filter; policy drop;
    ct state established,related accept
    # chi mo dung mot duong: HAProxy -> MetalLB VIP
    ip saddr { 192.168.1.241, 192.168.1.242 } ip daddr 10.10.10.200 tcp dport 443 accept
    # KHONG BAO GIO forward 6443 (k8s API) hay 22 tu WAN
    ip daddr 10.10.10.0/24 tcp dport { 22, 6443 } drop
    # cluster di ra Internet (pull image, Cloudflare, SMTP)
    ip saddr 10.10.10.0/24 accept
  }
}

table ip nat {
  chain postrouting {
    type nat hook postrouting priority srcnat;
    # NAT chieu DI RA cho cluster
    ip saddr 10.10.10.0/24 oifname "enp3s0" masquerade
    # KHONG SNAT chieu di vao tu HAProxy -> giu nguyen client IP
  }
}
```

## Phụ lục D — Vault JWT role cho GitHub Actions

```bash
vault auth enable jwt
vault write auth/jwt/config \
    oidc_discovery_url="https://token.actions.githubusercontent.com" \
    bound_issuer="https://token.actions.githubusercontent.com"

vault write auth/jwt/role/anmates-ci - <<'EOF'
{
  "role_type": "jwt",
  "user_claim": "actor",
  "bound_audiences": "vault",
  "bound_claims_type": "glob",
  "bound_claims": {
    "repository": "<owner>/AnMates",
    "ref": "refs/heads/main"
  },
  "token_policies": "anmates-ci",
  "token_ttl": "20m"
}
EOF
```

## Phụ lục E — Vault Kubernetes auth cho ESO

```bash
vault auth enable kubernetes
vault write auth/kubernetes/config \
    kubernetes_host="https://10.10.10.11:6443" \
    kubernetes_ca_cert=@/etc/vault/k8s-ca.crt \
    token_reviewer_jwt=@/etc/vault/eso-sa.jwt

vault write auth/kubernetes/role/anmates-eso \
    bound_service_account_names=external-secrets \
    bound_service_account_namespaces=external-secrets \
    policies=anmates-read ttl=1h
```
