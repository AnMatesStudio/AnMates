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
	//
	// KHÔNG gọi WithInsecure(): option tường minh đè lên env. Exporter tự suy ra
	// insecure từ scheme của OTEL_EXPORTER_OTLP_ENDPOINT (http:// → plaintext,
	// https:// → TLS) và vẫn tôn trọng OTEL_EXPORTER_OTLP_INSECURE.
	traceExp, err := otlptracegrpc.New(ctx)
	if err != nil {
		return noop, fmt.Errorf("otlp trace exporter: %w", err)
	}

	tp := sdktrace.NewTracerProvider(
		sdktrace.WithResource(res),
		// Batch, không phải SimpleSpanProcessor: simple export đồng bộ trên
		// đường request và biến độ trễ của collector thành độ trễ của API.
		sdktrace.WithBatcher(redactingExporter{traceExp},
			sdktrace.WithBatchTimeout(5*time.Second),
			sdktrace.WithMaxExportBatchSize(512),
			sdktrace.WithMaxQueueSize(4096),
		),
		// KHÔNG gọi WithSampler(): option tường minh ĐÈ LÊN OTEL_TRACES_SAMPLER.
		// SDK tự đọc env, và khi env trống mặc định của nó đã là
		// ParentBased(AlwaysSample) — trùng với samplerFromEnv().
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
	metricExp, err := otlpmetricgrpc.New(ctx)
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
