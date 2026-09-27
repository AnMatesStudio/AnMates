package middleware

import (
	"context"
	"time"

	"github.com/anmates/api/internal/httputil"
	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
)

// AccountGater is what the account middlewares need (services.AccountService satisfies it).
type AccountGater interface {
	Gate(ctx context.Context, userID uuid.UUID) (suspended, unverified bool, err error)
	IsAdmin(ctx context.Context, userID uuid.UUID) (bool, error)
}

// AccountGate blocks suspended or unverified users on routes that put them in front of other people.
func AccountGate(g AccountGater) fiber.Handler {
	return func(c *fiber.Ctx) error {
		ctx, cancel := context.WithTimeout(c.UserContext(), 10*time.Second)
		defer cancel()
		suspended, unverified, err := g.Gate(ctx, UserID(c))
		if err != nil {
			return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "account check failed")
		}
		if suspended {
			return httputil.Err(c, fiber.StatusForbidden, "ACCOUNT_SUSPENDED", "account suspended")
		}
		if unverified {
			return httputil.Err(c, fiber.StatusForbidden, "EMAIL_UNVERIFIED", "verify your email first")
		}
		return c.Next()
	}
}

// AdminOnly lets only admins through.
func AdminOnly(g AccountGater) fiber.Handler {
	return func(c *fiber.Ctx) error {
		ctx, cancel := context.WithTimeout(c.UserContext(), 10*time.Second)
		defer cancel()
		isAdmin, err := g.IsAdmin(ctx, UserID(c))
		if err != nil {
			return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "account check failed")
		}
		if !isAdmin {
			return httputil.Err(c, fiber.StatusForbidden, "FORBIDDEN", "admins only")
		}
		return c.Next()
	}
}
