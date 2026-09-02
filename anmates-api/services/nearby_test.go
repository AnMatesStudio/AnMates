package services

import "testing"

func TestNewNearbyProvider(t *testing.T) {
	cases := []struct {
		name        string
		provider    string
		goongKey    string
		tomtomKey   string
		wantName    string
		wantEnabled bool
	}{
		{"explicit goong with key", "goong", "gk", "", "goong", true},
		{"explicit tomtom with key", "tomtom", "", "tk", "tomtom", true},
		{"explicit goong without key -> disabled", "goong", "", "tk", "goong", false},
		{"explicit is case/space-insensitive", "  GOONG ", "gk", "", "goong", true},
		{"auto prefers goong when both keys set", "", "gk", "tk", "goong", true},
		{"auto falls back to tomtom when only tomtom key", "", "", "tk", "tomtom", true},
		{"auto with no keys -> disabled", "", "", "", "goong", false},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			p := NewNearbyProvider(c.provider, c.goongKey, c.tomtomKey)
			if p == nil {
				t.Fatalf("NewNearbyProvider returned nil")
			}
			if got := p.Name(); got != c.wantName {
				t.Errorf("Name() = %q, want %q", got, c.wantName)
			}
			if got := p.Enabled(); got != c.wantEnabled {
				t.Errorf("Enabled() = %v, want %v", got, c.wantEnabled)
			}
		})
	}
}

func TestHaversineMeters(t *testing.T) {
	// 0.01° of latitude ≈ 1.11 km. Allow a generous tolerance.
	d := haversineMeters(10.7769, 106.7009, 10.7869, 106.7009)
	if d < 1050 || d > 1170 {
		t.Fatalf("haversineMeters ≈ %.0fm, want ~1110m", d)
	}
	if same := haversineMeters(10.7769, 106.7009, 10.7769, 106.7009); same != 0 {
		t.Fatalf("haversineMeters of a point with itself = %v, want 0", same)
	}
}
