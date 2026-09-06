-- 015_sync_ledger.sql
-- Sổ theo dõi ETL từ Data-Pipeline: lô nào, quán nào qua được, quán nào không và vì sao.
--
-- Ai ghi bảng này: dịch vụ `anm-relay` chạy bằng container trên host devops-pc, KHÔNG phải
-- máy Windows. Windows chỉ POST vào relay rồi nhận 202; relay mới là bên mở kết nối tới
-- anmates-db (qua NodePort trên virbr0, đường mà chỉ host đi được). Nhờ vậy mật khẩu Postgres
-- không còn nằm trên máy Windows.
--
-- Vì sao sổ nằm ở đây chứ không phải bên foodrec: Grafana chạy trong cụm và với tới anmates-db
-- bằng ClusterIP + CoreDNS. Và relay vốn đã mở sẵn kết nối tới chính DB này để upsert — ghi sổ
-- nằm cùng transaction với việc ghi dữ liệu, nên sổ không bao giờ nói dối.
--
-- KHÔNG lặp lại việc của 013_pipeline_source.sql (CHECK source='pipeline' + partial unique
-- index (source, source_ref)) — file đó đã có và đã live từ 2026-08-30. Cũng KHÔNG tạo
-- venue_photos: bảng đó do 014_venue_photo_blobs.sql sở hữu, với định nghĩa chặt hơn
-- (CHECK mime_type, CHECK byte_size > 0, position smallint, hai unique index slot + dedup).
--
-- Hôm nay `skipped` chỉ đi ra logger.warning rồi chết theo tiến trình, nên "quán nào chưa vào
-- được catalog, kẹt bao lâu rồi" không trả lời được nếu không SSH vào Windows đọc
-- logs/publish_sync.log. Hai bảng dưới đây biến nó thành một câu SELECT.

-- Một dòng cho mỗi lô. Append-only — phần lịch sử, để vẽ xu hướng.
CREATE TABLE IF NOT EXISTS sync_runs (
  id           bigserial   PRIMARY KEY,
  batch_id     uuid        NOT NULL UNIQUE,      -- do relay cấp ở POST /batch
  started_at   timestamptz NOT NULL DEFAULT now(),
  finished_at  timestamptz,
  source_host  text        NOT NULL,             -- máy đẩy (windows-pc)
  relay_host   text        NOT NULL,             -- máy ghi (devops-pc)
  mode         text        NOT NULL CHECK (mode IN ('sync', 'dry-run')),
  schema_ver   int         NOT NULL DEFAULT 1,   -- hợp đồng JSON giữa Windows và relay
  read_count   int         NOT NULL DEFAULT 0,   -- đọc được bao nhiêu venue từ foodrec
  queued       int         NOT NULL DEFAULT 0,   -- đã nhận và đưa vào hàng đợi
  upserted     int         NOT NULL DEFAULT 0,   -- writer đã ghi thành công
  skipped      int         NOT NULL DEFAULT 0,   -- Windows loại trước khi gửi (thiếu toạ độ/tên)
  dlq          int         NOT NULL DEFAULT 0,   -- quá max_deliver, nằm ở venues.dlq
  hidden       int         NOT NULL DEFAULT 0,   -- --prune ẩn bao nhiêu
  photos       int         NOT NULL DEFAULT 0,
  ok           boolean     NOT NULL DEFAULT false,
  error        text
);

-- `queued - upserted - dlq` là số message CÒN NẰM TRONG HÀNG ĐỢI của lô đó. Đây là con số
-- phân biệt hai sự cố hoàn toàn khác nhau mà một ô "sync gần nhất" duy nhất không nói được:
-- Windows ngừng đẩy (không có lô mới) so với writer/DB có chuyện (lô mở mãi không đóng).
--
-- `finished_at IS NULL` kéo dài = lô chưa chảy hết. `ok=false` + `error` đã điền = lỗi bắt
-- được tử tế. Hai trạng thái đó phải phân biệt được trên dashboard.
CREATE INDEX IF NOT EXISTS idx_sync_runs_started ON sync_runs (started_at DESC);

-- Trạng thái HIỆN TẠI của mỗi venue, không phải một dòng cho mỗi lần chạy.
--
-- Cố ý không append-only: 25 venue × 96 lô/ngày là 2400 dòng/ngày để trả lời đúng một câu hỏi
-- mà bảng trạng thái trả lời rẻ hơn nhiều — "quán nào đang kẹt và kẹt bao lâu". `first_seen_at`
-- giữ nguyên qua các lô nên `now() - first_seen_at` chính là tuổi của chỗ kẹt; `sync_runs` lo
-- phần lịch sử.
CREATE TABLE IF NOT EXISTS sync_venue_state (
  source_ref     text        PRIMARY KEY,        -- id bên foodrec
  label          text        NOT NULL,           -- tên quán lúc nhìn thấy gần nhất, để đọc dashboard
  outcome        text        NOT NULL CHECK (outcome IN ('queued', 'synced', 'skipped', 'failed')),
  reason         text,                           -- câu lỗi nguyên văn: Skipped(), hoặc lỗi ghi DB
  restaurant_id  uuid        REFERENCES restaurants(id) ON DELETE SET NULL,
  attempts       int         NOT NULL DEFAULT 1, -- số lần lô chạm tới quán này
  deliveries     int         NOT NULL DEFAULT 0, -- num_delivered của message gần nhất (0 = chưa vào queue)
  first_seen_at  timestamptz NOT NULL DEFAULT now(),
  last_seen_at   timestamptz NOT NULL DEFAULT now(),
  last_change_at timestamptz NOT NULL DEFAULT now(),  -- chỉ nhích khi outcome/reason đổi
  last_batch_id  uuid        REFERENCES sync_runs(batch_id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_sync_venue_state_outcome
  ON sync_venue_state (outcome, first_seen_at);

-- Bốn outcome, cố ý phân biệt vì chúng là việc của người KHÁC NHAU:
--   skipped — dữ liệu chưa đủ (thiếu lat/lng hoặc tên). Windows loại trước khi gửi, chưa từng
--             vào queue. Việc của người duyệt nội dung.
--   queued  — đã vào hàng đợi, chưa tới lượt hoặc đang thử lại. Không phải lỗi, chỉ là chưa xong.
--   synced  — đã nằm trong restaurants.
--   failed  — đã đủ dữ liệu nhưng ghi không được, quá max_deliver và nằm ở venues.dlq.
--             Việc của kỹ sư; payload còn nguyên trong DLQ để phát lại sau khi vá.
--
-- Một venue biến mất khỏi foodrec (người duyệt rút duyệt) sẽ ngừng được cập nhật ở đây.
-- KHÔNG xoá dòng: `last_seen_at` cũ dần chính là bằng chứng nó đã rời danh sách, và
-- restaurants tương ứng cũng chỉ bị `--prune` đặt status='hidden' chứ không xoá.

-- Grafana đọc ba bảng: sync_runs, sync_venue_state, restaurants — phần nghiệp vụ ("quán nào,
-- vì sao"). Phần vận chuyển (độ sâu hàng đợi, DLQ) đến từ Prometheus scrape exporter của NATS
-- trên host qua gateway virbr0 192.168.122.1 — hai nguồn, mỗi nguồn đúng việc của nó.
--
-- Role `grafana_ro` + mật khẩu KHÔNG nằm trong migration này (secret không vào git) —
-- tạo bằng tay theo runbook AnMates-Data-Bridge docs/RUNBOOK.md §F.
>>>>>>> 381340f168e10e866331dbf827de0da5784d69ea
