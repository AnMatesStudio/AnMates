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

type Account struct {
	svc  services.AccountServicer
	auth services.AuthServicer
}

func NewAccount(svc services.AccountServicer, auth services.AuthServicer) *Account { return &Account{svc: svc, auth: auth} }

// Status handles GET /account/status
func (a *Account) Status(c *fiber.Ctx) error {
	uid := middleware.UserID(c)

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	st, err := a.svc.Status(ctx, uid)
	if err != nil {
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "query failed")
	}
	return httputil.OK(c, st)
}

// RequestVerify handles POST /account/verify-email/request
func (a *Account) RequestVerify(c *fiber.Ctx) error {
	uid := middleware.UserID(c)

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	st, err := a.svc.Status(ctx, uid)
	if err != nil {
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "query failed")
	}
	if st.Email == nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "no email on this account")
	}
	if st.EmailVerified {
		return httputil.OK(c, fiber.Map{"verified": true})
	}
	if !a.auth.EmailOTPEnabled() {
		return httputil.Err(c, fiber.StatusServiceUnavailable, "UNAVAILABLE", "email verification unavailable")
	}
	if err := a.auth.RequestEmailOTP(ctx, *st.Email); err != nil {
		msg := strings.ToLower(err.Error())
		if strings.Contains(msg, "cooldown") || strings.Contains(msg, "wait") {
			return httputil.Err(c, fiber.StatusTooManyRequests, httputil.ErrRateLimited, "please wait before requesting another code")
		}
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "send failed")
	}
	return httputil.OK(c, fiber.Map{"sent": true})
}

type confirmVerifyReq struct {
	Code string `json:"code"`
}

// ConfirmVerify handles POST /account/verify-email
func (a *Account) ConfirmVerify(c *fiber.Ctx) error {
	uid := middleware.UserID(c)

	var r confirmVerifyReq
	if err := c.BodyParser(&r); err != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid body")
	}
	code := strings.TrimSpace(r.Code)
	if len(code) < 4 || len(code) > 8 {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "code must be 4..8 digits")
	}
	for _, ch := range code {
		if ch < '0' || ch > '9' {
			return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "code must be 4..8 digits")
		}
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	st, err := a.svc.Status(ctx, uid)
	if err != nil {
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "query failed")
	}
	if st.Email == nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "no email on this account")
	}
	if _, err := a.auth.VerifyEmailOTP(ctx, *st.Email, code); err != nil {
		if errors.Is(err, services.ErrUnauthorized) {
			return httputil.Err(c, fiber.StatusUnauthorized, httputil.ErrUnauthorized, "wrong or expired code")
		}
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "verify failed")
	}
	if err := a.svc.MarkEmailVerified(ctx, uid); err != nil {
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "update failed")
	}
	return httputil.OK(c, fiber.Map{"verified": true})
}

// ListReports handles GET /admin/reports?status=open
func (a *Account) ListReports(c *fiber.Ctx) error {
	uid := middleware.UserID(c)

	status := c.Query("status", "open")
	if status != "open" && status != "dismissed" && status != "actioned" {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "status must be open, dismissed or actioned")
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	list, err := a.svc.ListReports(ctx, status)
	if err != nil {
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "query failed")
	}
	_ = uid
	return httputil.OK(c, list)
}

type resolveReportReq struct {
	Action string `json:"action"`
}

// ResolveReport handles POST /admin/reports/:id/resolve
func (a *Account) ResolveReport(c *fiber.Ctx) error {
	adminID := middleware.UserID(c)
	reportID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid report id")
	}
	var r resolveReportReq
	if err := c.BodyParser(&r); err != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid body")
	}
	action := strings.TrimSpace(r.Action)

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	if err := a.svc.ResolveReport(ctx, reportID, adminID, action); err != nil {
		if errors.Is(err, services.ErrBadAction) {
			return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "action must be dismiss or suspend")
		}
		if errors.Is(err, services.ErrNotFound) {
			return httputil.Err(c, fiber.StatusNotFound, httputil.ErrNotFound, "report not found")
		}
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "resolve failed")
	}
	return httputil.OK(c, fiber.Map{"resolved": true})
}

// Unsuspend handles POST /admin/users/:id/unsuspend
func (a *Account) Unsuspend(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	userID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid user id")
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	if err := a.svc.Unsuspend(ctx, userID); err != nil {
		if errors.Is(err, services.ErrNotFound) {
			return httputil.Err(c, fiber.StatusNotFound, httputil.ErrNotFound, "user not found")
		}
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "unsuspend failed")
	}
	_ = uid
	return httputil.OK(c, fiber.Map{"unsuspended": true})
}
