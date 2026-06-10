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

const placesNearbyURL = "https://places.googleapis.com/v1/places:searchNearby"

// nearbyFieldMask keeps the request at the Places "Pro" SKU (no Atmosphere/Enterprise
// fields) to control cost. See spec §7.
const nearbyFieldMask = "places.id,places.displayName,places.location," +
	"places.formattedAddress,places.rating,places.priceLevel," +
	"places.currentOpeningHours.openNow,places.types,places.photos.name"

var priceLevelMap = map[string]int{
	"PRICE_LEVEL_FREE":           0,
	"PRICE_LEVEL_INEXPENSIVE":    1,
	"PRICE_LEVEL_MODERATE":       2,
	"PRICE_LEVEL_EXPENSIVE":      3,
	"PRICE_LEVEL_VERY_EXPENSIVE": 4,
}

// GooglePlacesProvider queries Google Places API (New) searchNearby, expanding the
// radius once if too few results, with a daily call budget and an OSM fallback.
type GooglePlacesProvider struct {
	apiKey     string
	baseURL    string
	client     *http.Client
	fallback   NearbyProvider
	budget     *dailyBudget
	radiusM    int
	maxRadiusM int
	minResults int
}

func NewGooglePlacesProvider(apiKey string, fallback NearbyProvider, radiusM, maxRadiusM, minResults int) *GooglePlacesProvider {
	return &GooglePlacesProvider{
		apiKey:     apiKey,
		baseURL:    placesNearbyURL,
		client:     &http.Client{Timeout: 15 * time.Second},
		fallback:   fallback,
		budget:     newDailyBudget(2400), // default; override via WithDailyBudget
		radiusM:    radiusM,
		maxRadiusM: maxRadiusM,
		minResults: minResults,
	}
}

// WithDailyBudget overrides the default daily Places-call cap.
func (p *GooglePlacesProvider) WithDailyBudget(limit int) *GooglePlacesProvider {
	p.budget = newDailyBudget(limit)
	return p
}

// Nearby tries Google first (with radius expansion), falling back to OSM on any
// error or when the daily budget is exhausted.
func (p *GooglePlacesProvider) Nearby(ctx context.Context, loc LatLng, limit int) ([]NearbyVenue, error) {
	venues, err := p.searchOnce(ctx, loc, limit, p.radiusM)
	if err != nil {
		return p.fallback.Nearby(ctx, loc, limit)
	}
	if len(venues) < p.minResults {
		if more, err2 := p.searchOnce(ctx, loc, limit, p.maxRadiusM); err2 == nil && len(more) > len(venues) {
			venues = more
		}
	}
	if len(venues) == 0 {
		return p.fallback.Nearby(ctx, loc, limit)
	}
	return venues, nil
}

type placesNearbyReq struct {
	IncludedTypes       []string `json:"includedTypes"`
	MaxResultCount      int      `json:"maxResultCount"`
	RankPreference      string   `json:"rankPreference"`
	LocationRestriction struct {
		Circle struct {
			Center struct {
				Latitude  float64 `json:"latitude"`
				Longitude float64 `json:"longitude"`
			} `json:"center"`
			Radius float64 `json:"radius"`
		} `json:"circle"`
	} `json:"locationRestriction"`
}

type placesNearbyResp struct {
	Places []struct {
		DisplayName struct {
			Text string `json:"text"`
		} `json:"displayName"`
		Location struct {
			Latitude  float64 `json:"latitude"`
			Longitude float64 `json:"longitude"`
		} `json:"location"`
		FormattedAddress    string   `json:"formattedAddress"`
		Rating              *float64 `json:"rating"`
		PriceLevel          string   `json:"priceLevel"`
		CurrentOpeningHours *struct {
			OpenNow *bool `json:"openNow"`
		} `json:"currentOpeningHours"`
		Types []string `json:"types"`
	} `json:"places"`
}

func (p *GooglePlacesProvider) searchOnce(ctx context.Context, loc LatLng, limit, radiusM int) ([]NearbyVenue, error) {
	if !p.budget.allow() {
		return nil, ErrBudgetExhausted
	}

	maxCount := limit
	if maxCount > 20 {
		maxCount = 20
	}
	var reqBody placesNearbyReq
	reqBody.IncludedTypes = []string{"restaurant", "cafe"}
	reqBody.MaxResultCount = maxCount
	reqBody.RankPreference = "DISTANCE"
	reqBody.LocationRestriction.Circle.Center.Latitude = loc.Lat
	reqBody.LocationRestriction.Circle.Center.Longitude = loc.Lng
	reqBody.LocationRestriction.Circle.Radius = float64(radiusM)

	buf, err := json.Marshal(reqBody)
	if err != nil {
		return nil, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, p.baseURL, bytes.NewReader(buf))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Goog-Api-Key", p.apiKey)
	req.Header.Set("X-Goog-FieldMask", nearbyFieldMask)

	res, err := p.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("places searchNearby http %d", res.StatusCode)
	}

	var pr placesNearbyResp
	if err := json.NewDecoder(res.Body).Decode(&pr); err != nil {
		return nil, err
	}

	out := make([]NearbyVenue, 0, len(pr.Places))
	for _, pl := range pr.Places {
		if pl.DisplayName.Text == "" {
			continue
		}
		v := NearbyVenue{
			Name:      pl.DisplayName.Text,
			Lat:       pl.Location.Latitude,
			Lng:       pl.Location.Longitude,
			DistanceM: int(HaversineM(loc, LatLng{Lat: pl.Location.Latitude, Lng: pl.Location.Longitude})),
			Rating:    pl.Rating,
			Address:   pl.FormattedAddress,
		}
		if lvl, ok := priceLevelMap[pl.PriceLevel]; ok {
			v.PriceLevel = &lvl
		}
		if pl.CurrentOpeningHours != nil && pl.CurrentOpeningHours.OpenNow != nil {
			v.OpenNow = pl.CurrentOpeningHours.OpenNow
		}
		for _, t := range pl.Types {
			v.Tags = append(v.Tags, strings.ToLower(t))
		}
		out = append(out, v)
	}

	sortNearbyByDistance(out)
	if limit > 0 && len(out) > limit {
		out = out[:limit]
	}
	return out, nil
}
