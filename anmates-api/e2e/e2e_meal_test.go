package e2e

// Round 6 (picked from docs/research/feature-shortlist.md): anti no-show + icebreakers.
//   E2E-30  booking reminders 24 h and 2 h before a confirmed meal, once each, to both people
//           (needs the API's BOOKING_REMINDER_INTERVAL short, e.g. 3s, and E2E_DATABASE_URL to move the clock).
//   E2E-31  "on my way / running late / arrived" status: only for a confirmed booking near its time; tells the partner.
//   E2E-32  icebreakers built from the food both people like; members only; generic when nothing is shared.

import (
	"context"
	"fmt"
	"net/http"
	"strings"
	"testing"
	"time"
)

func kinds(t *testing.T, u user, mid string) map[string]int {
	t.Helper()
	ns, _ := notifications(t, u)
	out := map[string]int{}
	for _, n := range ns {
		if n.MatchID == mid {
			out[n.Kind]++
		}
	}
	return out
}

func waitKind(t *testing.T, u user, mid, kind string, within time.Duration) bool {
	t.Helper()
	deadline := time.Now().Add(within)
	for time.Now().Before(deadline) {
		if kinds(t, u, mid)[kind] > 0 {
			return true
		}
		time.Sleep(500 * time.Millisecond)
	}
	return false
}

// E2E-30: reminders fire once each for both members; an early confirmation (<20 h before) skips the 24 h one.
func TestE2E30_BookingReminders(t *testing.T) {
	pool := db(t)
	a, b, mid := matchedPair(t)
	bookAndConfirm(t, a, b, mid, "Phở Thìn Lò Đúc") // scheduled +30 h
	ctx := context.Background()
	// Move the meal to 23 h from now, confirmed "yesterday" (so the 24 h reminder is due).
	if _, err := pool.Exec(ctx, `UPDATE bookings SET scheduled_at = now() + interval '23 hours',
		updated_at = now() - interval '1 day' WHERE match_id = $1`, mid); err != nil {
		t.Fatal(err)
	}
	if !waitKind(t, a, mid, "booking_reminder_24h", 20*time.Second) || !waitKind(t, b, mid, "booking_reminder_24h", 5*time.Second) {
		t.Fatalf("24 h reminder not sent to both: A=%v B=%v", kinds(t, a, mid), kinds(t, b, mid))
	}
	if kinds(t, a, mid)["booking_reminder_2h"] != 0 {
		t.Fatalf("2 h reminder sent 23 h early")
	}
	// Now 90 minutes away → the 2 h reminder; the 24 h one must not repeat.
	pool.Exec(ctx, `UPDATE bookings SET scheduled_at = now() + interval '90 minutes' WHERE match_id = $1`, mid)
	if !waitKind(t, b, mid, "booking_reminder_2h", 20*time.Second) {
		t.Fatalf("2 h reminder not sent: %v", kinds(t, b, mid))
	}
	time.Sleep(8 * time.Second) // a few more ticks
	if k := kinds(t, a, mid); k["booking_reminder_24h"] != 1 || k["booking_reminder_2h"] != 1 {
		t.Fatalf("reminders must be sent exactly once each: %v", k)
	}

	// A booking confirmed only 10 h before the meal gets no "tomorrow" reminder.
	c, d, mid2 := matchedPair(t)
	bookAndConfirm(t, c, d, mid2, "Bún chả")
	pool.Exec(ctx, `UPDATE bookings SET scheduled_at = now() + interval '10 hours' WHERE match_id = $1`, mid2)
	time.Sleep(10 * time.Second)
	if kinds(t, c, mid2)["booking_reminder_24h"] != 0 {
		t.Fatalf("24 h reminder sent for a booking confirmed 10 h before")
	}
}

type mealStatus struct {
	Mine    *string `json:"mine"`
	Partner *string `json:"partner"`
}

