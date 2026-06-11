package services

import (
	"context"
	"html"
	"io"
	"net/http"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"
)

// ReviewInfo is the best-effort review signal for a venue, scraped keylessly
// from Bing web results. Google Maps is prohibited in VN, so we never touch it —
// this mirrors the venue-photo pipeline (Bing scrape, in-memory cache, graceful
// empty). Every field is optional: a rating/count is emitted ONLY when a clear
// pattern matches, so we never fabricate a score; when nothing parses the zero
// value is returned and the UI simply shows less.
type ReviewInfo struct {
	Rating      float64           `json:"rating,omitempty"`
	ReviewCount int               `json:"review_count,omitempty"`
	Highlights  []ReviewHighlight `json:"highlights"`
}

// ReviewHighlight is one community-sourced snippet plus the site it came from.
// It is labelled as a web excerpt in the UI — never presented as a verified
// first-party review.
type ReviewHighlight struct {
	Text   string `json:"text"`
	Source string `json:"source"` // bare domain, e.g. "foody.vn"
}

// ReviewSearcher resolves ReviewInfo for a venue query, caching results in
// memory (reviews change slowly; a day-long TTL is fine).
type ReviewSearcher struct {
	client *http.Client
	mu     sync.Mutex
	cache  map[string]reviewCacheEntry
}

type reviewCacheEntry struct {
	info    ReviewInfo
	expires time.Time
}

const (
	reviewCacheTTL      = 24 * time.Hour
	reviewEmptyCacheTTL = 1 * time.Hour // retry barren venues sooner
	reviewHTTPTimeout   = 9 * time.Second
	reviewReadCap       = 2 << 20 // 2 MiB
	maxHighlights       = 3
	maxHighlightLen     = 200
)

func NewReviewSearcher() *ReviewSearcher {
	return &ReviewSearcher{
		client: &http.Client{Timeout: reviewHTTPTimeout},
		cache:  make(map[string]reviewCacheEntry),
	}
}

func (s *ReviewSearcher) cached(key string) (ReviewInfo, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	e, ok := s.cache[key]
	if !ok || time.Now().After(e.expires) {
		return ReviewInfo{}, false
	}
	return e.info, true
}

func (s *ReviewSearcher) store(key string, info ReviewInfo) {
	ttl := reviewCacheTTL
	if info.Rating == 0 && info.ReviewCount == 0 && len(info.Highlights) == 0 {
		ttl = reviewEmptyCacheTTL
	}
	s.mu.Lock()
	s.cache[key] = reviewCacheEntry{info: info, expires: time.Now().Add(ttl)}
	s.mu.Unlock()
}

// Resolve returns the cached-or-freshly-scraped ReviewInfo for the venue query
// (typically "name + address"). Highlights are always a non-nil slice.
func (s *ReviewSearcher) Resolve(ctx context.Context, query string) ReviewInfo {
	key := strings.ToLower(strings.TrimSpace(query))
	if key == "" {
		return ReviewInfo{Highlights: []ReviewHighlight{}}
	}
	if info, ok := s.cached(key); ok {
		return info
	}
	info := s.crawl(ctx, query)
	if info.Highlights == nil {
		info.Highlights = []ReviewHighlight{}
	}
	s.store(key, info)
	return info
}

// crawl runs one Bing web search biased toward Vietnamese review pages and
// parses the rating / count / snippets out of the results HTML.
func (s *ReviewSearcher) crawl(ctx context.Context, venueQuery string) ReviewInfo {
	q := url.Values{
		"q":       {prepareReviewSearchQuery(venueQuery)},
		"setlang": {"vi"},
		"count":   {"12"},
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet,
		"https://www.bing.com/search?"+q.Encode(), http.NoBody)
	if err != nil {
		return ReviewInfo{}
	}
	req.Header.Set("User-Agent", ImageBrowserUA)
	req.Header.Set("Accept-Language", "vi,en;q=0.9")
	req.Header.Set("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")

	resp, err := s.client.Do(req)
	if err != nil {
		return ReviewInfo{}
	}
	defer resp.Body.Close() //nolint:errcheck // HTTP response body close; error unrecoverable
	if resp.StatusCode != http.StatusOK {
		return ReviewInfo{}
	}
	body, err := io.ReadAll(io.LimitReader(resp.Body, reviewReadCap))
	if err != nil {
		return ReviewInfo{}
	}
	return parseBingReviews(string(body), significantTokens(venueQuery))
}

// prepareReviewSearchQuery strips the OSM admin-division suffix (reusing the
// venue-image cleaner) and appends "đánh giá" to bias Bing toward review pages.
func prepareReviewSearchQuery(venue string) string {
	clean := strings.TrimSpace(adminSuffixRe.ReplaceAllString(strings.TrimSpace(venue), ""))
	if clean == "" {
		clean = strings.TrimSpace(venue)
	}
	return clean + " đánh giá review"
}

// --- HTML parsing (pure, unit-tested) ------------------------------------------

