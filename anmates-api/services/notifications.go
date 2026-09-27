package services

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Notification struct {
	ID        uuid.UUID  `json:"id"`
	Kind      string     `json:"kind"`
	MatchID   *uuid.UUID `json:"match_id"`
	ActorID   *uuid.UUID `json:"actor_id"`
	ActorName string     `json:"actor_name"`
	Read      bool       `json:"read"`
	CreatedAt time.Time  `json:"created_at"`
}

type NotificationList struct {
	Items  []Notification `json:"items"`
	Unread int            `json:"unread"`
}

type NotificationService struct{ pool *pgxpool.Pool }

func NewNotificationService(pool *pgxpool.Pool) *NotificationService {
	return &NotificationService{pool: pool}
}

// List returns the user's recent notifications plus their unread count.
func (s *NotificationService) List(ctx context.Context, userID uuid.UUID) (*NotificationList, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT n.id, n.kind, n.match_id, n.actor_id, COALESCE(u.name, ''), n.read_at IS NOT NULL, n.created_at
		FROM notifications n LEFT JOIN users u ON u.id = n.actor_id
		WHERE n.user_id = $1
		ORDER BY n.created_at DESC LIMIT 50
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := []Notification{}
	for rows.Next() {
		var n Notification
		if err := rows.Scan(&n.ID, &n.Kind, &n.MatchID, &n.ActorID, &n.ActorName, &n.Read, &n.CreatedAt); err != nil {
			return nil, err
		}
		items = append(items, n)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	var unread int
	if err := s.pool.QueryRow(ctx, `
		SELECT count(*) FROM notifications WHERE user_id = $1 AND read_at IS NULL
	`, userID).Scan(&unread); err != nil {
		return nil, err
	}

	return &NotificationList{Items: items, Unread: unread}, nil
}

// MarkAllRead marks all of the user's unread notifications as read.
func (s *NotificationService) MarkAllRead(ctx context.Context, userID uuid.UUID) error {
	_, err := s.pool.Exec(ctx, `
		UPDATE notifications SET read_at = now() WHERE user_id = $1 AND read_at IS NULL
	`, userID)
	return err
}
