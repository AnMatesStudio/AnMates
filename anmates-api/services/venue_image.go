package services

import (
	"context"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"sync"
	"time"
)

// ImageBrowserUA is a realistic desktop User-Agent. Search engines and many blog
// CDNs reject obvious bots, so every outbound request (search, page fetch, byte
// proxy) sends it.
const ImageBrowserUA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) " +
	"AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

// ImageSearcher resolves representative photos for a venue by web-searching its
// name (keyless DuckDuckGo Lite) and scraping the photos off the top result pages
// — the venue's own food-blog / review articles, whose `og:image` + inline photos
// are far more on-point than a generic image-search engine (which mangles a
// multi-word Vietnamese venue name into noise). Resolved URL lists are cached
// in-memory — venue photos are effectively static, so a long TTL is fine.
//
// Every failure path returns an empty list so the caller can fall back to a
// placeholder: the feature degrades gracefully and never blocks the UI.
type ImageSearcher struct {
	client *http.Client
	mu     sync.Mutex
	cache  map[string]imgCacheEntry
}

type imgCacheEntry struct {
	urls    []string
	expires time.Time
}

const (
	imageCacheTTL      = 24 * time.Hour   // a found photo set is good for a day
	imageEmptyCacheTTL = 30 * time.Minute // re-try misses sooner
	imageHTTPTimeout   = 10 * time.Second
	maxResultPages     = 5       // web-search result pages to crawl
	maxImagesPerQuery  = 6       // cap photos returned per venue
	maxImagesPerPage   = 4       // cap photos taken from any single page
	htmlReadCap        = 1 << 20 // 1 MiB of HTML per page
)

func NewImageSearcher() *ImageSearcher {
	return &ImageSearcher{
		client: &http.Client{Timeout: imageHTTPTimeout},
		cache:  make(map[string]imgCacheEntry),
	}
}

func (s *ImageSearcher) cached(key string) ([]string, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	e, ok := s.cache[key]
	if !ok || time.Now().After(e.expires) {
		return nil, false
	}
	return e.urls, true
}

func (s *ImageSearcher) store(key string, urls []string) {
	ttl := imageCacheTTL
	if len(urls) == 0 {
		ttl = imageEmptyCacheTTL
	}
	s.mu.Lock()
	s.cache[key] = imgCacheEntry{urls: urls, expires: time.Now().Add(ttl)}
	s.mu.Unlock()
}

// ResolveURLs returns up to maxImagesPerQuery photo URLs for query, crawled from
// the venue's web pages and cached per normalized query. Empty when nothing was
// found or the lookup was blocked.
func (s *ImageSearcher) ResolveURLs(ctx context.Context, query string) []string {
	key := strings.ToLower(strings.TrimSpace(query))
	if key == "" {
		return nil
	}
	if u, ok := s.cached(key); ok {
		return u
	}
	u := s.crawl(ctx, query)
	s.store(key, u)
	return u
}

// ResolveURL returns the single best photo URL (the first of ResolveURLs), or "".
func (s *ImageSearcher) ResolveURL(ctx context.Context, query string) string {
	urls := s.ResolveURLs(ctx, query)
	if len(urls) == 0 {
		return ""
	}
	return urls[0]
}

// ResolveURLAt returns the i-th photo URL for query, or "" if out of range.
func (s *ImageSearcher) ResolveURLAt(ctx context.Context, query string, i int) string {
	urls := s.ResolveURLs(ctx, query)
	if i < 0 || i >= len(urls) {
		return ""
	}
	return urls[i]
}

// crawl web-searches the venue name, then scrapes photos off the top result pages.
func (s *ImageSearcher) crawl(ctx context.Context, query string) []string {
	pages := s.searchPages(ctx, query)
	out := make([]string, 0, maxImagesPerQuery)
	seen := make(map[string]bool)
	for _, page := range pages {
		if len(out) >= maxImagesPerQuery {
			break
		}
		for _, img := range s.imagesFromPage(ctx, page) {
			if len(out) >= maxImagesPerQuery {
				break
			}
			if seen[img] {
				continue
			}
			seen[img] = true
			out = append(out, img)
		}
	}
	return out
}

// searchPages runs a keyless DuckDuckGo Lite web search and returns the top result
// page URLs (skipping social / shopping / login-walled domains we can't scrape).
func (s *ImageSearcher) searchPages(ctx context.Context, query string) []string {
	form := url.Values{"q": {query}}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost,
		"https://lite.duckduckgo.com/lite/", strings.NewReader(form.Encode()))
	if err != nil {
		return nil
	}
	req.Header.Set("User-Agent", ImageBrowserUA)
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("Accept-Language", "vi,en;q=0.9")

	resp, err := s.client.Do(req)
	if err != nil {
		return nil
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, htmlReadCap))
	if err != nil {
		return nil
	}
	return parseResultURLs(string(body), maxResultPages)
}

// imagesFromPage fetches a result page and extracts its representative photos.
func (s *ImageSearcher) imagesFromPage(ctx context.Context, pageURL string) []string {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, pageURL, nil)
	if err != nil {
		return nil
	}
	req.Header.Set("User-Agent", ImageBrowserUA)
	req.Header.Set("Accept-Language", "vi,en;q=0.9")

	resp, err := s.client.Do(req)
	if err != nil {
		return nil
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, htmlReadCap))
	if err != nil {
		return nil
	}
	return extractImages(string(body), pageURL, maxImagesPerPage)
}

