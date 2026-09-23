# OTel SDK Instrumentation cho anmates-api (Go) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Instrument `anmates-api` (Go Fiber + pgx) bằng OpenTelemetry SDK — traces, metrics, logs correlation — rồi verify E2E toàn bộ pipeline tới Grafana và audit theo OTel semantic conventions.

**Architecture:** Go **không có zero-code agent** (khác Python `opentelemetry-instrument`), nên SDK phải wire tay. Bootstrap đọc cấu hình **hoàn toàn từ `OTEL_*` environment** — không hardcode endpoint trong code. `otelfiber` tạo server span, `otelpgx` tạo DB span, `slog` gắn `trace_id` vào mỗi dòng log. Head sampling **TẮT** vì tail sampling nằm ở gateway.

**Tech Stack:** Go 1.25, Fiber v2.52.14, pgx v5.9.2, `go.opentelemetry.io/otel`, `github.com/gofiber/contrib/otelfiber/v2`, `github.com/exaring/otelpgx`.

**Spec:** [`../../../anmates-infra/docs/decisions/2026-09-08-otlp-lgtm-adoption.md`](../../../../anmates-infra/docs/decisions/2026-09-08-otlp-lgtm-adoption.md)

**Phụ thuộc:** Plan `anmates-infra/docs/superpowers/plans/2026-09-08-otlp-lgtm-pipeline.md` phải xong Task 4 (Alloy có Service) trước khi chạy Task 6 của plan này.

## Global Constraints

- 🔴 **KHÔNG đổi tên metric `http_requests_total`** trong `middleware/metrics.go`. Đó là hợp đồng với `prometheus-adapter` (rule `^(.*)_total` → `${1}_per_second`); đổi là HPA về `<unknown>`. `fiberprometheus` và spanmetrics **chạy song song**, không thay nhau.
- 🔴 **Telemetry không được chặn khởi động.** Collector chưa có thì app vẫn phải Ready. Observability không bao giờ được là hard dependency của đường phục vụ request.
- 🔴 **Head sampling TẮT** — `OTEL_TRACES_SAMPLER=parentbased_always_on`. Gateway làm tail sampling; SDK bỏ span trước thì gateway không còn gì để quyết định.
- 🔴 **Span name phải là route pattern**, không phải URL thô: `/api/v1/venues/:id`, không phải `/api/v1/venues/9f3c-...`. Mỗi id là một series `traces_spanmetrics_calls_total` mới.
- Cấu hình **chỉ qua env**. Không file Go nào chứa endpoint, exporter URL hay service name literal.
- `/health` và `/metrics` **bị loại khỏi trace** giống như đã bị loại khỏi `http_requests_total` — kubelet probe 10s + scrape 30s sẽ ngập Tempo.
- semconv: dùng **`http.request.method` / `http.response.status_code`** (semconv ≥ 1.21 stable HTTP). Gateway `spanmetrics.dimensions` khai đúng hai tên này — sai tên thì dimension rỗng.

## Test cycle — chạy sau MỖI task

```bash
cd /Users/thanhit/AnMatesStudio/AnMates/anmates-api

# GO111MODULE=on BẮT BUỘC: máy này có GO111MODULE=off trong
# ~/Library/Application Support/go/env, không set thì go rơi về GOPATH mode và
# báo "cannot find package" cho MỌI import. Không sửa file env global đó —
# nó ảnh hưởng mọi project Go khác trên máy.
export GO111MODULE=on

go build ./...
go vet ./...

# LOẠI package `smoke`: nó là integration test gọi http://localhost:8080, cần
# server đang chạy. Baseline (trước mọi thay đổi) đã FAIL 4 test ở đó vì không
# có server — đó là hành vi bình thường của nó, không phải regression.
go test $(go list ./... | grep -v /smoke) -race
```

**Baseline đã verify 2026-09-08** (trước khi implement gì):
`build` exit 0 · `vet` exit 0 · unit test PASS (`middleware`, `services`, `ws`)
· `smoke` FAIL 4/4 vì không có server — pre-existing, bỏ qua.
Toolchain: `go.mod` khai `go 1.25.0`, máy cài go1.23.2 nhưng `GOTOOLCHAIN=auto`
tự kéo go1.25.0 về khi ở module mode. Không cần cài tay.

---

## File Structure

```
anmates-api/
├── go.mod / go.sum                 MODIFY  Task 1
├── telemetry/
│   ├── telemetry.go                CREATE  Task 1 — SDK bootstrap + Shutdown
│   └── telemetry_test.go           CREATE  Task 1
├── middleware/
│   ├── tracing.go                  CREATE  Task 2 — otelfiber + X-Trace-Id
│   ├── tracing_test.go             CREATE  Task 2
│   ├── logger.go                   MODIFY  Task 4 — thêm trace_id/span_id
│   └── metrics.go                  KHÔNG ĐỔI (hợp đồng HPA)
├── db/
│   ├── db.go                       MODIFY  Task 3 — otelpgx QueryTracer
│   └── db_test.go                  CREATE  Task 3
└── main.go                         MODIFY  Task 1,2,4 — wire + shutdown

deploy/charts/anmates/
├── values.yaml                     MODIFY  Task 5 — block api.otel
├── values-prod.yaml                MODIFY  Task 5 — bật
└── templates/api-deployment.yaml   MODIFY  Task 5 — OTEL_* env + downward API
```

**Vì sao `telemetry/` là package riêng:** bootstrap SDK là một trách nhiệm độc lập, có vòng đời riêng (setup ở đầu `run()`, shutdown ở graceful shutdown) và cần test riêng cho hành vi "không chặn khởi động". Nhét vào `main.go` thì không test được.

---

## Task 1: Package `telemetry` — SDK bootstrap không chặn khởi động

**Files:**
- Create: `anmates-api/telemetry/telemetry.go`
- Create: `anmates-api/telemetry/telemetry_test.go`
- Modify: `anmates-api/go.mod`
- Modify: `anmates-api/main.go:60-70` (trong `run()`, sau `config.Load()`)

**Interfaces:**
- Produces:
  - `func Setup(ctx context.Context, log *slog.Logger) (shutdown func(context.Context) error, err error)`
  - `func Enabled() bool` — true khi `OTEL_EXPORTER_OTLP_ENDPOINT` có giá trị
  - Global `otel.GetTracerProvider()` / `otel.GetTextMapPropagator()` được set — Task 2 và 3 dùng ngầm qua các API global.

- [ ] **Step 1: Thêm dependencies**

```bash
cd /Users/thanhit/AnMatesStudio/AnMates/anmates-api
go get go.opentelemetry.io/otel@latest
go get go.opentelemetry.io/otel/sdk@latest
go get go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc@latest
go get go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc@latest
go get go.opentelemetry.io/contrib/instrumentation/runtime@latest
go get github.com/gofiber/contrib/otelfiber/v2@latest
go get github.com/exaring/otelpgx@latest
go mod tidy
```

Ghi lại version thực tế đã resolve — plan này viết theo API hiện hành, nếu upstream đổi thì `go build` ở Step 4 sẽ bắt được ngay:

```bash
go list -m go.opentelemetry.io/otel github.com/gofiber/contrib/otelfiber/v2 github.com/exaring/otelpgx
```

- [ ] **Step 2: Viết test TRƯỚC — hành vi "không chặn khởi động"**

Tạo `telemetry/telemetry_test.go`:

