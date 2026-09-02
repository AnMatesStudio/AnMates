# 2026-08-31 — Design: re-platform AnMates lên k8s on-prem

## TL;DR
7 vòng brainstorm với user → chốt design đầy đủ cho việc chuyển toàn bộ AnMates từ
Firebase Hosting + Cloud Run + Supabase sang k8s on-prem trên MỘT máy PC (KVM/libvirt),
Pi 4 làm edge node thứ hai. Spec ghi tại
`docs/superpowers/specs/2026-08-31-onprem-k8s-replatform-design.md` (810 dòng).
**Chưa hiện thực gì cả — mới là design.**

## Quyết định đã khoá
- **Cluster**: 1 control-plane (2 GB) + 3 worker (8 GB), giữ mạng `10.10.10.0/24` (host là NAT gateway)
- **Edge**: Cloudflare → HAProxy ×2 (Pi 4 MASTER + VM bridge BACKUP) + VIP keepalived
  `192.168.1.240` → MetalLB VIP `10.10.10.200` → ingress-nginx
- **Đường public**: public IP + Cloudflare proxy **origin port 8443** (né ISP chặn 443);
  cloudflared tunnel làm dự phòng nóng
- **Registry**: Harbor (loại Artifactory vì Docker registry cần bản Pro trả phí; loại Nexus vì JVM 3–4 Gi)
- **Secrets**: HashiCorp Vault **container trên host** (không trong k8s) + External Secrets Operator
- **CI/CD**: GHA cloud runner (test + `flutter build web`) → self-hosted runner trên host
  (`docker build COPY` + `helm upgrade --atomic`). **GHA zero-secret** — xác thực Vault bằng GitHub OIDC
- **Storage**: Longhorn `replica: 1` + MinIO (thay Firebase Storage)
- **DB**: CloudNativePG + PgBouncer
- **Auth**: Email OTP — **bỏ hẳn Firebase Phone OTP**
- **LLM**: Ollama native trên host với GPU (không VFIO passthrough)
- **Observability**: Grafana LGTM (Mimir + Loki + Tempo + Alloy + Grafana). Loại OpenSearch (JVM 3–4 Gi)
- **Môi trường**: 2 namespace `anmates` + `anmates-dev`
- **Tải mục tiêu**: 50 RPS (beta MVP)

## Phát hiện quan trọng khi đọc code
- `db/migrate.go` **đã có `pg_try_advisory_lock`** → multi-replica boot an toàn
- Migrations chỉ cần `pgcrypto`, **KHÔNG dùng PostGIS** (PostGIS chỉ có trong master-plan doc)
- `ws/redis_hub.go` bị `//go:build ignore` → hub in-memory → api hiện **kẹt 1 replica**
- Prod DB hiện là **Supabase** (không phải Cloud SQL) — theo `.github/CI-CD.md`
- `API_BASE_URL` + `GOONG_MAPTILES_KEY` nhúng lúc compile qua `--dart-define`
  → dev/prod cần **2 image khác nhau**, và host runner phải chạy `flutter build web` (4 GB RAM)
- `storage_service.dart` dùng hack `signInAnonymously()` để lách Firebase Storage rules

## Đóng góp kỹ thuật chính
1. **Runtime config cho Flutter** (`window.APP_CONFIG` do nginx sinh) → 1 image chạy cả dev
   lẫn prod, `flutter build web` chuyển lên GHA cloud runner, **giải phóng 2.5 GB RAM host**
   → chính là RAM tái phân bổ cho worker node
2. **GitHub OIDC → Vault JWT** → workflow không chứa `secrets.*` nào
3. Chỉ ra **2 control-plane kém hơn 1** (Raft quorum: N=2 → quorum 2 → 2 điểm hỏng)
4. Chỉ ra **ít worker to > nhiều worker nhỏ**: mỗi node tốn ~1.05 Gi overhead
   (3×8 GB cho 20.85 Gi allocatable vs 6×4 GB chỉ cho 17.7 Gi)
5. Giải thích Cloudflare Tunnel không cần `type: LoadBalancer` (cloudflared là egress client;
   phân luồng bằng `Host` header chứ không phải IP) — nhưng vẫn chọn LoadBalancer + VIP để
   LAN và public đi chung một đường, dễ chẩn đoán

