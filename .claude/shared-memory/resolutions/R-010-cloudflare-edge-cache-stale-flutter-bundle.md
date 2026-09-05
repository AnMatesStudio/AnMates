---
id: R-010
title: Deploy v2 xong vẫn hiện UI v1 — nginx gắn `immutable, max-age=30d` lên main.dart.js (Flutter không hash tên file), Cloudflare edge giữ bản cũ
tags: [cloudflare, cdn, cache, edge-cache, purge-cache, cloudflare-tunnel, nginx, cache-control, immutable, flutter-web, main-dart-js, stale-deploy, cf-cache-status]
platforms: [web]
severity: major
status: confirmed
date_resolved: 2026-09-02
confirmed_by: user
related_sessions: [sessions/2026-09-02-explore-v2-design-import.md]
related_blockers: []
---

# R-010: Deploy xong vẫn hiện UI cũ — Cloudflare edge cache giữ `main.dart.js` 30 ngày

## TL;DR
Sau khi merge + deploy UI v2 lên k8s on-prem, truy cập domain vẫn ra UI v1. Không phải lỗi
deploy, không phải Cloudflare Tunnel tự cache. Nguyên nhân: `nginx.conf` gắn
`Cache-Control: public, max-age=2592000, immutable` cho mọi file `.js`, trong khi
`flutter build web` **không hash tên file** — `main.dart.js` giữ nguyên tên qua mọi build.
Cloudflare edge tuân thủ đúng header đó và giữ bundle cũ 30 ngày. `Purge Everything` là fix
tức thời; sửa header là fix gốc.

## Symptoms
- Deploy thành công (CI xanh, image push GHCR, helm upgrade chạy), nhưng domain vẫn render UI v1
- `index.html` trả về hoàn toàn tươi (`Cf-Cache-Status: DYNAMIC`, `Server-Timing: cfOrigin;dur=93`)
  → dễ nhầm là "không có cache", nhưng đó chỉ là entry point
- Sau `Purge Everything` trên Cloudflare dashboard → v2 hiện ngay lập tức

## Root Cause
Chuỗi tải của Flutter web đều là **tên file tĩnh, không content-hash**:

```
index.html          (no-store  ✓ luôn tươi)
  └─ flutter_bootstrap.js   ← cùng tên mọi build
       └─ main.dart.js      ← cùng tên mọi build, 2.64 MB, chứa TOÀN BỘ code UI
```

`nginx.conf` có block:
```nginx
# Aggressive caching for hashed assets.     ← giả định SAI
location ~* \.(?:css|js|...)$ {
    expires 30d;
    add_header Cache-Control "public, max-age=2592000, immutable";
}
```

Comment ghi "hashed assets" nhưng Flutter không hash gì cả (verify: `find build/web -type f`
→ **0 file** khớp pattern `*.<hash>.js`). Nên:
- `immutable` = cache tuyệt đối không revalidate, kể cả khi user bấm reload
- `max-age=2592000` = 30 ngày

Theo docs Cloudflare (default-cache-behavior): `.js` nằm trong danh sách đuôi file cache mặc
định, và edge **cache theo đúng `max-age` origin khai** khi header là `public` + `max-age > 0`
(bảng TTL mặc định 120 phút chỉ áp dụng khi origin KHÔNG gửi header nào). Tức chính origin tự
ra lệnh cho Cloudflare giữ 30 ngày.

`index.html` được set `no-store` nên luôn tươi — **nhưng vô dụng**, vì nó chỉ trỏ tới
`flutter_bootstrap.js` → `main.dart.js`, cả hai đều bị đóng băng.

## Solution

### Fix tức thời (đã dùng)
Cloudflare dashboard → Caching → Configuration → **Purge Everything**. Cache Cloudflare là
**per-PoP**, purge xoá đồng loạt mọi PoP; nếu đợi tự nhiên thì phải hết 30 ngày.

### Fix gốc (code)
| File | Change |
|------|--------|
| `anmates_flutter/nginx.conf` | Bỏ `immutable`, hạ `max-age` 2592000 → **7200 (2h)**, bỏ `expires 30d` (nó tự phát Cache-Control riêng → gửi trùng field), thêm `otf` vào danh sách đuôi |

