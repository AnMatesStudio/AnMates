package ws

import (
	"strings"
	"testing"
)

// REDIS_URL rỗng -> single replica, in-process Hub. Đây là default path của MVP:
// không phụ thuộc Redis, không được trả error.
func TestNewBackplane_NoRedisURLReturnsLocalHub(t *testing.T) {
	hub, err := NewBackplane("")
	if err != nil {
		t.Fatalf("NewBackplane(%q): %v", "", err)
	}
	if _, ok := hub.(*Hub); !ok {
		t.Errorf("expect *Hub khi REDIS_URL rỗng, got %T", hub)
	}
}

// REDIS_URL có giá trị -> RedisHub làm broadcast backplane. go-redis connect
// lazy nên constructor không cần Redis server thật.
func TestNewBackplane_RedisURLReturnsRedisHub(t *testing.T) {
	hub, err := NewBackplane("redis://anmates-redis.anmates.svc.cluster.local:6379")
	if err != nil {
		t.Fatalf("NewBackplane: %v", err)
	}
	if _, ok := hub.(*RedisHub); !ok {
		t.Fatalf("expect *RedisHub khi có REDIS_URL, got %T", hub)
	}
	hub.CloseAll()
}

// REDIS_URL là connection string đầy đủ (kể cả credential) và được inject từ
// Secret `anmates-api`, giống DATABASE_URL. redis.ParseURL phải giữ được
// password nhúng trong URL.
func TestNewBackplane_ParsesCredentialsFromConnectionString(t *testing.T) {
	hub, err := NewBackplane("redis://:s3cret@anmates-redis.anmates.svc.cluster.local:6379/0")
	if err != nil {
		t.Fatalf("NewBackplane: %v", err)
	}
	rh, ok := hub.(*RedisHub)
	if !ok {
		t.Fatalf("expect *RedisHub, got %T", hub)
	}
	defer rh.CloseAll()

	opt := rh.rdb.Options()
	if opt.Password != "s3cret" {
		t.Errorf("Password = %q, want %q", opt.Password, "s3cret")
	}
	if opt.DB != 0 {
		t.Errorf("DB = %d, want 0", opt.DB)
	}
}

// Malformed REDIS_URL phải fail fast lúc startup thay vì để pod chạy với
// backplane hỏng — WebSocket broadcast sẽ im lặng mất message.
func TestNewBackplane_InvalidURLReturnsError(t *testing.T) {
	_, err := NewBackplane("http://not-a-redis-url")
	if err == nil {
		t.Fatal("expect error với scheme không phải redis, got nil")
	}
	if !strings.Contains(strings.ToLower(err.Error()), "redis") {
		t.Errorf("error message nên nhắc redis để dễ triage, got: %v", err)
	}
}
