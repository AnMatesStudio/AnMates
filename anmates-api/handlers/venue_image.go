package handlers

import (
	"context"
	"encoding/base64"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/anmates/api/internal/httputil"
	"github.com/anmates/api/services"
	"github.com/gofiber/fiber/v2"
)

const (
	imageProxyTimeout = 12 * time.Second
	imageMaxBytes     = 5 << 20 // 5 MiB cap per photo
)

// VenueImage serves a web-searched venue photo as raw image bytes.
//
// It is deliberately a plain image endpoint (not the JSON envelope) so the
// Flutter client can point an `Image.network` straight at it. It runs on the
// public router — `<img>` byte fetches can't carry a bearer token — and is
// registered outside the rate-limited group so a burst of thumbnails in the
// Discovery list doesn't trip 429s. Bytes are proxied (rather than returning the
// remote URL) so the browser only ever talks to our own CORS-friendly origin.
type VenueImage struct {
	resolver *services.VenuePhotoResolver
	client   *http.Client
}

func NewVenueImage(resolver *services.VenuePhotoResolver) *VenueImage {
	return &VenueImage{
		resolver: resolver,
		client:   &http.Client{Timeout: imageProxyTimeout},
	}
}

// Serve streams a venue photo as raw image bytes. Two modes:
//
//	?u=<base64url remote URL> → agentic/enrich path: stream that exact image
//	    (SSRF-guarded). The detail gallery uses this so photos are realtime and
//	    consistent with no server-side cache.
//	?q=<venue name>&i=<index> → keyless Bing fallback: stream the i-th crawled
//	    photo (i default 0). The Discovery list thumbnails use this.
func (h *VenueImage) Serve(c *fiber.Ctx) error {
	ctx, cancel := context.WithTimeout(c.UserContext(), imageProxyTimeout)
	defer cancel()

	remote, status := h.resolveRemote(ctx, c)
	if status != 0 {
		return c.SendStatus(status)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, remote, http.NoBody)
	if err != nil {
		return c.SendStatus(fiber.StatusBadGateway)
	}
	req.Header.Set("User-Agent", services.ImageBrowserUA)
	// Photos come from the venue's own blog/CDN now (not DDG); a same-origin
	// Referer mimics a legitimate page load and avoids hotlink protection that a
	// foreign or empty Referer can trip.
	if u, perr := url.Parse(remote); perr == nil && u.Host != "" {
		req.Header.Set("Referer", u.Scheme+"://"+u.Host+"/")
	}

	resp, err := h.client.Do(req)
	if err != nil {
		return c.SendStatus(fiber.StatusBadGateway)
	}
	defer resp.Body.Close() //nolint:errcheck // HTTP response body close; error unrecoverable
	if resp.StatusCode != http.StatusOK {
		return c.SendStatus(fiber.StatusBadGateway)
	}

	ct := resp.Header.Get("Content-Type")
	if !strings.HasPrefix(ct, "image/") {
		ct = "image/jpeg"
	}

	body, err := io.ReadAll(io.LimitReader(resp.Body, imageMaxBytes))
	if err != nil || len(body) == 0 {
		return c.SendStatus(fiber.StatusBadGateway)
	}

	c.Set("Content-Type", ct)
	c.Set("Cache-Control", "public, max-age=86400")
	return c.Send(body)
}

// resolveRemote picks the remote image URL to proxy from the request. Returns
// (url, 0) on success, or ("", httpStatus) describing the error to send.
func (h *VenueImage) resolveRemote(ctx context.Context, c *fiber.Ctx) (remoteURL string, status int) {
	// Enrich path: a caller-supplied remote URL (from the agentic crawl). It is
	// SSRF-guarded — the endpoint is public, so we must never proxy an internal/
	// private address (e.g. cloud metadata).
	if enc := strings.TrimSpace(c.Query("u")); enc != "" {
		raw, err := decodeProxyURL(enc)
		if err != nil {
			return "", fiber.StatusBadRequest
		}
		if !services.IsPublicHTTPImageURL(ctx, raw) {
			return "", fiber.StatusForbidden
		}
		return raw, 0
	}

	// Resolver path: i-th photo for the venue. lat/lng are required for the
	// Foursquare identity-grounded source (GPS+name match → website → og:image).
	q := strings.TrimSpace(c.Query("q"))
	if utf8.RuneCountInString(q) < 2 {
		return "", fiber.StatusBadRequest
	}
	idx := 0
	if v, err := strconv.Atoi(c.Query("i", "0")); err == nil && v > 0 {
		idx = v
	}
	lat, _ := strconv.ParseFloat(c.Query("lat"), 64)
	lng, _ := strconv.ParseFloat(c.Query("lng"), 64)
	remote := h.resolver.ResolveAt(ctx, q, lat, lng, idx)
	if remote == "" {
		return "", fiber.StatusNotFound
	}
	return remote, 0
}

// decodeProxyURL decodes the `u=` parameter, accepting both raw (unpadded) and
// standard URL-safe base64 so the Flutter client can encode without padding.
func decodeProxyURL(enc string) (string, error) {
	if b, err := base64.RawURLEncoding.DecodeString(enc); err == nil {
		return string(b), nil
	}
	b, err := base64.URLEncoding.DecodeString(enc)
	if err != nil {
		return "", err
	}
	return string(b), nil
}

// Count handles GET /api/v1/venues/images?q=<venue name>, returning how many
// photos were crawled for the venue so the detail-screen gallery knows how many
// pages to render. JSON envelope (unlike Serve, which streams raw bytes for
// <img>). Resolution is cached, so the subsequent per-index Serve calls are cheap.
func (h *VenueImage) Count(c *fiber.Ctx) error {
	q := strings.TrimSpace(c.Query("q"))
	if utf8.RuneCountInString(q) < 2 {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "query too short")
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), imageProxyTimeout)
	defer cancel()

	lat, _ := strconv.ParseFloat(c.Query("lat"), 64)
	lng, _ := strconv.ParseFloat(c.Query("lng"), 64)
	urls := h.resolver.Resolve(ctx, q, lat, lng)
	return httputil.OK(c, fiber.Map{"count": len(urls)})
}
