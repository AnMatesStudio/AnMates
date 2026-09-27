package ws

import (
	"encoding/json"
	"sync"

	"github.com/google/uuid"
)

// UserHub tracks each user's open /ws/notify connections on this replica. Replicas don't share it: every replica
// LISTENs to Postgres (pg_notify) and delivers to the sockets it holds, so no Redis is needed for this channel.
type UserHub struct {
	mu    sync.RWMutex
	conns map[uuid.UUID]map[*Client]struct{}
}

func NewUserHub() *UserHub {
	return &UserHub{conns: make(map[uuid.UUID]map[*Client]struct{})}
}

func (h *UserHub) Add(userID uuid.UUID, c *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()
	cons, ok := h.conns[userID]
	if !ok {
		cons = make(map[*Client]struct{})
		h.conns[userID] = cons
	}
	cons[c] = struct{}{}
}

// Remove drops the connection from the user's set, dropping the user key when the last conn goes.
func (h *UserHub) Remove(userID uuid.UUID, c *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if cons, ok := h.conns[userID]; ok {
		delete(cons, c)
		if len(cons) == 0 {
			delete(h.conns, userID)
		}
	}
}

// SendToUser queues env to every connection of the user on this replica and
// returns how many conns it was queued to. Uses the same non-blocking send as
// Hub.Broadcast: a full buffer drops the message for that client.
func (h *UserHub) SendToUser(userID uuid.UUID, env Envelope) int {
	h.mu.RLock()
	cons := h.conns[userID]
	clients := make([]*Client, 0, len(cons))
	for c := range cons {
		clients = append(clients, c)
	}
	h.mu.RUnlock()

	data, err := json.Marshal(env)
	if err != nil {
		return 0
	}
	for _, c := range clients {
		select {
		case c.send <- data:
		default:
			// Drop on backpressure; client will be cleaned up by its read loop.
		}
	}
	return len(clients)
}

// Count returns total open conns across all users (for logs/metrics).
func (h *UserHub) Count() int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	n := 0
	for _, cons := range h.conns {
		n += len(cons)
	}
	return n
}