```go
package telemetry

import (
	"context"
	"io"
	"log/slog"
	"testing"
	"time"
)

func quietLogger() *slog.Logger {
	return slog.New(slog.NewJSONHandler(io.Discard, nil))
}

// Không có OTEL_EXPORTER_OTLP_ENDPOINT: Setup phải trả về no-op shutdown và
// KHÔNG lỗi. Telemetry không bao giờ được là hard dependency của app.
func TestSetupDisabledWithoutEndpoint(t *testing.T) {
	t.Setenv("OTEL_EXPORTER_OTLP_ENDPOINT", "")
	t.Setenv("OTEL_SERVICE_NAME", "anmates-api")

	if Enabled() {
		t.Fatal("Enabled() phải false khi không có endpoint")
	}

	shutdown, err := Setup(context.Background(), quietLogger())
	if err != nil {
		t.Fatalf("Setup không được lỗi khi telemetry tắt: %v", err)
	}
	if shutdown == nil {
		t.Fatal("shutdown không được nil")
	}
	if err := shutdown(context.Background()); err != nil {
		t.Fatalf("shutdown no-op không được lỗi: %v", err)
	}
}

// Endpoint trỏ vào cổng chết: Setup vẫn phải trả về nhanh và không lỗi.
// Exporter OTLP/gRPC là non-blocking — nó KHÔNG dial lúc khởi tạo. Nếu test
// này treo hoặc fail nghĩa là ai đó đã thêm grpc.WithBlock().
func TestSetupDoesNotBlockOnDeadCollector(t *testing.T) {
	t.Setenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://127.0.0.1:1")
	t.Setenv("OTEL_EXPORTER_OTLP_PROTOCOL", "grpc")
	t.Setenv("OTEL_SERVICE_NAME", "anmates-api")

	done := make(chan error, 1)
	go func() {
		shutdown, err := Setup(context.Background(), quietLogger())
		if err == nil && shutdown != nil {
			sctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
			defer cancel()
			_ = shutdown(sctx)
		}
		done <- err
	}()

	select {
	case err := <-done:
		if err != nil {
			t.Fatalf("Setup không được lỗi khi collector chết: %v", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("Setup bị chặn — exporter đang dial blocking")
	}
}

// Sampler mặc định phải là always-on: tail sampling nằm ở gateway, SDK bỏ span
// trước thì gateway không còn gì để quyết định.
func TestDefaultSamplerIsAlwaysOn(t *testing.T) {
	t.Setenv("OTEL_TRACES_SAMPLER", "")
	if got := samplerFromEnv(); got != "parentbased_always_on" {
		t.Fatalf("sampler mặc định = %q, muốn parentbased_always_on", got)
	}
}
```

- [ ] **Step 3: Chạy test để xác nhận nó FAIL**

```bash
go test ./telemetry/ -run TestSetup -v
```
Expected: FAIL — `undefined: Setup`, `undefined: Enabled`, `undefined: samplerFromEnv`.

- [ ] **Step 4: Viết `telemetry/telemetry.go`**

```go
// Package telemetry dựng OpenTelemetry SDK cho anmates-api.
//
// Go KHÔNG có zero-code agent như `opentelemetry-instrument` của Python, nên
// phần này phải viết tay. Bù lại, TOÀN BỘ cấu hình đọc từ environment chuẩn
// OTEL_* — không endpoint, không service name nào hardcode trong Go file.
//
// Biến môi trường được dùng (SDK tự đọc, không cần parse tay):
//
//	OTEL_EXPORTER_OTLP_ENDPOINT   http://observability-alloy.monitoring.svc.cluster.local:4317
//	OTEL_EXPORTER_OTLP_PROTOCOL   grpc
//	OTEL_SERVICE_NAME             anmates-api
//	OTEL_RESOURCE_ATTRIBUTES      service.namespace=anmates,deployment.environment=onprem,...
//	OTEL_TRACES_SAMPLER           parentbased_always_on  (xem ghi chú sampler bên dưới)
//
// ENDPOINT RỖNG = TELEMETRY TẮT HOÀN TOÀN, app chạy bình thường. Đây là yêu
// cầu cứng: observability không được phép là hard dependency của đường phục vụ
// request — đúng thứ không ai muốn xử lý lúc 2 giờ sáng.
package telemetry

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"time"

	"go.opentelemetry.io/contrib/instrumentation/runtime"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlpmetric/otlpmetricgrpc"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/propagation"
	sdkmetric "go.opentelemetry.io/otel/sdk/metric"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
)

// Enabled cho biết telemetry có được bật hay không. Một biến duy nhất quyết
// định: có endpoint thì bật, không thì tắt.
func Enabled() bool {
	return os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT") != "" ||
		os.Getenv("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT") != ""
}

// samplerFromEnv trả về sampler sẽ dùng.
//
// Mặc định parentbased_always_on, KHÔNG phải parentbased_traceidratio:
// tail sampling chạy ở OTel Collector gateway, nơi nhìn được TOÀN BỘ span của
// một trace rồi mới quyết định giữ hay bỏ. SDK head-sample trước nghĩa là
// gateway chỉ thấy phần còn sót — error và slow request sẽ bị vứt ngẫu nhiên
// từ trước khi có ai kịp nhìn chúng.
func samplerFromEnv() string {
	if s := os.Getenv("OTEL_TRACES_SAMPLER"); s != "" {
		return s
	}
	return "parentbased_always_on"
}

// Setup dựng TracerProvider + MeterProvider và đăng ký chúng làm global.
//
// Trả về hàm shutdown PHẢI được gọi lúc thoát: BatchSpanProcessor giữ span
// trong buffer, không flush thì mọi span của vài giây cuối biến mất — đúng
// những span mô tả sự cố làm pod chết.
func Setup(ctx context.Context, log *slog.Logger) (func(context.Context) error, error) {
	noop := func(context.Context) error { return nil }

	if !Enabled() {
		log.Info("OpenTelemetry tắt (OTEL_EXPORTER_OTLP_ENDPOINT trống)")
		return noop, nil
	}

	// Sampler đọc từ env bởi SDK, nhưng SDK chỉ đọc khi biến có mặt.
	// Set giá trị mặc định vào env để hành vi khớp với samplerFromEnv().
	if os.Getenv("OTEL_TRACES_SAMPLER") == "" {
		_ = os.Setenv("OTEL_TRACES_SAMPLER", samplerFromEnv())
	}

	// resource.WithFromEnv() đọc OTEL_SERVICE_NAME và OTEL_RESOURCE_ATTRIBUTES.
	// WithHost/WithProcess bổ sung host.name, process.pid... theo semconv.
	res, err := resource.New(ctx,
		resource.WithFromEnv(),
		resource.WithHost(),
		resource.WithProcessPID(),
		resource.WithProcessRuntimeDescription(),
		resource.WithTelemetrySDK(),
	)
	// ErrPartialResource / ErrSchemaURLConflict là cảnh báo, không phải lỗi
	// chí mạng — resource vẫn dùng được. Chỉ bỏ cuộc khi res thực sự nil.
	if err != nil && !errors.Is(err, resource.ErrPartialResource) && !errors.Is(err, resource.ErrSchemaURLConflict) {
		log.Warn("otel resource lỗi, chạy tiếp với resource rút gọn", "err", err)
	}
	if res == nil {
		res = resource.Default()
	}

	// KHÔNG dùng grpc.WithBlock(): exporter phải khởi tạo được ngay cả khi
	// collector chưa lên. Nó tự retry ở nền.
	traceExp, err := otlptracegrpc.New(ctx, otlptracegrpc.WithInsecure())
	if err != nil {
		return noop, fmt.Errorf("otlp trace exporter: %w", err)
	}

	tp := sdktrace.NewTracerProvider(
		sdktrace.WithResource(res),
		// Batch, không phải SimpleSpanProcessor: simple export đồng bộ trên
		// đường request và biến độ trễ của collector thành độ trễ của API.
		sdktrace.WithBatcher(traceExp,
			sdktrace.WithBatchTimeout(5*time.Second),
			sdktrace.WithMaxExportBatchSize(512),
			sdktrace.WithMaxQueueSize(4096),
		),
		sdktrace.WithSampler(sdktrace.ParentBased(sdktrace.AlwaysSample())),
	)
	otel.SetTracerProvider(tp)

	// W3C TraceContext + Baggage. Đây là thứ làm traceparent tự động truyền
	// qua mọi HTTP hop — không file nào trong repo đọc/ghi header trace bằng tay.
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
		propagation.TraceContext{},
		propagation.Baggage{},
	))

	// Lỗi nội bộ của SDK đi vào log của app thay vì stderr trần.
	otel.SetErrorHandler(otel.ErrorHandlerFunc(func(e error) {
		log.Warn("otel sdk", "err", e)
	}))

	shutdowns := []func(context.Context) error{tp.Shutdown}

	// Metrics: runtime Go (goroutine, GC, heap). KHÔNG đụng tới
	// http_requests_total của fiberprometheus — cái đó là hợp đồng với
	// prometheus-adapter và đi đường Prometheus scrape riêng.
	metricExp, err := otlpmetricgrpc.New(ctx, otlpmetricgrpc.WithInsecure())
	if err != nil {
		log.Warn("otlp metric exporter lỗi, chỉ bật traces", "err", err)
	} else {
		mp := sdkmetric.NewMeterProvider(
			sdkmetric.WithResource(res),
			sdkmetric.WithReader(sdkmetric.NewPeriodicReader(metricExp,
				sdkmetric.WithInterval(30*time.Second))),
		)
		otel.SetMeterProvider(mp)
		shutdowns = append(shutdowns, mp.Shutdown)

		if err := runtime.Start(runtime.WithMinimumReadMemStatsInterval(15 * time.Second)); err != nil {
			log.Warn("runtime metrics không bật được", "err", err)
		}
	}

	log.Info("OpenTelemetry bật",
		"endpoint", os.Getenv("OTEL_EXPORTER_OTLP_ENDPOINT"),
		"service", os.Getenv("OTEL_SERVICE_NAME"),
		"sampler", samplerFromEnv())

	return func(c context.Context) error {
		var errs []error
		for _, fn := range shutdowns {
			if err := fn(c); err != nil {
				errs = append(errs, err)
			}
		}
		return errors.Join(errs...)
	}, nil
}
```

