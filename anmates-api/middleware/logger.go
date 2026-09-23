package middleware

import (
	"fmt"
	"log/slog"
	"sync/atomic"
	"time"

	"github.com/gofiber/fiber/v2"
	"go.opentelemetry.io/otel/trace"
)

var reqCounter atomic.Uint64

func nextReqID() string {
	return fmt.Sprintf("req-%05d", reqCounter.Add(1))
}

// RequestLogger logs one structured line per request.
//
// Log level by HTTP status:
//   - 5xx → Error
//   - 4xx → Warn   (includes response body so the error message is visible)
//   - 2xx/3xx → Info
//
// A short req_id is stored in fiber locals so handlers can reference it.
func RequestLogger(log *slog.Logger) fiber.Handler {
	return func(c *fiber.Ctx) error {
		start := time.Now()
		reqID := nextReqID()
		c.Locals("req_id", reqID)

		err := c.Next()

		// Skip noisy WebSocket upgrade requests
		path := c.Path()
		if len(path) >= 4 && path[:4] == "/ws/" {
			return err
		}

		status := c.Response().StatusCode()
		latency := time.Since(start)

		attrs := []any{
			slog.String("req_id", reqID),
			slog.String("method", c.Method()),
			slog.String("path", path),
			slog.Int("status", status),
			slog.String("latency", latency.Round(time.Millisecond).String()),
			slog.String("ip", c.IP()),
		}

		// For any error response, attach the response body so the error message
		// is visible in logs without having to dig through curl output.
		if status >= 400 {
			if body := c.Response().Body(); len(body) > 0 && len(body) < 4096 {
				attrs = append(attrs, slog.String("error_body", string(body)))
			}
		}

		if err != nil {
			attrs = append(attrs, slog.String("handler_error", err.Error()))
		}

		// trace_id/span_id vào MỖI dòng log. Đây là thứ làm trace -> log và
		// log -> trace jump chạy được:
		//   - log đi qua OTLP: trace_id thành structured metadata của Loki,
		//     khớp derivedFields matcher `label`
		//   - log scrape từ /var/log/pods: trace_id nằm trong text JSON,
		//     khớp derivedFields matcher `regex`
		// Cả hai matcher đều được cấu hình ở chart observability (anmates-infra).
		if sc := trace.SpanContextFromContext(c.UserContext()); sc.IsValid() {
			attrs = append(attrs,
				slog.String("trace_id", sc.TraceID().String()),
				slog.String("span_id", sc.SpanID().String()),
			)
		}

		switch {
		case status >= 500 || err != nil:
			log.Error("request", attrs...)
		case status >= 400:
			log.Warn("request", attrs...)
		default:
			log.Info("request", attrs...)
		}

		return err
	}
}
