# QA Report — Full-feature exploration & bug sweep

**Date:** 2026-06-08
**Tester:** main-assistant (QA role)
**Build under test:** running `docker compose` stack (api healthy :8080, ai_venue_search healthy :8090, db healthy :5432, **web `unhealthy` :54180**)
**Method:** live API probing (dev-login both users) across every route in `main.go`, + targeted code review of root causes. Negative/auth paths emphasized (prior suites only cover happy paths with valid tokens).
**Verdict:** ❌ **1 CRITICAL (auth gate non-functional) + 3 minor/config bugs.** Happy-path business logic mostly sound.

---

## 🔴 BUG-1 (CRITICAL) — JWT auth middleware does not block unauthenticated requests

**Severity:** critical (security / correctness)
**Where:** `internal/httputil/response.go` `Err()` + `middleware/auth.go` `JWT` / `ValidateBearer` (+ `handlers/chat.go` `WSAuth`)

### Symptom (reproduced, deterministic ×3)
```
GET  /api/v1/profile   (no token) → 404 {"success":false,...,"user not found"}   ← handler RAN
GET  /api/v1/wishlist  (no token) → HTTP 401 + body {"success":true,"data":[]}   ← status & body disagree
GET  /api/v1/matches   (no token) → HTTP 401 + body {"success":true,"data":[]}
PUT  /api/v1/me/location (no token) → 500 "save failed"                          ← handler RAN
POST /api/v1/wishlist  (no token, bad cat) → 400 "invalid food_category"         ← handler RAN
```
A 401-status-with-success-body response is impossible from one clean handler chain — it proves the
handler executed *after* the middleware already wrote its 401.

### Root cause
`httputil.Err()` does `return c.Status(s).JSON(...)`. Fiber's `c.JSON()` returns **`nil`** on success,
so `Err()` returns `nil`. The middleware then does:
```go
// middleware/auth.go
if err := ValidateBearer(c, secret); err != nil { return err } // err is nil → falls through
return c.Next()                                                 // handler runs with uuid.Nil
```
`ValidateBearer` writes the 401 body but returns `nil`, so `JWT` (and `WSAuth`) think auth **succeeded**
and call `c.Next()`. Handlers run with `middleware.UserID(c) == uuid.Nil`. The handler's own
`OK()`/`Err()` then overwrites the body (status stays at the already-set 401, unless the handler sets its own).

### Why it hasn't caused a visible breach yet (blast radius)
- `uuid.Nil` owns no rows, so reads return empty and most writes hit FK constraints (→ 500, not data corruption).
- WS + chat history + booking are *incidentally* protected by a secondary `IsMember(matchID, uuid.Nil)`
  check (nil is never a member → 404).
- **But the auth gate itself provides zero protection.** Any current/future handler that doesn't
  re-check ownership against the caller, or that treats `uuid.Nil` as valid, leaks. Status codes are
  already wrong app-wide (401 with success body, 404/500 instead of clean 401).