// E2E-31: meal-day status updates.
func TestE2E31_MealStatus(t *testing.T) {
	pool := db(t)
	a, b, mid := matchedPair(t)
	path := "/api/v1/matches/" + mid + "/booking/status"
	must(t, http.MethodPost, path, a.token, map[string]any{"status": "on_my_way"}, 409) // no booking yet
	bookAndConfirm(t, a, b, mid, "Lẩu Phan")
	must(t, http.MethodPost, path, a.token, map[string]any{"status": "on_my_way"}, 409) // 30 h away: too early
	pool.Exec(context.Background(), `UPDATE bookings SET scheduled_at = now() + interval '40 minutes' WHERE match_id = $1`, mid)

	must(t, http.MethodPost, path, a.token, map[string]any{"status": "bogus"}, 400)
	eve := newUser(t, "E2E Outsider")
	must(t, http.MethodPost, path, eve.token, map[string]any{"status": "on_my_way"}, 404)

	must(t, http.MethodPost, path, a.token, map[string]any{"status": "running_late_10"}, 200)
	if !waitKind(t, b, mid, "running_late_10", 5*time.Second) {
		t.Fatalf("partner not told A is running late: %v", kinds(t, b, mid))
	}
	var s mealStatus
	decode(t, must(t, http.MethodGet, path, b.token, nil, 200), &s)
	if s.Partner == nil || *s.Partner != "running_late_10" || s.Mine != nil {
		t.Fatalf("B's view = %+v", s)
	}
	must(t, http.MethodPost, path, a.token, map[string]any{"status": "arrived"}, 200) // latest wins
	decode(t, must(t, http.MethodGet, path, a.token, nil, 200), &s)
	if s.Mine == nil || *s.Mine != "arrived" {
		t.Fatalf("A's view = %+v", s)
	}
	for _, n := range func() []notif { ns, _ := notifications(t, b); return ns }() {
		if n.Kind == "arrived" && n.ActorName != a.name {
			t.Fatalf("arrived actor = %q", n.ActorName)
		}
	}
	// Too late: two hours after the meal it's over.
	pool.Exec(context.Background(), `UPDATE bookings SET scheduled_at = now() - interval '3 hours' WHERE match_id = $1`, mid)
	must(t, http.MethodPost, path, b.token, map[string]any{"status": "on_my_way"}, 409)
}

// E2E-32: icebreakers use the foods both people like.
func TestE2E32_Icebreakers(t *testing.T) {
	a, b, mid := matchedPair(t) // both have "Phở Thìn" + "Cơm tấm Ba Ghiền" (pho, com) in their wishlists
	var r struct {
		Prompts []struct {
			VI string `json:"vi"`
			EN string `json:"en"`
		} `json:"prompts"`
		Shared []string `json:"shared"`
	}
	decode(t, must(t, http.MethodGet, "/api/v1/matches/"+mid+"/icebreakers", a.token, nil, 200), &r)
	if len(r.Prompts) != 3 || len(r.Shared) == 0 {
		t.Fatalf("icebreakers = %+v", r)
	}
	mentions := 0
	for _, p := range r.Prompts {
		if p.VI == "" || p.EN == "" {
			t.Fatalf("prompt missing a language: %+v", p)
		}
		low := strings.ToLower(p.VI)
		if strings.Contains(low, "phở") || strings.Contains(low, "cơm tấm") {
			mentions++
		}
		if strings.Contains(p.VI, "{") {
			t.Fatalf("unfilled template: %q", p.VI)
		}
	}
	if mentions == 0 {
		t.Fatalf("no prompt mentions a shared food: %+v", r.Prompts)
	}
	// Both members see the same prompts (deterministic per match).
	var r2 struct {
		Prompts []struct {
			VI string `json:"vi"`
		} `json:"prompts"`
	}
	decode(t, must(t, http.MethodGet, "/api/v1/matches/"+mid+"/icebreakers", b.token, nil, 200), &r2)
	if len(r2.Prompts) != 3 || r2.Prompts[0].VI != r.Prompts[0].VI {
		t.Fatalf("members see different prompts")
	}
	eve := newUser(t, "E2E Outsider")
	must(t, http.MethodGet, "/api/v1/matches/"+mid+"/icebreakers", eve.token, nil, 404)
	must(t, http.MethodGet, "/api/v1/matches/not-a-uuid/icebreakers", a.token, nil, 400)

	// No shared food (a pair matched through the DB-free path: two fresh users liking each other) → generic prompts.
	c, d := newUser(t, "E2E No Food C"), newUser(t, "E2E No Food D")
	must(t, http.MethodPost, "/api/v1/swipes", c.token, map[string]any{"target_id": d.id, "liked": true}, 200)
	env := must(t, http.MethodPost, "/api/v1/swipes", d.token, map[string]any{"target_id": c.id, "liked": true}, 200)
	var sw struct {
		Match struct {
			ID string `json:"id"`
		} `json:"match"`
	}
	decode(t, env, &sw)
	decode(t, must(t, http.MethodGet, fmt.Sprintf("/api/v1/matches/%s/icebreakers", sw.Match.ID), c.token, nil, 200), &r)
	if len(r.Prompts) != 3 || len(r.Shared) != 0 {
		t.Fatalf("no-overlap icebreakers = %+v", r)
	}
}
