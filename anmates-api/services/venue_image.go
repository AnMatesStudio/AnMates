package services

import (
	"context"
	"hash/fnv"
	"html"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"
	"unicode"
)

// ImageBrowserUA is a realistic desktop User-Agent. Bing and CDNs reject obvious
// bots, so every outbound request sends it.
const ImageBrowserUA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) " +
	"AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"

// ImageSearcher resolves representative photos for a venue by searching Bing Images
// (keyless, no API key required) and extracting the direct `murl` image URLs that
// Bing embeds in its results HTML. Resolved URL lists are cached in-memory — venue
// photos are effectively static, so a long TTL is fine.
//
// Every failure path returns an empty list so the caller can fall back to a
// placeholder: the feature degrades gracefully and never blocks the UI.
type ImageSearcher struct {
	client *http.Client
	mu     sync.Mutex
	cache  map[string]imgCacheEntry
	// ttl is how long a resolved photo set is cached. Default is 0 (caching OFF) so
	// the keyless Bing fallback path re-resolves each time — the user asked for
	// realtime, not stale, images. Re-enable/tune via VENUE_IMAGE_CACHE_TTL (a Go
	// duration, e.g. "10m"); the agentic detail path is always uncached regardless.
	ttl time.Duration
}

type imgCacheEntry struct {
	urls    []string
	expires time.Time
}

const (
	imageHTTPTimeout  = 10 * time.Second
	maxImagesPerQuery = 5       // cap photos returned per venue (max 5 per user spec)
	htmlReadCap       = 2 << 20 // 2 MiB — Bing results page is larger than DDG Lite

	// Bing lists many dead / hotlink-protected image URLs. We pull a larger
	// candidate pool, probe each, and keep the first maxImagesPerQuery that
	// actually return image bytes — so Count never reports unservable photos
	// (which would render as blank/502 gallery pages on the client).
	candidatePoolSize = maxImagesPerQuery * 3
	imageProbeTimeout = 4 * time.Second
	imageProbeWorkers = 6 // bounded concurrency for candidate validation

	// Priority-3 fallback: when no real venue photo is found, serve on-theme
	// F&B category photos so the list ALWAYS has an image (user rule).
	fallbackImageCount = 5
)

func NewImageSearcher() *ImageSearcher {
	return &ImageSearcher{
		client: &http.Client{Timeout: imageHTTPTimeout},
		cache:  make(map[string]imgCacheEntry),
		ttl:    imageCacheTTLFromEnv(),
	}
}

// imageCacheTTLFromEnv reads VENUE_IMAGE_CACHE_TTL (a Go duration). Default 0 =
// caching disabled (re-resolve every request) so photos stay realtime.
func imageCacheTTLFromEnv() time.Duration {
	v := strings.TrimSpace(os.Getenv("VENUE_IMAGE_CACHE_TTL"))
	if v == "" {
		return 0
	}
	if d, err := time.ParseDuration(v); err == nil && d > 0 {
		return d
	}
	return 0
}

func (s *ImageSearcher) cached(key string) ([]string, bool) {
	if s.ttl <= 0 {
		return nil, false // caching disabled — always re-resolve
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	e, ok := s.cache[key]
	if !ok || time.Now().After(e.expires) {
		return nil, false
	}
	return e.urls, true
}

func (s *ImageSearcher) store(key string, urls []string) {
	// Never cache an empty result: a transient Bing/network hiccup must NOT pin a
	// venue to "no image" — the next render re-resolves and the cascade fills it.
	if s.ttl <= 0 || len(urls) == 0 {
		return
	}
	s.mu.Lock()
	s.cache[key] = imgCacheEntry{urls: urls, expires: time.Now().Add(s.ttl)}
	s.mu.Unlock()
}

// ResolveURLs returns up to maxImagesPerQuery photo URLs for query, fetched from
// Bing Images and cached per normalized query. Empty when nothing was found.
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

// crawl performs a Bing Images search for venueQuery (the raw venue name, area
// included), drops results whose title/description/page-URL don't mention a
// distinctive token of the venue name — Bing returns unrelated junk for venues
// it has no photos of — then validates the survivors so only reachable images
// are returned (Bing also lists many dead / hotlink-protected URLs).
func (s *ImageSearcher) crawl(ctx context.Context, venueQuery string) []string {
	q := url.Values{
		"q":     {prepareVenueSearchQuery(venueQuery)},
		"first": {"1"},
		"count": {strconv.Itoa(candidatePoolSize)}, // over-fetch; we filter + validate down
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet,
		"https://www.bing.com/images/search?"+q.Encode(), http.NoBody)
	if err != nil {
		return nil
	}
	req.Header.Set("User-Agent", ImageBrowserUA)
	req.Header.Set("Accept-Language", "vi,en;q=0.9")
	req.Header.Set("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")

	resp, err := s.client.Do(req)
	if err != nil {
		return nil
	}
	defer resp.Body.Close() //nolint:errcheck // HTTP response body close; error unrecoverable
	if resp.StatusCode != http.StatusOK {
		return nil
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, htmlReadCap))
	if err != nil {
		return nil
	}
	candidates := parseBingImages(string(body))
	relevant := filterRelevantImages(candidates, significantTokens(venueQuery))
	// Priority 1-2: the venue's real photos (website / Maps-indexed pages), kept
	// only when a result actually names this venue.
	urls := s.validate(ctx, relevant, maxImagesPerQuery)
	if len(urls) == 0 {
		// Priority 3: no real venue photo → an on-theme F&B category photo so the
		// list ALWAYS has an image (user rule). NSFW/junk already filtered out.
		urls = s.crawlCategory(ctx, venueQuery)
	}
	return urls
}

