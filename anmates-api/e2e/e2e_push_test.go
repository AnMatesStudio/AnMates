package e2e

// Round 5: self-hosted notification delivery.
//   E2E-27  our own WebSocket (/ws/notify) pushes each new notification in real time.
//   E2E-28  standard Web Push (RFC 8030/8291/8292) with our VAPID keys: the API POSTs an encrypted
//           payload to the subscription endpoint. The endpoint here is a fake push service inside
//           this test process (reachable from the api container as http://e2e:9099 — run the test
//           container with --network-alias e2e), and the test DECRYPTS the payload with the
//           browser-side keys it generated, proving the end-to-end encryption, not just headers.
//   E2E-29  dead subscriptions (410) are removed; bad input rejected; one push per notification.

import (
	"context"
	"crypto/aes"
	"crypto/cipher"
	"crypto/ecdh"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/fasthttp/websocket"
	"golang.org/x/crypto/hkdf"
)

// ── fake browser push service ────────────────────────────────────────────────

type pushHit struct {
	path    string
	headers http.Header
	body    []byte
}

type fakePushService struct {
	mu     sync.Mutex
	hits   []pushHit
	status map[string]int // path → status to answer (default 201)
}

var (
	pushSvcOnce sync.Once
	pushSvc     = &fakePushService{status: map[string]int{}}
)

func startFakePushService(t *testing.T) *fakePushService {
	t.Helper()
	pushSvcOnce.Do(func() {
		ln, err := net.Listen("tcp", ":9099")
		if err != nil {
			t.Fatalf("fake push service: %v", err)
		}
		go http.Serve(ln, http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			b, _ := io.ReadAll(r.Body)
			pushSvc.mu.Lock()
			pushSvc.hits = append(pushSvc.hits, pushHit{r.URL.Path, r.Header.Clone(), b})
			code := pushSvc.status[r.URL.Path]
			pushSvc.mu.Unlock()
			if code == 0 {
				code = http.StatusCreated
			}
			w.WriteHeader(code)
		}))
	})
	return pushSvc
}

func (f *fakePushService) waitFor(t *testing.T, path string, n int, within time.Duration) []pushHit {
	t.Helper()
	deadline := time.Now().Add(within)
	for time.Now().Before(deadline) {
		f.mu.Lock()
		var got []pushHit
		for _, h := range f.hits {
			if h.path == path {
				got = append(got, h)
			}
		}
		f.mu.Unlock()
		if len(got) >= n {
			return got
		}
		time.Sleep(100 * time.Millisecond)
	}
	return nil
}

// browserKeys is what a browser's PushManager holds for one subscription.
type browserKeys struct {
	priv *ecdh.PrivateKey
	auth []byte
}

func newBrowserKeys(t *testing.T) browserKeys {
	t.Helper()
	k, err := ecdh.P256().GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	a := make([]byte, 16)
	rand.Read(a)
	return browserKeys{k, a}
}

func b64u(b []byte) string { return base64.RawURLEncoding.EncodeToString(b) }

func (k browserKeys) subscription(endpoint string) map[string]any {
	return map[string]any{"endpoint": endpoint, "keys": map[string]any{
		"p256dh": b64u(k.priv.PublicKey().Bytes()), "auth": b64u(k.auth),
	}}
}

// decrypt implements the browser side of RFC 8291 (aes128gcm, single record).
func (k browserKeys) decrypt(t *testing.T, body []byte) []byte {
	t.Helper()
	if len(body) < 21 {
		t.Fatalf("push body too short: %d", len(body))
	}
	salt, rs, idlen := body[:16], binary.BigEndian.Uint32(body[16:20]), int(body[20])
	if rs < 18 || len(body) < 21+idlen {
		t.Fatalf("bad aes128gcm header")
	}
	asPubRaw, ct := body[21:21+idlen], body[21+idlen:]
	asPub, err := ecdh.P256().NewPublicKey(asPubRaw)
	if err != nil {
		t.Fatalf("server key: %v", err)
	}
	shared, err := k.priv.ECDH(asPub)
	if err != nil {
		t.Fatal(err)
	}
	expand := func(prk, info []byte, n int) []byte {
		out := make([]byte, n)
		io.ReadFull(hkdf.Expand(sha256.New, prk, info), out)
		return out
	}
	keyInfo := append(append([]byte("WebPush: info\x00"), k.priv.PublicKey().Bytes()...), asPubRaw...)
	ikm := expand(hkdf.Extract(sha256.New, shared, k.auth), keyInfo, 32)
	prk := hkdf.Extract(sha256.New, ikm, salt)
	cek := expand(prk, []byte("Content-Encoding: aes128gcm\x00"), 16)
	nonce := expand(prk, []byte("Content-Encoding: nonce\x00"), 12)
	block, _ := aes.NewCipher(cek)
	gcm, _ := cipher.NewGCM(block)
	pt, err := gcm.Open(nil, nonce, ct, nil)
	if err != nil {
		t.Fatalf("payload does not decrypt with the subscription keys: %v", err)
	}
	pt = []byte(strings.TrimRight(string(pt), "\x00"))
	if len(pt) == 0 || pt[len(pt)-1] != 0x02 {
		t.Fatalf("missing last-record delimiter")
	}
	return pt[:len(pt)-1]
}

