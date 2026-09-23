# OTel E2E verification — anmates-api

Plan: [`superpowers/plans/2026-09-08-otel-go-instrumentation.md`](superpowers/plans/2026-09-08-otel-go-instrumentation.md) · Task 6

**Verify ngày:** 2026-09-16 · branch `feat/otel-go-instrumentation`
**Version:** otel-go `v1.46.0` · otelfiber/v2 `v2.2.3` (semconv 1.21) · otelpgx `v0.12.0` · contrib/runtime `v0.71.0`

## Phạm vi đã chạy

Cluster (`10.10.10.11:6443`) **không kết nối được** lúc verify — `kubectl` timeout.
Vì vậy verify chia hai tầng:

| Tầng | Môi trường | Trạng thái |
|---|---|---|
| **Local E2E** | `deploy/otel-e2e-local/` — Postgres + OTel Collector 0.120 (spanmetrics cùng dimensions với gateway) + Tempo 2.6.1, app chạy native | ✅ Đã chạy |
| **Cluster E2E** | Alloy → gateway → Tempo/Mimir/Loki → Grafana | ⏳ Chưa chạy — cần cluster |

Chạy lại local:

```bash
deploy/otel-e2e-local/up.sh        # sinh secret ephemeral vào .env (gitignored) + lên compose
deploy/otel-e2e-local/run-api.sh
curl -s -D- -o /dev/null "localhost:58080/api/v1/venues?lat=10.77&lng=106.7" | grep -i x-trace-id
curl -s -H 'Accept: application/json' localhost:53200/api/traces/<TRACE_ID>
curl -s localhost:58889/metrics | grep traces_span_metrics_calls_total
docker compose --env-file deploy/otel-e2e-local/.env -f deploy/otel-e2e-local/compose.yml down -v
```

Mọi port của rig bind vào `127.0.0.1` — không nghe được từ máy khác trên mạng.
Mật khẩu Postgres + JWT secret sinh ngẫu nhiên mỗi lần chạy `up.sh`, không có
giá trị cố định nào trong file commit được.

## Kết quả theo bước của Task 6

| Step | Kiểm tra | Local | Cluster | Bằng chứng (local) |
|---|---|---|---|---|
| 1 | `X-Trace-Id` 32 hex, mỗi request một id | ✅ | ⏳ | 200/401/404 đều có header; `/health` không có. Preflight CORS trả `Access-Control-Expose-Headers: X-Trace-Id` |
| 2 | Receiver nhận span | ✅ | ⏳ | `otelcol_receiver_accepted_spans` 100, tăng theo traffic |
| 3 | Exporter gửi, không lỗi | ✅ | ⏳ | `exporter_sent_spans` 100, `send_failed_spans` 0, `send_failed_metric_points` 0 |
| 4 | 1 root, DB span là con của HTTP span | ✅ | ⏳ | `GET /api/v1/venues` (SERVER, root) → `pool.acquire`, `SELECT` (CLIENT, parent = root) |
| 5 | spanmetrics có series, span_name là route pattern | ✅ | ⏳ | `span_name="GET /api/v1/venues"`, `"GET /api/v1/venues/:id/photos/:position"` — không UUID |
| 6 | 🔴 Dimension semconv không rỗng | ✅ | ⏳ | `http_request_method="GET"`, `http_response_status_code="200"` có mặt → otelfiber phát semconv mới, **khớp gateway, không cần sửa** |
| 7 | servicegraph | — | ⏳ | Rig local không bật servicegraph; api chưa gọi service nào qua HTTP có instrument |
| 8 | Log có `trace_id` | ✅ | ⏳ | `"trace_id":"c4d277e8…","span_id":"a890b560…"` trong dòng log `request`; khớp regex derivedFields. Loki chưa verify |
| 9 | 5 correlation jump trong Grafana | — | ⏳ | Cần Grafana cluster |
| 10 | 🔴 HPA chain nguyên vẹn | ✅ (static) | ⏳ | `http_requests_total` không đổi; `helm template` prod: ServiceMonitor `path: /metrics`, `interval: 30s`; HPA vẫn tham chiếu `http_requests_per_second` |
| 11 | Data-Bridge writer vào pipeline | — | ⏳ | Ngoài phạm vi repo này |

## Lỗi thật tìm ra khi verify (đã sửa)

