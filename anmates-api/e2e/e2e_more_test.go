package e2e

// Round 3 journeys: onboarding reaches the deck, match preferences, account
// deletion, in-app notifications, Trust Score, meal history and Local Mates.

import (
	"fmt"
	"net/http"
	"testing"
	"time"
)

// onboard marks u as onboarded the way the app does after sign-up, so u can
// appear in other people's swipe decks.
// extra tags let a test pair rank above every other onboarded test user.
func onboard(t *testing.T, u user, extra ...string) {
	t.Helper()
	must(t, http.MethodPatch, "/api/v1/profile/preferences", u.token, map[string]any{
		"food_tags": append([]string{"lẩu", "hải sản"}, extra...), "vibe_tags": []string{},
	}, 200)
}

func bookAndConfirm(t *testing.T, proposer, confirmer user, mid, venue string) {
	t.Helper()
	when := time.Now().Add(30 * time.Hour).UTC().Format(time.RFC3339)
	must(t, http.MethodPost, "/api/v1/matches/"+mid+"/booking", proposer.token,
		map[string]any{"restaurant_name": venue, "scheduled_at": when}, 200, 201)
	must(t, http.MethodPost, "/api/v1/matches/"+mid+"/booking/confirm", confirmer.token, nil, 200)
}

func setLocation(t *testing.T, u user, lat, lng float64, district string) {
	t.Helper()
	must(t, http.MethodPut, "/api/v1/me/location", u.token,
		map[string]any{"lat": lat, "lng": lng, "district": district}, 200)
}

// E2E-15: a user onboarded through PATCH /profile/preferences shows up in a
// matching user's deck, with the district and price tier the filters need.
func TestE2E15_OnboardedUserReachesDeckWithPrefs(t *testing.T) {
	a, b := newUser(t, "E2E Deck A"), newUser(t, "E2E Deck B")
	tag := fmt.Sprintf("e2e-%d", time.Now().UnixNano())
	onboard(t, a, tag)
	onboard(t, b, tag)
	setLocation(t, b, 10.7769, 106.7009, "Quận 1")

	must(t, http.MethodPatch, "/api/v1/profile/match-prefs", b.token,
		map[string]any{"vibe_tags": []string{"quiet", "deal"}, "price_tier": 1}, 200)
	for _, bad := range []map[string]any{
		{"vibe_tags": []string{"bogus"}},
		{"vibe_tags": []string{"quiet", "deal", "lively", "long_sit"}}, // max 3
		{"vibe_tags": []string{}, "price_tier": 4},
	} {
		must(t, http.MethodPatch, "/api/v1/profile/match-prefs", b.token, bad, 400)
	}
	var p struct {
		VibeTags  []string `json:"vibe_tags"`
		PriceTier *int     `json:"price_tier"`
	}
	decode(t, must(t, http.MethodGet, "/api/v1/profile/match-prefs", b.token, nil, 200), &p)
	if len(p.VibeTags) != 2 || p.PriceTier == nil || *p.PriceTier != 1 {
		t.Fatalf("match-prefs = %+v", p)
	}
	// Clearing the price tier is allowed (null = no preference).
	must(t, http.MethodPatch, "/api/v1/profile/match-prefs", b.token,
		map[string]any{"vibe_tags": []string{"quiet"}, "price_tier": nil}, 200)
	must(t, http.MethodPatch, "/api/v1/profile/match-prefs", b.token,
		map[string]any{"vibe_tags": []string{"quiet", "deal"}, "price_tier": 1}, 200)

	env := must(t, http.MethodGet, "/api/v1/matches", a.token, nil, 200)
	var cs []struct {
		UserID    string   `json:"user_id"`
		District  *string  `json:"district"`
		PriceTier *int     `json:"price_tier"`
		VibeTags  []string `json:"vibe_tags"`
	}
	decode(t, env, &cs)
	for _, c := range cs {
		if c.UserID == b.id {
			if c.District == nil || *c.District != "Quận 1" || c.PriceTier == nil || *c.PriceTier != 1 {
				t.Fatalf("candidate B fields = district %v price %v", c.District, c.PriceTier)
			}
			return
		}
	}
	t.Fatalf("onboarded B (2 shared foods) missing from A's deck of %d", len(cs))
}