## Ràng buộc siết nhất
- **RAM 32 GB**: allocatable 20.85 Gi, workload 14.96 Gi, headroom **5.89 Gi**
- **Đĩa < 200 GB**: buộc Longhorn replica 1 + retention observability 14 ngày +
  Harbor giữ 5 tag/repo + GC tuần. Tổng Longhorn 140 GB, net ~128 GB sau khi thu hồi 2 CP VM
- **PC host là SPOF nặng**: gánh hypervisor + gateway + Ollama + CI runner + Vault

## Code sẽ phải sửa (chưa làm)
Go: bật `redis_hub.go` · `services/storage.go` (minio-go) + `POST /api/v1/uploads/photo` ·
gỡ `VerifyFirebaseToken`/`FIREBASE_WEB_API_KEY` · email OTP thành đường chính ·
bỏ `GOMAXPROCS`/`GOMEMLIMIT` hardcode trong Dockerfile · Ollama endpoint
Flutter: `lib/config.dart` mới (runtime config) · viết lại `storage_service.dart` ·
email OTP thay phone · xoá `firebase_options.dart` + 4 package firebase
Repo: `deploy/charts/` · `cd.helm.yml` · xoá `firebase.json`, `.firebaserc`, 3 workflow `cd.*`

## Verification
- Chưa có gì để verify — **design only**, chưa chạm code sản phẩm
- Spec self-review đã chạy: không có placeholder TBD/TODO; các bảng RAM/đĩa/phase cộng đúng
  (6.0 + 2.0 + 24.0 = 32.0 · allocatable 20.85 · workload 14.96 · headroom 5.89 · Longhorn 140 GB)

## Câu hỏi mở (ghi trong §16 của spec)
| Câu hỏi | Chặn phase |
|---|---|
| Dung lượng NVMe trống thực tế (`lsblk`, `df -h`) | P0 |
| CGNAT hay public IP thật? Port nào mở? | P5 |
| Số row `users` có `phone` nhưng không có `email` | P4 |
| IP công cộng tĩnh hay động | P5 |
| Tên miền cụ thể (spec dùng `anmates.vn` làm placeholder) | P5 |

## Follow-up
- Bước kế tiếp: viết implementation plan (skill `superpowers:writing-plans`)
- **Trước P0**: nên `./start.sh` xác nhận feature "Bản đồ" Goong + ảnh Foursquare
  (đang treo chờ R-008) để không re-platform trên nhánh còn dở

## Phát hiện muộn (khi cập nhật shared-memory) — §15 của spec
**XUNG ĐỘT**: kế hoạch ảnh quán "chính chủ" quyết ngày 2026-06-14 (scrape Google Maps panel
bằng Playwright từ IP residential → cache vĩnh viễn) nhắm đích upload là **Firebase Storage** —
đúng thứ design này gỡ bỏ. May là phần đó **chưa viết dòng code nào** → build thẳng vào
**MinIO** ngay từ đầu, chi phí đổi ≈ 0 (chỉ đổi đích upload + tên cột `firebase_urls` →
`photo_urls`; sidecar/handler/migration/SSRF-guard giữ nguyên).

**LỢI ÍCH NGOÀI DỰ KIẾN**: R-008 + session 2026-06-11 đã chứng minh scrape từ IP datacenter
(Cloud Run) dính CAPTCHA, từ IP residential thì không. Sau re-platform, cluster production
nằm ngay tại nhà trên FTTH dân dụng → job ingest chạy được **trực tiếp trong cluster** như
một CronJob, bỏ được nhịp scrape thủ công mà kế hoạch cũ bắt buộc phải có. Re-platform vô
tình gỡ đúng nút thắt vận hành của tính năng ảnh quán.
(Rủi ro ToS/bản quyền re-host ảnh không đổi — vẫn là rủi ro kinh doanh user đã chấp nhận.)

## Cập nhật 2026-08-31 (sau khi user chốt layout MVP)
User chọn **1 CP (4 GB / 2 vCPU) + 2 worker (8 GB / 4 vCPU)** cho giai đoạn MVP thay vì
1 CP (2 GB) + 3 worker (8 GB). Đã tính lại và sửa spec §0, §3.1, §3.2, §3.3, phase P0, rủi ro #3/#4/#20.

