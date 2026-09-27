package handlers

import (
	"context"
	"time"

	"github.com/anmates/api/internal/httputil"
	"github.com/anmates/api/middleware"
	"github.com/anmates/api/services"
	"github.com/gofiber/fiber/v2"
)

type Notifications struct{ svc services.NotificationServicer }

func NewNotifications(svc services.NotificationServicer) *Notifications { return &Notifications{svc: svc} }

// List handles GET /notifications
func (n *Notifications) List(c *fiber.Ctx) error {
	uid := middleware.UserID(c)

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	list, err := n.svc.List(ctx, uid)
	if err != nil {
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "query failed")
	}
	return httputil.OK(c, list)
}

// MarkAllRead handles POST /notifications/read
func (n *Notifications) MarkAllRead(c *fiber.Ctx) error {
	uid := middleware.UserID(c)

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	if err := n.svc.MarkAllRead(ctx, uid); err != nil {
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "mark read failed")
	}
	return httputil.OK(c, fiber.Map{"unread": 0})
}
