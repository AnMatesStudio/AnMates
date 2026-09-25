# 2026-09-25 — Ảnh thumbnail đã chọn ở Data-Pipeline → địa điểm trên AnMates

## TL;DR
App đã đọc `venue_photos` slot 0 làm thumbnail, nhưng bộ ảnh đó KHÔNG khớp với những gì người duyệt chọn ở màn Chờ duyệt. Có 3 lỗ hổng trên đường Data-Pipeline → Data-Bridge → AnMates, đã vá cả 3.

## Root cause
1. `serving/publish.py::_frames` bỏ qua ảnh AI (`generated_thumbnails` + `selected_generated`) → ảnh AI tick chọn không bao giờ tới app.
2. Writer Data-Bridge chỉ upsert theo position, không bao giờ xoá → bỏ chọn bớt ảnh thì slot cũ nằm lại trong `venue_photos`, app vẫn hiện.
3. `/venues/:id/photos/:pos` trả `Cache-Control: immutable, max-age=1y` trên URL không đổi → đổi ảnh bìa thì browser (Flutter web) giữ ảnh cũ cả năm.

## Solution
- Data-Pipeline: `_frames` xuất ảnh AI đã tick (kind `generated`, xếp sau frame, trước menu); `schema.sql` nới CHECK `media_assets.kind`; `sync_anmates.py` lấy thêm kind `generated` + gửi `photo_count` trên message venue (None khi có ảnh mà thiếu bytes → không xoá).
- Data-Bridge writer: `prune_photos()` xoá `position >= photo_count` trong cùng transaction upsert venue. Trường tuỳ chọn → không tăng `schema_version`.
- AnMates API: `/venues` trả `photo_versions` (12 ký tự đầu sha256 mỗi slot); Flutter gắn `?v=<version>` vào URL ảnh.

## Files changed
- Data-Pipeline: serving/{publish.py,schema.sql,sync_anmates.py}, tests/test_publish_generated_and_prune.py
- AnMates-Data-Bridge: writer/app/db.py, docs/api-contract.md
- AnMates: anmates-api/{services/venue_catalog.go,handlers/venue_photo.go}, anmates_flutter/lib/services/{api_client,venue_catalog_service}.dart, test/venue_catalog_test.dart

## Verification
- pytest publish/sync suites PASS (test_end_to_end fail sẵn từ trước, không liên quan); go build + go test services/handlers PASS; flutter test venue_catalog_test PASS.
- CHƯA verify trên môi trường thật (pending user).

## Deploy order / open follow-ups
- Serving DB phải chạy lại `serving/schema.sql` (idempotent) TRƯỚC khi publish bản ghi có ảnh AI, nếu không vi phạm CHECK như lỗi 'menu' ngày 2026-09-06.
- Redeploy writer (PC B), API + web.
- Còn tồn tại: bỏ tick HẾT khung hình → `selected_thumbnails=[]` = "giữ tất cả" (quy ước chung của publish/export/readiness), nên tất cả khung hình vẫn đi xuống.