- Host: dùng 26 GB / 32 GB → **dôi 6 GB**; CPU 12 vCPU / 20 nhân → **không overcommit**
- Allocatable: `2 × (8 − 1.05)` = **13.90 Gi** (giảm từ 20.85)
- **Kết luận quan trọng**: 2 worker đủ thoải mái cho **P0–P7** (workload 9.76 → headroom 4.14 Gi)
  nhưng **chật khi bật observability**: +P8a (Mimir+Loki+Alloy+Grafana) → headroom 1.14 Gi;
  +P8b (Tempo) → 0.64 Gi. → **Điều kiện thêm worker #3 là bật P8, không phải tăng user.**
  Host còn dôi 6 GB nên thêm worker #3 chỉ là tạo thêm VM, không reshape.
- `anmates-dev` chạy `ai-venue-search` `replicas: 0` (scale tay khi test AI) — bật thường trực
  tốn 1.2 Gi làm P8a còn 0 headroom
- Rủi ro #3 (CP sát trần) **đã gỡ** — CP 4 GB rộng rãi
- Đĩa dễ thở hơn: Longhorn PVC 140 → **100 GB**, mỗi worker 1 data disk 60 GB (qcow2 thin),
  net cấp phát mới ~78 GB sau khi thu hồi 2 CP VM. Retention observability 14d → **7d** ở MVP

## Cập nhật 2026-08-31 (2) — Layout MVP chốt lại + Jira backlog đã tạo

**Layout cuối user chốt**: 1 CP (**2 vCPU / 4 GB**) + 2 worker (**4 vCPU / 8 GB**) — cụm đã dựng xong.
- Host dùng 26/32 GB → dôi 6 GB; CPU 12/20 nhân → **không overcommit**
- Allocatable `2 × (8 − 1.05)` = **13.90 Gi**
- P1–P7 (lõi): 9.76 Gi → headroom **4.14 Gi** ✅
- +P9a (metrics+logs): 12.76 → 1.14 Gi ⚠️ · +P9b (traces): 13.26 → 0.64 Gi ❌
- **→ Điều kiện thêm worker #3 là bật observability, KHÔNG phải tăng user.**

**Registry: Harbor** (loại Artifactory — Docker registry cần bản Pro trả phí, bản OSS/JCR cho
container đã EOL; loại Nexus — JVM 3–4 Gi, Docker chỉ là tính năng phụ sau Maven/npm).
Lý do chính chọn Harbor **không phải** RBAC mà là **retention policy + GC** — thứ giữ cho ổ
không đầy khi chỉ còn <200 GB.

**Đĩa <200 GB** → Longhorn PVC 140 → **100 GB**, mỗi worker 1 data disk 60 GB (qcow2 thin),
retention observability 14d → **7d**, net cấp phát mới ~78 GB.

**Login**: bỏ SĐT hoàn toàn → rủi ro #12 đóng. Đếm row `users` có phone/không email ở P4.

### Jira backlog — project TECH (site anmatesstudio.atlassian.net)
Đã tạo **10 epic (TECH-10→19) + 41 task (TECH-20→60)**, label `onprem-k8s`, đã verify:
`parent IS EMPTY` chỉ trả về đúng 10 epic (không task mồ côi).

| Epic | Key | Task |
|---|---|---|
| [P1] Nền tảng cluster | TECH-10 | TECH-20→26 (7) |
| [P2] Vault trên host + ESO | TECH-11 | TECH-27→31 (5) |
| [P3] Harbor + CI/CD zero-secret | TECH-12 | TECH-32→38 (7) |
| [P4] Data plane + di trú Supabase | TECH-13 | TECH-39→44 (6) |
| [P5] Sửa code để chạy trên k8s | TECH-14 | TECH-45→49 (5) |
| [P6] Deploy UI + API | TECH-15 | TECH-50→52 (3) |
| [P7] Mở ra Internet | TECH-16 | TECH-53→60 (8) |
| [P8] Gỡ Firebase | TECH-17 | (chưa breakdown) |
| [P9] Observability | TECH-18 | (chưa breakdown) |
| [P10] Cutover + backup offsite | TECH-19 | (chưa breakdown) |

