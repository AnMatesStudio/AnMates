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
	"math/big"
	"net/http"
	"strings"
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

// EmailOTPOptions tunes the passwordless email-OTP flow.
type EmailOTPOptions struct {
	Expire         time.Duration // how long a code stays valid (e.g. 10m)
	ResendCooldown time.Duration // min gap between two code requests for one email (e.g. 60s)
	MaxAttempts    int           // wrong-code tries before a code is burned (e.g. 5)
}

// AuthService handles all authentication business logic.
type AuthService struct {
	pool       *pgxpool.Pool
	jwtSecret  []byte
	accessExp  time.Duration
	refreshExp time.Duration
	fbAPIKey   string
	httpClient *http.Client

	// Email OTP — configured via SetEmailOTP (nil emailSender ⇒ disabled).
	emailSender EmailSender
	emailOTP    EmailOTPOptions
}

// SetEmailOTP wires the email-OTP dependencies. Called once at startup; passing a
// nil sender leaves the email-OTP endpoints disabled.
func (s *AuthService) SetEmailOTP(sender EmailSender, opts EmailOTPOptions) {
	s.emailSender = sender
	s.emailOTP = opts
}

// EmailOTPEnabled reports whether an email sender has been configured.
func (s *AuthService) EmailOTPEnabled() bool { return s.emailSender != nil }

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

// RequestEmailOTP mints a 6-digit code for email, stores its hash, and sends it.
// A per-email cooldown throttles repeat requests. Returns ErrRateLimited when the
// caller asks again within the cooldown window.
func (s *AuthService) RequestEmailOTP(ctx context.Context, email string) error {
	if s.emailSender == nil {
		return fmt.Errorf("email OTP not configured")
	}

	// Cooldown: reject if a code was issued for this email very recently.
	var lastCreated time.Time
	err := s.pool.QueryRow(ctx, `
		SELECT created_at FROM email_otps
		WHERE email = $1 ORDER BY created_at DESC LIMIT 1
	`, email).Scan(&lastCreated)
	if err == nil && time.Since(lastCreated) < s.emailOTP.ResendCooldown {
		return ErrRateLimited
	}
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return fmt.Errorf("cooldown lookup: %w", err)
	}

	code, err := randomNumericCode(6)
	if err != nil {
		return fmt.Errorf("gen code: %w", err)
	}
	if _, err := s.pool.Exec(ctx, `
		INSERT INTO email_otps (email, code_hash, expires_at)
		VALUES ($1, $2, $3)
	`, email, hashToken(code), time.Now().Add(s.emailOTP.Expire)); err != nil {
		return fmt.Errorf("store otp: %w", err)
	}

	mins := int(s.emailOTP.Expire.Minutes())
	subject := "Mã đăng nhập ĂnMates: " + code
	text := fmt.Sprintf(
		"Chào bạn,\n\nMã đăng nhập ĂnMates của bạn là: %s\n\n"+
			"Mã có hiệu lực trong %d phút. Vui lòng không chia sẻ mã này với bất kỳ ai.\n\n"+
			"Nếu bạn không yêu cầu mã này, hãy bỏ qua email.\n\n— ĂnMates",
		code, mins)
	html := emailOTPHTML(code, mins)
	if err := s.emailSender.Send(ctx, email, subject, text, html); err != nil {
		return fmt.Errorf("send email: %w", err)
	}
	return nil
}

// emailOTPHTML renders the branded OTP email. It uses table-based layout +
// inline styles (the only reliably-supported approach across email clients —
// Gmail, Outlook, Apple Mail strip <style>/external CSS) and the ĂnMates brand
// colours (berry #B8336A → berryDeep #8E1F4D).
func emailOTPHTML(code string, mins int) string {
	// Space the digits so the code reads clearly and is easy to copy.
	spaced := strings.Join(strings.Split(code, ""), "&nbsp;")
	return `<!DOCTYPE html>
<html lang="vi">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta name="color-scheme" content="light only">
<title>Mã đăng nhập ĂnMates</title>
</head>
<body style="margin:0;padding:0;background-color:#FAF1F5;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#FAF1F5;padding:32px 12px;">
  <tr>
    <td align="center">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;background-color:#ffffff;border-radius:20px;overflow:hidden;box-shadow:0 8px 28px rgba(142,31,77,0.10);font-family:'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
        <!-- Header -->
        <tr>
          <td style="background:linear-gradient(135deg,#B8336A 0%,#8E1F4D 100%);background-color:#B8336A;padding:36px 32px 30px;text-align:center;">
            <div style="display:inline-block;width:56px;height:56px;line-height:56px;border-radius:16px;background-color:rgba(255,255,255,0.18);font-size:28px;">🍜</div>
            <div style="margin-top:14px;color:#ffffff;font-size:22px;font-weight:800;letter-spacing:0.3px;">ĂnMates</div>
            <div style="margin-top:4px;color:rgba(255,255,255,0.82);font-size:13px;">Va Mates, ăn miết.</div>
          </td>
        </tr>
        <!-- Body -->
        <tr>
          <td style="padding:34px 36px 12px;">
            <p style="margin:0 0 6px;color:#121212;font-size:18px;font-weight:700;">Mã đăng nhập của bạn</p>
            <p style="margin:0;color:#80121212;color:rgba(18,18,18,0.55);font-size:14px;line-height:1.6;">Nhập mã 6 số bên dưới để đăng nhập vào ĂnMates.</p>
          </td>
        </tr>
        <!-- Code pill -->
        <tr>
          <td style="padding:18px 36px 8px;" align="center">
            <div style="display:inline-block;background-color:#FAF1F5;border:1px solid #F1D6E1;border-radius:16px;padding:18px 28px;">
              <span style="color:#8E1F4D;font-size:34px;font-weight:800;letter-spacing:8px;font-family:'Courier New',monospace;">` + spaced + `</span>
            </div>
          </td>
        </tr>
        <tr>
          <td style="padding:14px 36px 4px;" align="center">
            <p style="margin:0;color:rgba(18,18,18,0.55);font-size:13px;">Mã có hiệu lực trong <strong style="color:#B8336A;">` + fmt.Sprintf("%d", mins) + ` phút</strong>.</p>
          </td>
        </tr>
        <!-- Divider -->
        <tr><td style="padding:22px 36px 0;"><div style="border-top:1px solid #F0E3E9;"></div></td></tr>
        <!-- Security note -->
        <tr>
          <td style="padding:18px 36px 30px;">
            <p style="margin:0;color:rgba(18,18,18,0.45);font-size:12.5px;line-height:1.7;">🔒 Vui lòng không chia sẻ mã này với bất kỳ ai. ĂnMates sẽ không bao giờ hỏi mã của bạn.<br>Nếu bạn không yêu cầu mã này, hãy bỏ qua email.</p>
          </td>
        </tr>
      </table>
      <!-- Footer -->
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;font-family:'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
        <tr>
          <td style="padding:18px 24px;text-align:center;">
            <p style="margin:0;color:rgba(18,18,18,0.40);font-size:11.5px;line-height:1.6;">© ĂnMates · Email tự động, vui lòng không trả lời.</p>
          </td>
        </tr>
      </table>
    </td>
  </tr>
</table>
</body>
</html>`
}

