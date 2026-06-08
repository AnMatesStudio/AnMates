package services

import (
	"errors"
	"testing"
	"time"
)

func TestValidateProposal(t *testing.T) {
	now := time.Date(2026, 6, 8, 12, 0, 0, 0, time.UTC)
	future := now.Add(24 * time.Hour)
	past := now.Add(-time.Hour)

	cases := []struct {
		name string
		in   ProposeInput
		want error
	}{
		{"ok", ProposeInput{RestaurantName: "King BBQ", ScheduledAt: future}, nil},
		{"empty name", ProposeInput{RestaurantName: "", ScheduledAt: future}, ErrNoVenue},
		{"past time", ProposeInput{RestaurantName: "King BBQ", ScheduledAt: past}, ErrPastSchedule},
		{"now is not future", ProposeInput{RestaurantName: "King BBQ", ScheduledAt: now}, ErrPastSchedule},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := validateProposal(tc.in, now); !errors.Is(got, tc.want) {
				t.Fatalf("validateProposal = %v, want %v", got, tc.want)
			}
		})
	}
}