// E2E-16: deleting the account removes the user and everything tied to them.
func TestE2E16_DeleteAccount(t *testing.T) {
	a, b, mid := matchedPair(t)
	must(t, http.MethodDelete, "/api/v1/profile", "", nil, 401)
	must(t, http.MethodDelete, "/api/v1/profile", a.token, nil, 200)
	status, _ := do(t, http.MethodGet, "/api/v1/profile", a.token, nil)
	if status != 401 && status != 404 {
		t.Fatalf("profile of deleted account → %d, want 401/404", status)
	}
	if conversationIDs(t, b)[mid] {
		t.Fatalf("partner still sees the deleted user's conversation")
	}
}

type notif struct {
	Kind      string `json:"kind"`
	MatchID   string `json:"match_id"`
	ActorName string `json:"actor_name"`
	Read      bool   `json:"read"`
}

func notifications(t *testing.T, u user) ([]notif, int) {
	t.Helper()
	var n struct {
		Items  []notif `json:"items"`
		Unread *int    `json:"unread"`
	}
	decode(t, must(t, http.MethodGet, "/api/v1/notifications", u.token, nil, 200), &n)
	if n.Unread == nil {
		t.Fatalf("notifications: no unread count")
	}
	return n.Items, *n.Unread
}

func hasKind(ns []notif, kind, mid string) bool {
	for _, n := range ns {
		if n.Kind == kind && n.MatchID == mid {
			return true
		}
	}
	return false
}

// E2E-17: match, booking and rating events land in the right inbox.
func TestE2E17_Notifications(t *testing.T) {
	a, b, mid := matchedPair(t)
	na, _ := notifications(t, a)
	nb, _ := notifications(t, b)
	if !hasKind(na, "match", mid) || !hasKind(nb, "match", mid) {
		t.Fatalf("match notification missing: A=%+v B=%+v", na, nb)
	}

	bookAndConfirm(t, a, b, mid, "Lẩu Phan")
	nb, _ = notifications(t, b)
	na, _ = notifications(t, a)
	if !hasKind(nb, "booking_proposed", mid) {
		t.Fatalf("B not told about the proposal: %+v", nb)
	}
	if !hasKind(na, "booking_confirmed", mid) {
		t.Fatalf("A not told about the confirmation: %+v", na)
	}
	if hasKind(na, "booking_proposed", mid) {
		t.Fatalf("proposer notified of their own proposal")
	}

	must(t, http.MethodPost, "/api/v1/matches/"+mid+"/rating", b.token, map[string]any{"stars": 5}, 200)
	na, unread := notifications(t, a)
	if !hasKind(na, "rating", mid) || unread < 3 {
		t.Fatalf("A after rating: unread %d items %+v", unread, na)
	}
	for _, n := range na {
		if n.Kind == "rating" && n.ActorName != b.name {
			t.Fatalf("rating actor_name = %q, want %q", n.ActorName, b.name)
		}
	}

	decode(t, must(t, http.MethodPost, "/api/v1/notifications/read", a.token, nil, 200), &struct{}{})
	if _, unread = notifications(t, a); unread != 0 {
		t.Fatalf("unread after mark-all-read = %d", unread)
	}
	must(t, http.MethodGet, "/api/v1/notifications", "", nil, 401)
}

type trust struct {
	Score         *int `json:"score"`
	Meals         int  `json:"meals"`
	GoodRatings   int  `json:"good_ratings"`
	NoShowReports int  `json:"no_show_reports"`
	OtherReports  int  `json:"other_reports"`
}

func trustOf(t *testing.T, u user) trust {
	t.Helper()
	var tr trust
	decode(t, must(t, http.MethodGet, "/api/v1/profile/trust", u.token, nil, 200), &tr)
	if tr.Score == nil {
		t.Fatalf("trust: no score")
	}
	return tr
}

