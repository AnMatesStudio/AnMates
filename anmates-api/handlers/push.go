package handlers

import (
	"context"
	"encoding/base64"
	"time"

	"github.com/anmates/api/internal/httputil"
	"github.com/anmates/api/middleware"
	"github.com/anmates/api/services"
	wsx "github.com/anmates/api/ws"
	"github.com/gofiber/contrib/websocket"
	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
)

type Push struct {
	store    *services.PushService
	sender   *services.WebPushSender // nil when VAPID keys are not configured
	hub      *wsx.UserHub
	allowAny bool // DEV_MODE: accept non-vendor endpoints (tests)
}

func NewPush(store *services.PushService, sender *services.WebPushSender, hub *wsx.UserHub, allowAny bool) *Push {
	return &Push{store: store, sender: sender, hub: hub, allowAny: allowAny}
}

type subscribeReq struct {
	Endpoint string `json:"endpoint"`
	Keys     struct {
		P256dh string `json:"p256dh"`
		Auth   string `json:"auth"`
	} `json:"keys"`
}

type unsubscribeReq struct {
	Endpoint string `json:"endpoint"`
}

// VapidPublicKey handles GET /push/vapid-public-key (public): returns the browser's
// push subscription public key, or 503 when Web Push is not configured.
func (p *Push) VapidPublicKey(c *fiber.Ctx) error {
	if p.sender == nil {
		return httputil.Err(c, fiber.StatusServiceUnavailable, "UNAVAILABLE", "web push not configured")
	}
	return httputil.OK(c, fiber.Map{"key": p.sender.PublicKey()})
}

// Subscribe handles POST /push/subscribe (auth): registers (or re-registers) one
// of the user's browser push endpoints after validating it.
func (p *Push) Subscribe(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	var r subscribeReq
	if err := c.BodyParser(&r); err != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid body")
	}
	if r.Endpoint == "" || !services.AllowedPushEndpoint(r.Endpoint, p.allowAny) {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "unsupported push endpoint")
	}
	pub, err := base64.RawURLEncoding.DecodeString(r.Keys.P256dh)
	if err != nil {
		pub, err = base64.URLEncoding.DecodeString(r.Keys.P256dh)
	}
	if err != nil || len(pub) != 65 || pub[0] != 0x04 {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid subscription keys")
	}
	auth, err := base64.RawURLEncoding.DecodeString(r.Keys.Auth)
	if err != nil {
		auth, err = base64.URLEncoding.DecodeString(r.Keys.Auth)
	}
	if err != nil || len(auth) != 16 {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid subscription keys")
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), 10*time.Second)
	defer cancel()
	sub := services.PushSubscription{
		Endpoint: r.Endpoint,
		P256dh:   r.Keys.P256dh,
		Auth:     r.Keys.Auth,
	}
	if err := p.store.Subscribe(ctx, uid, sub, c.Get("User-Agent")); err != nil {
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "subscribe failed")
	}
	return httputil.OK(c, fiber.Map{"subscribed": true})
}

// Unsubscribe handles POST /push/unsubscribe (auth): removes the user's own push endpoint.
func (p *Push) Unsubscribe(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	var r unsubscribeReq
	if err := c.BodyParser(&r); err != nil {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "invalid body")
	}
	if r.Endpoint == "" {
		return httputil.Err(c, fiber.StatusBadRequest, httputil.ErrValidation, "endpoint required")
	}
	ctx, cancel := context.WithTimeout(c.UserContext(), 10*time.Second)
	defer cancel()
	if err := p.store.Unsubscribe(ctx, uid, r.Endpoint); err != nil {
		return httputil.Err(c, fiber.StatusInternalServerError, httputil.ErrInternal, "unsubscribe failed")
	}
	return httputil.OK(c, fiber.Map{"unsubscribed": true})
}

// NotifyAuth handles the auth step of /ws/notify: validates the bearer token
// (?access_token=) and chains to the WebSocket upgrade.
func (p *Push) NotifyAuth(secret []byte) fiber.Handler {
	return func(c *fiber.Ctx) error {
		if err := middleware.ValidateBearer(c, secret); err != nil {
			return httputil.Err(c, fiber.StatusUnauthorized, httputil.ErrUnauthorized, "unauthorized")
		}
		uid := middleware.UserID(c)
		c.Locals("user_id", uid)
		if !websocket.IsWebSocketUpgrade(c) {
			return fiber.ErrUpgradeRequired
		}
		return c.Next()
	}
}

// NotifyWS handles /ws/notify: one server→client notification socket per user.
func (p *Push) NotifyWS() fiber.Handler {
	return websocket.New(func(conn *websocket.Conn) {
		uid, ok := conn.Locals("user_id").(uuid.UUID)
		if !ok {
			_ = conn.Close()
			return
		}
		// The user channel has no match room, so the client's HubI seam is a no-op;
		// registration with the UserHub is what SendToUser keys off.
		client := wsx.NewClient(conn, noopHub{}, uuid.Nil, uid, nil)
		p.hub.Add(uid, client)
		defer p.hub.Remove(uid, client)

		go p.writePump(client)
		// Server→client only: read and discard until the peer closes.
		_ = conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		conn.SetPongHandler(func(string) error {
			_ = conn.SetReadDeadline(time.Now().Add(60 * time.Second))
			return nil
		})
		for {
			if _, _, err := conn.ReadMessage(); err != nil {
				break
			}
		}
	})
}

// writePump drains the client's outbound channel onto the socket until it closes.
func (p *Push) writePump(client *wsx.Client) {
	for msg := range client.Send() {
		_ = client.Conn().SetWriteDeadline(time.Now().Add(10 * time.Second))
		if err := client.Conn().WriteMessage(websocket.TextMessage, msg); err != nil {
			return
		}
	}
}

// noopHub is a no-op room hub: the notify channel is per-user with no match room,
// so the Client's Join/Leave/Broadcast seam is unused.
type noopHub struct{}

func (noopHub) Join(uuid.UUID, *wsx.Client)                   {}
func (noopHub) Leave(uuid.UUID, *wsx.Client)                  {}
func (noopHub) Broadcast(uuid.UUID, uuid.UUID, wsx.Envelope)  {}
func (noopHub) CloseAll()                                     {}