// ── E2E-27: realtime over our own WebSocket ──────────────────────────────────

func wsURL(token string) string {
	return strings.Replace(baseURL(), "http", "ws", 1) + "/ws/notify?access_token=" + token
}

func TestE2E27_RealtimeWebSocket(t *testing.T) {
	a, b := newUser(t, "E2E WS A"), newUser(t, "E2E WS B")
	if _, resp, err := websocket.DefaultDialer.Dial(wsURL("not-a-token"), nil); err == nil || resp == nil || resp.StatusCode != 401 {
		t.Fatalf("bad token must be refused with 401 (err=%v)", err)
	}
	conn, _, err := websocket.DefaultDialer.Dial(wsURL(a.token), nil)
	if err != nil {
		t.Fatalf("dial /ws/notify: %v", err)
	}
	defer conn.Close()
	time.Sleep(300 * time.Millisecond)

	for _, u := range []user{a, b} {
		for _, f := range [][2]string{{"Phở", "pho"}, {"Cơm", "com"}} {
			must(t, http.MethodPost, "/api/v1/wishlist", u.token, map[string]any{"food_name": f[0], "food_category": f[1]}, 201, 409)
		}
	}
	must(t, http.MethodPost, "/api/v1/swipes", a.token, map[string]any{"target_id": b.id, "liked": true}, 200)
	start := time.Now()
	must(t, http.MethodPost, "/api/v1/swipes", b.token, map[string]any{"target_id": a.id, "liked": true}, 200)

	conn.SetReadDeadline(time.Now().Add(5 * time.Second))
	_, msg, err := conn.ReadMessage()
	if err != nil {
		t.Fatalf("no realtime message within 5 s: %v", err)
	}
	var env struct {
		Type    string `json:"type"`
		Payload struct {
			Kind      string `json:"kind"`
			MatchID   string `json:"match_id"`
			ActorName string `json:"actor_name"`
			Title     string `json:"title"`
			Body      string `json:"body"`
		} `json:"payload"`
	}
	if err := json.Unmarshal(msg, &env); err != nil {
		t.Fatalf("bad message %s: %v", msg, err)
	}
	if env.Type != "notification" || env.Payload.Kind != "match" || env.Payload.ActorName != b.name || env.Payload.Body == "" {
		t.Fatalf("realtime message = %s", msg)
	}
	t.Logf("realtime delivery after %v", time.Since(start))
}

// ── E2E-28: Web Push, decrypted end to end ───────────────────────────────────

func TestE2E28_WebPushDelivered(t *testing.T) {
	svc := startFakePushService(t)
	var vk struct {
		Key string `json:"key"`
	}
	decode(t, must(t, http.MethodGet, "/api/v1/push/vapid-public-key", "", nil, 200), &vk)
	if raw, err := base64.RawURLEncoding.DecodeString(vk.Key); err != nil || len(raw) != 65 {
		t.Fatalf("VAPID public key must be a base64url P-256 point, got %q", vk.Key)
	}

	a, b := newUser(t, "E2E Push A"), newUser(t, "E2E Push B")
	keys := newBrowserKeys(t)
	path := fmt.Sprintf("/push/%d", time.Now().UnixNano())
	must(t, http.MethodPost, "/api/v1/push/subscribe", a.token, keys.subscription("http://e2e:9099"+path), 200, 201)

	for _, u := range []user{a, b} {
		for _, f := range [][2]string{{"Phở", "pho"}, {"Cơm", "com"}} {
			must(t, http.MethodPost, "/api/v1/wishlist", u.token, map[string]any{"food_name": f[0], "food_category": f[1]}, 201, 409)
		}
	}
	must(t, http.MethodPost, "/api/v1/swipes", a.token, map[string]any{"target_id": b.id, "liked": true}, 200)
	must(t, http.MethodPost, "/api/v1/swipes", b.token, map[string]any{"target_id": a.id, "liked": true}, 200)

	hits := svc.waitFor(t, path, 1, 8*time.Second)
	if hits == nil {
		t.Fatalf("no Web Push request reached the subscription endpoint within 8 s")
	}
	h := hits[0]
	if h.headers.Get("Content-Encoding") != "aes128gcm" || h.headers.Get("TTL") == "" {
		t.Fatalf("headers: Content-Encoding=%q TTL=%q", h.headers.Get("Content-Encoding"), h.headers.Get("TTL"))
	}
	if auth := h.headers.Get("Authorization"); !strings.HasPrefix(auth, "vapid t=") || !strings.Contains(auth, "k="+vk.Key) {
		t.Fatalf("Authorization is not VAPID with our key: %q", auth)
	}
	var p struct {
		Kind      string `json:"kind"`
		ActorName string `json:"actor_name"`
		Title     string `json:"title"`
		Body      string `json:"body"`
		URL       string `json:"url"`
	}
	plain := keys.decrypt(t, h.body)
	if err := json.Unmarshal(plain, &p); err != nil {
		t.Fatalf("decrypted payload is not JSON: %s", plain)
	}
	if p.Kind != "match" || p.ActorName != b.name || p.Title == "" || p.Body == "" {
		t.Fatalf("decrypted payload = %s", plain)
	}
	// Exactly one push per notification, even with several API replicas listening.
	time.Sleep(1500 * time.Millisecond)
	if n := len(svc.waitFor(t, path, 1, time.Second)); n != 1 {
		t.Fatalf("got %d pushes for one notification, want exactly 1", n)
	}
}

