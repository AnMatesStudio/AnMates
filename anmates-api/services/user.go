package services

import (
	"context"
	"time"

	"github.com/anmates/api/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type UserService struct {
	pool *pgxpool.Pool
}

func NewUserService(pool *pgxpool.Pool) *UserService { return &UserService{pool: pool} }

// userColumns is the shared SELECT/RETURNING projection so every read of a user
// row scans the same fields in the same order.
const userColumns = `id, name, email, phone, avatar_url, bio,
	nickname, birth_date, personality_score, food_tags, vibe_tags, onboarding_done`

// scanUser scans a row produced by userColumns into u.
func scanUser(row interface {
	Scan(dest ...any) error
}, u *models.User) error {
	return row.Scan(
		&u.ID, &u.Name, &u.Email, &u.Phone, &u.AvatarURL, &u.Bio,
		&u.Nickname, &u.BirthDate, &u.PersonalityScore, &u.FoodTags, &u.VibeTags, &u.OnboardingDone,
	)
}

func (s *UserService) GetProfile(ctx context.Context, userID uuid.UUID) (*models.User, error) {
	var u models.User
	err := scanUser(s.pool.QueryRow(ctx, `
		SELECT `+userColumns+` FROM users WHERE id = $1
	`, userID), &u)
	if err != nil {
		return nil, ErrNotFound
	}
	return &u, nil
}

// ListPhotos returns a user's gallery photos ordered by position (Screen 10/11).
func (s *UserService) ListPhotos(ctx context.Context, userID uuid.UUID) ([]models.UserPhoto, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT id, user_id, url, caption, position, created_at
		FROM user_photos WHERE user_id = $1 ORDER BY position, created_at
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	photos := []models.UserPhoto{}
	for rows.Next() {
		var p models.UserPhoto
		if err := rows.Scan(&p.ID, &p.UserID, &p.URL, &p.Caption, &p.Position, &p.CreatedAt); err != nil {
			return nil, err
		}
		photos = append(photos, p)
	}
	return photos, rows.Err()
}

func (s *UserService) UpdateProfile(ctx context.Context, userID uuid.UUID, name, avatarURL, bio *string) (*models.User, error) {
	var u models.User
	err := scanUser(s.pool.QueryRow(ctx, `
		UPDATE users SET
			name       = COALESCE($2, name),
			avatar_url = COALESCE($3, avatar_url),
			bio        = COALESCE($4, bio)
		WHERE id = $1
		RETURNING `+userColumns+`
	`, userID, name, avatarURL, bio), &u)
	if err != nil {
		return nil, err
	}
	return &u, nil
}

// UpdateOnboardingProfile persists Screen 08 data (name, nickname, DOB, personality).
func (s *UserService) UpdateOnboardingProfile(ctx context.Context, userID uuid.UUID, name, nickname string, birthDate *time.Time, personalityScore *int16) (*models.User, error) {
	var u models.User
	err := scanUser(s.pool.QueryRow(ctx, `
		UPDATE users SET
			name              = COALESCE(NULLIF($2, ''), name),
			nickname          = NULLIF($3, ''),
			birth_date        = $4,
			personality_score = $5
		WHERE id = $1
		RETURNING `+userColumns+`
	`, userID, name, nickname, birthDate, personalityScore), &u)
	if err != nil {
		return nil, err
	}
	return &u, nil
}

// UpdatePreferences persists Screen 09 data (food + vibe tags) and marks
// onboarding complete.
func (s *UserService) UpdatePreferences(ctx context.Context, userID uuid.UUID, foodTags, vibeTags []string) (*models.User, error) {
	if foodTags == nil {
		foodTags = []string{}
	}
	if vibeTags == nil {
		vibeTags = []string{}
	}
	var u models.User
	err := scanUser(s.pool.QueryRow(ctx, `
		UPDATE users SET
			food_tags       = $2,
			vibe_tags       = $3,
			onboarding_done = TRUE
		WHERE id = $1
		RETURNING `+userColumns+`
	`, userID, foodTags, vibeTags), &u)
	if err != nil {
		return nil, err
	}
	return &u, nil
}

// OnboardingInput carries the full Screen 08+09+10 payload submitted on "Hoàn tất".
type OnboardingInput struct {
	Name             string
	Nickname         string
	BirthDate        *time.Time
	PersonalityScore *int16
	FoodTags         []string
	VibeTags         []string
	AvatarURL        string
	Photos           []models.UserPhoto // gallery (extra) photos; URL/Caption/Position set
}

// CompleteOnboarding persists the whole onboarding payload in one transaction:
// profile fields + preferences + avatar + gallery photos, and flips
// onboarding_done. Gallery photos are replaced wholesale (delete + insert) so the
// call is idempotent on re-submit.
func (s *UserService) CompleteOnboarding(ctx context.Context, userID uuid.UUID, in OnboardingInput) (*models.User, []models.UserPhoto, error) {
	if in.FoodTags == nil {
		in.FoodTags = []string{}
	}
	if in.VibeTags == nil {
		in.VibeTags = []string{}
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, nil, err
	}
	defer tx.Rollback(ctx) //nolint:errcheck // no-op once committed

	var u models.User
	err = scanUser(tx.QueryRow(ctx, `
		UPDATE users SET
			name              = COALESCE(NULLIF($2, ''), name),
			nickname          = NULLIF($3, ''),
			birth_date        = $4,
			personality_score = $5,
			food_tags         = $6,
			vibe_tags         = $7,
			avatar_url        = NULLIF($8, ''),
			onboarding_done   = TRUE
		WHERE id = $1
		RETURNING `+userColumns+`
	`, userID, in.Name, in.Nickname, in.BirthDate, in.PersonalityScore,
		in.FoodTags, in.VibeTags, in.AvatarURL), &u)
	if err != nil {
		return nil, nil, err
	}

	if _, err := tx.Exec(ctx, `DELETE FROM user_photos WHERE user_id = $1`, userID); err != nil {
		return nil, nil, err
	}
	for i, p := range in.Photos {
		if _, err := tx.Exec(ctx, `
			INSERT INTO user_photos (user_id, url, caption, position)
			VALUES ($1, $2, $3, $4)
		`, userID, p.URL, p.Caption, int16(i)); err != nil {
			return nil, nil, err
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, nil, err
	}

	photos, err := s.ListPhotos(ctx, userID)
	if err != nil {
		return &u, nil, err
	}
	return &u, photos, nil
}
