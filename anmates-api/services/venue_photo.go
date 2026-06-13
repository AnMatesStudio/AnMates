package services

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"sync"
	"time"
)

// VenuePhotoResolver picks a venue's photo from the most identity-confident source
// available, in order:
//
//	1. Foursquare (free search) → the venue's OWN official website → og:image.
//	   The website is the venue's own domain, so its hero image is genuinely a
//	   photo of THIS venue ("chính chủ"). Highest identity confidence.
//	2. Agentic enrich (sidecar Playwright crawl + LLM food-verification) — only
//	   when allowAgentic (the detail hero, where the per-venue latency is OK; never
//	   on a 60-item list).
//	3. Keyless Bing image search with the name-relevance + non-food-source filter,
//	   ending in an honest on-theme category photo (never a random wrong image).
//
// Results are cached so repeated thumbnail loads don't re-hit Foursquare/crawl.
type VenuePhotoResolver struct {
	fsq      *FoursquareClient
	enricher *VenueEnricher
	bing     *ImageSearcher
	client   *http.Client

	mu    sync.Mutex
	cache map[string]photoCacheEntry
	ttl   time.Duration
}

type photoCacheEntry struct {
	urls    []string
	expires time.Time
}

const (
	siteFetchTimeout = 6 * time.Second
	siteHTMLReadCap  = 768 << 10 // 768 KiB of HTML is plenty for <head> metas
	siteImagesCap    = 6
)

func NewVenuePhotoResolver(fsq *FoursquareClient, enricher *VenueEnricher, bing *ImageSearcher) *VenuePhotoResolver {
	return &VenuePhotoResolver{
		fsq:      fsq,
		enricher: enricher,
		bing:     bing,
		client:   &http.Client{Timeout: siteFetchTimeout},
		cache:    make(map[string]photoCacheEntry),
		ttl:      30 * time.Minute,
	}
}

// Resolve returns candidate photo URLs for the venue, best (most identity-trusted)
// first. `query` is the venue name (optionally with address); lat/lng locate it.
func (r *VenuePhotoResolver) Resolve(ctx context.Context, query string, lat, lng float64, allowAgentic bool) []string {
	query = strings.TrimSpace(query)
	if query == "" {
		return nil
	}
	key := fmt.Sprintf("%s|%.4f,%.4f|%t", strings.ToLower(query), lat, lng, allowAgentic)
	if v, ok := r.cached(key); ok {
		return v
	}

	// 1) Foursquare → official website → og:image (chính chủ).
	if r.fsq.Enabled() && (lat != 0 || lng != 0) {
		if m, err := r.fsq.Match(ctx, query, lat, lng); err == nil && m != nil && m.Website != "" {
			if urls := r.crawlSiteImages(ctx, m.Website); len(urls) > 0 {
				r.store(key, urls)
				return urls
			}
		}
	}

	// 2) Agentic enrich (verified real photos) — detail hero only.
	if allowAgentic && r.enricher.Enabled() {
		if res, err := r.enricher.Enrich(ctx, query, "", "", lat, lng, 8); err == nil && res != nil && res.IsFoodVenue {
			urls := make([]string, 0, len(res.Images))
			for _, im := range res.Images {
				if u := strings.TrimSpace(im.URL); u != "" {
					urls = append(urls, u)
				}
			}
			if len(urls) > 0 {
				r.store(key, urls)
				return urls
			}
		}
	}

	// 3) Improved Bing search + honest category fallback.
	urls := r.bing.ResolveURLs(ctx, query)
	r.store(key, urls)
	return urls
}

// ResolveAt returns the i-th photo URL for the venue, or "" if out of range.
func (r *VenuePhotoResolver) ResolveAt(ctx context.Context, query string, lat, lng float64, allowAgentic bool, i int) string {
	urls := r.Resolve(ctx, query, lat, lng, allowAgentic)
	if i < 0 || i >= len(urls) {
		return ""
	}
	return urls[i]
}

