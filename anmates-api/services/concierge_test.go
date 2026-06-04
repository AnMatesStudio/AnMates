package services

import (
	"context"
	"math"
	"testing"

	"github.com/google/uuid"
)

func TestCrossedThreshold(t *testing.T) {
	cases := []struct {
		before, after, thr int
		want               bool
	}{
		{69, 70, 70, true},   // exact crossing
		{60, 90, 70, true},   // jump past
		{70, 71, 70, false},  // already above
		{70, 70, 70, false},  // at threshold but not a crossing
		{50, 69, 70, false},  // below
		{0, 100, 70, true},   // from zero
	}
	for _, c := range cases {
		if got := crossedThreshold(c.before, c.after, c.thr); got != c.want {
			t.Errorf("crossedThreshold(%d,%d,%d)=%v want %v", c.before, c.after, c.thr, got, c.want)
		}
	}
}

func TestHaversineM(t *testing.T) {
	// 1° of latitude ≈ 111.19 km.
	d := HaversineM(LatLng{0, 0}, LatLng{0, 1})
	if math.Abs(d-111195) > 500 {
		t.Errorf("HaversineM 1deg lat = %.0f, want ~111195", d)
	}
	if d0 := HaversineM(LatLng{10.77, 106.70}, LatLng{10.77, 106.70}); d0 != 0 {
		t.Errorf("same point distance = %.4f, want 0", d0)
	}
}

func TestMidpoint(t *testing.T) {
	m := Midpoint(LatLng{10.0, 106.0}, LatLng{10.5, 107.0})
	if m.Lat != 10.25 || m.Lng != 106.5 {
		t.Errorf("Midpoint = %+v, want {10.25 106.5}", m)
	}
}

func TestValidatePicksDropsHallucinations(t *testing.T) {
	r1 := uuid.New()
	r2 := uuid.New()
	rating := 4.5
	candidates := []Candidate{
		{ID: r1, Name: "Quán A", Lat: 10.77, Lng: 106.70, Rating: &rating, DistanceM: 100},
		{ID: r2, Name: "Quán B", Lat: 10.78, Lng: 106.69, DistanceM: 200},
	}
	picks := []Pick{
		{RestaurantID: r1.String(), Reason: "gần"},
		{RestaurantID: uuid.New().String(), Reason: "bịa"}, // hallucinated → dropped
		{RestaurantID: r1.String(), Reason: "trùng"},       // duplicate → dropped
		{RestaurantID: r2.String(), Reason: "hợp gu"},
	}
	out := validatePicks(picks, candidates, 3)
	if len(out) != 2 {
		t.Fatalf("validatePicks len = %d, want 2", len(out))
	}
	if out[0].RestaurantID != r1.String() || out[1].RestaurantID != r2.String() {
		t.Errorf("unexpected ids: %s, %s", out[0].RestaurantID, out[1].RestaurantID)
	}
	// Venue facts must come from the DB candidate, not the model.
	if out[0].Name != "Quán A" || out[0].DistanceM != 100 || out[0].Rating == nil || *out[0].Rating != 4.5 {
		t.Errorf("venue facts not copied from candidate: %+v", out[0])
	}
}

func TestValidatePicksCapsAtMax(t *testing.T) {
	var candidates []Candidate
	var picks []Pick
	for i := 0; i < 6; i++ {
		id := uuid.New()
		candidates = append(candidates, Candidate{ID: id, Name: "Q", DistanceM: i})
		picks = append(picks, Pick{RestaurantID: id.String(), Reason: "x"})
	}
	if got := len(validatePicks(picks, candidates, 3)); got != 3 {
		t.Errorf("cap = %d, want 3", got)
	}
}

func TestFakeLLMReturnsUpToThree(t *testing.T) {
	var candidates []Candidate
	for i := 0; i < 5; i++ {
		candidates = append(candidates, Candidate{ID: uuid.New(), Name: "Q"})
	}
	out, err := FakeLLM{}.Rank(context.Background(), ConciergeInput{Candidates: candidates})
	if err != nil {
		t.Fatal(err)
	}
	if len(out.Picks) != 3 {
		t.Errorf("FakeLLM picks = %d, want 3", len(out.Picks))
	}
	if out.Intro == "" {
		t.Error("FakeLLM intro empty")
	}
}

func TestContainsCJKAndSafeReason(t *testing.T) {
	// Vietnamese with diacritics must NOT be flagged.
	if containsCJK("Yên tĩnh, hợp first date — đông vui, gần điểm giữa") {
		t.Error("Vietnamese text wrongly flagged as CJK")
	}
	// Chinese leakage (the exact failure the 7B model produced) must be caught.
	if !containsCJK("Giá hợp lý, 评分高，距离适中") {
		t.Error("Chinese text not detected")
	}
	// safeReason replaces CJK-tainted reasons with a clean Vietnamese fallback.
	if got := safeReason("评分高"); containsCJK(got) {
		t.Errorf("safeReason leaked CJK: %q", got)
	}
	if got := safeReason(""); got == "" {
		t.Error("safeReason should provide a fallback for empty input")
	}
	if got := safeReason("Yên tĩnh, hợp gu"); got != "Yên tĩnh, hợp gu" {
		t.Errorf("safeReason mangled clean Vietnamese: %q", got)
	}
}

func TestParseConciergeJSON(t *testing.T) {
	// Wrapped in a code fence + prose — should still parse.
	raw := "Đây nhé:\n```json\n{\"intro\":\"hi\",\"picks\":[{\"restaurant_id\":\"x\",\"reason\":\"y\"}]}\n```"
	out, err := parseConciergeJSON(raw)
	if err != nil {
		t.Fatal(err)
	}
	if out.Intro != "hi" || len(out.Picks) != 1 || out.Picks[0].RestaurantID != "x" {
		t.Errorf("parsed = %+v", out)
	}
	if _, err := parseConciergeJSON("not json at all"); err == nil {
		t.Error("expected error for non-json")
	}
}
