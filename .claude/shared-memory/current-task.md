# Current Task

**Status (2026-09-06) — Fix thu tu thumbnail Data_Pipeline→AnMates + rig test 1 may:**
Va 3 bug: (1) `drop_unsendable_photos()` khong renumber sau khi loc anh trung/qua
kho -> de lo hong `position`, Flutter duyet tuan tu bi 404 mat anh; (2) `write_photo()`
khong xu ly case reorder (cung sha256, position moi) -> anh ket vinh vien o slot cu;
(3) (phu, phat hien khi verify) `ensure_batch()` thieu `schema_ver` -> **MOI lan ghi
cua writer chet**, khong lien quan thumbnail nhung chan dung toan bo duong ghi.
Ca 3 da vá + verify bang du lieu that qua rig 1 may moi (xem
`AnMates-Data-Bridge/docs/LOCAL_TESTING.md`) toi tan API `anmates-api` that
(`photo_count`, `/photos/:position`). CHUA verify duoc Flutter UI thuc su (may nay
khong co Flutter SDK) — UI v2 hien tai cung moi chi render `photoUrls.first`, chua co
carousel nhieu anh nao dung toi danh sach day du. Xem
`sessions/2026-09-06-thumbnail-order-fix-and-local-test-rig.md`.

---

**Status (2026-09-03, tiep tuc) — Fix goc bug API_BASE_URL bake-in (3 lop) + search that tu DB:**
Sau khi deploy public qua Cloudflare Tunnel bi loi (feed rong tren dien thoai that), user
xac nhan fix + yeu cau them search that. Da sua CA 3 lop tung bake absolute host vao web
bundle: .env (API_BASE_URL=http://localhost:8080 leftover), docker-compose.yml build-arg
default, va Dockerfile ARG default — gio ca 3 deu rong, dung dung kien truc domain-agnostic
(Uri.base.origin runtime fallback) da co tu 2026-09-02.

Them GET /api/v1/venues?q= — search server-side that, khong dau tieng Viet (foldVN, dung
golang.org/x/text co san, khong can extension Postgres), khop ten lan dia chi. Flutter
search_overlay.dart doi tu loc client-side (cap 60 dong) sang goi API that co debounce
300ms, hien anh that trong ket qua.

Verified: unit test foldVN/matchesQuery PASS, golangci-lint 0 issues, flutter test 50/50,
search qua API va qua UI that (Playwright go chu that) deu dung, xac nhan hoat dong qua
ca localhost lan tunnel Cloudflare that.
Xem sessions/2026-09-03-v2-feed-real-db-data.md (phan 4: deploy + fix bake-in + search that).

---


**Status (2026-09-03, tiep tuc) — Anh quan that (DB blob, khong URL) + xoa SACH toan bo mock
data trong app (CHUA user-confirm):**
Sau khi fix bug 401, user yeu cau 2 viec tiep: (1) review cach luu anh, doi tu URL sang
base64 luu thang DB; (2) "Xoa het data mockup, data gia di, lay data that thoi" — ap dung
cho CA app, khong chi venue.

**Anh quan (Phan 2):** root cause anh chet la Data_Pipeline publish.py rewrite path local
thanh URL qua ngrok tunnel cua may chay pipeline — tunnel dong la chet het. Fix: doc bytes
NGAY LUC publish (con file that de doc), base64-encode, luu ca hai ben (Data_Pipeline
serving DB + AnMates qua migration 014 bang `venue_photos`). Endpoint moi
`GET /venues/:id/photos/:position` public, ETag=sha256. Da chay that: 119 anh dong bo,
xac nhan JPEG that (bun bo Hue tu TikTok, 144KB).

**Xoa mock data (Phan 3):** phat hien 3 service Flutter (`match_service.dart`,
`booking_service.dart`, `chat_socket.dart`) da viet xong production-ready nhung CHUA TUNG
duoc goi tu UI v2 — bi bo roi khi migrate v1->v2 (R-009). Hoi user ve 3 co che gia hoan
toan (Vibe-Check %, Trust Score gating, AI bill-split — 0 cot nao trong schema) qua
AskUserQuestion -> chon **xoa het, khong gate gi, khong xay backend moi cho 3 thu nay**.
Da noi that: Swipe/Mates (GET /matches - thuat toan wishlist-overlap co san), Chat (GET
/matches/:id/messages + gui that qua ChatSocket/WebSocket), Bill doi thanh man Booking that
(GET /matches/:id/booking). Xoa "Yuna" hardcode (dung lam TEN NGUOI DUNG HIEN TAI o 2 man
hinh) -> `profileName` that. Cac tinh nang KHONG co backend (Notifications, Local Mates, My
Reviews, Visited, Trust Score history) -> honest-empty state, KHONG xay tinh nang moi.

**Bug tu phat hien qua Playwright that:** header chat hien "—" sau khi match vi thu tu xoa
candidate truoc khi luu ten - da fix bang `_activeMate`/`chatPartner`. Verified full loop
that: swipe -> POST /swipes matched:true -> match that trong DB -> chat that -> go tin nhan
that qua WebSocket -> xac nhan da luu qua GET messages lai. golangci-lint 0 issues, flutter
test 50/50.

**Chua lam (co y, ngoai pham vi "xoa data gia"):** xay backend that cho Notifications/Local
Mates/Reviews/Trust Score/Bill-split (do la tinh nang moi, khong phai don dep data); noi
filter khu vuc/gia/vibe vao query.
Xem sessions/2026-09-03-v2-feed-real-db-data.md (phan 2 + phan 3).

---


**Status (2026-09-03) — UI v2 load quán THẬT từ DB (code done, CHƯA user-confirm):**
User: *"app đang dùng mockup data, hãy thay đổi và load data từ real DB. Hãy check DB có
data chưa trước khi load"*. Check trước: bảng `restaurants` có **34 dòng** (16 `seed` +
18 `pipeline`) — có data thật.
**Phát hiện chính:** không route nào expose bảng `restaurants` (`/venues/search` = web-search
sidecar, `/venues/nearby` = TomTom/Goong, `/venues/image` = Foursquare). `VenueEngine.
SearchCandidates` có đọc DB nhưng chỉ concierge gọi → feed v2 buộc phải giữ mock của design.
**Đã làm:** thêm `GET /api/v1/venues` (DB-backed, luôn bật) + `VenueCatalogService` +
`v2_venue_mapper.dart`; **xoá `kPlaces` + `kVenues`** khỏi `v2_data.dart`; feed / search
overlay / chip lọc khu vực / màn chi tiết đọc `V2State.venues`. Có loading + lỗi + rỗng
(nút Thử lại), **không fallback về sample row**. Thiếu rating/giá/địa chỉ → `—` hoặc bỏ dòng,
không bịa.
**Verified:** golangci-lint v2.12.2 → 0 issues · flutter analyze 8 info (= baseline) ·
flutter test **38/38** · browser thật: `200 /api/v1/venues?limit=60 → 34 venues`, feed hiện
Bánh Mì Huỳnh Hoa ★4.5 45–75k / Bánh Xèo 46A ★4.5 70–130k / Bún Bò Giáo Toàn ★4.6 50–90k —
khớp row DB. Screenshot: scratchpad `shots4/{feed_2,detail}.png`.
**⚠️ Đã tự gây bug rồi sửa trong cùng session:** route ban đầu đặt sau `api.Use(jwtMW)` →
browser thật (không token, vì UI v2 chưa có login) nhận 401 → feed rỗng, user báo *"sao không
thấy data gì hết vậy?"*. Miss vì script Playwright tự seed token. Đã chuyển `/venues` sang
public (`api.Get` trước `api.Use(jwtMW)`), verify lại **không token → 200 + 34 quán**, các
route user-scoped vẫn 401. **Luôn probe API bằng session KHÔNG token trước khi báo done.**
**Chưa làm (cố ý):** ảnh quán thật (`photos` của 18 dòng pipeline trỏ ngrok đã chết; cần
`FOURSQUARE_KEY`); các bảng mock còn lại (`kMates`, `kNotifs`, `kTiers`, `kBill`, `kTrustLog`,
`kLocals`, `kVisited`, `kMyReviews`) — DB chưa có dữ liệu tương ứng; filter chưa nối vào query.
Xem sessions/2026-09-03-v2-feed-real-db-data.md.

---

**Status (2026-09-05, rev 4 + sửa mạng) — `AnMates-Data-Bridge` viết lại theo 6 bước luồng user, đã push, CHƯA chạy thật:**
**https://github.com/AnMatesStudio/AnMates-Data-Bridge** (PRIVATE) · commit `fe9bce3` · local
`/Users/thanhit/AnMatesStudio/AnMates-Data-Bridge`.
**Luồng:** PC A (Data-Pipeline/Windows) → publish **AMQP :5672** qua Tailscale → **RabbitMQ**
container trên PC B (devops-pc, KVM host) → **writer** → **VIP ingress-nginx `10.10.10.200:5432`** (tcp-services → ClusterIP) → `anmates-db` pod → log kết quả → Grafana (sau).
**Đổi so với rev 3:** NATS→RabbitMQ quorum queue · bỏ lớp HTTP ingest (PC A nói AMQP thẳng) ·
NodePort→MetalLB · thêm OTLP traces+metrics+logs.
**MẠNG THẬT: `virbr1` = `10.10.10.0/24`, gateway `10.10.10.1`** (không phải virbr0/192.168.122.x).
**BỐN CÁI BẪY, đọc kỹ trước khi làm:**
1. **MetalLB CHƯA cài ở đâu cả** — `anmates-infra/charts/network` chỉ có ingress-nginx +
   cert-manager. Runbook §B3 là bước cài mới.
2. **Mạng libvirt gắn `virbr1` KHÔNG tên `default`** — `default` là của `virbr0`. Dò tên thật ở runbook §A1 rồi dùng `$K8S_NET`, đừng gõ `default`.
3. **KHÔNG viết `Ingress` resource cho Postgres** — Ingress là HTTP/HTTPS, apply thành công nhưng không có gì xảy ra. Phải dùng ConfigMap `tcp-services` (§B4).
4. **Thu hẹp dải DHCP libvirt TRƯỚC khi cài MetalLB** — `virsh net-update default modify
   ip-dhcp-range` về `.2–.199`, chừa `.200–.250` (dải VÍ DỤ — đọc dải thật bằng `virsh net-dumpxml`). Làm ngược thứ tự → cấp trùng IP, lỗi hiện
   ngẫu nhiên vài ngày sau. Runbook §B2.
