package ws

import (
	"testing"

	"github.com/google/uuid"
)

// newUserClient builds a Client just for its send channel — the ws conn, room
// hub, and handler are never touched by UserHub.
func newUserClient(userID uuid.UUID) *Client {
	return NewClient(nil, nil, uuid.New(), userID, nil)
}

func TestUserHub(t *testing.T) {
	hub := NewUserHub()
	u1 := uuid.New()
	u2 := uuid.New()
	c1a := newUserClient(u1)
	c1b := newUserClient(u1)
	c2 := newUserClient(u2)

	hub.Add(u1, c1a)
	hub.Add(u1, c1b)
	hub.Add(u2, c2)

	if got := hub.SendToUser(u1, Envelope{Type: "system"}); got != 2 {
		t.Fatalf("SendToUser(u1) = %d, want 2", got)
	}
	if got := hub.Count(); got != 3 {
		t.Fatalf("Count() = %d, want 3", got)
	}

	hub.Remove(u1, c1a)
	if got := hub.SendToUser(u1, Envelope{Type: "system"}); got != 1 {
		t.Fatalf("SendToUser(u1) after Remove = %d, want 1", got)
	}

	hub.Remove(u1, c1b)
	if got := hub.Count(); got != 1 {
		t.Fatalf("Count() after removing last conn of u1 = %d, want 1", got)
	}
	hub.mu.RLock()
	_, keyPresent := hub.conns[u1]
	hub.mu.RUnlock()
	if keyPresent {
		t.Fatal("user key for u1 still present after last conn removed")
	}
	if _, keyPresent2 := hub.conns[u2]; !keyPresent2 {
		t.Fatal("user key for u2 unexpectedly gone")
	}
}