**Đường tới hạn (critical path)**: TECH-45 (Flutter runtime config, 13 SP) và TECH-46
(bật `ws/redis_hub.go`, 5 SP) chặn TECH-50/51 — nên bắt đầu song song với P1 ngay từ đầu
vì chúng là code, không phụ thuộc hạ tầng.

**3 task chặn epic khác**: TECH-21 (đo đĩa thật, chặn P1), TECH-53 (chẩn đoán CGNAT, chặn
toàn bộ P7), TECH-44 (đếm user không email, chặn P8).

Ghi chú: MCP Atlassian Rovo ban đầu chưa authorize (session non-interactive không chạy được
OAuth) → user bật qua `/mcp` rồi mới tạo được. Supabase MCP vẫn chưa authorize → P4 dùng
`pg_dump` với connection string thủ công.

## Sửa lỗi thứ tự (user chất vấn "vì sao không ưu tiên HAProxy/Cloudflare/network trước?")

User đúng — có **dependency ngược thật** trong backlog ban đầu, không phải chỉ là vấn đề ưu tiên:

**Lỗi**: cert-manager bắt buộc dùng **DNS-01** (ISP chặn port 80 → HTTP-01 không validate được).
DNS-01 phải tạo TXT record trong zone Cloudflare → **không có domain thì `ClusterIssuer` không
bao giờ `Ready`**. Nhưng mình xếp mua domain (TECH-54) ở tận P7, trong khi TECH-25 (cert-manager,
P1) và TECH-32 (Harbor ingress, P3) đều cần nó. Điều kiện tiên quyết bị đặt xuống cuối.

**Lỗi thứ 2**: TECH-53 (chẩn đoán CGNAT) là ngã ba đường — nếu CGNAT thì port-forward bất khả
thi, toàn bộ nhánh HAProxy vô nghĩa, phải đổi sang tunnel/VPS. Biết ở tuần 6 thay vì ngày 1 là
kiểu rủi ro tệ nhất.

**Nhưng "làm HAProxy trước" không hoàn toàn đúng**: HAProxy backend trỏ MetalLB VIP, chưa có
ingress-nginx thì health-check fail. → Tách theo tiêu chí **có phụ thuộc cụm hay không**:

| Loại | Phụ thuộc cụm? | Xếp ở đâu |
|---|---|---|
| Khám phá + mua sắm (CGNAT, domain, credential) | ❌ | **P0 — trước tất cả** |
| Đấu nối (HAProxy, keepalived, nftables, router) | ✅ cần VIP | **ngay sau P1** (không phải sau P6) |

**Điểm user nói đúng mà mình bỏ sót**: đấu nối không cần đợi P6. Có VIP là validate được cả
đường vào bằng **backend hello-world**. Nếu đợi tới P6, lúc trang không load phải debug hai
tầng cùng lúc (mạng hay app?).

### Thay đổi trên Jira
- **Tạo epic [P0] TECH-61** "Khám phá mạng + tên miền — LÀM TRƯỚC TIÊN"
- Re-parent **TECH-53** (→ P0.1 chẩn đoán CGNAT) và **TECH-54** (→ P0.2 domain) từ P7 sang P0
- Tạo **TECH-62** (P0.3) — Cloudflare API token DNS-01 + Origin CA cert → Vault
- Tạo **TECH-63** (P7.0) — validate đường vào E2E bằng hello-world, chạy ngay sau P1
- Sửa summary **TECH-25** và **TECH-32** ghi rõ dependency
- Sửa epic **TECH-16**: "[P7] Đấu nối Internet — bắt đầu NGAY SAU P1" + bảng thứ tự thực thi

Spec cập nhật: §13 tách P0a/P0b, sửa mô tả P5, thêm ghi chú 2 điều chỉnh thứ tự → 903 dòng.
Tổng Jira: **11 epic + 43 task**.

## Tách Jira: TECH (app/code) ↔ PI (infra)

User tạo project mới **PI = "Platform & Infrastructure"** (id 10002, team-managed) và chốt phân chia:
- **TECH** — chỉ feature app + code
- **PI** — k8s infra, network, CI/CD, helm deployment

