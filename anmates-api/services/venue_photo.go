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

// VenuePhotoResolver picks a venue's photo from Foursquare's identity-grounded
// source: free /places/search returns the venue's official website → we crawl
// og:image from that domain. Because the website is the venue's own, the photo
// is genuinely of THIS specific venue ("chính chủ"). Bing web search has been
// removed — it could not be controlled and returned garbage for generic names.
//
// Results are cached so repeated thumbnail loads don't re-hit Foursquare/crawl.
type VenuePhotoResolver struct {
	fsq    *FoursquareClient
	bing   *ImageSearcher // used only for URL reachability validation, not search
	client *http.Client

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

func NewVenuePhotoResolver(fsq *FoursquareClient, bing *ImageSearcher) *VenuePhotoResolver {
	return &VenuePhotoResolver{
		fsq:    fsq,
		bing:   bing,
		client: &http.Client{Timeout: siteFetchTimeout},
		cache:  make(map[string]photoCacheEntry),
		ttl:    30 * time.Minute,
	}
}

// Resolve returns candidate photo URLs for the venue. Only the Foursquare
// identity-grounded path is used: GPS+name match → official website → og:image.
// Returns nil when Foursquare finds no website for the venue; callers fall back
// to a category placeholder (VenueThumbnail handles the empty case with the
// venue emoji). Bing web search has been removed — it could not be controlled.
func (r *VenuePhotoResolver) Resolve(ctx context.Context, query string, lat, lng float64) []string {
	query = strings.TrimSpace(query)
	if query == "" {
		return nil
	}
	key := fmt.Sprintf("%s|%.4f,%.4f", strings.ToLower(query), lat, lng)
	if v, ok := r.cached(key); ok {
		return v
	}

	// Foursquare → official website → og:image (chính chủ).
	if r.fsq.Enabled() && (lat != 0 || lng != 0) {
		if m, err := r.fsq.Match(ctx, query, lat, lng); err == nil && m != nil && m.Website != "" {
			if urls := r.crawlSiteImages(ctx, m.Website); len(urls) > 0 {
				r.store(key, urls)
				return urls
			}
		}
	}

	return nil
}

// ResolveAt returns the i-th photo URL for the venue, or "" if out of range.
func (r *VenuePhotoResolver) ResolveAt(ctx context.Context, query string, lat, lng float64, i int) string {
	urls := r.Resolve(ctx, query, lat, lng)
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
