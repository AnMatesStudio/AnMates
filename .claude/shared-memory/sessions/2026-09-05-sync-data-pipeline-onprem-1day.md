# 2026-09-05 — Thiết kế tuyến sync Data-Pipeline → catalog on-prem (bản 1 ngày)

## TL;DR

User hỏi: sync dữ liệu quán ăn từ Data-Pipeline chạy local trên máy Windows, qua devops-pc
Ubuntu trong Tailscale network, vào Postgres pod trong cụm k8s on-prem, để `api` + `web` đọc lên.
Sau khi đọc `docs/plans/2026-09-01-mvp-1day-onprem-k8s.md`, chốt phương án **NodePort qua
tailnet** và viết runbook 1 ngày + architecture diagram. Chưa chạy gì trên cụm — user tự chạy.

## Phát hiện quan trọng (không phải suy đoán, đã đọc code)

**1. Không phải viết ETL mới.** `Data-Pipeline/serving/` đã có đủ và đang chạy:
`publish.py` (SQLite → `foodrec` Postgres, hash mỗi record nên chạy lại không đụng `updated_at`),
`sync_anmates.py` (`foodrec` → `public.restaurants`, upsert theo `(source, source_ref)`),
`doctor.py` (5 preflight, có check "đúng DB AnMates không"), `scripts/run_publish_sync.ps1`
(Scheduled Task 15 phút). Chỉ `ANMATES_DB_URL` đang trỏ `localhost:5432` là phải đổi.

**2. Có 4 khoảng trống schema chặn cứng bên AnMates.** `serving/README.md` dặn apply
`013_pipeline_source.sql` "từ repo AnMates" — **file đó không tồn tại**, và số 013 đã bị
`013_seed_admin.sql` chiếm. Hệ quả đã verify trong code:
- `006_restaurants.sql`: `CHECK (source IN ('seed','goong','osm'))` → mọi dòng `'pipeline'` bị từ chối
- thiếu unique index `(source, source_ref) WHERE source_ref IS NOT NULL` → `ON CONFLICT`
  ở `sync_anmates.py:324` không có đích
- không có bảng `public.venue_photos` (sync ghi vào đó ở `sync_photos()`)
- không có `services/venue_catalog.go` lẫn `venue_photo_store.go` mà comment của pipeline
  nhắc tới; API hiện lấy ảnh live từ Foursquare + crawl `og:image` (`services/venue_photo.go`)

**3. Migration đi kèm image, không apply bằng psql.** `anmates-api/db/migrate.go` dùng
`//go:embed migrations/*.sql` + `pg_try_advisory_lock`, chạy lúc `api` boot. Apply tay bằng
`kubectl exec psql` sẽ làm `schema_migrations` lệch với binary. → migration 014 phải commit,
để CI build, rồi `helm upgrade`.

**4. Số liệu thật từ `data_pipeline.db`:** 74 bản ghi → 26 `APPROVED` (31 REJECTED, 17 chờ
duyệt) → 25 có `lat`/`lng` → 25 venue + 195 ảnh sẽ vào catalog. Chặng rụng nhiều nhất là
geocode, không phải mạng: AnMates để `lat`/`lng` là `NOT NULL` và concierge tìm theo bbox.

## Quyết định — đảo lại khuyến nghị ban đầu

Phân tích đầu tiên (trước khi đọc plan 1 ngày) khuyến nghị **Tailscale k8s operator + egress
Service**, cụm tự kéo, không mở cổng nào. Sau khi đọc plan 2026-09-01 → **đổi sang NodePort +
ACL tailnet**, vì:

- Plan §0 cắt MetalLB/ingress-nginx/cert-manager với lý lẽ "cloudflared trỏ thẳng Service →
  không cần lớp edge nào cả". Tailnet đã là mạng riêng có ACL → không cần lớp egress nào cả.
- Plan preamble: Claude Code **không có kubeconfig**, user gõ tay mọi lệnh. "Cài operator +
  tạo OAuth client + apply CRD" không hợp khuôn đó; `kubectl create service nodeport` thì hợp.