- [ ] **Step 5: Chạy test — phải PASS**

```bash
go test ./telemetry/ -v -race
```
Expected: PASS cả 3 test.

- [ ] **Step 6: Wire vào `main.go`**

Trong `run()`, chèn **ngay sau** khối `cfg, err := config.Load()` và **trước** `db.NewPool` (DB tracer ở Task 3 cần TracerProvider đã đăng ký):

```go
	// Telemetry dựng TRƯỚC pool: otelpgx lấy TracerProvider global lúc khởi
	// tạo pool. Đảo thứ tự thì DB span rơi vào no-op provider và biến mất.
	otelShutdown, err := telemetry.Setup(ctx, log)
	if err != nil {
		return fmt.Errorf("telemetry: %w", err)
	}
```

Thêm import `"github.com/anmates/api/telemetry"`.

Trong goroutine graceful shutdown, thêm flush **trước** `app.ShutdownWithContext`:

```go
		log.Info("shutdown signal received")
		hub.CloseAll()
		shutCtx, shutCancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer shutCancel()
		if err := app.ShutdownWithContext(shutCtx); err != nil {
			log.Error("shutdown", "err", err)
		}
		// Flush span còn trong buffer SAU khi server ngừng nhận request mới.
		// Không flush = mất mọi span của vài giây cuối, đúng những span mô tả
		// sự cố khiến pod bị giết.
		if err := otelShutdown(shutCtx); err != nil {
			log.Error("otel shutdown", "err", err)
		}
		cancel()
```

- [ ] **Step 7: Build + test toàn bộ**

```bash
go build ./... && go vet ./... && go test ./... -race
```
Expected: tất cả PASS.

- [ ] **Step 8: Commit**

```bash
git add anmates-api/telemetry/ anmates-api/main.go anmates-api/go.mod anmates-api/go.sum
git commit -m "feat(api): OpenTelemetry SDK bootstrap

Cấu hình hoàn toàn qua OTEL_* env, không hardcode endpoint. Endpoint rỗng =
telemetry tắt, app chạy bình thường — observability không phải hard dependency.
Head sampling để always_on vì tail sampling nằm ở collector gateway.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 2: HTTP server span + X-Trace-Id

**Files:**
- Create: `anmates-api/middleware/tracing.go`
- Create: `anmates-api/middleware/tracing_test.go`
- Modify: `anmates-api/main.go` (thêm `middleware.Tracing(app)` sau `middleware.Metrics`)

**Interfaces:**
- Consumes: TracerProvider global (Task 1)
- Produces:
  - `func Tracing(app *fiber.App)` — gắn otelfiber + response header
  - Response header `X-Trace-Id` trên mọi response — client đọc được để báo lỗi kèm trace id (đường thay thế rẻ cho Flutter RUM, vốn ngoài scope)
  - Server span có `c.UserContext()` mang span context — Task 3 phụ thuộc điều này

- [ ] **Step 1: Viết test TRƯỚC**

Tạo `middleware/tracing_test.go`:

```go
package middleware

import (
	"context"
	"io"
	"net/http/httptest"
	"testing"

	"github.com/gofiber/fiber/v2"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/propagation"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
	"go.opentelemetry.io/otel/trace"
)

func newTestApp(t *testing.T) (*fiber.App, *tracetest.SpanRecorder) {
	t.Helper()
	sr := tracetest.NewSpanRecorder()
	tp := sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(sr))
	otel.SetTracerProvider(tp)
	otel.SetTextMapPropagator(propagation.TraceContext{})

	app := fiber.New()
	Tracing(app)
	return app, sr
}

// Request thường phải sinh ra đúng một server span.
func TestTracingCreatesServerSpan(t *testing.T) {
	app, sr := newTestApp(t)
	app.Get("/api/v1/venues", func(c *fiber.Ctx) error { return c.SendString("ok") })

	resp, err := app.Test(httptest.NewRequest("GET", "/api/v1/venues", nil))
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()

	spans := sr.Ended()
	if len(spans) != 1 {
		t.Fatalf("muốn 1 span, có %d", len(spans))
	}
	if spans[0].SpanKind() != trace.SpanKindServer {
		t.Fatalf("span kind = %v, muốn Server", spans[0].SpanKind())
	}
}

// 🔴 Test quan trọng nhất của task này.
// otelfiber gắn span context vào c.UserContext(), KHÔNG phải c.Context().
// Handler gọi DB bằng context.Background() sẽ tạo orphan root span thay vì
// span con — waterfall nhìn thì có nhưng rỗng, và việc soi N+1 query trở nên
// vô dụng. Test này khoá đúng bất biến đó.
func TestUserContextCarriesSpan(t *testing.T) {
	app, _ := newTestApp(t)

	var got context.Context
	app.Get("/probe", func(c *fiber.Ctx) error {
		got = c.UserContext()
		return c.SendString("ok")
	})

	resp, err := app.Test(httptest.NewRequest("GET", "/probe", nil))
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()

	sc := trace.SpanContextFromContext(got)
	if !sc.IsValid() {
		t.Fatal("c.UserContext() không mang span context — handler gọi DB sẽ tạo orphan span")
	}
}

// /health và /metrics bị kubelet probe + Prometheus scrape liên tục. Trace
// chúng là ngập Tempo bằng lưu lượng máy móc.
func TestTracingSkipsProbePaths(t *testing.T) {
	app, sr := newTestApp(t)
	app.Get("/health", func(c *fiber.Ctx) error { return c.SendString("ok") })
	app.Get(MetricsPath, func(c *fiber.Ctx) error { return c.SendString("ok") })

	for _, p := range []string{"/health", MetricsPath} {
		resp, err := app.Test(httptest.NewRequest("GET", p, nil))
		if err != nil {
			t.Fatal(err)
		}
		_, _ = io.Copy(io.Discard, resp.Body)
		resp.Body.Close()
	}

	if n := len(sr.Ended()); n != 0 {
		t.Fatalf("muốn 0 span cho probe path, có %d", n)
	}
}

// X-Trace-Id là đường rẻ để client báo lỗi kèm trace id mà không cần SDK
// phía client (Flutter RUM ngoài scope — xem ADR §7).
func TestTraceIDResponseHeader(t *testing.T) {
	app, _ := newTestApp(t)
	app.Get("/api/v1/venues", func(c *fiber.Ctx) error { return c.SendString("ok") })

	resp, err := app.Test(httptest.NewRequest("GET", "/api/v1/venues", nil))
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()

	if id := resp.Header.Get("X-Trace-Id"); len(id) != 32 {
		t.Fatalf("X-Trace-Id = %q, muốn 32 ký tự hex", id)
	}
}