// E2E-18 Trust Score = clamp(80 + 4·meals + 2·good ratings − 20·no-show reporters − 10·other reporters, 0, 100).
func TestE2E18_TrustScore(t *testing.T) {
	a, b, mid := matchedPair(t)
	if s := *trustOf(t, a).Score; s != 80 {
		t.Fatalf("fresh score %d, want 80", s)
	}
	bookAndConfirm(t, b, a, mid, "Cơm tấm Ba Ghiền")
	if s := *trustOf(t, a).Score; s != 84 {
		t.Fatalf("after 1 meal %d, want 84", s)
	}
	must(t, http.MethodPost, "/api/v1/matches/"+mid+"/rating", b.token, map[string]any{"stars": 5}, 200)
	if s := *trustOf(t, a).Score; s != 86 {
		t.Fatalf("after a 5★ rating %d, want 86", s)
	}
	c, d := newUser(t, "E2E Reporter C"), newUser(t, "E2E Reporter D")
	must(t, http.MethodPost, "/api/v1/reports", c.token, map[string]any{"user_id": a.id, "reason": "no_show"}, 201)
	must(t, http.MethodPost, "/api/v1/reports", c.token, map[string]any{"user_id": a.id, "reason": "no_show"}, 201) // same reporter twice
	must(t, http.MethodPost, "/api/v1/reports", d.token, map[string]any{"user_id": a.id, "reason": "harassment"}, 201)
	tr := trustOf(t, a)
	if *tr.Score != 56 || tr.Meals != 1 || tr.GoodRatings != 1 || tr.NoShowReports != 1 || tr.OtherReports != 1 {
		t.Fatalf("after reports %+v (score %d), want 56 / 1 / 1 / 1 / 1", tr, *tr.Score)
	}
	// B's own ratings of others and A's reports never move B's score the wrong way.
	if s := *trustOf(t, b).Score; s != 84 {
		t.Fatalf("B score %d, want 84 (1 meal, no 4★ received)", s)
	}
}

// E2E-19: "Quán bạn đã đi" + "Review của bạn" come from real bookings and ratings.
func TestE2E19_History(t *testing.T) {
	a, b, mid := matchedPair(t)
	var h struct {
		Visits []struct {
			RestaurantName string `json:"restaurant_name"`
			PartnerName    string `json:"partner_name"`
		} `json:"visits"`
		Reviews []struct {
			Stars          int    `json:"stars"`
			Note           string `json:"note"`
			RestaurantName string `json:"restaurant_name"`
		} `json:"reviews"`
	}
	decode(t, must(t, http.MethodGet, "/api/v1/profile/history", a.token, nil, 200), &h)
	if len(h.Visits) != 0 || len(h.Reviews) != 0 {
		t.Fatalf("fresh history not empty: %+v", h)
	}
	bookAndConfirm(t, a, b, mid, "Bún chả Hương Liên")
	must(t, http.MethodPost, "/api/v1/matches/"+mid+"/rating", a.token,
		map[string]any{"stars": 5, "note": "Đúng giờ, Dễ nói chuyện"}, 200)
	decode(t, must(t, http.MethodGet, "/api/v1/profile/history", a.token, nil, 200), &h)
	if len(h.Visits) != 1 || h.Visits[0].RestaurantName != "Bún chả Hương Liên" || h.Visits[0].PartnerName != b.name {
		t.Fatalf("visits = %+v", h.Visits)
	}
	if len(h.Reviews) != 1 || h.Reviews[0].Stars != 5 || h.Reviews[0].Note != "Đúng giờ, Dễ nói chuyện" ||
		h.Reviews[0].RestaurantName != "Bún chả Hương Liên" {
		t.Fatalf("reviews = %+v", h.Reviews)
	}
}

