package ws

import (
	"encoding/json"
	"time"

	"github.com/gofiber/contrib/websocket"
	"github.com/google/uuid"
)

const (
	writeWait      = 10 * time.Second
	pongWait       = 60 * time.Second
	pingPeriod     = (pongWait * 9) / 10
	maxMessageSize = 4 * 1024 // 4 KB per chat message is more than enough.
)

// MessageHandler persists an inbound user message and returns the canonical
// envelope to broadcast to other room members. Errors abort the inbound message
// but don't tear down the connection.
type MessageHandler func(matchID, senderID uuid.UUID, env Envelope) (Envelope, error)

// Client wraps one WebSocket connection. read/write run as goroutines.
type Client struct {
	conn    *websocket.Conn
	hub     HubI
	matchID uuid.UUID
	userID  uuid.UUID
	send    chan []byte
	onMsg   MessageHandler
}

func NewClient(conn *websocket.Conn, hub HubI, matchID, userID uuid.UUID, onMsg MessageHandler) *Client {
	return &Client{
		conn:    conn,
		hub:     hub,
		matchID: matchID,
		userID:  userID,
		send:    make(chan []byte, 16),
		onMsg:   onMsg,
	}
}

// Run blocks until the connection closes. Spawns the writer; reader runs inline.
func (c *Client) Run() {
	c.hub.Join(c.matchID, c)
	defer func() {
		c.hub.Leave(c.matchID, c)
		_ = c.conn.Close()
	}()

	go c.writeLoop()
	c.readLoop()
}

func (c *Client) readLoop() {
	c.conn.SetReadLimit(maxMessageSize)
	_ = c.conn.SetReadDeadline(time.Now().Add(pongWait))
	c.conn.SetPongHandler(func(string) error {
		_ = c.conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})

	for {
		_, data, err := c.conn.ReadMessage()
		if err != nil {
			return
		}
		var env Envelope
		if err := json.Unmarshal(data, &env); err != nil {
			continue
		}
		out, err := c.onMsg(c.matchID, c.userID, env)
		if err != nil {
			// Notify only the sender of failures (e.g. chat locked).
			notice, _ := json.Marshal(Envelope{Type: "error", Payload: json.RawMessage(`{"message":"` + err.Error() + `"}`)})
			select {
			case c.send <- notice:
			default:
			}
			continue
		}
		if out.Type != "" {
			c.hub.Broadcast(c.matchID, c.userID, out)
		}
	}
}

func (c *Client) writeLoop() {
	ticker := time.NewTicker(pingPeriod)
	defer ticker.Stop()

	for {
		select {
		case msg, ok := <-c.send:
			_ = c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				_ = c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			if err := c.conn.WriteMessage(websocket.TextMessage, msg); err != nil {
				return
			}
		case <-ticker.C:
			_ = c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}