// crawlCategory fetches generic on-theme F&B photos for the venue's category
// (e.g. "quán cà phê đẹp"). It skips the name-relevance filter — the query is
// intentionally generic — but still drops junk/NSFW and validates reachability.
func (s *ImageSearcher) crawlCategory(ctx context.Context, venueQuery string) []string {
	cat := categoryStockQuery(venueQuery)
	if cat == "" {
		return nil
	}
	q := url.Values{
		"q":     {cat},
		"first": {"1"},
		"count": {strconv.Itoa(candidatePoolSize)},
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet,
		"https://www.bing.com/images/search?"+q.Encode(), http.NoBody)
	if err != nil {
		return nil
	}
	req.Header.Set("User-Agent", ImageBrowserUA)
	req.Header.Set("Accept-Language", "vi,en;q=0.9")
	req.Header.Set("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")

	resp, err := s.client.Do(req)
	if err != nil {
		return nil
	}
	defer resp.Body.Close() //nolint:errcheck // HTTP response body close; error unrecoverable
	if resp.StatusCode != http.StatusOK {
		return nil
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, htmlReadCap))
	if err != nil {
		return nil
	}
	imgs := parseBingImages(string(body))
	urls := make([]string, 0, len(imgs))
	for _, im := range imgs {
		urls = append(urls, im.url)
	}
	// Same-category venues share this generic query → identical image list. Rotate
	// per-venue so neighbouring venues of the same type don't show the same photo.
	urls = rotateByKey(urls, venueQuery)
	return s.validate(ctx, urls, fallbackImageCount)
}

// rotateByKey deterministically rotates a slice by an offset derived from key, so
// different keys surface a different element first while reusing the same pool.
func rotateByKey(s []string, key string) []string {
	if len(s) < 2 {
		return s
	}
	h := fnv.New32a()
	_, _ = h.Write([]byte(key))
	off := int(h.Sum32()) % len(s)
	if off < 0 {
		off += len(s)
	}
	return append(append([]string{}, s[off:]...), s[:off]...)
}

// categoryStockQuery maps a venue name to a generic, image-rich Vietnamese F&B
// query for its category, used only as the no-real-photo fallback. Every branch
// is food/drink so the fallback is always F&B-relevant (user rule 3 + 4).
func categoryStockQuery(name string) string {
	s := strings.ToLower(name)
	switch {
	case containsAny(s, "tiệc cưới", "tiec cuoi", "wedding", "hội nghị", "hoi nghi", "palace", "banquet", "sự kiện", "su kien"):
		return "nhà hàng tiệc cưới sang trọng"
	case containsAny(s, "cà phê", "ca phe", "coffee", "cafe", "café", "trà sữa", "tra sua", "tea", "milk"):
		return "quán cà phê đẹp"
	case containsAny(s, "lẩu", "lau", "hotpot", "nướng", "nuong", "bbq", "barbecue", "grill", "korean", "nhật", "sushi"):
		return "nhà hàng lẩu nướng"
	case containsAny(s, "bar", "beer", "bia", "pub", "lounge", "club"):
		return "quán bar pub đẹp"
	case containsAny(s, "phở", "pho", "bún", "bun", "cơm", "com", "quán ăn", "quan an", "restaurant", "nhà hàng", "nha hang", "ăn"):
		return "nhà hàng món việt"
	default:
		return "nhà hàng quán ăn đẹp"
	}
}

func containsAny(s string, subs ...string) bool {
	for _, sub := range subs {
		if strings.Contains(s, sub) {
			return true
		}
	}
	return false
}