- Giữ sync trên máy Windows (Scheduled Task đã chạy) → không thêm image, không thêm lane CI,
  không thêm Secret.

**Giá phải trả, đã ghi vào mục rủi ro:** NodePort mở cổng Postgres trên *mọi* node của cụm.
Phòng thủ duy nhất là ACL tailnet + cụm không có IP public. Operator là việc tuần sau.

**Cắt khỏi ngày 1 có chủ đích:** handler Go phục vụ `venue_photos`. Bảng vẫn tạo để ETL có chỗ
đổ bytes ngay lần sync đầu, nhưng ảnh pipeline **chưa lên UI** trong ngày 1 — UI dùng ảnh
Foursquare như hiện tại. Quán hiện mà không có ảnh pipeline = đúng thiết kế, không phải bug.

## Files changed

- `anmates-api/db/migrations/014_pipeline_source.sql` (**mới**) — nới CHECK `source` nhận
  `'pipeline'`, unique index `(source, source_ref)`, bảng `venue_photos` với 2 ràng buộc UNIQUE
  (`position` và `sha256` — `sync_anmates.py` tự lọc trùng sha256 vì `ON CONFLICT` chỉ đỡ được một)
- `docs/plans/2026-09-05-sync-pipeline-onprem-1day.md` (**mới**) — runbook S0–S5, 4 cổng kiểm soát
- `docs/plans/2026-09-05-sync-pipeline-onprem-1day.html` (**mới**) — architecture diagram, mở
  thẳng bằng browser được (self-contained, có export PNG/PDF)

## Verification — PENDING

Chưa verify được gì cần cụm: không có kubeconfig, không có SSH tới host, không có Postgres
để chạy migration thật. Đã verify được:
- schema SQLite + số liệu (query trực tiếp `data_pipeline.db`)
- `restaurants.source` CHECK hiện tại và việc thiếu `venue_photos` (đọc `006_restaurants.sql`
  + grep toàn bộ `anmates-api`)
- cơ chế `go:embed` của migration runner (`db/migrate.go`)

**User cần chạy để đóng:** 4 cổng kiểm soát trong runbook (§2).

## Open follow-ups

1. `014_pipeline_source.sql` **chưa được apply lên cụm nào** — cần commit + CI + `helm upgrade`
2. Handler Go đọc `venue_photos` (giới hạn 3 MB/ảnh phải khớp `_MAX_PHOTO_BYTES` trong
   `serving/sync_anmates.py`)
3. Xác nhận `devops-pc` có phải node của cụm không — cả runbook giả định thế, suy ra từ
   `Data-Pipeline/scan_ports.ps1` đang nhắm `devops-pc.tail795b47.ts.net`. Nếu không phải:
   dùng hostname tailnet của một node thật, hoặc `socat` trên devops-pc
4. Sau khi chạy được: Tailscale operator → đóng NodePort lại

## Key facts

- Tailnet: `tail795b47.ts.net` · host đích trong runbook: `devops-pc` · port đề xuất: `30432`
- Rows do ETL sở hữu bằng `source='pipeline'` + `source_ref=<foodrec id>`; mọi statement scope
  theo 2 cột đó → hàng `seed`/`goong`/`osm` vô hình với ETL
- `--prune` đặt `status='hidden'`, **không xoá** (booking/swipe có thể đang trỏ vào). Lần chạy
  đầu không dùng cờ này
- Cổng 5432 trên máy Windows bị service native `postgresql-x64-18` chiếm và che container
  `anmates-db-1` — đây là lý do `doctor.py` có check identity; giữ nguyên check đó


---

# Addendum (cùng ngày) — rev 2: devops-pc là KVM host, không phải node

## Điều gì sai ở rev 1

rev 1 giả định `devops-pc` là node của cụm, nên `devops-pc.tail795b47.ts.net:30432` sẽ tới
được NodePort. User cho biết **devops-pc là máy vật lý chạy cụm k8s trên KVM**. Node k8s là
VM sau libvirt NAT (`virbr0`, mặc định `192.168.122.0/24`). Tailscale chạy trên *host*;
NodePort lắng nghe trên IP của *VM*. Gói tin tới hostname tailnet của devops-pc **dừng ở
netstack của host**, không vào tới VM. Phương án rev 1 không chạy được như đã viết.