**NEXT (user):** `docs/RUNBOOK.md` — A (PC B: RabbitMQ, kiểm bind ≠ 0.0.0.0) → B (ACL, thu hẹp
DHCP, cài MetalLB, svc LoadBalancer, migration 014+015) → C (bật writer) → D (PC A: `pip install
pika`, copy `anmates_publisher.py`, xoá `ANMATES_DB_URL`, đổi `sync_anmates.py`) → E (verify +
test tắt DB 2 phút) → F (observability GĐ1).
**Chưa làm:** chưa `docker compose up` lần nào · chưa cài MetalLB · Loki/Tempo (GĐ1/GĐ2) ·
trigger-on-approval (đòn bẩy lớn nhất cho độ trễ hiển thị, ~7,5 phút trung vị).
**⚠️ Repo AnMates có thay đổi CHƯA COMMIT:** 014, 015, con trỏ `docs/plans/`, shared-memory.
Xem sessions/2026-09-05-sync-data-pipeline-onprem-1day.md (Addendum 4).

---

**Status (2026-09-05) — `AnMates-Data-Bridge` đã tách repo và push (PRIVATE), CHƯA chạy thật:**
**https://github.com/AnMatesStudio/AnMates-Data-Bridge** · local
`/Users/thanhit/AnMatesStudio/AnMates-Data-Bridge`.
Chở quán đã duyệt từ Data-Pipeline (Windows) qua tailnet vào `anmates-db`, KHÔNG mở subnet:
`bridge :8443` bind đúng IP tailnet trên devops-pc → NATS JetStream → writer → NodePort 30432
(chỉ host với tới, vì devops-pc vốn đã là gateway virbr0 `192.168.122.1`).
**Trong repo mới:** compose 3 service, service thật (`bridge/app/`), client cho Windows
(`client/bridge_client.py`), `docs/RUNBOOK.md` setup 2 máy với 6 cổng kiểm soát.
**Ở LẠI repo này:** `anmates-api/db/migrations/014_pipeline_source.sql` + `015_sync_ledger.sql`
— đi vào binary api qua `//go:embed`, tách ra là migration runner không thấy.
**NEXT (user):** theo `docs/RUNBOOK.md` — Phần A (devops-pc: ghim IP VM, `.env`, `make up`,
systemd) → B (ACL 1 dòng, TẮT `--advertise-routes` nếu từng bật, commit+CI+helm cho migration,
NodePort) → C (Windows: clone repo, copy client, xoá `ANMATES_DB_URL` khỏi `.env`, sửa
`sync_anmates.py` bỏ `upsert`/`sync_photos`) → D (verify + bài test tắt DB 2 phút).
**Cổng quan trọng nhất (#B):** từ Windows `ping 192.168.122.11` phải KHÔNG tới,
`curl -k https://devops-pc...:8443/healthz` phải tới.
**Chưa làm:** chưa `docker compose up` lần nào; trigger-on-approval (đòn bẩy lớn nhất cho độ
trễ hiển thị, ~7,5 phút trung vị) nằm phía Data-Pipeline, chưa làm.
**⚠️ Repo AnMates có thay đổi CHƯA COMMIT:** 014, 015, file con trỏ `docs/plans/`, shared-memory.
Xem sessions/2026-09-05-sync-data-pipeline-onprem-1day.md (Addendum 3).

---

**Status (2026-09-05, rev 3) — Relay + message queue trên devops-pc (design done, service CHƯA viết):**
User không muốn mở subnet Tailscale cho máy ngoài gọi thẳng worker node → **bỏ subnet router**.
Điểm xoay: devops-pc VỐN ĐÃ là gateway virbr0 `192.168.122.1`, host với tới VM không cần route
nào; chỉ các máy *khác* mới thiếu đường. Nên đặt dịch vụ ngay trên host.
**Kiến trúc `anm-relay`** (compose trên `/opt/anm-relay/`, systemd giữ sống): `ingest :8443`
bind ĐÚNG IP tailnet + `nats` JetStream file-store (`workqueue`, dedup 24h, `max_payload=8MB`)
+ `writer` tuần tự + `nats-exporter` bind chỉ `192.168.122.1:7777`. Tailnet chỉ thấy 1 host 1
cổng; dải `192.168.122.0/24` KHÔNG quảng bá.
**1 message = 1 quán**, ảnh subject riêng `Nats-Msg-Id=sha256`, dedup `source_ref:content_hash`.
Ba trạng thái: ACK → synced · NAK+backoff → quay lại stream · quá 5 lần → `venues.dlq` +
`outcome='failed'`. Writer TỰ đẩy DLQ ở lần giao cuối (workqueue xoá message khi vượt max_deliver).
**Được thêm:** mật khẩu Postgres rời khỏi máy Windows (chỉ còn bearer token); cụm sập vẫn nhận
được, queue giữ hộ. **Giá:** 3 container phải giữ sống, 5 chỗ debug thay vì 3, state trên đĩa host.
**CHƯA LÀM:** (1) service `anm-relay` chưa viết — mới có compose + unit + hợp đồng API;
(2) `sync_anmates.py` chưa đổi từ ghi DB sang POST (code mẫu ở runbook §R4).
**NEXT (user):** 6 cổng kiểm soát trong `docs/plans/2026-09-05-sync-pipeline-onprem-1day.md`.
Quan trọng nhất là **#2**: từ Windows `ping 192.168.122.11` phải KHÔNG tới, còn
`curl https://devops-pc:8443/healthz` phải tới. Nếu rev 2 đã bật `--advertise-routes` thì TẮT.
Xem sessions/2026-09-05-sync-data-pipeline-onprem-1day.md (Addendum 2).

---

**Status (2026-09-05, rev 2) — Tuyến sync Data-Pipeline → catalog on-prem + lớp quan sát (design done, PENDING user chạy trên cụm):**
⚠️ **devops-pc là KVM host, KHÔNG phải node của cụm.** Node k8s là VM sau libvirt NAT
(`virbr0`, mặc định `192.168.122.0/24`). Tailscale chạy trên host, NodePort nghe trên IP VM →
gói tin gửi tới `devops-pc.tail795b47.ts.net:30432` **dừng ở netstack của host**. Phương án
rev 1 không chạy được.
**Chốt transport:** devops-pc làm **subnet router** — `sudo tailscale up
--advertise-routes=192.168.122.0/24` + `net.ipv4.ip_forward=1` + Approve route trong admin
console. Windows nối thẳng `192.168.122.<node>:30432`. **Ghim static lease cho VM TRƯỚC khi
tạo NodePort** (`virsh net-update default add ip-dhcp-host`).
**Chốt quan sát:** 2 bảng sổ trong `anmates-db` (`015_sync_ledger.sql`) + Grafana datasource
Postgres qua ClusterIP. Không Pushgateway/exporter. Panel quan trọng nhất: bảng "quán chưa qua
được" (lý do nguyên văn + số ngày kẹt).
**Migration:** `014_pipeline_source.sql` + `015_sync_ledger.sql` đi qua `go:embed`, phải commit
+ CI + `helm upgrade`, **không** `kubectl exec psql`.
**NEXT (user):** 7 cổng kiểm soát trong `docs/plans/2026-09-05-sync-pipeline-onprem-1day.md` —
#A ping VM · #B psql tới `:30432` · #1 schema · #2 dry-run 25/1/0 · #C `sync_runs.ok=true` ·
#D dashboard hiện 1 dòng kẹt · #3 count = 25.
**Chưa làm:** vá `sync_anmates.py` (~40 dòng, code có sẵn ở runbook §M1) — repo Data-Pipeline
riêng, để user review. Xác nhận dải virbr0 thật.
Xem sessions/2026-09-05-sync-data-pipeline-onprem-1day.md (có Addendum rev 2).

---

**Status (2026-09-05) — Tuyến sync Data-Pipeline → catalog on-prem, bản 1 ngày (design done, PENDING user chạy trên cụm):**
Chốt **NodePort qua tailnet** (`svc/anmates-db-tailnet`, NodePort 30432, khoá bằng ACL Tailscale),
KHÔNG dùng Tailscale k8s operator ở ngày 1 — theo đúng logic plan 2026-09-01 §0 và ràng buộc
"user gõ tay mọi lệnh". Sync vẫn chạy trên máy Windows bằng Scheduled Task đã có; chỉ đổi
`ANMATES_DB_URL` trong `Data-Pipeline/.env`, không sửa code Python.
**Chặn cứng đã tìm ra:** `restaurants.source` CHECK chưa nhận `'pipeline'`, thiếu unique index
`(source, source_ref)`, chưa có bảng `venue_photos` — `serving/README` dặn apply
`013_pipeline_source.sql` nhưng file đó không tồn tại và số 013 đã bị `013_seed_admin.sql` chiếm.
Đã viết **`anmates-api/db/migrations/014_pipeline_source.sql`**. Migration chạy qua `go:embed`
lúc `api` boot → phải commit + CI + `helm upgrade`, **không** `kubectl exec psql`.
**NEXT (user):** 4 cổng kiểm soát trong `docs/plans/2026-09-05-sync-pipeline-onprem-1day.md` —
(1) `\d restaurants` thấy `'pipeline'` + có `venue_photos`; (2) từ Windows `psql` tới `:30432`;
(3) `doctor` 5/5 + `--dry-run` ra 25 upsert / 1 skip / 0 lỗi; (4) `count(*) WHERE source='pipeline'` = 25.
**Cần xác nhận:** `devops-pc` có phải node của cụm không (cả runbook giả định thế).
Xem sessions/2026-09-05-sync-data-pipeline-onprem-1day.md.

---

**Status (2026-09-02, cache) — R-010: fix cache policy nginx, PENDING verify trên prod:**
Sau khi deploy v2, domain vẫn ra UI v1. Root cause đã confirm (user purge → v2 hiện ngay):
`nginx.conf` gắn `immutable, max-age=30d` cho `.js`, mà Flutter **không hash tên file** nên
Cloudflare edge giữ `main.dart.js` cũ 30 ngày. Đã sửa: `max-age=7200` (2h, trùng default
Cloudflare), bỏ `immutable`, bỏ `expires` (tránh gửi trùng Cache-Control), thêm `otf`.
Giữ nguyên việc cache `.js` — bundle 2.64 MB, bỏ cache là mỗi page load kéo lại qua tunnel.
**NEXT:** deploy → soi header của `main.dart.js` (KHÔNG phải `/`), kỳ vọng
`cache-control: public, max-age=7200` và không còn `immutable` → confirm → cập nhật R-010.
Nếu muốn staleness = 0: cần cache-bust URL bằng `?v=<git-sha>` (post-build sed trong CI), chưa làm.

---

**Status (2026-09-02) — R-009 CLOSED: UI v2 duyệt, xoá sạch UI v1:**
User đã xem UI v2 (build web + `flutter run -t lib/main_v2.dart`), báo 2 bug (lưới gu món
hàng 2/4 bị cắt mép; màn Quẹt không kéo được + nút bị nav che) — cả hai đã fix và verify.
User confirm bằng cách yêu cầu bước tiếp theo: **"xóa toàn bộ UI cũ sạch sẽ nhất chỉ giữ lại
phần nào có thể sử dụng tiếp vào new UI v2"**.
Đã xoá: `lib/views/*` (trừ `v2/`), `lib/widgets/*` (trừ `v2/`), `lib/theme/app_theme.dart`,
`assets/{food,avatars,icons}/`, `lib/main_v2.dart`, `integration_test/app_test.dart`.
Đã giữ: `lib/services/*` (18 file, verify 0 import ngược từ views/widgets), `lib/models/*`,
`lib/utils/*`, `lib/firebase_options.dart`, `lib/theme/app_theme_v2.dart`, `lib/views/v2/*`,
`lib/widgets/v2/*`. `lib/main.dart` viết lại làm entry point duy nhất → `V2App`.
**Verified:** flutter analyze 0 lỗi, flutter test -j1 22/22 pass (⚠️ `flutter test` không có
`-j1` silently drop 2 file test khi chạy song song trong sandbox này — không do session gây ra,
luôn dùng `-j1` để verify chính xác), `flutter build web --release` (entry mặc định) OK, đã
serve local + user duyệt trên browser.
**Chưa làm** (out of scope, cố ý): rename `_v2` suffix (AppColorsV2/V2App/...) giờ là UI duy
nhất nhưng risk cao nếu đổi không được yêu cầu; audit/prune pubspec dependencies không còn cần.
Xem R-009 (đầy đủ bug list + gotchas) + sessions/2026-09-02-explore-v2-design-import.md.

---


**Status (2026-09-02, phần 2) — CI/CD gộp 3 workflow → 1 `ci.yml` + bỏ hẳn `ANMATES_DOMAIN` (code done, PENDING lần chạy CI thật):**
User đã tự config DNS + Cloudflare Tunnel → yêu cầu xoá biến `ANMATES_DOMAIN` và tối
ưu pipeline. Đã bỏ luôn `API_BASE_URL` khỏi build web: `auth_service.dart` default
đổi từ URL Cloud Run cũ → rỗng, runtime fallback `Uri.base.origin` (web) /
`http://localhost:8080` (native) → **image web domain-agnostic**, đổi DNS không cần
build lại, không còn GH variable nào. Gộp `ci-build-push.yml` + `ci.go-api.yml` +
`ci.flutter-web.yml` → **1 file `.github/workflows/ci.yml`** (2 lane song song
`api`/`web`, PR build không push, main push GHCR, job cuối in lệnh helm).
**Win build-time lớn nhất:** web image không compile Flutter trong Docker nữa (bỏ pull
image SDK ~4GB) — CI build bundle trên runner rồi đóng gói bằng
`anmates_flutter/Dockerfile.prebuilt` (nginx + COPY). `Dockerfile` cũ giữ nguyên cho
`docker compose`/`start.sh` local.
**Verified:** flutter analyze 0 lỗi · test 23/23 · `flutter build web` không cần
API_BASE_URL OK (bundle không còn URL Cloud Run) · go vet+test pass · ci.yml parse OK.
Docker build CHƯA chạy thật (máy không có docker daemon) → lần CI đầu là bằng chứng.
⚠️ **User cần làm:** nếu branch protection đang require status check theo tên cũ
(`Lint + Test`, `Docker build (no push)`, `Analyze + Test + Build web`) → đổi sang
`Go API` / `Flutter Web`, nếu không PR sẽ treo chờ check không bao giờ chạy.
See sessions/2026-09-02-admin-password-login-remove-phone-otp.md (Addendum 2).

---

**Status (2026-09-02) — Login flow đổi sang admin/admin password login, bỏ Firebase phone OTP (code done, static-verified, PENDING user live-confirm + helm upgrade):**
User báo lỗi `ClientException: Failed to fetch, uri=https:///api/v1/auth/email/request-otp`
trên pod k8s. Root cause: `ANMATES_DOMAIN` (GH repo var, PI-17) chưa set → CI bake
`API_BASE_URL=https://` (thiếu host) vào build web → mọi request "Failed to fetch".
Fix: 2 workflow (`ci-build-push.yml`, `ci.flutter-web.yml`) fallback về `API_BASE_URL`
rỗng (relative same-origin, nginx đã proxy `/api/` sẵn) khi domain chưa set.
User đồng thời yêu cầu **đổi flow login = username: admin / password: admin**, bỏ
Firebase phone OTP hoàn toàn. Đã làm: wire `AuthView` (email+password, có sẵn nhưng
mồ côi) làm entry thay `PhoneInputView`; migration `013_seed_admin.sql` seed user
`admin`/`admin` (bcrypt, `onboarding_done=true`); xoá `phone_input_view.dart` +
`otp_view.dart` + `auth_error_messages.dart` (Firebase phone OTP) + `email_input_view.dart`
+ `email_otp_view.dart` (mồ côi sau khi bỏ entry point); bỏ package
`firebase_auth_platform_interface`; xoá `#recaptcha-container` khỏi `web/index.html`;
sửa `integration_test/app_test.dart` sang flow mới. **Verified:** flutter analyze 0
lỗi, flutter test 23/23, go build/vet/test (trừ `smoke` cần server sống — pre-existing).
⚠️ **LƯU Ý MÂU THUẪN với quyết định trước đó**: session 2026-09-01 (dòng dưới) ghi
"user yêu cầu bỏ Firebase Auth hoàn toàn, **chỉ Email OTP + tester quick-login**"
(không phải password admin/admin) — quyết định hôm nay của user rõ ràng/cụ thể hơn
(literal "username: admin, pass: admin") nên được ưu tiên, nhưng CẦN user xác nhận
đây đúng là hướng mới (không phải nhớ nhầm) trước khi coi R-xxx đã chốt.
Backend `PhoneVerify`/`RequestEmailOTP`/`VerifyEmailOTP` handlers vẫn còn (không xoá,
không dùng nữa) — hỏi user có muốn dọn luôn không.
**NEXT:** user chạy `helm upgrade` (rerun migration + rebuild web image) → test đăng
nhập admin/admin trên pod thật → confirm → viết R-xxx.
See sessions/2026-09-02-admin-password-login-remove-phone-otp.md.

---

**Status (2026-09-01) — Jira MCP đã authorize (Cline), bắt đầu thực thi project PI — chờ kết quả khám phá PI-1 từ PC host:**
Cline (VS Code) đã connect 2 Jira MCP server (OAuth 2.1, scopes `read:jira-work` + `write:jira-work`) và
verify đầy đủ project **PI** trên `anmatesstudio.atlassian.net` (cloudId `9b284e38-8718-4dc9-b91a-0d55873bd1d8`):
**14 epic PI-1→PI-14** khớp backlog đã tạo — PI-1 `[P0] Network Assessment & DNS/PKI Bootstrap` đang
**In Progress**, PI-2→PI-14 To Do. Gotcha ghi nhận: JQL phải bounded (unbounded bị chặn); Confluence API
404 (thiếu scope/chưa bật); 54 issue cũ project **Tech** vẫn chờ user bulk-delete tay.
**NEXT (không đổi):** user chạy lệnh khám phá PI-1 trên PC host thật (`lsblk`, `df -h`, `virsh vol-list`,
chẩn đoán CGNAT) rồi paste kết quả — Cline/Claude Code tổng hợp, update Jira PI-1/PI-2 + shared-memory. **UPDATE 2026-09-01: PI-16 Done — chốt Cloudflare Tunnel (chỉ expose web pod qua tunnel, API backend internal trong cluster, không cần port-forward/CGNAT). Ticket đang làm: PI-17 (domain — cần cho Cloudflare DNS + tunnel hostname); PI-20 (kiểm toán đĩa) là ứng viên song song.**
Cả Cline lẫn Claude Code đọc session `sessions/2026-09-01-jira-mcp-authorize-replatform-kickoff.md`
trước khi làm tiếp để đồng bộ trạng thái.
---
**Status (2026-08-31) — DESIGN DUYỆT, chờ viết implementation plan: re-platform AnMates lên k8s on-prem.**
Sau 7 vòng brainstorm, spec đầy đủ đã ghi tại `docs/superpowers/specs/2026-08-31-onprem-k8s-replatform-design.md`
(810 dòng). **Chưa hiện thực gì — design only, chưa chạm code sản phẩm.**
Kiến trúc: Cloudflare (proxy, origin port 8443 né ISP chặn 443) → HAProxy ×2 L7 (Pi 4 MASTER +
VM bridge BACKUP) + VIP keepalived → MetalLB `10.10.10.200` → ingress-nginx → pod.
Cluster **MVP: 1 control-plane (4GB/2vCPU) + 2 worker (8GB/4vCPU)** trên KVM, giữ mạng
`10.10.10.0/24`. Worker #3 thêm khi bật observability đầy đủ (P8), KHÔNG phải khi tăng user —
host còn dôi 6 GB nên chỉ là tạo thêm VM, không reshape cụm.
Harbor · Vault trên host + ESO · GHA zero-secret qua GitHub OIDC · self-hosted runner chỉ
`docker build COPY` + `helm upgrade --atomic` · Longhorn replica 1 + MinIO + CNPG + PgBouncer +
Redis · 2 ns `anmates`/`anmates-dev` · Grafana LGTM · Ollama native trên host với GPU.
Mục tiêu 50 RPS (beta MVP). Ràng buộc: RAM headroom 5.89 Gi, **đĩa < 200 GB**.
**NEXT**: thực thi theo **project PI** ("Platform & Infrastructure") — **14 epic + 74 task (PI-1→PI-89)**
chia theo category+phase. Bắt đầu **PI-1** (khám phá mạng/tên miền) + **PI-2** (host) — cả hai
không phụ thuộc cụm. ⚠️ 54 issue cũ trong TECH cần user tự bulk-delete (MCP không có tool delete).
Cũ: Jira backlog project TECH — 11 epic + 43 task. **Bắt đầu ở [P0] TECH-61**
(TECH-53 chẩn đoán CGNAT · TECH-54 domain · TECH-62 Cloudflare credential) vì P1/P3 phụ thuộc ngược
vào nó. Cũ: 10 epic (TECH-10→19) + 41 task
(TECH-20→60), label `onprem-k8s`. Bắt đầu: TECH-20 (xác minh cụm) + TECH-21 (đo đĩa thật)
song song với TECH-45 (Flutter runtime config, 13 SP — đường tới hạn) và TECH-46 (bật redis_hub).
**Câu hỏi mở** (§16 của spec): dung lượng NVMe trống thực tế (chặn P0) · CGNAT hay public IP
thật (chặn P5) · số row `users` có phone nhưng không email (chặn P4) · IP tĩnh hay động · tên miền.
Xem sessions/2026-08-31-onprem-k8s-replatform-design.md

---

## Task trước đó (vẫn treo chờ user confirm in-app → R-008)

**Status (2026-06-14) — Venue-photo source decision: Google Maps API RULED OUT (VN-gated) → R-008; chosen path = headless Maps scrape → Firebase → DB (decided, NOT built, user starts tomorrow):** Goal = real "chính chủ" venue photos on Discovery list/detail keyed off the Goong venue, without Google Maps API and without generic web-search stock. Spent a long session trying **Google Places API (New)** as the source. **Fixed EVERY config gate** (billing Active+linked+Visa ••5073 Primary on "My Maps Billing Account"; key `…a6ycwA` Application restrictions=None + Places API (New) enabled & in allowlist; project `anmates`=number `748505933219` matched on Welcome page + Gemini `consumer`) — **yet ALL Google Maps Platform APIs still return 403 "caller does not have permission" / legacy "You must enable Billing"**, while **Cloud Storage (non-Maps GCP) SUCCEEDS in the SAME project+billing** (isolation test = smoking gun). Conclusion (user-agreed): **Maps Platform is country-gated for Vietnam** (mapping regulation) → NOT config/IAM/billing error → corroborates LOCKED "Google Maps PROHIBITED in VN → Goong". Durable evidence written to **R-008** (grep-able error strings) + session `2026-06-14-google-maps-api-blocked-vn-and-photo-scrape-decision.md`. **DO NOT re-attempt Google Maps/Places/Geocoding for this project.** Also evaluated: Foursquare Photos (key valid but Photos=Premium $18.75 CPM, no free tier → only viable with permanent per-venue cache; user found pricey) — kept as paid fallback, not chosen. **CHOSEN DIRECTION (user, start tomorrow):** Goong=venue data (working); photos = **headless-browser (Playwright) scrape of the Google Maps place panel, run from a RESIDENTIAL IP** → download bytes → **Firebase Storage** → store `{goong_id, firebase_urls, source, fetched_at}` in **Postgres** (new `venue_photos` migration), cache **permanently** (scrape ONCE/venue). **Feasibility live-probed 2026-06-14 (residential IP):** no CAPTCHA/consent/sorry; place photos served from **`lh{3,4,5,6}.ggpht.com`** (+ streetviewpixels); raw HTML lacks full photo URLs → **must headless-render JS** (`APP_INITIALIZATION_STATE` blob present). **HARD CAVEAT:** datacenter IPs (Cloud Run) → CAPTCHA (repo already proved 2026-06-11) → scrape runs residential only; permanent cache means production just reads DB; uncached new venues fall back to Bing/agentic (R-007)→placeholder. ToS/copyright re-host = user-accepted business risk. Build plan (TODO): (1) sidecar `GoogleMapsCrawler` reusing Playwright + new `/maps-photos`; (2) Go `POST /api/v1/venues/photos/ingest` → sidecar → download (SSRF-guard reuse) → Firebase upload → persist; (3) migration `venue_photos`; (4) serve DB-first → lazy-ingest → Bing fallback → placeholder; (5) Flutter thumbnails/hero read Firebase URLs. See R-008 + the session for full evidence + plan.

---

**Status (2026-06-13) — FEATURE "Bản đồ" tab: in-app Goong vector map + restaurant markers (code done, static-verified, pending in-app user confirm):** User asked for a Goong-Maps UI showing a map + recommended quán. Brainstormed → user chose **Goong tiles only** + **new 5th bottom tab**. Built it. **Finding:** Goong Maptiles is **VECTOR-only** (style `goong_map_web.json` 200; raster `.png` 404) → render its MapLibre style in **flutter_map** via **`vector_map_tiles`**. **Version is critical:** `vector_map_tiles 10.x` needs `flutter_gpu`+Flutter main channel (unusable on stable web-first) → pinned **`>=9.0.0-beta.9 <10.0.0`** (CPU/canvas renderer `vector_tile_renderer 6.1.0`, web-OK, keeps flutter_map 8.3.0). NEW `lib/views/map/map_view.dart` `MapView` (StyleReader `…?api_key={key}`+apiKey → `FlutterMap`+`VectorTileLayer`(TileOffset.mapbox)+`MarkerLayer` venue pins+user dot+recenter FAB+Goong attribution; venues reuse `PlacesService.getNearby` personalized list = the recommendations; tap pin→mini-card(`VenueThumbnail`+`OpenNowBadge`)→`VenueDetailView`; blank-key notice+style retry). `MainTabView` insert `MapView`@idx1; `AnmTabBar` 4→5 (Khám phá·**Bản đồ**·Wishlist·Chat·Ăn Match). Key plumbing: `kGoongMaptilesKey=String.fromEnvironment('GOONG_MAPTILES_KEY')`; local dart-define chain Dockerfile ARG→docker-compose build arg→start.sh export from `.env`; **CI/CD** (both flutter-web workflows) inject it as GH **secret** (done earlier today). **Verified:** flutter analyze 0 issues on changed files (9 pre-existing infos elsewhere); **flutter build web GREEN** (Wasm dry-run ok); tile pipeline live-probed (style/composite-pbf/sprite/glyphs all 200). **PENDING (user):** create GH secret `GOONG_MAPTILES_KEY` (for deploy) + `./start.sh` → tap **Bản đồ** tab → confirm tiles render + pins + tap→detail → then resolution. See sessions/2026-06-13-goong-map-tab-implementation.md + -goong-maptiles-ci-cd.md.

---

**Status (2026-06-13) — Discovery nearby list → Goong (pluggable provider) + onboarding-personalized keywords + Goong V2 (code done, live-probed via Go client, pending in-app user confirm):** User asked to switch the Discovery "quán ăn" list to Goong + get images via the API. Done over 3 rounds. (1) **Pluggable `NearbyProvider`** (TomTom | Goong by env `MAP_PROVIDER`, auto-prefers Goong) — NEW `services/nearby.go` (interface+factory+`NearbyVenue` moved here+haversine) + NEW `services/goong.go` `GoongClient`. (2) **Pure Goong, NO distance filter** (return ALL venues, sort-only) — user choice after live finding that Goong AutoComplete is name-matched + loosely location-biased (generic keywords → ~4-13 generic "Nhà Hàng" placeholders 3-7km out; user saw this & asked why < TomTom). (3) **Personalized keywords from onboarding** — NEW `services/food_keywords.go` `FoodKeywordsFromOnboarding(food,vibe,culture)` decodes the playful onboarding slang (fwb/ons/419/bx/ox/kr/jp/street/fancy…) → real VN **dish** keywords (deduped, cap 8); dish names appear in real venue names so the list now surfaces REAL venues. Backend-derived from the JWT user (`handlers/venue_nearby.go` + `ProfileLookup`=UserService) → **zero Flutter change**. (4) **Goong API V2** `/v2/place/{autocomplete,detail}` (same shapes; V2 detail `types`→amenity w/ keyword fallback). `Nearby` interface gained `keywords` arg (Goong uses, TomTom ignores); Goong cache key includes keywords. Flutter `places_service.getNearby` → provider-only, Overpass null-fallback; thumbnails unchanged (ride on Goong-accurate name+address). Env/CI updated (MAP_PROVIDER + GOONG_API_KEY, kept TomTom). **Verified:** go build/vet/test GREEN; golangci-lint v2.12.2 **0**; flutter analyze clean (5 pre-existing infos); places_merge_test 4/4; **live e2e via Go client with real key** → V2 + personalized keywords (beef/seafood/spicy/Korean/street user) → **14 real named venues** (Lẩu bò Bé Ba, Bò nướng tảng 5S, Lẩu Thái Hào Ký…) vs old 4 generic. **PENDING (user):** `./start.sh` → onboard w/ tags → open Discovery → confirm personalized+real list + thumbnails → R-008. NB user with no tags gets default keywords (generic). See sessions/2026-06-13-goong-nearby-provider.md + docs/specs/2026-06-13-goong-discovery-nearby.md.

---

**Status (2026-06-12) — Discover vibe filters made functional + live-verified by screenshot (code done, pending user "ok"):** User confirmed the Discovery screen looks good, then asked to make the vibe chips (Máy lạnh / Vỉa hè / Khuất hẻm / Sang chảnh / Ngồi khuya) actually filter (they were visual-only). Implemented multi-select **union** filtering: `OsmPlace` gained `airConditioning`/`outdoorSeating`/`stars` (parsed from OSM tags, additive); `discover_view.dart` now defaults to **no vibe selected** (initial list stays full), adds a vibe filter in `_filteredPlaces` + `_matchesVibe` (real OSM tags + name/cuisine/amenity heuristics; Ngồi khuya reuses `parseOpeningHours` probed at 23:00), re-pages on toggle, filter-aware empty state. **Verified LIVE** via host Chrome/Playwright (geolocation HCMC D1): 4 screenshots show correct reshaping — all→full list, Vỉa hè→Lotteria/KFC (street/fast-food), Ngồi khuya→bars + Nhà Hàng Alibaba "Đang mở", Sang chảnh→Cà Phê The Refinery/Mimi Ultra Lounge. `flutter analyze` clean on changed files; `places_merge_test` 4/4. Also captured the earlier Discovery+Detail real-photo screenshots (the prebuilt **api image was stale** — served `/venues/image` behind JWT; current source is public at main.go:235, so **rebuilt api** to restore the public image proxy — redeploy check worthwhile). Screenshots in `screenshots/0*.png` + `.dev-e2e/shots/`. See sessions/2026-06-12-discover-vibe-filters.md.

---

**Status (2026-06-11) — Agentic venue enrichment: realtime Google crawl + LLM-verified photos, image cache OFF (code done, static-verified, pending live confirm):** User opened venue detail "Surgeon Bbq Curry" (Singapore seed data) → hero photo was an **operating room**. Root cause: the Bing path's *string-match* relevance filter (`filterRelevantImages`) lets the token "surgeon" match surgery photos — no semantic notion of "food"; only an LLM can judge that. User asked to **(1) turn off image cache** and **(2) build an agentic AI crawling images+info realtime from Google**, choosing **headless-browser (Playwright)** scraping (warned: Cloud Run datacenter IPs → CAPTCHA → graceful Bing fallback). **Built a 3-layer slice.** Sidecar (ai-venue-search/): NEW `providers/google_scrape.py` `GoogleCrawler` (headless Chromium → google.com web search → fetch venue's own food-relevant pages → og:image+content imgs; consent/`/sorry/` CAPTCHA → empty; **Bing httpx fallback**), NEW `enrich.py` `VenueEnricher` (agentic: plan_queries→crawl→**LLM verify+extract** strict json_schema over Ollama: `is_food_venue`+`keep_image_indices` rejecting non-food + extracted `info`; reflect/retry; heuristic fallback), schemas Enrich{Request,edImage,edInfo,Response}, `POST /enrich` (never 502), `ENRICH_*` config, `playwright`+Dockerfile chromium, compose env, `tests/test_enrich.py` (12). Go: NEW `services/venue_enrich.go` (client→/enrich, **no cache**); `venue_image.go` **cache OFF** (`VENUE_IMAGE_CACHE_TTL` default 0; removed hardcoded 24h) + **`IsPublicHTTPImageURL`** SSRF guard; `handlers/venue_image.go` **`?u=<b64url remote>` proxy mode** (SSRF-guarded, realtime) alongside `?q=&i=`; NEW `handlers/venue_enrich.go` `GET /api/v1/venues/enrich` (public, degrades empty); `main.go` register+wire. Flutter: `api_client.imageProxyUrl`, NEW `venue_enrich_service.dart`, `venue_thumbnail.dart` optional `imageUrl`, `venue_detail_view.dart` mutable `_d` + `_loadEnrichment` (verified gallery + `withEnrichment` facts-merge; Bing fallback else). **Structural anti-surgeon design:** images sourced ONLY from food-relevant venue pages + LLM verdict → a fake venue with no real food photos → empty → honest placeholder (not an operating room). **Verified:** sidecar 35/35 pytest + py_compile; Go build/vet + **golangci-lint v2.12.2 → 0 issues** + services/handlers/middleware unit tests GREEN (smoke needs live :8080). Flutter NOT analyzed (no host PATH). **Enabled by default in docker** (compose sets AI_SEARCH_URL). **PENDING (user):** `./start.sh` (sidecar rebuild pulls Chromium ~300MB) → real venue detail shows relevant food photos+facts; "Surgeon Bbq Curry" shows placeholder → when confirmed = R-008 (tags venue-image/agentic/playwright/google-scrape/llm-verify/ssrf/cache). Supersedes R-007's Bing path for the detail hero. See sessions/2026-06-11-agentic-venue-enrichment-google-crawl.md.

