package services

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PushSubscription struct {
	Endpoint string
	P256dh   string
	Auth     string
}

// NotificationPayload is what both delivery channels send (WebSocket envelope payload and the encrypted Web Push body).
type NotificationPayload struct {
	ID        uuid.UUID  `json:"id"`
	UserID    uuid.UUID  `json:"-"`
	Kind      string     `json:"kind"`
	MatchID   *uuid.UUID `json:"match_id"`
	ActorName string     `json:"actor_name"`
	Title     string     `json:"title"`
	Body      string     `json:"body"`
	URL       string     `json:"url"`
	CreatedAt time.Time  `json:"created_at"`
}

type PushService struct{ pool *pgxpool.Pool }

func NewPushService(pool *pgxpool.Pool) *PushService { return &PushService{pool: pool} }

// Subscribe registers (or re-registers) one of the user's browser push endpoints.
func (s *PushService) Subscribe(ctx context.Context, userID uuid.UUID, sub PushSubscription, userAgent string) error {
	_, err := s.pool.Exec(ctx, `
		INSERT INTO push_subscriptions (user_id, endpoint, p256dh, auth, user_agent)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (endpoint) DO UPDATE SET
			user_id = EXCLUDED.user_id,
			p256dh  = EXCLUDED.p256dh,
			auth    = EXCLUDED.auth,
			user_agent = EXCLUDED.user_agent,
			last_used_at = now()
	`, userID, sub.Endpoint, sub.P256dh, sub.Auth, userAgent)
	return err
}

// Unsubscribe removes the user's own push endpoint.
func (s *PushService) Unsubscribe(ctx context.Context, userID uuid.UUID, endpoint string) error {
	_, err := s.pool.Exec(ctx, `DELETE FROM push_subscriptions WHERE user_id = $1 AND endpoint = $2`, userID, endpoint)
	return err
}

// DeleteEndpoint removes a (dead) push endpoint regardless of who owned it.
func (s *PushService) DeleteEndpoint(ctx context.Context, endpoint string) error {
	_, err := s.pool.Exec(ctx, `DELETE FROM push_subscriptions WHERE endpoint = $1`, endpoint)
	return err
}

// Subscriptions lists all of the user's push endpoints.
func (s *PushService) Subscriptions(ctx context.Context, userID uuid.UUID) ([]PushSubscription, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT endpoint, p256dh, auth
		FROM push_subscriptions
		WHERE user_id = $1
		ORDER BY created_at
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	subs := []PushSubscription{}
	for rows.Next() {
		var sub PushSubscription
		if err := rows.Scan(&sub.Endpoint, &sub.P256dh, &sub.Auth); err != nil {
			return nil, err
		}
		subs = append(subs, sub)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return subs, nil
}

// ClaimPush marks a notification as push-delivered; it reports true only for the claimant that set pushed_at.
func (s *PushService) ClaimPush(ctx context.Context, notificationID uuid.UUID) (bool, error) {
	tag, err := s.pool.Exec(ctx, `UPDATE notifications SET pushed_at = now() WHERE id = $1 AND pushed_at IS NULL`, notificationID)
	if err != nil {
		return false, err
	}
	return tag.RowsAffected() == 1, nil
}

// Load fetches a notification and builds its display payload (title, URL, localized body).
func (s *PushService) Load(ctx context.Context, notificationID uuid.UUID) (*NotificationPayload, error) {
	var p NotificationPayload
	err := s.pool.QueryRow(ctx, `
		SELECT n.id, n.user_id, n.kind, n.match_id, COALESCE(u.name, ''), n.created_at
		FROM notifications n
		LEFT JOIN users u ON u.id = n.actor_id
		WHERE n.id = $1
	`, notificationID).Scan(&p.ID, &p.UserID, &p.Kind, &p.MatchID, &p.ActorName, &p.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}

	who := p.ActorName
	if who == "" {
		who = "Mate"
	}
	p.Title = "ĂnMates"
	p.URL = "/"
	switch p.Kind {
	case "match":
		p.Body = fmt.Sprintf("Bạn và %s đã match!", who)
	case "message":
		p.Body = fmt.Sprintf("%s vừa nhắn tin cho bạn", who)
	case "booking_proposed":
		p.Body = fmt.Sprintf("%s mời bạn đi ăn — xem lịch hẹn", who)
	case "booking_confirmed":
		p.Body = fmt.Sprintf("%s đã xác nhận lịch hẹn", who)
	case "booking_cancelled":
		p.Body = "Một lịch hẹn đã bị huỷ"
	case "rating":
		p.Body = fmt.Sprintf("%s đã đánh giá bữa ăn — rate lại để xem", who)
	default:
		p.Body = "Bạn có thông báo mới"
	}
	return &p, nil
}
