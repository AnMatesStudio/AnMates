package e2e

import (
	"fmt"
	"os"
	"testing"
)

// TestMain skips the whole package unless E2E_BASE_URL points at a running API:
// these journeys need a live server + Postgres, which `go test ./...` in CI
// (or on a laptop without the stack up) does not have.
func TestMain(m *testing.M) {
	if os.Getenv("E2E_BASE_URL") == "" {
		fmt.Println("e2e: E2E_BASE_URL not set — skipping (needs a running API; see e2e_test.go)")
		os.Exit(0)
	}
	os.Exit(m.Run())
}