// traceparent gửi vào phải được nối tiếp, không tạo trace mới.
func TestTraceparentIsContinued(t *testing.T) {
	app, sr := newTestApp(t)
	app.Get("/api/v1/venues", func(c *fiber.Ctx) error { return c.SendString("ok") })

	req := httptest.NewRequest("GET", "/api/v1/venues", nil)
	req.Header.Set("traceparent", "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01")

	resp, err := app.Test(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()

	spans := sr.Ended()
	if len(spans) != 1 {
		t.Fatalf("muốn 1 span, có %d", len(spans))
	}
	if got := spans[0].SpanContext().TraceID().String(); got != "4bf92f3577b34da6a3ce929d0e0e4736" {
		t.Fatalf("trace id = %s — traceparent không được nối tiếp", got)
	}
}
```

- [ ] **Step 2: Chạy test để xác nhận FAIL**

```bash
go test ./middleware/ -run "TestTracing|TestUserContext|TestTraceID|TestTraceparent" -v
```
Expected: FAIL — `undefined: Tracing`.

- [ ] **Step 3: Viết `middleware/tracing.go`**

```go
package middleware

import (
	"github.com/gofiber/contrib/otelfiber/v2"
	"github.com/gofiber/fiber/v2"
	"go.opentelemetry.io/otel/trace"
)

// tracingSkipPaths — cùng danh sách với metricsSkipPaths và cùng lý do:
// /health bị kubelet probe 10s/lần, /metrics bị Prometheus scrape 30s/lần.
// Cả hai là lưu lượng máy móc, không phải người dùng. Trace chúng là bơm vào
// Tempo một sàn span cố định che lấp trace thật.
func tracingSkipPath(path string) bool {
	for _, p := range metricsSkipPaths {
		if path == p {
			return true
		}
	}
	// WebSocket: một connection sống hàng giờ sẽ thành MỘT span khổng lồ và
	// làm hỏng mọi phép đo p95. Message-level tracing là việc riêng, chưa làm.
	return len(path) >= 4 && path[:4] == "/ws/"
}

// Tracing gắn OpenTelemetry HTTP server span vào app.
//
// otelfiber tự đọc traceparent vào (W3C TraceContext) và đặt span context vào
// c.UserContext(). MỌI handler gọi DB hay HTTP client PHẢI truyền
// c.UserContext() xuống — dùng context.Background() hay c.Context() sẽ tạo
// orphan root span: waterfall trông có span nhưng không lồng vào nhau, và
// việc soi N+1 query trở nên vô nghĩa. middleware/tracing_test.go khoá điều này.
//
// Fiber chạy trên fasthttp chứ không phải net/http, nên otelhttp KHÔNG dùng
// được — phải là otelfiber.
func Tracing(app *fiber.App) {
	app.Use(otelfiber.Middleware(
		otelfiber.WithNext(func(c *fiber.Ctx) bool {
			return tracingSkipPath(c.Path())
		}),
		// Span name theo ROUTE PATTERN (/api/v1/venues/:id), không phải URL thô.
		// URL thô nghĩa là mỗi venue id sinh một series
		// traces_spanmetrics_calls_total mới — cardinality nổ ngay.
		otelfiber.WithSpanNameFormatter(func(c *fiber.Ctx) string {
			if r := c.Route(); r != nil && r.Path != "" {
				return c.Method() + " " + r.Path
			}
			return c.Method()
		}),
	))

	// X-Trace-Id trên mọi response. Client (Flutter) đọc header này và đính
	// vào báo lỗi — cho được 80% giá trị của RUM với ~0 công sức, trong khi
	// Dart chưa có OTel SDK chính thức (xem ADR §7).
	app.Use(func(c *fiber.Ctx) error {
		if sc := trace.SpanContextFromContext(c.UserContext()); sc.IsValid() {
			c.Set("X-Trace-Id", sc.TraceID().String())
		}
		return c.Next()
	})
}
```

- [ ] **Step 4: Chạy test — phải PASS**

```bash
go test ./middleware/ -v -race
```
Expected: PASS, kể cả các test cũ trong `metrics_test.go` và `auth_test.go`.

- [ ] **Step 5: Wire vào `main.go`**

Ngay **sau** dòng `middleware.Metrics(app, "anmates-api")`:

```go
	// Sau Metrics, trước cors/logger: server span bao trọn thời gian xử lý,
	// và RequestLogger ở dưới đọc được trace_id từ c.UserContext().
	middleware.Tracing(app)
```

- [ ] **Step 6: Verify CORS cho phép client đọc X-Trace-Id**

Header custom không nằm trong CORS-safelist — browser không đọc được nếu thiếu `Access-Control-Expose-Headers`. Sửa khối `cors.New` trong `main.go`:

```go
	app.Use(cors.New(cors.Config{
		AllowOrigins: cfg.CORSOrigins,
		AllowMethods: "GET,POST,PUT,PATCH,DELETE,OPTIONS",
		AllowHeaders: "Content-Type,Authorization,traceparent,tracestate",
		// Không có dòng này thì browser NHẬN được header nhưng JS không đọc
		// được — X-Trace-Id vô dụng phía client.
		ExposeHeaders: "X-Trace-Id",
	}))
```

`traceparent` thêm vào `AllowHeaders` để client về sau gửi được (khi có Dart SDK).

- [ ] **Step 7: Build + test**

```bash
go build ./... && go vet ./... && go test ./... -race
```

- [ ] **Step 8: Commit**

```bash
git add anmates-api/middleware/tracing.go anmates-api/middleware/tracing_test.go anmates-api/main.go
git commit -m "feat(api): HTTP server span (otelfiber) + X-Trace-Id header

Span name dùng route pattern, không URL thô — URL thô làm nổ cardinality
spanmetrics. /health, /metrics, /ws/ bị loại khỏi trace.
X-Trace-Id + ExposeHeaders cho client báo lỗi kèm trace id.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 3: DB span (otelpgx) + kiểm chứng parent-child

**Files:**
- Modify: `anmates-api/db/db.go`
- Create: `anmates-api/db/db_test.go`

**Interfaces:**
- Consumes: TracerProvider global (Task 1), `c.UserContext()` (Task 2)
- Produces: `db.NewPool` gắn `otelpgx` QueryTracer — mọi query sinh client span `db.system=postgresql`

- [ ] **Step 1: Viết test TRƯỚC**

Tạo `db/db_test.go`:

```go
package db

import (
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
)

// NewPool phải gắn QueryTracer. Không có nó thì không span DB nào được sinh ra
// và waterfall dừng ở tầng HTTP — mất đúng thứ tracing hữu ích nhất cho backend.
//
// Không cần Postgres thật: chỉ kiểm tra config được dựng đúng.
func TestPoolConfigHasQueryTracer(t *testing.T) {
	cfg, err := pgxpool.ParseConfig("postgres://u:p@127.0.0.1:5432/db?sslmode=disable")
	if err != nil {
		t.Fatal(err)
	}
	applyTracing(cfg)

	if cfg.ConnConfig.Tracer == nil {
		t.Fatal("ConnConfig.Tracer nil — otelpgx chưa được gắn, sẽ không có DB span nào")
	}
}
```

- [ ] **Step 2: Chạy test để xác nhận FAIL**

```bash
go test ./db/ -run TestPoolConfig -v
```
Expected: FAIL — `undefined: applyTracing`.

- [ ] **Step 3: Sửa `db/db.go`**

Thêm import và hàm `applyTracing`, rồi gọi nó trong `NewPool`:

```go
package db

import (
	"context"
	"fmt"
	"time"

	"github.com/exaring/otelpgx"
	"github.com/jackc/pgx/v5/pgxpool"
)

// applyTracing gắn OpenTelemetry QueryTracer vào pool config.
//
// Mỗi query thành một client span với db.system, db.statement và tên bảng —
// và vì span được tạo từ context truyền vào, nó là CON của HTTP server span
// miễn là handler truyền c.UserContext() xuống. Truyền context.Background()
// là span rơi ra ngoài trace (xem middleware/tracing_test.go).
//
// WithTrimSQLInSpanName: tên span là "SELECT restaurants" thay vì cả câu SQL.
// Không trim thì mỗi biến thể câu query thành một span name khác nhau, và
// spanmetrics sinh một series cho từng cái.
func applyTracing(cfg *pgxpool.Config) {
	cfg.ConnConfig.Tracer = otelpgx.NewTracer(
		otelpgx.WithTrimSQLInSpanName(),
	)
}

func NewPool(ctx context.Context, url string, maxConns, minConns int32) (*pgxpool.Pool, error) {
	cfg, err := pgxpool.ParseConfig(url)
	if err != nil {
		return nil, fmt.Errorf("parse db url: %w", err)
	}
	cfg.MaxConns = maxConns
	cfg.MinConns = minConns
	cfg.MaxConnLifetime = time.Hour
	cfg.MaxConnIdleTime = 30 * time.Minute
	cfg.HealthCheckPeriod = time.Minute

	applyTracing(cfg)

	pool, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		return nil, fmt.Errorf("new pool: %w", err)
	}
	pingCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	if err := pool.Ping(pingCtx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("ping db: %w", err)
	}
	return pool, nil
}
```

> ⚠️ `otelpgx.WithIncludeQueryParameters()` **KHÔNG bật**: query parameter chứa email, số điện thoại, JWT — đưa vào span attribute là đẩy PII vào Tempo.

- [ ] **Step 4: Chạy test — phải PASS**

```bash
go test ./db/ -v -race
```

- [ ] **Step 5: Audit — handler nào đang KHÔNG truyền UserContext**

Đây là bước bắt lỗi thật, không phải formality:

```bash
cd /Users/thanhit/AnMatesStudio/AnMates/anmates-api
echo "=== handler dùng c.Context() thay vì c.UserContext() ==="
grep -rn "c\.Context()" handlers/ services/ || echo "(không có — tốt)"
echo "=== context.Background() trong handler/service ==="
grep -rn "context\.Background()" handlers/ services/ || echo "(không có — tốt)"
```

Mọi kết quả tìm được ở đường phục vụ request đều phải sửa thành `c.UserContext()`. Ngoại lệ hợp lệ: goroutine nền sống lâu hơn request (ví dụ concierge prefetch) — chỗ đó dùng `context.WithoutCancel(c.UserContext())` để giữ trace link mà không bị huỷ theo request:

```go
	bg := context.WithoutCancel(c.UserContext())
	go func() { conciergeSvc.Prefetch(bg, matchID) }()
```

- [ ] **Step 6: Build + test toàn bộ**

```bash
go build ./... && go vet ./... && go test ./... -race
```

- [ ] **Step 7: Commit**

```bash
git add anmates-api/db/db.go anmates-api/db/db_test.go anmates-api/handlers anmates-api/services
git commit -m "feat(api): DB span qua otelpgx + sửa context propagation

QueryTracer gắn vào pgxpool config. WithTrimSQLInSpanName để span name là
'SELECT restaurants' thay vì cả câu SQL (mỗi biến thể = một series spanmetrics).
Query parameter KHÔNG đưa vào attribute: chứa email/phone/JWT.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 4: Log correlation — trace_id trong mỗi dòng log

**Files:**
- Modify: `anmates-api/middleware/logger.go`
- Modify: `anmates-api/middleware/tracing_test.go` (thêm test)

**Interfaces:**
- Consumes: span context từ `c.UserContext()` (Task 2)
- Produces: mỗi dòng log của request có `trace_id` và `span_id` — Loki `derivedFields` matcher `regex` bắt được (xem plan infra Task 6)

- [ ] **Step 1: Thêm test vào `middleware/tracing_test.go`**

```go
// Log phải mang trace_id thì log -> trace jump mới chạy. Loki derivedFields
// có matcher regex '(?:trace_id|traceID|traceId)[=:"\s]+([a-f0-9]{32})' —
// định dạng slog JSON ("trace_id":"<32 hex>") khớp matcher đó.
func TestRequestLoggerIncludesTraceID(t *testing.T) {
	sr := tracetest.NewSpanRecorder()
	otel.SetTracerProvider(sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(sr)))
	otel.SetTextMapPropagator(propagation.TraceContext{})

	var buf bytes.Buffer
	log := slog.New(slog.NewJSONHandler(&buf, nil))

	app := fiber.New()
	Tracing(app)
	app.Use(RequestLogger(log))
	app.Get("/api/v1/venues", func(c *fiber.Ctx) error { return c.SendString("ok") })

	resp, err := app.Test(httptest.NewRequest("GET", "/api/v1/venues", nil))
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()

	out := buf.String()
	if !strings.Contains(out, `"trace_id":"`) {
		t.Fatalf("log không có trace_id — log->trace jump sẽ không chạy.\nlog: %s", out)
	}
	m := regexp.MustCompile(`"trace_id":"([a-f0-9]{32})"`).FindStringSubmatch(out)
	if m == nil {
		t.Fatalf("trace_id không phải 32 ký tự hex, Loki derivedFields sẽ không khớp.\nlog: %s", out)
	}
}
```

Thêm import: `"bytes"`, `"log/slog"`, `"regexp"`, `"strings"`.

- [ ] **Step 2: Chạy test để xác nhận FAIL**

```bash
go test ./middleware/ -run TestRequestLoggerIncludesTraceID -v
```
Expected: FAIL — log không chứa `"trace_id":"`.

