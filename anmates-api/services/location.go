package services

import (
	"context"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// LocationService stores the last-known coarse location per user. Used to compute
// the meetup midpoint for the AI Concierge. Never exposed to other users.
type LocationService struct {
	pool *pgxpool.Pool
}

func NewLocationService(pool *pgxpool.Pool) *LocationService { return &LocationService{pool: pool} }

// Upsert writes (or replaces) the caller's last-known location.
func (s *LocationService) Upsert(ctx context.Context, userID uuid.UUID, lat, lng float64, district string) error {
	var districtPtr *string
	if district != "" {
		districtPtr = &district
	}
	_, err := s.pool.Exec(ctx, `
		INSERT INTO user_locations (user_id, lat, lng, district, updated_at)
		VALUES ($1, $2, $3, $4, now())
		ON CONFLICT (user_id) DO UPDATE
		SET lat = EXCLUDED.lat, lng = EXCLUDED.lng,
		    district = EXCLUDED.district, updated_at = now()
	`, userID, lat, lng, districtPtr)
	return err
}