---

**Status (2026-06-11) — Ported google-maps-scraper venue-enrichment features into Discovery (A/B/C done, D=spike no-build; code done, pending live confirm):** User pointed at `github.com/omkarcloud/google-maps-scraper` → research + apply. Google Maps source is banned in VN (locked), and ~half the repo is B2B lead-gen → ported only the *concepts* fed by permitted sources (TomTom/OSM + R-007 Bing scrape). User picked all 4. **A "Đang mở/Đã đóng" badge** (pure Flutter): NEW `utils/opening_hours.dart` OSM hours parser (24/7, multi-rule `;`, day-lists, split shifts, overnight) + `widgets/open_now_badge.dart`, wired into discover `_RestaurantRow` (replaces raw 🕒 chip) + detail (badge under title + `_matchChecks` now real). **B ratings+reviews** (flagship): NEW `services/venue_reviews.go` (keyless Bing **web** scrape → rating/count/snippets, 24h cache, **never fabricated** — emitted only when a clear pattern matches) + `handlers/venue_reviews.go` `GET /api/v1/venues/reviews` (under `auth`) + Flutter `venue_reviews_service.dart` + detail "CẢM NHẬN TỪ CỘNG ĐỒNG" section + merged ⭐ in meta. **C richer list**: `places_service.dart` `getNearby` now fetches TomTom+Overpass concurrently and merges (NEW `mergeNearbyPlaces`/`normalizeVenueName`/`OsmPlace.mergeFill` — dedup by name+250m, fill blank fields, append uniques → fuller list once TOMTOM_API_KEY set; OSM-only otherwise). **D popular-times**: SPIKE → no VN-legal free source (Google-derived banned; BestTime/Foursquare paid+sparse) → intentionally NOT built (honesty principle); A badge is the real-data substitute. **Images belong to location** (user note): already correct via R-007 name+address query + relevance filter; C's address-merge sharpens it. **Verified:** Go build/vet/test GREEN (golang:1.25 Docker), Flutter analyze clean on changed files + 11/11 new tests (`opening_hours_test`, `places_merge_test`, `venue_reviews_test`). **PENDING (user):** `./start.sh` → confirm badge/reviews/merge at http://127.0.0.1:54180; when confirmed → R-008. ⚠️ TomTom path doesn't supply opening_hours yet (badge shows on OSM path); Bing review scrape can be blank for obscure quán (degrades to no section). See sessions/2026-06-11-discovery-scraper-features-port.md.

