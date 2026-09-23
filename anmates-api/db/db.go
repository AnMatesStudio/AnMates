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
// Span name mặc định của otelpgx (>= v0.12) là operation ("SELECT"), không phải
// cả câu SQL — KHÔNG bật WithFullSQLInSpanName: mỗi biến thể câu query sẽ thành
// một span name khác nhau và spanmetrics sinh một series cho từng cái.
//
// KHÔNG bật WithIncludeQueryParameters: query parameter chứa email, số điện
// thoại, token — đưa vào span attribute là đẩy PII vào Tempo.
func applyTracing(cfg *pgxpool.Config) {
	cfg.ConnConfig.Tracer = otelpgx.NewTracer()
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
