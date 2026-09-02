package handlers

import (
	"testing"

	"github.com/anmates/api/services"
)

func TestFilterAndSortPicks(t *testing.T) {
	picks := []services.CardPick{
		{Name: "Venue A", DistanceM: 500},
		{Name: "Venue B", DistanceM: 2000},
		{Name: "Venue C", DistanceM: 1000},
		{Name: "Venue D", DistanceM: 15000},
		{Name: "Venue E", DistanceM: 8000},
	}

	tests := []struct {
		name              string
		sortByDistance    bool
		maxDistanceM      int
		expectedCount     int
		expectedFirstName string
		expectedOrder     []string
	}{
		{
			name:              "sort by distance with default max",
			sortByDistance:    true,
			maxDistanceM:      10000,
			expectedCount:     4,
			expectedFirstName: "Venue A",
			expectedOrder:     []string{"Venue A", "Venue C", "Venue B", "Venue E"},
		},
		{
			name:              "sort by distance with custom max",
			sortByDistance:    true,
			maxDistanceM:      3000,
			expectedCount:     3,
			expectedFirstName: "Venue A",
			expectedOrder:     []string{"Venue A", "Venue C", "Venue B"},
		},
		{
			name:              "no sort, just filter",
			sortByDistance:    false,
			maxDistanceM:      10000,
			expectedCount:     4,
			expectedFirstName: "Venue A",
			expectedOrder:     []string{"Venue A", "Venue B", "Venue C", "Venue E"},
		},
		{
			name:              "filter only, exclude all beyond 5km",
			sortByDistance:    true,
			maxDistanceM:      5000,
			expectedCount:     3,
			expectedFirstName: "Venue A",
			expectedOrder:     []string{"Venue A", "Venue C", "Venue B"},
		},
		{
			name:              "no results beyond max",
			sortByDistance:    true,
			maxDistanceM:      300,
			expectedCount:     0,
			expectedFirstName: "",
			expectedOrder:     []string{},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := filterAndSortPicks(picks, tt.sortByDistance, tt.maxDistanceM)
			if len(result) != tt.expectedCount {
				t.Errorf("expected %d results, got %d", tt.expectedCount, len(result))
			}
			if tt.expectedCount > 0 && result[0].Name != tt.expectedFirstName {
				t.Errorf("expected first venue %q, got %q", tt.expectedFirstName, result[0].Name)
			}

			if len(result) > 0 && tt.sortByDistance {
				for i := 1; i < len(result); i++ {
					if result[i].DistanceM < result[i-1].DistanceM {
						t.Errorf("results not sorted: %d > %d", result[i-1].DistanceM, result[i].DistanceM)
					}
				}
			}

			for i, r := range result {
				if i < len(tt.expectedOrder) && r.Name != tt.expectedOrder[i] {
					t.Errorf("position %d: expected %q, got %q", i, tt.expectedOrder[i], r.Name)
				}
			}
		})
	}
}

func TestFilterAndSortPicksDistanceOrdering(t *testing.T) {
	picks := []services.CardPick{
		{Name: "Far", DistanceM: 9500},
		{Name: "Near", DistanceM: 100},
		{Name: "Mid", DistanceM: 5000},
	}

	result := filterAndSortPicks(picks, true, 10000)
	if len(result) != 3 {
		t.Fatalf("expected 3 results, got %d", len(result))
	}

	expected := []string{"Near", "Mid", "Far"}
	for i, name := range expected {
		if result[i].Name != name {
			t.Errorf("position %d: expected %q, got %q", i, name, result[i].Name)
		}
	}

	for i := 1; i < len(result); i++ {
		if result[i].DistanceM < result[i-1].DistanceM {
			t.Errorf("not sorted at position %d: %d < %d", i, result[i].DistanceM, result[i-1].DistanceM)
		}
	}
}
