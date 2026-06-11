package handlers

import (
	"context"
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
	searcher *services.ImageSearcher
	client   *http.Client
}

func NewVenueImage(searcher *services.ImageSearcher) *VenueImage {
	return &VenueImage{
		searcher: searcher,
		client:   &http.Client{Timeout: imageProxyTimeout},
	}
}

// Serve handles GET /api/v1/venues/image?q=<venue name>&i=<index>.
// `i` (default 0) selects which crawled photo to stream — the detail-screen
// gallery walks 0..count-1; the list thumbnails just use 0.
func (h *VenueImage) Serve(c *fiber.Ctx) error {
	q := strings.TrimSpace(c.Query("q"))
	if utf8.RuneCountInString(q) < 2 {
		return c.SendStatus(fiber.StatusBadRequest)
	}

	idx := 0
	if v, err := strconv.Atoi(c.Query("i", "0")); err == nil && v > 0 {
		idx = v
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), imageProxyTimeout)
	defer cancel()

	remote := h.searcher.ResolveURLAt(ctx, q, idx)
	if remote == "" {
		return c.SendStatus(fiber.StatusNotFound)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, remote, nil)
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
	defer resp.Body.Close()
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

	urls := h.searcher.ResolveURLs(ctx, q)
	return httputil.OK(c, fiber.Map{"count": len(urls)})
}
