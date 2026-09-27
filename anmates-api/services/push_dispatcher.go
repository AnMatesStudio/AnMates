package services

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/url"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/anmates/api/ws"
)

// PushDispatcher turns every new notification row into deliveries. Each replica runs one: it LISTENs on
// 'anm_notification' (see 022_push.sql), relays to its own WebSocket clients, and races the other replicas to
// ClaimPush — only the winner sends the Web Push, so a user never gets duplicates.
type PushDispatcher struct {
	pool   *pgxpool.Pool
	store  *PushService
	hub    *ws.UserHub
	sender *WebPushSender // nil = Web Push disabled (no VAPID keys) — realtime still works
	log    *slog.Logger
}

func NewPushDispatcher(pool *pgxpool.Pool, store *PushService, hub *ws.UserHub, sender *WebPushSender, log *slog.Logger) *PushDispatcher {
	return &PushDispatcher{pool: pool, store: store, hub: hub, sender: sender, log: log}
}

// Run blocks until ctx is done, reconnecting with backoff (1 s doubling to 30 s) if the LISTEN connection drops.
func (d *PushDispatcher) Run(ctx context.Context) {
	backoff := time.Second
	for ctx.Err() == nil {
		conn, err := d.pool.Acquire(ctx)
		if err != nil {
			if ctx.Err() != nil {
				return
			}
			d.log.Warn("push: acquire listener connection", "err", err)
		} else {
			_, err = conn.Exec(ctx, "LISTEN anm_notification")
			if err == nil {
				backoff = time.Second // a clean session reset the backoff
				for {
					n, err := conn.Conn().WaitForNotification(ctx)
					if err != nil {
						break
					}
					id, perr := uuid.Parse(n.Payload)
					if perr != nil {
						d.log.Warn("push: bad notification id", "payload", n.Payload, "err", perr)
						continue
					}
					go d.deliver(ctx, id) // don't block the listener
				}
			}
			conn.Release()
			if ctx.Err() != nil {
				return
			}
			d.log.Warn("push: LISTEN session dropped", "err", err)
		}
		select {
		case <-ctx.Done():
			return
		case <-time.After(backoff):
		}
		if backoff *= 2; backoff > 30*time.Second {
			backoff = 30 * time.Second
		}
	}
}

func (d *PushDispatcher) deliver(ctx context.Context, id uuid.UUID) {
	ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()

	p, err := d.store.Load(ctx, id)
	if err != nil {
		d.log.Warn("push: load notification", "id", id, "err", err)
		return
	}

	body, err := json.Marshal(p)
	if err != nil {
		d.log.Warn("push: marshal payload", "id", id, "err", err)
		return
	}
	// Realtime first: always delivered to this replica's own sockets, regardless of the push race.
	d.hub.SendToUser(p.UserID, ws.Envelope{Type: "notification", Payload: json.RawMessage(body)})

	if d.sender == nil {
		return // Web Push disabled (no VAPID keys)
	}
	won, err := d.store.ClaimPush(ctx, p.ID)
	if err != nil {
		d.log.Warn("push: claim", "id", p.ID, "err", err)
		return
	}
	if !won {
		return // another replica is sending the Web Push
	}
	subs, err := d.store.Subscriptions(ctx, p.UserID)
	if err != nil {
		d.log.Warn("push: subscriptions", "user", p.UserID, "err", err)
		return
	}
	for _, sub := range subs {
		status, err := d.sender.Send(ctx, sub, body)
		switch {
		case err != nil:
			d.log.Warn("push: send", "endpoint", endpointHost(sub.Endpoint), "err", err)
		case status == 404 || status == 410:
			if err := d.store.DeleteEndpoint(ctx, sub.Endpoint); err != nil && !errors.Is(err, context.Canceled) {
				d.log.Warn("push: delete dead endpoint", "endpoint", endpointHost(sub.Endpoint), "err", err)
			} else {
				d.log.Info("push: dropped dead endpoint", "endpoint", endpointHost(sub.Endpoint))
			}
		default:
			d.log.Debug("push: sent", "user", p.UserID, "status", status)
		}
	}
}

// endpointHost reduces a push endpoint URL to its host so logs never carry full endpoint URLs or keys.
func endpointHost(raw string) string {
	u, err := url.Parse(raw)
	if err != nil || u.Host == "" {
		return raw
	}
	return u.Host
}
