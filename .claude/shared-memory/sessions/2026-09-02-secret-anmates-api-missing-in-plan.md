# Session 2026-09-02 — Vá lỗ hổng "secret anmates-api" trong plan on-prem k8s

## TL;DR
User deploy pod `api` bị `Error: secret "anmates-api" not found`. Nguyên nhân là gap trong
`docs/plans/2026-09-01-mvp-1day-onprem-k8s.md`, không phải bug code/chart. Đã vá doc, chưa có
xác nhận user chạy lại và pass.

## Root cause
- Chart `deploy/charts/anmates/templates/api-deployment.yaml` dùng
  `envFrom.secretRef.name: {{ .Values.api.secretName }}` = `anmates-api` (đúng, khớp
  `values.yaml`) — chart không có bug.
- Lệnh `kubectl create secret generic anmates-api ...` CÓ tồn tại trong plan (H3, dưới phần
  "Helm chart app"), nhưng:
  1. H0 "Tiền đề" không liệt kê việc thu thập 6 giá trị cần cho secret
     (`JWT_SECRET`, `FIREBASE_WEB_API_KEY`, `GOONG_API_KEY`, `FOURSQUARE_KEY`,
     `SMTP_PASSWORD`, + `DATABASE_URL` ghép từ H2) — lệnh ở H3 chỉ có placeholder `...`.
  2. H5 (Deploy) không có pre-flight check secret tồn tại trước `helm upgrade`, và lệnh tạo
     secret nằm lẫn giữa code Helm chart ở H3 (không có ⚠️ cảnh báo riêng) → dễ bỏ sót khi làm
     runbook theo thứ tự H3→H4→H5.

## Solution (đã áp dụng vào doc)
- H0: thêm bảng 7 giá trị cần cho secret `anmates-api` + nguồn lấy từng giá trị.
- H3: thêm cảnh báo ⚠️ BẮT BUỘC trước H5 ngay trên lệnh `kubectl create secret generic
  anmates-api`, + lệnh xác nhận đủ key (`kubectl get secret ... -o jsonpath='{.data}'`).
- H5: thêm pre-flight `kubectl -n anmates get secret ghcr-pull anmates-api
  anmates-db-credentials` trước dòng `helm upgrade`.

## Files changed
- `docs/plans/2026-09-01-mvp-1day-onprem-k8s.md`

## Verification (pending)
User cần tự chạy trên PC host (Claude Code không có kubeconfig cluster on-prem):
```bash
kubectl -n anmates create secret generic anmates-api \
  --from-literal=DATABASE_URL=postgres://anmates:<password>@anmates-db.anmates.svc.cluster.local:5432/anmates?sslmode=disable \
  --from-literal=JWT_SECRET=<random> \
  --from-literal=FIREBASE_WEB_API_KEY=<firebase-console> \
  --from-literal=GOONG_API_KEY=<goong> \
  --from-literal=FOURSQUARE_KEY=<foursquare> \
  --from-literal=SMTP_PASSWORD=<smtp> \
  --from-literal=DEV_BYPASS_SECRET=<random-32-chars>
kubectl -n anmates rollout status deploy/anmates-api
```
Chờ user báo lại pod `api` Ready hay còn lỗi khác (vd DATABASE_URL sai password → CrashLoop
khác với "secret not found").

## Open follow-ups
- Nếu user confirm fix work → migrate session này thành `R-0XX` theo Path A của CLAUDE.md.
- Cân nhắc thêm 1 dòng vào `values.yaml`/NOTES.txt Helm chart in ra cảnh báo nếu thiếu secret
  (không làm hôm nay — ngoài phạm vi câu hỏi hiện tại, chỉ sửa doc).

## Key facts
- Secret cần 2 secret khác nữa cũng phải tồn tại trước `helm upgrade`: `ghcr-pull`
  (docker-registry, tạo cùng lúc ở H3) và `anmates-db-credentials` (tạo ở H2).
- namespace `anmates` phải tồn tại trước (tạo ở H2, lệnh H3 idempotent lặp lại `kubectl create
  ns anmates --dry-run=client -o yaml | kubectl apply -f -`).
