package services

import (
	"context"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"

	webpush "github.com/SherClockHolmes/webpush-go"
)

// WebPushSender sends RFC 8291-encrypted payloads signed with our VAPID keys (RFC 8292). Self-hosted: no Firebase or
// vendor account — the browser's push service only relays the encrypted bytes.
type WebPushSender struct {
	publicKey, privateKey, subject string
	allowAnyHost                   bool // DEV_MODE: tests use a fake push service on the docker network
	client                         *http.Client
}

func NewWebPushSender(publicKey, privateKey, subject string, allowAnyHost bool) *WebPushSender {
	return &WebPushSender{
		publicKey:    publicKey,
		privateKey:   privateKey,
		subject:      subject,
		allowAnyHost: allowAnyHost,
		client:       &http.Client{Timeout: 10 * time.Second},
	}
}

func (w *WebPushSender) PublicKey() string { return w.publicKey }

// Send returns the push service's HTTP status (201 = accepted; 404/410 = subscription is dead).
func (w *WebPushSender) Send(ctx context.Context, s PushSubscription, payload []byte) (int, error) {
	if !AllowedPushEndpoint(s.Endpoint, w.allowAnyHost) {
		return 0, fmt.Errorf("webpush: endpoint not allowed: %q", s.Endpoint)
	}
	resp, err := webpush.SendNotificationWithContext(ctx, payload, &webpush.Subscription{
		Endpoint: s.Endpoint,
		Keys:     webpush.Keys{Auth: s.Auth, P256dh: s.P256dh},
	}, &webpush.Options{
		Subscriber:      w.subject,
		VAPIDPublicKey:  w.publicKey,
		VAPIDPrivateKey: w.privateKey,
		TTL:             86400,
		Urgency:         webpush.UrgencyHigh,
		HTTPClient:      w.client,
	})
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()
	return resp.StatusCode, nil
}

// AllowedPushEndpoint blocks SSRF: users choose the endpoint URL and our server POSTs to it. In production only the
// browser vendors' push services over https are allowed; allowAnyHost (DEV_MODE) lifts this for local tests.
func AllowedPushEndpoint(raw string, allowAnyHost bool) bool {
	u, err := url.Parse(raw)
	if err != nil || u.Host == "" {
		return false
	}
	if allowAnyHost {
		return u.Scheme == "http" || u.Scheme == "https"
	}
	if u.Scheme != "https" {
		return false
	}
	host := strings.ToLower(u.Hostname())
	for _, h := range []string{
		"fcm.googleapis.com",
		"jmt17.google.com",
		"push.services.mozilla.com",
		"push.apple.com",
		"notify.windows.com",
	} {
		if host == h || strings.HasSuffix(host, "."+h) {
			return true
		}
	}
	return false
}
