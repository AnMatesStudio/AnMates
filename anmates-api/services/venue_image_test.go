package services

import (
	"context"
	"strings"
	"testing"
)

// bingResult builds a minimal Bing `iusc` m-blob element for one image result.
func bingResult(murl, title, desc, purl string) string {
	return `<a class="iusc" m="{&quot;purl&quot;:&quot;` + purl +
		`&quot;,&quot;murl&quot;:&quot;` + murl +
		`&quot;,&quot;t&quot;:&quot;` + title +
		`&quot;,&quot;desc&quot;:&quot;` + desc + `&quot;}">`
}

func TestParseBingImages(t *testing.T) {
	html := bingResult("https://cdn.example.com/photos/tara-coffee.jpg", "Tara Coffee Thủ Đức", "quán cà phê", "https://foody.vn/tara-coffee") +
		bingResult("https://cdn.example.com/photos/tara-coffee.jpg", "dup", "dup", "https://x.vn") + // duplicate url
		bingResult("https://cdn.example.com/assets/logo.png", "logo", "", "https://x.vn") + // junk
		bingResult("https://cdn.example.com/photos/tara-2.webp", "Tara Coffee menu", "", "https://blog.vn/tara")

	got := parseBingImages(html)
	if len(got) != 2 {
		t.Fatalf("parseBingImages() returned %d images, want 2: %+v", len(got), got)
	}
	if got[0].url != "https://cdn.example.com/photos/tara-coffee.jpg" {
		t.Errorf("first url = %q", got[0].url)
	}
	if !strings.Contains(got[0].haystack, "tara coffee") {
		t.Errorf("haystack missing title tokens: %q", got[0].haystack)
	}
	if !strings.Contains(got[0].haystack, "foody.vn") {
		t.Errorf("haystack missing page url: %q", got[0].haystack)
	}
}

func TestSignificantTokens(t *testing.T) {
	tests := []struct {
		in   string
		want []string
	}{
		{"Tara Coffee", []string{"tara", "coffee"}},
		{"Trung tâm Hội nghị - Tiệc cưới Claris Palace Phường Hiệp Bình", []string{"claris", "palace"}},
		{"NiNo Cafe TP. HCM", []string{"nino", "cafe"}},
	}
	for _, tt := range tests {
		got := significantTokens(tt.in)
		if len(got) != len(tt.want) {
			t.Errorf("significantTokens(%q) = %v, want %v", tt.in, got, tt.want)
			continue
		}
		for i := range tt.want {
			if got[i] != tt.want[i] {
				t.Errorf("significantTokens(%q)[%d] = %q, want %q", tt.in, i, got[i], tt.want[i])
			}
		}
	}
}

func TestFilterRelevantImages(t *testing.T) {
	imgs := []bingImage{
		{url: "https://a.vn/1.jpg", haystack: "tara coffee thủ đức quán cà phê"},
		{url: "https://b.vn/2.jpg", haystack: "chat us on whatsapp"},                 // irrelevant junk
		{url: "https://c.vn/3.jpg", haystack: "philippines flag history"},            // irrelevant junk
		{url: "https://d.vn/4.jpg", haystack: "review tara coffee không gian đẹp"},
	}
	got := filterRelevantImages(imgs, []string{"tara", "coffee"})
	if len(got) != 2 || got[0] != "https://a.vn/1.jpg" || got[1] != "https://d.vn/4.jpg" {
		t.Errorf("filterRelevantImages kept %v, want the two tara-coffee urls", got)
	}

	// No distinctive tokens → cannot judge → keep everything.
	all := filterRelevantImages(imgs, nil)
	if len(all) != len(imgs) {
		t.Errorf("with no tokens kept %d, want %d", len(all), len(imgs))
	}
}

func TestPrepareVenueSearchQuery(t *testing.T) {
	tests := []struct {
		in   string
		want string
	}{
		{"Tara Coffee", "Tara Coffee ảnh"},
		{"KFC", "KFC ảnh"},
		{"Claris Palace Phường Hiệp Bình", "Claris Palace ảnh"},
		{"Trung tâm Hội nghị - Tiệc cưới Claris Palace Phường Hiệp Bình", "Trung tâm Hội nghị - Tiệc cưới Claris Palace ảnh"},
		{"Giang Quán Quận 1", "Giang Quán ảnh"},
		{"NiNo Cafe TP. HCM", "NiNo Cafe ảnh"},
	}
	for _, tt := range tests {
		if got := prepareVenueSearchQuery(tt.in); got != tt.want {
			t.Errorf("prepareVenueSearchQuery(%q) = %q, want %q", tt.in, got, tt.want)
		}
	}
}

func TestCategoryStockQuery(t *testing.T) {
	tests := []struct {
		in   string
		want string
	}{
		{"Trung tâm Hội nghị - Tiệc cưới Claris Palace", "nhà hàng tiệc cưới sang trọng"},
		{"Tara Coffee", "quán cà phê đẹp"},
		{"Quán Lẩu Bò Tươi", "nhà hàng lẩu nướng"},
		{"Saigon Beer Garden", "quán bar pub đẹp"},
		{"Phở Hùng", "nhà hàng món việt"},
		{"Somewhere Mysterious", "nhà hàng quán ăn đẹp"}, // default
	}
	for _, tt := range tests {
		if got := categoryStockQuery(tt.in); got != tt.want {
			t.Errorf("categoryStockQuery(%q) = %q, want %q", tt.in, got, tt.want)
		}
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

func TestIsPublicHTTPImageURL(t *testing.T) {
	// Uses IP literals (no DNS) so the SSRF guard is exercised without network.
	public := []string{
		"https://1.2.3.4/photo.jpg",
		"http://8.8.8.8/x.png",
		"https://203.0.113.10/a/b.webp",
	}
	ctx := context.Background()
	for _, u := range public {
		if !IsPublicHTTPImageURL(ctx, u) {
			t.Errorf("IsPublicHTTPImageURL(%q) = false, want true", u)
		}
	}

	blocked := []string{
		"http://127.0.0.1/x.jpg",                       // loopback
		"http://10.0.0.5/x.jpg",                        // RFC1918
		"http://192.168.1.1/x.jpg",                     // RFC1918
		"http://172.16.5.5/x.jpg",                      // RFC1918
		"http://169.254.169.254/latest/meta-data",      // cloud metadata (link-local)
		"https://[::1]/x.jpg",                          // IPv6 loopback
		"http://[fc00::1]/x.jpg",                       // IPv6 ULA (private)
		"http://0.0.0.0/x.jpg",                         // unspecified
		"ftp://1.2.3.4/x.jpg",                          // non-http scheme
		"file:///etc/passwd",                           // non-http scheme
		"not a url at all",                             // unparseable as http
		"https:///nohost.jpg",                          // empty host
	}
	for _, u := range blocked {
		if IsPublicHTTPImageURL(ctx, u) {
			t.Errorf("IsPublicHTTPImageURL(%q) = true, want false (SSRF)", u)
		}
	}
}
