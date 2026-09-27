package services

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// ReportReasons are the values the user_reports.reason CHECK allows.
var ReportReasons = map[string]struct{}{
	"spam": {}, "harassment": {}, "fake_profile": {}, "no_show": {}, "inappropriate": {}, "other": {},
}

type BlockedUser struct {
	UserID    uuid.UUID `json:"user_id"`
	Name      string    `json:"name"`
	CreatedAt time.Time `json:"created_at"`
}

type SafetyService struct{ pool *pgxpool.Pool }

func NewSafetyService(pool *pgxpool.Pool) *SafetyService { return &SafetyService{pool: pool} }

// Unmatch deletes a match for one of its two users (messages/bookings/ratings cascade).
func (s *SafetyService) Unmatch(ctx context.Context, matchID, userID uuid.UUID) error {
	tag, err := s.pool.Exec(ctx,
		`DELETE FROM matches WHERE id = $1 AND (user_a_id = $2 OR user_b_id = $2)`,
		matchID, userID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// Block inserts a user_block and clears any match and swipes between the two users.
func (s *SafetyService) Block(ctx context.Context, blockerID, blockedID uuid.UUID) error {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	if _, err := tx.Exec(ctx,
		`INSERT INTO user_blocks (blocker_id, blocked_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
		blockerID, blockedID); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx,
		`DELETE FROM matches WHERE (user_a_id = $1 AND user_b_id = $2) OR (user_a_id = $2 AND user_b_id = $1)`,
		blockerID, blockedID); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx,
		`DELETE FROM swipes WHERE (user_id = $1 AND target_id = $2) OR (user_id = $2 AND target_id = $1)`,
		blockerID, blockedID); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

// Unblock removes a user_block row if it exists.
func (s *SafetyService) Unblock(ctx context.Context, blockerID, blockedID uuid.UUID) error {
	_, err := s.pool.Exec(ctx,
		`DELETE FROM user_blocks WHERE blocker_id = $1 AND blocked_id = $2`,
		blockerID, blockedID)
	return err
}

// ListBlocked returns the users the given user has blocked, newest first.
func (s *SafetyService) ListBlocked(ctx context.Context, blockerID uuid.UUID) ([]BlockedUser, error) {
	rows, err := s.pool.Query(ctx, `
SELECT b.blocked_id, u.name, b.created_at
FROM user_blocks b JOIN users u ON u.id = b.blocked_id
WHERE b.blocker_id = $1 ORDER BY b.created_at DESC`, blockerID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	users := make([]BlockedUser, 0, 16)
	for rows.Next() {
		var (
			b   BlockedUser
			name *string
		)
		if err := rows.Scan(&b.UserID, &name, &b.CreatedAt); err != nil {
			return nil, err
		}
		if name != nil {
			b.Name = *name
		}
		users = append(users, b)
	}
	return users, rows.Err()
}

// Report inserts a user report and returns its id.
func (s *SafetyService) Report(ctx context.Context, reporterID, reportedID uuid.UUID, reason, note string) (uuid.UUID, error) {
	var id uuid.UUID
	err := s.pool.QueryRow(ctx,
		`INSERT INTO user_reports (reporter_id, reported_id, reason, note) VALUES ($1, $2, $3, $4) RETURNING id`,
		reporterID, reportedID, reason, note).Scan(&id)
	if err != nil {
		return uuid.UUID{}, err
	}
	return id, nil
}