### Suggested fix
Make auth failure propagate a real error. Two clean options:
1. `ValidateBearer` returns a **non-nil** error on failure (don't write the body there); let the
   `JWT`/`WSAuth` wrapper render it. Simplest and most correct.
2. Change the two call sites to not rely on `Err`'s return: have `ValidateBearer` return `(bool ok, err)`
   or a sentinel.
Do **not** just change `Err()` to return non-nil globally — handlers that `return httputil.Err(...)`
correctly rely on "response already written" semantics; only the `if err := ValidateBearer(...)` branch is wrong.

### Regression guard to add
A negative-auth test for every protected route (no token + garbage token → expect clean 401, no handler side effects). None exists today — `e2e_full_flow.js` always sends valid tokens, which is why 31/31 stayed green over this bug.

---

## 🟠 BUG-2 (minor, data integrity) — `PUT /me/location` stores Null Island (0,0) on missing fields

**Severity:** minor→major (corrupts AI Concierge distance; related to ISSUE-9 "0m")
**Where:** `handlers/location.go` `locationUpdateReq`

```
PUT /api/v1/me/location  {}                      → 200 {"ok":true}, DB row lat=0 lng=0
PUT /api/v1/me/location  {"lat":10}              → 200, lng silently 0
```
`Lat`/`Lng` are non-pointer `float64`, so a missing value defaults to `0`, and the range check
(`lat<-90 || lat>90 ...`) accepts `0`. A bad/empty body overwrites a user's real location with (0,0),
which is exactly the input that produces bogus "0m"/wrong-distance venue cards.

**Note:** the booking handler already does this correctly with `*float64` (`proposeBookingReq`).
**Fix:** make `Lat`/`Lng` `*float64` and reject when nil (mirror `proposeBookingReq`).

---

## 🟠 BUG-3 (config) — web container stuck "unhealthy" (stale image; healthcheck uses `localhost`)

**Severity:** minor (ops/observability; `depends_on` of nothing today, but masks real failures)
**Where:** `anmates_flutter/Dockerfile` HEALTHCHECK vs running image

The **running** container's healthcheck is `wget -qO- http://localhost/ ...` (FailingStreak 104).
busybox wget resolves `localhost`→IPv6 `::1` first; nginx listens IPv4 only → connection refused →
permanently unhealthy. The **current Dockerfile was already fixed** to `http://127.0.0.1/` (lines 23-26,
same class as R-006 B2), but **the image in use predates the fix** (`localhost` still baked in). Running
the fixed command manually inside the container returns exit 0.
**Fix:** `docker compose build web` (or `up --build web`) to pick up the corrected HEALTHCHECK. The app
itself serves fine (curl :54180 → 200); only the health probe is broken.

---

## 🟡 BUG-4 (latent config) — malformed `API_BASE_URL` default in docker-compose

**Severity:** low (latent; masked by `.env` today)
**Where:** `docker-compose.yml` line 108

```yaml
API_BASE_URL: ${API_BASE_URL:-http://127.0.0.1/:8080}
```
The default `http://127.0.0.1/:8080` has a stray `/` before the port — it's not a valid base URL. Only
masked because `.env` sets `API_BASE_URL=http://localhost:8080`. If `.env` is removed/CI changes, the web
build bakes in a broken API URL.
**Secondary observation:** `.env` points the web build at `http://localhost:8080` while the app is served
at `http://127.0.0.1:54180` and project rule R-001 standardizes on `127.0.0.1` (Firebase reCAPTCHA). API
calls still work only because CORS is `Access-Control-Allow-Origin: *`. Recommend standardizing on
`http://127.0.0.1:8080` for consistency.
**Fix:** `${API_BASE_URL:-http://127.0.0.1:8080}`.

---

## ✅ Verified WORKING (no bug)

| Area | Result |
|------|--------|
| dev-login (both users), `/profile` GET | 200, correct payload |
| `/wishlist`, `/matches`, `/conversations` (authed) | 200 |
| Wishlist categories — Flutter `_categories` codes ⇄ backend `AllowedCategories` | **exact match** (lau/bbq/pho/bun/com/cafe/trang_mieng/other) |
| `PUT /me/location` valid coords | 200; out-of-range lat=99 → 400 |
| Swipe like + undo | 200 |
| Booking: propose field contract (`restaurant_name`) Flutter ⇄ Go | aligned |
| Booking confirm-own-proposal | 409 "đợi mate xác nhận giúm nha" ✓ |
| Booking confirm by partner | 200 confirmed ✓ |
| Booking read by outsider (3rd user) | 404 MATCH_NOT_FOUND ✓ (membership authz works) |
| CORS preflight OPTIONS | 204 ✓ |

---

## Not covered this session
- **AI Concierge live fire** — needs LM Studio on host; happy path already covered by prior reports
  (`e2e_full_flow.js` 31/31, `qa_full_flow.js` 5/5, R-006). Not re-run here.
- **Flutter UI visual pass** — API/code level only this session (web container reachable but no browser drive).
- **Real Firebase OTP** (web 127.0.0.1 flow) — unchanged since R-001.

## Recommended priority
1. **BUG-1** before any further endpoints ship — the auth gate must actually gate. Add negative-auth e2e.
2. BUG-2 (location validation) — quick `*float64` fix, removes a Concierge-distance footgun.
3. BUG-3 rebuild web image; BUG-4 fix compose default.
