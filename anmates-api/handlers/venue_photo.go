package handlers

import (
	"context"
	"errors"
	"time"

	"github.com/anmates/api/services"
	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
)

const venuePhotoTimeout = 5 * time.Second

// VenuePhoto serves a venue's stored image bytes: GET /api/v1/venues/:id/photos/:position.
//
// Registered public (see main.go, alongside /venues), like /venues/image — an
// <img src> fetch can't carry a bearer token. Unlike /venues/image, this reads
// bytes straight out of Postgres instead of proxying a remote host: see
// db/migrations/014_venue_photo_blobs.sql for why a URL wasn't durable enough.
type VenuePhoto struct {
	store *services.VenuePhotoStore
}

func NewVenuePhoto(store *services.VenuePhotoStore) *VenuePhoto {
	return &VenuePhoto{store: store}
}

func (h *VenuePhoto) Serve(c *fiber.Ctx) error {
	restaurantID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return c.SendStatus(fiber.StatusBadRequest)
	}
	position, err := c.ParamsInt("position")
	if err != nil || position < 0 {
		return c.SendStatus(fiber.StatusBadRequest)
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), venuePhotoTimeout)
	defer cancel()

	photo, err := h.store.Get(ctx, restaurantID, position)
	if errors.Is(err, services.ErrPhotoNotFound) {
		return c.SendStatus(fiber.StatusNotFound)
	}
	if err != nil {
		return c.SendStatus(fiber.StatusInternalServerError)
	}

	// Content-addressed (sha256 of the decoded bytes), so a strong ETag is
	// exactly correct, not just a heuristic — the same digest can only ever
	// mean the same bytes. immutable is safe for the same reason: a re-publish
	// that changes the image lands at the same URL but a different ETag, which
	// correctly invalidates any cache keyed on it.
	etag := `"` + photo.SHA256 + `"`
	if c.Get("If-None-Match") == etag {
		return c.SendStatus(fiber.StatusNotModified)
	}
	c.Set("ETag", etag)
	c.Set("Cache-Control", "public, max-age=31536000, immutable")
	c.Set("Content-Type", photo.MIMEType)
	return c.Send(photo.Data)
}
