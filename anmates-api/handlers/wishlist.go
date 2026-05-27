package handlers

import (
	"context"
	"strings"
	"time"

	"github.com/anmates/api/middleware"
	"github.com/anmates/api/models"
	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Wishlist struct {
	pool *pgxpool.Pool
}

func NewWishlist(pool *pgxpool.Pool) *Wishlist { return &Wishlist{pool: pool} }

var allowedCategories = map[string]struct{}{
	"bun": {}, "pho": {}, "com": {}, "lau": {}, "bbq": {},
	"cafe": {}, "trang_mieng": {}, "other": {},
}

type wishlistCreateReq struct {
	FoodName     string `json:"food_name"`
	FoodCategory string `json:"food_category"`
}

func (w *Wishlist) List(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	rows, err := w.pool.Query(ctx, `
		SELECT id, user_id, food_name, food_category, created_at
		FROM wishlists WHERE user_id = $1 ORDER BY created_at DESC
	`, uid)
	if err != nil {
		return models.Err(c, fiber.StatusInternalServerError, models.ErrInternal, "query failed")
	}
	defer rows.Close()

	items := make([]models.Wishlist, 0, 16)
	for rows.Next() {
		var it models.Wishlist
		if err := rows.Scan(&it.ID, &it.UserID, &it.FoodName, &it.FoodCategory, &it.CreatedAt); err != nil {
			return models.Err(c, fiber.StatusInternalServerError, models.ErrInternal, "scan failed")
		}
		items = append(items, it)
	}
	return models.OK(c, items)
}

func (w *Wishlist) Create(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	var r wishlistCreateReq
	if err := c.BodyParser(&r); err != nil {
		return models.Err(c, fiber.StatusBadRequest, models.ErrValidation, "invalid body")
	}
	r.FoodName = strings.TrimSpace(r.FoodName)
	r.FoodCategory = strings.TrimSpace(strings.ToLower(r.FoodCategory))
	if r.FoodName == "" || len(r.FoodName) > 100 {
		return models.Err(c, fiber.StatusBadRequest, models.ErrValidation, "food_name required (1..100)")
	}
	if _, ok := allowedCategories[r.FoodCategory]; !ok {
		return models.Err(c, fiber.StatusBadRequest, models.ErrValidation, "invalid food_category")
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	var item models.Wishlist
	err := w.pool.QueryRow(ctx, `
		INSERT INTO wishlists (user_id, food_name, food_category)
		VALUES ($1, $2, $3)
		RETURNING id, user_id, food_name, food_category, created_at
	`, uid, r.FoodName, r.FoodCategory).Scan(
		&item.ID, &item.UserID, &item.FoodName, &item.FoodCategory, &item.CreatedAt)
	if err != nil {
		if isUniqueViolation(err) {
			return models.Err(c, fiber.StatusConflict, models.ErrConflict, "food already in wishlist")
		}
		return models.Err(c, fiber.StatusInternalServerError, models.ErrInternal, "insert failed")
	}
	return c.Status(fiber.StatusCreated).JSON(models.SuccessEnvelope{Success: true, Data: item})
}

func (w *Wishlist) Delete(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	id, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return models.Err(c, fiber.StatusBadRequest, models.ErrValidation, "invalid id")
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	tag, err := w.pool.Exec(ctx,
		`DELETE FROM wishlists WHERE id = $1 AND user_id = $2`, id, uid)
	if err != nil {
		return models.Err(c, fiber.StatusInternalServerError, models.ErrInternal, "delete failed")
	}
	if tag.RowsAffected() == 0 {
		return models.Err(c, fiber.StatusNotFound, models.ErrNotFound, "wishlist item not found")
	}
	return models.OK(c, fiber.Map{"deleted": id})
}
