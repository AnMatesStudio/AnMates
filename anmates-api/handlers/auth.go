package handlers

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
	"net/mail"
	"strings"
	"time"

	"github.com/anmates/api/config"
	"github.com/anmates/api/middleware"
	"github.com/anmates/api/models"
	"github.com/gofiber/fiber/v2"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"
)

type Auth struct {
	pool *pgxpool.Pool
	cfg  *config.Config
}

func NewAuth(pool *pgxpool.Pool, cfg *config.Config) *Auth {
	return &Auth{pool: pool, cfg: cfg}
}

type registerReq struct {
	Name     string `json:"name"`
	Email    string `json:"email"`
	Password string `json:"password"`
}

type loginReq struct {
	Email    string `json:"email"`
	Password string `json:"password"`
}

type refreshReq struct {
	RefreshToken string `json:"refresh_token"`
}

type phoneVerifyReq struct {
	FirebaseToken string `json:"firebase_token"`
	Name          string `json:"name"`
}

type devLoginReq struct {
	Secret string `json:"secret"`
	Phone  string `json:"phone"`
	Name   string `json:"name"`
}

type tokenResp struct {
	AccessToken  string    `json:"access_token"`
	RefreshToken string    `json:"refresh_token,omitempty"`
	ExpiresAt    time.Time `json:"expires_at"`
	User         *userOut  `json:"user,omitempty"`
}

type userOut struct {
	ID        string  `json:"id"`
	Name      string  `json:"name"`
	Email     *string `json:"email,omitempty"`
	Phone     *string `json:"phone,omitempty"`
	AvatarURL *string `json:"avatar_url"`
	Bio       *string `json:"bio"`
}

