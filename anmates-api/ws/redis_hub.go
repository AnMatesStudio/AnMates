//go:build ignore
// +build ignore
// To activate: run `go get github.com/redis/go-redis/v9`, remove the build
// tags above, and set REDIS_URL in your environment. main.go already wires
// NewRedisHub when cfg.RedisURL is non-empty.

package ws

import (
	"context"
	"encoding/json"
	"log/slog"
	"sync"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9" // go get github.com/redis/go-redis/v9
)

const redisChanPrefix = "anmates:chat:"

// RedisHub implements HubI using Redis pub/sub as the broadcast backplane.
// Each instance subscribes to per-match channels; Broadcast publishes to Redis
// so all instances in the cluster receive the message.
type RedisHub struct {
	rdb     *redis.Client
	local   *Hub // local client registry — delivery still happens in-process
	mu      sync.RWMutex
	subs    map[uuid.UUID]*redis.PubSub // one sub per active match room
	ctx     context.Context
	cancel  context.CancelFunc
}

type redisEnvelope struct {
	SenderID uuid.UUID `json:"sender_id"`
	Env      Envelope  `json:"env"`
}

func NewRedisHub(redisURL string) (*RedisHub, error) {
	opt, err := redis.ParseURL(redisURL)
	if err != nil {
		return nil, err
	}
	ctx, cancel := context.WithCancel(context.Background())
	rh := &RedisHub{
		rdb:    redis.NewClient(opt),
		local:  NewHub(),
		subs:   make(map[uuid.UUID]*redis.PubSub),
		ctx:    ctx,
		cancel: cancel,
	}
	return rh, nil
}

func (rh *RedisHub) Join(matchID uuid.UUID, c *Client) {
	rh.local.Join(matchID, c)
	rh.mu.Lock()
	defer rh.mu.Unlock()
	if _, ok := rh.subs[matchID]; !ok {
		sub := rh.rdb.Subscribe(rh.ctx, redisChanPrefix+matchID.String())
		rh.subs[matchID] = sub
		go rh.subscribeLoop(matchID, sub)
	}
}

func (rh *RedisHub) Leave(matchID uuid.UUID, c *Client) {
	rh.local.Leave(matchID, c)
	rh.mu.Lock()
	defer rh.mu.Unlock()
	// Unsubscribe when room is empty.
	rh.local.mu.RLock()
	empty := len(rh.local.rooms[matchID]) == 0
	rh.local.mu.RUnlock()
	if empty {
		if sub, ok := rh.subs[matchID]; ok {
			_ = sub.Close()
			delete(rh.subs, matchID)
		}
	}
}

// Broadcast publishes to Redis; subscribeLoop delivers to local clients.
func (rh *RedisHub) Broadcast(matchID, senderID uuid.UUID, env Envelope) {
	msg, err := json.Marshal(redisEnvelope{SenderID: senderID, Env: env})
	if err != nil {
		return
	}
	if err := rh.rdb.Publish(rh.ctx, redisChanPrefix+matchID.String(), msg).Err(); err != nil {
		slog.Warn("redis publish", "match", matchID, "err", err)
	}
}

// subscribeLoop reads from Redis and fans out to local clients, excluding the
// original sender (identified by SenderID in the payload).
func (rh *RedisHub) subscribeLoop(matchID uuid.UUID, sub *redis.PubSub) {
	ch := sub.Channel()
	for msg := range ch {
		var re redisEnvelope
		if err := json.Unmarshal([]byte(msg.Payload), &re); err != nil {
			continue
		}
		rh.local.Broadcast(matchID, re.SenderID, re.Env)
	}
}

func (rh *RedisHub) CloseAll() {
	rh.cancel()
	rh.mu.Lock()
	for _, sub := range rh.subs {
		_ = sub.Close()
	}
	rh.subs = make(map[uuid.UUID]*redis.PubSub)
	rh.mu.Unlock()
	rh.local.CloseAll()
}
