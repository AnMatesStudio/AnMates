package httputil

import "github.com/gofiber/fiber/v2"

// Error codes — keep in sync with API spec.
const (
	ErrUnauthorized  = "UNAUTHORIZED"
	ErrNotFound      = "NOT_FOUND"
	ErrValidation    = "VALIDATION_ERROR"
	ErrMatchNotFound = "MATCH_NOT_FOUND"
	ErrChatLocked    = "CHAT_LOCKED"
	ErrRateLimited   = "RATE_LIMITED"
	ErrConflict      = "CONFLICT"
	ErrInternal      = "INTERNAL"
)

type SuccessEnvelope struct {
	Success bool        `json:"success"`
	Data    interface{} `json:"data"`
	Meta    *Meta       `json:"meta,omitempty"`
}

type ErrorEnvelope struct {
	Success bool      `json:"success"`
	Error   ErrorBody `json:"error"`
}

type ErrorBody struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

type Meta struct {
	Page  *int `json:"page,omitempty"`
	Total *int `json:"total,omitempty"`
}

func OK(c *fiber.Ctx, data interface{}) error {
	return c.JSON(SuccessEnvelope{Success: true, Data: data})
}

func OKWithMeta(c *fiber.Ctx, data interface{}, meta Meta) error {
	return c.JSON(SuccessEnvelope{Success: true, Data: data, Meta: &meta})
}

func Err(c *fiber.Ctx, status int, code, msg string) error {
	return c.Status(status).JSON(ErrorEnvelope{
		Success: false,
		Error:   ErrorBody{Code: code, Message: msg},
	})
}