## Sửa: subnet router

`sudo tailscale up --advertise-routes=192.168.122.0/24` trên devops-pc + `net.ipv4.ip_forward=1`
+ Approve route trong admin console. Máy Windows nối thẳng `192.168.122.<node>:30432`.
Chọn subnet router thay vì iptables DNAT (hỏng khi libvirt cấp lại IP, vô hình với
`tailscale status`), thay vì cài Tailscale trong từng VM (3 node nữa phải quản), thay vì socat
(thêm daemon chết lặng). Được cả dải → `kubectl`, `psql`, Grafana đi chung một đường.

**Phải ghim IP của VM** (`virsh net-update default add ip-dhcp-host`) TRƯỚC khi tạo NodePort —
DHCP cấp lại IP sau reboot sẽ làm tuyến tự hỏng vào một ngày không ai đụng tới nó.

**Bốn chỗ gói tin có thể chết:** ACL tailnet · `ip_forward` · route chưa approve · selector
Service. Ba chỗ đầu nằm trên devops-pc và **im lặng** — `tailscale status` xanh trong khi
`psql` treo hết timeout.

## Thêm: lớp quan sát (yêu cầu mới của user)

User muốn monitor được sync nào thành công/thất bại và visualize.

**Vấn đề thật:** `sync_anmates.py` chỉ `logger.warning` danh sách skipped rồi để nó chết theo
tiến trình (đã đọc `main()`, dòng 467–503). Không có dòng nào ghi lại lần chạy, không có
timestamp sync gần nhất. Muốn biết "quán nào kẹt" phải SSH vào Windows đọc
`logs/publish_sync.log`.

**Chốt:** hai bảng sổ trong `anmates-db` + Grafana datasource Postgres. KHÔNG Pushgateway,
KHÔNG exporter — `sync_anmates.py` đã mở sẵn kết nối tới đúng cái DB mà Grafana đọc được bằng
ClusterIP. Sổ bên `foodrec` thì Grafana phải quay ngược ra tailnet: thêm một chiều, thêm một
chỗ hỏng.

- `sync_runs` — append-only, một dòng/lần chạy. Mở + commit **trước** khi làm việc, đóng sau:
  `finished_at IS NULL` = chết ngang, khác `ok=false` + `error` = lỗi bắt được tử tế.
- `sync_venue_state` — trạng thái HIỆN TẠI mỗi venue, cố ý không append-only (25 venue × 96
  lần chạy/ngày = 2400 dòng/ngày cho một câu hỏi mà bảng trạng thái trả lời rẻ hơn).
  `last_change_at` chỉ nhích khi `outcome`/`reason` đổi — nếu không thì "kẹt bao lâu" reset
  mỗi 15 phút và cột đó vô nghĩa.

Grafana onprem **đã bật sẵn** (`environments/onprem/observability/values.yaml`: prometheus +
grafana, persistence 5Gi, `datasources.yaml` đã có Prometheus) — chỉ thêm datasource thứ hai.
Prometheus lo hạ tầng, sổ lo nghiệp vụ; cố ý không trộn (Prometheus xoá theo retention 7 ngày).

## Files changed (rev 2)

- `anmates-api/db/migrations/015_sync_ledger.sql` (**mới**) — `sync_runs` + `sync_venue_state`.
  Role `grafana_ro` cố ý KHÔNG nằm trong migration (secret không vào git)
- `docs/plans/2026-09-05-sync-pipeline-onprem-1day.md` — viết lại: §0.1 transport, §0.2 quan
  sát, S0–S2 đổi theo subnet router, thêm M1 (vá `sync_anmates.py`, ~40 dòng, có sẵn code) và
  M2 (Grafana), bảng panel dashboard, rủi ro cập nhật
- `docs/plans/2026-09-05-sync-pipeline-onprem-1day.html` — 3 hình: đường đi gói tin qua KVM,
  vòng quan sát, phác thảo dashboard