- [ ] **Step 3: Sửa `middleware/logger.go`**

Thêm import:

```go
	"go.opentelemetry.io/otel/trace"
```

Trong `RequestLogger`, sau khi dựng `attrs`, thêm:

```go
		// trace_id/span_id vào MỖI dòng log. Đây là thứ làm trace -> log và
		// log -> trace jump chạy được:
		//   - log đi qua OTLP: trace_id thành structured metadata của Loki,
		//     khớp derivedFields matcher `label`
		//   - log scrape từ /var/log/pods: trace_id nằm trong text JSON,
		//     khớp derivedFields matcher `regex`
		// Cả hai matcher đều được cấu hình ở chart observability (Task 6).
		if sc := trace.SpanContextFromContext(c.UserContext()); sc.IsValid() {
			attrs = append(attrs,
				slog.String("trace_id", sc.TraceID().String()),
				slog.String("span_id", sc.SpanID().String()),
			)
		}
```

Đặt khối này **trước** `switch` chọn level, sau khối `if err != nil`.

- [ ] **Step 4: Chạy test — phải PASS**

```bash
go test ./middleware/ -v -race
```

- [ ] **Step 5: Build + test toàn bộ**

```bash
go build ./... && go vet ./... && go test ./... -race
```

- [ ] **Step 6: Commit**

```bash
git add anmates-api/middleware/logger.go anmates-api/middleware/tracing_test.go
git commit -m "feat(api): trace_id/span_id trong mỗi dòng log

Định dạng slog JSON khớp cả hai matcher derivedFields của Loki (label cho log
qua OTLP, regex cho log scrape từ /var/log/pods).

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 5: Helm — OTEL_* env cho pod

**Files:**
- Modify: `deploy/charts/anmates/values.yaml`
- Modify: `deploy/charts/anmates/values-prod.yaml`
- Modify: `deploy/charts/anmates/templates/api-deployment.yaml`

- [ ] **Step 1: Thêm block `otel:` vào `values.yaml`**

Trong `api:`, ngay sau block `env:`:

```yaml
  # OpenTelemetry. Cấu hình HOÀN TOÀN qua env — không file Go nào chứa endpoint.
  # TẮT mặc định: endpoint rỗng = telemetry.Setup() trả no-op, app chạy bình
  # thường. Bật sau khi chart observability (anmates-infra) đã có Alloy Service.
  otel:
    enabled: false
    # Trỏ vào ALLOY (agent tier), KHÔNG phải gateway. Service Alloy đặt
    # internalTrafficPolicy: Local nên telemetry ở lại node của pod gửi VÀ
    # giữ nguyên source IP để k8sattributes nhận diện đúng pod.
    endpoint: http://observability-alloy.monitoring.svc.cluster.local:4317
    protocol: grpc
    serviceName: anmates-api
    serviceNamespace: anmates
    environment: onprem
    # parentbased_always_on, KHÔNG phải traceidratio: tail sampling nằm ở
    # collector gateway (baseline 20% + giữ toàn bộ error/slow). SDK head-sample
    # trước nghĩa là gateway chỉ thấy phần còn sót và error bị vứt ngẫu nhiên.
    sampler: parentbased_always_on
```

- [ ] **Step 2: Thêm env vào `templates/api-deployment.yaml`**

Trong `env:` của container `api`, sau `DEV_MODE`:

```yaml
            {{- if .Values.api.otel.enabled }}
            - name: OTEL_EXPORTER_OTLP_ENDPOINT
              value: {{ .Values.api.otel.endpoint | quote }}
            - name: OTEL_EXPORTER_OTLP_PROTOCOL
              value: {{ .Values.api.otel.protocol | quote }}
            - name: OTEL_SERVICE_NAME
              value: {{ .Values.api.otel.serviceName | quote }}
            - name: OTEL_TRACES_SAMPLER
              value: {{ .Values.api.otel.sampler | quote }}
            # Downward API: k8sattributes của Alloy có HAI pod_association rule.
            # Rule đọc resource attribute chạy trước và bền hơn rule theo
            # source IP — IP bị rewrite ở đâu đó là rule kia hỏng im lặng.
            - name: K8S_POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: K8S_NAMESPACE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            - name: K8S_NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
            - name: OTEL_RESOURCE_ATTRIBUTES
              value: >-
                service.namespace={{ .Values.api.otel.serviceNamespace }},
                service.version={{ .Values.image.api.tag }},
                deployment.environment={{ .Values.api.otel.environment }},
                k8s.pod.name=$(K8S_POD_NAME),
                k8s.namespace.name=$(K8S_NAMESPACE_NAME),
                k8s.node.name=$(K8S_NODE_NAME)
            {{- end }}