---

**Status (2026-06-11) — CI: TOMTOM_API_KEY now injected from a GitHub secret (config-only, pending deploy):** The Discovery `/venues/nearby` TomTom proxy key was in `.env`/config + read by the backend, but the deploy workflows never passed it to Cloud Run → proxy stayed off on the deployed API (client fell back to Overpass). Added `--set-env-vars "TOMTOM_API_KEY=${{ secrets.TOMTOM_API_KEY }}"` to BOTH `cd.go-api.yml` (prod) and `ci.go-api.yml` deploy-dev. Used a **secret** (private key, like SMTP_PASSWORD/JWT_SECRET). Safe before the secret exists: empty key → `TomTomClient.Enabled()==false` → route not registered → Overpass fallback. Also documented TOMTOM_API_KEY + SMTP_PASSWORD in `.github/CI-CD.md` secrets table. **PENDING (user):** create GH repo secret `TOMTOM_API_KEY` → next deploy → API logs `TomTom nearby enabled`. See sessions/2026-06-11-ci-tomtom-api-key-secret.md.

---

**Status (2026-06-11) — Email OTP added as a 2nd auth option (alongside phone OTP, no captcha; code done, pending live verify):** User asked for a login path without Firebase phone-OTP's reCAPTCHA → decision: **keep phone OTP, ADD passwordless email OTP** (Gmail SMTP). Backend mints a 6-digit code, emails it, verifies, upserts a user by email, issues the existing JWT pair — no Firebase, no captcha; anti-abuse via 60s per-email cooldown + 5 max attempts + 10m expiry + global rate limiter. **Backend (additive, phone flow untouched):** migration `012_email_otp.sql` (`email_otps`), NEW `services/email.go` (`EmailSender`/`SMTPSender` net/smtp auto-STARTTLS+PLAIN for Gmail 587 + App Password / `LogSender` dev fallback), `services/auth.go` `SetEmailOTP`+`EmailOTPEnabled`+`RequestEmailOTP`/`VerifyEmailOTP`/`upsertEmailUser`, `ErrRateLimited`, `AuthServicer` ext, `handlers/auth.go` 2 handlers (request=200-always to avoid email enumeration, 429 cooldown; verify=401→IssueTokens), `config.go` `SMTP_*`+`EMAIL_OTP_*`, `main.go` sender wiring (real SMTP when `SMTP_HOST`+`SMTP_USERNAME`; else `LogSender` in DEV_MODE; else routes disabled). **Flutter (additive):** `auth_service.dart` `requestEmailOtp`/`verifyEmailOtp`; NEW `email_input_view.dart` + `email_otp_view.dart` (6-box + keypad, same UX as phone `OtpView`); `phone_input_view.dart` got "Đăng nhập bằng email" button. **Verified:** go build/vet/test GREEN (golang:1.25) + flutter analyze clean. **Follow-ups done same day:** (a) **Branded HTML email** — `services/email.go` Send now sends multipart/alternative (text+HTML) + RFC2047-encoded UTF-8 Subject/From; `services/auth.go` `emailOTPHTML()` table-based inline-styled brand template (berry gradient, OTP pill). (b) **CI/CD** — `cd.go-api.yml` (prod) + `ci.go-api.yml` deploy-dev inject `SMTP_HOST`/`SMTP_USERNAME` (GH **vars**, host defaults smtp.gmail.com) + `SMTP_PASSWORD` (GH **secret**) via `--set-env-vars` (gcloud replaces whole env set → must list them). (c) **golangci-lint CI fix** — 11 issues → 0 (main.go if-else→switch, auth.go `max`→`upper`; + pre-existing venue_image/venue.go httpNoBody/errcheck/importShadow); verified `golangci-lint run` v2.12.2 → 0 issues. Image source stays **Bing** (user declined Google — server-side Google scrape would hit DDG-style CAPTCHA). **CONFIRMED:** local SMTP works (user received real OTP email). **PENDING:** full round-trip (email→code→app) visual confirm + fresh OTP to preview HTML + create GH SMTP vars/secret + commit/push branch. When round-trip confirmed → R-008/next (tags email-otp/auth/smtp/passwordless; R-007 now taken by the venue-image pipeline). See sessions/2026-06-11-email-otp-auth-option.md.

