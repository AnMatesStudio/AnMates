package services

import (
	"context"
	"fmt"

	"github.com/anmates/api/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

var AllowedCategories = map[string]struct{}{
	"bun": {}, "pho": {}, "com": {}, "lau": {}, "bbq": {},
	"cafe": {}, "trang_mieng": {}, "other": {},
}

type WishlistService struct {
	pool *pgxpool.Pool
}

func NewWishlistService(pool *pgxpool.Pool) *WishlistService { return &WishlistService{pool: pool} }

func (s *WishlistService) List(ctx context.Context, userID uuid.UUID) ([]models.Wishlist, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT id, user_id, food_name, food_category, created_at
		FROM wishlists WHERE user_id = $1 ORDER BY created_at DESC
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := make([]models.Wishlist, 0, 16)
	for rows.Next() {
		var it models.Wishlist
		if err := rows.Scan(&it.ID, &it.UserID, &it.FoodName, &it.FoodCategory, &it.CreatedAt); err != nil {
			return nil, err
		}
		items = append(items, it)
	}
	return items, nil
}

func (s *WishlistService) Create(ctx context.Context, userID uuid.UUID, foodName, category string) (*models.Wishlist, error) {
	var item models.Wishlist
	err := s.pool.QueryRow(ctx, `
		INSERT INTO wishlists (user_id, food_name, food_category)
		VALUES ($1, $2, $3)
		RETURNING id, user_id, food_name, food_category, created_at
	`, userID, foodName, category).Scan(
		&item.ID, &item.UserID, &item.FoodName, &item.FoodCategory, &item.CreatedAt)
	if err != nil {
		if isUniqueViolation(err) {
			return nil, fmt.Errorf("%w: food already in wishlist", ErrDuplicate)
		}
		return nil, err
	}
	return &item, nil
}

func (s *WishlistService) Delete(ctx context.Context, userID, itemID uuid.UUID) error {
	tag, err := s.pool.Exec(ctx,
		`DELETE FROM wishlists WHERE id = $1 AND user_id = $2`, itemID, userID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
