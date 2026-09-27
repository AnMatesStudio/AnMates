package handlers

import (
	"context"
	"encoding/base64"
	"errors"
	"regexp"
	"strings"
	"time"

	"github.com/anmates/api/internal/httputil"
	"github.com/anmates/api/middleware"
	"github.com/anmates/api/services"
	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
)

const avatarTimeout = 10 * time.Second

// Avatar uploads and serves profile photos kept in Postgres (migration 021).
type Avatar struct {
	store *services.AvatarStore
	users services.UserServicer
}

func NewAvatar(store *services.AvatarStore, users services.UserServicer) *Avatar {
	return &Avatar{store: store, users: users}
}

// The bundled illustrations the app offers (lib/views/v2/v2_data.dart
// kAvatarSamples). Only these, so avatar_url can't point a partner's app at
// an arbitrary host.
var avatarSampleRe = regexp.MustCompile(`^asset:assets/v2/(avatar-chibi|avatars/sample-(10|[1-9]))\.png$`)

// The ?v= of services.AvatarPath.
var avatarVersionRe = regexp.MustCompile(`^[0-9a-f]{12}$`)

// validAvatarChoice says whether PUT /profile may set avatar_url to [s] for
// user [uid]: "" (the app's default), a bundled sample, or the user's own
// uploaded photo. Uploading goes through PUT /profile/avatar, never a URL — an
// external one would hand every viewer's IP to whoever runs that host.
func validAvatarChoice(uid, s string) bool {
	if s == "" || avatarSampleRe.MatchString(s) {
		return true
	}
	own := "/api/v1/users/" + uid + "/avatar?v="
	v, ok := strings.CutPrefix(s, own)
	return ok && avatarVersionRe.MatchString(v)
}

// decodeImageBase64 accepts plain base64 or a `data:…;base64,` URL, with any
// line breaks a client's encoder added.
func decodeImageBase64(s string) ([]byte, error) {
	s = strings.TrimSpace(s)
	if i := strings.Index(s, ";base64,"); strings.HasPrefix(s, "data:") && i >= 0 {
		s = s[i+len(";base64,"):]
	}
	s = strings.Join(strings.Fields(s), "")
	return base64.StdEncoding.DecodeString(s)
}

type uploadAvatarReq struct {
	ImageBase64 string `json:"image_base64"`
}

// Upload handles PUT /api/v1/profile/avatar {"image_base64": "…"}: the app's
// circle crop (a 512×512 PNG). Stored re-encoded as JPEG; returns the profile
// with its new avatar_url.
func (h *Avatar) Upload(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	var r uploadAvatarReq
	if err := c.BodyParser(&r); err != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid body")
	}
	data, err := decodeImageBase64(r.ImageBase64)
	if err != nil || len(data) == 0 {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "image_base64 must be a base64 image")
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), avatarTimeout)
	defer cancel()

	if _, err := h.store.Put(ctx, uid, data); err != nil {
		switch {
		case errors.Is(err, services.ErrAvatarTooLarge):
			return httputil.Err(c, fiber.StatusRequestEntityTooLarge, httputil.ErrValidation, "image too large (max 2 MB)")
		case errors.Is(err, services.ErrUnsupportedImageType):
			return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "image must be a JPEG or PNG")
		case errors.Is(err, services.ErrAvatarDimensions):
			return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "image must be 64–1024 px on each side")
		}
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "could not save the photo")
	}
	user, err := h.users.GetProfile(ctx, uid)
	if err != nil {
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "could not load the profile")
	}
	return httputil.OK(c, toUserOut(user))
}

// Serve handles GET /api/v1/users/:id/avatar. Public, like venue photos: an
// <img src> can't carry a bearer token, and the id is an unguessable UUID the
// viewer already got from a deck or a conversation. With the current ?v= it is
// cached for good (a new photo is a new URL); without, it is revalidated.
func (h *Avatar) Serve(c *fiber.Ctx) error {
	id, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return c.SendStatus(fiber.StatusBadRequest)
	}
	ctx, cancel := context.WithTimeout(c.UserContext(), avatarTimeout)
	defer cancel()

	a, err := h.store.Get(ctx, id)
	if errors.Is(err, services.ErrAvatarNotFound) {
		return c.SendStatus(fiber.StatusNotFound)
	}
	if err != nil {
		return c.SendStatus(fiber.StatusInternalServerError)
	}

	etag := `"` + a.SHA256 + `"`
	if v := c.Query("v"); len(v) >= 12 && strings.HasPrefix(a.SHA256, v) {
		c.Set("Cache-Control", "public, max-age=31536000, immutable")
	} else {
		c.Set("Cache-Control", "public, no-cache")
	}
	c.Set("ETag", etag)
	if c.Get("If-None-Match") == etag {
		return c.SendStatus(fiber.StatusNotModified)
	}
	c.Set("Content-Type", "image/jpeg")
	return c.Send(a.Data)
}