## Open follow-ups (rev 2)

1. Vá `sync_anmates.py` — code đã viết sẵn trong runbook §M1 nhưng **chưa apply vào repo
   Data-Pipeline** (repo riêng, để user review trước)
2. Xác nhận dải virbr0 thật (`virsh net-dumpxml default`) — runbook dùng mặc định
   `192.168.122.0/24`, có thể khác
3. 🔴 Rủi ro lớn nhất còn lại: cả 3 node trên MỘT máy vật lý, `pg_dump` cũng đổ vào PVC trên
   chính máy đó → chưa phải backup


---

# Addendum 2 (cùng ngày) — rev 3: bỏ subnet router, relay + message queue trên host

## Yêu cầu mới của user

"Không muốn mở subnet trên Tailscale để máy ngoài gọi thẳng đến worker node. Design lại 1
service container chạy trên host devops-pc dùng message queue, khi nhận data mới thì ghi vào
anmates-db trong k8s."

## Sự thật làm thiết kế này chạy được

**devops-pc VỐN ĐÃ ở trên virbr0 — nó chính là gateway `192.168.122.1`.** Host với tới VM mà
không cần route nào. Cái duy nhất thiếu là đường cho các máy *khác*, và đó chính là thứ user
không muốn mở. Nên: đặt dịch vụ ngay trên host, nơi đã sẵn hai chân ở hai mạng.

Kết quả: tailnet chỉ thấy `devops-pc:8443`. Dải `192.168.122.0/24` KHÔNG quảng bá →
kubelet/etcd/API server vô hình với mọi thiết bị tailnet. NodePort 30432 vẫn tồn tại nhưng chỉ
host đi tới được.

## Kiến trúc `anm-relay`

Stack compose trên host (`/opt/anm-relay/`), 3 container + systemd unit:
- `ingest :8443` — bind ĐÚNG IP tailnet (không `0.0.0.0`), bearer token, trả `202` sau khi
  JetStream xác nhận ghi đĩa
- `nats` JetStream — file store trên đĩa host, `retention: workqueue`, `duplicate_window 24h`,
  `max_payload=8MB` (ảnh 3 MB → ~4 MB sau base64, mặc định 1 MB sẽ chặn)
- `writer` — pull consumer tuần tự (`max_ack_pending=1`), upsert + ghi sổ cùng transaction
- `nats-exporter` — bind CHỈ `192.168.122.1:7777` để Prometheus trong VM scrape ngược ra host
  qua gateway virbr0 (lại là hình học có lợi: VM với tới host được, không cần route)

**1 message = 1 quán**, ảnh đi subject riêng `venues.photo` với `Nats-Msg-Id = sha256`.
Không gộp lô vào một message: lô hỏng nửa chừng thì không biểu diễn được quán nào qua/không qua.
Dedup dùng `Nats-Msg-Id = source_ref:content_hash` — khớp đúng cơ chế hash `publish.py` đã có.

**Ba trạng thái, không có thứ tư:** ACK → synced · NAK+backoff (5s→30s→2p→10p, max 5) → quay
lại stream · quá 5 lần → `venues.dlq` + `outcome='failed'`, payload giữ nguyên để phát lại.
Writer phải TỰ đẩy sang DLQ ở lần giao cuối (đọc `num_delivered`) vì retention `workqueue` xoá
message khi vượt `max_deliver` — không trông vào advisory.

## Ranh giới code

Windows giữ `to_anmates()` + toàn bộ mapping (logic pipeline, còn đổi). Relay chỉ là cái bút:
upsert, ghi ảnh, ghi sổ. Hợp đồng JSON có `schema_version`, relay từ chối bản lạ.
`ANMATES_DB_URL` XOÁ khỏi máy Windows → **mật khẩu Postgres rời khỏi máy Windows**.

## Đắt hơn rev 2, và nói thẳng ra

