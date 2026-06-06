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

// SwipeResult is returned by Swipe: Matched is true only when the swipe
// reciprocated an existing like and a match was created/found.
type SwipeResult struct {
	Matched bool          `json:"matched"`
	Match   *models.Match `json:"match,omitempty"`
}

// ListCandidates ranks other onboarded users by shared "interests" — the union
// of their onboarding food_tags and their wishlist food names (lower/trimmed so
// "Lẩu Thái" and "lẩu thái" collapse). Excludes self, already-matched pairs, and
// anyone the caller has already swiped (like or pass). Threshold: >= 2 shared
// interests. Output columns match models.MatchCandidate.
func (s *MatchingService) ListCandidates(ctx context.Context, userID uuid.UUID) ([]models.MatchCandidate, error) {
	// Interest set per user = onboarding food_tags ∪ wishlist food names ∪ wishlist
	// food categories. The three vocabularies are disjoint (food_tags like 'spicy'
	// vs categories like 'lau' vs free-text names) so they never collide; together
	// they give both coarse (category) and specific (dish) overlap signals.
	const q = `
		WITH tags AS (
			SELECT u.id AS user_id, lower(trim(t)) AS tag
			FROM users u
			CROSS JOIN LATERAL unnest(COALESCE(u.food_tags, '{}'::text[])) AS t
			WHERE u.onboarding_done = TRUE
			UNION
			SELECT w.user_id, lower(trim(w.food_name))
			FROM wishlists w
			JOIN users u2 ON u2.id = w.user_id AND u2.onboarding_done = TRUE
			UNION
			SELECT w.user_id, lower(trim(w.food_category))
			FROM wishlists w
			JOIN users u3 ON u3.id = w.user_id AND u3.onboarding_done = TRUE
		),
		interests AS (
			SELECT user_id, array_agg(DISTINCT tag) FILTER (WHERE tag <> '') AS tags
			FROM tags
			GROUP BY user_id
		),
		me AS (
			SELECT COALESCE((SELECT tags FROM interests WHERE user_id = $1), '{}'::text[]) AS tags
		)
		SELECT c.user_id, u.name, u.avatar_url, c.overlap_count, c.overlap_foods,
		       (c.overlap_count::float / NULLIF(c.union_count, 0)) AS score
		FROM (
			SELECT i.user_id,
			       cardinality(ARRAY(
			           SELECT unnest(COALESCE(i.tags, '{}'::text[]))
			           INTERSECT SELECT unnest(me.tags))) AS overlap_count,
			       ARRAY(
			           SELECT unnest(COALESCE(i.tags, '{}'::text[]))
			           INTERSECT SELECT unnest(me.tags)) AS overlap_foods,
			       cardinality(ARRAY(
			           SELECT unnest(COALESCE(i.tags, '{}'::text[]))
			           UNION SELECT unnest(me.tags))) AS union_count
			FROM interests i CROSS JOIN me
			WHERE i.user_id <> $1
			  AND NOT EXISTS (
				SELECT 1 FROM matches m
				WHERE (m.user_a_id = $1 AND m.user_b_id = i.user_id)
				   OR (m.user_a_id = i.user_id AND m.user_b_id = $1)
			  )
			  AND NOT EXISTS (
				SELECT 1 FROM swipes sw WHERE sw.user_id = $1 AND sw.target_id = i.user_id
			  )
		) c
		JOIN users u ON u.id = c.user_id
		WHERE c.overlap_count >= 2
		ORDER BY score DESC, c.overlap_count DESC
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
	return out, rows.Err()
}

// Swipe records the caller's decision on targetID. A pass (liked=false) only
// records the decision. A like (liked=true) records it and, if the target has
// already liked the caller, creates (or returns the existing) match.
func (s *MatchingService) Swipe(ctx context.Context, userID, targetID uuid.UUID, liked bool) (*SwipeResult, error) {
	if _, err := s.pool.Exec(ctx, `
		INSERT INTO swipes (user_id, target_id, liked)
		VALUES ($1, $2, $3)
		ON CONFLICT (user_id, target_id)
		DO UPDATE SET liked = EXCLUDED.liked, created_at = now()
	`, userID, targetID, liked); err != nil {
		return nil, err
	}

	if !liked {
		return &SwipeResult{Matched: false}, nil
	}

	var reciprocated bool
	if err := s.pool.QueryRow(ctx, `
		SELECT EXISTS(
			SELECT 1 FROM swipes WHERE user_id = $1 AND target_id = $2 AND liked = TRUE
		)
	`, targetID, userID).Scan(&reciprocated); err != nil {
		return nil, err
	}
	if !reciprocated {
		return &SwipeResult{Matched: false}, nil
	}

	match, err := s.createMatch(ctx, userID, targetID)
	if err != nil {
		return nil, err
	}
	return &SwipeResult{Matched: true, Match: match}, nil
}

// Undo removes the caller's most recent swipe so the candidate can resurface.
// If that swipe had already produced a match the match is left intact (the pair
// stays excluded from the deck via the match check), so undo is a no-op there.
func (s *MatchingService) Undo(ctx context.Context, userID uuid.UUID) error {
	_, err := s.pool.Exec(ctx, `
		DELETE FROM swipes
		WHERE user_id = $1
		  AND created_at = (SELECT max(created_at) FROM swipes WHERE user_id = $1)
	`, userID)
	return err
}

// createMatch fetches-or-creates the match between two users. Idempotent: returns
// the existing match if one exists in either direction. Scores on shared
// interests (food_tags ∪ wishlist) and seeds noi_lau_progress for new matches.
func (s *MatchingService) createMatch(ctx context.Context, userID, targetID uuid.UUID) (*models.Match, error) {
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

	// Jaccard over the union of food_tags and wishlist food names, same basis as
	// ListCandidates so the deck score and the persisted match score agree.
	var score float64
	if err := s.pool.QueryRow(ctx, `
		WITH ta AS (
			SELECT lower(trim(t)) AS tag FROM users u
			CROSS JOIN LATERAL unnest(COALESCE(u.food_tags, '{}'::text[])) AS t WHERE u.id = $1
			UNION SELECT lower(trim(food_name)) FROM wishlists WHERE user_id = $1
			UNION SELECT lower(trim(food_category)) FROM wishlists WHERE user_id = $1
		),
		tb AS (
			SELECT lower(trim(t)) AS tag FROM users u
			CROSS JOIN LATERAL unnest(COALESCE(u.food_tags, '{}'::text[])) AS t WHERE u.id = $2
			UNION SELECT lower(trim(food_name)) FROM wishlists WHERE user_id = $2
			UNION SELECT lower(trim(food_category)) FROM wishlists WHERE user_id = $2
		),
		inter AS (SELECT count(*)::float c FROM (
			SELECT tag FROM ta WHERE tag <> '' INTERSECT SELECT tag FROM tb WHERE tag <> '') x),
		uni AS (SELECT count(*)::float c FROM (
			SELECT tag FROM ta WHERE tag <> '' UNION SELECT tag FROM tb WHERE tag <> '') y)
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
	return out, rows.Err()
}
