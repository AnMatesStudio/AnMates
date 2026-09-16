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
