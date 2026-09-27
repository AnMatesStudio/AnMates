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
	"github.com/google/uuid"
)

type Safety struct{ svc services.SafetyServicer }

func NewSafety(svc services.SafetyServicer) *Safety { return &Safety{svc: svc} }

type userTargetReq struct {
	UserID string `json:"user_id"`
}

type reportReq struct {
	UserID string `json:"user_id"`
	Reason string `json:"reason"`
	Note   string `json:"note"`
}

// Unmatch handles DELETE /matches/:id.
func (s *Safety) Unmatch(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	id, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid match id")
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	if err := s.svc.Unmatch(ctx, id, uid); err != nil {
		if errors.Is(err, services.ErrNotFound) {
			return httputil.Err(c, fiber.StatusNotFound, httputil.ErrMatchNotFound, "match not found")
		}
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "unmatch failed")
	}
	return httputil.OK(c, fiber.Map{"unmatched": true})
}

// Block handles POST /blocks.
func (s *Safety) Block(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	var r userTargetReq
	if err := c.BodyParser(&r); err != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid body")
	}
	target, err := uuid.Parse(r.UserID)
	if err != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid user_id")
	}
	if target == uid {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "cannot block yourself")
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	if err := s.svc.Block(ctx, uid, target); err != nil {
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "block failed")
	}
	c.Status(fiber.StatusCreated)
	return httputil.OK(c, fiber.Map{"blocked": true})
}

// Unblock handles DELETE /blocks/:userId.
func (s *Safety) Unblock(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	target, err := uuid.Parse(c.Params("userId"))
	if err != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid user id")
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	if err := s.svc.Unblock(ctx, uid, target); err != nil {
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "unblock failed")
	}
	return httputil.OK(c, fiber.Map{"unblocked": true})
}

// ListBlocked handles GET /blocks.
func (s *Safety) ListBlocked(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	list, err := s.svc.ListBlocked(ctx, uid)
	if err != nil {
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "query failed")
	}
	return httputil.OK(c, list)
}

// Report handles POST /reports.
func (s *Safety) Report(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	var r reportReq
	if err := c.BodyParser(&r); err != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid body")
	}
	target, err := uuid.Parse(r.UserID)
	if err != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid user_id")
	}
	if target == uid {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "cannot report yourself")
	}
	r.Reason = strings.TrimSpace(strings.ToLower(r.Reason))
	if _, ok := services.ReportReasons[r.Reason]; !ok {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid reason")
	}
	r.Note = strings.TrimSpace(r.Note)
	if len([]rune(r.Note)) > 500 {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "note too long (max 500)")
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	id, err := s.svc.Report(ctx, uid, target, r.Reason, r.Note)
	if err != nil {
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "report failed")
	}
	c.Status(fiber.StatusCreated)
	return httputil.OK(c, fiber.Map{"id": id})
}