| | rev 2 subnet router | rev 3 relay+queue |
|---|---|---|
| Bề mặt tailnet | cả dải VM | 1 host, 1 cổng |
| Bí mật trên Windows | mật khẩu DB | bearer token |
| Cụm sập | lần chạy fail | queue giữ, tự chảy |
| Thứ phải giữ sống | 0 | 3 container + systemd |
| Chỗ debug khi hỏng | 3 | 5 |
| Công code | ~40 dòng Python | dịch vụ mới + đổi Windows sang HTTP |

## Files changed (rev 3)

- `deploy/anm-relay/{docker-compose.yml,.env.example,anm-relay.service}` (**mới**)
- `anmates-api/db/migrations/015_sync_ledger.sql` — viết lại cho mô hình queue: `batch_id`,
  đếm `queued`/`dlq`, `outcome` thêm `'queued'`, tách `source_host`/`relay_host`
- `docs/plans/2026-09-05-sync-pipeline-onprem-1day.{md,html}` — viết lại toàn bộ

## Open follow-ups (rev 3)

1. **`anm-relay` chưa được viết** — mới có compose + unit + hợp đồng API. Cần một service
   nhỏ (Go hoặc Python) hiện thực `/batch`, `/batch/{id}/venue`, `/batch/{id}/photo`,
   `/batch/{id}/complete`, `/healthz` + writer loop
2. Đổi `sync_anmates.py` từ ghi DB sang POST (code mẫu ở runbook §R4) — chưa apply
3. Cổng kiểm soát #2 là cái quan trọng nhất: từ Windows `ping 192.168.122.11` phải KHÔNG tới,
   `curl https://devops-pc:8443/healthz` phải tới
4. Nếu rev 2 đã bật `--advertise-routes` thì phải TẮT: `sudo tailscale up --advertise-routes=`
   + xoá route trong admin console


---

# Addendum 3 (cùng ngày) — tách repo `AnMates-Data-Bridge`, đã push

## Repo mới

**https://github.com/AnMatesStudio/AnMates-Data-Bridge** (PRIVATE, branch `main`).
Local: `/Users/thanhit/AnMatesStudio/AnMates-Data-Bridge`.

Tên: user đề xuất `AnMates-Data-Bridge` / `AnMates-Data-Queue` → chọn **Bridge** vì nó bắt cặp
với `Data-Pipeline` (pipeline sinh ra, bridge chở qua) và mô tả cả hệ thống, còn "queue" chỉ
là một bộ phận bên trong. Trước đó đã đặt `anmates-conduit`, user yêu cầu đổi.

## Đã chuyển khỏi repo AnMates

| Cũ | Mới |
|---|---|
| `docs/plans/2026-09-05-sync-pipeline-onprem-1day.md` | `docs/architecture.md` |
| `docs/plans/2026-09-05-sync-pipeline-onprem-1day.html` | `docs/architecture.html` |
| `deploy/anm-relay/*` | `docker-compose.yml`, `.env.example`, `deploy/data-bridge.service` |

Chỗ cũ để lại **file con trỏ** `docs/plans/2026-09-05-sync-pipeline-onprem-1day.md` chỉ sang
repo mới. `deploy/anm-relay/` đã xoá.

## CỐ Ý Ở LẠI repo AnMates

`anmates-api/db/migrations/014_pipeline_source.sql` + `015_sync_ledger.sql`. Chúng đi vào
binary `api` qua `//go:embed migrations/*.sql` trong `anmates-api/db/migrate.go` — tách ra
khỏi repo đó là migration runner không thấy nữa. Ghi rõ trong README của repo mới và trong
file con trỏ.

## Nội dung repo mới

- `docker-compose.yml` — `name: bridge`, 3 service: `nats` (JetStream file store,
  `--max_payload=8MB`), `bridge` (build tại chỗ), `nats-exporter` (bind CHỈ `192.168.122.1:7777`)
- `bridge/app/` — service THẬT, không phải skeleton: `config.py`, `streams.py` (khai báo
  stream/consumer idempotent), `main.py` (FastAPI ingest, NDJSON stream, bearer + hmac compare,
  `schema_version` 409), `writer.py` (2 consumer tách nhau + batch-then-isolate + DLQ),
  `db.py` (upsert + photos + ledger CÙNG transaction)
