package services

import (
	"bytes"
	"context"
	"io"
	"net/http"
	"os"
	"testing"
)

// Temporary live diagnostics — not committed. Run with GOOGLE_PLACES_LIVE=1.

func TestLiveGooglePlacesRaw(t *testing.T) {
	if os.Getenv("GOOGLE_PLACES_LIVE") != "1" {
		t.Skip("set GOOGLE_PLACES_LIVE=1")
	}
	key := os.Getenv("GOOGLE_PLACES_API_KEY")
	if key == "" {
		t.Skip("GOOGLE_PLACES_API_KEY not set")
	}
	body := []byte(`{"includedTypes":["restaurant","cafe"],"maxResultCount":8,"rankPreference":"DISTANCE","locationRestriction":{"circle":{"center":{"latitude":10.7769,"longitude":106.7009},"radius":3000}}}`)
	req, _ := http.NewRequestWithContext(context.Background(), http.MethodPost, placesNearbyURL, bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Goog-Api-Key", key)
	req.Header.Set("X-Goog-FieldMask", nearbyFieldMask)
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("http err: %v", err)
	}
	defer res.Body.Close()
	b, _ := io.ReadAll(res.Body)
	t.Logf("STATUS %d", res.StatusCode)
	if len(b) > 1200 {
		b = b[:1200]
	}
	t.Logf("BODY %s", string(b))
}

func TestLiveGooglePlacesNearby(t *testing.T) {
	if os.Getenv("GOOGLE_PLACES_LIVE") != "1" {
		t.Skip("set GOOGLE_PLACES_LIVE=1")
	}
	key := os.Getenv("GOOGLE_PLACES_API_KEY")
	if key == "" {
		t.Skip("GOOGLE_PLACES_API_KEY not set")
	}
	p := NewGooglePlacesProvider(key, NewOSMNearbyProvider(10000), 3000, 10000, 5)
	// searchOnce bypasses the OSM fallback so a Google failure surfaces directly.
	got, err := p.searchOnce(context.Background(), LatLng{Lat: 10.7769, Lng: 106.7009}, 8, 3000)
	if err != nil {
		t.Fatalf("searchOnce error (no fallback): %v", err)
	}
	for i, v := range got {
		open := "?"
		if v.OpenNow != nil {
			if *v.OpenNow {
				open = "open"
			} else {
				open = "closed"
			}
		}
		rating := "-"
		if v.Rating != nil {
			rating = "★"
		}
		price := "-"
		if v.PriceLevel != nil {
			price = "$"
		}
		t.Logf("%d. %-32s %5dm  %s %s %s  %v", i+1, v.Name, v.DistanceM, rating, price, open, v.Tags)
	}
	if len(got) == 0 {
		t.Fatal("0 venues")
	}
	t.Logf("LIVE GOOGLE OK: %d venues, nearest %q at %dm", len(got), got[0].Name, got[0].DistanceM)
}
