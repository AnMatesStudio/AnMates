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

type Wishlist struct {
	svc services.WishlistServicer
}

func NewWishlist(svc services.WishlistServicer) *Wishlist { return &Wishlist{svc: svc} }

type wishlistCreateReq struct {
	FoodName     string `json:"food_name"`
	FoodCategory string `json:"food_category"`
}

func (w *Wishlist) List(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	items, err := w.svc.List(ctx, uid)
	if err != nil {
		return httputil.Err(c,fiber.StatusInternalServerError, httputil.ErrInternal, "query failed")
	}
	return httputil.OK(c,items)
}

func (w *Wishlist) Create(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	var r wishlistCreateReq
	if err := c.BodyParser(&r); err != nil {
		return httputil.Err(c,fiber.StatusBadRequest, httputil.ErrValidation, "invalid body")
	}
	r.FoodName = strings.TrimSpace(r.FoodName)
	r.FoodCategory = strings.TrimSpace(strings.ToLower(r.FoodCategory))
	if r.FoodName == "" || len(r.FoodName) > 100 {
		return httputil.Err(c,fiber.StatusBadRequest, httputil.ErrValidation, "food_name required (1..100)")
	}
	if _, ok := services.AllowedCategories[r.FoodCategory]; !ok {
		return httputil.Err(c,fiber.StatusBadRequest, httputil.ErrValidation, "invalid food_category")
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	item, err := w.svc.Create(ctx, uid, r.FoodName, r.FoodCategory)
	if err != nil {
		if errors.Is(err, services.ErrDuplicate) {
			return httputil.Err(c,fiber.StatusConflict, httputil.ErrConflict, "food already in wishlist")
		}
		return httputil.Err(c,fiber.StatusInternalServerError, httputil.ErrInternal, "insert failed")
	}
	return c.Status(fiber.StatusCreated).JSON(httputil.SuccessEnvelope{Success: true, Data: item})
}

func (w *Wishlist) Delete(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	id, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return httputil.Err(c,fiber.StatusBadRequest, httputil.ErrValidation, "invalid id")
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	if err := w.svc.Delete(ctx, uid, id); err != nil {
		if errors.Is(err, services.ErrNotFound) {
			return httputil.Err(c,fiber.StatusNotFound, httputil.ErrNotFound, "wishlist item not found")
		}
		return httputil.Err(c,fiber.StatusInternalServerError, httputil.ErrInternal, "delete failed")
	}
	return httputil.OK(c,fiber.Map{"deleted": id})
}