- `client/bridge_client.py` — thả vào `Data-Pipeline/serving/` trên Windows
- `docs/RUNBOOK.md` — setup 2 máy, 6 cổng kiểm soát, phần E vận hành + phần F troubleshooting
- `docs/api-contract.md` — hợp đồng JSON, `schema_version` là hàng rào chống lệch repo
- `Makefile` — `make up/health/streams/reset-dlq`; `make health` kiểm cả bind address

## Bốn tối ưu từ lượt trước đã gấp vào thiết kế

1. **Hai consumer tách nhau** (`venue-writer` / `photo-writer`) — venue là thứ UI cần để hiện
   quán và ghi trong một `execute_values`; ảnh ~4 MB base64 và API còn chưa đọc tới. Quán
   xuất hiện sau vài giây thay vì đợi hết cả trăm ảnh.
2. **NDJSON stream** cho ingest — 1 bắt tay TLS thay vì N.
3. **Batch-then-isolate** ở writer — lô 50 venue bằng một `execute_values`; lô hỏng thì thử
   lại từng cái để cô lập, giữ nguyên granularity per-venue mà dashboard dựa vào.
4. `PHOTO_INFLIGHT=3` — pod `anmates-db` có `limits: cpu "1"`, quá 3-4 song song chỉ đổi thời
   gian chờ thành tranh chấp CPU.

**Chưa gấp:** trigger-on-approval (thay nhịp poll 15 phút) — đây là đòn bẩy LỚN NHẤT cho độ
trễ hiển thị (~7,5 phút trung vị) nhưng nằm ở phía Data-Pipeline, chưa làm.

## Verification

Đã verify: `docker-compose.yml` parse bằng pyyaml, tên image viết thường, mọi `.py` parse
bằng `ast`, repo push thành công (PRIVATE). **Chưa verify:** chưa chạy `docker compose up`
lần nào (máy này không có cụm/host), chưa có kết nối NATS hay Postgres thật nào được mở.

## ⚠️ Thay đổi CHƯA COMMIT trong repo AnMates

`014_pipeline_source.sql`, `015_sync_ledger.sql`, file con trỏ ở `docs/plans/`, và toàn bộ
shared-memory. Cố ý không commit — user chưa yêu cầu commit repo AnMates. Migration phải
được commit + CI + `helm upgrade` thì mới có schema (RUNBOOK §B3).


---

# Addendum 4 — rev 4: RabbitMQ + MetalLB + OpenTelemetry (đã push)

User đưa 6 bước luồng yêu cầu, docs cũ không khớp → viết lại toàn bộ repo
`AnMates-Data-Bridge`. Commit `fe9bce3`.

## Ba thay đổi kiến trúc

1. **NATS JetStream → RabbitMQ 3.13 quorum queue.** PC A publish **thẳng AMQP :5672**, bỏ lớp
   HTTP ingest FastAPI của rev 3. Lý do bỏ được: user AMQP đã là bí mật thu hồi được và phân
   quyền được, nên không cần một tiến trình đứng trước chỉ để giữ mật khẩu DB khỏi PC A.
   `schema_version` chuyển sang writer kiểm rồi đẩy DLQ. Ít hơn một tiến trình, ít hơn một chỗ hỏng.
2. **NodePort → MetalLB LoadBalancer** `192.168.122.240`. Bỏ được việc ghim IP VM bằng DHCP
   static lease; IP dịch vụ ổn định kể cả khi pod dời node.
3. **OpenTelemetry từ ngày 1** — traces + metrics + logs qua OTLP, collector trên host,
   Prometheus/Loki/Tempo trong cụm đọc ngược ra qua gateway virbr0.

## Hai cái bẫy đã verify bằng cách đọc repo, không đoán

- **MetalLB CHƯA được cài ở đâu cả.** `anmates-infra/charts/network/Chart.yaml` chỉ có
  ingress-nginx + cert-manager; `environments/onprem/network/values.yaml` ghi rõ *"MetalLB cũng
  đã bị cắt khỏi MVP"*. Đây là bước cài mới (runbook §B3), không phải bật cờ có sẵn.
