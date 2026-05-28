package services

import (
	"context"

	"github.com/anmates/api/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type UserService struct {
	pool *pgxpool.Pool
}

func NewUserService(pool *pgxpool.Pool) *UserService { return &UserService{pool: pool} }

func (s *UserService) GetProfile(ctx context.Context, userID uuid.UUID) (*models.User, error) {
	var u models.User
	err := s.pool.QueryRow(ctx, `
		SELECT id, name, email, avatar_url, bio FROM users WHERE id = $1
	`, userID).Scan(&u.ID, &u.Name, &u.Email, &u.AvatarURL, &u.Bio)
	if err != nil {
		return nil, ErrNotFound
	}
	return &u, nil
}

func (s *UserService) UpdateProfile(ctx context.Context, userID uuid.UUID, name, avatarURL, bio *string) (*models.User, error) {
	var u models.User
	err := s.pool.QueryRow(ctx, `
		UPDATE users SET
			name       = COALESCE($2, name),
			avatar_url = COALESCE($3, avatar_url),
			bio        = COALESCE($4, bio)
		WHERE id = $1
		RETURNING id, name, email, avatar_url, bio
	`, userID, name, avatarURL, bio).Scan(
		&u.ID, &u.Name, &u.Email, &u.AvatarURL, &u.Bio)
	if err != nil {
		return nil, err
	}
	return &u, nil
}
