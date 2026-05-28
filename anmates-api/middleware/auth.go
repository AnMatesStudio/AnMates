package middleware

import (
	"errors"
	"strings"
	"time"

	"github.com/anmates/api/internal/httputil"
	"github.com/gofiber/fiber/v2"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

const (
	ctxUserIDKey = "anmates.user_id"
	jwtIssuer    = "anmates"
	jwtAudience  = "anmates-mobile"
)

type Claims struct {
	UserID uuid.UUID `json:"sub"`
	jwt.RegisteredClaims
}

// SignAccessToken issues a short-lived JWT for an authenticated user.
func SignAccessToken(secret []byte, userID uuid.UUID, ttl time.Duration) (string, time.Time, error) {
	exp := time.Now().Add(ttl)
	claims := Claims{
		UserID: userID,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   userID.String(),
			Issuer:    jwtIssuer,
			Audience:  jwt.ClaimStrings{jwtAudience},
			ExpiresAt: jwt.NewNumericDate(exp),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			NotBefore: jwt.NewNumericDate(time.Now()),
			ID:        uuid.NewString(),
		},
	}
	t := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	s, err := t.SignedString(secret)
	return s, exp, err
}

// JWT validates the Bearer token and stores the user id in fiber locals.
func JWT(secret []byte) fiber.Handler {
	return func(c *fiber.Ctx) error {
		if err := ValidateBearer(c, secret); err != nil {
			return err
		}
		return c.Next()
	}
}

// ValidateBearer parses the Authorization header (or `access_token` query),
// validates the JWT, and stores the user id in fiber locals. Does NOT call
// c.Next() — callers that aren't pure middleware can chain manually.
func ValidateBearer(c *fiber.Ctx, secret []byte) error {
	raw := c.Get("Authorization")
	if raw == "" {
		if tok := c.Query("access_token"); tok != "" {
			raw = "Bearer " + tok
		}
	}
	if !strings.HasPrefix(raw, "Bearer ") {
		return httputil.Err(c, fiber.StatusUnauthorized, httputil.ErrUnauthorized, "missing bearer token")
	}
	uid, err := parseToken(raw[len("Bearer "):], secret)
	if err != nil {
		return httputil.Err(c, fiber.StatusUnauthorized, httputil.ErrUnauthorized, "invalid token")
	}
	c.Locals(ctxUserIDKey, uid)
	return nil
}

// UserID returns the authenticated user id stored by the JWT middleware.
// Returns uuid.Nil if no token was validated for this request.
func UserID(c *fiber.Ctx) uuid.UUID {
	v, ok := c.Locals(ctxUserIDKey).(uuid.UUID)
	if !ok {
		return uuid.Nil
	}
	return v
}

func parseToken(tok string, secret []byte) (uuid.UUID, error) {
	claims := &Claims{}
	parsed, err := jwt.ParseWithClaims(tok, claims, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("unexpected signing method")
		}
		return secret, nil
	}, jwt.WithIssuer(jwtIssuer), jwt.WithAudience(jwtAudience))
	if err != nil || !parsed.Valid {
		return uuid.Nil, errors.New("invalid token")
	}
	return claims.UserID, nil
}