---

**Status (2026-06-11) — Venue image proxy fixed (401→429→404 chain) + Goong venue-freshen added:** User's Discovery detail screen couldn't load venue photos. Fixed a 3-error chain: (401) the image routes `app.Get("/api/v1/venues/image")` sat AFTER `api.Use(jwtMW)` — in Fiber v2 that catch-all JWT middleware also guards `app`-level `/api/v1*` routes registered after it → moved registrations BEFORE `api.Use(jwtMW)`; (429) the `/api/v1` group rate limiter caught them too → wrapped `rlHandler` to skip `/api/v1/venues/image*`; (404) **DDG Lite now serves a bot-CAPTCHA when scraped server-side** + OSM admin suffixes over-specified the query → **rewrote `services/venue_image.go` from DDG page-crawl to Bing Images** (parse `murl` JSON from results HTML) + `prepareVenueSearchQuery` strips `Phường/Quận/TP.` & appends "ảnh". **Image fix user-confirmed working** (screenshot: Tara Coffee detail w/ 6-photo hero gallery). Then user asked to fix STALE OSM venue data (OSM "Tara Coffee" → reality "AgriSocial" per Google) — chose **Goong** (fits locked "no Google Maps in VN" decision) over Google Places. Added freshen-at-detail-open: `services/goong.go` `GoongClient.Freshen` (tier1 autocomplete-by-name→detail w/ ≤150m guard; tier2 reverse-geocode fallback; 24h cache; nil-degrades), `handlers/venue_fresh.go` `GET /api/v1/venues/fresh` (authed, `{}` when no hit), `config.GoongAPIKey`, `.env`/`.env.example` `GOONG_API_KEY`. Flutter: `venue_fresh_service.dart` + `venue_detail_view.dart` (mutable `_d`, `withFresh`, `_freshen()` in initState, re-fetches photos if name changes). **Verified:** Go build/vet GREEN + services tests pass (golang:1.25). **PENDING (blocked on user):** real `GOONG_API_KEY` to live-verify freshen (route disabled until set → app behaves as before). ⚠️ Caveat: Goong has no Google-style nearby-POI search → may not surface an outright replacement name as well as Google Places would. See sessions/2026-06-11-venue-image-routing-bing-and-goong-freshen.md.

