package services

import (
	"context"
	"math"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// VibeCodes are the match-preference vibes the app's filter chips use.
var VibeCodes = map[string]struct{}{"lively": {}, "quiet": {}, "eat_run": {}, "long_sit": {}, "deal": {}}

type MatchPrefs struct {
	VibeTags  []string `json:"vibe_tags"`
	PriceTier *int16   `json:"price_tier"`
}

type TrustScore struct {
	Score         int `json:"score"`
	Meals         int `json:"meals"`
	GoodRatings   int `json:"good_ratings"`
	NoShowReports int `json:"no_show_reports"`
	OtherReports  int `json:"other_reports"`
}

type Visit struct {
	MatchID        uuid.UUID `json:"match_id"`
	RestaurantName string    `json:"restaurant_name"`
	ScheduledAt    time.Time `json:"scheduled_at"`
	PartnerName    string    `json:"partner_name"`
}

type Review struct {
	MatchID        uuid.UUID `json:"match_id"`
	Stars          int       `json:"stars"`
	Note           string    `json:"note"`
	RestaurantName string    `json:"restaurant_name"`
	CreatedAt      time.Time `json:"created_at"`
}

type History struct {
	Visits  []Visit  `json:"visits"`
	Reviews []Review `json:"reviews"`
}

type LocalMate struct {
	UserID     uuid.UUID `json:"user_id"`
	Name       string    `json:"name"`
	AvatarURL  *string   `json:"avatar_url"`
	District   *string   `json:"district"`
	Meals      int       `json:"meals"`
	DistanceKm float64   `json:"distance_km"`
}

type ProfileExtrasService struct{ pool *pgxpool.Pool }

func NewProfileExtrasService(pool *pgxpool.Pool) *ProfileExtrasService {
	return &ProfileExtrasService{pool: pool}
}

// GetMatchPrefs returns the user's match preferences (vibe tags and price tier).
func (s *ProfileExtrasService) GetMatchPrefs(ctx context.Context, userID uuid.UUID) (*MatchPrefs, error) {
	p := &MatchPrefs{VibeTags: []string{}}
	err := s.pool.QueryRow(ctx, `
		SELECT COALESCE(vibe_tags, '{}'), price_tier FROM users WHERE id = $1
	`, userID).Scan(&p.VibeTags, &p.PriceTier)
	if err != nil {
		return nil, err
	}
	return p, nil
}

// SetMatchPrefs updates the user's match preferences and returns them.
func (s *ProfileExtrasService) SetMatchPrefs(ctx context.Context, userID uuid.UUID, vibes []string, priceTier *int16) (*MatchPrefs, error) {
	if vibes == nil {
		vibes = []string{}
	}
	_, err := s.pool.Exec(ctx, `
		UPDATE users SET vibe_tags = $2, price_tier = $3 WHERE id = $1
	`, userID, vibes, priceTier)
	if err != nil {
		return nil, err
	}
	return s.GetMatchPrefs(ctx, userID)
}

// DeleteAccount removes the user; every table referencing users cascades.
func (s *ProfileExtrasService) DeleteAccount(ctx context.Context, userID uuid.UUID) error {
	tag, err := s.pool.Exec(ctx, `DELETE FROM users WHERE id = $1`, userID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// Trust returns the user's trust score computed from meals, ratings and reports.
func (s *ProfileExtrasService) Trust(ctx context.Context, userID uuid.UUID) (*TrustScore, error) {
	var t TrustScore
	err := s.pool.QueryRow(ctx, `
		SELECT
			(SELECT count(*) FROM bookings b JOIN matches m ON m.id = b.match_id
			 WHERE (m.user_a_id = $1 OR m.user_b_id = $1) AND b.status IN ('confirmed', 'completed')),
			(SELECT count(*) FROM meal_ratings r JOIN matches m ON m.id = r.match_id
			 WHERE (m.user_a_id = $1 OR m.user_b_id = $1) AND r.rater_id <> $1 AND r.stars >= 4),
			(SELECT count(DISTINCT reporter_id) FROM user_reports WHERE reported_id = $1 AND reason = 'no_show'),
			(SELECT count(DISTINCT reporter_id) FROM user_reports
			 WHERE reported_id = $1 AND reason IN ('harassment', 'fake_profile', 'inappropriate'))
	`, userID).Scan(&t.Meals, &t.GoodRatings, &t.NoShowReports, &t.OtherReports)
	if err != nil {
		return nil, err
	}
	score := 80 + 4*t.Meals + 2*t.GoodRatings - 20*t.NoShowReports - 10*t.OtherReports
	if score < 0 {
		score = 0
	}
	if score > 100 {
		score = 100
	}
	t.Score = score
	return &t, nil
}

// History returns the user's recent meal visits and the reviews they gave.
func (s *ProfileExtrasService) History(ctx context.Context, userID uuid.UUID) (*History, error) {
	h := &History{Visits: []Visit{}, Reviews: []Review{}}

	rows, err := s.pool.Query(ctx, `
		SELECT b.match_id, b.restaurant_name, b.scheduled_at, COALESCE(u.name, '')
		FROM bookings b JOIN matches m ON m.id = b.match_id
		JOIN users u ON u.id = CASE WHEN m.user_a_id = $1 THEN m.user_b_id ELSE m.user_a_id END
		WHERE (m.user_a_id = $1 OR m.user_b_id = $1) AND b.status IN ('confirmed', 'completed')
		ORDER BY b.scheduled_at DESC LIMIT 50
	`, userID)
	if err != nil {
		return nil, err
	}
	for rows.Next() {
		var v Visit
		if err := rows.Scan(&v.MatchID, &v.RestaurantName, &v.ScheduledAt, &v.PartnerName); err != nil {
			return nil, err
		}
		h.Visits = append(h.Visits, v)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	rows.Close()

	rows, err = s.pool.Query(ctx, `
		SELECT r.match_id, r.stars, r.note, r.created_at,
		       COALESCE((SELECT b.restaurant_name FROM bookings b WHERE b.match_id = r.match_id
		                 ORDER BY b.created_at DESC LIMIT 1), '')
		FROM meal_ratings r WHERE r.rater_id = $1
		ORDER BY r.created_at DESC LIMIT 50
	`, userID)
	if err != nil {
		return nil, err
	}
	for rows.Next() {
		var r Review
		if err := rows.Scan(&r.MatchID, &r.Stars, &r.Note, &r.CreatedAt, &r.RestaurantName); err != nil {
			return nil, err
		}
		h.Reviews = append(h.Reviews, r)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	rows.Close()

	return h, nil
}

// Locals returns non-bot users within 5 km who have at least one real meal, nearest first.
func (s *ProfileExtrasService) Locals(ctx context.Context, userID uuid.UUID) ([]LocalMate, error) {
	rows, err := s.pool.Query(ctx, `
		WITH me AS (SELECT lat, lng FROM user_locations WHERE user_id = $1),
		near AS (
			SELECT l.user_id, l.district,
			       6371 * 2 * asin(sqrt(
			         power(sin(radians(l.lat - me.lat) / 2), 2) +
			         cos(radians(me.lat)) * cos(radians(l.lat)) * power(sin(radians(l.lng - me.lng) / 2), 2)
			       )) AS km
			FROM user_locations l CROSS JOIN me
			WHERE l.user_id <> $1
		),
		meals AS (
			SELECT u.id AS user_id, count(b.*) AS n
			FROM users u JOIN matches m ON (m.user_a_id = u.id OR m.user_b_id = u.id)
			JOIN bookings b ON b.match_id = m.id AND b.status IN ('confirmed', 'completed')
			GROUP BY u.id
		)
		SELECT n.user_id, u.name, u.avatar_url, n.district, meals.n::int, n.km
		FROM near n
		JOIN users u ON u.id = n.user_id AND NOT u.is_bot
		  AND u.suspended_at IS NULL AND (u.email IS NULL OR u.email_verified_at IS NOT NULL)
		JOIN meals ON meals.user_id = n.user_id
		WHERE n.km <= 5
		  AND NOT EXISTS (SELECT 1 FROM user_blocks ub
		                  WHERE (ub.blocker_id = $1 AND ub.blocked_id = n.user_id)
			                     OR (ub.blocker_id = n.user_id AND ub.blocked_id = $1))
		ORDER BY n.km ASC, meals.n DESC
		LIMIT 20
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	locals := []LocalMate{}
	for rows.Next() {
		var lm LocalMate
		if err := rows.Scan(&lm.UserID, &lm.Name, &lm.AvatarURL, &lm.District, &lm.Meals, &lm.DistanceKm); err != nil {
			return nil, err
		}
		lm.DistanceKm = math.Round(lm.DistanceKm*10) / 10
		locals = append(locals, lm)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return locals, nil
}