// --- HTML parsing (pure, unit-tested) ------------------------------------------

var (
	hrefRe    = regexp.MustCompile(`(?i)href="(https?://[^"]+|//duckduckgo\.com/l/\?[^"]+)"`)
	ogImageRe = regexp.MustCompile(`(?i)<meta[^>]+(?:property|name)=["']og:image(?::secure_url)?["'][^>]*\scontent=["']([^"']+)["']`)
	ogImageRe2 = regexp.MustCompile(`(?i)<meta[^>]+content=["']([^"']+)["'][^>]+(?:property|name)=["']og:image(?::secure_url)?["']`)
	imgSrcRe   = regexp.MustCompile(`(?i)(?:src|data-src|data-lazy-src|data-original)=["']([^"']+?\.(?:jpe?g|png|webp))(?:\?[^"']*)?["']`)
)

// Domains whose result pages we can't usefully scrape (login walls / social /
// shopping / video / maps). The article blogs and review sites we DO want are
// everything else.
var blockedPageDomains = []string{
	"facebook.com", "fb.com", "instagram.com", "youtube.com", "youtu.be",
	"tiktok.com", "twitter.com", "x.com", "pinterest.", "linkedin.com",
	"shopee.vn", "lazada.vn", "tiki.vn", "sendo.vn",
	"google.com", "maps.google.", "duckduckgo.com",
}

func isBlockedPageDomain(u string) bool {
	low := strings.ToLower(u)
	for _, d := range blockedPageDomains {
		if strings.Contains(low, d) {
			return true
		}
	}
	return false
}

// parseResultURLs extracts up to n distinct result page URLs from a DuckDuckGo
// Lite results page, decoding DDG's `/l/?uddg=` redirect wrapper and dropping
// un-scrapable domains.
func parseResultURLs(html string, n int) []string {
	out := make([]string, 0, n)
	seen := make(map[string]bool)
	for _, m := range hrefRe.FindAllStringSubmatch(html, -1) {
		u := normalizeResultURL(m[1])
		if u == "" || seen[u] || isBlockedPageDomain(u) {
			continue
		}
		seen[u] = true
		out = append(out, u)
		if len(out) >= n {
			break
		}
	}
	return out
}

// normalizeResultURL unwraps a DuckDuckGo `/l/?...&uddg=<encoded target>` redirect
// to the real destination, and passes through plain absolute URLs.
func normalizeResultURL(raw string) string {
	if strings.Contains(raw, "duckduckgo.com/l/") {
		if i := strings.Index(raw, "uddg="); i >= 0 {
			enc := raw[i+len("uddg="):]
			if amp := strings.IndexByte(enc, '&'); amp >= 0 {
				enc = enc[:amp]
			}
			if dec, err := url.QueryUnescape(enc); err == nil && strings.HasPrefix(dec, "http") {
				return dec
			}
		}
		return ""
	}
	if strings.HasPrefix(raw, "http") {
		return raw
	}
	return ""
}

// extractImages pulls the og:image plus inline content photos out of a page's
// HTML, absolutizes them against pageURL, drops obvious chrome (logos, icons,
// avatars, sprites, ad/share/loader assets), and returns up to n distinct URLs.
func extractImages(html, pageURL string, n int) []string {
	out := make([]string, 0, n)
	seen := make(map[string]bool)

	add := func(raw string) bool {
		u := absolutizeURL(raw, pageURL)
		if u == "" || seen[u] || isJunkImage(u) {
			return false
		}
		seen[u] = true
		out = append(out, u)
		return len(out) >= n
	}

	// og:image first — it's the page's curated hero shot.
	for _, re := range []*regexp.Regexp{ogImageRe, ogImageRe2} {
		for _, m := range re.FindAllStringSubmatch(html, -1) {
			if add(m[1]) {
				return out
			}
		}
	}
	for _, m := range imgSrcRe.FindAllStringSubmatch(html, -1) {
		if add(m[1]) {
			return out
		}
	}
	return out
}

// absolutizeURL resolves a possibly-relative image URL against the page it came
// from, returning "" for data: URIs and unparseable values.
func absolutizeURL(raw, pageURL string) string {
	raw = strings.TrimSpace(raw)
	if raw == "" || strings.HasPrefix(raw, "data:") {
		return ""
	}
	if strings.HasPrefix(raw, "//") {
		return "https:" + raw
	}
	if strings.HasPrefix(raw, "http") {
		return raw
	}
	base, err := url.Parse(pageURL)
	if err != nil {
		return ""
	}
	ref, err := url.Parse(raw)
	if err != nil {
		return ""
	}
	resolved := base.ResolveReference(ref)
	if resolved.Scheme != "http" && resolved.Scheme != "https" {
		return ""
	}
	return resolved.String()
}

// Substrings that mark a non-photo asset (site chrome, ads, tracking, UI icons).
var junkImageMarkers = []string{
	"logo", "icon", "favicon", "sprite", "avatar", "banner", "/ads", "advert",
	"pixel", "placeholder", "loading", "blank", "spacer", "share", "social",
	"button", "/flag", "emoji", "thumb_default", "no-image", "noimage",
}

func isJunkImage(u string) bool {
	low := strings.ToLower(u)
	for _, m := range junkImageMarkers {
		if strings.Contains(low, m) {
			return true
		}
	}
	return false
}
