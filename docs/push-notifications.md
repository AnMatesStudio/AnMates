# Push notifications (self-hosted)

AnMates delivers notifications without Firebase Cloud Messaging or any vendor account. Everything runs on our own
servers; the only outside hop is the one no website can avoid: the browser's own push service. For example, Chrome
uses Google's, Firefox uses Mozilla's and Safari uses Apple's. That hop only carries bytes encrypted for the
recipient's browser (RFC 8291), so those services cannot read them.

## How it works

```
DB trigger (match / message / booking / rating)
  → INSERT notifications row            (019_notifications_prefs.sql)
  → pg_notify('anm_notification', id)   (022_push.sql)
  → every API replica LISTENs           (services/push_dispatcher.go)
      ├─ realtime: sends it to that user's open /ws/notify sockets on this replica  (ws/userhub.go)
      └─ Web Push: the replica that wins ClaimPush (notifications.pushed_at) encrypts + signs with our
         VAPID key and POSTs to each of the user's subscription endpoints       (services/webpush.go)
            404/410 → subscription deleted
```

- **App open, or open in a background tab.** The `/ws/notify` WebSocket delivers instantly. The app updates the badge
  and list, and shows a system notification when the tab is hidden. This works with no keys at all.
- **App closed.** Web Push reaches the service worker `web/push/sw.js` (scope `/push/`, separate from Flutter's own
  worker), which shows the notification. This needs VAPID keys (below) and the user must switch it on (Me → "Thông báo
  đẩy", or the Inbox card).
- **One push per notification.** Replicas race on `UPDATE notifications SET pushed_at = now() WHERE id = $1 AND
  pushed_at IS NULL`, and only the winner sends.
- **SSRF guard.** In production we only POST to vendor push hosts over https (`services.AllowedPushEndpoint`).
  `DEV_MODE` lifts this so the e2e suite can use a fake push service.

## Enabling Web Push (one-time)

1. Generate a key pair once. Never rotate it casually: every existing subscription is tied to the public key.
   ```bash
   node -e "const {generateKeyPairSync}=require('crypto');const {privateKey}=generateKeyPairSync('ec',{namedCurve:'prime256v1'});const j=privateKey.export({format:'jwk'});console.log('VAPID_PUBLIC_KEY='+Buffer.concat([Buffer.from([4]),Buffer.from(j.x,'base64url'),Buffer.from(j.y,'base64url')]).toString('base64url'));console.log('VAPID_PRIVATE_KEY='+j.d)"
   ```
2. Local: append both lines (and optionally `VAPID_SUBJECT=mailto:…`) to `.env`, then run `docker compose up -d --build api`.
3. Production (k8s, the API reads the whole `anmates-api` secret through `envFrom`). Run this from a machine with
   cluster access, such as the `pc-runner` host:
   ```bash
   kubectl -n anmates patch secret anmates-api --type merge -p \
     '{"stringData":{"VAPID_PUBLIC_KEY":"<public>","VAPID_PRIVATE_KEY":"<private>","VAPID_SUBJECT":"mailto:anmates.studio@gmail.com"}}'
   kubectl -n anmates rollout restart deploy/anmates-api
   ```
   Check: `GET /api/v1/push/vapid-public-key` returns 200 with the key, and the API log says `web push enabled`.
   Without keys the API logs `web push disabled` and the endpoint returns 503; realtime keeps working.

## Platform limits (same as any web push, FCM included)

- **iPhone/iPad:** push only works after the user adds the app to the Home Screen from Safari (iOS 16.4+) and opens
  it from there. The Me screen explains this when it detects Safari on iOS outside the installed app.
- The user must allow notifications. We ask only when they tap "Bật" (Inbox card or the Me switch), never on first load.
- Native apps (if we ever ship them) would need FCM (Android) and APNs (iOS). This design does not cover that.

## Tests

- `anmates-api/e2e/e2e_push_test.go`:
  - E2E-27 checks realtime over `/ws/notify`.
  - E2E-28 checks Web Push through a fake push service, **decrypting** the payload with the browser-side keys.
  - E2E-29 checks subscription validation, dedupe, unsubscribe, and removal of dead (410) endpoints.
  - Running it needs `--network-alias e2e` on the test container. See the header of `e2e_test.go`.
- `services/webpush_test.go` covers the endpoint allow-list, including look-alike hosts.