1. **Span cuối bị mất mỗi lần pod terminate** — `app.Listen` trả về ngay khi
   `ShutdownWithContext` bắt đầu, `main` thoát trong lúc `otelShutdown` còn flush.
   Tái hiện: request ngay trước SIGTERM không bao giờ tới collector (counter đứng yên).
   Sửa: `run()` đợi `shutdownDone`. Sau sửa: counter 100 → 104, trace có trong Tempo.
2. **Flush treo 15s khi collector chết** — dùng chung `shutCtx`. Sửa: timeout riêng 5s.
   Đo: collector chết thoát sau 5.06s (trước 15.11s); collector sống 0.37s.
3. **PII trong span** — otelfiber ghi `url.query` + `url.full` (gồm query) vào mọi
   server span, không có option tắt. Query chứa toạ độ GPS (`/venues?lat=&lng=`) và
   từ khoá tìm kiếm. Regex PII của Task 7 Step 3 **không bắt được** loại này.
   Sửa: `telemetry/redact.go` — exporter wrapper bỏ `url.query`, cắt query khỏi `url.full`.
   Sau sửa: 0 hit `lat=`/`lng=` trong trace, `url.full=/api/v1/venues`.
4. **Migration 015 có conflict marker sót** (`>>>>>>> 381340f…`) — DB mới không migrate
   được, app fatal lúc khởi động. Không liên quan OTel nhưng chặn E2E. Migrator track theo
   tên file nên DB đã apply 015 không bị ảnh hưởng.

## Còn phải làm khi cluster lên

### Điều kiện: image có SDK phải chạy trên cluster

Code OTel nằm trên branch `feat/otel-go-instrumentation`. CI chỉ build + push image khi
push lên `main`. Pod đang chạy là image cũ → **không có SDK**, dù chart đã có
`api.otel.enabled`.

```bash
# 1. Pipeline observability 0.5.0 đã lên (runbook anmates-infra otlp-lgtm-deploy.md §4.1–4.7)
kubectl -n monitoring get svc observability-alloy observability-otel-gateway

# 2. Merge branch → CI push ghcr.io/<owner>/anmates-api:<sha>, rồi trên host:
helm upgrade --install anmates ./deploy/charts/anmates -n anmates \
  -f deploy/charts/anmates/values-prod.yaml \
  --set image.owner=<owner> --set image.api.tag=<sha> --set image.web.tag=<sha> \
  --atomic --wait --timeout 10m

# 3. Verify tự động (runbook §4.5–4.7 §6 + plan Task 6/7)
deploy/scripts/verify-otel.sh
```

### Bốn tầng để biết SDK đã thật sự được áp

| Tầng | Câu hỏi | Kiểm bằng | `verify-otel.sh` |
|---|---|---|---|
| Image | binary có instrumentation không | `go version -m` trên `/app/api` rút từ image → phải thấy `otelfiber`, `otelpgx`, `otlptracegrpc`. **Không** grep `opentelemetry` trơn: `main` đã có `go.opentelemetry.io/otel` gián tiếp | mục 1 |
| Cấu hình | pod có `OTEL_*` không | env của Deployment: `OTEL_EXPORTER_OTLP_ENDPOINT` trỏ Alloy, `OTEL_TRACES_SAMPLER=parentbased_always_on` | mục 2 |
| Runtime | SDK có khởi động không | log `"msg":"OpenTelemetry bật"` (image mới + env có) hoặc `"OpenTelemetry tắt"` (image mới, thiếu env). Không thấy dòng nào = image cũ | mục 3 |
| Pipeline | dữ liệu tới được đâu | `X-Trace-Id` → Alloy `accepted_spans` → gateway `sent_spans`/`send_failed` → Tempo → spanmetrics Mimir → Loki | mục 4–9 |

Mục 10 là hợp đồng HPA (runbook §4.7), mục 11 là checklist correlation làm tay trên Grafana.

Script đã chạy thử trên rig local (có thêm Prometheus đứng thay query API của Mimir, và
spanmetrics namespace `traces.spanmetrics` giống gateway) — 10/10 PASS:

```bash
deploy/otel-e2e-local/up.sh && deploy/otel-e2e-local/run-api.sh &
SKIP_K8S=1 SKIP_LOKI=1 API_URL=http://localhost:58080 \
  ALLOY_METRICS_URL=http://localhost:58888/metrics GATEWAY_METRICS_URL=http://localhost:58888/metrics \
  TEMPO_URL=http://localhost:53200 MIMIR_URL=http://localhost:59090 \
  deploy/scripts/verify-otel.sh
```

Sau khi chạy trên cluster, cập nhật cột **Cluster** ở bảng trên và `docs/otel-conformance.md`.