```

> ⚠️ `$(K8S_POD_NAME)` là cú pháp **Kubernetes** expand env, không phải shell. Nó chỉ hoạt động khi biến được tham chiếu đã khai báo **TRƯỚC** trong cùng danh sách `env` — thứ tự ở trên đúng, đừng đảo.

- [ ] **Step 3: Bật ở `values-prod.yaml`**

```yaml
  # Bật sau khi anmates-infra chart observability >= 0.5.0 đã deploy và
  # `kubectl -n monitoring get svc observability-alloy` trả về kết quả.
  otel:
    enabled: true
```

- [ ] **Step 4: Verify render**

```bash
cd /Users/thanhit/AnMatesStudio/AnMates
helm template anmates ./deploy/charts/anmates -f deploy/charts/anmates/values-prod.yaml \
  | python3 -c "
import sys, yaml
for d in yaml.safe_load_all(sys.stdin):
    if not d or d.get('kind')!='Deployment': continue
    for c in d['spec']['template']['spec']['containers']:
        if c['name']!='api': continue
        env={e['name']: e for e in c['env']}
        names=[e['name'] for e in c['env']]
        for k in ('OTEL_EXPORTER_OTLP_ENDPOINT','OTEL_SERVICE_NAME','OTEL_RESOURCE_ATTRIBUTES','OTEL_TRACES_SAMPLER'):
            assert k in env, f'thiếu {k}'
        assert env['OTEL_TRACES_SAMPLER']['value']=='parentbased_always_on'
        # Thứ tự: K8S_POD_NAME phải đứng TRƯỚC OTEL_RESOURCE_ATTRIBUTES
        assert names.index('K8S_POD_NAME') < names.index('OTEL_RESOURCE_ATTRIBUTES'), \
            'K8S_POD_NAME phải khai báo trước OTEL_RESOURCE_ATTRIBUTES thì \$() mới expand'
        print('OK — OTEL env đầy đủ và đúng thứ tự')
"
```
Expected: `OK — OTEL env đầy đủ và đúng thứ tự`

- [ ] **Step 5: Verify ServiceMonitor và HPA KHÔNG bị đụng**

```bash
helm template anmates ./deploy/charts/anmates -f deploy/charts/anmates/values-prod.yaml \
  | grep -A4 "kind: ServiceMonitor" | grep -E "path:|interval:"
helm template anmates ./deploy/charts/anmates -f deploy/charts/anmates/values-prod.yaml \
  | grep -A3 "http_requests_per_second"
```
Expected: `path: /metrics`, `interval: 30s`, và HPA vẫn tham chiếu `http_requests_per_second`. Hợp đồng HPA nguyên vẹn.

- [ ] **Step 6: Commit**

```bash
git add deploy/charts/anmates/values.yaml deploy/charts/anmates/values-prod.yaml \
        deploy/charts/anmates/templates/api-deployment.yaml
git commit -m "feat(chart): OTEL_* env cho anmates-api

Trỏ vào Alloy (agent), không phải gateway. Downward API cung cấp k8s.pod.name
cho pod_association rule của k8sattributes. Sampler always_on vì tail sampling
ở gateway.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 6: Verify E2E — pipeline thật, cluster thật

Task này **không sửa code**. Nó chứng minh dữ liệu chảy hết từ request tới Grafana. Chạy sau khi cả plan infra và Task 1–5 đã deploy.

**Prerequisites:**
```bash
kubectl -n monitoring get pods           # tất cả Running
kubectl -n monitoring get svc observability-alloy observability-otel-gateway observability-mimir
kubectl -n anmates rollout status deploy/anmates-api
kubectl -n anmates logs deploy/anmates-api | grep "OpenTelemetry bật"
```
Dòng cuối phải in ra endpoint + sampler. Không thấy nó = `api.otel.enabled` chưa bật.

- [ ] **Step 1: Sinh traffic có thể nhận diện**

```bash
kubectl -n anmates port-forward svc/anmates-api 8080:8080 &
sleep 2
for i in $(seq 1 30); do
  curl -s -o /dev/null -D- localhost:8080/api/v1/venues | grep -i x-trace-id
  sleep 0.2
done
```
Expected: mỗi request in ra một `X-Trace-Id` 32 hex khác nhau. **Lưu lại một cái** làm `TRACE_ID` cho các bước sau.

Không có header → Task 2 chưa deploy, hoặc telemetry tắt.

- [ ] **Step 2: Alloy có nhận span không**

```bash
kubectl -n monitoring port-forward svc/observability-alloy 12345:12345 &
sleep 2
curl -s localhost:12345/metrics | grep -E 'otelcol_receiver_accepted_spans|otelcol_exporter_send_failed'
```
Expected: `otelcol_receiver_accepted_spans_total` > 0 và đang tăng; `send_failed` = 0.

`accepted_spans` = 0 → app không gửi được. Kiểm tra `OTEL_EXPORTER_OTLP_ENDPOINT` resolve được từ trong pod:
```bash
kubectl -n anmates exec deploy/anmates-api -- getent hosts observability-alloy.monitoring.svc.cluster.local
```

- [ ] **Step 3: Gateway có export sang cả ba backend không**

```bash
kubectl -n monitoring port-forward deploy/observability-otel-gateway 8888:8888 &
sleep 2
curl -s localhost:8888/metrics | grep -E 'otelcol_exporter_sent_(spans|metric_points|log_records)_total'
curl -s localhost:8888/metrics | grep 'otelcol_exporter_send_failed'
```
Expected: cả ba `sent_*` > 0, mọi `send_failed` = 0.

`send_failed` > 0 → đọc log gateway, gần như luôn là sai tên Service backend:
```bash
kubectl -n monitoring logs deploy/observability-otel-gateway --tail=50
```

- [ ] **Step 4: Trace có trong Tempo và ĐÚNG hình dạng**

```bash
kubectl -n monitoring port-forward svc/observability-tempo 3200:3200 &
sleep 2
TRACE_ID=<dán từ Step 1>
curl -s "localhost:3200/api/traces/${TRACE_ID}" | python3 -c "
import sys, json
d=json.load(sys.stdin)
spans=[s for b in d['batches'] for ss in b['scopeSpans'] for s in ss['spans']]
print(f'Tổng span: {len(spans)}')
by_id={s['spanId']: s for s in spans}
roots=[s for s in spans if not s.get('parentSpanId')]
print(f'Root span: {len(roots)} — {[s[\"name\"] for s in roots]}')
assert len(roots)==1, 'PHẢI có đúng 1 root span. >1 nghĩa là DB span mồ côi — handler dùng context.Background() thay vì c.UserContext()'
kinds={}
for s in spans: kinds[s.get('kind')]=kinds.get(s.get('kind'),0)+1
print('Span kind:', kinds)  # 2=SERVER, 3=CLIENT
assert any(s.get('kind')==3 for s in spans), 'Không có CLIENT span — otelpgx chưa hoạt động'
for s in spans:
    if s.get('kind')==3:
        assert s.get('parentSpanId'), f'DB span {s[\"name\"]} không có parent — orphan!'
print('OK — 1 root, DB span là con của HTTP span')
"
```
Expected: `OK — 1 root, DB span là con của HTTP span`

🔴 Đây là test bắt lỗi `c.UserContext()`. Fail ở đây = quay lại Task 3 Step 5.

- [ ] **Step 5: spanmetrics có trong Mimir không**

```bash
kubectl -n monitoring port-forward svc/observability-mimir 9009:9009 &
sleep 2
curl -sG 'localhost:9009/prometheus/api/v1/query' \
  --data-urlencode 'query=sum by (service_name, span_name) (traces_spanmetrics_calls_total)' \
  | python3 -m json.tool
```
Expected: có series với `service_name="anmates-api"` và `span_name="GET /api/v1/venues"`.

`span_name` chứa UUID thô → `WithSpanNameFormatter` ở Task 2 không hoạt động → cardinality sắp nổ, sửa ngay.

- [ ] **Step 6: 🔴 Verify dimension của spanmetrics KHÔNG rỗng**

Đây là bẫy tích hợp thật: gateway khai `spanMetrics.dimensions` là `http.request.method` / `http.response.status_code` (semconv mới). Nếu `otelfiber` phát ra tên cũ (`http.method`, `http.status_code`) thì dimension **rỗng hoàn toàn** mà không có lỗi nào.

