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

func (p *WebSearchProvider) Suggest(ctx context.Context, mid LatLng, mood []string, budgetMin, budgetMax, radiusM, limit int) (string, []cardPick, int, error) {
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
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return "", nil, 0, fmt.Errorf("ai-venue-search http %d", resp.StatusCode)
	}

	var parsed searchResp
	if err := json.NewDecoder(resp.Body).Decode(&parsed); err != nil {
		return "", nil, 0, err
	}

	picks := make([]cardPick, 0, len(parsed.Picks))
	for _, v := range parsed.Picks {
		if strings.TrimSpace(v.Name) == "" {
			continue
		}
		// Recompute distance from the midpoint when we have coordinates, so the
		// card's distance label never depends on the search service's own math.
		dist := v.DistanceM
		if v.Lat != 0 || v.Lng != 0 {
			dist = int(HaversineM(mid, LatLng{Lat: v.Lat, Lng: v.Lng}))
		}
		picks = append(picks, cardPick{
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
	return parsed.Intro, picks, parsed.CostTokens, nil
}