// ── E2E-29: validation, unsubscribe, dead endpoints ──────────────────────────

func TestE2E29_PushSubscriptionLifecycle(t *testing.T) {
	svc := startFakePushService(t)
	pool := db(t)
	a, b := newUser(t, "E2E Sub A"), newUser(t, "E2E Sub B")
	keys := newBrowserKeys(t)

	must(t, http.MethodPost, "/api/v1/push/subscribe", "", keys.subscription("http://e2e:9099/x"), 401)
	for _, bad := range []map[string]any{
		{"endpoint": "", "keys": map[string]any{"p256dh": "x", "auth": "y"}},
		{"endpoint": "http://e2e:9099/x"},
		{"endpoint": "http://e2e:9099/x", "keys": map[string]any{"p256dh": "not-base64!!", "auth": b64u(keys.auth)}},
	} {
		must(t, http.MethodPost, "/api/v1/push/subscribe", a.token, bad, 400)
	}

	dead := fmt.Sprintf("/push/dead-%d", time.Now().UnixNano())
	svc.mu.Lock()
	svc.status[dead] = http.StatusGone
	svc.mu.Unlock()
	must(t, http.MethodPost, "/api/v1/push/subscribe", a.token, keys.subscription("http://e2e:9099"+dead), 200, 201)
	count := func(ep string) int {
		var n int
		pool.QueryRow(context.Background(), `SELECT count(*) FROM push_subscriptions WHERE endpoint=$1`, ep).Scan(&n)
		return n
	}
	if count("http://e2e:9099"+dead) != 1 {
		t.Fatalf("subscription not stored")
	}
	// Re-subscribing the same endpoint must not duplicate it.
	must(t, http.MethodPost, "/api/v1/push/subscribe", a.token, keys.subscription("http://e2e:9099"+dead), 200, 201)
	if count("http://e2e:9099"+dead) != 1 {
		t.Fatalf("same endpoint stored twice")
	}

	// A report notification isn't a kind we emit — use a match to trigger a push to the dead endpoint.
	for _, u := range []user{a, b} {
		for _, f := range [][2]string{{"Phở", "pho"}, {"Cơm", "com"}} {
			must(t, http.MethodPost, "/api/v1/wishlist", u.token, map[string]any{"food_name": f[0], "food_category": f[1]}, 201, 409)
		}
	}
	must(t, http.MethodPost, "/api/v1/swipes", a.token, map[string]any{"target_id": b.id, "liked": true}, 200)
	must(t, http.MethodPost, "/api/v1/swipes", b.token, map[string]any{"target_id": a.id, "liked": true}, 200)
	if svc.waitFor(t, dead, 1, 8*time.Second) == nil {
		t.Fatalf("no push attempt to the dead endpoint")
	}
	deadline := time.Now().Add(3 * time.Second)
	for count("http://e2e:9099"+dead) != 0 && time.Now().Before(deadline) {
		time.Sleep(100 * time.Millisecond)
	}
	if count("http://e2e:9099"+dead) != 0 {
		t.Fatalf("410 Gone subscription was not removed")
	}

	live := fmt.Sprintf("http://e2e:9099/push/live-%d", time.Now().UnixNano())
	must(t, http.MethodPost, "/api/v1/push/subscribe", b.token, keys.subscription(live), 200, 201)
	must(t, http.MethodPost, "/api/v1/push/unsubscribe", b.token, map[string]any{"endpoint": live}, 200)
	if count(live) != 0 {
		t.Fatalf("unsubscribe left the row")
	}
}
