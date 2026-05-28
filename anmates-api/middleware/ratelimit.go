package middleware

import (
	"sync"
	"time"

	"github.com/anmates/api/internal/httputil"
	"github.com/gofiber/fiber/v2"
	"golang.org/x/time/rate"
)

// RateLimit is a per-IP token bucket using sync.Map. In-process only — fine for
// a single VPS instance. A goroutine reaps idle entries every 10 minutes to keep
// the map bounded under attack.
type RateLimit struct {
	visitors sync.Map // map[string]*visitor
	rps      rate.Limit
	burst    int
}

type visitor struct {
	limiter  *rate.Limiter
	lastSeen time.Time
	mu       sync.Mutex
}

// NewRateLimit returns a middleware that allows `burst` requests up-front and
// refills at `rps` per second. Spec calls for ~5 burst, 0.5/sec refill.
func NewRateLimit(rps float64, burst int) *RateLimit {
	rl := &RateLimit{rps: rate.Limit(rps), burst: burst}
	go rl.reaper()
	return rl
}

func (rl *RateLimit) Handler() fiber.Handler {
	return func(c *fiber.Ctx) error {
		ip := c.IP()
		v := rl.getOrCreate(ip)
		v.mu.Lock()
		v.lastSeen = time.Now()
		allowed := v.limiter.Allow()
		v.mu.Unlock()
		if !allowed {
			return httputil.Err(c, fiber.StatusTooManyRequests, httputil.ErrRateLimited, "rate limit exceeded")
		}
		return c.Next()
	}
}

func (rl *RateLimit) getOrCreate(ip string) *visitor {
	if v, ok := rl.visitors.Load(ip); ok {
		return v.(*visitor)
	}
	nv := &visitor{
		limiter:  rate.NewLimiter(rl.rps, rl.burst),
		lastSeen: time.Now(),
	}
	actual, _ := rl.visitors.LoadOrStore(ip, nv)
	return actual.(*visitor)
}

// reaper removes visitors that haven't hit us in 10 minutes.
func (rl *RateLimit) reaper() {
	t := time.NewTicker(10 * time.Minute)
	defer t.Stop()
	for range t.C {
		cutoff := time.Now().Add(-10 * time.Minute)
		rl.visitors.Range(func(k, v any) bool {
			vis := v.(*visitor)
			vis.mu.Lock()
			stale := vis.lastSeen.Before(cutoff)
			vis.mu.Unlock()
			if stale {
				rl.visitors.Delete(k)
			}
			return true
		})
	}
}