// VerifyEmailOTP validates code against the newest unconsumed, unexpired OTP for
// email. On success it consumes the code, upserts a user keyed by email, and
// returns that user. Wrong/expired/exhausted codes return ErrUnauthorized.
func (s *AuthService) VerifyEmailOTP(ctx context.Context, email, code string) (*models.User, error) {
	var (
		otpID    uuid.UUID
		codeHash string
		attempts int
	)
	err := s.pool.QueryRow(ctx, `
		SELECT id, code_hash, attempts FROM email_otps
		WHERE email = $1 AND consumed_at IS NULL AND expires_at > now()
		ORDER BY created_at DESC LIMIT 1
	`, email).Scan(&otpID, &codeHash, &attempts)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrUnauthorized
	}
	if err != nil {
		return nil, fmt.Errorf("lookup otp: %w", err)
	}

	// Count this try; burn the code once it exceeds the attempt budget.
	attempts++
	if attempts > s.emailOTP.MaxAttempts {
		_, _ = s.pool.Exec(ctx, `UPDATE email_otps SET consumed_at = now() WHERE id = $1`, otpID)
		return nil, ErrUnauthorized
	}
	if hashToken(code) != codeHash {
		_, _ = s.pool.Exec(ctx, `UPDATE email_otps SET attempts = $1 WHERE id = $2`, attempts, otpID)
		return nil, ErrUnauthorized
	}

	if _, err := s.pool.Exec(ctx,
		`UPDATE email_otps SET attempts = $1, consumed_at = now() WHERE id = $2`,
		attempts, otpID,
	); err != nil {
		return nil, fmt.Errorf("consume otp: %w", err)
	}
	return s.upsertEmailUser(ctx, email)
}

// upsertEmailUser returns the user with this email, creating a passwordless one
// (name derived from the local-part) the first time the email signs in.
func (s *AuthService) upsertEmailUser(ctx context.Context, email string) (*models.User, error) {
	var u models.User
	err := s.pool.QueryRow(ctx, `
		SELECT id, name, email, phone, avatar_url, bio, onboarding_done, created_at
		FROM users WHERE email = $1
	`, email).Scan(&u.ID, &u.Name, &u.Email, &u.Phone, &u.AvatarURL, &u.Bio, &u.OnboardingDone, &u.CreatedAt)
	if err == nil {
		return &u, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return nil, fmt.Errorf("lookup by email: %w", err)
	}

	name := email
	if local, _, ok := strings.Cut(email, "@"); ok && local != "" {
		name = local
	}
	err = s.pool.QueryRow(ctx, `
		INSERT INTO users (email, name)
		VALUES ($1, $2)
		RETURNING id, name, email, phone, avatar_url, bio, onboarding_done, created_at
	`, email, name).Scan(
		&u.ID, &u.Name, &u.Email, &u.Phone, &u.AvatarURL, &u.Bio, &u.OnboardingDone, &u.CreatedAt)
	if err != nil {
		if isUniqueViolation(err) {
			// Lost a race against a concurrent first-login — re-read the row.
			if rerr := s.pool.QueryRow(ctx, `
				SELECT id, name, email, phone, avatar_url, bio, onboarding_done, created_at
				FROM users WHERE email = $1
			`, email).Scan(&u.ID, &u.Name, &u.Email, &u.Phone, &u.AvatarURL, &u.Bio, &u.OnboardingDone, &u.CreatedAt); rerr == nil {
				return &u, nil
			}
		}
		return nil, fmt.Errorf("insert user: %w", err)
	}
	return &u, nil
}

// randomNumericCode returns an n-digit, zero-padded decimal code from crypto/rand.
func randomNumericCode(n int) (string, error) {
	max := big.NewInt(1)
	for i := 0; i < n; i++ {
		max.Mul(max, big.NewInt(10))
	}
	v, err := rand.Int(rand.Reader, max)
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%0*d", n, v), nil
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
