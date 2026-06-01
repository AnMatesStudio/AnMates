package handlers

import (
	"context"
	"errors"
	"net/mail"
	"strings"
	"time"

	"github.com/anmates/api/internal/httputil"
	"github.com/anmates/api/models"
	"github.com/anmates/api/services"
	"github.com/gofiber/fiber/v2"
)

type Auth struct {
	svc             services.AuthServicer
	devBypassSecret string
}

func NewAuth(svc services.AuthServicer, devBypassSecret string) *Auth {
	return &Auth{svc: svc, devBypassSecret: devBypassSecret}
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
	ID               string   `json:"id"`
	Name             string   `json:"name"`
	Email            *string  `json:"email,omitempty"`
	Phone            *string  `json:"phone,omitempty"`
	AvatarURL        *string  `json:"avatar_url"`
	Bio              *string  `json:"bio"`
	Nickname         *string  `json:"nickname,omitempty"`
	BirthDate        *string  `json:"birth_date,omitempty"`
	PersonalityScore *int16   `json:"personality_score,omitempty"`
	FoodTags         []string   `json:"food_tags"`
	VibeTags         []string   `json:"vibe_tags"`
	OnboardingDone   bool       `json:"onboarding_done"`
	Photos           []photoOut `json:"photos,omitempty"`
}

type photoOut struct {
	ID       string  `json:"id"`
	URL      string  `json:"url"`
	Caption  *string `json:"caption,omitempty"`
	Position int16   `json:"position"`
}

func toPhotosOut(photos []models.UserPhoto) []photoOut {
	out := make([]photoOut, 0, len(photos))
	for _, p := range photos {
		out = append(out, photoOut{
			ID:       p.ID.String(),
			URL:      p.URL,
			Caption:  p.Caption,
			Position: p.Position,
		})
	}
	return out
}

func toUserOut(u *models.User) *userOut {
	var birthDate *string
	if u.BirthDate != nil {
		s := u.BirthDate.Format("2006-01-02")
		birthDate = &s
	}
	foodTags := u.FoodTags
	if foodTags == nil {
		foodTags = []string{}
	}
	vibeTags := u.VibeTags
	if vibeTags == nil {
		vibeTags = []string{}
	}
	return &userOut{
		ID:               u.ID.String(),
		Name:             u.Name,
		Email:            u.Email,
		Phone:            u.Phone,
		AvatarURL:        u.AvatarURL,
		Bio:              u.Bio,
		Nickname:         u.Nickname,
		BirthDate:        birthDate,
		PersonalityScore: u.PersonalityScore,
		FoodTags:         foodTags,
		VibeTags:         vibeTags,
		OnboardingDone:   u.OnboardingDone,
	}
}

func tokensJSON(u *models.User, t *services.Tokens) tokenResp {
	return tokenResp{
		AccessToken:  t.AccessToken,
		RefreshToken: t.RefreshToken,
		ExpiresAt:    t.ExpiresAt,
		User:         toUserOut(u),
	}
}

func (a *Auth) Register(c *fiber.Ctx) error {
	var r registerReq
	if err := c.BodyParser(&r); err != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid body")
	}
	r.Email = strings.ToLower(strings.TrimSpace(r.Email))
	r.Name = strings.TrimSpace(r.Name)
	if !validEmail(r.Email) || len(r.Password) < 10 || r.Name == "" {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation,
			"name required; valid email; password >= 10 chars")
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	u, err := a.svc.RegisterUser(ctx, r.Email, r.Password, r.Name)
	if err != nil {
		if errors.Is(err, services.ErrDuplicate) {
			return httputil.Err(c, fiber.StatusConflict, httputil.ErrConflict, "email already registered")
		}
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "create user failed")
	}
	tokens, err := a.svc.IssueTokens(ctx, u.ID)
	if err != nil {
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "token issue failed")
	}
	return c.Status(fiber.StatusCreated).JSON(httputil.SuccessEnvelope{Success: true, Data: tokensJSON(u, tokens)})
}