// crawlSiteImages fetches the venue's own website and extracts its social-preview
// images (og:image / twitter:image / image_src). These are the photo the venue
// chose to represent itself — i.e. its real photo. SSRF-guarded + reachability-
// validated so a hostile site can't make us proxy an internal address.
func (r *VenuePhotoResolver) crawlSiteImages(ctx context.Context, website string) []string {
	base, err := url.Parse(website)
	if err != nil || base.Host == "" || !strings.HasPrefix(base.Scheme, "http") {
		return nil
	}
	html := r.fetchHTML(ctx, website)
	if html == "" {
		return nil
	}
	seen := make(map[string]bool)
	candidates := make([]string, 0, 4)
	for _, raw := range extractSocialImages(html) {
		abs := absolutizeURL(base, raw)
		if abs == "" || seen[abs] {
			continue
		}
		seen[abs] = true
		if !IsPublicHTTPImageURL(ctx, abs) {
			continue
		}
		candidates = append(candidates, abs)
	}
	if len(candidates) == 0 {
		return nil
	}
	return r.bing.validate(ctx, candidates, siteImagesCap)
}

func (r *VenuePhotoResolver) fetchHTML(ctx context.Context, pageURL string) string {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, pageURL, http.NoBody)
	if err != nil {
		return ""
	}
	req.Header.Set("User-Agent", ImageBrowserUA)
	req.Header.Set("Accept", "text/html,application/xhtml+xml")
	resp, err := r.client.Do(req)
	if err != nil {
		return ""
	}
	defer resp.Body.Close() //nolint:errcheck // response body close; error unrecoverable
	if resp.StatusCode != http.StatusOK {
		return ""
	}
	if ct := resp.Header.Get("Content-Type"); ct != "" && !strings.Contains(ct, "html") {
		return ""
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, siteHTMLReadCap))
	if err != nil {
		return ""
	}
	return string(body)
}

func (r *VenuePhotoResolver) cached(key string) ([]string, bool) {
	r.mu.Lock()
	defer r.mu.Unlock()
	e, ok := r.cache[key]
	if !ok || time.Now().After(e.expires) {
		return nil, false
	}
	return e.urls, true
}

func (r *VenuePhotoResolver) store(key string, urls []string) {
	if len(urls) == 0 {
		return
	}
	r.mu.Lock()
	r.cache[key] = photoCacheEntry{urls: urls, expires: time.Now().Add(r.ttl)}
	r.mu.Unlock()
}

// --- HTML helpers -------------------------------------------------------------

var (
	// og:image / twitter:image, tolerant of attribute order.
	ogImageRe = regexp.MustCompile(`(?is)<meta[^>]+(?:property|name)=["'](?:og:image(?::secure_url)?|twitter:image(?::src)?)["'][^>]+content=["']([^"']+)["']`)
	ogImageRe2 = regexp.MustCompile(`(?is)<meta[^>]+content=["']([^"']+)["'][^>]+(?:property|name)=["'](?:og:image(?::secure_url)?|twitter:image(?::src)?)["']`)
	imageSrcRe = regexp.MustCompile(`(?is)<link[^>]+rel=["']image_src["'][^>]+href=["']([^"']+)["']`)
)

// extractSocialImages pulls a venue page's declared preview images, in document
// order. These are the images the site chose to represent itself.
func extractSocialImages(html string) []string {
	out := make([]string, 0, 4)
	for _, re := range []*regexp.Regexp{ogImageRe, ogImageRe2, imageSrcRe} {
		for _, m := range re.FindAllStringSubmatch(html, -1) {
			if len(m) > 1 {
				if u := strings.TrimSpace(m[1]); u != "" {
					out = append(out, u)
				}
			}
		}
	}
	return out
}

// absolutizeURL resolves a possibly-relative image URL against the page base,
// returning "" for unusable (data:, javascript:) refs.
func absolutizeURL(base *url.URL, ref string) string {
	ref = strings.TrimSpace(ref)
	if ref == "" || strings.HasPrefix(ref, "data:") || strings.HasPrefix(ref, "javascript:") {
		return ""
	}
	u, err := url.Parse(ref)
	if err != nil {
		return ""
	}
	return base.ResolveReference(u).String()
}
