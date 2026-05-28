package ws

import (
	"encoding/json"
	"sync"

	"github.com/google/uuid"
)

// Envelope is the wire format for chat WebSocket messages.
type Envelope struct {
	Type    string          `json:"type"` // "message" | "typing" | "read" | "system"
	Payload json.RawMessage `json:"payload,omitempty"`
}

// HubI is the broadcast backplane interface. The local Hub is single-process;
// swap to RedisHub (ws/redis_hub.go) for multi-instance deployments.
type HubI interface {
	Join(matchID uuid.UUID, c *Client)
	Leave(matchID uuid.UUID, c *Client)
	// Broadcast sends env to every client in the room except the sender.
	// senderID is used instead of *Client so Redis-backed hubs can exclude
	// the originating user across nodes.
	Broadcast(matchID, senderID uuid.UUID, env Envelope)
	CloseAll()
}

// Hub multiplexes connections by match (room). Single-instance only — no
// cross-node backplane. Swap to RedisHub for >1 instance.
type Hub struct {
	mu    sync.RWMutex
	rooms map[uuid.UUID]map[*Client]struct{}
}

func NewHub() *Hub {
	return &Hub{rooms: make(map[uuid.UUID]map[*Client]struct{})}
}

func (h *Hub) Join(matchID uuid.UUID, c *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()
	room, ok := h.rooms[matchID]
	if !ok {
		room = make(map[*Client]struct{})
		h.rooms[matchID] = room
	}
	room[c] = struct{}{}
}

func (h *Hub) Leave(matchID uuid.UUID, c *Client) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if room, ok := h.rooms[matchID]; ok {
		delete(room, c)
		if len(room) == 0 {
			delete(h.rooms, matchID)
		}
	}
}

// Broadcast sends env to every client in the room except the one whose userID
// matches senderID. Slow clients are dropped rather than blocking the broadcast.
func (h *Hub) Broadcast(matchID, senderID uuid.UUID, env Envelope) {
	h.mu.RLock()
	room := h.rooms[matchID]
	clients := make([]*Client, 0, len(room))
	for c := range room {
		if c.userID != senderID {
			clients = append(clients, c)
		}
	}
	h.mu.RUnlock()

	data, err := json.Marshal(env)
	if err != nil {
		return
	}
	for _, c := range clients {
		select {
		case c.send <- data:
		default:
			// Drop on backpressure; client will be cleaned up by its read loop.
		}
	}
}

// CloseAll forces every connection to shut down; called during graceful shutdown.
func (h *Hub) CloseAll() {
	h.mu.Lock()
	defer h.mu.Unlock()
	for _, room := range h.rooms {
		for c := range room {
			close(c.send)
		}
	}
	h.rooms = make(map[uuid.UUID]map[*Client]struct{})
}