func (a *Auth) Login(c *fiber.Ctx) error {
	var r loginReq
	if err := c.BodyParser(&r); err != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid body")
	}
	r.Email = strings.ToLower(strings.TrimSpace(r.Email))

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	u, err := a.svc.LoginUser(ctx, r.Email, r.Password)
	if errors.Is(err, services.ErrUnauthorized) {
		return httputil.Err(c, fiber.StatusUnauthorized, httputil.ErrUnauthorized, "invalid credentials")
	}
	if err != nil {
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "login failed")
	}
	tokens, err := a.svc.IssueTokens(ctx, u.ID)
	if err != nil {
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "token issue failed")
	}
	return httputil.OK(c, tokensJSON(u, tokens))
}

func (a *Auth) PhoneVerify(c *fiber.Ctx) error {
	var r phoneVerifyReq
	if err := c.BodyParser(&r); err != nil || r.FirebaseToken == "" {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "firebase_token required")
	}
	r.Name = strings.TrimSpace(r.Name)
	if r.Name == "" {
		r.Name = "Người dùng"
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	uid, phone, err := a.svc.VerifyFirebaseToken(ctx, r.FirebaseToken)
	if err != nil {
		return httputil.Err(c, fiber.StatusUnauthorized, httputil.ErrUnauthorized, "invalid firebase token")
	}
	if phone == "" {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "firebase token has no phone number")
	}
	u, err := a.svc.UpsertPhoneUser(ctx, uid, phone, r.Name)
	if err != nil {
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "upsert user failed: "+err.Error())
	}
	tokens, err := a.svc.IssueTokens(ctx, u.ID)
	if err != nil {
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "token issue failed")
	}
	return httputil.OK(c, tokensJSON(u, tokens))
}

func (a *Auth) Refresh(c *fiber.Ctx) error {
	var r refreshReq
	if err := c.BodyParser(&r); err != nil || r.RefreshToken == "" {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "refresh_token required")
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	u, tokens, err := a.svc.RotateRefreshToken(ctx, r.RefreshToken)
	if errors.Is(err, services.ErrUnauthorized) {
		return httputil.Err(c, fiber.StatusUnauthorized, httputil.ErrUnauthorized, "invalid refresh token")
	}
	if err != nil {
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "refresh failed")
	}
	return httputil.OK(c, tokensJSON(u, tokens))
}

// DevLogin issues JWTs for a test phone user without Firebase. Only registered when DevMode=true.
func (a *Auth) DevLogin(c *fiber.Ctx) error {
	var r devLoginReq
	if err := c.BodyParser(&r); err != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid body")
	}
	if a.devBypassSecret == "" || r.Secret != a.devBypassSecret {
		return httputil.Err(c, fiber.StatusForbidden, httputil.ErrUnauthorized, "invalid dev secret")
	}
	r.Phone = strings.TrimSpace(r.Phone)
	r.Name = strings.TrimSpace(r.Name)
	if r.Phone == "" {
		r.Phone = "+84999000001"
	}
	if r.Name == "" {
		r.Name = "Dev User"
	}
	devUID := "dev:" + r.Phone

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	u, err := a.svc.UpsertPhoneUser(ctx, devUID, r.Phone, r.Name)
	if err != nil {
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "dev upsert failed: "+err.Error())
	}
	tokens, err := a.svc.IssueTokens(ctx, u.ID)
	if err != nil {
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "token issue failed")
	}
	return httputil.OK(c, tokensJSON(u, tokens))
}

func (a *Auth) Logout(c *fiber.Ctx) error {
	var r refreshReq
	if err := c.BodyParser(&r); err == nil && r.RefreshToken != "" {
		ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
		defer cancel()
		_ = a.svc.InvalidateRefreshToken(ctx, r.RefreshToken)
	}
	return httputil.OK(c, fiber.Map{"logged_out": true})
}

func validEmail(s string) bool {
	if s == "" {
		return false
	}
	_, err := mail.ParseAddress(s)
	return err == nil
}
