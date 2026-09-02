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

// VenueEnricher calls the ai-venue-search sidecar's /enrich endpoint, which drives
// a headless Google crawl + LLM verification and returns photos that are genuinely
// of THIS food venue (plus extracted facts). It is the realtime, agentic source
// behind the detail-screen hero — deliberately NOT cached here, so each open re-
// crawls the live web (the user asked for fresh, not stale, images).
//
// When the sidecar is unconfigured or the crawl is blocked, the result is empty
// and the caller degrades to the keyless Bing path (ImageSearcher).
type VenueEnricher struct {
	baseURL string
	hc      *http.Client
}

func NewVenueEnricher(baseURL string) *VenueEnricher {
	return &VenueEnricher{
		baseURL: strings.TrimRight(baseURL, "/"),
		// Headless Chromium + page fetches + an LLM verdict is slow; give it room.
		hc: &http.Client{Timeout: 80 * time.Second},
	}
}

// Enabled reports whether an enrichment sidecar URL is configured.
func (e *VenueEnricher) Enabled() bool { return e.baseURL != "" }

type enrichReq struct {
	Name      string  `json:"name"`
	Address   string  `json:"address,omitempty"`
	City      string  `json:"city,omitempty"`
	Lat       float64 `json:"lat,omitempty"`
	Lng       float64 `json:"lng,omitempty"`
	MaxImages int     `json:"max_images,omitempty"`
}

// EnrichedImage is one verified venue photo. URL is the direct remote image (the
// image proxy re-fetches its bytes); Source/Caption are debug/relevance context.
type EnrichedImage struct {
	URL     string `json:"url"`
	Source  string `json:"source"`
	Caption string `json:"caption"`
}

// EnrichedInfo holds the facts the agent extracted from the crawled pages. Every
// field is optional — only what the web actually stated is filled.
type EnrichedInfo struct {
	Cuisine      string   `json:"cuisine"`
	Address      string   `json:"address"`
	Description  string   `json:"description"`
	OpeningHours string   `json:"opening_hours"`
	Phone        string   `json:"phone"`
	Rating       *float64 `json:"rating"`
	PriceMin     *int     `json:"price_min"`
	PriceMax     *int     `json:"price_max"`
}

// EnrichResult mirrors the sidecar's EnrichResponse. IsFoodVenue=false (or empty
// Images) means the crawl found nothing genuinely this eatery → caller falls back.
type EnrichResult struct {
	Images      []EnrichedImage `json:"images"`
	Info        EnrichedInfo    `json:"info"`
	IsFoodVenue bool            `json:"is_food_venue"`
	Intro       string          `json:"intro"`
	Provider    string          `json:"provider"`
}

// Enrich asks the sidecar to crawl the live web for one venue. Returns an error
// only on transport/protocol failure; a "found nothing" outcome is a valid
// (empty) result, not an error.
func (e *VenueEnricher) Enrich(ctx context.Context, name, address, city string, lat, lng float64, maxImages int) (*EnrichResult, error) {
	if !e.Enabled() {
		return &EnrichResult{}, nil
	}
	if maxImages <= 0 {
		maxImages = 6
	}
	body, _ := json.Marshal(enrichReq{
		Name: name, Address: address, City: city, Lat: lat, Lng: lng, MaxImages: maxImages,
	})

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, e.baseURL+"/enrich", bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := e.hc.Do(req)
	if err != nil {
		return nil, err
	}
	defer func() { _ = resp.Body.Close() }()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("ai-venue-search /enrich http %d", resp.StatusCode)
	}

	var out EnrichResult
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return nil, err
	}
	return &out, nil
}
