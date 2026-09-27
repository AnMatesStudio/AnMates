// Package e2e walks whole user journeys through the running anmates-api, the
// way the app does: two real users, a match, chat, a booking, a meal rating —
// plus the safety actions every meet-a-stranger app needs (unmatch, block,
// report). Like ./smoke it does NOT start a server; point it at one:
//
//	docker compose up -d db api
//	docker run --rm --network anmates_default -e E2E_BASE_URL=http://api:8080 \
//	  -e DEV_BYPASS_SECRET=... -v <repo>/anmates-api:/src -w /src \
//	  golang:1.25-alpine go test ./e2e/ -count=1 -v
//
// Use the compose network: on the host, port 8080 may belong to another
// server (llama-server also answers /health with 200).
//
// Server prerequisites: DEV_MODE=true, DEV_BYPASS_SECRET, DISABLE_RATE_LIMIT=1.
// Every run creates fresh users, so the suite is re-runnable without cleanup.
package e2e

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

// ── Config + HTTP ────────────────────────────────────────────────────────────

func baseURL() string {
	if v := os.Getenv("E2E_BASE_URL"); v != "" {
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

var client = &http.Client{Timeout: 15 * time.Second}

type envelope struct {
	Success bool            `json:"success"`
	Data    json.RawMessage `json:"data"`
	Error   *struct {
		Code    string `json:"code"`
		Message string `json:"message"`
	} `json:"error"`
}

func (e envelope) code() string {
	if e.Error == nil {
		return ""
	}
	return e.Error.Code
}

func do(t *testing.T, method, path, token string, body any) (int, envelope) {
	t.Helper()
	var rdr io.Reader
	if body != nil {
		b, _ := json.Marshal(body)
		rdr = bytes.NewReader(b)
	}
	req, err := http.NewRequestWithContext(context.Background(), method, baseURL()+path, rdr)
	if err != nil {
		t.Fatalf("build %s %s: %v", method, path, err)
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	res, err := client.Do(req)
	if err != nil {
		t.Fatalf("%s %s: %v", method, path, err)
	}
	defer res.Body.Close()
	raw, _ := io.ReadAll(res.Body)
	var env envelope
	_ = json.Unmarshal(raw, &env)
	if testing.Verbose() {
		s := string(raw)
		if len(s) > 200 {
			s = s[:200] + "…"
		}
		t.Logf("%s %s → %d %s", method, path, res.StatusCode, s)
	}
	return res.StatusCode, env
}

// must asserts the status and fails with the endpoint named, so a missing
// route reads as "POST /api/v1/blocks → 404, want 201", not a decode panic.
func must(t *testing.T, method, path, token string, body any, want ...int) envelope {
	t.Helper()
	status, env := do(t, method, path, token, body)
	for _, w := range want {
		if status == w {
			return env
		}
	}
	t.Fatalf("%s %s → %d (error=%s), want %v", method, path, status, env.code(), want)
	return env
}

func decode(t *testing.T, env envelope, v any) {
	t.Helper()
	if err := json.Unmarshal(env.Data, v); err != nil {
		t.Fatalf("decode data %s: %v", string(env.Data), err)
	}
}

// ── Fixtures ─────────────────────────────────────────────────────────────────

type user struct {
	token string
	id    string
	name  string
}

var seq atomic.Int64

func newUser(t *testing.T, name string) user {
	t.Helper()
	n := time.Now().UnixNano()%1_000_000_000_000 + seq.Add(1)
	phone := fmt.Sprintf("+8477%013d", n)
	status, env := do(t, http.MethodPost, "/api/v1/auth/dev-login", "", map[string]any{
		"secret": devSecret(), "phone": phone, "name": name,
	})
	if status == http.StatusForbidden {
		t.Skip("dev-login disabled (DEV_MODE off or wrong DEV_BYPASS_SECRET)")
	}
	if status != http.StatusOK {
		t.Fatalf("dev-login → %d", status)
	}
	var s struct {
		AccessToken string `json:"access_token"`
		User        struct {
			ID string `json:"id"`
		} `json:"user"`
	}
	decode(t, env, &s)
	return user{token: s.AccessToken, id: s.User.ID, name: name}
}

// matchedPair creates two users with overlapping wishlists who like each
// other, and returns them with their match id.
func matchedPair(t *testing.T) (user, user, string) {
	t.Helper()
	a, b := newUser(t, "E2E An"), newUser(t, "E2E Bình")
	for _, u := range []user{a, b} {
		for _, f := range [][2]string{{"Phở Thìn", "pho"}, {"Cơm tấm Ba Ghiền", "com"}} {
			must(t, http.MethodPost, "/api/v1/wishlist", u.token,
				map[string]any{"food_name": f[0], "food_category": f[1]}, 201, 409)
		}
	}
	must(t, http.MethodPost, "/api/v1/swipes", a.token, map[string]any{"target_id": b.id, "liked": true}, 200)
	env := must(t, http.MethodPost, "/api/v1/swipes", b.token, map[string]any{"target_id": a.id, "liked": true}, 200)
	var sw struct {
		Matched bool `json:"matched"`
		Match   struct {
			ID string `json:"id"`
		} `json:"match"`
	}
	decode(t, env, &sw)
	if !sw.Matched || sw.Match.ID == "" {
		t.Fatalf("mutual like did not create a match: %+v", sw)
	}
	return a, b, sw.Match.ID
}

func conversationIDs(t *testing.T, u user) map[string]bool {
	t.Helper()
	env := must(t, http.MethodGet, "/api/v1/conversations", u.token, nil, 200)
	var cs []struct {
		MatchID string `json:"match_id"`
	}
	decode(t, env, &cs)
	out := map[string]bool{}
	for _, c := range cs {
		out[c.MatchID] = true
	}
	return out
}

func candidateIDs(t *testing.T, u user) map[string]bool {
	t.Helper()
	env := must(t, http.MethodGet, "/api/v1/matches", u.token, nil, 200)
	var cs []struct {
		UserID string `json:"user_id"`
	}
	decode(t, env, &cs)
	out := map[string]bool{}
	for _, c := range cs {
		out[c.UserID] = true
	}
	return out
}

// ── E2E-01..03 · existing journey (must pass today) ─────────────────────────

// E2E-01: match → both see the conversation → propose + confirm a meal.
func TestE2E01_MatchChatBooking(t *testing.T) {
	a, b, mid := matchedPair(t)

	if !conversationIDs(t, a)[mid] || !conversationIDs(t, b)[mid] {
		t.Fatalf("match %s missing from someone's inbox", mid)
	}
	must(t, http.MethodGet, "/api/v1/matches/"+mid+"/messages", a.token, nil, 200)

	when := time.Now().Add(48 * time.Hour).UTC().Format(time.RFC3339)
	must(t, http.MethodPost, "/api/v1/matches/"+mid+"/booking", a.token, map[string]any{
		"restaurant_name": "Phở Thìn Lò Đúc", "scheduled_at": when,
	}, 200, 201)
	// The proposer cannot confirm their own proposal.
	must(t, http.MethodPost, "/api/v1/matches/"+mid+"/booking/confirm", a.token, nil, 409)
	env := must(t, http.MethodPost, "/api/v1/matches/"+mid+"/booking/confirm", b.token, nil, 200)
	var bk struct {
		Status string `json:"status"`
	}
	decode(t, env, &bk)
	if bk.Status != "confirmed" {
		t.Fatalf("booking status = %q, want confirmed", bk.Status)
	}
}

// E2E-02: a stranger can't read or act on someone else's match.
func TestE2E02_OutsiderIsLockedOut(t *testing.T) {
	_, _, mid := matchedPair(t)
	eve := newUser(t, "E2E Outsider")
	must(t, http.MethodGet, "/api/v1/matches/"+mid+"/messages", eve.token, nil, 404)
	must(t, http.MethodGet, "/api/v1/matches/"+mid+"/booking", eve.token, nil, 404)
}

// E2E-03: every protected route rejects a missing token.
func TestE2E03_AuthRequired(t *testing.T) {
	for _, r := range [][2]string{
		{"GET", "/api/v1/profile"}, {"GET", "/api/v1/conversations"}, {"GET", "/api/v1/matches"},
	} {
		must(t, r[0], r[1], "", nil, 401)
	}
}

// ── E2E-10.. · missing features (fail until implemented) ────────────────────

// E2E-10 Unmatch: DELETE /matches/:id removes the match for BOTH sides.
func TestE2E10_Unmatch(t *testing.T) {
	a, b, mid := matchedPair(t)
	eve := newUser(t, "E2E Outsider")

	must(t, http.MethodDelete, "/api/v1/matches/"+mid, eve.token, nil, 404) // not a member
	must(t, http.MethodDelete, "/api/v1/matches/not-a-uuid", a.token, nil, 400)
	must(t, http.MethodDelete, "/api/v1/matches/"+mid, a.token, nil, 200)

	if conversationIDs(t, a)[mid] || conversationIDs(t, b)[mid] {
		t.Fatalf("unmatched conversation %s still in an inbox", mid)
	}
	must(t, http.MethodGet, "/api/v1/matches/"+mid+"/messages", b.token, nil, 404)
	must(t, http.MethodDelete, "/api/v1/matches/"+mid, b.token, nil, 404) // already gone
}

// E2E-11 Block: ends the match, hides both people from each other's deck,
// and a like can never re-create a match while the block stands.
func TestE2E11_Block(t *testing.T) {
	a, b, mid := matchedPair(t)

	must(t, http.MethodPost, "/api/v1/blocks", a.token, map[string]any{"user_id": a.id}, 400) // self
	must(t, http.MethodPost, "/api/v1/blocks", a.token, map[string]any{"user_id": "nope"}, 400)
	must(t, http.MethodPost, "/api/v1/blocks", a.token, map[string]any{"user_id": b.id}, 201)
	must(t, http.MethodPost, "/api/v1/blocks", a.token, map[string]any{"user_id": b.id}, 201) // idempotent

	if conversationIDs(t, a)[mid] || conversationIDs(t, b)[mid] {
		t.Fatalf("block did not remove match %s", mid)
	}
	if candidateIDs(t, a)[b.id] || candidateIDs(t, b)[a.id] {
		t.Fatalf("blocked pair still see each other in the deck")
	}
	must(t, http.MethodPost, "/api/v1/swipes", b.token, map[string]any{"target_id": a.id, "liked": true}, 200, 403)
	status, env := do(t, http.MethodPost, "/api/v1/swipes", a.token, map[string]any{"target_id": b.id, "liked": true})
	if status == 200 {
		var sw struct {
			Matched bool `json:"matched"`
		}
		decode(t, env, &sw)
		if sw.Matched {
			t.Fatalf("mutual like re-created a match across a block")
		}
	} else if status != 403 {
		t.Fatalf("swipe across block → %d, want 200 (matched=false) or 403", status)
	}

	env = must(t, http.MethodGet, "/api/v1/blocks", a.token, nil, 200)
	var list []struct {
		UserID string `json:"user_id"`
		Name   string `json:"name"`
	}
	decode(t, env, &list)
	if len(list) != 1 || list[0].UserID != b.id {
		t.Fatalf("GET /blocks = %+v, want exactly %s", list, b.id)
	}

	must(t, http.MethodDelete, "/api/v1/blocks/"+b.id, a.token, nil, 200)
	env = must(t, http.MethodGet, "/api/v1/blocks", a.token, nil, 200)
	decode(t, env, &list)
	if len(list) != 0 {
		t.Fatalf("unblock left %+v", list)
	}
}

// E2E-12 Report: a user can report another with a known reason.
func TestE2E12_Report(t *testing.T) {
	a, b := newUser(t, "E2E Reporter"), newUser(t, "E2E Reported")
	env := must(t, http.MethodPost, "/api/v1/reports", a.token,
		map[string]any{"user_id": b.id, "reason": "no_show", "note": "Không đến buổi hẹn"}, 201)
	var r struct {
		ID string `json:"id"`
	}
	decode(t, env, &r)
	if r.ID == "" {
		t.Fatalf("report returned no id")
	}
	for _, bad := range []map[string]any{
		{"user_id": b.id, "reason": "bogus"},
		{"user_id": a.id, "reason": "spam"}, // self
		{"user_id": "nope", "reason": "spam"},
		{"user_id": b.id, "reason": "other", "note": strings.Repeat("x", 501)},
	} {
		must(t, http.MethodPost, "/api/v1/reports", a.token, bad, 400)
	}
	must(t, http.MethodPost, "/api/v1/reports", "", map[string]any{"user_id": b.id, "reason": "spam"}, 401)
}

// E2E-13 Meal rating: private until both have rated, then both see both.
func TestE2E13_MealRating(t *testing.T) {
	a, b, mid := matchedPair(t)
	path := "/api/v1/matches/" + mid + "/rating"
	eve := newUser(t, "E2E Outsider")

	for _, bad := range []map[string]any{{"stars": 0}, {"stars": 6}, {"stars": 3, "note": strings.Repeat("x", 501)}} {
		must(t, http.MethodPost, path, a.token, bad, 400)
	}
	must(t, http.MethodPost, path, eve.token, map[string]any{"stars": 5}, 404)
	must(t, http.MethodGet, path, eve.token, nil, 404)

	type view struct {
		Mine *struct {
			Stars int    `json:"stars"`
			Note  string `json:"note"`
		} `json:"mine"`
		Partner *struct {
			Stars int `json:"stars"`
		} `json:"partner"`
		BothRated bool `json:"both_rated"`
	}

	must(t, http.MethodPost, path, a.token, map[string]any{"stars": 5, "note": "Vui lắm"}, 200)
	var va, vb view
	decode(t, must(t, http.MethodGet, path, a.token, nil, 200), &va)
	decode(t, must(t, http.MethodGet, path, b.token, nil, 200), &vb)
	if va.Mine == nil || va.Mine.Stars != 5 || va.Partner != nil || va.BothRated {
		t.Fatalf("A after rating alone: %+v", va)
	}
	if vb.Mine != nil || vb.Partner != nil {
		t.Fatalf("B must not see A's rating before rating: %+v", vb)
	}

	must(t, http.MethodPost, path, b.token, map[string]any{"stars": 4}, 200)
	must(t, http.MethodPost, path, a.token, map[string]any{"stars": 4, "note": "Sửa lại"}, 200) // re-rate = update
	decode(t, must(t, http.MethodGet, path, b.token, nil, 200), &vb)
	if !vb.BothRated || vb.Mine == nil || vb.Mine.Stars != 4 || vb.Partner == nil || vb.Partner.Stars != 4 {
		t.Fatalf("B after both rated: %+v", vb)
	}
}

// E2E-14 Profile stats: the Me screen's numbers come from real data.
func TestE2E14_ProfileStats(t *testing.T) {
	a, b, mid := matchedPair(t)
	type stats struct {
		Meals   *int `json:"meals"`
		Matches *int `json:"matches"`
	}
	var s stats
	decode(t, must(t, http.MethodGet, "/api/v1/profile/stats", a.token, nil, 200), &s)
	if s.Meals == nil || s.Matches == nil || *s.Meals != 0 || *s.Matches != 1 {
		t.Fatalf("fresh match stats = %+v, want meals 0, matches 1", s)
	}

	when := time.Now().Add(24 * time.Hour).UTC().Format(time.RFC3339)
	must(t, http.MethodPost, "/api/v1/matches/"+mid+"/booking", a.token,
		map[string]any{"restaurant_name": "Bún chả Hương Liên", "scheduled_at": when}, 200, 201)
	must(t, http.MethodPost, "/api/v1/matches/"+mid+"/booking/confirm", b.token, nil, 200)

	decode(t, must(t, http.MethodGet, "/api/v1/profile/stats", b.token, nil, 200), &s)
	if *s.Meals != 1 || *s.Matches != 1 {
		t.Fatalf("after confirmed booking stats = meals %d matches %d, want 1/1", *s.Meals, *s.Matches)
	}
	must(t, http.MethodGet, "/api/v1/profile/stats", "", nil, 401)
}
