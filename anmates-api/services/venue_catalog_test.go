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

func TestPageOf(t *testing.T) {
	all := []int{0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11}
	cases := []struct {
		name          string
		offset, limit int
		want          []int
	}{
		{"first page", 0, 5, []int{0, 1, 2, 3, 4}},
		{"middle page", 5, 5, []int{5, 6, 7, 8, 9}},
		{"short last page", 10, 5, []int{10, 11}},
		{"offset exactly at end", 12, 5, []int{}},
		{"offset past end", 50, 5, []int{}},
		{"no limit returns the rest", 9, 0, []int{9, 10, 11}},
		{"negative offset treated as zero", -3, 2, []int{0, 1}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got := pageOf(all, tc.offset, tc.limit)
			if len(got) != len(tc.want) {
				t.Fatalf("pageOf(%d, %d) = %v, want %v", tc.offset, tc.limit, got, tc.want)
			}
			for i := range got {
				if got[i] != tc.want[i] {
					t.Fatalf("pageOf(%d, %d) = %v, want %v", tc.offset, tc.limit, got, tc.want)
				}
			}
		})
	}
}

// Consecutive pages must tile the full list exactly — no row twice, none missed.
func TestPageOfTilesWithoutGapsOrOverlap(t *testing.T) {
	all := make([]int, 23)
	for i := range all {
		all[i] = i
	}
	var seen []int
	for off := 0; ; off += 10 {
		p := pageOf(all, off, 10)
		if len(p) == 0 {
			break
		}
		seen = append(seen, p...)
	}
	if len(seen) != len(all) {
		t.Fatalf("paged through %d rows, want %d", len(seen), len(all))
	}
	for i, v := range seen {
		if v != i {
			t.Fatalf("row %d = %d, want %d", i, v, i)
		}
	}
}
