package services

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// FoursquareClient matches a venue (by name + coordinates) against Foursquare's
// free Places **search** tier to recover the venue's OWN official website — a
// high-confidence "chính chủ" photo source (we crawl that site's og:image).
//
// Why not Foursquare photos directly? The new Places API gates `/photos` behind
// paid credits ("no API credits remaining"); search + the `website` field are on
// the free tier. So we use Foursquare for IDENTITY (which real place is this, by
// GPS distance + name) and its website link, then fetch the photo from the venue's
// own domain. Degrades to a zero value (Enabled()==false) with no key.
type FoursquareClient struct {
	apiKey  string
	baseURL string
	version string
	client  *http.Client
}

const (
	fsqBaseURL = "https://places-api.foursquare.com"
	fsqVersion = "2025-06-17"
	fsqTimeout = 6 * time.Second
	// A matched place must be within this radius of the Goong coordinates AND
	// share a name token — otherwise it's a different venue that merely sits
	// nearby, and using its website would be a wrong-identity photo.
	fsqMatchMaxMeters = 250
	fsqReadCap        = 1 << 20
)

// FoursquareMatch is a confident venue match with its official web presence.
type FoursquareMatch struct {
	FsqID      string
	Name       string
	Website    string
	DistanceM  int
	FacebookID string
}

func NewFoursquareClient(apiKey string) *FoursquareClient {
	return &FoursquareClient{
		apiKey:  strings.TrimSpace(apiKey),
		baseURL: fsqBaseURL,
		version: fsqVersion,
		client:  &http.Client{Timeout: fsqTimeout},
	}
}

func (f *FoursquareClient) Enabled() bool { return f != nil && f.apiKey != "" }

// Match returns the best Foursquare venue for (query, lat, lng) — the nearest
// result that shares a distinctive name token and sits within the match radius —
// or nil when nothing matches confidently. Never fabricates: a weak/far match is
// dropped so we never attribute a wrong venue's website.
func (f *FoursquareClient) Match(ctx context.Context, query string, lat, lng float64) (*FoursquareMatch, error) {
	if !f.Enabled() {
		return nil, nil
	}
	query = strings.TrimSpace(query)
	if query == "" || (lat == 0 && lng == 0) {
		return nil, nil
	}

	q := url.Values{
		"query":  {query},
		"ll":     {fmt.Sprintf("%f,%f", lat, lng)},
		"radius": {"400"},
		"limit":  {"6"},
		"fields": {"fsq_place_id,name,distance,location,website,social_media"},
	}
	results, err := f.search(ctx, q)
	if err != nil {
		return nil, err
	}

	wantTokens := significantTokens(query)
	var best *FoursquareMatch
	for i := range results {
		r := &results[i]
		if r.Distance > fsqMatchMaxMeters {
			continue
		}
		// Require a shared distinctive token (identity guard), unless the place is
		// almost exactly on the pin (≤40m) where co-location is strong evidence.
		if !shareToken(wantTokens, significantTokens(r.Name)) && r.Distance > 40 {
			continue
		}
		website := strings.TrimSpace(r.Website)
		fb := ""
		if r.SocialMedia != nil {
			fb = strings.TrimSpace(r.SocialMedia.FacebookID)
		}
		// Keep the nearest qualifying match.
		if best == nil || r.Distance < best.DistanceM {
			best = &FoursquareMatch{
				FsqID:      r.FsqID,
				Name:       r.Name,
				Website:    website,
				DistanceM:  r.Distance,
				FacebookID: fb,
			}
		}
	}
	return best, nil
}

func (f *FoursquareClient) search(ctx context.Context, q url.Values) ([]fsqResult, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, f.baseURL+"/places/search?"+q.Encode(), http.NoBody)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+f.apiKey)
	req.Header.Set("X-Places-Api-Version", f.version)
	req.Header.Set("Accept", "application/json")

	resp, err := f.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close() //nolint:errcheck // response body close; error unrecoverable
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("foursquare status %d", resp.StatusCode)
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, fsqReadCap))
	if err != nil {
		return nil, err
	}
	var raw struct {
		Results []fsqResult `json:"results"`
	}
	if err := json.Unmarshal(body, &raw); err != nil {
		return nil, err
	}
	return raw.Results, nil
}

type fsqResult struct {
	FsqID       string          `json:"fsq_place_id"`
	Name        string          `json:"name"`
	Distance    int             `json:"distance"`
	Website     string          `json:"website"`
	SocialMedia *fsqSocialMedia `json:"social_media"`
}

type fsqSocialMedia struct {
	FacebookID string `json:"facebook_id"`
	Instagram  string `json:"instagram"`
}

// shareToken reports whether the two token sets overlap on any distinctive token.
func shareToken(a, b []string) bool {
	if len(a) == 0 || len(b) == 0 {
		return false
	}
	set := make(map[string]bool, len(a))
	for _, t := range a {
		set[t] = true
	}
	for _, t := range b {
		if set[t] {
			return true
		}
	}
	return false
}
