package services

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

// stubFallback records whether the fallback was used.
type stubFallback struct{ called bool }

func (s *stubFallback) Nearby(ctx context.Context, loc LatLng, limit int) ([]NearbyVenue, error) {
	s.called = true
	return []NearbyVenue{{Name: "OSM Fallback", Lat: 10.77, Lng: 106.70, DistanceM: 1}}, nil
}

func newTestServer(t *testing.T, places []map[string]any) *httptest.Server {
	t.Helper()
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("X-Goog-Api-Key") == "" {
			t.Errorf("missing X-Goog-Api-Key header")
		}
		if r.Header.Get("X-Goog-FieldMask") == "" {
			t.Errorf("missing X-Goog-FieldMask header")
		}
		_ = json.NewEncoder(w).Encode(map[string]any{"places": places})
	}))
}

func TestGooglePlacesNearby_ParsesAndSorts(t *testing.T) {
	srv := newTestServer(t, []map[string]any{
		{
			"displayName":         map[string]any{"text": "Quán Xa"},
			"location":            map[string]any{"latitude": 10.80, "longitude": 106.70},
			"formattedAddress":    "123 Far St",
			"rating":              4.2,
			"priceLevel":          "PRICE_LEVEL_MODERATE",
			"currentOpeningHours": map[string]any{"openNow": true},
			"types":               []string{"restaurant", "korean_restaurant"},
		},
		{
			"displayName": map[string]any{"text": "Quán Gần"},
			"location":    map[string]any{"latitude": 10.7701, "longitude": 106.7001},
			"types":       []string{"cafe"},
		},
	})
	defer srv.Close()

	p := NewGooglePlacesProvider("KEY", &stubFallback{}, 3000, 10000, 5)
	p.baseURL = srv.URL

	got, err := p.Nearby(context.Background(), LatLng{Lat: 10.77, Lng: 106.70}, 8)
	if err != nil {
		t.Fatalf("Nearby err: %v", err)
	}
	if len(got) != 2 {
		t.Fatalf("want 2 venues, got %d", len(got))
	}
	if got[0].Name != "Quán Gần" {
		t.Errorf("want nearest first 'Quán Gần', got %q", got[0].Name)
	}
	if got[1].PriceLevel == nil || *got[1].PriceLevel != 2 {
		t.Errorf("want priceLevel 2 for moderate, got %v", got[1].PriceLevel)
	}
	if got[1].OpenNow == nil || !*got[1].OpenNow {
		t.Errorf("want openNow true")
	}
}

func TestGooglePlacesNearby_BudgetExhaustedFallsBack(t *testing.T) {
	srv := newTestServer(t, nil)
	defer srv.Close()

	fb := &stubFallback{}
	p := NewGooglePlacesProvider("KEY", fb, 3000, 10000, 5)
	p.baseURL = srv.URL
	p.budget.count = p.budget.limit // force over budget

	got, err := p.Nearby(context.Background(), LatLng{Lat: 10.77, Lng: 106.70}, 8)
	if err != nil {
		t.Fatalf("unexpected err: %v", err)
	}
	if !fb.called {
		t.Errorf("expected fallback to be used when budget exhausted")
	}
	if len(got) != 1 || got[0].Name != "OSM Fallback" {
		t.Errorf("want fallback result, got %v", got)
	}
}
