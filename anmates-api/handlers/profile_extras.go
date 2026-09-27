package handlers

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/anmates/api/internal/httputil"
	"github.com/anmates/api/middleware"
	"github.com/anmates/api/services"
	"github.com/gofiber/fiber/v2"
)

type ProfileExtras struct{ svc services.ProfileExtrasServicer }

func NewProfileExtras(svc services.ProfileExtrasServicer) *ProfileExtras { return &ProfileExtras{svc: svc} }

type matchPrefsReq struct {
	VibeTags  []string `json:"vibe_tags"`
	PriceTier *int16   `json:"price_tier"`
}

// GetMatchPrefs handles GET /profile/match-prefs
func (p *ProfileExtras) GetMatchPrefs(c *fiber.Ctx) error {
	uid := middleware.UserID(c)

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	prefs, err := p.svc.GetMatchPrefs(ctx, uid)
	if err != nil {
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "query failed")
	}
	return httputil.OK(c, prefs)
}

// SetMatchPrefs handles PATCH /profile/match-prefs
func (p *ProfileExtras) SetMatchPrefs(c *fiber.Ctx) error {
	uid := middleware.UserID(c)

	var r matchPrefsReq
	if err := c.BodyParser(&r); err != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid body")
	}
	if len(r.VibeTags) > 3 {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "at most 3 vibe_tags")
	}
	tags := []string{}
	seen := map[string]struct{}{}
	for _, tag := range r.VibeTags {
		tag = strings.TrimSpace(strings.ToLower(tag))
		if _, ok := services.VibeCodes[tag]; !ok {
			return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid vibe tag")
		}
		if _, dup := seen[tag]; dup {
			continue
		}
		seen[tag] = struct{}{}
		tags = append(tags, tag)
	}
	if r.PriceTier != nil && (*r.PriceTier < 0 || *r.PriceTier > 3) {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "price_tier must be 0..3")
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	prefs, err := p.svc.SetMatchPrefs(ctx, uid, tags, r.PriceTier)
	if err != nil {
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "update failed")
	}
	return httputil.OK(c, prefs)
}

// DeleteAccount handles DELETE /profile
func (p *ProfileExtras) DeleteAccount(c *fiber.Ctx) error {
	uid := middleware.UserID(c)

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	if err := p.svc.DeleteAccount(ctx, uid); err != nil {
		if errors.Is(err, services.ErrNotFound) {
			return httputil.Err(c, fiber.StatusNotFound, httputil.ErrNotFound, "account not found")
		}
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "delete failed")
	}
	return httputil.OK(c, fiber.Map{"deleted": true})
}

// Trust handles GET /profile/trust
func (p *ProfileExtras) Trust(c *fiber.Ctx) error {
	uid := middleware.UserID(c)

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	tr, err := p.svc.Trust(ctx, uid)
	if err != nil {
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "query failed")
	}
	return httputil.OK(c, tr)
}

// History handles GET /profile/history
func (p *ProfileExtras) History(c *fiber.Ctx) error {
	uid := middleware.UserID(c)

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	h, err := p.svc.History(ctx, uid)
	if err != nil {
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "query failed")
	}
	return httputil.OK(c, h)
}

// Locals handles GET /locals
func (p *ProfileExtras) Locals(c *fiber.Ctx) error {
	uid := middleware.UserID(c)

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	list, err := p.svc.Locals(ctx, uid)
	if err != nil {
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "query failed")
	}
	return httputil.OK(c, list)
}
