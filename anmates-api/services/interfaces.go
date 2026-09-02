package services

import (
	"context"
	"time"

	"github.com/anmates/api/models"
	"github.com/google/uuid"
)

type AuthServicer interface {
	RegisterUser(ctx context.Context, email, password, name string) (*models.User, error)
	LoginUser(ctx context.Context, email, password string) (*models.User, error)
	VerifyFirebaseToken(ctx context.Context, idToken string) (uid, phone string, err error)
	UpsertPhoneUser(ctx context.Context, uid, phone, name string) (*models.User, error)
	RequestEmailOTP(ctx context.Context, email string) error
	VerifyEmailOTP(ctx context.Context, email, code string) (*models.User, error)
	EmailOTPEnabled() bool
	IssueTokens(ctx context.Context, userID uuid.UUID) (*Tokens, error)
	RotateRefreshToken(ctx context.Context, rawToken string) (*models.User, *Tokens, error)
	InvalidateRefreshToken(ctx context.Context, rawToken string) error
}

type UserServicer interface {
	GetProfile(ctx context.Context, userID uuid.UUID) (*models.User, error)
	UpdateProfile(ctx context.Context, userID uuid.UUID, name, avatarURL, bio *string) (*models.User, error)
	UpdateOnboardingProfile(ctx context.Context, userID uuid.UUID, name, nickname string, birthDate *time.Time, personalityScore *int16) (*models.User, error)
	UpdatePreferences(ctx context.Context, userID uuid.UUID, foodTags, vibeTags []string) (*models.User, error)
	CompleteOnboarding(ctx context.Context, userID uuid.UUID, in OnboardingInput) (*models.User, []models.UserPhoto, error)
	ListPhotos(ctx context.Context, userID uuid.UUID) ([]models.UserPhoto, error)
}

type WishlistServicer interface {
	List(ctx context.Context, userID uuid.UUID) ([]models.Wishlist, error)
	Create(ctx context.Context, userID uuid.UUID, foodName, category string) (*models.Wishlist, error)
	Delete(ctx context.Context, userID, itemID uuid.UUID) error
}

type MatchingServicer interface {
	ListCandidates(ctx context.Context, userID uuid.UUID) ([]models.MatchCandidate, error)
	Swipe(ctx context.Context, userID, targetID uuid.UUID, liked bool) (*SwipeResult, error)
	Undo(ctx context.Context, userID uuid.UUID) error
	Conversations(ctx context.Context, userID uuid.UUID) ([]models.Conversation, error)
}

type ChatServicer interface {
	IsMember(ctx context.Context, matchID, userID uuid.UUID) bool
	History(ctx context.Context, matchID uuid.UUID, cursor string, limit int) ([]models.Message, error)
	CheckPaywall(ctx context.Context, matchID uuid.UUID) (locked bool, err error)
	SaveMessage(ctx context.Context, matchID, senderID uuid.UUID, content, msgType string) (*models.Message, error)
	IncrementPoints(ctx context.Context, matchID uuid.UUID) (before, after int)
}

type NoiLauServicer interface {
	IsMember(ctx context.Context, matchID, userID uuid.UUID) bool
	GetProgress(ctx context.Context, matchID uuid.UUID) (*models.NoiLauProgress, error)
}

type BookingServicer interface {
	Propose(ctx context.Context, matchID, userID uuid.UUID, in ProposeInput) (*models.Booking, error)
	Get(ctx context.Context, matchID, userID uuid.UUID) (*models.Booking, error)
	Confirm(ctx context.Context, matchID, userID uuid.UUID) (*models.Booking, error)
	Cancel(ctx context.Context, matchID, userID uuid.UUID) (*models.Booking, error)
}
