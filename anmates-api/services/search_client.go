package services

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"
)

// WebSearchProvider is the preferred concierge data source. It delegates venue
// discovery to the ai-venue-search Python service (which runs an MCP web-search
// + structuring), so the Go backend needs no map API and no `restaurants` table.
//
// Anti-hallucination note: unlike the DB path, venue facts here come from the
// web search, not a local DB — we trust the service's structured output. We still
// clean the model-authored reason text (CJK guard + length clip) and recompute
// distance from the midpoint so the card's distance is always consistent.
type WebSearchProvider struct {
	baseURL string
	hc      *http.Client
}

func NewWebSearchProvider(baseURL string) *WebSearchProvider {
	return &WebSearchProvider{
		baseURL: strings.TrimRight(baseURL, "/"),
		// Generous: the sidecar chains web-search + page-fetch + LLM + geocoding.
		hc: &http.Client{Timeout: 70 * time.Second},
	}
}

type searchReq struct {
	Lat       float64  `json:"lat"`
	Lng       float64  `json:"lng"`
	RadiusM   int      `json:"radius_m"`
	BudgetMin int      `json:"budget_min"`
	BudgetMax int      `json:"budget_max"`
	MoodTags  []string `json:"mood_tags"`
	Limit     int      `json:"limit"`
	Query     string   `json:"query,omitempty"`
}

type searchVenue struct {
	Name      string   `json:"name"`
	Address   string   `json:"address"`
	Rating    *float64 `json:"rating"`
	PriceMin  *int     `json:"price_min"`
	PriceMax  *int     `json:"price_max"`
	Lat       float64  `json:"lat"`
	Lng       float64  `json:"lng"`
	DistanceM int      `json:"distance_m"`
	Reason    string   `json:"reason"`
}

type searchResp struct {
	Intro      string        `json:"intro"`
	Picks      []searchVenue `json:"picks"`
	CostTokens int           `json:"cost_tokens"`
}

func (p *WebSearchProvider) Suggest(ctx context.Context, mid LatLng, mood []string, budgetMin, budgetMax, radiusM, limit int) (intro string, picks []CardPick, costTokens int, err error) {
	// The sidecar's mood_tags is List[str] (no null allowed) — send [] not null
	// when the matched users have no taste tags yet.
	if mood == nil {
		mood = []string{}
	}
	body, _ := json.Marshal(searchReq{
		Lat: mid.Lat, Lng: mid.Lng, RadiusM: radiusM,
		BudgetMin: budgetMin, BudgetMax: budgetMax, MoodTags: mood, Limit: limit,
	})

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, p.baseURL+"/suggest", bytes.NewReader(body))
	if err != nil {
		return "", nil, 0, err
	}
	httpReq.Header.Set("Content-Type", "application/json")

	resp, err := p.hc.Do(httpReq)
	if err != nil {
		return "", nil, 0, err
	}
	defer func() {
		_ = resp.Body.Close()
	}()
	if resp.StatusCode != http.StatusOK {
		return "", nil, 0, fmt.Errorf("ai-venue-search http %d", resp.StatusCode)
	}

	var parsed searchResp
	if err := json.NewDecoder(resp.Body).Decode(&parsed); err != nil {
		return "", nil, 0, err
	}

	return parsed.Intro, mapPicks(parsed, mid), parsed.CostTokens, nil
}

// mapPicks converts a raw sidecar response into CardPick slices, recomputing
// distance from origin when coordinates are present.
func mapPicks(parsed searchResp, origin LatLng) []CardPick {
	picks := make([]CardPick, 0, len(parsed.Picks))
	for _, v := range parsed.Picks {
		if strings.TrimSpace(v.Name) == "" {
			continue
		}
		// Recompute distance from origin when we have coordinates, so the
		// card's distance label never depends on the search service's own math.
		dist := v.DistanceM
		if v.Lat != 0 || v.Lng != 0 {
			dist = int(HaversineM(origin, LatLng{Lat: v.Lat, Lng: v.Lng}))
		}
		picks = append(picks, CardPick{
			Name:      clip(v.Name, 80),
			Address:   clip(v.Address, 160),
			Rating:    v.Rating,
			PriceMin:  v.PriceMin,
			PriceMax:  v.PriceMax,
			Lat:       v.Lat,
			Lng:       v.Lng,
			DistanceM: dist,
			Reason:    safeReason(v.Reason),
		})
	}
	return picks
}

// SearchText performs a free-text venue search via the sidecar's /search endpoint.
// Used by the Discovery feature; lat/lng may be 0 when the user has no location.
func (p *WebSearchProvider) SearchText(ctx context.Context, query string, loc LatLng, radiusM, limit int) ([]CardPick, error) {
	body, _ := json.Marshal(searchReq{
		Query:    query,
		Lat:      loc.Lat,
		Lng:      loc.Lng,
		RadiusM:  radiusM,
		MoodTags: []string{},
		Limit:    limit,
	})

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, p.baseURL+"/search", bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	httpReq.Header.Set("Content-Type", "application/json")

	resp, err := p.hc.Do(httpReq)
	if err != nil {
		return nil, err
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("ai-venue-search /search http %d", resp.StatusCode)
	}

	var parsed searchResp
	if err := json.NewDecoder(resp.Body).Decode(&parsed); err != nil {
		return nil, err
	}
	return mapPicks(parsed, loc), nil
}
