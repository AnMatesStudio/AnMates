package services

import "errors"

var (
	ErrDuplicate    = errors.New("duplicate")
	ErrNotFound     = errors.New("not found")
	ErrUnauthorized = errors.New("unauthorized")
	ErrForbidden    = errors.New("forbidden")
)
