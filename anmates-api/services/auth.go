package services

import (
	"bytes"
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"time"

	"github.com/anmates/api/middleware"
	"github.com/anmates/api/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"
)

// Tokens is the token pair returned after successful authentication.
type Tokens struct {
	AccessToken  string
	RefreshToken string
	ExpiresAt    time.Time
}

// AuthService handles all authentication business logic.
type AuthService struct {
	pool       *pgxpool.Pool
	jwtSecret  []byte
	accessExp  time.Duration
	refreshExp time.Duration
	fbAPIKey   string
	httpClient *http.Client
}

func NewAuthService(
	pool *pgxpool.Pool,
	jwtSecret []byte,
	accessExp, refreshExp time.Duration,
	fbAPIKey string,
	httpClient *http.Client,
) *AuthService {
	return &AuthService{
		pool:       pool,
		jwtSecret:  jwtSecret,
		accessExp:  accessExp,
		refreshExp: refreshExp,
		fbAPIKey:   fbAPIKey,
		httpClient: httpClient,
	}
}

func (s *AuthService) RegisterUser(ctx context.Context, email, password, name string) (*models.User, error) {
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return nil, fmt.Errorf("hash password: %w", err)
	}
	var u models.User
	err = s.pool.QueryRow(ctx, `
		INSERT INTO users (email, password_hash, name)
		VALUES ($1, $2, $3)
		RETURNING id, email, name, avatar_url, bio, created_at
	`, email, string(hash), name).Scan(
		&u.ID, &u.Email, &u.Name, &u.AvatarURL, &u.Bio, &u.CreatedAt)
	if err != nil {
		if isUniqueViolation(err) {
			return nil, fmt.Errorf("%w: email already registered", ErrDuplicate)
		}
		return nil, err
	}
	return &u, nil
}

func (s *AuthService) LoginUser(ctx context.Context, email, password string) (*models.User, error) {
	var u models.User
	err := s.pool.QueryRow(ctx, `
		SELECT id, email, password_hash, name, avatar_url, bio, created_at
		FROM users WHERE email = $1
	`, email).Scan(&u.ID, &u.Email, &u.PasswordHash, &u.Name, &u.AvatarURL, &u.Bio, &u.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrUnauthorized
	}
	if err != nil {
		return nil, err
	}
	if u.PasswordHash == nil || bcrypt.CompareHashAndPassword([]byte(*u.PasswordHash), []byte(password)) != nil {
		return nil, ErrUnauthorized
	}
	return &u, nil
}