### ⚠️ KHÔNG xoá được backlog cũ trong TECH bằng MCP
Connector Atlassian Rovo **không có tool delete** (chỉ create/edit/comment/transition/search).
54 issue đã tạo trong TECH (11 epic TECH-10→19,61 + 43 task) phải user tự bulk-delete qua Jira UI.
JQL đã đưa cho user:
1. `project = TECH AND labels = "onprem-k8s" AND issuetype = Task` (43)
2. `project = TECH AND labels = "onprem-k8s" AND issuetype = Epic` (11)
Xoá task trước rồi mới xoá epic.

### 14 epic đã tạo trong PI (PI-1 → PI-14)
| Key | Epic | Phase | Label |
|---|---|---|---|
| PI-1 | Khám phá mạng + tên miền | P0 | network |
| PI-2 | Chuẩn bị host + hypervisor | P0 | host |
| PI-3 | Nền tảng cluster (MetalLB/ingress/cert-manager/Longhorn) | P1 | k8s-platform |
| PI-4 | Namespace + guardrails đa môi trường | P1 | k8s-platform |
| PI-5 | Secrets — Vault trên host + ESO | P2 | secrets |
| PI-6 | Edge — HAProxy HA + keepalived + Cloudflare + firewall | P2 | network |
| PI-7 | Container Registry — Harbor | P3 | cicd |
| PI-8 | CI/CD — runner + Vault OIDC + Helm chart | P3 | cicd |
| PI-9 | Data plane — CNPG/PgBouncer/MinIO/Redis | P4 | data |
| PI-10 | Di trú dữ liệu từ cloud | P4 | data |
| PI-11 | Deploy ứng dụng lên k8s | P5 | deploy |
| PI-12 | Cutover + tắt cloud | P6 | deploy |
| PI-13 | Observability — Grafana LGTM | P7 | observability |
| PI-14 | Backup offsite + DR runbook | P8 | ops |

Chưa breakdown task — mới là epic cấp cao theo yêu cầu user.

### Phụ thuộc chéo PI → TECH (đã ghi trong mô tả epic)
§10 của spec (thay đổi code) **thuộc TECH, không thuộc PI**. Ba epic PI phụ thuộc vào nó:
- **PI-8** (Helm chart) và **PI-11** (deploy) cần: Flutter runtime config thay `--dart-define`
  (nếu không thì dev/prod cần 2 image khác nhau), bật `ws/redis_hub.go` (nếu không api kẹt 1
  replica), tách `/healthz` + `/readyz`, Dockerfile Go bỏ `GOMAXPROCS`/`GOMEMLIMIT`
- **PI-10** (di trú ảnh) cần endpoint upload MinIO ở Go API
- **PI-13** (traces) cần `otelfiber` + OTel Python

Lưu ý kỹ thuật: viết `&amp;` trong summary bị lưu literal → phải dùng `&` hoặc `+` trần.

## Breakdown task cho PI — hoàn tất (74 task)

Tạo đủ task con cho cả 14 epic trong project PI. Verified: `parent IS EMPTY` trên Task = **0**
(không có task mồ côi), tổng **74 task**, keys **PI-16 → PI-89** (PI-15 bị bỏ trống).

| Epic | Key | Task | Số task |
|---|---|---|---|
| [P0] Khám phá mạng + tên miền | PI-1 | PI-16→19 | 4 |
| [P0] Chuẩn bị host + hypervisor | PI-2 | PI-20→26 | 7 |
| [P1] Nền tảng cluster | PI-3 | PI-27→31 | 5 |
| [P1] Namespace + guardrails | PI-4 | PI-32→34 | 3 |
| [P2] Vault + ESO | PI-5 | PI-38→43 | 6 |
| [P2] Edge HAProxy/keepalived/Cloudflare | PI-6 | PI-50→57 | 8 |
| [P3] Harbor | PI-7 | PI-35→37 | 3 |
| [P3] CI/CD runner + OIDC + Helm | PI-8 | PI-44→49 | 6 |
| [P4] Data plane | PI-9 | PI-58→63 | 6 |
| [P4] Di trú dữ liệu | PI-10 | PI-64→67 | 4 |
| [P5] Deploy app | PI-11 | PI-68→71 | 4 |
| [P6] Cutover + tắt cloud | PI-12 | PI-72→76 | 5 |
| [P7] Observability LGTM | PI-13 | PI-77→84 | 8 |
| [P8] Backup + DR | PI-14 | PI-85→89 | 5 |

