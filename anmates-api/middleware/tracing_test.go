package middleware

import (
	"bytes"
	"context"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"regexp"
	"strings"
	"testing"

	"github.com/gofiber/fiber/v2"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/propagation"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
	"go.opentelemetry.io/otel/trace"
)

func newTracingTestApp(t *testing.T) (*fiber.App, *tracetest.SpanRecorder) {
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
	app, sr := newTracingTestApp(t)
	app.Get("/api/v1/venues", func(c *fiber.Ctx) error { return c.SendString("ok") })

	resp, err := app.Test(httptest.NewRequestWithContext(context.Background(), http.MethodGet, "/api/v1/venues", http.NoBody))
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = resp.Body.Close() }()

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
	app, _ := newTracingTestApp(t)

	var got context.Context
	app.Get("/probe", func(c *fiber.Ctx) error {
		got = c.UserContext()
		return c.SendString("ok")
	})

	resp, err := app.Test(httptest.NewRequestWithContext(context.Background(), http.MethodGet, "/probe", http.NoBody))
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = resp.Body.Close() }()

	sc := trace.SpanContextFromContext(got)
	if !sc.IsValid() {
		t.Fatal("c.UserContext() không mang span context — handler gọi DB sẽ tạo orphan span")
	}
}

// /health và /metrics bị kubelet probe + Prometheus scrape liên tục. Trace
// chúng là ngập Tempo bằng lưu lượng máy móc.
func TestTracingSkipsProbePaths(t *testing.T) {
	app, sr := newTracingTestApp(t)
	app.Get("/health", func(c *fiber.Ctx) error { return c.SendString("ok") })
	app.Get(MetricsPath, func(c *fiber.Ctx) error { return c.SendString("ok") })

	for _, p := range []string{"/health", MetricsPath} {
		resp, err := app.Test(httptest.NewRequestWithContext(context.Background(), http.MethodGet, p, http.NoBody))
		if err != nil {
			t.Fatal(err)
		}
		_, _ = io.Copy(io.Discard, resp.Body)
		_ = resp.Body.Close()
	}

	if n := len(sr.Ended()); n != 0 {
		t.Fatalf("muốn 0 span cho probe path, có %d", n)
	}
}

// X-Trace-Id là đường rẻ để client báo lỗi kèm trace id mà không cần SDK
// phía client (Flutter RUM ngoài scope — xem ADR §7).
func TestTraceIDResponseHeader(t *testing.T) {
	app, _ := newTracingTestApp(t)
	app.Get("/api/v1/venues", func(c *fiber.Ctx) error { return c.SendString("ok") })

	resp, err := app.Test(httptest.NewRequestWithContext(context.Background(), http.MethodGet, "/api/v1/venues", http.NoBody))
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = resp.Body.Close() }()

	if id := resp.Header.Get("X-Trace-Id"); len(id) != 32 {
		t.Fatalf("X-Trace-Id = %q, muốn 32 ký tự hex", id)
	}
}

// traceparent gửi vào phải được nối tiếp, không tạo trace mới.
func TestTraceparentIsContinued(t *testing.T) {
	app, sr := newTracingTestApp(t)
	app.Get("/api/v1/venues", func(c *fiber.Ctx) error { return c.SendString("ok") })

	req := httptest.NewRequestWithContext(context.Background(), http.MethodGet, "/api/v1/venues", http.NoBody)
	req.Header.Set("traceparent", "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01")

	resp, err := app.Test(req)
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = resp.Body.Close() }()

	spans := sr.Ended()
	if len(spans) != 1 {
		t.Fatalf("muốn 1 span, có %d", len(spans))
	}
	if got := spans[0].SpanContext().TraceID().String(); got != "4bf92f3577b34da6a3ce929d0e0e4736" {
		t.Fatalf("trace id = %s — traceparent không được nối tiếp", got)
	}
}

// Span name phải là route pattern, không phải URL thô: mỗi id trong tên span là
// một series traces_spanmetrics_calls_total mới — cardinality nổ.
func TestSpanNameUsesRoutePattern(t *testing.T) {
	app, sr := newTracingTestApp(t)
	app.Get("/api/v1/venues/:id", func(c *fiber.Ctx) error { return c.SendString("ok") })

	resp, err := app.Test(httptest.NewRequestWithContext(context.Background(), http.MethodGet, "/api/v1/venues/9f3c-abcd", http.NoBody))
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = resp.Body.Close() }()

	spans := sr.Ended()
	if len(spans) != 1 {
		t.Fatalf("muốn 1 span, có %d", len(spans))
	}
	if got := spans[0].Name(); got != "GET /api/v1/venues/:id" {
		t.Fatalf("span name = %q, muốn \"GET /api/v1/venues/:id\"", got)
	}
}

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

	resp, err := app.Test(httptest.NewRequestWithContext(context.Background(), http.MethodGet, "/api/v1/venues", http.NoBody))
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = resp.Body.Close() }()

	out := buf.String()
	if !strings.Contains(out, `"trace_id":"`) {
		t.Fatalf("log không có trace_id — log->trace jump sẽ không chạy.\nlog: %s", out)
	}
	m := regexp.MustCompile(`"trace_id":"([a-f0-9]{32})"`).FindStringSubmatch(out)
	if m == nil {
		t.Fatalf("trace_id không phải 32 ký tự hex, Loki derivedFields sẽ không khớp.\nlog: %s", out)
	}
}

// Tail sampling policy keep-all-errors dựa vào status ERROR. Theo semconv, 5xx
// là ERROR ở server span; 4xx là lỗi phía client và để UNSET.
func TestServerSpanStatusFollowsSemconv(t *testing.T) {
	app, sr := newTracingTestApp(t)
	app.Get("/boom", func(c *fiber.Ctx) error { return c.SendStatus(fiber.StatusInternalServerError) })
	app.Get("/missing", func(c *fiber.Ctx) error { return c.SendStatus(fiber.StatusNotFound) })

	for _, p := range []string{"/boom", "/missing"} {
		resp, err := app.Test(httptest.NewRequestWithContext(context.Background(), http.MethodGet, p, http.NoBody))
		if err != nil {
			t.Fatal(err)
		}
		_ = resp.Body.Close()
	}

	got := map[string]codes.Code{}
	for _, s := range sr.Ended() {
		got[s.Name()] = s.Status().Code
	}
	if got["GET /boom"] != codes.Error {
		t.Fatalf("5xx status = %v, muốn Error", got["GET /boom"])
	}
	if got["GET /missing"] != codes.Unset {
		t.Fatalf("4xx status = %v, muốn Unset", got["GET /missing"])
	}
}
