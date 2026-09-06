package ws

import "fmt"

// NewBackplane chọn broadcast backplane theo REDIS_URL.
//
// redisURL rỗng  -> in-process Hub. Chỉ đúng khi api chạy SINGLE replica:
//
//	Broadcast chỉ tới được client đang giữ WebSocket connection
//	với chính pod đó. Scale ra nhiều replica mà vẫn dùng Hub này
//	thì message mất im lặng — không error, không log.
//
// redisURL có    -> RedisHub, dùng Redis pub/sub làm backplane giữa các replica.
//
//	Đây là precondition để bật HPA cho anmates-api.
//
// redisURL là connection string đầy đủ (kể cả credential), inject từ Secret
// `anmates-api` giống DATABASE_URL — không tách password thành env riêng.
//
// Malformed URL trả error để fail fast lúc startup, thay vì để pod Ready với
// backplane hỏng.
func NewBackplane(redisURL string) (HubI, error) {
	if redisURL == "" {
		return NewHub(), nil
	}
	rh, err := NewRedisHub(redisURL)
	if err != nil {
		return nil, fmt.Errorf("redis backplane: %w", err)
	}
	return rh, nil
}