// validate probes candidate image URLs concurrently and returns the first `want`
// that are actually reachable and serve image bytes, preserving Bing's order
// (so the best-ranked photos stay first). The proxy will re-fetch each URL when
// streaming, but probing here keeps Count honest so no blank gallery pages render.
func (s *ImageSearcher) validate(ctx context.Context, candidates []string, want int) []string {
	if len(candidates) == 0 {
		return nil
	}
	ok := make([]bool, len(candidates))
	sem := make(chan struct{}, imageProbeWorkers)
	var wg sync.WaitGroup
	for i, u := range candidates {
		wg.Add(1)
		sem <- struct{}{}
		go func(i int, u string) {
			defer wg.Done()
			defer func() { <-sem }()
			ok[i] = s.reachableImage(ctx, u)
		}(i, u)
	}
	wg.Wait()

	out := make([]string, 0, want)
	for i, good := range ok {
		if good {
			out = append(out, candidates[i])
			if len(out) >= want {
				break
			}
		}
	}
	return out
}

// reachableImage does a lightweight ranged GET to confirm a candidate URL is
// live and serves image bytes (matching the headers the proxy will later send,
// so a URL that passes here will almost always stream successfully).
func (s *ImageSearcher) reachableImage(ctx context.Context, u string) bool {
	pctx, cancel := context.WithTimeout(ctx, imageProbeTimeout)
	defer cancel()
	req, err := http.NewRequestWithContext(pctx, http.MethodGet, u, http.NoBody)
	if err != nil {
		return false
	}
	req.Header.Set("User-Agent", ImageBrowserUA)
	req.Header.Set("Range", "bytes=0-1023") // only need the first bytes to verify
	if pu, perr := url.Parse(u); perr == nil && pu.Host != "" {
		req.Header.Set("Referer", pu.Scheme+"://"+pu.Host+"/")
	}
	resp, err := s.client.Do(req)
	if err != nil {
		return false
	}
	defer resp.Body.Close() //nolint:errcheck // HTTP response body close; error unrecoverable
	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusPartialContent {
		return false
	}
	if !strings.HasPrefix(resp.Header.Get("Content-Type"), "image/") {
		return false
	}
	_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, 1024))
	return true
}

// --- HTML parsing (pure, unit-tested) ------------------------------------------

// bingImage is one parsed Bing image result: the direct URL plus a lowercased
// "haystack" (title + description + source-page URL) used to judge relevance.
type bingImage struct {
	url      string
	haystack string
}

// Bing embeds each image result as an HTML element with an `m="{...}"` attribute
// holding entity-encoded JSON (so `"` is `&quot;`). We pull the whole blob, then
// extract the individual fields from it.
var (
	mBlobRe     = regexp.MustCompile(`m="(\{[^"]*\})"`)
	fieldMurlRe = regexp.MustCompile(`&quot;murl&quot;:&quot;(https?://[^&]+)`)
	fieldTRe    = regexp.MustCompile(`&quot;t&quot;:&quot;([^&]*)`)
	fieldDescRe = regexp.MustCompile(`&quot;desc&quot;:&quot;([^&]*)`)
	fieldPurlRe = regexp.MustCompile(`&quot;purl&quot;:&quot;([^&]*)`)
)

// adminSuffixRe strips Vietnamese ward/district/city suffixes that OSM often
// appends to POI display names (e.g. "Phường Hiệp Bình", "Quận 1"). They make
// image searches too specific to match venue review pages.
var adminSuffixRe = regexp.MustCompile(`(?i)\s+(Phường|P\.|Quận|Q\.|Huyện|H\.|Thành phố|TP\.?|Xã|Tỉnh|Thị trấn|Thị xã)\s+\S.*$`)

// parseBingImages extracts the distinct image results from Bing's HTML, dropping
// junk assets (logos, icons, ads) and duplicates, preserving Bing's rank order.
func parseBingImages(htmlStr string) []bingImage {
	out := make([]bingImage, 0, candidatePoolSize)
	seen := make(map[string]bool)
	for _, b := range mBlobRe.FindAllStringSubmatch(htmlStr, -1) {
		blob := b[1]
		mu := fieldMurlRe.FindStringSubmatch(blob)
		if mu == nil {
			continue
		}
		u := html.UnescapeString(mu[1])
		if seen[u] || isJunkImage(u) {
			continue
		}
		seen[u] = true

		parts := make([]string, 0, 3)
		for _, re := range []*regexp.Regexp{fieldTRe, fieldDescRe, fieldPurlRe} {
			if m := re.FindStringSubmatch(blob); m != nil {
				parts = append(parts, m[1])
			}
		}
		hay := strings.ToLower(html.UnescapeString(strings.Join(parts, " ")))
		out = append(out, bingImage{url: u, haystack: hay})
	}
	return out
}

// venueStopwords are generic Vietnamese venue words (and the "ảnh" suffix we add)
// that carry no identifying signal — matching on them would let unrelated wedding
// / restaurant / coffee stock photos through. We key relevance on the remaining
// distinctive tokens (brand / proper nouns like "claris", "palace", "tara").
var venueStopwords = map[string]bool{
	"trung": true, "tâm": true, "hội": true, "nghị": true, "tiệc": true,
	"cưới": true, "nhà": true, "hàng": true, "quán": true, "cà": true,
	"phê": true, "ảnh": true, "the": true, "và": true, "số": true,
	"đường": true, "khu": true, "chi": true, "nhánh": true,
}

