package handlers

import (
	"context"
	"strings"
	"time"

	"github.com/anmates/api/internal/httputil"
	"github.com/anmates/api/middleware"
	"github.com/anmates/api/models"
	"github.com/anmates/api/services"
	"github.com/gofiber/fiber/v2"
)

type User struct {
	svc services.UserServicer
}

func NewUser(svc services.UserServicer) *User { return &User{svc: svc} }

func (u *User) GetProfile(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	user, err := u.svc.GetProfile(ctx, uid)
	if err != nil {
		return httputil.Err(c, fiber.StatusNotFound, httputil.ErrNotFound, "user not found")
	}
	out := toUserOut(user)
	if photos, err := u.svc.ListPhotos(ctx, uid); err == nil {
		out.Photos = toPhotosOut(photos)
	}
	return httputil.OK(c, out)
}

type updateProfileReq struct {
	Name      *string `json:"name"`
	AvatarURL *string `json:"avatar_url"`
	Bio       *string `json:"bio"`
}

func (u *User) UpdateProfile(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	var r updateProfileReq
	if err := c.BodyParser(&r); err != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid body")
	}
	if r.Name != nil {
		trim := strings.TrimSpace(*r.Name)
		if trim == "" {
			return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "name must not be empty")
		}
		r.Name = &trim
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	user, err := u.svc.UpdateProfile(ctx, uid, r.Name, r.AvatarURL, r.Bio)
	if err != nil {
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "update failed")
	}
	return httputil.OK(c, toUserOut(user))
}

type onboardingProfileReq struct {
	Name             string `json:"name"`
	Nickname         string `json:"nickname"`
	BirthDate        string `json:"birth_date"` // "YYYY-MM-DD"
	PersonalityScore *int16 `json:"personality_score"`
}

// UpdateOnboarding handles PATCH /profile/onboarding (Screen 08).
func (u *User) UpdateOnboarding(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	var r onboardingProfileReq
	if err := c.BodyParser(&r); err != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid body")
	}
	r.Name = strings.TrimSpace(r.Name)
	r.Nickname = strings.TrimSpace(r.Nickname)
	if r.Name == "" {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "name must not be empty")
	}

	var birthDate *time.Time
	if strings.TrimSpace(r.BirthDate) != "" {
		t, err := time.Parse("2006-01-02", strings.TrimSpace(r.BirthDate))
		if err != nil {
			return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "birth_date must be YYYY-MM-DD")
		}
		birthDate = &t
	}

	if r.PersonalityScore != nil {
		v := *r.PersonalityScore
		if v < 0 {
			v = 0
		}
		if v > 100 {
			v = 100
		}
		r.PersonalityScore = &v
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	user, err := u.svc.UpdateOnboardingProfile(ctx, uid, r.Name, r.Nickname, birthDate, r.PersonalityScore)
	if err != nil {
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "update failed")
	}
	return httputil.OK(c, toUserOut(user))
}

type preferencesReq struct {
	FoodTags []string `json:"food_tags"`
	VibeTags []string `json:"vibe_tags"`
}

// UpdatePreferences handles PATCH /profile/preferences (Screen 09). Marks onboarding complete.
func (u *User) UpdatePreferences(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	var r preferencesReq
	if err := c.BodyParser(&r); err != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid body")
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	user, err := u.svc.UpdatePreferences(ctx, uid, r.FoodTags, r.VibeTags)
	if err != nil {
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "update failed")
	}
	return httputil.OK(c, toUserOut(user))
}

type photoIn struct {
	URL     string  `json:"url"`
	Caption *string `json:"caption"`
}

type completeOnboardingReq struct {
	Name             string    `json:"name"`
	Nickname         string    `json:"nickname"`
	BirthDate        string    `json:"birth_date"` // "YYYY-MM-DD"
	PersonalityScore *int16    `json:"personality_score"`
	FoodTags         []string  `json:"food_tags"`
	VibeTags         []string  `json:"vibe_tags"`
	AvatarURL        string    `json:"avatar_url"`
	Photos           []photoIn `json:"photos"`
}

// CompleteOnboarding handles PATCH /profile/complete-onboarding — the single
// submit for Screens 08+09+10 on "Hoàn tất". Validates the assembled payload,
// persists everything atomically and marks onboarding complete.
func (u *User) CompleteOnboarding(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	var r completeOnboardingReq
	if err := c.BodyParser(&r); err != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid body")
	}

	r.Name = strings.TrimSpace(r.Name)
	r.Nickname = strings.TrimSpace(r.Nickname)
	r.AvatarURL = strings.TrimSpace(r.AvatarURL)
	if r.Name == "" {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "name must not be empty")
	}
	if r.AvatarURL == "" {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "avatar_url is required")
	}
	if len(r.FoodTags) < 5 || len(r.FoodTags) > 10 {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "food_tags must have between 5 and 10 items")
	}
	if len(r.VibeTags) < 2 || len(r.VibeTags) > 5 {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "vibe_tags must have between 2 and 5 items")
	}

	var birthDate *time.Time
	if strings.TrimSpace(r.BirthDate) != "" {
		t, err := time.Parse("2006-01-02", strings.TrimSpace(r.BirthDate))
		if err != nil {
			return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "birth_date must be YYYY-MM-DD")
		}
		birthDate = &t
	}

	if r.PersonalityScore != nil {
		v := *r.PersonalityScore
		if v < 0 {
			v = 0
		}
		if v > 100 {
			v = 100
		}
		r.PersonalityScore = &v
	}

	photos := make([]models.UserPhoto, 0, len(r.Photos))
	for i, p := range r.Photos {
		url := strings.TrimSpace(p.URL)
		if url == "" {
			continue
		}
		photos = append(photos, models.UserPhoto{URL: url, Caption: p.Caption, Position: int16(i)})
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	user, savedPhotos, err := u.svc.CompleteOnboarding(ctx, uid, services.OnboardingInput{
		Name:             r.Name,
		Nickname:         r.Nickname,
		BirthDate:        birthDate,
		PersonalityScore: r.PersonalityScore,
		FoodTags:         r.FoodTags,
		VibeTags:         r.VibeTags,
		AvatarURL:        r.AvatarURL,
		Photos:           photos,
	})
	if err != nil {
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "complete onboarding failed")
	}
	out := toUserOut(user)
	out.Photos = toPhotosOut(savedPhotos)
	return httputil.OK(c, out)
}
