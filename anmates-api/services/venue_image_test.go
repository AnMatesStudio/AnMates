package services

import (
	"reflect"
	"testing"
)

func TestNormalizeResultURL(t *testing.T) {
	tests := []struct {
		name string
		in   string
		want string
	}{
		{
			name: "plain absolute url passes through",
			in:   "https://mia.vn/cam-nang-du-lich/lau-bo-giao-toan-12628",
			want: "https://mia.vn/cam-nang-du-lich/lau-bo-giao-toan-12628",
		},
		{
			name: "ddg redirect is unwrapped",
			in:   "//duckduckgo.com/l/?uddg=https%3A%2F%2Fghiensaigon.com%2Fbun-bo-giao-toan%2F&rut=abc",
			want: "https://ghiensaigon.com/bun-bo-giao-toan/",
		},
		{
			name: "ddg redirect without uddg is dropped",
			in:   "//duckduckgo.com/l/?rut=abc",
			want: "",
		},
		{
			name: "relative href is dropped",
			in:   "/settings",
			want: "",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := normalizeResultURL(tt.in); got != tt.want {
				t.Errorf("normalizeResultURL(%q) = %q, want %q", tt.in, got, tt.want)
			}
		})
	}
}

func TestParseResultURLs(t *testing.T) {
	html := `
	<a href="https://duckduckgo.com/settings">settings</a>
	<a href="https://ghiensaigon.com/bun-bo-giao-toan/">result 1</a>
	<a href="https://www.facebook.com/bunbohuegiaotoan/">social (skip)</a>
	<a href="https://mia.vn/cam-nang-du-lich/lau-bo-giao-toan-12628">result 2</a>
	<a href="https://mia.vn/cam-nang-du-lich/lau-bo-giao-toan-12628">dup (skip)</a>
	<a href="https://vnexpress.net/quan-lau-bo-4473766.html">result 3</a>
	`
	got := parseResultURLs(html, 5)
	want := []string{
		"https://ghiensaigon.com/bun-bo-giao-toan/",
		"https://mia.vn/cam-nang-du-lich/lau-bo-giao-toan-12628",
		"https://vnexpress.net/quan-lau-bo-4473766.html",
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("parseResultURLs() = %v, want %v", got, want)
	}

	if capped := parseResultURLs(html, 1); len(capped) != 1 {
		t.Errorf("expected cap of 1, got %d", len(capped))
	}
}

func TestExtractImages(t *testing.T) {
	page := "https://mia.vn/cam-nang-du-lich/lau-bo-giao-toan-12628"
	html := `
	<meta property="og:image" content="https://mia.vn/media/uploads/blog/lau-bo-giao-toan.jpg">
	<img src="https://mia.vn/static/logo.png">
	<img src="https://mia.vn/media/uploads/blog/lau-bo-giao-toan-1.jpg">
	<img data-src="/media/uploads/blog/lau-bo-giao-toan-2.webp">
	<img src="data:image/gif;base64,R0lGOD01">
	<img src="https://mia.vn/static/author-avatar.jpg">
	`
	got := extractImages(html, page, 6)
	want := []string{
		"https://mia.vn/media/uploads/blog/lau-bo-giao-toan.jpg",  // og:image first
		"https://mia.vn/media/uploads/blog/lau-bo-giao-toan-1.jpg",
		"https://mia.vn/media/uploads/blog/lau-bo-giao-toan-2.webp", // relative → absolutized
	}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("extractImages() = %v, want %v", got, want)
	}
}

func TestExtractImagesContentAttrOrder(t *testing.T) {
	// og:image with content BEFORE property (attribute order variant).
	html := `<meta content="https://host.vn/hero.jpg" property="og:image" />`
	got := extractImages(html, "https://host.vn/page", 6)
	want := []string{"https://host.vn/hero.jpg"}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("extractImages() = %v, want %v", got, want)
	}
}

func TestIsJunkImage(t *testing.T) {
	junk := []string{
		"https://x.vn/assets/logo.png",
		"https://x.vn/img/favicon.ico.png",
		"https://x.vn/sprite-sheet.png",
		"https://x.vn/user/avatar.jpg",
		"https://x.vn/ads/banner-300x250.jpg",
		"https://x.vn/loading-placeholder.webp",
	}
	for _, u := range junk {
		if !isJunkImage(u) {
			t.Errorf("isJunkImage(%q) = false, want true", u)
		}
	}
	good := []string{
		"https://mia.vn/media/uploads/blog/lau-bo-giao-toan-1.jpg",
		"https://host.vn/photos/restaurant-interior.webp",
	}
	for _, u := range good {
		if isJunkImage(u) {
			t.Errorf("isJunkImage(%q) = true, want false", u)
		}
	}
}

func TestAbsolutizeURL(t *testing.T) {
	page := "https://mia.vn/blog/post"
	tests := []struct {
		in   string
		want string
	}{
		{"https://cdn.vn/a.jpg", "https://cdn.vn/a.jpg"},
		{"//cdn.vn/a.jpg", "https://cdn.vn/a.jpg"},
		{"/media/a.jpg", "https://mia.vn/media/a.jpg"},
		{"a.jpg", "https://mia.vn/blog/a.jpg"},
		{"data:image/png;base64,xxxx", ""},
		{"  ", ""},
	}
	for _, tt := range tests {
		if got := absolutizeURL(tt.in, page); got != tt.want {
			t.Errorf("absolutizeURL(%q) = %q, want %q", tt.in, got, tt.want)
		}
	}
}