// VerifyFirebaseToken calls the Firebase identitytoolkit REST API with the configured HTTP client (timeout enforced).
func (s *AuthService) VerifyFirebaseToken(ctx context.Context, idToken string) (uid, phone string, err error) {
	if s.fbAPIKey == "" {
		return "", "", fmt.Errorf("FIREBASE_WEB_API_KEY not configured")
	}
	body, _ := json.Marshal(map[string]string{"idToken": idToken})
	url := "https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=" + s.fbAPIKey
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return "", "", err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := s.httpClient.Do(req)
	if err != nil {
		return "", "", err
	}
	defer resp.Body.Close() //nolint:errcheck // HTTP response body close; error unrecoverable

	var result struct {
		Users []struct {
			LocalID     string `json:"localId"`
			PhoneNumber string `json:"phoneNumber"`
		} `json:"users"`
		Error *struct {
			Message string `json:"message"`
		} `json:"error"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return "", "", err
	}
	if result.Error != nil {
		return "", "", fmt.Errorf("firebase: %s", result.Error.Message)
	}
	if len(result.Users) == 0 {
		return "", "", fmt.Errorf("firebase: user not found")
	}
	return result.Users[0].LocalID, result.Users[0].PhoneNumber, nil
}

// UpsertPhoneUser handles three cases without tripping any UNIQUE constraint:
//  1. firebase_uid already in DB → keep phone fresh, return that row.
//  2. phone already in DB (different firebase_uid) → re-bind to the new firebase_uid.
//  3. Neither matches → INSERT new row.
func (s *AuthService) UpsertPhoneUser(ctx context.Context, uid, phone, name string) (*models.User, error) {
	var u models.User

	err := s.pool.QueryRow(ctx, `
		SELECT id, name, email, phone, avatar_url, bio, onboarding_done, created_at
		FROM users WHERE firebase_uid = $1
	`, uid).Scan(&u.ID, &u.Name, &u.Email, &u.Phone, &u.AvatarURL, &u.Bio, &u.OnboardingDone, &u.CreatedAt)
	if err == nil {
		if u.Phone == nil || *u.Phone != phone {
			_, _ = s.pool.Exec(ctx, `UPDATE users SET phone = $1 WHERE id = $2`, phone, u.ID)
			u.Phone = &phone
		}
		return &u, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return nil, fmt.Errorf("lookup by firebase_uid: %w", err)
	}

	err = s.pool.QueryRow(ctx, `
		SELECT id, name, email, phone, avatar_url, bio, onboarding_done, created_at
		FROM users WHERE phone = $1
	`, phone).Scan(&u.ID, &u.Name, &u.Email, &u.Phone, &u.AvatarURL, &u.Bio, &u.OnboardingDone, &u.CreatedAt)
	if err == nil {
		_, _ = s.pool.Exec(ctx, `UPDATE users SET firebase_uid = $1 WHERE id = $2`, uid, u.ID)
		return &u, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return nil, fmt.Errorf("lookup by phone: %w", err)
	}

	err = s.pool.QueryRow(ctx, `
		INSERT INTO users (firebase_uid, phone, name)
		VALUES ($1, $2, $3)
		RETURNING id, name, email, phone, avatar_url, bio, onboarding_done, created_at
	`, uid, phone, name).Scan(
		&u.ID, &u.Name, &u.Email, &u.Phone, &u.AvatarURL, &u.Bio, &u.OnboardingDone, &u.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("insert user: %w", err)
	}
	return &u, nil
}

// IssueTokens generates a new access+refresh token pair and persists the refresh token hash.
func (s *AuthService) IssueTokens(ctx context.Context, userID uuid.UUID) (*Tokens, error) {
	access, exp, err := middleware.SignAccessToken(s.jwtSecret, userID, s.accessExp)
	if err != nil {
		return nil, fmt.Errorf("sign access token: %w", err)
	}
	raw, err := randomToken()
	if err != nil {
		return nil, fmt.Errorf("gen refresh token: %w", err)
	}
	if _, err := s.pool.Exec(ctx, `
		INSERT INTO refresh_tokens (user_id, token_hash, expires_at)
		VALUES ($1, $2, $3)
	`, userID, hashToken(raw), time.Now().Add(s.refreshExp)); err != nil {
		return nil, fmt.Errorf("store refresh token: %w", err)
	}
	return &Tokens{AccessToken: access, RefreshToken: raw, ExpiresAt: exp}, nil
}

// RotateRefreshToken validates the old token, deletes it, and issues a fresh pair.
func (s *AuthService) RotateRefreshToken(ctx context.Context, rawToken string) (*models.User, *Tokens, error) {
	h := hashToken(rawToken)
	var u models.User
	err := s.pool.QueryRow(ctx, `
		SELECT u.id, u.email, u.name, u.phone, u.avatar_url, u.bio, u.onboarding_done, u.created_at
		FROM refresh_tokens rt
		JOIN users u ON u.id = rt.user_id
		WHERE rt.token_hash = $1 AND rt.expires_at > now()
	`, h).Scan(&u.ID, &u.Email, &u.Name, &u.Phone, &u.AvatarURL, &u.Bio, &u.OnboardingDone, &u.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil, ErrUnauthorized
	}
	if err != nil {
		return nil, nil, err
	}
	if _, err := s.pool.Exec(ctx, `DELETE FROM refresh_tokens WHERE token_hash = $1`, h); err != nil {
		return nil, nil, err
	}
	tokens, err := s.IssueTokens(ctx, u.ID)
	if err != nil {
		return nil, nil, err
	}
	return &u, tokens, nil
}

// InvalidateRefreshToken removes the token from the DB (logout).
func (s *AuthService) InvalidateRefreshToken(ctx context.Context, rawToken string) error {
	_, err := s.pool.Exec(ctx, `DELETE FROM refresh_tokens WHERE token_hash = $1`, hashToken(rawToken))
	return err
}

func randomToken() (string, error) {
	b := make([]byte, 48)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return base64.URLEncoding.EncodeToString(b), nil
}

func hashToken(raw string) string {
	sum := sha256.Sum256([]byte(raw))
	return base64.StdEncoding.EncodeToString(sum[:])
}

func isUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23505"
}
