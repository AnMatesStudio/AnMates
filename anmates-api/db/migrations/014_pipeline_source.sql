-- 014_pipeline_source.sql
-- Mở đường cho ETL của Data-Pipeline (serving/sync_anmates.py) ghi vào catalog.
--
-- Ba thứ dưới đây là điều kiện cần để `python -m serving.sync_anmates` chạy được;
-- thiếu bất kỳ cái nào thì 100% dòng bị Postgres từ chối, không phải một phần.
--
-- Migration này chạy tự động lúc `api` boot (db/migrate.go, //go:embed migrations/*.sql,
-- có pg_try_advisory_lock) — KHÔNG apply bằng psql tay, nếu không schema_migrations sẽ
-- lệch với thứ thật sự nằm trong image.

-- 1) Nới CHECK: catalog nay có thêm một nguồn.
--    Rows do ETL tạo được sở hữu bằng (source='pipeline', source_ref=<id bên foodrec>);
--    mọi câu lệnh trong sync_anmates.py đều scope theo hai cột đó, nên hàng 'seed'/'goong'/'osm'
--    vô hình với nó — một lần chạy hỏng chỉ phá được thứ chính pipeline sinh ra.
ALTER TABLE restaurants DROP CONSTRAINT IF EXISTS restaurants_source_check;
ALTER TABLE restaurants ADD CONSTRAINT restaurants_source_check
  CHECK (source IN ('seed', 'goong', 'osm', 'pipeline'));

-- 2) Đích cho `ON CONFLICT (source, source_ref) WHERE source_ref IS NOT NULL`
--    (sync_anmates.py::upsert). Partial index vì hàng seed có source_ref NULL và
--    NULL không đụng nhau trong unique index — nhưng nói rõ ra thì ý định rõ hơn.
CREATE UNIQUE INDEX IF NOT EXISTS uq_restaurants_source_ref
  ON restaurants (source, source_ref) WHERE source_ref IS NOT NULL;

-- 3) Ảnh quán do pipeline cào, lưu thẳng bytes thay vì URL.
--    `restaurants.photos` vẫn giữ URL gốc, nhưng chỉ để truy vết nguồn: URL đó do app
--    pipeline trên máy Windows phục vụ, không phải lúc nào cũng với tới được từ cụm.
--    Bytes thật đi qua đây.
--
--    Hai ràng buộc UNIQUE, không phải một: (restaurant_id, position) là khoá ghi, còn
--    (restaurant_id, sha256) chặn hai vị trí cùng một tấm ảnh. sync_anmates.py đã tự lọc
--    trùng sha256 trước khi INSERT vì ON CONFLICT chỉ đỡ được một ràng buộc.
CREATE TABLE IF NOT EXISTS venue_photos (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id uuid NOT NULL REFERENCES restaurants(id) ON DELETE CASCADE,
  position      int  NOT NULL,
  data_base64   text NOT NULL,
  mime_type     text NOT NULL,
  byte_size     int  NOT NULL,
  sha256        text NOT NULL,
  source_url    text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT uq_venue_photos_position UNIQUE (restaurant_id, position),
  CONSTRAINT uq_venue_photos_sha      UNIQUE (restaurant_id, sha256)
);

CREATE INDEX IF NOT EXISTS idx_venue_photos_restaurant ON venue_photos(restaurant_id);

-- Chưa có handler Go nào đọc bảng này (2026-09-05). Đó là chủ đích: bảng tồn tại trước để
-- ETL có chỗ đổ bytes ngay từ lần sync đầu, còn endpoint phục vụ ảnh là việc ngày hôm sau.
-- Tới lúc viết, giới hạn 3 MB/ảnh phải khớp với _MAX_PHOTO_BYTES trong
-- Data-Pipeline/serving/sync_anmates.py.
