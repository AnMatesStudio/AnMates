// Package smoke exercises every public route of the running anmates-api so we
// can catch broken endpoints before shipping. It does NOT spin up its own
// server — you point it at one with SMOKE_BASE_URL (default http://localhost:8080).
//
// Run:
//
//	docker compose --env-file .env up -d   # or: npm run dev
//	npm run test:smoke
//
// Prerequisites the server must satisfy:
//   - DEV_MODE=true and DEV_BYPASS_SECRET set (the test uses /auth/dev-login
//     to skip Firebase OTP)
//   - DISABLE_RATE_LIMIT=1 (otherwise the burst of requests trips 429)
//   - Reachable Postgres (the test inserts wishlists / matches / users)
//
// The test is intentionally tolerant of an already-populated DB: it generates
// unique phones/emails per run so it can be re-run without cleanup.
package smoke

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"testing"
	"time"
)

// ── Config ───────────────────────────────────────────────────────────────────

func baseURL() string {
	if v := os.Getenv("SMOKE_BASE_URL"); v != "" {
		return strings.TrimRight(v, "/")
	}
	return "http://localhost:8080"
}

func devSecret() string {
	if v := os.Getenv("DEV_BYPASS_SECRET"); v != "" {
		return v
	}
	return "dev-local-2026"
}

// ── HTTP helpers ─────────────────────────────────────────────────────────────

var client = &http.Client{Timeout: 10 * time.Second}

type envelope struct {
	Success bool            `json:"success"`
	Data    json.RawMessage `json:"data"`
	Error   *struct {
		Code    string `json:"code"`
		Message string `json:"message"`
	} `json:"error"`
}