Mỗi task có: bối cảnh ngắn + gotcha chính + acceptance criteria kiểm chứng được + story point.

### Task chặn nhiều thứ khác (làm sớm)
- **PI-16** chẩn đoán CGNAT → chặn cả PI-6; nếu CGNAT thì PI-54/55 (router forward) vô nghĩa và PI-57 (tunnel) thành đường chính
- **PI-17** mua domain → chặn PI-31 (cert-manager DNS-01) → chặn PI-35 (Harbor ingress)
- **PI-20** kiểm toán đĩa → chặn PI-21, và ảnh hưởng sizing PI-35/PI-61
- **PI-77** thêm worker #3 → chặn cả epic observability

### Task có "Definition of Done" nghiêm ngặt
- **PI-63** CNPG backup: *chưa Done nếu chưa restore thử thành công*
- **PI-86** TEST RESTORE từ **offsite**: phải Done **trước PI-75** (tắt cloud)
- **PI-45** Vault OIDC: bằng chứng là *thử từ branch khác main → BỊ TỪ CHỐI*
- **PI-49** CI/CD: phải *cố tình làm fail smoke check* để xác nhận `--atomic` rollback

### Lưu ý Jira UI
Board của project team-managed **chỉ hiển thị hierarchyLevel 0** (Task/Story/Bug) — Epic
(level 1) không bao giờ lên Board, không có setting nào đổi được. Epic xem ở **Timeline**
hoặc **List**. Giờ đã có 74 task nên Board có nội dung; dùng nút **Group → Epic** để mỗi
epic thành một swimlane.

## 2026-09-01 — Plan mới: MVP 1 ngày (thay thế lộ trình nhiều tuần cho ngày đầu)

User đổi mục tiêu: **1 ngày phải chạy được** api+web trên k8s on-prem, 1 môi trường production
duy nhất (chưa có user thật). Bản full-reference (rename từ file thiết kế nhiều tuần) giữ làm
tài liệu tham khảo, không xoá.

### Quyết định cắt phạm vi
- **Bỏ**: MetalLB/ingress-nginx/cert-manager/HAProxy/keepalived/Pi4 (cloudflared trỏ thẳng
  Service — không port-forward nên không cần lớp edge) · Harbor (đổi **GHCR**, free + không
  giới hạn 100MB/layer mà Cloudflare Tunnel áp — chặn ngay layer Chromium ~350MB nếu dùng
  Harbor qua tunnel) · Vault/ESO (kubectl create secret thủ công) · MinIO (giữ Firebase
  Storage) · Redis (api 1 replica, hub in-memory vẫn đúng) · namespace dev · LGTM (thay
  metrics-server + Cloudflare Analytics + kubectl logs) · ai-venue-search (tắt, concierge
  tự disable khi AI_SEARCH_URL rỗng)
- **Giữ tối thiểu 4 stack self-managed** (network/DB/storage/observability), mỗi cái 1 repo
  riêng theo yêu cầu user

### Phát hiện quan trọng khi rà code cho yêu cầu "bỏ Firebase Auth, chỉ Email OTP + tester
quick-login không cần auth"
Backend **đã có sẵn cả hai thứ user yêu cầu**, không phải viết mới:
- `services/auth.go` RequestEmailOTP/VerifyEmailOTP — chạy đầy đủ (migration 012_email_otp.sql)
- `handlers/auth.go` DevLogin — CHÍNH LÀ "tester quick login", gate bằng DEV_MODE+DEV_BYPASS_SECRET

Frontend: `email_input_view.dart`+`email_otp_view.dart` đã viết xong nhưng **MỒ CÔI** — không
navigation nào gọi tới. Đường vào production thật: `splash_screen.dart` → (chưa login) →
`OnboardingView` → cuối cùng push `PhoneInputView` (Firebase phone OTP) — đây mới là nơi
Firebase Auth thực sự nằm trong luồng chạy, không phải `AuthView` (email+password, cũng
không có caller nào — có thể là legacy/orphaned luôn).

