package telemetry

import (
	"context"
	"strings"

	"go.opentelemetry.io/otel/attribute"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
)

// redactingExporter bỏ query string khỏi span trước khi export.
//
// otelfiber ghi url.query và url.full (OriginalURL, gồm cả query) vào MỌI
// server span và không có option tắt. Query của anmates-api chứa dữ liệu người
// dùng: /venues?lat=&lng= là vị trí GPS, /venues/search?q= là từ khoá tìm kiếm.
// url.path + http.route còn nguyên nên trace vẫn đủ để debug.
//
// Làm ở exporter chứ không ở collector: dữ liệu nhạy cảm không bao giờ rời
// process, bất kể collector nào đứng sau được cấu hình ra sao.
type redactingExporter struct {
	sdktrace.SpanExporter
}

func (e redactingExporter) ExportSpans(ctx context.Context, spans []sdktrace.ReadOnlySpan) error {
	out := make([]sdktrace.ReadOnlySpan, len(spans))
	for i, s := range spans {
		out[i] = redactedSpan{s}
	}
	return e.SpanExporter.ExportSpans(ctx, out)
}

type redactedSpan struct {
	sdktrace.ReadOnlySpan
}

func (s redactedSpan) Attributes() []attribute.KeyValue {
	in := s.ReadOnlySpan.Attributes()
	out := make([]attribute.KeyValue, 0, len(in))
	for _, kv := range in {
		switch kv.Key {
		case "url.query":
			continue
		case "url.full":
			full, _, _ := strings.Cut(kv.Value.AsString(), "?")
			kv = attribute.String(string(kv.Key), full)
		}
		out = append(out, kv)
	}
	return out
}