**✅ RESOLVED → R-007 (2026-06-11):** Goong part REVERTED (user). Image pipeline finished + user-confirmed: Bing source, 401/429/404 routing/rate fixes, **502 fix** (concurrent reachability probe of candidates — dead/hotlink URLs dropped so Count only reports servable photos), **relevance filter** (parse Bing per-result `t`/`desc`/`purl`, keep only images whose haystack mentions a distinctive venue token via `significantTokens`/`venueStopwords` — kills wrong/NSFW photos), **category stock fallback** (`crawlCategory`/`categoryStockQuery`: when no real photo, generic on-theme query e.g. "nhà hàng tiệc cưới sang trọng", cap 5, skips relevance), and a touch+mouse swipeable hero gallery. Cap 6→10. See resolutions/R-007-venue-image-bing-relevance-fallback.md.

---

**Status (2026-06-11) — Discovery: reliable exact-venue search + web-page image crawl (code done, pending live verify):** User: search bar must reliably return the quán **"lẩu bò giáo toàn"** + get its photos by scraping web pages, shown in detail. Findings (live-probed): OSM/Photon/Nominatim don't have this venue; DDG `i.js` + Bing *image* search are blocked/mangle the VN name → unusable; but DDG-Lite *web* search + crawling `og:image`/content `<img>` off the venue's blog pages (mia.vn → `lau-bo-giao-toan-*.jpg`, real 200 image/jpeg) works great. **Part 1 (sidecar `service.py`):** free-text `/search` now degrades a structurer/LLM failure to empty picks (not 502) AND injects a **deterministic seed card** for the typed name when it looks like a venue name (≥2 words/≥8 chars; bare dishes left to the LLM) and no structured pick matches it — so exact-name search ALWAYS returns the quán regardless of LLM availability/relevance. New `tests/test_query_seed.py`. **Part 2 (`services/venue_image.go` rewritten):** resolver = DDG-Lite web search → crawl top pages → og:image + content imgs (absolutized, junk-filtered), ≤6/venue, 24h cache; handler `Serve` gained `i` index + new `Count` (`GET /api/v1/venues/images?q=`→{count}); Flutter detail hero is now a swipeable `PageView` gallery (count via new `venue_image_service.dart`, `VenueThumbnail` index param). **Verified:** go build/vet/test GREEN, sidecar pytest 12/12, flutter analyze clean, network chain end-to-end for the named venue. **PENDING:** live `./start.sh` → search "lẩu bò giáo toàn" returns the card + tap → 12.1 with photo gallery. When confirmed → R-007. See sessions/2026-06-11-discovery-venue-seed-and-web-image-crawl.md.

---

**Status (2026-06-10) — FEATURE Discovery venue thumbnails + Chi tiết quán (12.1) detail screen (code done, pending live verify):** User: "search hình thumbnail của quán trên web và render vào list quán" + "click vào quán → show 12.1_ChiTietQuan, implement UI luôn". Done full-stack. (1) Thumbnails: NEW public, un-rate-limited Go endpoint `GET /api/v1/venues/image?q=` does **keyless DuckDuckGo image search server-side** (`services/venue_image.go` vqd page→i.js JSON, 24h cache; `handlers/venue_image.go` proxies photo bytes w/ Cache-Control 24h so Flutter `Image.network` needs no CORS/token; registered on root `app` in main.go, NOT the rl group/jwt). Flutter `VenueThumbnail` widget (fade-in + `PhotoSlot` fallback) replaces `📸` in both Discovery rows. (2) Detail: NEW `views/discover/venue_detail_view.dart` `VenueDetailView` + `VenueDetailData.fromOsm/.fromResult`; tapping any Discovery row opens it (was Google Maps). Hero photo + tag/title/meta + social-proof + VỀ QUÁN + taste chips + "Hợp gu {name}:%" card + sticky "＋ Wishlist / Tìm Mate ăn cùng" bar. Honesty: only real meta segments shown, fake count/% softened/placeholdered. CTAs: Wishlist→WishlistService.add, Tìm Mate→SwipeView, near_me→MapsLauncher. **Verified:** go build/vet/test GREEN (golang:1.25 + new `services/venue_image_test.go`), `flutter analyze` clean on changed files. **PENDING:** live `./start.sh` (rebuilds api) → confirm photos render + 12.1 opens at http://127.0.0.1:54180. Limitation: DDG may block datacenter IPs on Cloud Run → graceful placeholder there. When confirmed → R-007. See sessions/2026-06-10-venue-thumbnails-and-detail-screen.md.

---

**Status (2026-06-10) — Containerize the LLM → ALL services now in Docker (config-only, pending live verify):** User asked "modify start.sh to run all services in docker". Finding: app services (db/api/ai_venue_search/flutter_web) were already fully dockerized via `docker compose`; the ONLY host dependency left was the venue-search structurer LLM (`LLM_BASE_URL=host.docker.internal:1234`, LM Studio on host). User chose **Containerize the LLM**. Added bundled **`ollama`** service (`ollama/ollama:latest`, OpenAI API `:11434/v1`, `ollama` named volume, healthcheck) + one-shot **`ollama_pull`** (pulls `${OLLAMA_MODEL:-qwen2.5:3b}` ~2GB, idempotent). Repointed sidecar: `STRUCTURER` pollinations→**openai**, `LLM_BASE_URL`→`http://ollama:11434/v1`, `LLM_MODEL`→`${OLLAMA_MODEL}`, +`depends_on ollama`. New **`docker-compose.gpu.yml`** opt-in NVIDIA override (kept out of base so CPU-only `up` never fails). `start.sh`: COMPOSE_FILE select (`OLLAMA_GPU=1` merges gpu), exports `OLLAMA_MODEL`, step-8b model-pull wait, banner shows Ollama URL. **No Python edits** — sidecar's `_lm_studio` json_schema path already speaks Ollama's OpenAI shape. Static-verified: `compose config -q` (base+gpu merge) ✓, interpolation resolves ✓, `bash -n start.sh` ✓. **PENDING:** live `./start.sh` (first run pulls image+model) + confirm Ollama honors strict `response_format: json_schema` (fallback: `OLLAMA_MODEL=qwen2.5:7b` or `STRUCTURER=pollinations`). When confirmed → R-007. See sessions/2026-06-10-dockerize-llm-ollama.md.

---