→ Việc thật chỉ là: đổi 1 dòng điều hướng (PhoneInputView→EmailInputView trong
onboarding_view.dart ~L73) + thêm 1 nút gọi AuthService().devLogin() đã có sẵn + xoá
phone_input_view.dart/otp_view.dart/auth_error_messages.dart + bỏ 1 package
(firebase_auth_platform_interface) khỏi pubspec.

### Crux đã hỏi user và chốt
`storage_service.dart` dùng `FirebaseAuth.instance.signInAnonymously()` để qua rule Firebase
Storage — nếu bỏ hẳn firebase_auth thì upload ảnh vỡ theo. Hỏi user: giữ firebase_auth chỉ
cho mục đích này, hay swap MinIO luôn trong ngày 1? **User chọn: giữ firebase_auth chỉ cho
Storage** (đúng scope — yêu cầu là bỏ Auth/đăng nhập, không phải Storage; de-Firebase Storage
để lại cho lộ trình sau, đã có kế hoạch trong bản full-reference §10.3).

### Quyết định DB seed
Bỏ hẳn ý định pg_dump từ Supabase — không cần, vì Discovery list quán fetch LIVE từ Goong
API, không phải từ DB seed. Test data thật chỉ là tài khoản, mà nút tester quick-login tự
tạo được ngay lúc bấm. Thêm 1 `seed.sql` tối thiểu (1 tester profile onboarding_done=true +
1 wishlist item) chỉ để có sẵn data xem nhanh không cần thao tác.

