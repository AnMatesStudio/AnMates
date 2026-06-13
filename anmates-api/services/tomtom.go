package services

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"
)

// TomTomClient fetches nearby food POIs from the TomTom Search API. TomTom keeps
// fresher Vietnam POI data than community-maintained OSM/Overpass, so it powers
// the Discovery "nearby" list when a key is configured. The client degrades to a
// zero value (Enabled()==false) when no key is set, letting callers fall back.
type TomTomClient struct {
	apiKey string
	client *http.Client
}

const (
	tomtomTimeout    = 8 * time.Second
	tomtomMaxResults = 100 // TomTom nearbySearch hard cap is 100
	// Restaurant (7315) + Café/Pub (9376) category branches — keeps the list to
	// eat/drink venues, matching the Overpass amenity filter we replace.
	tomtomFoodCategories = "7315,9376"
)

func NewTomTomClient(apiKey string) *TomTomClient {
	return &TomTomClient{
		apiKey: strings.TrimSpace(apiKey),
		client: &http.Client{Timeout: tomtomTimeout},
	}
}

func (t *TomTomClient) Enabled() bool { return t != nil && t.apiKey != "" }
func (t *TomTomClient) Name() string  { return "tomtom" }

// NearbyVenue and the NearbyProvider interface live in nearby.go (shared across
// the TomTom and Goong providers).

// tomtomDateTime / tomtomTimeRange model TomTom's openingHours payload (with
// openingHours=nextSevenDays each entry is one concrete open period).
type tomtomDateTime struct {
	Date   string `json:"date"` // "2006-01-02"
	Hour   int    `json:"hour"`
	Minute int    `json:"minute"`
}

type tomtomTimeRange struct {
	StartTime tomtomDateTime `json:"startTime"`
	EndTime   tomtomDateTime `json:"endTime"`
}

// tomtomResponse models the subset of the TomTom nearbySearch payload we read.
type tomtomResponse struct {
	Results []struct {
		ID   string  `json:"id"`
		Dist float64 `json:"dist"`
		Poi  struct {
			Name        string   `json:"name"`
			Phone       string   `json:"phone"`
			Categories  []string `json:"categories"`
			Classifications []struct {
				Code string `json:"code"`
			} `json:"classifications"`
			OpeningHours struct {
				TimeRanges []tomtomTimeRange `json:"timeRanges"`
			} `json:"openingHours"`
		} `json:"poi"`
		Address struct {
			FreeformAddress string `json:"freeformAddress"`
			StreetName      string `json:"streetName"`
			StreetNumber    string `json:"streetNumber"`
		} `json:"address"`
		Position struct {
			Lat float64 `json:"lat"`
			Lon float64 `json:"lon"`
		} `json:"position"`
	} `json:"results"`
}

// Nearby returns up to `limit` food venues within radiusM metres of (lat,lng),
// ordered by distance (TomTom returns nearest-first). The keywords arg is part of
// the NearbyProvider contract but TomTom ignores it — it queries by POI category.
func (t *TomTomClient) Nearby(ctx context.Context, lat, lng float64, radiusM, limit int, _ []string) ([]NearbyVenue, error) {
	if !t.Enabled() {
		return nil, fmt.Errorf("tomtom disabled")
	}
	if limit <= 0 || limit > tomtomMaxResults {
		limit = tomtomMaxResults
	}

	q := url.Values{
		"key":         {t.apiKey},
		"lat":         {strconv.FormatFloat(lat, 'f', 6, 64)},
		"lon":         {strconv.FormatFloat(lng, 'f', 6, 64)},
		"radius":      {strconv.Itoa(radiusM)},
		"limit":       {strconv.Itoa(limit)},
		"categorySet": {tomtomFoodCategories},
		// Ask TomTom for the next 7 days of hours so we can backfill the open/closed
		// badge for venues OSM hasn't tagged with opening_hours.
		"openingHours": {"nextSevenDays"},
		"language":     {"vi-VN"},
	}
	endpoint := "https://api.tomtom.com/search/2/nearbySearch/.json?" + q.Encode()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, http.NoBody)
	if err != nil {
		return nil, err
	}
	resp, err := t.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close() //nolint:errcheck // response body close; error unrecoverable
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("tomtom status %d", resp.StatusCode)
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, 4<<20))
	if err != nil {
		return nil, err
	}

	var raw tomtomResponse
	if err := json.Unmarshal(body, &raw); err != nil {
		return nil, err
	}

	out := make([]NearbyVenue, 0, len(raw.Results))
	for _, r := range raw.Results {
		name := strings.TrimSpace(r.Poi.Name)
		if name == "" {
			continue
		}
		addr := strings.TrimSpace(r.Address.FreeformAddress)
		if addr == "" {
			addr = strings.TrimSpace(strings.TrimSpace(r.Address.StreetNumber + " " + r.Address.StreetName))
		}
		out = append(out, NearbyVenue{
			ID:        "tt_" + r.ID,
			Name:      name,
			Lat:       r.Position.Lat,
			Lng:       r.Position.Lon,
			Amenity:   tomtomAmenity(r.Poi.Classifications),
			Cuisine:   tomtomCuisine(r.Poi.Categories),
			Address:      addr,
			Phone:        strings.TrimSpace(r.Poi.Phone),
			OpeningHours: tomtomHoursToOSM(r.Poi.OpeningHours.TimeRanges),
			DistanceM:    int(r.Dist + 0.5),
		})
	}
	return out, nil
}

