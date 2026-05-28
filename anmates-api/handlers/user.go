package handlers

import (
	"context"
	"strings"
	"time"

	"github.com/anmates/api/internal/httputil"
	"github.com/anmates/api/middleware"
	"github.com/anmates/api/services"
	"github.com/gofiber/fiber/v2"
)

type User struct {
	svc services.UserServicer
}

func NewUser(svc services.UserServicer) *User { return &User{svc: svc} }

func (u *User) GetProfile(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	user, err := u.svc.GetProfile(ctx, uid)
	if err != nil {
		return httputil.Err(c,fiber.StatusNotFound, httputil.ErrNotFound, "user not found")
	}
	return httputil.OK(c,toUserOut(user))
}

type updateProfileReq struct {
	Name      *string `json:"name"`
	AvatarURL *string `json:"avatar_url"`
	Bio       *string `json:"bio"`
}

func (u *User) UpdateProfile(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	var r updateProfileReq
	if err := c.BodyParser(&r); err != nil {
		return httputil.Err(c,fiber.StatusBadRequest, httputil.ErrValidation, "invalid body")
	}
	if r.Name != nil {
		trim := strings.TrimSpace(*r.Name)
		if trim == "" {
			return httputil.Err(c,fiber.StatusBadRequest, httputil.ErrValidation, "name must not be empty")
		}
		r.Name = &trim
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	user, err := u.svc.UpdateProfile(ctx, uid, r.Name, r.AvatarURL, r.Bio)
	if err != nil {
		return httputil.Err(c,fiber.StatusInternalServerError, httputil.ErrInternal, "update failed")
	}
	return httputil.OK(c,toUserOut(user))
}