Quyết định **vẫn cache `.js`** (không chuyển sang `no-store`): `main.dart.js` nặng 2.64 MB —
bỏ cache thì mỗi lượt tải trang đều kéo lại 2.64 MB và mọi request đều xuyên tunnel về máy
on-prem, mất sạch lợi ích CDN. Lỗi nằm ở `immutable` + 30 ngày, không nằm ở việc cache.

Chọn 2h vì trùng TTL mặc định của Cloudflare cho response 200 → hành vi edge dễ đoán, và
worst-case staleness sau deploy chỉ còn 2 tiếng (hoặc 1 lần purge nếu cần ngay).

## Verification
- User `Purge Everything` → UI v2 hiện ngay → xác nhận đúng tầng cache là thủ phạm ✅
- Header `index.html` do user gửi: `Cf-Cache-Status: DYNAMIC` + `cfOrigin;dur=93` → chứng minh
  entry point vốn đã luôn tươi, vấn đề nằm ở hop tiếp theo ✅
- Build output verify: `find build/web -type f | grep -E "\.[a-f0-9]{8,}\.(js|css)$"` → rỗng,
  chứng minh Flutter không hash tên file ✅
- ⚠️ **Fix nginx CHƯA verify trên prod** — cần deploy lần tới rồi kiểm tra header của
  `main.dart.js` (không phải của `/`): kỳ vọng `cache-control: public, max-age=7200`, không còn
  `immutable`.

## Why this fix works (for future-Claude)
- **Kiểm tra `Cf-Cache-Status` của ĐÚNG file đang nghi ngờ.** User gửi header của `/`
  (index.html) thấy `DYNAMIC` và tưởng "không có cache" — nhưng file có vấn đề là
  `main.dart.js`. Với SPA, entry point tươi không đảm bảo gì; phải soi file bundle.
- **`immutable` chỉ dành cho filename có content-hash.** Bất cứ build tool nào giữ nguyên tên
  file qua các build (Flutter web là một ví dụ điển hình) thì `immutable` luôn sai.
- **Cloudflare Tunnel (cloudflared) tự nó KHÔNG cache.** Nhưng hostname của tunnel luôn đi qua
  Cloudflare edge, và edge tuân theo `Cache-Control` của origin. Đừng đổ lỗi cho tunnel.
- Cloudflare cache **theo từng PoP** — hai user ở hai vùng có thể thấy version khác nhau tuỳ
  thời điểm PoP đó cache. Đây là lý do bug trông "lúc có lúc không".

## Gotchas / Related issues
- **Không thêm `json` vào regex location đó.** Trong nginx, regex location ưu tiên hơn prefix
  location, nên `/api/...` nào kết thúc bằng đuôi trong danh sách sẽ bị phục vụ từ disk thay vì
  proxy sang API. Hiện tại đã verify: **0 route API nào** kết thúc bằng đuôi file tĩnh nên chưa
  gãy, nhưng thêm `json` sẽ mở rộng rủi ro đáng kể.
- **`flutter_service_worker.js` từ Flutter 3.44 chỉ còn là stub tự huỷ** (`self.registration.unregister()`)
  — service worker đã deprecated. Nên tầng cache phía browser do SW gây ra **không còn tồn tại**;
  đừng đi tìm nguyên nhân ở đó nữa.
- `canvaskit/` nặng 37 MB nhưng chỉ đổi khi nâng Flutter SDK. Với 2h TTL thì repeat visitor sẽ
  revalidate lại — chấp nhận được, nhưng nếu sau này thấy tốn băng thông thì đây là ứng viên
  tách rule riêng TTL dài.
- Muốn **staleness = 0** mà vẫn giữ cache dài: phải cache-bust bằng URL (thêm `?v=<git-sha>` vào
  `flutter_bootstrap.js` trong `index.html` **và** vá tham chiếu `main.dart.js` bên trong
  bootstrap) — cần bước post-build sed trong Dockerfile/CI. Chưa làm, ngoài phạm vi lần này.

## References
- [Cloudflare — Default cache behavior](https://developers.cloudflare.com/cache/concepts/default-cache-behavior/)
- [Cloudflare — CDN-Cache-Control](https://developers.cloudflare.com/cache/concepts/cdn-cache-control/)
- [Cloudflare — Cache responses (CF-Cache-Status values)](https://developers.cloudflare.com/cache/concepts/cache-responses/)
- Liên quan: [R-009](R-009-v2-design-full-migration-and-v1-removal.md) — chính lần deploy v2 làm lộ ra bug này