func do(t *testing.T, method, path string, token string, body any) (*http.Response, envelope) {
	t.Helper()
	var rdr io.Reader
	if body != nil {
		b, err := json.Marshal(body)
		if err != nil {
			t.Fatalf("marshal body: %v", err)
		}
		rdr = bytes.NewReader(b)
	}
	req, err := http.NewRequest(method, baseURL()+path, rdr)
	if err != nil {
		t.Fatalf("build req %s %s: %v", method, path, err)
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	resp, err := client.Do(req)
	if err != nil {
		t.Fatalf("%s %s: %v", method, path, err)
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	var env envelope
	_ = json.Unmarshal(raw, &env)
	t.Logf("%s %s → %d  %s", method, path, resp.StatusCode, truncate(string(raw), 240))
	return resp, env
}

func assertStatus(t *testing.T, resp *http.Response, want ...int) {
	t.Helper()
	for _, w := range want {
		if resp.StatusCode == w {
			return
		}
	}
	t.Fatalf("%s %s: got %d, want %v", resp.Request.Method, resp.Request.URL.Path, resp.StatusCode, want)
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n] + "…"
}

// ── Tests ────────────────────────────────────────────────────────────────────

// TestHealth is the canary — if this fails the rest of the suite is meaningless.
func TestHealth(t *testing.T) {
	resp, env := do(t, http.MethodGet, "/health", "", nil)
	assertStatus(t, resp, http.StatusOK)
	if !env.Success {
		t.Fatalf("health: success=false: %+v", env.Error)
	}
}

// TestAuthEmail covers register → login → refresh → logout for the email flow.
func TestAuthEmail(t *testing.T) {
	stamp := time.Now().UnixNano()
	email := fmt.Sprintf("smoke+%d@anmates.test", stamp)
	password := "supersecret-123"

	// register
	resp, env := do(t, http.MethodPost, "/api/auth/register", "", map[string]any{
		"email":    email,
		"password": password,
		"name":     "Smoke Test",
	})
	assertStatus(t, resp, http.StatusCreated)
	var reg struct {
		AccessToken  string `json:"access_token"`
		RefreshToken string `json:"refresh_token"`
		User         struct {
			ID string `json:"id"`
		} `json:"user"`
	}
	if err := json.Unmarshal(env.Data, &reg); err != nil {
		t.Fatalf("decode register: %v", err)
	}
	if reg.AccessToken == "" || reg.RefreshToken == "" || reg.User.ID == "" {
		t.Fatalf("register: missing fields: %+v", reg)
	}

	// register again → 409
	resp, _ = do(t, http.MethodPost, "/api/auth/register", "", map[string]any{
		"email": email, "password": password, "name": "Dup",
	})
	assertStatus(t, resp, http.StatusConflict)

	// login
	resp, env = do(t, http.MethodPost, "/api/auth/login", "", map[string]any{
		"email": email, "password": password,
	})
	assertStatus(t, resp, http.StatusOK)
	var login struct {
		AccessToken  string `json:"access_token"`
		RefreshToken string `json:"refresh_token"`
	}
	_ = json.Unmarshal(env.Data, &login)
	if login.AccessToken == "" {
		t.Fatalf("login: empty access token")
	}

	// bad password → 401
	resp, _ = do(t, http.MethodPost, "/api/auth/login", "", map[string]any{
		"email": email, "password": "wrong",
	})
	assertStatus(t, resp, http.StatusUnauthorized)

	// refresh
	resp, env = do(t, http.MethodPost, "/api/auth/refresh", "", map[string]any{
		"refresh_token": login.RefreshToken,
	})
	assertStatus(t, resp, http.StatusOK)
	var refreshed struct {
		AccessToken  string `json:"access_token"`
		RefreshToken string `json:"refresh_token"`
	}
	_ = json.Unmarshal(env.Data, &refreshed)
	if refreshed.AccessToken == "" {
		t.Fatalf("refresh: empty access token")
	}

	// old refresh now invalid → 401
	resp, _ = do(t, http.MethodPost, "/api/auth/refresh", "", map[string]any{
		"refresh_token": login.RefreshToken,
	})
	assertStatus(t, resp, http.StatusUnauthorized)

	// logout
	resp, _ = do(t, http.MethodPost, "/api/auth/logout", "", map[string]any{
		"refresh_token": refreshed.RefreshToken,
	})
	assertStatus(t, resp, http.StatusOK)
}

// TestFullFlow walks dev-login → profile → wishlist → matches → conversations
// → chat history → nồi lẩu progress for two users. The pair is needed because
// `/api/matches` requires another user with ≥2 overlapping foods to surface.
func TestFullFlow(t *testing.T) {
	stamp := time.Now().UnixNano()
	a := devLogin(t, fmt.Sprintf("+8499%013d", stamp%10000000000000), "Alice Smoke")
	b := devLogin(t, fmt.Sprintf("+8488%013d", stamp%10000000000000), "Bob Smoke")

	// Profile
	resp, env := do(t, http.MethodGet, "/api/profile", a.access, nil)
	assertStatus(t, resp, http.StatusOK)
	if !env.Success {
		t.Fatalf("profile: %+v", env.Error)
	}

	resp, _ = do(t, http.MethodPut, "/api/profile", a.access, map[string]any{
		"name": "Alice Updated",
		"bio":  "I love pho",
	})
	assertStatus(t, resp, http.StatusOK)

	// Wishlist — A and B share 2 foods (pho, com), differ on a 3rd.
	addWishlist(t, a.access, "Phở Bát Đàn", "pho")
	addWishlist(t, a.access, "Cơm tấm Sài Gòn", "com")
	addWishlist(t, a.access, "Bún chả Hương Liên", "bun")

	addWishlist(t, b.access, "Phở Bát Đàn", "pho")
	addWishlist(t, b.access, "Cơm tấm Sài Gòn", "com")
	addWishlist(t, b.access, "Bún bò Huế", "bun")

	// invalid category → 400
	resp, _ = do(t, http.MethodPost, "/api/wishlist", a.access, map[string]any{
		"food_name": "nope", "food_category": "bogus",
	})
	assertStatus(t, resp, http.StatusBadRequest)

	// List wishlist (auth required, unauth → 401)
	resp, _ = do(t, http.MethodGet, "/api/wishlist", "", nil)
	assertStatus(t, resp, http.StatusUnauthorized)

	resp, env = do(t, http.MethodGet, "/api/wishlist", a.access, nil)
	assertStatus(t, resp, http.StatusOK)
	var items []map[string]any
	_ = json.Unmarshal(env.Data, &items)
	if len(items) < 3 {
		t.Fatalf("wishlist: want ≥3 items for A, got %d", len(items))
	}

	// Delete one wishlist item
	firstID, _ := items[0]["id"].(string)
	if firstID != "" {
		resp, _ = do(t, http.MethodDelete, "/api/wishlist/"+firstID, a.access, nil)
		assertStatus(t, resp, http.StatusOK)
	}

	// Matches — A should now see B as a candidate (≥2 overlap).
	// Note: matches may be empty if other users in the DB already share more
	// foods — we treat "API responds 200 with array" as the smoke contract.
	resp, env = do(t, http.MethodGet, "/api/matches", a.access, nil)
	assertStatus(t, resp, http.StatusOK)
	var candidates []map[string]any
	_ = json.Unmarshal(env.Data, &candidates)

	// Accept B explicitly (idempotent — works whether B is in the candidate list or not).
	resp, env = do(t, http.MethodPost, "/api/matches/"+b.userID+"/accept", a.access, nil)
	assertStatus(t, resp, http.StatusCreated, http.StatusOK)
	var match struct {
		ID string `json:"id"`
	}
	_ = json.Unmarshal(env.Data, &match)
	if match.ID == "" {
		t.Fatalf("accept: empty match id")
	}

	// Idempotent: second call returns the same match.
	resp, _ = do(t, http.MethodPost, "/api/matches/"+b.userID+"/accept", a.access, nil)
	assertStatus(t, resp, http.StatusCreated, http.StatusOK)

	// Conversations
	resp, env = do(t, http.MethodGet, "/api/conversations", a.access, nil)
	assertStatus(t, resp, http.StatusOK)
	var convos []map[string]any
	_ = json.Unmarshal(env.Data, &convos)
	found := false
	for _, cv := range convos {
		if cv["match_id"] == match.ID {
			found = true
			break
		}
	}
	if !found {
		t.Errorf("conversations: match %s not present in %d convos", match.ID, len(convos))
	}

	// Chat history (empty for fresh match)
	resp, _ = do(t, http.MethodGet, "/api/matches/"+match.ID+"/messages", a.access, nil)
	assertStatus(t, resp, http.StatusOK)

	// Chat history pagination params
	resp, _ = do(t, http.MethodGet, "/api/matches/"+match.ID+"/messages?limit=10", a.access, nil)
	assertStatus(t, resp, http.StatusOK)

	// Nồi Lẩu progress (level 1, points 0)
	resp, env = do(t, http.MethodGet, "/api/matches/"+match.ID+"/progress", a.access, nil)
	assertStatus(t, resp, http.StatusOK)
	var prog struct {
		Level  int `json:"level"`
		Points int `json:"points"`
	}
	_ = json.Unmarshal(env.Data, &prog)
	if prog.Level < 1 {
		t.Errorf("progress: level=%d, want ≥1", prog.Level)
	}

	// Unauth on a protected route → 401
	resp, _ = do(t, http.MethodGet, "/api/profile", "", nil)
	assertStatus(t, resp, http.StatusUnauthorized)

	// Garbage uuid → 400
	resp, _ = do(t, http.MethodPost, "/api/matches/not-a-uuid/accept", a.access, nil)
	assertStatus(t, resp, http.StatusBadRequest)
}

// TestDevLoginGate verifies the secret is enforced. Wrong secret → 403.
func TestDevLoginGate(t *testing.T) {
	resp, _ := do(t, http.MethodPost, "/api/auth/dev-login", "", map[string]any{
		"secret": "definitely-wrong",
		"phone":  "+84999999998",
		"name":   "Hack",
	})
	assertStatus(t, resp, http.StatusForbidden)
}

// ── Test helpers ─────────────────────────────────────────────────────────────

type session struct {
	access  string
	refresh string
	userID  string
}

func devLogin(t *testing.T, phone, name string) session {
	t.Helper()
	resp, env := do(t, http.MethodPost, "/api/auth/dev-login", "", map[string]any{
		"secret": devSecret(),
		"phone":  phone,
		"name":   name,
	})
	if resp.StatusCode == http.StatusForbidden {
		t.Skipf("dev-login disabled (DEV_MODE off or wrong secret) — skipping. body=%+v", env.Error)
	}
	assertStatus(t, resp, http.StatusOK)
	var s struct {
		AccessToken  string `json:"access_token"`
		RefreshToken string `json:"refresh_token"`
		User         struct {
			ID string `json:"id"`
		} `json:"user"`
	}
	if err := json.Unmarshal(env.Data, &s); err != nil {
		t.Fatalf("decode dev-login: %v", err)
	}
	if s.AccessToken == "" || s.User.ID == "" {
		t.Fatalf("dev-login: empty token/user")
	}
	return session{access: s.AccessToken, refresh: s.RefreshToken, userID: s.User.ID}
}

func addWishlist(t *testing.T, token, name, category string) {
	t.Helper()
	resp, _ := do(t, http.MethodPost, "/api/wishlist", token, map[string]any{
		"food_name":     name,
		"food_category": category,
	})
	// 201 fresh, 409 if already added — both are "OK" for a re-runnable smoke test.
	assertStatus(t, resp, http.StatusCreated, http.StatusConflict)
}
