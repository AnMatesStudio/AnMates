package telemetry

import (
	"context"
	"testing"

	"go.opentelemetry.io/otel/attribute"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
)

// otelfiber ghi url.query và url.full (kèm query string) vào mọi server span.
// Query của /venues và /venues/search chứa toạ độ lat/lng và từ khoá tìm kiếm
// của người dùng — không được rời process.
func TestRedactingExporterDropsQueryString(t *testing.T) {
	mem := tracetest.NewInMemoryExporter()
	tp := sdktrace.NewTracerProvider(sdktrace.WithSyncer(redactingExporter{mem}))

	_, span := tp.Tracer("test").Start(context.Background(), "GET /api/v1/venues")
	span.SetAttributes(
		attribute.String("url.path", "/api/v1/venues"),
		attribute.String("url.query", "lat=10.77&lng=106.7"),
		attribute.String("url.full", "/api/v1/venues?lat=10.77&lng=106.7"),
		attribute.String("http.route", "/api/v1/venues"),
	)
	span.End()

	spans := mem.GetSpans()
	if len(spans) != 1 {
		t.Fatalf("muốn 1 span, có %d", len(spans))
	}
	got := map[attribute.Key]string{}
	for _, kv := range spans[0].Attributes {
		got[kv.Key] = kv.Value.Emit()
	}
	if _, ok := got["url.query"]; ok {
		t.Fatalf("url.query vẫn còn: %v", got)
	}
	if got["url.full"] != "/api/v1/venues" {
		t.Fatalf("url.full = %q, muốn bỏ query string", got["url.full"])
	}
	if got["url.path"] != "/api/v1/venues" || got["http.route"] != "/api/v1/venues" {
		t.Fatalf("attribute không nhạy cảm bị mất: %v", got)
	}
}
