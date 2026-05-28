package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
	"time"

	"github.com/anmates/api/internal/httputil"
	"github.com/anmates/api/middleware"
	"github.com/anmates/api/services"
	wsx "github.com/anmates/api/ws"
	"github.com/gofiber/contrib/websocket"
	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
)

type Chat struct {
	svc services.ChatServicer
	hub wsx.HubI
}

func NewChat(svc services.ChatServicer, hub wsx.HubI) *Chat {
	return &Chat{svc: svc, hub: hub}
}

// History returns paginated messages oldest→newest using cursor=created_at.
func (ch *Chat) History(c *fiber.Ctx) error {
	uid := middleware.UserID(c)
	matchID, err := uuid.Parse(c.Params("id"))
	if err != nil {
		return httputil.Err(c,fiber.StatusBadRequest, httputil.ErrValidation, "invalid match id")
	}

	ctx, cancel := context.WithTimeout(c.UserContext(), 30*time.Second)
	defer cancel()

	if !ch.svc.IsMember(ctx, matchID, uid) {
		return httputil.Err(c,fiber.StatusNotFound, httputil.ErrMatchNotFound, "match not found")
	}

	limit := c.QueryInt("limit", 50)
	if limit < 1 || limit > 200 {
		limit = 50
	}
	cursor := c.Query("cursor")
	if cursor != "" {
		if _, perr := time.Parse(time.RFC3339Nano, cursor); perr != nil {
			return httputil.Err(c,fiber.StatusBadRequest, httputil.ErrValidation, "invalid cursor")
		}
	}

	msgs, err := ch.svc.History(ctx, matchID, cursor, limit)
	if err != nil {
		return httputil.Err(c,fiber.StatusInternalServerError, httputil.ErrInternal, "query failed")
	}
	return httputil.OK(c,msgs)
}

// WebSocket is the Fiber handler installed at /ws/chat/:matchId.
func (ch *Chat) WebSocket() fiber.Handler {
	return websocket.New(func(conn *websocket.Conn) {
		matchID, ok := conn.Locals("match_id").(uuid.UUID)
		uid, okU := conn.Locals("user_id").(uuid.UUID)
		if !ok || !okU {
			_ = conn.Close()
			return
		}
		client := wsx.NewClient(conn, ch.hub, matchID, uid, ch.onIncoming)
		client.Run()
	})
}

type incomingMessage struct {
	Content string `json:"content"`
	MsgType string `json:"msg_type"`
}

// onIncoming processes one inbound envelope; persists messages, updates Nồi Lẩu, enforces paywall.
func (ch *Chat) onIncoming(matchID, senderID uuid.UUID, env wsx.Envelope) (wsx.Envelope, error) {
	switch env.Type {
	case "typing":
		out, _ := json.Marshal(map[string]string{"user_id": senderID.String()})
		return wsx.Envelope{Type: "typing", Payload: out}, nil

	case "read":
		return wsx.Envelope{Type: "read", Payload: env.Payload}, nil

	case "message":
		var in incomingMessage
		if err := json.Unmarshal(env.Payload, &in); err != nil {
			return wsx.Envelope{}, errors.New("invalid payload")
		}
		in.Content = strings.TrimSpace(in.Content)
		if in.Content == "" || len(in.Content) > 2000 {
			return wsx.Envelope{}, errors.New("content empty or too long")
		}
		if in.MsgType == "" {
			in.MsgType = "text"
		}

		ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()

		locked, _ := ch.svc.CheckPaywall(ctx, matchID)
		if locked {
			return wsx.Envelope{}, errors.New("chat locked at level 3 — upgrade to continue")
		}

		saved, err := ch.svc.SaveMessage(ctx, matchID, senderID, in.Content, in.MsgType)
		if err != nil {
			return wsx.Envelope{}, errors.New("save failed")
		}

		ch.svc.IncrementPoints(ctx, matchID)

		payload, _ := json.Marshal(saved)
		return wsx.Envelope{Type: "message", Payload: payload}, nil
	}
	return wsx.Envelope{}, errors.New("unknown type")
}

// WSAuth runs JWT auth, validates the user is in the match, then chains to the WS upgrade.
func (ch *Chat) WSAuth(secret []byte) fiber.Handler {
	return func(c *fiber.Ctx) error {
		if err := middleware.ValidateBearer(c, secret); err != nil {
			return err
		}
		matchID, err := uuid.Parse(c.Params("matchId"))
		if err != nil {
			return httputil.Err(c,fiber.StatusBadRequest, httputil.ErrValidation, "invalid match id")
		}
		uid := middleware.UserID(c)

		ctx, cancel := context.WithTimeout(c.UserContext(), 5*time.Second)
		defer cancel()
		if !ch.svc.IsMember(ctx, matchID, uid) {
			return httputil.Err(c,fiber.StatusNotFound, httputil.ErrMatchNotFound, "match not found")
		}

		c.Locals("match_id", matchID)
		c.Locals("user_id", uid)
		if !websocket.IsWebSocketUpgrade(c) {
			return fiber.ErrUpgradeRequired
		}
		return c.Next()
	}
}
