package services

import (
	"context"

	"github.com/anmates/api/models"
	"github.com/google/uuid"
)

type AuthServicer interface {
	RegisterUser(ctx context.Context, email, password, name string) (*models.User, error)
	LoginUser(ctx context.Context, email, password string) (*models.User, error)
	VerifyFirebaseToken(ctx context.Context, idToken string) (uid, phone string, err error)
	UpsertPhoneUser(ctx context.Context, uid, phone, name string) (*models.User, error)
	IssueTokens(ctx context.Context, userID uuid.UUID) (*Tokens, error)
	RotateRefreshToken(ctx context.Context, rawToken string) (*models.User, *Tokens, error)
	InvalidateRefreshToken(ctx context.Context, rawToken string) error
}

type UserServicer interface {
	GetProfile(ctx context.Context, userID uuid.UUID) (*models.User, error)
	UpdateProfile(ctx context.Context, userID uuid.UUID, name, avatarURL, bio *string) (*models.User, error)
}

type WishlistServicer interface {
	List(ctx context.Context, userID uuid.UUID) ([]models.Wishlist, error)
	Create(ctx context.Context, userID uuid.UUID, foodName, category string) (*models.Wishlist, error)
	Delete(ctx context.Context, userID, itemID uuid.UUID) error
}

type MatchingServicer interface {
	ListCandidates(ctx context.Context, userID uuid.UUID) ([]models.MatchCandidate, error)
	AcceptMatch(ctx context.Context, userID, targetID uuid.UUID) (*models.Match, error)
	Conversations(ctx context.Context, userID uuid.UUID) ([]models.Conversation, error)
}

type ChatServicer interface {
	IsMember(ctx context.Context, matchID, userID uuid.UUID) bool
	History(ctx context.Context, matchID uuid.UUID, cursor string, limit int) ([]models.Message, error)
	CheckPaywall(ctx context.Context, matchID uuid.UUID) (locked bool, err error)
	SaveMessage(ctx context.Context, matchID, senderID uuid.UUID, content, msgType string) (*models.Message, error)
	IncrementPoints(ctx context.Context, matchID uuid.UUID)
}

type NoiLauServicer interface {
	IsMember(ctx context.Context, matchID, userID uuid.UUID) bool
	GetProgress(ctx context.Context, matchID uuid.UUID) (*models.NoiLauProgress, error)
}