// significantTokens returns the distinctive lowercased tokens of a venue name
// (admin suffix stripped, stopwords + 1-char tokens dropped), used to test
// whether a Bing image result is actually about this venue.
func significantTokens(name string) []string {
	clean := adminSuffixRe.ReplaceAllString(strings.TrimSpace(name), "")
	fields := strings.FieldsFunc(strings.ToLower(clean), func(r rune) bool {
		return !unicode.IsLetter(r) && !unicode.IsNumber(r)
	})
	out := make([]string, 0, len(fields))
	seen := make(map[string]bool)
	for _, f := range fields {
		if len([]rune(f)) < 2 || venueStopwords[f] || seen[f] {
			continue
		}
		seen[f] = true
		out = append(out, f)
	}
	return out
}

// filterRelevantImages keeps only images whose haystack mentions at least one
// distinctive venue token. When the name has no distinctive token (fully generic),
// it can't judge — it returns every URL rather than dropping the whole set.
func filterRelevantImages(imgs []bingImage, tokens []string) []string {
	if len(tokens) == 0 {
		urls := make([]string, 0, len(imgs))
		for _, im := range imgs {
			urls = append(urls, im.url)
		}
		return urls
	}
	out := make([]string, 0, len(imgs))
	for _, im := range imgs {
		for _, t := range tokens {
			if strings.Contains(im.haystack, t) {
				out = append(out, im.url)
				break
			}
		}
	}
	return out
}

// prepareVenueSearchQuery strips Vietnamese admin-division suffixes that OSM
// attaches to POI display names and appends "ảnh" (photo) to bias Bing toward
// image-rich review/blog pages rather than directory listings.
func prepareVenueSearchQuery(venue string) string {
	clean := strings.TrimSpace(adminSuffixRe.ReplaceAllString(strings.TrimSpace(venue), ""))
	if clean == "" {
		clean = strings.TrimSpace(venue)
	}
	return clean + " ảnh"
}

// Substrings that mark a non-photo asset (site chrome, ads, tracking, UI icons)
// OR an unsafe / clearly non-F&B image (adult content) we must never serve.
var junkImageMarkers = []string{
	"logo", "icon", "favicon", "sprite", "avatar", "banner", "/ads", "advert",
	"pixel", "placeholder", "loading", "blank", "spacer", "share", "social",
	"button", "/flag", "emoji", "thumb_default", "no-image", "noimage",
	// Safety: drop adult / pornographic sources (user rule: no "đồi trụy" images).
	"porn", "xxx", "sex", "nude", "nsfw", "adult", "erotic", "xvideos",
	"pornhub", "xhamster", "onlyfans", "hentai", "boob", "lingerie",
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

// IsPublicHTTPImageURL reports whether raw is a plain http(s) URL that resolves to
// a public (globally-routable) host — the SSRF guard for the proxy's `?u=` mode,
// which streams a caller-supplied remote URL. It rejects non-http schemes and any
// host that resolves to a loopback / private / link-local / multicast / unspecified
// address (e.g. 127.0.0.1, 10.x, 192.168.x, ::1, fc00::/7, and the cloud-metadata
// 169.254.169.254), so the open endpoint can't be turned into an internal-network
// probe. DNS is resolved here and EVERY resolved IP must be public.
func IsPublicHTTPImageURL(ctx context.Context, raw string) bool {
	u, err := url.Parse(strings.TrimSpace(raw))
	if err != nil {
		return false
	}
	if u.Scheme != "http" && u.Scheme != "https" {
		return false
	}
	host := u.Hostname()
	if host == "" {
		return false
	}

	var ips []net.IP
	if ip := net.ParseIP(host); ip != nil {
		ips = []net.IP{ip}
	} else {
		addrs, err := net.DefaultResolver.LookupIPAddr(ctx, host)
		if err != nil || len(addrs) == 0 {
			return false
		}
		for _, a := range addrs {
			ips = append(ips, a.IP)
		}
	}
	for _, ip := range ips {
		if !isPublicIP(ip) {
			return false
		}
	}
	return true
}

func isPublicIP(ip net.IP) bool {
	// IsPrivate covers RFC1918 (10/8, 172.16/12, 192.168/16) and IPv6 ULA (fc00::/7).
	if ip.IsLoopback() || ip.IsPrivate() || ip.IsUnspecified() ||
		ip.IsLinkLocalUnicast() || ip.IsLinkLocalMulticast() || ip.IsMulticast() {
		return false
	}
	return true
}