```bash
curl -sG 'localhost:9009/prometheus/api/v1/query' \
  --data-urlencode 'query=traces_spanmetrics_calls_total{service_name="anmates-api"}' \
  | python3 -c "
import sys, json
r=json.load(sys.stdin)['data']['result']
assert r, 'không có series nào'
labels=r[0]['metric']
print('Labels:', json.dumps(labels, indent=2))
missing=[k for k in ('http_request_method','http_response_status_code') if k not in labels]
if missing:
    print()
    print('⚠️  DIMENSION RỖNG:', missing)
    print('   otelfiber đang phát semconv CŨ (http.method / http.status_code).')
    print('   SỬA: đổi gateway.spanMetrics dimensions trong charts/observability/values.yaml')
    print('   sang tên cũ, HOẶC nâng otelfiber lên bản dùng semconv >= 1.21.')
    sys.exit(1)
print('OK — dimension đầy đủ, semconv khớp giữa SDK và gateway')
"
```
Expected: `OK — dimension đầy đủ, semconv khớp giữa SDK và gateway`

Nếu fail: sửa `charts/observability/templates/gateway-configmap.yaml`, khối `spanmetrics.dimensions`, cho khớp tên mà SDK thực sự phát ra. **Đừng đoán — đọc label thật mà lệnh trên in ra.**

- [ ] **Step 7: servicegraph có sinh không**

```bash
curl -sG 'localhost:9009/prometheus/api/v1/query' \
  --data-urlencode 'query=traces_service_graph_request_total' | python3 -m json.tool | head -30
```
Expected: có series `client`/`server`. Rỗng là bình thường nếu `anmates-api` chưa gọi service nào khác qua HTTP — service graph cần ít nhất một cặp caller/callee.

- [ ] **Step 8: Log vào Loki kèm trace_id**

```bash
kubectl -n monitoring port-forward svc/observability-loki-gateway 3100:80 &
sleep 2
curl -sG 'localhost:3100/loki/api/v1/query_range' \
  --data-urlencode '{service_name="anmates-api"} | json | trace_id != ""' \
  --data-urlencode 'limit=5' | python3 -c "
import sys, json
d=json.load(sys.stdin)
res=d['data']['result']
assert res, 'Loki không trả dòng log nào — kiểm tra otelcol.processor.transform pod_logs còn trong pipeline không'
print('Streams:', len(res))
print('Ví dụ:', res[0]['values'][0][1][:200])
print('OK — log query được bằng service_name và có trace_id')
"
```
Expected: `OK — ...`

Rỗng nhưng log vẫn có trong Loki → stream label rơi vào log-record attribute thay vì resource attribute. Kiểm tra `otelcol.processor.transform "pod_logs"` (plan infra Task 4).

- [ ] **Step 9: Verify 4 correlation jump trong Grafana UI**

```bash
kubectl -n monitoring port-forward svc/observability-grafana 3000:80 &
open http://localhost:3000
```

Làm tay, ghi kết quả vào bảng:

| # | Jump | Cách làm | Pass? |
|---|---|---|---|
| 1 | **metric → trace** | Explore → Mimir → `histogram_quantile(0.95, sum(rate(traces_spanmetrics_duration_milliseconds_bucket{service_name="anmates-api"}[5m])) by (le))` → bật **Exemplars** → click diamond marker | ☐ |
| 2 | **trace → log** | Explore → Tempo → dán `TRACE_ID` → chọn span → **Logs for this span** | ☐ |
| 3 | **log → trace** | Explore → Loki → `{service_name="anmates-api"}` → mở một dòng → **View trace** | ☐ |
| 4 | **trace → metric** | Trong trace view → panel bên phải → **Request rate / Error rate / p95** | ☐ |
| 5 | **service graph** | Explore → Tempo → tab **Service Graph** | ☐ |

Jump #1 không có diamond → thiếu **một trong hai**: `exemplars.enabled` ở spanmetrics connector, hoặc `max_global_exemplars_per_user` ở Mimir. Cần **cả hai**.

- [ ] **Step 10: 🔴 Verify HPA KHÔNG bị hỏng**

Regression check quan trọng nhất — toàn bộ plan này không được đụng vào chain HPA:

```bash
kubectl get apiservice v1beta1.custom.metrics.k8s.io
kubectl get --raw "/apis/custom.metrics.k8s.io/v1beta1/namespaces/anmates/pods/*/http_requests_per_second" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('\n'.join(f\"{i['describedObject']['name']}\t{i['value']}\" for i in d['items']))"
kubectl -n anmates get hpa anmates-api
```
Expected: APIService `AVAILABLE: True`, mỗi pod ra một số (0 là hợp lệ khi không có tải), HPA `TARGETS` hiện số chứ **không phải `<unknown>`**.

`<unknown>` → chain đứt. Đối chiếu `anmates-infra/charts/observability/README.md §4`.

- [ ] **Step 11: Verify Data-Bridge writer cũng vào chung pipeline**

`AnMates-Data-Bridge` đã emit OTLP từ ngày 1 và `deploy/otel-collector.yaml` có sẵn nhánh Tempo đang comment.

```bash
# Trong AnMates-Data-Bridge/deploy/otel-collector.yaml, bỏ comment và sửa
# namespace: platform ghi `observability`, cụm này dùng `monitoring`.
#   otlp/tempo:
#     endpoint: observability-alloy.monitoring.svc.cluster.local:4317
#     tls: { insecure: true }
# rồi đổi pipeline traces/logs exporters từ [debug] sang exporter thật.
docker compose -f AnMates-Data-Bridge/docker-compose.yml restart otel-collector

curl -sG 'localhost:3200/api/search' \
  --data-urlencode 'tags=service.name=anmates-data-bridge-writer' | python3 -m json.tool | head -20
```
Expected: có trace của writer. Đây là xác nhận pipeline nhận được cả workload ngoài cluster.

- [ ] **Step 12: Ghi kết quả vào runbook**

Tạo `AnMates/docs/observability-e2e-verified.md` với bảng kết quả 11 bước trên, ngày verify, và version chart/image đã dùng. Commit.

---

## Task 7: Audit OTel best practice

Đối chiếu với OpenTelemetry semantic conventions và khuyến nghị chính thức. Mỗi mục có lệnh kiểm chứng, không phải checklist niềm tin.

- [ ] **Step 1: Resource attributes bắt buộc**

```bash
TRACE_ID=<một trace id thật>
curl -s "localhost:3200/api/traces/${TRACE_ID}" | python3 -c "
import sys, json
d=json.load(sys.stdin)
attrs={}
for b in d['batches']:
    for a in b['resource']['attributes']:
        v=a['value']
        attrs[a['key']]=v.get('stringValue') or v.get('intValue') or v
required=['service.name','service.version','service.namespace','deployment.environment',
          'k8s.pod.name','k8s.namespace.name','telemetry.sdk.language']
missing=[k for k in required if k not in attrs]
print(json.dumps(attrs, indent=2, default=str))
assert not missing, f'THIẾU resource attribute: {missing}'
assert attrs['telemetry.sdk.language']=='go'
print('OK — resource attributes đầy đủ theo semconv')
"
```
Expected: `OK`. Thiếu `k8s.*` → downward API ở Task 5 chưa đúng, hoặc `k8sattributes` của Alloy không nhận diện được pod.

- [ ] **Step 2: Span naming — low cardinality**

```bash
curl -sG 'localhost:9009/prometheus/api/v1/query' \
  --data-urlencode 'query=count(count by (span_name) (traces_spanmetrics_calls_total{service_name="anmates-api"}))' \
  | python3 -c "
import sys, json
n=int(json.load(sys.stdin)['data']['result'][0]['value'][1])
print(f'Số span_name khác nhau: {n}')
assert n < 100, f'{n} span_name — quá nhiều, gần như chắc chắn có URL/UUID lọt vào tên span'
print('OK — cardinality span_name trong tầm kiểm soát')
"
```
Expected: `OK`, con số nên xấp xỉ số route trong `main.go` (~30).

- [ ] **Step 3: Không có PII trong span attribute**

```bash
curl -s "localhost:3200/api/traces/${TRACE_ID}" | python3 -c "
import sys, json, re
raw=sys.stdin.read()
patterns={
  'email': r'[\w.+-]+@[\w-]+\.[\w.]+',
  'jwt': r'eyJ[A-Za-z0-9_-]{10,}',
  'authorization header': r'(?i)\"(authorization|bearer)\"',
  'password': r'(?i)password',
}
hits={k: len(re.findall(p, raw)) for k,p in patterns.items()}
hits={k:v for k,v in hits.items() if v}
assert not hits, f'PII/secret trong span: {hits}'
print('OK — không thấy PII trong span attribute')
"
```
Expected: `OK`. Fail → kiểm tra `otelpgx.WithIncludeQueryParameters()` có bị bật nhầm không (Task 3 cố ý không bật).

