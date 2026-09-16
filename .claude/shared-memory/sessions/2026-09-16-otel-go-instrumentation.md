# 2026-09-16 — OTel SDK instrumentation cho anmates-api (Go)

## TL;DR
Implement plan `docs/superpowers/plans/2026-09-08-otel-go-instrumentation.md` Task 1–5
trên branch `feat/otel-go-instrumentation` (10 commit). Task 6/7 (E2E) chạy trên **rig
local** vì cluster `10.10.10.11:6443` không kết nối được. E2E local tìm ra 3 bug thật
trong plan/wiring + 1 bug có sẵn trên main — đã sửa hết.

## Kết quả
- `telemetry/` — SDK bootstrap, env-only, endpoint rỗng = no-op. Traces + metrics OTLP gRPC.
- `middleware/tracing.go` — otelfiber, span name `METHOD /route/:pattern`, skip `/health` `/metrics` `/ws/`, header `X-Trace-Id` (CORS expose).
- `db/db.go` — otelpgx QueryTracer (span name = operation, không param).
- `middleware/logger.go` — `trace_id`/`span_id` mỗi dòng log.
- Chart: block `api.otel` (tắt mặc định, bật ở values-prod), downward API cho `k8s.*`.
- `deploy/otel-e2e-local/` — Postgres + Collector 0.120 (spanmetrics dims giống gateway) + Tempo.

## Lệch so với plan (có lý do, đã verify bằng source SDK)
- KHÔNG `sdktrace.WithSampler(...)` — option tường minh đè `OTEL_TRACES_SAMPLER`.
- KHÔNG `WithInsecure()` — đè scheme-based TLS + `OTEL_EXPORTER_OTLP_INSECURE`; `http://` tự thành plaintext.
- KHÔNG `otelpgx.WithTrimSQLInSpanName()` — deprecated ở v0.12, đã là mặc định.
- Test helper đổi tên `newTracingTestApp` (trùng `newTestApp` trong auth_test.go).
- `OTEL_RESOURCE_ATTRIBUTES` render một dòng thay vì folded scalar.

## Bug tìm ra khi E2E (đã sửa)
1. Shutdown: `app.Listen` return ngay khi shutdown bắt đầu → main thoát trước khi `otelShutdown` flush → mất span cuối mỗi lần pod terminate. Fix: `shutdownDone` channel.
2. Flush treo 15s khi collector chết → timeout riêng 5s.
3. PII: otelfiber ghi `url.query`/`url.full` (lat/lng, search q) → `telemetry/redact.go` exporter wrapper.
4. `db/migrations/015_sync_ledger.sql` dòng cuối `>>>>>>> 381340f…` (merge b92bc0c) → DB mới fatal lúc migrate.

## Verification
- `go build`/`vet`/`test -race` (trừ smoke) PASS.
- Local E2E: xem `docs/observability-e2e-verified.md`, `docs/otel-conformance.md`.
- Cluster E2E: **PENDING** (Task 6 Step 1–11, Task 7 Step 1–9).

## Key facts
- otelfiber v2.2.3 dùng semconv v1.21 → `http.request.method`/`http.response.status_code` → khớp gateway spanmetrics, không cần đổi infra.
- otelfiber cũng phát metric OTLP `http.server.duration` (ms) — song song, không đụng `http_requests_total`.
- DB query trên đường WS/concierge dùng `context.Background()` → root span `SELECT` lẻ (không phải orphan của HTTP trace).
- 401 từ jwtMW có span name `GET /api/v1`.

## Open follow-ups
- Chạy Task 6/7 trên cluster khi kết nối được; cập nhật cột Cluster trong 2 doc.
- `otelhttp.NewTransport` cho Firebase + LLM client (servicegraph đang rỗng).
- Commit đầu (3ff4e56) không build riêng lẻ (main.go gọi `middleware.Tracing` từ commit sau) — squash khi merge nếu cần bisect sạch.