func (a *Auth) Register(c *fiber.Ctx) error {
	var r registerReq
	if err := c.BodyParser(&r); err != nil {
		return models.Err(c, fiber.StatusBadRequest, models.ErrValidation, "invalid body")
	}
	r.Email = strings.ToLower(strings.TrimSpace(r.Email))
	r.Name = strings.TrimSpace(r.Name)
	if !validEmail(r.Email) || len(r.Password) < 10 || r.Name == "" {
		return models.Err(c, fiber.StatusBadRequest, models.ErrValidation,
			"name required; valid email; password >= 10 chars")
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(r.Password), bcrypt.DefaultCost)
	if err != nil {
		return models.Err(c, fiber.StatusInternalServerError, models.ErrInternal, "hash failed")
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	var u models.User
	err = a.pool.QueryRow(ctx, `
		INSERT INTO users (email, password_hash, name)
		VALUES ($1, $2, $3)
		RETURNING id, email, name, avatar_url, bio, created_at
	`, r.Email, string(hash), r.Name).Scan(
		&u.ID, &u.Email, &u.Name, &u.AvatarURL, &u.Bio, &u.CreatedAt)
	if err != nil {
		if isUniqueViolation(err) {
			return models.Err(c, fiber.StatusConflict, models.ErrConflict, "email already registered")
		}
		return models.Err(c, fiber.StatusInternalServerError, models.ErrInternal, "create user failed")
	}

	return a.issueTokens(c, ctx, &u, fiber.StatusCreated)
}

func (a *Auth) Login(c *fiber.Ctx) error {
	var r loginReq
	if err := c.BodyParser(&r); err != nil {
		return models.Err(c, fiber.StatusBadRequest, models.ErrValidation, "invalid body")
	}
	r.Email = strings.ToLower(strings.TrimSpace(r.Email))

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	var u models.User
	err := a.pool.QueryRow(ctx, `
		SELECT id, email, password_hash, name, avatar_url, bio, created_at
		FROM users WHERE email = $1
	`, r.Email).Scan(&u.ID, &u.Email, &u.PasswordHash, &u.Name, &u.AvatarURL, &u.Bio, &u.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return models.Err(c, fiber.StatusUnauthorized, models.ErrUnauthorized, "invalid credentials")
	}
	if err != nil {
		return models.Err(c, fiber.StatusInternalServerError, models.ErrInternal, "login failed")
	}
	if u.PasswordHash == nil || bcrypt.CompareHashAndPassword([]byte(*u.PasswordHash), []byte(r.Password)) != nil {
		return models.Err(c, fiber.StatusUnauthorized, models.ErrUnauthorized, "invalid credentials")
	}
	return a.issueTokens(c, ctx, &u, fiber.StatusOK)
}

// PhoneVerify verifies a Firebase ID token and upserts the phone user, then issues JWT.
func (a *Auth) PhoneVerify(c *fiber.Ctx) error {
	var r phoneVerifyReq
	if err := c.BodyParser(&r); err != nil || r.FirebaseToken == "" {
		return models.Err(c, fiber.StatusBadRequest, models.ErrValidation, "firebase_token required")
	}
	r.Name = strings.TrimSpace(r.Name)
	if r.Name == "" {
		r.Name = "Người dùng"
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	uid, phone, err := a.verifyFirebaseToken(ctx, r.FirebaseToken)
	if err != nil {
		return models.Err(c, fiber.StatusUnauthorized, models.ErrUnauthorized, "invalid firebase token")
	}
	if phone == "" {
		return models.Err(c, fiber.StatusBadRequest, models.ErrValidation, "firebase token has no phone number")
	}

	u, err := upsertPhoneUser(ctx, a.pool, uid, phone, r.Name)
	if err != nil {
		return models.Err(c, fiber.StatusInternalServerError, models.ErrInternal, "upsert user failed: "+err.Error())
	}
	return a.issueTokens(c, ctx, u, fiber.StatusOK)
}

// upsertPhoneUser handles three cases without tripping any UNIQUE constraint:
//  1. firebase_uid already in DB → keep phone fresh, return that row.
//  2. phone already in DB (different/old firebase_uid) → re-bind to the new
//     firebase_uid. This is the common case when Firebase rotated the session
//     (different project, signed out, etc.) but the user kept their number.
//  3. Neither matches → INSERT new row.
//
// ON CONFLICT alone can't cover this because Postgres only accepts one conflict
// target per statement and we have two unique columns (firebase_uid, phone).
func upsertPhoneUser(ctx context.Context, pool *pgxpool.Pool, uid, phone, name string) (*models.User, error) {
	var u models.User

	// 1. Try firebase_uid
	err := pool.QueryRow(ctx, `
		SELECT id, name, email, phone, avatar_url, bio, created_at
		FROM users WHERE firebase_uid = $1
	`, uid).Scan(&u.ID, &u.Name, &u.Email, &u.Phone, &u.AvatarURL, &u.Bio, &u.CreatedAt)
	if err == nil {
		if u.Phone == nil || *u.Phone != phone {
			_, _ = pool.Exec(ctx, `UPDATE users SET phone = $1 WHERE id = $2`, phone, u.ID)
			u.Phone = &phone
		}
		return &u, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return nil, fmt.Errorf("lookup by firebase_uid: %w", err)
	}

	// 2. Try phone (firebase_uid rotated)
	err = pool.QueryRow(ctx, `
		SELECT id, name, email, phone, avatar_url, bio, created_at
		FROM users WHERE phone = $1
	`, phone).Scan(&u.ID, &u.Name, &u.Email, &u.Phone, &u.AvatarURL, &u.Bio, &u.CreatedAt)
	if err == nil {
		_, _ = pool.Exec(ctx, `UPDATE users SET firebase_uid = $1 WHERE id = $2`, uid, u.ID)
		return &u, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return nil, fmt.Errorf("lookup by phone: %w", err)
	}

	// 3. Fresh user
	err = pool.QueryRow(ctx, `
		INSERT INTO users (firebase_uid, phone, name)
		VALUES ($1, $2, $3)
		RETURNING id, name, email, phone, avatar_url, bio, created_at
	`, uid, phone, name).Scan(
		&u.ID, &u.Name, &u.Email, &u.Phone, &u.AvatarURL, &u.Bio, &u.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("insert user: %w", err)
	}
	return &u, nil
}

func (a *Auth) verifyFirebaseToken(ctx context.Context, idToken string) (uid, phone string, err error) {
	if a.cfg.FirebaseWebAPIKey == "" {
		return "", "", fmt.Errorf("FIREBASE_WEB_API_KEY not configured")
	}

	body, _ := json.Marshal(map[string]string{"idToken": idToken})
	url := "https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=" + a.cfg.FirebaseWebAPIKey

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return "", "", err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", "", err
	}
	defer resp.Body.Close()

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

func (a *Auth) Refresh(c *fiber.Ctx) error {
	var r refreshReq
	if err := c.BodyParser(&r); err != nil || r.RefreshToken == "" {
		return models.Err(c, fiber.StatusBadRequest, models.ErrValidation, "refresh_token required")
	}
	h := hashToken(r.RefreshToken)

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	var u models.User
	err := a.pool.QueryRow(ctx, `
		SELECT u.id, u.email, u.name, u.phone, u.avatar_url, u.bio, u.created_at
		FROM refresh_tokens rt
		JOIN users u ON u.id = rt.user_id
		WHERE rt.token_hash = $1 AND rt.expires_at > now()
	`, h).Scan(&u.ID, &u.Email, &u.Name, &u.Phone, &u.AvatarURL, &u.Bio, &u.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return models.Err(c, fiber.StatusUnauthorized, models.ErrUnauthorized, "invalid refresh token")
	}
	if err != nil {
		return models.Err(c, fiber.StatusInternalServerError, models.ErrInternal, "refresh failed")
	}

	if _, err := a.pool.Exec(ctx, `DELETE FROM refresh_tokens WHERE token_hash = $1`, h); err != nil {
		return models.Err(c, fiber.StatusInternalServerError, models.ErrInternal, "rotate failed")
	}
	return a.issueTokens(c, ctx, &u, fiber.StatusOK)
}

// DevLogin issues JWTs for a test phone user without going through Firebase.
// Gated by DEV_MODE=true + DEV_BYPASS_SECRET match. Never enable in production.
func (a *Auth) DevLogin(c *fiber.Ctx) error {
	if !a.cfg.DevMode {
		return models.Err(c, fiber.StatusForbidden, models.ErrUnauthorized, "dev login disabled")
	}
	var r devLoginReq
	if err := c.BodyParser(&r); err != nil {
		return models.Err(c, fiber.StatusBadRequest, models.ErrValidation, "invalid body")
	}
	if a.cfg.DevBypassSecret == "" || r.Secret != a.cfg.DevBypassSecret {
		return models.Err(c, fiber.StatusForbidden, models.ErrUnauthorized, "invalid dev secret")
	}
	r.Phone = strings.TrimSpace(r.Phone)
	r.Name = strings.TrimSpace(r.Name)
	if r.Phone == "" {
		r.Phone = "+84999000001"
	}
	if r.Name == "" {
		r.Name = "Dev User"
	}
	// Synthetic firebase_uid so multiple dev phones don't collide.
	devUID := "dev:" + r.Phone

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	u, err := upsertPhoneUser(ctx, a.pool, devUID, r.Phone, r.Name)
	if err != nil {
		return models.Err(c, fiber.StatusInternalServerError, models.ErrInternal, "dev upsert failed: "+err.Error())
	}
	return a.issueTokens(c, ctx, u, fiber.StatusOK)
}

func (a *Auth) Logout(c *fiber.Ctx) error {
	var r refreshReq
	if err := c.BodyParser(&r); err == nil && r.RefreshToken != "" {
		ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
		defer cancel()
		_, _ = a.pool.Exec(ctx, `DELETE FROM refresh_tokens WHERE token_hash = $1`, hashToken(r.RefreshToken))
	}
	return models.OK(c, fiber.Map{"logged_out": true})
}

func (a *Auth) issueTokens(c *fiber.Ctx, ctx context.Context, u *models.User, status int) error {
	access, exp, err := middleware.SignAccessToken(a.cfg.JWTSecret, u.ID, a.cfg.JWTAccessExpire)
	if err != nil {
		return models.Err(c, fiber.StatusInternalServerError, models.ErrInternal, "token sign failed")
	}
	raw, err := randomToken()
	if err != nil {
		return models.Err(c, fiber.StatusInternalServerError, models.ErrInternal, "token gen failed")
	}
	if _, err := a.pool.Exec(ctx, `
		INSERT INTO refresh_tokens (user_id, token_hash, expires_at)
		VALUES ($1, $2, $3)
	`, u.ID, hashToken(raw), time.Now().Add(a.cfg.JWTRefreshExpire)); err != nil {
		return models.Err(c, fiber.StatusInternalServerError, models.ErrInternal, "store refresh failed")
	}

	return c.Status(status).JSON(models.SuccessEnvelope{
		Success: true,
		Data: tokenResp{
			AccessToken:  access,
			RefreshToken: raw,
			ExpiresAt:    exp,
			User: &userOut{
				ID: u.ID.String(), Name: u.Name,
				Email: u.Email, Phone: u.Phone,
				AvatarURL: u.AvatarURL, Bio: u.Bio,
			},
		},
	})
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

func validEmail(s string) bool {
	if s == "" {
		return false
	}
	_, err := mail.ParseAddress(s)
	return err == nil
}

func isUniqueViolation(err error) bool {
	return err != nil && strings.Contains(err.Error(), "23505")
}
