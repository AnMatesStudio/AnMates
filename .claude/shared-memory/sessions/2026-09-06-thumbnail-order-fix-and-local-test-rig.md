# 2026-09-06 — Thứ tự thumbnail Data_Pipeline → AnMates + rig test 1 máy

## TL;DR

User hỏi: ảnh thumbnail sync từ Data_Pipeline qua AnMates có giữ đúng thứ tự
trên UI không. Trace hết chuỗi `Data_Pipeline → RabbitMQ → AnMates-Data-Bridge
→ anmates-api → anmates_flutter`, tìm ra 2 bug thật (gap vị trí + reorder bị
kẹt), vá cả hai, rồi dựng rig test 1 máy để verify bằng dữ liệu thật thay vì
chỉ đọc code. Trong lúc verify phát hiện thêm bug thứ 3 (chặn đứng MỌI lần
ghi), vá luôn.

## Root cause (3 bug, độc lập nhau)

1. **Gap vị trí ảnh** — `Data_Pipeline/serving/sync_anmates.py`
   `drop_unsendable_photos()`: loại ảnh quá khổ/trùng byte nhưng không renumber
   lại `position` còn lại → để lại lỗ (vd `{0,2,3}`). `venue_catalog.go`'s
   `photo_count = count(*)` không phát hiện lỗ; Flutter (`venue_catalog_service.dart`)
   duyệt tuần tự `photos/0..count-1`, gặp lỗ là 404 và MẤT LUÔN ảnh hợp lệ nằm
   sau lỗ đó, dù ảnh vẫn còn nguyên trong DB.
2. **Reorder ảnh cũ bị kẹt** — `AnMates-Data-Bridge/{writer,bridge}/app/db.py`
   `write_photo()`: khi pipeline publish lại và đổi vị trí một ảnh đã có (cùng
   sha256, position mới), INSERT mới đâm vào unique index
   `idx_venue_photos_dedup (restaurant_id, sha256)`, bị bắt và coi là "đã xong"
   — ảnh kẹt vĩnh viễn ở position cũ. `anmates-api/services/venue_photo_store.go`
   `Put()` đã xử lý đúng case này (DELETE bản ghi ở slot khác cùng sha trước
   khi insert) nhưng hàm đó là dead code, không ai gọi.
3. **(Phát hiện phụ khi verify) `ensure_batch()` thiếu `schema_ver`** — writer
   insert vào `sync_runs` không truyền `schema_ver`, cột này `NOT NULL` mà
   KHÔNG có default trên `anmates-db` (migration 015 có `DEFAULT 1` trong file
   nhưng bảng được tạo trước khi default đó được thêm — forward-only migration
   không tự ALTER lại). Hậu quả: **MỌI lần ghi của writer (venue lẫn ảnh) chết
   với `NotNullViolation`**, rơi hết vào `sync.dlq` sau `DELIVERY_LIMIT` lần thử.
   `bridge/app/db.py`'s `open_batch()` đã truyền `schema_ver` đúng từ đầu —
   writer là bản viết lại sau, làm rớt mất tham số này.

## Fix

- `Data_Pipeline/serving/sync_anmates.py`: renumber `photo_blobs` về dãy liên
  tục `0..len(keep)-1` sau khi lọc, trong `drop_unsendable_photos()`. Test mới
  `test_anh_bi_loai_o_giua_khong_de_lai_khoang_trong` trong
  `tests/test_sync_photos_dedup.py`.
- `AnMates-Data-Bridge/writer/app/db.py` + `bridge/app/db.py`: thêm
  `DELETE FROM venue_photos WHERE restaurant_id=%s AND sha256=%s AND position<>%s`
  trước INSERT trong `write_photo()`, mirror đúng `venue_photo_store.go Put()`.
- `AnMates-Data-Bridge/writer/app/db.py`: `ensure_batch()` truyền
  `config.SCHEMA_VERSION` tường minh thay vì dựa vào default cột.

## Rig test 1 máy (mới, tái dùng được)

Không cần k8s/MetalLB/tailnet để test writer — trên 1 máy, writer chỉ cần join
network `anmates_default` (docker compose của repo `AnMates`) và trỏ thẳng
`ANMATES_DB_URL` vào `anmates-db-1`. Xem
`AnMates-Data-Bridge/docs/LOCAL_TESTING.md` (mới) +
`Data_Pipeline/docs/LOCAL_TESTING_ANMATES_SYNC.md` (mới) cho cách dựng + bẫy
đã gặp. File mới: `AnMates-Data-Bridge/docker-compose.override.yml` (compose
tự nạp, KHÔNG đưa lên devops-pc), `.env` của repo đó đã điền `MQ_USER`/`MQ_PASS`
riêng cho rig.

## Verify (dữ liệu thật, không phải mock)

Dùng đúng nhà hàng có sẵn trong `foodrec` (source_ref `119`, "Chạng Vạng
Rooftop") — ảnh position 0 và 1 trùng sha256 thật (data có sẵn từ trước, không
phải case dàn dựng). Chạy `python -m serving.sync_anmates -v` thật (không
`--dry-run`) qua rig, chờ RabbitMQ tiêu thụ hết:

- Trước khi vá: `venue_photos` cho quán này có position `{0,2,3,...,11}` — lỗ
  đúng ở vị trí 1, khớp bug #1.
- Sau khi vá cả 3 bug, chạy lại: `position` liên tục `0..10` (11 ảnh), ảnh vốn
  ở position 2 (sha `bcdfa6f8...`) nay nằm ở position 1 với `created_at` MỚI
  (bản ghi cũ ở position 2 đã bị xoá đúng như kỳ vọng của fix #2, không phải
  do trùng lặp ngẫu nhiên).
- `sync_runs`/`sync_venue_state` cập nhật đúng hôm nay (trước khi vá bug #3,
  hai bảng này đứng yên từ 2026-09-05 dù script chạy "thành công" phía
  publisher — publisher không biết writer đang chết hết mọi lần ghi).
- Gọi thật API `anmates-api` (`:8080`, container đã chạy sẵn cho dev local):
  `GET /venues/<id>/photos/0..10` → 200 tất cả; `/photos/11` → 404 đúng như kỳ
  vọng; `GET /venues?...` trả `photo_count: 11` khớp — đây chính xác là những
  gì `venue_catalog_service.dart` gọi để build gallery.

**Chưa verify**: Flutter SDK không có trên máy này → không build/chạy được
`anmates_flutter` thật để xem UI render. Đã verify tới đúng ranh giới API mà
Flutter gọi (URL, status code, `photo_count`), nhưng chưa "nhìn thấy ảnh đúng
thứ tự trên màn hình" theo đúng nghĩa đen. Ghi chú thêm: UI v2 hiện tại
(`v2_venue_mapper.dart`) chỉ render `photoUrls.first` — chưa có carousel nhiều
ảnh nào dùng đến toàn bộ danh sách, nên 2 bug #1/#2 chưa gây hậu quả thấy được
cho tới khi carousel đó được xây.

## Dữ liệu test để lại trong `anmates-db` local

25 quán `source='pipeline'` (từ `foodrec`, restaurant id 1-... của
Data_Pipeline) + ~180 ảnh trong `venue_photos`, một phần là leftover từ phiên
2026-09-05 (rig "Windows side done" trong memory cũ), một phần ghi mới hôm
nay. Không xoá gì — an toàn cho dev local (không phải data người dùng thật),
nhưng nếu cần catalog sạch để demo thì `DELETE FROM restaurants WHERE
source='pipeline'` (cascade xoá `venue_photos`) trước khi chạy lại.
