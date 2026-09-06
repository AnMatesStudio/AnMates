package middleware

import (
	"github.com/ansrivas/fiberprometheus/v2"
	"github.com/gofiber/fiber/v2"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/collectors"
)

// MetricsPath là endpoint Prometheus scrape. Nó KHÔNG được nginx trong pod web
// proxy ra ngoài (anmates_flutter/nginx.conf chỉ mở /health, /api/, /ws/), nên
// chỉ truy cập được từ trong cluster.
const MetricsPath = "/metrics"

// metricsSkipPaths là các route bị loại khỏi http_requests_total.
//
// Cả hai đều là lưu lượng máy móc chứ không phải người dùng: /health bị kubelet
// probe 10s/lần (api.probe.periodSeconds), /metrics bị Prometheus scrape
// 30s/lần. Đếm chúng vào counter mà HPA đọc nghĩa là mỗi pod tự tạo ra một sàn
// request cố định — HPA sẽ không bao giờ scale về min, và scale-out lại càng
// làm sàn đó cao thêm.
var metricsSkipPaths = []string{"/health", MetricsPath}

// Metrics gắn Prometheus instrumentation vào app và mở endpoint scrape.
//
// Counter phơi ra tên `http_requests_total` (namespace "http", không subsystem).
// Đây là HỢP ĐỒNG với prometheus-adapter bên anmates-infra: rule ở đó khớp
// `^(.*)_total` và đổi tên thành `${1}_per_second`, tạo ra metric
// `http_requests_per_second` mà HPA tham chiếu. Đổi tên metric ở đây là làm
// hỏng HPA ở repo kia — sửa cả hai nơi cùng lúc.
//
// Dùng registry riêng thay vì prometheus.DefaultRegisterer để hai lần gọi
// Metrics() (trong test chẳng hạn) không panic vì duplicate registration.
func Metrics(app *fiber.App, serviceName string) {
	reg := prometheus.NewRegistry()
	reg.MustRegister(
		collectors.NewGoCollector(),
		collectors.NewProcessCollector(collectors.ProcessCollectorOpts{}),
	)

	fp := fiberprometheus.NewWithRegistry(reg, serviceName, "http", "", nil)
	fp.SetSkipPaths(metricsSkipPaths)
	fp.RegisterAt(app, MetricsPath)
	app.Use(fp.Middleware)
}