**Status (2026-06-08) — FEATURE First Date / Booking (nhóm E #1) done full-stack:** User chọn build First Date trước. Backend: migration `011_bookings` (1 active booking/match, partial unique index), `services/booking.go` (Propose replace-active / Get / Confirm chỉ non-proposer / Cancel + validateProposal pure-tested), `BookingServicer`, `handlers/booking.go`, 4 routes `POST/GET /matches/:id/booking` + `/confirm` + `/cancel`. Flutter: `booking_service.dart`, `booking_view.dart` rewrite mock→real (calendar động theo tháng hiện tại, load existing, banner propose/confirm/cancel, CTA propose thật), wire chat "Chốt First Date"→BookingView (venue từ AI card gần nhất). Verify: go build+vet+test ok, **e2e_full_flow 31/31** (step 13: propose/confirm-own-409/confirm/cancel), flutter build OK, **booking UI smoke PASS** (tap CTA→BookingView→propose→DB row). Defer: chat broadcast khi confirm, voucher/check-in (cần Live Tracking + Trust). Nhóm E còn: Trust Score, Lá thư, Safety, Selfie/Tracking/Check-in/Review.

---

**Status (2026-06-08) — "Làm hết" nhóm C+D done:** **C1** bỏ message paywall chết (handlers/chat.go, seam giữ cho Phase-2). **C2** dev deep-link trong main.dart gate sau `_devDeepLinkEnabled` (kDebugMode||localhost) → inert ở prod, vẫn chạy dev/e2e (hết rủi ro "revert before ship"). **D** e2e_full_flow.js +step 12: profile GET/PUT, wishlist CRUD, swipe+undo → **e2e 26/26** (was 20). Verify: Go+Dart build OK, go vet+test ok, e2e 26/26, D1 deep-link vẫn PASS. **Defer:** A1-`restaurant_id` (web-search không ground DB; chưa có consumer — cần booking/DB-ingest trước), **nhóm E** (letters/booking/tracking/checkin/review/trust/safety) = 6-8 feature lớn + phụ thuộc product open-questions → cần build từng cái, KHÔNG làm 1 lượt; chờ user chọn feature ưu tiên.

---

**Status (2026-06-08) — "Làm tất cả": ISSUE-9 + B1 + D1 + R-006 done (+ live Thủ Đức test):** Sau khi fix A1/A2/B2: (1) live test "địa chỉ hiện tại" — IP-geo trả Gò Vấp sai (vị trí ISP), geocode đúng "Đường số 2, Phường Thủ Đức"=10.8383,106.7497 → card ra toàn quán Thủ Đức (King BBQ Buffet/Sumo Yakiniku/Buffet Sống Sắc), video quay lại OK; (2) **ISSUE-9** distanceLabel ẩn "0m" khi lat/lng=0 (rebuild flutter_web xác nhận trực quan); (3) **B1** ConciergeService.fire chờ prewarm in-flight (channel) → hết 502, verify SETTLE_MS=0 card vẫn fire 20/20; (4) **D1** thêm `.dev-e2e/e2e_card_buttons.js` (Playwright tap "Gợi ý cho Mate"→assert WS send) PASS; (5) **R-006** viết (A1/A2/B2, user-confirmed). Verify: pytest 11, go vet+test ok, e2e 20/20, D1 PASS. Còn lại (chưa làm): A1-restaurant_id (cần DB ingest), nhóm C khác (C1 dead paywall, C2 temp deep-link), nhóm D mở rộng (auth thật/wishlist/swipe-undo/profile), nhóm E (scope chưa build).

---

**Status (2026-06-08) — E2E coverage audit + FIX nhóm A+B (AI Concierge data quality + ops):** Đánh giá độ phủ `e2e_full_flow.js`: chỉ cover ~8/24 chặng journey ở tầng API/WS (UI Flutter 0%, auth thật bypass bằng dev-login, nhiều endpoint built-but-untested, ~13 chặng Phase-1 chưa build) — xem ma trận + tổng hợp 8 issue (A/B/C/D/E) trong sessions/2026-06-08-e2e-full-flow-issues.md. User chọn fix **nhóm A+B**: **A2** intro hết nêu tên khu vực sai ("Xuân Hòa" do OSM/Nominatim đều trả district sai cho midpoint trung tâm HCM) — bỏ prepend area + prompt cấm nêu phường/quận; **A1** toạ độ venue: radius guard động (≤6km) + chỉ tin street-address, quán ngoài vùng→lat/lng=0 (hết lỗi Subin BBQ Thủ Đức ghim 184m); **B2** api container "unhealthy"→healthy (healthcheck localhost→127.0.0.1, busybox wget IPv6 vs Go IPv4). Verify: pytest 11 passed, rebuild sidecar + api healthy, E2E 20/20, card thật 3 quán in-area (1.10/1.96/2.85km) dist khớp, intro "giữa 2 bạn". Chỉ sửa Python sidecar + docker-compose (không Go/Dart). ⚠️ Chưa user-confirm UI Flutter trực quan → R-006 khi confirm. Còn lại: A1-restaurant_id, B1 (502), nhóm C/D/E.

---

**Status (2026-06-08) — E2E full-flow GREEN + paywall removed cho MVP market test:** Theo chỉ đạo "làm để test thị trường" → bỏ paywall (MVP free). `services/chat.go CheckPaywall` → luôn `return false` (gỡ hard-lock level-3, BLOCKER-004 resolved). Rebuild image → **E2E full-flow `.dev-e2e/e2e_full_flow.js` 20/20 PASS**: dev-login → onboarding → preferences → location → deck(overlap=6) → mutual-like → match → conversations → WS 2 chiều → Vibe leo **0→72 tự nhiên** (không còn kẹt 30) → **AI Concierge `ai_venue_card` fire end-to-end** (King BBQ · Subin BBQ, web-search + LM Studio). ⚠️ Pending user confirm + chưa verify UI Flutter trực quan (mới API+WS). NB sidecar 502 nếu warm(60)+fire(70) gọi LLM đồng thời (chỉ khi gửi burst <1s; chat thật cách phút → OK). See sessions/2026-06-07-e2e-full-flow-test-2users-chat.md.

**Status (2026-06-07) — E2E full-flow test (từ đầu → 2 user chat + AI card):** Test toàn bộ luồng thật bằng script Node API+WS mới `.dev-e2e/e2e_full_flow.js`: dev-login → onboarding → preferences → location → discovery deck (overlap=6) → mutual-like swipe → match → conversations → WebSocket 2 chiều → Vibe climb → **AI Concierge `ai_venue_card` fire end-to-end** (3 quán thật từ web-search + LM Studio). **16/16 bước flow chính PASS.** Phát hiện+xử lý 3 vấn đề: (A env) API container chạy image STALE thiếu `010_swipes` → `docker compose build api`; (B data) pgdata volume local thiếu cột `noi_lau_progress.level` (do migration phantom cũ `003_noi_lau_drop_level.sql` đã bỏ khỏi repo) → match creation 500 → `ALTER TABLE … ADD COLUMN level`; (C ⚠️ design) **paywall hard-lock level-3 (30đ) chặn Concierge trigger (70đ)** → raise BLOCKER-004, cần user quyết. Không sửa source production. See sessions/2026-06-07-e2e-full-flow-test-2users-chat.md.

---

**Status (2026-06-07) — Prod CD gaps fixed (pre-merge):** Before merging `feat/ai-concierge-map`→main, fixed 2 deploy gaps that would break AI Concierge on prod: (1) `cd.go-api.yml` prod deploy was missing `AI_SEARCH_URL` (Cloud Run `--set-env-vars` replaces env → would disable Concierge) — added it mirroring dev; (2) `ai-venue-search/` had no `cd.*` → created `cd.ai-venue-search.yml` (push main → Cloud Run 8090). ⚠️ Not yet run in GH Actions; verify repo var `AI_SEARCH_URL`. Flutter Android/iOS still have no CD by design. See sessions/2026-06-07-prod-cd-gaps-ai-search-url-sidecar.md.

---

**Status (2026-06-06) — Mutual-like + wishlist CRUD (follow-ups resolved):** On top of the swipe→match→chat flow below, resolved all open items. **Mutual-like gate:** new `010_swipes.sql` + `swipes` table; `AcceptMatch`→`Swipe(like/pass)` (match created only on reciprocated like) + `Undo` (rewind); routes `/matches/:id/accept`→`POST /swipes` + `/swipes/undo`; `ListCandidates` excludes already-swiped. **Wishlist real:** new `wishlist_service.dart` + `WishlistView` rewritten mock→CRUD (list/add-sheet/delete). **Matching interest set** = food_tags ∪ wishlist food_name ∪ wishlist food_category (3 disjoint vocabularies), threshold raised back to **≥2**. Flutter `swipe_view` mutual-like UX + rewind restored; `smoke_test` moved to /swipes. **Verified:** Docker go build/vet rc=0 (incl smoke), `go test ./services` ok; **matching SQL validated LIVE on Postgres 16** (`.dev-e2e/matching_sql_check.sql`). ⚠️ Flutter not analyzed on host — verify via `./start.sh`. **TODO (user):** 2 real-OTP users, onboard with ≥2 shared food tags (or both wishlist same category), Ăn Match → both swipe right → chat. See sessions/2026-06-06-real-swipe-match-chat-flow.md (Part 2).

---

**Status (2026-06-06) — Real swipe→match→chat flow:** Wired the mate-discovery flow end-to-end for real phone-OTP users. Bottom tab 4 "Mình"→**"Ăn Match"** (opens `SwipeView`); profile now reached via avatar tap on Khám phá (+back button added). `SwipeView` rewritten mock→real (loads candidates + currentUserId, swipe-right/♥ → `acceptMatch` → `MatchView` → "Hello" → live `ChatDetailView(matchId)`; loading/error/empty states). **BLOCKER fixed:** matching scored on `wishlists` (never written by app → empty deck) → switched `ListCandidates` + `AcceptMatch` to **`users.food_tags` Jaccard**, threshold ≥1 shared tag, so 2 onboarded users are matchable immediately. Accept stays one-sided+instant. **Verified:** Docker go build/vet rc=0, `go test ./services` ok (smoke needs live :8080). ⚠️ Flutter NOT analyzed on host (no PATH) — verify via `./start.sh`. **TODO (user):** create 2 users via real OTP, onboard with ≥1 common food tag, test Ăn Match → swipe → chat at http://127.0.0.1:54180. See sessions/2026-06-06-real-swipe-match-chat-flow.md.

---

**Status (2026-06-06):** AI Concierge **pre-warm cache** + **2-user side-by-side E2E** done (code, build/test GREEN; video not recorded yet). Latency fix: `AI_WARM_POINTS` (default trigger−10=60) → concierge prefetches the slow web-search in background when Vibe enters `[warm,trigger)`, caches in-memory (10min TTL), `fire` posts instantly via `takeWarm` (falls back to fresh `compute` on miss). Pure `decideAction` + extracted `compute` (status ok/error/skipped) keep run-row granularity; idempotency unchanged. New 2-phone video tooling in `.dev-e2e/` (2nd flutter_web port 54181 for distinct localStorage; `e2e_two_users.js` drives An↔Bình chat 58→70, card on both phones, reload for full-history shot; `run-e2e.ps1`). Verified Docker golang:1.25: build+vet clean, services 10/10 (new TestDecideAction). **TODO (user):** run `.dev-e2e\run-e2e.ps1` w/ LM Studio up to record the video; revert `main.dart` TEMP deep-link before commit. See sessions/2026-06-06-ai-concierge-prewarm-2user-e2e.md.

---

**Status (2026-06-04):** AI Concierge venue source SWAPPED map/DB → **MCP web-search**, sidecar LIVE-VERIFIED in Docker. `ai-venue-search/` (FastAPI) wired into `docker-compose.yml` (service `ai_venue_search`:8090, healthcheck, host-gateway); api gets `AI_SEARCH_URL=http://ai_venue_search:8090`. **FREE, no keys**: DuckDuckGo MCP search + Nominatim reverse-geocode + structurer chain Pollinations→LM Studio (FallbackStructurer; Pollinations anon 429s → LM Studio qwen3.5-9b w/ strict json_schema carries it). `POST /suggest` confirmed 200 w/ concrete VN venue names. Go side: `VenueProvider` interface + `WebSearchProvider`(web) / `DBLLMVenueProvider`(legacy fallback). **Run:** `./start.sh` or `docker compose up --build`. ⚠️ Go build still unverified on host (no Go PATH — covered by httptest + Docker build). Limitation: web-search → lat/lng often 0 (weak map pins), names not 100% grounded. Tip: `STRUCTURER=openai` makes LM Studio primary (skips Pollinations 429). See sessions/2026-06-04-ai-concierge-mcp-websearch.md.

---

## Previous status

**Status:** AI Concierge chat slice IMPLEMENTED (code complete) — ⚠️ NOT YET built/tested locally (Go+Flutter toolchains not on host PATH; build via Docker `start.sh` / CI). Flutter chat view still a MOCK (card shown from sample data; WS delivery is the remaining seam).
**Verification pending (user/Docker):** `docker compose` build, `go test ./...`, `go vet`, `flutter analyze`, `flutter test`. Live E2E needs LM Studio at `AI_BASE_URL=http://host.docker.internal:1234/v1` + a model (Qwen2.5-14B suits RTX 5080 16GB). Then: 2 users + match + push locations + chat until points≥70 → expect `ai_venue_card` from "Trợ lý ĂnMates" with 3 seeded venues, once.
**✅ WebSocket wired (2026-06-04):** `chat_socket.dart` + live `chat_detail_view` (matchId → load history+progress, connect WS, render real `ai_venue_card`, send over socket) + `chat_list_view` loads real conversations. Demo mode preserved when matchId null.
**LM Studio (RTX 5080) — RESOLVED:** qwen3.5-9b is a reasoning model → LM Studio puts JSON in `reasoning_content` (content empty). Fixed in `llm.go`: fallback to reasoning_content + max_tokens=2000. Verified end-to-end: clean Vietnamese, 1.3s, correct budget filter + anti-hallucination. **9b now preferred.** Dev `.env`: `AI_BASE_URL=http://host.docker.internal:1234/v1`, `AI_MODEL=qwen/qwen3.5-9b`. (vl-7b also works via content path; CJK guard still in place.)
**Next seam:** replace seed venues with Goong ingest; add `user_prefs_budget`; investigate qwen3.5-9b empty-content (try disabling reasoning / non-strict json). Still pending: run `go test`/`flutter analyze`/`flutter test` in Docker/CI; full live E2E.

---

## Previous status

**Status:** SPEC ready (spec-driven) — awaiting go-ahead to implement AI Concierge chat slice.
**Owner:** main-assistant
**Started at:** 2026-06-03
**Last updated:** 2026-06-03
**Active spec:** `docs/specs/ai-concierge-chat-spec.md` — vertical slice: Vibe `points>=70` → Claude agent posts top-3 seeded venues as `ai_venue_card` in chat. ⚠️ **Google Maps PROHIBITED in VN** → data/routing = **Goong**; render = OSM tiles. Locked: trigger 70, app pushes location (user_locations), seed restaurants for slice, Haiku agent behind LLMClient interface. Migrations 006-008. **Steps 1-4+6-8 implementable WITHOUT keys (fake LLM); live E2E needs ANTHROPIC_API_KEY.** Prereq from user: Anthropic API key (+ later Goong key). Implementation not started.

---

## Previous task (archived)

**Status:** delivered (pending review) — Meetup & Dining Map master plan authored.
**Owner:** main-assistant
**Started at:** 2026-06-03
**Last updated:** 2026-06-03
**Goal:** Design a complete map-based meetup planning experience (find → evaluate → agree → book → meet a restaurant for matched users). Output: `docs/meetup-map-master-plan.md` (18 sections, Mermaid). Key decisions: pragmatic-incremental Riverpod for new `map/restaurants/booking` features only; flutter_map+OSM/Overpass for MVP with Mapbox (Directions/Matrix) as V2 upgrade; map becomes a core MVP surface (supersedes prior "no full map in Phase 1"). New backend: PostGIS + `restaurants/venue_suggestions/bookings/user_locations/favorite_restaurants/meetup_recommendations/location_sessions` tables + APIs. Doc-only, no code written. See sessions/2026-06-03-meetup-map-master-plan.md. ⚠️ Pending: user/team review + verify Cloud SQL PostGIS availability before MAP-R-1.

---

## Previous task (archived)

**Status:** done — CI→dev deploy running. R-005 written.
**Owner:** main-assistant
**Started at:** 2026-06-01
**Last updated:** 2026-06-01
**Goal:** CI deploy lên GitHub Environment `dev` để test branch/PR trên URL thật. `ci.flutter-web.yml` + `ci.go-api.yml` thêm job `deploy-dev` (same-repo PR only) → `environment: dev` (web: dev-anmates-studio.web.app, api: shared Cloud Run anmates-api ENV=dev, API_BASE_URL chung). `cd.*` giữ nguyên — tách production (Cloud Run riêng + Cloud SQL + Secret Manager) là follow-up tương lai. User chọn **1 env `dev`**. ⚠️ Setup thủ công còn lại: tạo env `dev`, tạo Firebase site `dev-anmates-studio`. See sessions/2026-06-01-ci-dev-environment-deploy.md.
**Jira:** TECH-7 (current branch)

---

## Previous task (archived)

**Status:** done — onboarding flow 08→09→10→11 fully working. R-004 written.
**Goal:** Refactor onboarding submit flow: Screens 08/09 store to client draft (no API), NEW Screen 10 photo upload (Firebase Storage), "Hoàn tất" validates all 3 + one-shot `PATCH /profile/complete-onboarding`, Screen 11 GETs profile (nickname+avatar). New `user_photos` table. See sessions/2026-05-31-onboarding-flow-refactor-screen08-09-10-11.md + R-004.

---

## Previous task (archived)

**Status:** done — UI confirmed by user, nav bug fixed, R-003 written.
**Goal:** Implement post-OTP onboarding: Screen 08 (Thông Tin Cá Nhân, 3/5) + Screen 09 (Gú Ẩm Thực, 4/5). See R-003 + sessions/2026-05-31-screen08-ui-polish.md.
**Jira:** TECH-7 (Screen 08) in epic TECH-6 (Auth & Profile UI/UX)

---

## Previous task (archived)

**Status:** in-progress (FE-UI-007 ✅ Screen 03 in-review — next: FE-UI-008 Screen 04)
**Owner:** main-assistant
**Started at:** 2026-05-26
**Last updated:** 2026-05-28
**Jira:** SCRUM-13 (FE-UI-007) In Progress | SCRUM-7 (FE-UI-001 audit) In Progress
**Goal:** Refactor TOÀN BỘ UI Flutter app (`anmates_flutter/`) khớp 24 design HTML mới nhất (`plan/lastest/design/`) + animation spec chi tiết trong `design-system.md`. Phased delivery (8 phases). This session covers **Phase 0 (Foundation) + Phase 1 (Onboarding screens 01-07)**.

## Most recent progress (2026-05-27)

Onboarding screen 02 "Chọn quán" refactored end-to-end: polaroid cards with real cartoon PNG illustrations (Lẩu/Cafe chill/Đồ nướng/Ăn vặt), tightly-stacked layout, full animation suite (staggered entry + ambient float + hover lift + press), responsive sizing for iPhone SE through 14, swipe enabled on touch + mouse + trackpad + stylus. ~400 lines of dead CustomPainter code removed. Visual confirmation pending. See [sessions/2026-05-26-onboard-02-chon-quan-polaroid-cards.md](sessions/2026-05-26-onboard-02-chon-quan-polaroid-cards.md) for full multi-iteration log.

**Blocked on user decision:** how to interpret the `food_card.png` re-crop request (food-art-only vs whole-polaroid + Flutter chrome refactor).

## Scope (this session)

- **Phase 0** — Foundation primitives + theme extension + assets
  - Brand primitives: `AppButton` (Primary/Secondary/Outline/Danger/Ghost), `AppChip` (Filter/Tag/Mood/State), `AppCard` (Restaurant/Mate/Booking), `AppInput` (Text/Phone/OTP/Search), `Avatar` (with optional TrustBadge ring), `VibeRing` (0–100 circular), `TrustBadge` (Perfect/Trusted/Limited), `AppLoader` (3 modes: splash / overlay / top-bar), `Sparkle` (twinkle SVG)
  - Theme extension: spacing tokens, semantic colors, reduce-motion provider, haptic helper
  - Assets folder skeleton: `assets/sparkles/` (CustomPainter fallback if no SVG)
- **Phase 1** — Onboarding (Screens 01–07)
  - 01 Splash (full animation timeline)
  - 02/03/04 Onboard carousel (3 educational screens with hero animations)
  - 05 Đăng nhập (phone + Apple ID — keep existing Firebase wiring)
  - 06 OTP (6-digit auto-advance — keep existing Firebase wiring)
  - 07 Face verify (liveness mock — UI only, no real ML)

## Out of scope (next sessions)

- Phase 2 (08, 09a, 10a — profile setup)
- Phase 3 (09b, 10b, 11 — discovery)
- Phase 4 (12, 13 — match)
- Phase 5 (14, 15, 16, 17 — chat + booking)
- Phase 6 (18-22 — kèo/letter/tracking/review)
- Phase 7 (23, 24 — tab Mình + trust)
- N1-N7 screens (no design yet — design-team blocker)
- Phase 2 IAP screens (25-28)
- Backend Go changes

## Acceptance criteria (this session)

- [ ] Phase 0 primitives in `lib/widgets/anm/` — all 9 primitives implemented + exported from a barrel file
- [ ] Theme extended with spacing/semantic tokens; reduce-motion + haptic helpers in `lib/services/`
- [ ] `pubspec.yaml` updated (`flutter_svg` added; `lottie` only if needed)
- [ ] Phase 1 screens 01-07 rewritten end-to-end matching reference HTML + design-system.md animation timelines
- [ ] Existing Firebase OTP wiring preserved (no regression on R-001 fix)
- [ ] Vietnamese diacritics render OK on all copy
- [ ] Hit targets ≥44×44px on every tappable element
- [ ] Reduce-motion mode covers all animated screens
- [ ] `flutter analyze` clean (0 errors, ≤5 warnings)
- [ ] `flutter test` passes (existing tests must continue to pass; no new tests required this session)
- [ ] QA report saved to `qa-reports/2026-05-26-phase-0-1.md`

## Key references

- HTML designs: `plan/lastest/design/01 _ Splash.html` … `07 _ Face verify.html` + `Brand system.html` (READ FIRST) + `Logo studies.html`
- Animation timelines: `.claude/shared-memory/design-system.md` lines ~200–700 (AppLoader, Sparkle, Splash, Onboard 02/03/04, Auth 05/06/07)
- Existing legacy code to REPLACE: `lib/views/splash/splash_screen.dart`, `lib/views/onboarding/onboarding_view.dart`, `lib/views/auth/auth_view.dart`, `lib/views/auth/phone_input_view.dart`, `lib/views/auth/otp_view.dart`
- Brand tokens (LOCKED — do not invent new shades): `lib/theme/app_theme.dart` `AppColors`
- Firebase OTP code (must keep wiring): `auth_error_messages.dart`, services hitting Firebase Phone Auth

## Loop policy

Max 3 coder→qa cycles for Phase 1. If still failing after 3, mark blocked and escalate to user.
