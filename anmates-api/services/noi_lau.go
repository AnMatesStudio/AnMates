package services

import (
	"context"
	"errors"

	"github.com/anmates/api/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type NoiLauService struct {
	pool *pgxpool.Pool
}

func NewNoiLauService(pool *pgxpool.Pool) *NoiLauService { return &NoiLauService{pool: pool} }

// IsMember checks whether userID is a participant in the given match.
func (s *NoiLauService) IsMember(ctx context.Context, matchID, userID uuid.UUID) bool {
	var ok bool
	_ = s.pool.QueryRow(ctx, `
		SELECT EXISTS(SELECT 1 FROM matches
			WHERE id = $1 AND (user_a_id = $2 OR user_b_id = $2))
	`, matchID, userID).Scan(&ok)
	return ok
}

// GetProgress returns the Nồi Lẩu progress for a match. Returns a zero-state if no row exists yet.
func (s *NoiLauService) GetProgress(ctx context.Context, matchID uuid.UUID) (*models.NoiLauProgress, error) {
	p := &models.NoiLauProgress{MatchID: matchID, Points: 0, Level: 1}
	err := s.pool.QueryRow(ctx, `
		SELECT points, level, last_activity FROM noi_lau_progress WHERE match_id = $1
	`, matchID).Scan(&p.Points, &p.Level, &p.LastActivity)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return nil, err
	}
	p.NextThreshold = models.NextThreshold(p.Points)
	p.Locked = p.Level >= 3
	return p, nil
}
