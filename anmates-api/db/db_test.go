package db

import (
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
)

// NewPool phải gắn QueryTracer. Không có nó thì không span DB nào được sinh ra
// và waterfall dừng ở tầng HTTP — mất đúng thứ tracing hữu ích nhất cho backend.
//
// Không cần Postgres thật: chỉ kiểm tra config được dựng đúng.
func TestPoolConfigHasQueryTracer(t *testing.T) {
	cfg, err := pgxpool.ParseConfig("postgres://u:p@127.0.0.1:5432/db?sslmode=disable")
	if err != nil {
		t.Fatal(err)
	}
	applyTracing(cfg)

	if cfg.ConnConfig.Tracer == nil {
		t.Fatal("ConnConfig.Tracer nil — otelpgx chưa được gắn, sẽ không có DB span nào")
	}
}
