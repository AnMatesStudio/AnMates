package services

import (
	"context"
	"errors"

	"github.com/anmates/api/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type MatchingService struct {
	pool *pgxpool.Pool
}

func NewMatchingService(pool *pgxpool.Pool) *MatchingService { return &MatchingService{pool: pool} }

func (s *MatchingService) ListCandidates(ctx context.Context, userID uuid.UUID) ([]models.MatchCandidate, error) {
	const q = `
		WITH my_foods AS (
			SELECT DISTINCT food_name FROM wishlists WHERE user_id = $1
		),
		my_count AS (SELECT COUNT(*)::int AS c FROM my_foods),
		theirs AS (
			SELECT
				w.user_id,
				COUNT(*) FILTER (WHERE w.food_name IN (SELECT food_name FROM my_foods))::int AS overlap,
				COUNT(*)::int AS their_count,
				array_agg(DISTINCT w.food_name)
					FILTER (WHERE w.food_name IN (SELECT food_name FROM my_foods)) AS overlap_foods
			FROM wishlists w
			WHERE w.user_id <> $1
			  AND NOT EXISTS (
				SELECT 1 FROM matches m
				WHERE (m.user_a_id = $1 AND m.user_b_id = w.user_id)
				   OR (m.user_a_id = w.user_id AND m.user_b_id = $1)
			  )
			GROUP BY w.user_id
		)
		SELECT u.id, u.name, u.avatar_url,
		       t.overlap, t.overlap_foods,
		       (t.overlap::float / NULLIF(mc.c + t.their_count - t.overlap, 0)) AS score
		FROM theirs t
		JOIN users u ON u.id = t.user_id
		CROSS JOIN my_count mc
		WHERE t.overlap >= 2
		ORDER BY score DESC, t.overlap DESC
		LIMIT 50
	`
	rows, err := s.pool.Query(ctx, q, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]models.MatchCandidate, 0, 16)
	for rows.Next() {
		var mc models.MatchCandidate
		if err := rows.Scan(&mc.UserID, &mc.Name, &mc.AvatarURL,
			&mc.OverlapCount, &mc.OverlapFoods, &mc.Score); err != nil {
			return nil, err
		}
		out = append(out, mc)
	}
	return out, nil
}

// AcceptMatch creates a match between userID and targetID. Idempotent: returns the existing
// match if one already exists in either direction.
func (s *MatchingService) AcceptMatch(ctx context.Context, userID, targetID uuid.UUID) (*models.Match, error) {
	var match models.Match
	err := s.pool.QueryRow(ctx, `
		SELECT id, user_a_id, user_b_id, status, score, created_at FROM matches
		WHERE (user_a_id = $1 AND user_b_id = $2) OR (user_a_id = $2 AND user_b_id = $1)
	`, userID, targetID).Scan(&match.ID, &match.UserAID, &match.UserBID, &match.Status, &match.Score, &match.CreatedAt)
	if err == nil {
		return &match, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return nil, err
	}

	var score float64
	if err := s.pool.QueryRow(ctx, `
		WITH a AS (SELECT DISTINCT food_name FROM wishlists WHERE user_id = $1),
		     b AS (SELECT DISTINCT food_name FROM wishlists WHERE user_id = $2),
		     inter AS (SELECT COUNT(*)::float c FROM a JOIN b USING (food_name)),
		     uni   AS (SELECT COUNT(*)::float c FROM (SELECT food_name FROM a UNION SELECT food_name FROM b) u)
		SELECT CASE WHEN uni.c = 0 THEN 0 ELSE inter.c / uni.c END FROM inter, uni
	`, userID, targetID).Scan(&score); err != nil {
		return nil, err
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	err = tx.QueryRow(ctx, `
		INSERT INTO matches (user_a_id, user_b_id, status, score)
		VALUES ($1, $2, 'accepted', $3)
		RETURNING id, user_a_id, user_b_id, status, score, created_at
	`, userID, targetID, score).Scan(
		&match.ID, &match.UserAID, &match.UserBID, &match.Status, &match.Score, &match.CreatedAt)
	if err != nil {
		if isUniqueViolation(err) {
			_ = tx.Rollback(ctx)
			err = s.pool.QueryRow(ctx, `
				SELECT id, user_a_id, user_b_id, status, score, created_at FROM matches
				WHERE (user_a_id = $1 AND user_b_id = $2) OR (user_a_id = $2 AND user_b_id = $1)
			`, userID, targetID).Scan(&match.ID, &match.UserAID, &match.UserBID, &match.Status, &match.Score, &match.CreatedAt)
			if err != nil {
				return nil, err
			}
			return &match, nil
		}
		return nil, err
	}

	if _, err := tx.Exec(ctx,
		`INSERT INTO noi_lau_progress (match_id, points, level) VALUES ($1, 0, 1)`,
		match.ID,
	); err != nil {
		return nil, err
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return &match, nil
}

func (s *MatchingService) Conversations(ctx context.Context, userID uuid.UUID) ([]models.Conversation, error) {
	const q = `
		SELECT
			mt.id AS match_id,
			CASE WHEN mt.user_a_id = $1 THEN mt.user_b_id ELSE mt.user_a_id END AS partner_id,
			u.name AS partner_name,
			u.avatar_url,
			last_msg.content,
			last_msg.created_at AS last_message_at,
			mt.score,
			mt.created_at
		FROM matches mt
		JOIN users u ON u.id = CASE WHEN mt.user_a_id = $1 THEN mt.user_b_id ELSE mt.user_a_id END
		LEFT JOIN LATERAL (
			SELECT content, created_at FROM messages
			WHERE match_id = mt.id
			ORDER BY created_at DESC LIMIT 1
		) last_msg ON true
		WHERE mt.user_a_id = $1 OR mt.user_b_id = $1
		ORDER BY COALESCE(last_msg.created_at, mt.created_at) DESC
	`
	rows, err := s.pool.Query(ctx, q, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]models.Conversation, 0, 16)
	for rows.Next() {
		var cv models.Conversation
		if err := rows.Scan(
			&cv.MatchID, &cv.PartnerID, &cv.PartnerName, &cv.PartnerAvatarURL,
			&cv.LastMessage, &cv.LastMessageAt, &cv.Score, &cv.CreatedAt,
		); err != nil {
			return nil, err
		}
		out = append(out, cv)
	}
	return out, nil
}
