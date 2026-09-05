package services

import "testing"

func TestFoldVN(t *testing.T) {
	cases := []struct {
		name string
		in   string
		want string
	}{
		{"lowercases", "PHỞ", "pho"},
		{"strips tone marks", "Bún Bò Giáo Toàn", "bun bo giao toan"},
		{"folds đ/Đ to d", "Bánh Đúc, Đà Nẵng", "banh duc, da nang"},
		{"plain ascii passes through", "Pizza 4P's", "pizza 4p's"},
		{"empty stays empty", "", ""},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := foldVN(c.in); got != c.want {
				t.Errorf("foldVN(%q) = %q, want %q", c.in, got, c.want)
			}
		})
	}
}

func TestMatchesQuery(t *testing.T) {
	addr := "26 Lê Thị Riêng, P.Bến Thành"
	v := CatalogVenue{Name: "Bánh Mì Huỳnh Hoa", Address: &addr}

	cases := []struct {
		name  string
		query string
		want  bool
	}{
		{"matches name without diacritics", "banh mi", true},
		{"matches name with diacritics", "huỳnh hoa", true},
		{"matches address, not just name", "ben thanh", true},
		{"case-insensitive", "BANH MI", true},
		{"no match", "bun bo", false},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := matchesQuery(v, foldVN(c.query)); got != c.want {
				t.Errorf("matchesQuery(%q) = %v, want %v", c.query, got, c.want)
			}
		})
	}

	t.Run("nil address never panics", func(t *testing.T) {
		noAddr := CatalogVenue{Name: "Ốc Đào"}
		if !matchesQuery(noAddr, foldVN("oc dao")) {
			t.Error("expected name match with nil address")
		}
		if matchesQuery(noAddr, foldVN("nguyen trai")) {
			t.Error("expected no match against nil address")
		}
	})
}