var (
	// Organic result blocks. Bing wraps each as <li class="b_algo ...">…</li>.
	bAlgoRe = regexp.MustCompile(`(?s)<li class="b_algo[^"]*">(.*?)</li>`)
	// First result link (the source URL) inside a block.
	bLinkRe = regexp.MustCompile(`<a[^>]+href="(https?://[^"]+)"`)
	// Description paragraph inside a block.
	bSnippetRe = regexp.MustCompile(`(?s)<p[^>]*>(.*?)</p>`)
	tagRe      = regexp.MustCompile(`<[^>]*>`)
	wsRe       = regexp.MustCompile(`\s+`)

	// Rating patterns, tried in order of specificity. Group 1 is the 0–5 score.
	ratingRes = []*regexp.Regexp{
		regexp.MustCompile(`([0-5](?:[.,]\d))\s*/\s*5`),
		regexp.MustCompile(`(?i)(?:xếp hạng|đánh giá|rating|điểm)\s*[:\s]\s*([0-5](?:[.,]\d))`),
		regexp.MustCompile(`(?i)([0-5](?:[.,]\d))\s*(?:sao|★|⭐|stars?|out of 5)`),
	}
	// Review-count patterns. Group 1 is the (possibly grouped) integer.
	countRes = []*regexp.Regexp{
		regexp.MustCompile(`(?i)([\d][\d.,]*)\s*(?:đánh giá|lượt đánh giá|nhận xét|reviews?|ratings?)`),
		regexp.MustCompile(`(?i)(?:dựa trên|based on)\s*([\d][\d.,]*)`),
	}
)

// parseBingReviews extracts rating, review count, and up to maxHighlights
// snippets from Bing results HTML. `tokens` are the venue's distinctive name
// tokens, used to prefer snippets that are actually about this venue.
func parseBingReviews(htmlStr string, tokens []string) ReviewInfo {
	info := ReviewInfo{Highlights: []ReviewHighlight{}}

	rating, count := parseRatingAndCount(htmlStr)
	info.Rating = rating
	info.ReviewCount = count

	seen := make(map[string]bool)
	for _, block := range bAlgoRe.FindAllStringSubmatch(htmlStr, -1) {
		if len(info.Highlights) >= maxHighlights {
			break
		}
		body := block[1]

		sm := bSnippetRe.FindStringSubmatch(body)
		if sm == nil {
			continue
		}
		text := cleanSnippet(sm[1])
		if len([]rune(text)) < 24 { // too short to be a useful review line
			continue
		}
		// Prefer venue-relevant or review-flavoured snippets; skip the rest.
		if !snippetRelevant(text, tokens) {
			continue
		}
		key := strings.ToLower(text)
		if seen[key] {
			continue
		}
		seen[key] = true

		source := ""
		if lm := bLinkRe.FindStringSubmatch(body); lm != nil {
			source = domainOf(lm[1])
		}
		info.Highlights = append(info.Highlights, ReviewHighlight{Text: text, Source: source})
	}
	return info
}

func parseRatingAndCount(htmlStr string) (float64, int) {
	// Strip tags once so patterns can match across element boundaries.
	text := wsRe.ReplaceAllString(html.UnescapeString(tagRe.ReplaceAllString(htmlStr, " ")), " ")

	var rating float64
	for _, re := range ratingRes {
		if m := re.FindStringSubmatch(text); m != nil {
			v, err := strconv.ParseFloat(strings.Replace(m[1], ",", ".", 1), 64)
			if err == nil && v >= 0 && v <= 5 {
				rating = v
				break
			}
		}
	}

	var count int
	for _, re := range countRes {
		if m := re.FindStringSubmatch(text); m != nil {
			digits := strings.NewReplacer(".", "", ",", "", " ", "").Replace(m[1])
			n, err := strconv.Atoi(digits)
			if err == nil && n > 0 && n < 10_000_000 {
				count = n
				break
			}
		}
	}
	return rating, count
}

// reviewWords flag a snippet as review-flavoured even when it doesn't repeat the
// venue name (Bing often paraphrases). Kept short + high-signal.
var reviewWords = []string{
	"đánh giá", "review", "ngon", "không gian", "phục vụ", "giá cả",
	"chất lượng", "món", "quán", "nhà hàng", "thực đơn", "view", "nhận xét",
}

func snippetRelevant(text string, tokens []string) bool {
	low := strings.ToLower(text)
	for _, t := range tokens {
		if strings.Contains(low, t) {
			return true
		}
	}
	for _, w := range reviewWords {
		if strings.Contains(low, w) {
			return true
		}
	}
	return false
}

func cleanSnippet(s string) string {
	s = html.UnescapeString(tagRe.ReplaceAllString(s, ""))
	s = wsRe.ReplaceAllString(s, " ")
	s = strings.TrimSpace(s)
	// Cap overly long snippets on a word boundary so cards stay compact.
	if r := []rune(s); len(r) > maxHighlightLen {
		// Cut on a word boundary near the cap so we don't slice mid-word.
		cut := maxHighlightLen
		for cut > 0 && r[cut] != ' ' {
			cut--
		}
		if cut == 0 {
			cut = maxHighlightLen
		}
		s = strings.TrimSpace(string(r[:cut])) + "…"
	}
	return s
}

func domainOf(rawURL string) string {
	u, err := url.Parse(rawURL)
	if err != nil || u.Host == "" {
		return ""
	}
	return strings.TrimPrefix(u.Host, "www.")
}
