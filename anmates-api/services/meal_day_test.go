package services

import (
	"strings"
	"testing"

	"github.com/google/uuid"
)

func TestBuildIcebreakersWithSharedFood(t *testing.T) {
	id := uuid.MustParse("11111111-1111-1111-1111-111111111111")
	got := buildIcebreakers(id, []string{"phở"})
	if len(got) != 3 {
		t.Fatalf("want 3 prompts, got %d", len(got))
	}
	for i, p := range got {
		if !strings.Contains(strings.ToLower(p.VI), "phở") {
			t.Errorf("prompt %d vi %q does not mention phở", i, p.VI)
		}
		if !strings.Contains(strings.ToLower(p.EN), "phở") {
			t.Errorf("prompt %d en %q does not mention phở", i, p.EN)
		}
		for _, s := range []string{p.VI, p.EN} {
			if strings.Contains(s, "{") || strings.Contains(s, "}") {
				t.Errorf("prompt %d %q still contains a brace", i, s)
			}
		}
	}
	var leading bool
	for _, p := range got {
		if strings.HasPrefix(p.VI, "Phở") {
			leading = true
			break
		}
	}
	if !leading {
		t.Fatalf("no prompt starts with capitalised \"Phở\": %+v", got)
	}

	again := buildIcebreakers(id, []string{"phở"})
	for i := range got {
		if got[i] != again[i] {
			t.Fatalf("same match id produced different output at %d: %+v vs %+v", i, got[i], again[i])
		}
	}

	otherID := uuid.MustParse("22222222-2222-2222-2222-222222222222")
	other := buildIcebreakers(otherID, []string{"phở"})
	if len(other) != 3 {
		t.Fatalf("different id: want 3 prompts, got %d", len(other))
	}
	for i, p := range other {
		if !strings.Contains(strings.ToLower(p.VI), "phở") || !strings.Contains(strings.ToLower(p.EN), "phở") {
			t.Errorf("different id: prompt %d does not mention phở: %+v", i, p)
		}
		if strings.Contains(p.VI, "{") || strings.Contains(p.EN, "}") {
			t.Errorf("different id: prompt %d still contains a brace: %+v", i, p)
		}
	}
}

func TestBuildIcebreakersWithoutSharedFood(t *testing.T) {
	got := buildIcebreakers(uuid.MustParse("33333333-3333-3333-3333-333333333333"), nil)
	if len(got) != 3 {
		t.Fatalf("want 3 prompts, got %d", len(got))
	}
	for i, p := range got {
		if !isGenericTemplate(p) {
			t.Errorf("prompt %d is not from the generic list: %+v", i, p)
		}
	}
}

func isGenericTemplate(p Icebreaker) bool {
	for _, t := range genericTemplates {
		if p.VI == t.vi && p.EN == t.en {
			return true
		}
	}
	return false
}
