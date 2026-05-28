package services

import (
	"context"
	"time"

	"github.com/anmates/api/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type ChatService struct {
	pool *pgxpool.Pool
}

func NewChatService(pool *pgxpool.Pool) *ChatService { return &ChatService{pool: pool} }

// IsMember checks whether userID is a participant in the given match.
func (s *ChatService) IsMember(ctx context.Context, matchID, userID uuid.UUID) bool {
	var ok bool
	_ = s.pool.QueryRow(ctx, `
		SELECT EXISTS(SELECT 1 FROM matches
			WHERE id = $1 AND (user_a_id = $2 OR user_b_id = $2))
	`, matchID, userID).Scan(&ok)
	return ok
}

// History returns paginated messages for a match (newest-first if no cursor, older-than-cursor otherwise).
// cursor must be RFC3339Nano or empty; caller is responsible for validation.
func (s *ChatService) History(ctx context.Context, matchID uuid.UUID, cursor string, limit int) ([]models.Message, error) {
	var (
		rows pgx.Rows
		err  error
	)
	if cursor == "" {
		rows, err = s.pool.Query(ctx, `
			SELECT id, match_id, sender_id, content, msg_type, created_at
			FROM messages WHERE match_id = $1
			ORDER BY created_at DESC LIMIT $2
		`, matchID, limit)
	} else {
		t, _ := time.Parse(time.RFC3339Nano, cursor) // pre-validated by caller
		rows, err = s.pool.Query(ctx, `
			SELECT id, match_id, sender_id, content, msg_type, created_at
			FROM messages WHERE match_id = $1 AND created_at < $2
			ORDER BY created_at DESC LIMIT $3
		`, matchID, t, limit)
	}
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]models.Message, 0, limit)
	for rows.Next() {
		var m models.Message
		if err := rows.Scan(&m.ID, &m.MatchID, &m.SenderID, &m.Content, &m.MsgType, &m.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	return out, nil
}

// CheckPaywall returns true if the match has reached the level-3 lock.
func (s *ChatService) CheckPaywall(ctx context.Context, matchID uuid.UUID) (locked bool, err error) {
	var lvl int
	err = s.pool.QueryRow(ctx,
		`SELECT level FROM noi_lau_progress WHERE match_id = $1`, matchID,
	).Scan(&lvl)
	if err != nil {
		return false, nil // no row yet → not locked
	}
	return lvl >= 3, nil
}

// SaveMessage persists a message and returns the saved row.
func (s *ChatService) SaveMessage(ctx context.Context, matchID, senderID uuid.UUID, content, msgType string) (*models.Message, error) {
	var saved models.Message
	err := s.pool.QueryRow(ctx, `
		INSERT INTO messages (match_id, sender_id, content, msg_type)
		VALUES ($1, $2, $3, $4)
		RETURNING id, match_id, sender_id, content, msg_type, created_at
	`, matchID, senderID, content, msgType).Scan(
		&saved.ID, &saved.MatchID, &saved.SenderID, &saved.Content, &saved.MsgType, &saved.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &saved, nil
}

// IncrementPoints adds +1 point (plus streak bonus) to the Nồi Lẩu progress for a match.
// Level is recomputed using the canonical models.LevelForPoints so there is a single
// source of truth for the threshold table.
// Errors are intentionally swallowed so a DB hiccup never silently drops the message.
func (s *ChatService) IncrementPoints(ctx context.Context, matchID uuid.UUID) {
	var newPoints int
	err := s.pool.QueryRow(ctx, `
		UPDATE noi_lau_progress
		SET points = points + 1 + CASE
		      WHEN last_activity IS NOT NULL
		       AND last_activity::date = (CURRENT_DATE - INTERVAL '1 day')::date
		      THEN 5 ELSE 0 END,
		    last_activity = now()
		WHERE match_id = $1
		RETURNING points
	`, matchID).Scan(&newPoints)
	if err != nil {
		return
	}
	newLevel := models.LevelForPoints(newPoints)
	_, _ = s.pool.Exec(ctx,
		`UPDATE noi_lau_progress SET level = $1 WHERE match_id = $2`,
		newLevel, matchID,
	)
}
