package models

import (
	"time"

	"github.com/google/uuid"
)

type User struct {
	ID           uuid.UUID `json:"id"`
	Email        *string   `json:"email,omitempty"`
	PasswordHash *string   `json:"-"`
	Name         string    `json:"name"`
	AvatarURL    *string   `json:"avatar_url,omitempty"`
	Bio          *string   `json:"bio,omitempty"`
	Phone        *string   `json:"phone,omitempty"`
	FirebaseUID  *string   `json:"-"`
	CreatedAt    time.Time `json:"created_at"`
}

type Wishlist struct {
	ID           uuid.UUID `json:"id"`
	UserID       uuid.UUID `json:"user_id"`
	FoodName     string    `json:"food_name"`
	FoodCategory string    `json:"food_category"`
	CreatedAt    time.Time `json:"created_at"`
}

type Match struct {
	ID        uuid.UUID `json:"id"`
	UserAID   uuid.UUID `json:"user_a_id"`
	UserBID   uuid.UUID `json:"user_b_id"`
	Status    string    `json:"status"`
	Score     float64   `json:"score"`
	CreatedAt time.Time `json:"created_at"`
}

type Message struct {
	ID        uuid.UUID `json:"id"`
	MatchID   uuid.UUID `json:"match_id"`
	SenderID  uuid.UUID `json:"sender_id"`
	Content   string    `json:"content"`
	MsgType   string    `json:"msg_type"`
	CreatedAt time.Time `json:"created_at"`
}

type NoiLauProgress struct {
	MatchID       uuid.UUID  `json:"match_id"`
	Points        int        `json:"points"`
	Level         int        `json:"level"`
	NextThreshold *int       `json:"next_threshold"`
	Locked        bool       `json:"locked"`
	LastActivity  *time.Time `json:"last_activity"`
}

// MatchCandidate is what GET /api/matches returns — not persisted.
type MatchCandidate struct {
	UserID       uuid.UUID `json:"user_id"`
	Name         string    `json:"name"`
	AvatarURL    *string   `json:"avatar_url,omitempty"`
	OverlapCount int       `json:"overlap_count"`
	OverlapFoods []string  `json:"overlap_foods"`
	Score        float64   `json:"score"`
}

// Conversation is what GET /api/conversations returns — accepted matches with partner info.
type Conversation struct {
	MatchID          uuid.UUID  `json:"match_id"`
	PartnerID        uuid.UUID  `json:"partner_id"`
	PartnerName      string     `json:"partner_name"`
	PartnerAvatarURL *string    `json:"partner_avatar_url,omitempty"`
	LastMessage      *string    `json:"last_message,omitempty"`
	LastMessageAt    *time.Time `json:"last_message_at,omitempty"`
	Score            float64    `json:"score"`
	CreatedAt        time.Time  `json:"created_at"`
}

// NoiLauThresholds maps level index to minimum point threshold (level 1 = 0 pts, level 5 = 100 pts).
var NoiLauThresholds = []int{0, 10, 30, 60, 100}

// LevelForPoints returns the level (1..5) for a given point total.
func LevelForPoints(p int) int {
	level := 1
	for i, t := range NoiLauThresholds {
		if p >= t {
			level = i + 1
		}
	}
	return level
}

// NextThreshold returns the points needed for the next level, or nil if maxed.
func NextThreshold(p int) *int {
	for _, t := range NoiLauThresholds {
		if t > p {
			v := t
			return &v
		}
	}
	return nil
}
