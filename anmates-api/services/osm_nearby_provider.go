package services

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// OSMNearbyProvider queries OpenStreetMap Overpass for nearby eateries.
// Free, keyless — the fallback when Google Places is unavailable or over budget.
type OSMNearbyProvider struct {
	client  *http.Client
	radiusM int
}

func NewOSMNearbyProvider(radiusM int) *OSMNearbyProvider {
	return &OSMNearbyProvider{client: &http.Client{Timeout: 20 * time.Second}, radiusM: radiusM}
}

type overpassResp struct {
	Elements []struct {
		Type   string  `json:"type"`
		Lat    float64 `json:"lat"`
		Lon    float64 `json:"lon"`
		Center *struct {
			Lat float64 `json:"lat"`
			Lon float64 `json:"lon"`
		} `json:"center"`
		Tags map[string]string `json:"tags"`
	} `json:"elements"`
}

func (p *OSMNearbyProvider) Nearby(ctx context.Context, loc LatLng, limit int) ([]NearbyVenue, error) {
	q := fmt.Sprintf(`[out:json][timeout:20];
(
  node["amenity"~"restaurant|cafe|fast_food|bar"]["name"](around:%d,%f,%f);
  way["amenity"~"restaurant|cafe|fast_food|bar"]["name"](around:%d,%f,%f);
);
out center 100;`, p.radiusM, loc.Lat, loc.Lng, p.radiusM, loc.Lat, loc.Lng)

	body := "data=" + url.QueryEscape(q)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost,
		"https://overpass-api.de/api/interpreter", strings.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	// Overpass returns 406 to the default Go user-agent; identify the app.
	req.Header.Set("User-Agent", "AnMatesApp/1.0 (discovery nearby)")

	res, err := p.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("overpass http %d", res.StatusCode)
	}

	var or overpassResp
	if err := json.NewDecoder(res.Body).Decode(&or); err != nil {
		return nil, err
	}

	out := make([]NearbyVenue, 0, len(or.Elements))
	for _, e := range or.Elements {
		lat, lng := e.Lat, e.Lon
		if e.Center != nil {
			lat, lng = e.Center.Lat, e.Center.Lon
		}
		name := e.Tags["name:vi"]
		if name == "" {
			name = e.Tags["name"]
		}
		if name == "" || (lat == 0 && lng == 0) {
			continue
		}
		v := NearbyVenue{
			Name:      name,
			Lat:       lat,
			Lng:       lng,
			DistanceM: int(HaversineM(loc, LatLng{Lat: lat, Lng: lng})),
			Address:   strings.TrimSpace(e.Tags["addr:housenumber"] + " " + e.Tags["addr:street"]),
		}
		if c := e.Tags["cuisine"]; c != "" {
			v.Tags = []string{strings.ToLower(strings.SplitN(c, ";", 2)[0])}
		} else if a := e.Tags["amenity"]; a != "" {
			v.Tags = []string{a}
		}
		out = append(out, v)
	}

	sortNearbyByDistance(out)
	if limit > 0 && len(out) > limit {
		out = out[:limit]
	}
	return out, nil
}