// E2E-20 Local Mates: nearby (≤5 km) people with ≥1 real meal, nearest-experienced first.
func TestE2E20_LocalMates(t *testing.T) {
	me := newUser(t, "E2E Local Me")
	var none []map[string]any
	decode(t, must(t, http.MethodGet, "/api/v1/locals", me.token, nil, 200), &none)
	if len(none) != 0 {
		t.Fatalf("no location yet → want [], got %d", len(none))
	}
	// A random spot per run (grid of ~1 km cells) so earlier runs' users are never within 5 km.
	n := time.Now().UnixNano()
	base := [2]float64{-60 + float64(n%12000)/100, -170 + float64((n/12000)%34000)/100}
	setLocation(t, me, base[0], base[1], "E2E Town")

	l1, l2, mid := matchedPair(t) // both near, 1 meal each
	bookAndConfirm(t, l1, l2, mid, "Phở gần nhà")
	setLocation(t, l1, base[0]+0.01, base[1], "E2E Town") // ~1.1 km
	setLocation(t, l2, base[0]+0.03, base[1], "E2E Town") // ~3.3 km
	far, farB, fmid := matchedPair(t)
	bookAndConfirm(t, far, farB, fmid, "Quán xa")
	setLocation(t, far, base[0]+0.2, base[1], "Far") // ~22 km
	noMeal := newUser(t, "E2E No Meal")
	setLocation(t, noMeal, base[0]+0.005, base[1], "E2E Town")

	var ls []struct {
		UserID     string  `json:"user_id"`
		Name       string  `json:"name"`
		Meals      int     `json:"meals"`
		DistanceKm float64 `json:"distance_km"`
	}
	decode(t, must(t, http.MethodGet, "/api/v1/locals", me.token, nil, 200), &ls)
	got := map[string]bool{}
	for _, l := range ls {
		got[l.UserID] = true
	}
	if !got[l1.id] || !got[l2.id] || got[far.id] || got[noMeal.id] || got[me.id] {
		t.Fatalf("locals = %+v", ls)
	}
	if ls[0].UserID != l1.id || ls[0].DistanceKm < 0.8 || ls[0].DistanceKm > 1.5 || ls[0].Meals != 1 {
		t.Fatalf("first local = %+v, want l1 at ~1.1 km with 1 meal", ls[0])
	}

	must(t, http.MethodPost, "/api/v1/blocks", me.token, map[string]any{"user_id": l1.id}, 201)
	decode(t, must(t, http.MethodGet, "/api/v1/locals", me.token, nil, 200), &ls)
	for _, l := range ls {
		if l.UserID == l1.id {
			t.Fatalf("blocked user still listed as a local")
		}
	}
}

// E2E-21: each deck candidate carries distance_km from the viewer's saved location
// (null when either side has none), so the app's 0–200 km radius filter can use it.
func TestE2E21_CandidateDistance(t *testing.T) {
	a, b, c := newUser(t, "E2E Dist A"), newUser(t, "E2E Dist B"), newUser(t, "E2E Dist C")
	tag := fmt.Sprintf("e2e-dist-%d", time.Now().UnixNano())
	for _, u := range []user{a, b, c} {
		onboard(t, u, tag)
	}
	n := time.Now().UnixNano()
	lat, lng := -60+float64(n%12000)/100, -170+float64((n/12000)%34000)/100
	setLocation(t, a, lat, lng, "E2E")
	setLocation(t, b, lat+0.09, lng, "E2E") // ~10 km north; C has no location

	var cs []struct {
		UserID     string   `json:"user_id"`
		DistanceKm *float64 `json:"distance_km"`
	}
	decode(t, must(t, http.MethodGet, "/api/v1/matches", a.token, nil, 200), &cs)
	seen := 0
	for _, x := range cs {
		switch x.UserID {
		case b.id:
			seen++
			if x.DistanceKm == nil || *x.DistanceKm < 9.5 || *x.DistanceKm > 10.5 {
				t.Fatalf("B distance_km = %v, want ~10", x.DistanceKm)
			}
		case c.id:
			seen++
			if x.DistanceKm != nil {
				t.Fatalf("C has no location, distance_km = %v, want null", *x.DistanceKm)
			}
		}
	}
	if seen != 2 {
		t.Fatalf("B and C (same unique tastes) not both in A's deck: saw %d of %d", seen, len(cs))
	}
}
