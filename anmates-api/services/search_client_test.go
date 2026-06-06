package services

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestWebSearchProviderSuggest(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/suggest" || r.Method != http.MethodPost {
			t.Errorf("unexpected request %s %s", r.Method, r.URL.Path)
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{
			"intro":"hai đứa hợp gu nè",
			"cost_tokens":123,
			"picks":[
				{"name":"Lẩu Nấm","rating":4.6,"price_min":120000,"price_max":180000,"lat":10.78,"lng":106.70,"distance_m":999,"reason":"ngon, hợp gu"},
				{"name":"","reason":"phải bị loại vì rỗng"}
			]
		}`))
	}))
	defer srv.Close()

	p := NewWebSearchProvider(srv.URL)
	mid := LatLng{Lat: 10.77, Lng: 106.70}
	intro, picks, cost, err := p.Suggest(context.Background(), mid, []string{"lẩu"}, 80000, 150000, 4000, 3)
	if err != nil {
		t.Fatal(err)
	}
	if intro != "hai đứa hợp gu nè" {
		t.Errorf("intro = %q", intro)
	}
	if cost != 123 {
		t.Errorf("cost = %d, want 123", cost)
	}
	if len(picks) != 1 {
		t.Fatalf("picks = %d, want 1 (empty-name pick dropped)", len(picks))
	}
	// Distance must be recomputed from the midpoint, not trust the 999 from the body.
	if picks[0].DistanceM == 999 {
		t.Error("distance_m was not recomputed from midpoint")
	}
	if picks[0].Name != "Lẩu Nấm" || picks[0].Reason != "ngon, hợp gu" {
		t.Errorf("pick = %+v", picks[0])
	}
	if picks[0].Rating == nil || *picks[0].Rating != 4.6 {
		t.Errorf("rating not mapped: %+v", picks[0].Rating)
	}
}

func TestWebSearchProviderHTTPError(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusBadGateway)
	}))
	defer srv.Close()

	p := NewWebSearchProvider(srv.URL)
	if _, _, _, err := p.Suggest(context.Background(), LatLng{}, nil, 0, 0, 0, 3); err == nil {
		t.Error("expected error on non-200 response")
	}
}