- [ ] **Step 4: Error được ghi đúng chuẩn**

Span lỗi phải có `status.code = ERROR` — đó là thứ policy `keep-all-errors` của tail sampling dựa vào.

```bash
# Sinh một lỗi 5xx thật (đường ngắn nhất: gọi route cần auth mà không có token
# thì ra 401 — dùng route không tồn tại để lấy 404, hoặc tắt DB tạm để /health 503)
curl -s -o /dev/null -D- localhost:8080/api/v1/profile | grep -i x-trace-id
ERR_TRACE=<trace id vừa lấy>
curl -s "localhost:3200/api/traces/${ERR_TRACE}" | python3 -c "
import sys, json
d=json.load(sys.stdin)
spans=[s for b in d['batches'] for ss in b['scopeSpans'] for s in ss['spans']]
for s in spans:
    st=s.get('status',{})
    print(s['name'], '->', st.get('code','UNSET'))
print()
print('Ghi chú: span 4xx KHÔNG bắt buộc là ERROR theo semconv (lỗi phía client).')
print('Chỉ 5xx và exception chưa bắt mới bắt buộc status ERROR.')
"
```
Expected: in ra status của từng span. 4xx để `UNSET` là **đúng** theo semconv; 5xx phải là `ERROR`.

- [ ] **Step 5: Tail sampling giữ đúng thứ cần giữ**

```bash
curl -sG 'localhost:9009/prometheus/api/v1/query' \
  --data-urlencode 'query=sum(rate(traces_spanmetrics_calls_total{service_name="anmates-api"}[5m]))' \
  | python3 -c "import sys,json; print('spanmetrics rate (100% traffic):', json.load(sys.stdin)['data']['result'])"

curl -sG 'localhost:3200/api/search' --data-urlencode 'tags=service.name=anmates-api' \
  --data-urlencode 'limit=20' | python3 -c "import sys,json; print('trace lưu trong Tempo:', len(json.load(sys.stdin).get('traces',[])))"
```
Expected: spanmetrics rate phản ánh **toàn bộ** traffic; số trace trong Tempo thấp hơn nhiều (baseline 20%). Hai con số bằng nhau nghĩa là tail sampling chưa chạy — kiểm tra pipeline `traces/sampled`.

- [ ] **Step 6: Không head-sample ở SDK**

```bash
kubectl -n anmates exec deploy/anmates-api -- env | grep OTEL_TRACES_SAMPLER
```
Expected: `OTEL_TRACES_SAMPLER=parentbased_always_on`. Bất kỳ giá trị `traceidratio` nào ở đây là **sai**: nó vứt span trước khi gateway kịp nhìn, và error sẽ bị mất ngẫu nhiên bất chấp policy `keep-all-errors`.

- [ ] **Step 7: Cardinality tổng thể của Mimir**

```bash
curl -sG 'localhost:9009/prometheus/api/v1/query' \
  --data-urlencode 'query=count({__name__=~"traces_spanmetrics.*"})' | python3 -m json.tool
curl -sG 'localhost:9009/prometheus/api/v1/query' \
  --data-urlencode 'query=count({__name__=~".+"})' | python3 -m json.tool
```
Ghi lại hai con số này làm **baseline**. `maxGlobalSeriesPerUser: 500000` là trần cứng; vượt là Mimir từ chối ghi. Theo dõi lại sau 1 tuần — tăng đều đặn nghĩa là có label per-request lọt vào.

- [ ] **Step 8: Batch processor, không phải simple**

```bash
grep -n "WithBatcher\|WithSyncer\|NewSimpleSpanProcessor" anmates-api/telemetry/telemetry.go
```
Expected: chỉ thấy `WithBatcher`. `WithSyncer`/`SimpleSpanProcessor` export đồng bộ trên đường request và biến độ trễ collector thành độ trễ API.

- [ ] **Step 9: Graceful shutdown thực sự flush**

```bash
kubectl -n anmates delete pod -l app=anmates-api --wait=false
sleep 20
# Trace của các request ngay trước khi pod chết phải vẫn có trong Tempo
curl -sG 'localhost:3200/api/search' --data-urlencode 'tags=service.name=anmates-api' \
  --data-urlencode 'limit=5' | python3 -m json.tool | head -20
```
Expected: vẫn thấy trace mới. Đứt hẳn ở thời điểm restart nghĩa là `otelShutdown` không được gọi hoặc gọi sai thứ tự (phải **sau** `app.ShutdownWithContext`).

- [ ] **Step 10: Tổng hợp — bảng conformance**

Tạo `AnMates/docs/otel-conformance.md`:

```markdown
# OTel conformance — anmates-api

Verify ngày: <YYYY-MM-DD> · chart observability <version> · image api <tag>

| # | Best practice | Trạng thái | Bằng chứng |
|---|---|---|---|
| 1 | Cấu hình qua `OTEL_*` env, không hardcode | ☐ | `grep -rn "4317" --include=*.go` ra rỗng |
| 2 | W3C TraceContext propagator | ☐ | `TestTraceparentIsContinued` PASS |
| 3 | Resource attrs: service.name/version/namespace, deployment.environment, k8s.* | ☐ | Task 7 Step 1 |
| 4 | Span name low-cardinality (route pattern) | ☐ | Task 7 Step 2 |
| 5 | Không PII/secret trong attribute | ☐ | Task 7 Step 3 |
| 6 | Status ERROR chỉ cho 5xx/exception | ☐ | Task 7 Step 4 |
| 7 | Head sampling TẮT (tail sampling ở gateway) | ☐ | Task 7 Step 6 |
| 8 | BatchSpanProcessor | ☐ | Task 7 Step 8 |
| 9 | Shutdown flush span | ☐ | Task 7 Step 9 |
| 10 | Telemetry không chặn khởi động | ☐ | `TestSetupDoesNotBlockOnDeadCollector` PASS |
| 11 | DB span là con của HTTP span | ☐ | Task 6 Step 4 |
| 12 | spanmetrics dimension khớp semconv của SDK | ☐ | Task 6 Step 6 |
| 13 | 5 correlation jump hoạt động | ☐ | Task 6 Step 9 |
| 14 | HPA chain không bị hỏng | ☐ | Task 6 Step 10 |

## Chưa đạt / còn nợ

- **Flutter RUM** — Dart chưa có official OTel SDK (CNCF donation chưa xong).
  Hiện dùng `X-Trace-Id` response header làm đường thay thế.
- **WebSocket tracing** — connection dài bị loại khỏi trace. Message-level
  tracing chưa làm.
- **Metrics nghiệp vụ** — mới có runtime metrics. Chưa có counter/histogram cho
  match created, booking confirmed, concierge fired.
```

- [ ] **Step 11: Commit**

```bash
git add docs/otel-conformance.md docs/observability-e2e-verified.md
git commit -m "docs: E2E verification + OTel conformance audit cho anmates-api

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Self-review

**Spec coverage:**

| Yêu cầu | Task |
|---|---|
| OTel SDK cho Go | Task 1 (bootstrap), 2 (HTTP), 3 (DB), 4 (logs) |
| Cấu hình qua env | Task 1, Task 5 |
| Không chặn khởi động | Task 1 Step 2 (test), Step 4 |
| Giữ hợp đồng HPA | Global Constraints, Task 5 Step 5, Task 6 Step 10 |
| E2E verification | Task 6 (11 bước) |
| OTel best practice | Task 7 (10 mục có lệnh kiểm chứng) |
| Data-Bridge vào chung pipeline | Task 6 Step 11 |
| Flutter ngoài scope, có đường thay thế | Task 2 (X-Trace-Id), Task 7 Step 10 |

**Type consistency:** `Setup`/`Enabled`/`samplerFromEnv` định nghĩa Task 1, dùng Task 1 Step 6 (main.go). `Tracing(app)` định nghĩa Task 2, dùng main.go. `applyTracing(cfg)` định nghĩa Task 3, dùng trong `NewPool` cùng file. `metricsSkipPaths` là biến có sẵn ở `middleware/metrics.go`, dùng lại ở `tracing.go` Task 3 — cùng package `middleware` nên truy cập được, và dùng lại thay vì khai mới giữ hai danh sách không lệch nhau.

**Rủi ro đã biết, có bước xử lý:**
- semconv mismatch giữa otelfiber và gateway dimensions → Task 6 Step 6 in ra label thật và chỉ đúng chỗ sửa.
- API upstream đổi so với plan → Task 1 Step 1 in version thực tế, `go build` ở Step 7 bắt ngay.
