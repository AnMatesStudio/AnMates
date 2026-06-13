package services

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestParseGoongAutocomplete(t *testing.T) {
	body := `{"predictions":[
		{"place_id":"p1","description":"Quán A, 1 Lê Lợi","structured_formatting":{"main_text":"Quán A","secondary_text":"1 Lê Lợi, Q1"}},
		{"place_id":"p2","structured_formatting":{"main_text":"Quán B","secondary_text":"2 Lê Lợi"}}
	],"status":"OK"}`
	preds, err := parseGoongAutocomplete([]byte(body))
	if err != nil {
		t.Fatalf("parseGoongAutocomplete error: %v", err)
	}
	if len(preds) != 2 {
		t.Fatalf("got %d predictions, want 2", len(preds))
	}
	if preds[0].PlaceID != "p1" || preds[0].MainText != "Quán A" || preds[0].SecondaryText != "1 Lê Lợi, Q1" {
		t.Errorf("prediction[0] = %+v", preds[0])
	}
	if preds[1].PlaceID != "p2" || preds[1].MainText != "Quán B" {
		t.Errorf("prediction[1] = %+v", preds[1])
	}
}

func TestParseGoongDetail(t *testing.T) {
	// V2 detail adds a `types` array (and compound/plus_code we ignore).
	body := `{"result":{"place_id":"p1","name":"Quán A","formatted_address":"1 Lê Lợi, Phường Bến Nghé, Quận 1","geometry":{"location":{"lat":10.7769,"lng":106.7009}},"types":["restaurant","food"]},"status":"OK"}`
	d, err := parseGoongDetail([]byte(body))
	if err != nil {
		t.Fatalf("parseGoongDetail error: %v", err)
	}
	if d.Name != "Quán A" {
		t.Errorf("Name = %q, want %q", d.Name, "Quán A")
	}
	if d.FormattedAddress != "1 Lê Lợi, Phường Bến Nghé, Quận 1" {
		t.Errorf("FormattedAddress = %q", d.FormattedAddress)
	}
	if d.Lat != 10.7769 || d.Lng != 106.7009 {
		t.Errorf("coords = (%v,%v), want (10.7769,106.7009)", d.Lat, d.Lng)
	}
	if len(d.Types) != 2 || d.Types[0] != "restaurant" {
		t.Errorf("Types = %v, want [restaurant food]", d.Types)
	}
}

func TestGoongAmenityFromTypes(t *testing.T) {
	cases := []struct {
		types []string
		want  string
	}{
		{[]string{"restaurant"}, "restaurant"},
		{[]string{"cafe"}, "cafe"},
		{[]string{"bar"}, "bar"},
		{[]string{"night_club"}, "bar"},
		{[]string{"meal_takeaway"}, "fast_food"},
		{[]string{"food", "point_of_interest"}, "restaurant"},
		{[]string{"lodging"}, ""}, // not food → empty → caller falls back to keyword
		{nil, ""},
	}
	for _, c := range cases {
		if got := goongAmenityFromTypes(c.types); got != c.want {
			t.Errorf("goongAmenityFromTypes(%v) = %q, want %q", c.types, got, c.want)
		}
	}
}

func TestGoongAmenityForKeyword(t *testing.T) {
	cases := map[string]string{
		"quán cà phê": "cafe",
		"cà phê":      "cafe",
		"quán nhậu":   "bar",
		"bar":         "bar",
		"nhà hàng":    "restaurant",
		"lẩu nướng":   "restaurant",
		"quán ăn":     "restaurant",
	}
	for kw, want := range cases {
		if got := goongAmenityForKeyword(kw); got != want {
			t.Errorf("goongAmenityForKeyword(%q) = %q, want %q", kw, got, want)
		}
	}
}