### File
Plan ghi tại `docs/plans/2026-09-01-mvp-1day-onprem-k8s.md` — 6 mục: kiến trúc rút gọn, ngân
sách RAM (~1.93 Gi dùng / 12 Gi headroom), thay đổi code Auth có dẫn chứng cụ thể, lịch theo
giờ H0→H8 với 2 cổng kiểm soát (hello-world qua tunnel, E2E cuối), bảng rủi ro, lộ trình sau
ngày 1 (backup CronJob là ưu tiên #1).

Chưa tạo Jira mới cho plan này — 88 issue project PI (từ lộ trình nhiều tuần cũ) VẪN CÒN,
user vẫn chưa bulk-delete (MCP không có tool delete). Cần hỏi user: giữ nguyên PI cũ làm
backlog dài hạn + tạo project/epic riêng cho sprint 1-ngày, hay dọn PI trước.

## 2026-09-01 (tiếp) — Đồng bộ với Cline (anmates-70) + phát hiện access

### Phối hợp 2 agent
Phát hiện Cline đang chạy song song trên Jira PI (lộ trình nhiều tuần cũ, đang ở PI-16/17/20).
Nhắn trực tiếp qua SendMessage tới session `anmates-70` (peer trên cùng máy). Cline xác nhận:
- Không đụng cluster hôm nay (đang làm Flutter quán-detail trên branch `feat/implement-quan-detail`)
- Không có `deploy/` nào được tạo, không lệnh kubectl/helm nào chạy từ session đó
- **Cảnh báo quan trọng**: `kubectl config current-context` trên máy = `orbstack` (k8s local),
  KHÔNG phải cụm on-prem thật

### Phát hiện của phiên này (khớp cảnh báo Cline)
Máy chạy session này **không có SSH host entry lẫn kubeconfig nào cho cụm on-prem** —
`~/.ssh/config` chỉ có jenkins-azure/ansible-*/EKS, không có PC host AnMates.
`~/.kube/` chỉ có `orbstack`, `devops-cluster-admin-config`, `eks-kubeconfig`.
→ **Cả 2 Claude session (Cline lẫn Claude Code) đều KHÔNG chạy được kubectl/helm trực tiếp
lên cụm thật** — chỉ user, trên chính PC host, mới có quyền đó.

### Quyết định user (hỏi qua AskUserQuestion)
1. **Scope split**: cả hai agent cùng làm — Cline giữ phần khám phá/mua sắm không đụng
   cluster (domain, Cloudflare token, câu hỏi mở §16 spec cũ); Claude Code lo toàn bộ phần
   đụng cluster của plan 1 ngày (Helm chart, secrets, deploy, cloudflared config)
2. **Kiến trúc API expose (PI-16)**: chốt theo đúng kết luận Cline — **1 hostname public duy
   nhất** (web), API internal-only, gọi qua nginx reverse-proxy nội bộ (CoreDNS). Đã sửa vào
   plan §1 + thêm nginx.conf mẫu (`location /api/` + `/ws/` proxy_pass tới
   `anmates-api.anmates.svc.cluster.local:8080`, có `Upgrade`/`Connection` header cho
   WebSocket chat). **Không cần sửa `lib/services/api_client.dart`** — chỉ cần build
   `API_BASE_URL` = domain của chính web app (same-origin), không phải rỗng
3. **Cluster access**: plan là **RUNBOOK**, không phải tự động hoá — user tự chạy mọi
   `kubectl`/`helm` trên PC host, báo lại kết quả/lỗi để Claude Code debug tiếp. Đã thêm
   cảnh báo context + `[BẠN chạy trên PC host]` vào đầu mỗi bước H0 trong plan

### File
`docs/plans/2026-09-01-mvp-1day-onprem-k8s.md` đã cập nhật: banner runbook ở đầu file, §1
kiến trúc single-hostname + nginx proxy, §4-H0 cảnh báo context, §4-H3 nginx.conf mẫu, workflow
CI + verify E2E sửa theo 1 hostname (bỏ `api.<domain>` khỏi mọi chỗ).

## 2026-09-01 (tiếp #2) — Helm chart app + GHA workflow đã viết xong

Phần "Claude Code làm ngay, không cần cluster" (đã liệt kê ở lần cập nhật trước) hoàn tất:

### Đã tạo
- `deploy/charts/anmates/` — Helm chart hoàn chỉnh: `Chart.yaml`, `values.yaml`,
  `values-prod.yaml`, `templates/{api,web}-{deployment,service}.yaml`, `NOTES.txt`.
  `helm lint` sạch (0 chart failed) + `helm template` render đúng — đã verify bằng lệnh
  thật, không phải suy đoán. `api` Service là ClusterIP thuần, không Ingress — đúng kiến
  trúc single-hostname đã chốt.
- `.github/workflows/ci-build-push.yml` — 5 job (test-api, test-web song song → build-push-api,
  build-push-web → notify in lệnh helm). Đăng nhập GHCR bằng GITHUB_TOKEN, không secret
  registry riêng. Cần 1 GH secret (`GOONG_MAPTILES_KEY`) + 1 GH variable (`ANMATES_DOMAIN`).
  Validate cú pháp YAML bằng pyyaml — parse OK, dependency graph đúng.
- `anmates_flutter/nginx.conf` — thêm 3 location block: `/health` (exact match), `/api/`,
  `/ws/` (có Upgrade/Connection header + read_timeout 3600s cho chat), tất cả proxy tới
  `http://anmates-api:8080` (Service name ngắn, cùng namespace).

### Gotcha phát hiện + vá luôn (không để lại nợ)
Route `/health` trong Go đăng ký thẳng trên `app`, NGOÀI group `/api/v1`
(`app.Get("/health", ...)` ở main.go) — nginx chỉ proxy `/api/` + `/ws/` thì health qua
public hostname sẽ 404. Vá bằng `location = /health` riêng trong nginx.conf.

### 3 workflow cd.*.yml cũ (Cloud Run/Firebase) — cố ý không đụng
Vẫn tự chạy song song khi push main — giữ nguyên làm đường lùi tới Cloud Run/Firebase, dù
không phải chủ đích ban đầu của plan 1 ngày (bản full-reference có chủ đích này, bản 1 ngày
thì không nói tới, nhưng giữ lại vô hại và có lợi).

### Trạng thái
Plan `docs/plans/2026-09-01-mvp-1day-onprem-k8s.md` đã đồng bộ 100% với code thật (H3-H6 viết
lại theo đúng file đã tạo, đánh dấu rõ [ĐÃ VIẾT XONG] / [BẠN chạy trên PC host] / [BẠN test]
ở từng bước). Còn lại: §3.2 sửa code Auth (5 việc, chưa làm) + `seed.sql` (chưa viết file
riêng, nội dung đã có trong plan §H2) + phần user tự chạy trên host (H0-H2, H5).