// tomtomHoursToOSM converts TomTom's next-seven-days time ranges into an OSM-style
// opening_hours string (e.g. "Mo 09:00-22:00; Sa 09:00-23:00") — the exact format
// the Flutter OpenNowBadge already parses, so this backfills the badge with no UI
// change. A range crossing midnight (bars) becomes a wrap like "21:00-04:00".
// Returns "" when TomTom supplied no hours, keeping the UI honest (no badge) rather
// than inventing a schedule.
func tomtomHoursToOSM(ranges []tomtomTimeRange) string {
	if len(ranges) == 0 {
		return ""
	}
	abbr := map[time.Weekday]string{
		time.Monday: "Mo", time.Tuesday: "Tu", time.Wednesday: "We", time.Thursday: "Th",
		time.Friday: "Fr", time.Saturday: "Sa", time.Sunday: "Su",
	}
	spansByDay := map[time.Weekday][]string{}
	seen := map[string]bool{}
	for _, r := range ranges {
		d, err := time.Parse("2006-01-02", r.StartTime.Date)
		if err != nil {
			continue
		}
		span := fmt.Sprintf("%02d:%02d-%02d:%02d",
			r.StartTime.Hour, r.StartTime.Minute, r.EndTime.Hour, r.EndTime.Minute)
		key := abbr[d.Weekday()] + "|" + span
		if seen[key] {
			continue // same weekday can recur across the 7-day window
		}
		seen[key] = true
		spansByDay[d.Weekday()] = append(spansByDay[d.Weekday()], span)
	}
	order := []time.Weekday{
		time.Monday, time.Tuesday, time.Wednesday, time.Thursday,
		time.Friday, time.Saturday, time.Sunday,
	}
	rules := make([]string, 0, len(order))
	for _, wd := range order {
		if spans := spansByDay[wd]; len(spans) > 0 {
			rules = append(rules, abbr[wd]+" "+strings.Join(spans, ","))
		}
	}
	return strings.Join(rules, "; ")
}

// tomtomAmenity maps TomTom POI classification codes to the OSM amenity values
// the Flutter model already understands (restaurant/cafe/fast_food/bar).
func tomtomAmenity(cls []struct {
	Code string `json:"code"`
}) string {
	for _, c := range cls {
		code := strings.ToUpper(c.Code)
		switch {
		case strings.Contains(code, "FAST_FOOD"):
			return "fast_food"
		case strings.Contains(code, "CAFE"), strings.Contains(code, "COFFEE"):
			return "cafe"
		case strings.Contains(code, "PUB"), strings.Contains(code, "BAR"), strings.Contains(code, "NIGHTLIFE"):
			return "bar"
		case strings.Contains(code, "RESTAURANT"):
			return "restaurant"
		}
	}
	return "restaurant"
}

// tomtomCuisine surfaces a human cuisine/category hint from TomTom categories.
func tomtomCuisine(cats []string) string {
	for _, c := range cats {
		c = strings.TrimSpace(c)
		// Skip the generic umbrella labels; prefer a specific cuisine if present.
		if c == "" || strings.EqualFold(c, "restaurant") || strings.EqualFold(c, "cafe/pub") {
			continue
		}
		return c
	}
	if len(cats) > 0 {
		return strings.TrimSpace(cats[0])
	}
	return ""
}
