package services

import (
	"reflect"
	"testing"
)

func TestFoodKeywordsFromOnboarding(t *testing.T) {
	cases := []struct {
		name    string
		food    []string
		vibe    []string
		culture []string
		want    []string
	}{
		{"no tags -> nil (caller uses defaults)", nil, nil, nil, nil},
		{"single food tag expands", []string{"fwb"}, nil, nil, []string{"quán nhậu", "bia"}},
		{
			"dedup across dimensions (fwb + party both → quán nhậu/bia)",
			[]string{"fwb"}, []string{"party"}, nil,
			[]string{"quán nhậu", "bia"},
		},
		{
			"culture nationality maps to cuisine keywords",
			nil, nil, []string{"kr", "jp"},
			[]string{"quán hàn", "gà hàn quốc", "sushi", "ramen"},
		},
		{"dietary/generic tags map to nothing", []string{"no_onion"}, []string{"yolo", "chill"}, nil, nil},
		{"unknown tag is ignored", []string{"not_a_real_tag"}, nil, nil, nil},
		{"tags are case/space-insensitive", []string{"  FWB "}, nil, nil, []string{"quán nhậu", "bia"}},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got := FoodKeywordsFromOnboarding(c.food, c.vibe, c.culture)
			if !reflect.DeepEqual(got, c.want) {
				t.Errorf("FoodKeywordsFromOnboarding(%v,%v,%v) = %v, want %v",
					c.food, c.vibe, c.culture, got, c.want)
			}
		})
	}
}

func TestFoodKeywordsCap(t *testing.T) {
	// Many tags must be capped so the Goong fan-out (1 autocomplete + N detail
	// calls per keyword) stays bounded.
	food := []string{"fwb", "ons", "419", "sgbb", "sgdd"}
	culture := []string{"kr", "jp", "th"}
	vibe := []string{"street", "fancy", "quiet"}
	got := FoodKeywordsFromOnboarding(food, vibe, culture)
	if len(got) > maxOnboardingKeywords {
		t.Fatalf("got %d keywords, want <= %d", len(got), maxOnboardingKeywords)
	}
	// Must still be unique.
	seen := map[string]bool{}
	for _, k := range got {
		if seen[k] {
			t.Errorf("duplicate keyword %q", k)
		}
		seen[k] = true
	}
}