// TestGoongNearby drives the full autocomplete→detail flow against a stub Goong
// V2 server: it must use the passed keywords, dedup a place returned twice, derive
// amenity from the V2 `types` (overriding the keyword) and fall back to the keyword
// when types are absent, return ALL venues regardless of distance, and sort
// nearest-first.
func TestGoongNearby(t *testing.T) {
	mux := http.NewServeMux()
	mux.HandleFunc("/v2/place/autocomplete", func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Query().Get("input") {
		case "nhà hàng":
			// p1 (near) + p2 (far) + p3 (nearest) — p3 surfaced by a "restaurant"
			// keyword but its V2 types say cafe (proves types precedence).
			_, _ = w.Write([]byte(`{"predictions":[
				{"place_id":"p1","structured_formatting":{"main_text":"Nhà Hàng P1"}},
				{"place_id":"p2","structured_formatting":{"main_text":"Nhà Hàng Xa"}},
				{"place_id":"p3","structured_formatting":{"main_text":"Quán P3"}}
			],"status":"OK"}`))
		case "quán cà phê":
			// p3 again (dup → must be ignored, already seen)
			_, _ = w.Write([]byte(`{"predictions":[
				{"place_id":"p3","structured_formatting":{"main_text":"Quán P3"}}
			],"status":"OK"}`))
		default:
			_, _ = w.Write([]byte(`{"predictions":[],"status":"OK"}`))
		}
	})
	mux.HandleFunc("/v2/place/detail", func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Query().Get("place_id") {
		case "p1": // ~111 m, types restaurant
			_, _ = w.Write([]byte(`{"result":{"place_id":"p1","name":"Nhà Hàng P1","formatted_address":"1 Lê Lợi, Quận 1","geometry":{"location":{"lat":10.7779,"lng":106.7009}},"types":["restaurant"]},"status":"OK"}`))
		case "p2": // ~13.7 km away, NO types → falls back to keyword (nhà hàng→restaurant)
			_, _ = w.Write([]byte(`{"result":{"place_id":"p2","name":"Nhà Hàng Xa","formatted_address":"Xa","geometry":{"location":{"lat":10.9000,"lng":106.7009}}},"status":"OK"}`))
		case "p3": // ~15 m (nearest), types cafe — overrides the "nhà hàng" keyword
			_, _ = w.Write([]byte(`{"result":{"place_id":"p3","name":"Quán P3","formatted_address":"3 Lê Lợi, Quận 1","geometry":{"location":{"lat":10.7770,"lng":106.7010}},"types":["cafe"]},"status":"OK"}`))
		default:
			http.Error(w, "not found", http.StatusNotFound)
		}
	})
	srv := httptest.NewServer(mux)
	defer srv.Close()

	g := NewGoongClient("testkey")
	g.baseURL = srv.URL
	g.ttl = 0 // disable cache for a deterministic test

	// Pass keywords explicitly (the personalized path) — overrides g.keywords.
	venues, err := g.Nearby(context.Background(), 10.7769, 106.7009, 5000, 60,
		[]string{"nhà hàng", "quán cà phê"})
	if err != nil {
		t.Fatalf("Nearby error: %v", err)
	}
	// ALL venues returned regardless of distance (no radius filter): p3, p1, p2.
	if len(venues) != 3 {
		t.Fatalf("got %d venues, want 3 (p3 + p1 + p2; deduped, no distance filter)", len(venues))
	}
	// Sorted nearest-first: p3 (~15m), p1 (~111m), p2 (~13.7km).
	if venues[0].ID != "goong_p3" || venues[0].Amenity != "cafe" {
		t.Errorf("venues[0] = %+v, want goong_p3 / cafe (from V2 types, overriding keyword)", venues[0])
	}
	if venues[1].ID != "goong_p1" || venues[1].Amenity != "restaurant" {
		t.Errorf("venues[1] = %+v, want goong_p1 / restaurant", venues[1])
	}
	if venues[1].Address != "1 Lê Lợi, Quận 1" {
		t.Errorf("venues[1].Address = %q", venues[1].Address)
	}
	// The far venue (p2, ~13.7km) is included (no distance filter) and sorts last;
	// it has no types so amenity falls back to the keyword (restaurant).
	if venues[2].ID != "goong_p2" || venues[2].Amenity != "restaurant" {
		t.Errorf("venues[2] = %+v, want goong_p2 / restaurant (keyword fallback)", venues[2])
	}
	if venues[0].DistanceM >= venues[1].DistanceM || venues[1].DistanceM >= venues[2].DistanceM {
		t.Errorf("not sorted nearest-first: %d, %d, %d", venues[0].DistanceM, venues[1].DistanceM, venues[2].DistanceM)
	}
}
