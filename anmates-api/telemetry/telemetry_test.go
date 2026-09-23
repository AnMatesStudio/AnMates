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
