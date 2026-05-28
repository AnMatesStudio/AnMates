package handlers

import (
	"context"
	"time"

	"github.com/anmates/api/internal/httputil"
	"github.com/anmates/api/middleware"
	"github.com/anmates/api/services"
	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
)

type NoiLau struct {
	svc services.NoiLauServicer
}

func NewNoiLau(svc services.NoiLauServicer) *NoiLau { return &NoiLau{svc: svc} }

func (n *NoiLau) Get(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	matchID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return httputil.Err(c,fiber.StatusBadRequest, httputil.ErrValidation, "invalid match id")
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	if !n.svc.IsMember(ctx, matchID, uid) {
		return httputil.Err(c,fiber.StatusNotFound, httputil.ErrMatchNotFound, "match not found")
	}

	p, err := n.svc.GetProgress(ctx, matchID)
	if err != nil {
		return httputil.Err(c,fiber.StatusInternalServerError, httputil.ErrInternal, "query failed")
	}
	return httputil.OK(c,p)
}
