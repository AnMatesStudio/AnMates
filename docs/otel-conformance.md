# OTel conformance — anmates-api

Verify ngày: 2026-09-16 · local E2E (`deploy/otel-e2e-local/`) · cluster: **chưa** (không kết nối được)
Chi tiết: [`observability-e2e-verified.md`](observability-e2e-verified.md)

✅ đạt · ⏳ cần verify trên cluster

| # | Best practice | Trạng thái | Bằng chứng |
|---|---|---|---|
| 1 | Cấu hình qua `OTEL_*` env, không hardcode | ✅ | Không file `.go` nào chứa `4317`/`observability-alloy` ngoài doc comment. Không gọi `WithSampler`/`WithInsecure` — option tường minh đè env (đã đọc source SDK v1.46) |
| 2 | W3C TraceContext propagator | ✅ | `TestTraceparentIsContinued` PASS |
| 3 | Resource attrs: service.name/version/namespace, deployment.environment, k8s.* | ✅ local / ⏳ cluster | Local đủ 7 attr bắt buộc, `telemetry.sdk.language=go`. Cluster cần kiểm downward API thật |
| 4 | Span name low-cardinality (route pattern) | ✅ | `TestSpanNameUsesRoutePattern` + spanmetrics local: 6 span_name. Ghi chú: 401 do JWT middleware gộp thành `GET /api/v1` |
| 5 | Không PII/secret trong attribute | ✅ | Query string bị redact trước export (`telemetry/redact.go`, `TestRedactingExporterDropsQueryString`); otelpgx không bật `WithIncludeQueryParameters`; 0 hit email/JWT/password/lat/lng |
| 6 | Status ERROR chỉ cho 5xx/exception | ✅ | `TestServerSpanStatusFollowsSemconv` (500→Error, 404→Unset); local 401/404 → UNSET |
| 7 | Head sampling TẮT (tail sampling ở gateway) | ✅ | Chart render `OTEL_TRACES_SAMPLER=parentbased_always_on`; `TestDefaultSamplerIsAlwaysOn` |
| 8 | BatchSpanProcessor | ✅ | `telemetry.go` chỉ có `WithBatcher` |
| 9 | Shutdown flush span | ✅ local / ⏳ cluster | Sửa bug thoát sớm; request ngay trước SIGTERM có trong Tempo. Cluster: Task 7 Step 9 |
| 10 | Telemetry không chặn khởi động | ✅ | `TestSetupDoesNotBlockOnDeadCollector` PASS; binary thật với collector chết Ready sau 0.71s, shutdown ≤ 5.06s |
| 11 | DB span là con của HTTP span | ✅ local / ⏳ cluster | Tempo local: 1 root, CLIENT span có parent |
| 12 | spanmetrics dimension khớp semconv của SDK | ✅ | `http_request_method`, `http_response_status_code` có giá trị với cùng khai báo dimension như gateway |
| 13 | 5 correlation jump hoạt động | ⏳ | Cần Grafana cluster |
| 14 | HPA chain không bị hỏng | ✅ static / ⏳ live | `middleware/metrics.go` không đổi, `TestMetrics_*` PASS, helm render ServiceMonitor/HPA không đổi |

## Chưa đạt / còn nợ

- **Flutter RUM** — Dart chưa có official OTel SDK. Hiện dùng `X-Trace-Id` response header
  (đã expose qua CORS) làm đường thay thế.
- **WebSocket tracing** — `/ws/` bị loại khỏi trace. DB query trên đường WS message và
  goroutine concierge dùng `context.Background()` → thành root span `SELECT` riêng lẻ trong
  Tempo (không mồ côi khỏi HTTP trace nào, nhưng là noise). Message-level tracing chưa làm.
- **Outbound HTTP chưa instrument** — Firebase verify và LLM (`AI_BASE_URL`) dùng
  `http.Client` trần, không có CLIENT span → servicegraph không có cạnh nào. Bước tiếp:
  `otelhttp.NewTransport`.
- **Metrics nghiệp vụ** — mới có runtime, `http.server.*` (otelfiber) và `db.client.*`
  (otelpgx). Chưa có counter/histogram cho match created, booking confirmed, concierge fired.
- **Span name khi auth fail** — 401 từ `jwtMW` mang tên `GET /api/v1` (route của
  middleware group), không phải route đích. Low-cardinality nên an toàn, nhưng kém thông tin.
