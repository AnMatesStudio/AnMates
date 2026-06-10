package services

import (
	"context"
	"errors"
	"sort"
	"sync"
	"time"
)

// ErrBudgetExhausted signals the daily Places call budget is spent; callers
// should fall back to a free source (OSM) for the rest of the day.
var ErrBudgetExhausted = errors.New("nearby: daily places budget exhausted")

// NearbyVenue is one restaurant returned to the Discovery "HOT QUANH BẠN" list.
// Distance is computed server-side (Haversine) from the requesting user.
type NearbyVenue struct {
	Name       string   `json:"name"`
	Lat        float64  `json:"lat"`
	Lng        float64  `json:"lng"`
	DistanceM  int      `json:"distance_m"`
	Rating     *float64 `json:"rating,omitempty"`
	PriceLevel *int     `json:"price_level,omitempty"` // 0..4 (Google PRICE_LEVEL_*), nil if unspecified
	OpenNow    *bool    `json:"open_now,omitempty"`
	Address    string   `json:"address,omitempty"`
	Tags       []string `json:"tags,omitempty"` // Google place `types`, lowercased
}

// NearbyProvider returns venues near loc, nearest-first, capped at limit.
type NearbyProvider interface {
	Nearby(ctx context.Context, loc LatLng, limit int) ([]NearbyVenue, error)
}

// sortNearbyByDistance sorts ascending by DistanceM.
func sortNearbyByDistance(vs []NearbyVenue) {
	sort.Slice(vs, func(i, j int) bool { return vs[i].DistanceM < vs[j].DistanceM })
}

// dailyBudget caps Places calls per day (Asia/Ho_Chi_Minh boundary). Thread-safe.
type dailyBudget struct {
	mu    sync.Mutex
	limit int
	loc   *time.Location
	day   string
	count int
}

func newDailyBudget(limit int) *dailyBudget {
	loc, err := time.LoadLocation("Asia/Ho_Chi_Minh")
	if err != nil {
		loc = time.FixedZone("ICT", 7*3600)
	}
	return &dailyBudget{limit: limit, loc: loc}
}

// allow reports whether another call fits under 90% of today's budget,
// incrementing the counter when it does. Resets at the local day boundary.
func (b *dailyBudget) allow() bool {
	b.mu.Lock()
	defer b.mu.Unlock()
	today := time.Now().In(b.loc).Format("2006-01-02")
	if today != b.day {
		b.day, b.count = today, 0
	}
	if b.count >= (b.limit*9)/10 {
		return false
	}
	b.count++
	return true
}
