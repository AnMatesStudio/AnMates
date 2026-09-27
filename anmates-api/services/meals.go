package services

import (
	"context"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type MealRating struct {
	Stars int    `json:"stars"`
	Note  string `json:"note"`
}

// RatingView is what one member sees: their own rating, and the partner's only
// once both have rated (ratings stay private until then).
type RatingView struct {
	Mine      *MealRating `json:"mine"`
	Partner   *MealRating `json:"partner"`
	BothRated bool        `json:"both_rated"`
}

type UserStats struct {
	Meals   int `json:"meals"`
	Matches int `json:"matches"`
}

type MealService struct{ pool *pgxpool.Pool }

func NewMealService(pool *pgxpool.Pool) *MealService { return &MealService{pool: pool} }

// isMember reports whether userID is one of the two members of the match.
func (s *MealService) isMember(ctx context.Context, matchID, userID uuid.UUID) (bool, error) {
	var ok bool
	err := s.pool.QueryRow(ctx, `
		SELECT EXISTS(SELECT 1 FROM matches WHERE id = $1 AND (user_a_id = $2 OR user_b_id = $2))
	`, matchID, userID).Scan(&ok)
	if err != nil {
		return false, err
	}
	return ok, nil
}

// SubmitRating upserts the member's meal rating for the match.
func (s *MealService) SubmitRating(ctx context.Context, matchID, userID uuid.UUID, stars int, note string) error {
	ok, err := s.isMember(ctx, matchID, userID)
	if err != nil {
		return err
	}
	if !ok {
		return ErrNotFound
	}
	_, err = s.pool.Exec(ctx, `
		INSERT INTO meal_ratings (match_id, rater_id, stars, note)
		VALUES ($1, $2, $3, $4)
		ON CONFLICT (match_id, rater_id)
		DO UPDATE SET stars = EXCLUDED.stars, note = EXCLUDED.note, updated_at = now()
	`, matchID, userID, stars, note)
	return err
}

// GetRating returns the caller's rating and, only when both have rated, the partner's.
func (s *MealService) GetRating(ctx context.Context, matchID, userID uuid.UUID) (*RatingView, error) {
	ok, err := s.isMember(ctx, matchID, userID)
	if err != nil {
		return nil, err
	}
	if !ok {
		return nil, ErrNotFound
	}
	rows, err := s.pool.Query(ctx, `
		SELECT rater_id, stars, note FROM meal_ratings WHERE match_id = $1
	`, matchID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	view := &RatingView{}
	var partner *MealRating
	for rows.Next() {
		var raterID uuid.UUID
		var rating MealRating
		if err := rows.Scan(&raterID, &rating.Stars, &rating.Note); err != nil {
			return nil, err
		}
		if raterID == userID {
			view.Mine = &rating
		} else {
			partner = &rating
		}
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	view.BothRated = view.Mine != nil && partner != nil
	if view.BothRated {
		view.Partner = partner
	}
	return view, nil
}

// Stats returns the member's completed-meal and match counts.
func (s *MealService) Stats(ctx context.Context, userID uuid.UUID) (*UserStats, error) {
	var st UserStats
	err := s.pool.QueryRow(ctx, `
		SELECT
			(SELECT count(*) FROM bookings b JOIN matches m ON m.id = b.match_id
			 WHERE (m.user_a_id = $1 OR m.user_b_id = $1) AND b.status IN ('confirmed', 'completed')),
			(SELECT count(*) FROM matches WHERE user_a_id = $1 OR user_b_id = $1)
	`, userID).Scan(&st.Meals, &st.Matches)
	if err != nil {
		return nil, err
	}
	return &st, nil
}