- **Dải MetalLB phải nằm ngoài dải DHCP libvirt.** MetalLB L2 quảng bá ARP trên virbr0; libvirt
  mặc định lấy gần hết `.2–.254`. Phải `virsh net-update default modify ip-dhcp-range` thu hẹp
  xuống `.2–.199` **trước**, rồi mới cấp `.240–.250` cho MetalLB. Làm ngược thứ tự → cấp trùng
  IP, lỗi hiện ra ngẫu nhiên vài ngày sau. Runbook §B2 làm đúng thứ tự.

## Đánh đổi phải chấp nhận

**RabbitMQ core không có dedup** như `Nats-Msg-Id` của JetStream. Bù bằng **lọc gia tăng ở
nguồn** theo `foodrec.updated_at` — `Data-Pipeline/serving/README.md` đã tài liệu hoá đúng mẫu
này (*"Store the largest updated_at you have seen and ask only for what changed"*). Lọc ở nguồn
rẻ hơn dedup ở đích vì bản không đổi không tốn cả băng thông lẫn message.

**RabbitMQ không có backoff sẵn** → dùng mẫu chuẩn: nack → `anmates.sync.retry` → queue TTL 30s
không consumer → dead-letter **ngược** về exchange chính. App tự `sleep` thì giữ luôn connection
và prefetch slot. Bộ đếm số lần giao dùng `x-delivery-limit` của **quorum queue** — của broker,
không phải của app, nên writer restart không mất số.

## Yêu cầu #5 — log kết quả: ba đích, không đích nào thay được hai đích kia

| Đích | Trả lời câu hỏi |
|---|---|
| dòng log JSON có `trace_id` | "lúc 14:03 chuyện gì xảy ra" — Loki tìm, nhảy sang trace |
| queue `sync.result` (TTL 7d) | "PC A tự đọc ngược về" — đóng vòng cho người vận hành phía Windows |
| bảng `sync_venue_state` | "quán nào **đang** kẹt và kẹt bao lâu" |

## Yêu cầu #6 — observability hai giai đoạn vì ngân sách RAM

Cụm 13.90 Gi allocatable. `environments/full/observability` (Mimir/Loki/Tempo **distributed**)
request ~16.9 Gi → không schedule nổi. Nhưng bản **single-binary thì vừa**:
GĐ1 = rabbitmq_prometheus + OTel collector + Loki single-binary (~1 Gi) → logs;
GĐ2 = Tempo monolithic (~1 Gi) → traces + APM view. Sau GĐ2 vẫn còn ~9 Gi headroom.
`otel.setup()` cố ý **không chặn khởi động** nếu collector chưa có — observability không được
phép thành phụ thuộc cứng của đường ghi dữ liệu.

## Files

- `docker-compose.yml` — rabbitmq (hostname **ghim** `anmates-mq`: đổi hostname = mất queue;
  `disk_free_limit 2GB` để đĩa đầy không kéo theo 3 VM) + writer + otel-collector
- `writer/app/` — `topology.py` (exchange/queue idempotent), `consumer.py` (batch-then-isolate
  cho venue, per-message cho ảnh, retry/DLQ), `otel.py` (JSON log có trace_id), `db.py` (chép
  nguyên từ `bridge/app/db.py`, thuần psycopg2)
- `client/anmates_publisher.py` — publisher confirms + `delivery_mode=2`
- `docs/networking-topology.html` (**mới**, yêu cầu #3) — sơ đồ + bảng cổng
- `docs/architecture.html` — **xoá** (bản vẽ rev 3, sẽ lạc hướng người đọc)
- `bridge/README.md` — đánh dấu code NATS là DEPRECATED, giữ để đối chiếu

## Verification

Đã verify: compose parse bằng pyyaml (3 service), mọi `.py` parse bằng `ast`, quét không có
chuỗi bí mật nào bị staged, push thành công. **Chưa verify:** chưa `docker compose up` lần nào,
chưa có kết nối RabbitMQ/Postgres thật, chưa cài MetalLB.
