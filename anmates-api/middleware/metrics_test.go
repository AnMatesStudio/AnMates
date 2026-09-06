package middleware

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gofiber/fiber/v2"
)

// newMetricsApp dựng app có Metrics + vài route đại diện cho anmates-api thật:
// một route thường, một route có path param, /health (probe) và /metrics (scrape).
func newMetricsApp(t *testing.T) *fiber.App {
	t.Helper()
	app := fiber.New()
	Metrics(app, "anmates-api-test")
	app.Get("/health", func(c *fiber.Ctx) error { return c.SendString("ok") })
	app.Get("/api/v1/venues", func(c *fiber.Ctx) error { return c.SendString("[]") })
	app.Get("/api/v1/venues/:id", func(c *fiber.Ctx) error { return c.SendString("{}") })
	return app
}

func get(t *testing.T, app *fiber.App, path string) string {
	t.Helper()
	req := httptest.NewRequestWithContext(context.Background(), http.MethodGet, path, http.NoBody)
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("app.Test(%s): %v", path, err)
	}
	defer func() { _ = resp.Body.Close() }()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatalf("read body(%s): %v", path, err)
	}
	return string(body)
}

// Tên counter là hợp đồng với prometheus-adapter: rule trong
// anmates-infra/charts/observability/values.yaml khớp `^(.*)_total` rồi đổi
// thành `${1}_per_second`. Đổi tên metric ở đây = HPA mất metric.
func TestMetrics_ExposesHTTPRequestsTotalForAdapterRule(t *testing.T) {
	app := newMetricsApp(t)
	get(t, app, "/api/v1/venues")

	body := get(t, app, "/metrics")

	for _, want := range []string{
		"http_requests_total",
		`path="/api/v1/venues"`,
		`method="GET"`,
		`status_code="200"`,
		`service="anmates-api-test"`,
	} {
		if !strings.Contains(body, want) {
			t.Errorf("scrape output thiếu %q", want)
		}
	}
}

// Label `path` phải là route pattern, không phải URL thô — nếu không, mỗi venue
// id sinh một time series mới và Prometheus nổ cardinality.
func TestMetrics_PathLabelUsesRoutePattern(t *testing.T) {
	app := newMetricsApp(t)
	get(t, app, "/api/v1/venues/11111111-1111-1111-1111-111111111111")
	get(t, app, "/api/v1/venues/22222222-2222-2222-2222-222222222222")

	body := get(t, app, "/metrics")

	if !strings.Contains(body, `path="/api/v1/venues/:id"`) {
		t.Errorf("muốn label path là route pattern `/api/v1/venues/:id`, không thấy trong:\n%s", body)
	}
	if strings.Contains(body, "11111111-1111-1111-1111-111111111111") {
		t.Error("URL thô bị đưa vào label path — cardinality sẽ nổ theo số lượng id")
	}
}

// /health bị kubelet probe 10s/lần và /metrics bị Prometheus scrape 30s/lần.
// Đếm chúng vào http_requests_total nghĩa là HPA scale theo lưu lượng máy móc
// chứ không phải lưu lượng người dùng.
func TestMetrics_SkipsHealthAndMetricsPaths(t *testing.T) {
	app := newMetricsApp(t)
	get(t, app, "/health")
	get(t, app, "/metrics")

	body := get(t, app, "/metrics")

	if strings.Contains(body, `path="/health"`) {
		t.Error("/health bị đếm vào http_requests_total — probe sẽ làm nhiễu HPA")
	}
	if strings.Contains(body, `path="/metrics"`) {
		t.Error("/metrics bị đếm vào http_requests_total — scrape sẽ làm nhiễu HPA")
	}
}

// Runtime metrics của Go (goroutine, GC, heap) là thứ chẩn đoán OOM — cụm chỉ
// có 13.9Gi nên đây không phải thứ xa xỉ.
func TestMetrics_ExposesGoRuntimeCollectors(t *testing.T) {
	app := newMetricsApp(t)

	body := get(t, app, "/metrics")

	for _, want := range []string{"go_goroutines", "go_memstats_alloc_bytes"} {
		if !strings.Contains(body, want) {
			t.Errorf("scrape output thiếu runtime metric %q", want)
		}
	}
}
