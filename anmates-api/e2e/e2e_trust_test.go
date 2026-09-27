package e2e

// Round 4 (launch blockers): legal consent + 18+ at sign-up, email verification
// gate, auto-suspension after reports, and the admin report queue.
//
// Some steps need direct DB access (E2E_DATABASE_URL, e.g. the api's DATABASE_URL
// on the compose network): to plant a known OTP hash (codes are emailed, never
// returned) and to make a test user an admin. Those tests skip without it.

import (
	"context"
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"net/http"
	"os"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

func db(t *testing.T) *pgxpool.Pool {
	t.Helper()
	url := os.Getenv("E2E_DATABASE_URL")
	if url == "" {
		t.Skip("E2E_DATABASE_URL not set")
	}
	p, err := pgxpool.New(context.Background(), url)
	if err != nil {
		t.Fatalf("db: %v", err)
	}
	t.Cleanup(p.Close)
	return p
}

func adultDOB() string { return time.Now().AddDate(-25, 0, 0).Format("2006-01-02") }

type emailUser struct {
	user
	email string
}

func register(t *testing.T, name string) emailUser {
	t.Helper()
	email := fmt.Sprintf("e2e+%d@anmates.test", time.Now().UnixNano()+seq.Add(1))
	env := must(t, http.MethodPost, "/api/v1/auth/register", "", map[string]any{
		"email": email, "password": "supersecret-123", "name": name,
		"birth_date": adultDOB(), "accept_terms": true,
	}, 201)
	var r struct {
		AccessToken string `json:"access_token"`
		User        struct {
			ID string `json:"id"`
		} `json:"user"`
	}
	decode(t, env, &r)
	return emailUser{user{token: r.AccessToken, id: r.User.ID, name: name}, email}
}

type acctStatus struct {
	EmailVerified bool `json:"email_verified"`
	Suspended     bool `json:"suspended"`
	IsAdmin       bool `json:"is_admin"`
	TermsAccepted bool `json:"terms_accepted"`
}

func status(t *testing.T, u user) acctStatus {
	t.Helper()
	var s acctStatus
	decode(t, must(t, http.MethodGet, "/api/v1/account/status", u.token, nil, 200), &s)
	return s
}

// verifyEmail runs the real flow: request a code, plant a known one in its place, confirm it.
func verifyEmail(t *testing.T, pool *pgxpool.Pool, u emailUser) {
	t.Helper()
	must(t, http.MethodPost, "/api/v1/account/verify-email/request", u.token, nil, 200)
	sum := sha256.Sum256([]byte("424242"))
	if _, err := pool.Exec(context.Background(), `
		UPDATE email_otps SET code_hash = $2
		WHERE id = (SELECT id FROM email_otps WHERE email = $1 ORDER BY created_at DESC LIMIT 1)`,
		u.email, base64.StdEncoding.EncodeToString(sum[:])); err != nil {
		t.Fatalf("plant otp: %v", err)
	}
	must(t, http.MethodPost, "/api/v1/account/verify-email", u.token, map[string]any{"code": "000000"}, 401)
	must(t, http.MethodPost, "/api/v1/account/verify-email", u.token, map[string]any{"code": "424242"}, 200)
}

// E2E-22: sign-up needs accepted terms and an adult birth date.
func TestE2E22_SignupConsentAndAge(t *testing.T) {
	base := func() map[string]any {
		return map[string]any{
			"email": fmt.Sprintf("e2e+%d@anmates.test", time.Now().UnixNano()), "password": "supersecret-123",
			"name": "E2E Signup", "birth_date": adultDOB(), "accept_terms": true,
		}
	}
	for name, mutate := range map[string]func(m map[string]any){
		"no terms":       func(m map[string]any) { delete(m, "accept_terms") },
		"terms false":    func(m map[string]any) { m["accept_terms"] = false },
		"no birth date":  func(m map[string]any) { delete(m, "birth_date") },
		"bad birth date": func(m map[string]any) { m["birth_date"] = "27/09/2000" },
		"17 years old":   func(m map[string]any) { m["birth_date"] = time.Now().AddDate(-17, 0, 0).Format("2006-01-02") },
	} {
		m := base()
		mutate(m)
		if status, _ := do(t, http.MethodPost, "/api/v1/auth/register", "", m); status != 400 {
			t.Fatalf("%s → %d, want 400", name, status)
		}
	}
	u := register(t, "E2E Adult")
	s := status(t, u.user)
	if !s.TermsAccepted || s.EmailVerified || s.Suspended || s.IsAdmin {
		t.Fatalf("fresh email account status = %+v", s)
	}
	must(t, http.MethodGet, "/api/v1/account/status", "", nil, 401)
}

// E2E-23: an unverified email account can't swipe or see decks/locals until it verifies.
func TestE2E23_EmailVerificationGate(t *testing.T) {
	pool := db(t)
	u := register(t, "E2E Unverified")
	other := newUser(t, "E2E Target")
	for _, r := range [][2]string{{"GET", "/api/v1/matches"}, {"GET", "/api/v1/locals"}} {
		env := must(t, r[0], r[1], u.token, nil, 403)
		if env.code() != "EMAIL_UNVERIFIED" {
			t.Fatalf("%s code = %q", r[1], env.code())
		}
	}
	must(t, http.MethodPost, "/api/v1/swipes", u.token, map[string]any{"target_id": other.id, "liked": true}, 403)
	must(t, http.MethodGet, "/api/v1/profile", u.token, nil, 200) // the rest of the app still works

	verifyEmail(t, pool, u)
	if !status(t, u.user).EmailVerified {
		t.Fatalf("still unverified after the correct code")
	}
	must(t, http.MethodGet, "/api/v1/matches", u.token, nil, 200)
	must(t, http.MethodPost, "/api/v1/swipes", u.token, map[string]any{"target_id": other.id, "liked": true}, 200)
	// Phone/dev accounts are never gated.
	must(t, http.MethodGet, "/api/v1/matches", other.token, nil, 200)
}

// E2E-24: unverified accounts are invisible in other people's decks until they verify.
func TestE2E24_UnverifiedHiddenFromDecks(t *testing.T) {
	pool := db(t)
	tag := fmt.Sprintf("e2e-ver-%d", time.Now().UnixNano())
	u := register(t, "E2E Hidden")
	viewer := newUser(t, "E2E Viewer")
	onboard(t, u.user, tag)
	onboard(t, viewer, tag)
	inDeck := func() bool { return candidateIDs(t, viewer)[u.id] }
	if inDeck() {
		t.Fatalf("unverified account visible in a deck")
	}
	verifyEmail(t, pool, u)
	if !inDeck() {
		t.Fatalf("verified account (same unique tastes) missing from the deck")
	}
}

// E2E-25: three different reporters within 30 days suspend an account automatically.
func TestE2E25_AutoSuspend(t *testing.T) {
	tag := fmt.Sprintf("e2e-sus-%d", time.Now().UnixNano())
	x, viewer := newUser(t, "E2E Reported X"), newUser(t, "E2E Viewer2")
	onboard(t, x, tag)
	onboard(t, viewer, tag)
	if !candidateIDs(t, viewer)[x.id] {
		t.Fatalf("precondition: X should be in viewer's deck")
	}
	for i := 0; i < 3; i++ {
		r := newUser(t, fmt.Sprintf("E2E Reporter %d", i))
		must(t, http.MethodPost, "/api/v1/reports", r.token, map[string]any{"user_id": x.id, "reason": "harassment"}, 201)
		if i == 1 && status(t, x).Suspended {
			t.Fatalf("suspended after only 2 reporters")
		}
	}
	env := must(t, http.MethodGet, "/api/v1/matches", x.token, nil, 403)
	if env.code() != "ACCOUNT_SUSPENDED" {
		t.Fatalf("suspended code = %q", env.code())
	}
	if !status(t, x).Suspended {
		t.Fatalf("status not suspended")
	}
	if candidateIDs(t, viewer)[x.id] {
		t.Fatalf("suspended account still in a deck")
	}
}

// E2E-26: admins see open reports and can dismiss / suspend / unsuspend; others get 403.
func TestE2E26_AdminReportQueue(t *testing.T) {
	pool := db(t)
	admin, a, b := newUser(t, "E2E Admin"), newUser(t, "E2E Rep A"), newUser(t, "E2E Rep B")
	must(t, http.MethodGet, "/api/v1/admin/reports", a.token, nil, 403)
	if _, err := pool.Exec(context.Background(), `UPDATE users SET is_admin = TRUE WHERE id = $1`, admin.id); err != nil {
		t.Fatalf("make admin: %v", err)
	}
	if !status(t, admin).IsAdmin {
		t.Fatalf("status.is_admin false for admin")
	}
	var r1, r2 struct {
		ID string `json:"id"`
	}
	decode(t, must(t, http.MethodPost, "/api/v1/reports", a.token, map[string]any{"user_id": b.id, "reason": "spam", "note": "quảng cáo"}, 201), &r1)
	decode(t, must(t, http.MethodPost, "/api/v1/reports", b.token, map[string]any{"user_id": a.id, "reason": "fake_profile"}, 201), &r2)

	var list []struct {
		ID           string `json:"id"`
		ReportedID   string `json:"reported_id"`
		ReportedName string `json:"reported_name"`
		ReporterName string `json:"reporter_name"`
		Reason       string `json:"reason"`
		Note         string `json:"note"`
		Status       string `json:"status"`
	}
	decode(t, must(t, http.MethodGet, "/api/v1/admin/reports?status=open", admin.token, nil, 200), &list)
	found := 0
	for _, r := range list {
		if r.ID == r1.ID && r.ReportedName == "E2E Rep B" && r.ReporterName == "E2E Rep A" && r.Note == "quảng cáo" && r.Status == "open" {
			found++
		}
		if r.ID == r2.ID {
			found++
		}
	}
	if found != 2 {
		t.Fatalf("admin queue missing the two new reports (found %d of %d rows)", found, len(list))
	}
	must(t, http.MethodPost, "/api/v1/admin/reports/"+r1.ID+"/resolve", admin.token, map[string]any{"action": "bogus"}, 400)
	must(t, http.MethodPost, "/api/v1/admin/reports/"+r1.ID+"/resolve", admin.token, map[string]any{"action": "dismiss"}, 200)
	must(t, http.MethodPost, "/api/v1/admin/reports/"+r2.ID+"/resolve", admin.token, map[string]any{"action": "suspend"}, 200)
	if !status(t, a).Suspended || status(t, b).Suspended {
		t.Fatalf("suspend action hit the wrong account")
	}
	decode(t, must(t, http.MethodGet, "/api/v1/admin/reports?status=open", admin.token, nil, 200), &list)
	for _, r := range list {
		if r.ID == r1.ID || r.ID == r2.ID {
			t.Fatalf("resolved report still open: %+v", r)
		}
	}
	must(t, http.MethodPost, "/api/v1/admin/users/"+a.id+"/unsuspend", admin.token, nil, 200)
	if status(t, a).Suspended {
		t.Fatalf("unsuspend did not lift the suspension")
	}
	must(t, http.MethodPost, "/api/v1/admin/users/"+a.id+"/unsuspend", b.token, nil, 403)
}
