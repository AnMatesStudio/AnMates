# 2026-09-02 — Login flow → admin/admin password login; remove Firebase phone OTP

## TL;DR
User hit `ClientException: Failed to fetch, uri=https:///api/v1/auth/email/request-otp`
on the "Đăng nhập bằng email" screen (deployed k8s pod). Asked to (1) find root
cause, (2) change the login flow to a simple **username: admin / password: admin**,
(3) remove Firebase phone-number OTP entirely.

## Root cause
`https:///api/v1/...` has an **empty host** between `https://` and the path. Traced to
`.github/workflows/ci-build-push.yml` (+ `ci.flutter-web.yml`): both unconditionally
baked `--dart-define=API_BASE_URL=https://${{ vars.ANMATES_DOMAIN }}` into the
Flutter web build. The repo variable `ANMATES_DOMAIN` is **not set yet** — domain
provisioning is tracked as PI-17 and still pending (see current-task.md 2026-09-01
status) — so the interpolation produced the literal `API_BASE_URL=https://` with no
host, which Dart's `Uri.parse('$_baseUrl/api/v1/...')` turns into a malformed
same-scheme-no-host URI. Every `http.post` call in `auth_service.dart` hit this, not
just the email-OTP one.

Confirmed this bake was actually unnecessary: `anmates_flutter/nginx.conf` already
reverse-proxies `/api/` and `/ws/` to the `anmates-api` Service **same-origin**
inside the pod, so an absolute domain URL was never required — a relative path
works identically once a domain exists AND while it doesn't.

## Fix
1. **CI (root cause)** — `ci-build-push.yml` + `ci.flutter-web.yml`: resolve
   `API_BASE_URL` in a separate step; when `ANMATES_DOMAIN` is empty, pass an
   **empty** `API_BASE_URL` (→ Flutter calls relative paths, still same-origin-correct)
   instead of the bare `https://` scheme. When the var IS set later (PI-17 done),
   behavior is unchanged (`https://<domain>`).
2. **Login flow → admin/admin** — `AuthView` (`lib/views/auth/auth_view.dart`) already
   existed fully built (email+password login/register hitting the existing
   `/api/v1/auth/login` + `/api/v1/auth/register` endpoints) but was **never wired
   in** — the app's real entry was `PhoneInputView`. Rewired
   `onboarding_view.dart`'s `_navigateAway` to push `AuthView` instead.
   `AuthView`'s login mode has no email-format/length validation client-side (only
   register does), so `Login` handler (`handlers/auth.go`) also does no format
   check — it just looks up `users.email = $1` — so a non-email username like
   `admin` logs in fine as long as the row exists.
   New migration `anmates-api/db/migrations/013_seed_admin.sql` seeds
   `email='admin'`, bcrypt hash of `admin` (cost 10, generated + verified via
   `bcrypt.CompareHashAndPassword` locally), `onboarding_done=true` (skips onboarding
   screens after login).
3. **Removed Firebase phone OTP** — deleted `phone_input_view.dart`, `otp_view.dart`
   (both used `FirebaseAuth.instance.{signInWithPhoneNumber,verifyPhoneNumber,
   signInWithCredential}` + web `RecaptchaVerifier`), and `auth_error_messages.dart`
   (only consumer of `friendlyPhoneAuthError`, now orphaned). Removed the now-unused
   `firebase_auth_platform_interface` pubspec dependency (only needed for
   `RecaptchaVerifier`/`FirebaseAuthPlatform`) — kept `firebase_auth` itself, since
   `storage_service.dart` still uses `FirebaseAuth.instance.signInAnonymously()` for
   Firebase Storage uploads (unrelated to phone OTP). Removed the
   `#recaptcha-container` div from `web/index.html`.
4. **Removed now-orphaned email OTP** — `email_input_view.dart` + `email_otp_view.dart`
   were only reachable via `PhoneInputView`'s "Đăng nhập bằng email" button (the
   screen from the bug screenshot); with that entry gone they had no route in, so
   deleted them too rather than leave dead screens. Removed the matching
   `AuthService.requestEmailOtp` / `.verifyEmailOtp` / `.phoneVerify` methods
   (`phoneVerify` was Firebase-specific, also orphaned). Backend
   `RequestEmailOTP`/`VerifyEmailOTP`/`PhoneVerify` handlers + routes were left
   alone (unused now, but not broken — smallest diff; can be pruned later if
   confirmed permanently unwanted).
5. Updated `integration_test/app_test.dart` (only place still referencing
   `PhoneInputView`) to drive the new `AuthView` admin/admin flow instead of the old
   phone + dev-mode-skip-OTP flow.

## Verified (static — no live pod)
- `flutter analyze`: **0 errors** (same 9 pre-existing `info` lints as before, in
  untouched files).
- `flutter test`: **23/23 passed**.
- `cd anmates-api && GO111MODULE=on go build ./... && go vet ./...`: clean.
- `go test ./...`: `handlers`/`middleware`/`services` pass; `smoke` package fails
  only on `dial tcp [::1]:8080: connection refused` (needs a live server —
  pre-existing, unrelated to this change).
- Generated the admin bcrypt hash via `htpasswd -bnBC 10 "" admin`, verified it
  matches `"admin"` with Go's `bcrypt.CompareHashAndPassword` before embedding it
  in the migration.

## Files changed
- `.github/workflows/ci-build-push.yml`, `.github/workflows/ci.flutter-web.yml`
- `anmates-api/db/migrations/013_seed_admin.sql` (new)
- `anmates_flutter/lib/views/onboarding/onboarding_view.dart`
- `anmates_flutter/lib/services/auth_service.dart`
- `anmates_flutter/pubspec.yaml`
- `anmates_flutter/web/index.html`
- `anmates_flutter/integration_test/app_test.dart`
- Deleted: `lib/views/auth/{phone_input_view,otp_view,email_input_view,email_otp_view,auth_error_messages}.dart`

## Open follow-ups / NOT done
- **Not live-verified** — needs an actual `helm upgrade` (which reruns the DB
  migration + rebuilds/redeploys the web image via CI) to confirm end-to-end.
  `ANMATES_DOMAIN` is still unset (PI-17), so the pod will keep serving via
  relative same-origin URLs (now correctly, no longer broken) until a domain
  exists.
- Backend `PhoneVerify`/`RequestEmailOTP`/`VerifyEmailOTP` handlers + Firebase
  phone-verify plumbing (`VerifyFirebaseToken`) still exist server-side, unused —
  left in place to keep the diff minimal; ask user if these + the `firebase_uid`
  column / `002_phone_auth.sql` should be fully retired later.
- `AuthView` still shows Facebook/Apple/Google social buttons (stubbed,
  "sắp ra mắt" toast) — untouched, out of scope for this change.
- No password-reset flow exists for the `admin` account (by design — it's a fixed
  seeded credential, not a real user flow).

## Key facts for next session
- `ANMATES_DOMAIN` GH repo variable = the PI-17 blocker; once set, CI naturally
  switches back to an absolute `https://<domain>` `API_BASE_URL` with no code
  change needed.
- Admin login: **email `admin`, password `admin`** (seeded in
  `013_seed_admin.sql`, `onboarding_done=true`).

## Addendum (same session) — fixed a WebSocket regression in the CI fix itself

While answering a follow-up question about reusing `ANMATES_DOMAIN` for a future
`api.anmates.site` DNS record, re-traced how `API_BASE_URL=""` (the CI fallback
above) flows through the Dart code and found it breaks **chat WebSocket**, not just
a theoretical edge case: `ApiClient.wsUrl()` derives `wss://`/`ws://` from
`_baseUrl` via `.replaceFirst('https://', 'wss://')` — with an empty base this
produces a bare relative path (`/ws/chat/<id>`), and browsers reject
`new WebSocket()` unless the resolved scheme is exactly `ws`/`wss` (unlike `fetch`,
which happily resolves relative URLs against the document origin).

Fix: `auth_service.dart`'s `apiBaseUrl` is now a **getter**, not a `const` — when
the compiled-in `API_BASE_URL` is empty, it returns `Uri.base.origin` on web (the
page's own absolute origin, always has a real scheme). Both HTTP calls and
`wsUrl()` derive from this, so both work correctly with no baked domain, and will
keep working unchanged once `ANMATES_DOMAIN` (PI-17) is set. `api_client.dart` had
an independent duplicate `const _baseUrl = String.fromEnvironment(...)` — replaced
with `String get _baseUrl => apiBaseUrl;` importing the one in `auth_service.dart`,
removing the duplication.

`main.dart`'s `apiBaseUrl.contains('localhost')` check still works unchanged (was
already `static final`, not `const`, so the getter is a drop-in replacement).

Also answered: reusing `ANMATES_DOMAIN` for a **separate** API subdomain
(`api.anmates.site`, bypassing the web pod's nginx same-origin proxy) is possible
but is a different architecture than the PI-16 single-hostname decision — would
need a distinct var (not overload `ANMATES_DOMAIN`), though CORS needs no change
(`CORS_ORIGINS` already defaults to `*`, no cookies/credentials in use).

Re-verified: `flutter analyze` 0 errors, `flutter test` 23/23.

## Addendum 2 — ANMATES_DOMAIN removed + CI/CD consolidated & sped up

User asked to drop `ANMATES_DOMAIN` entirely (they now own DNS + Cloudflare Tunnel)
and optimise the whole pipeline for simplicity + build time.

**Build-time config removed.** `auth_service.dart`'s `_configuredBaseUrl` default
changed from the stale Cloud Run URL to `''`; effective `apiBaseUrl` is now:
baked value → else `Uri.base.origin` (web) → else `http://localhost:8080` (native).
So the web image is **domain-agnostic**: no `API_BASE_URL` dart-define in CI, no GH
variable, no rebuild when DNS/tunnel/hostname changes. Verified the compiled bundle
no longer contains the Cloud Run URL (`grep -c` → 0). Local `docker compose`/
`start.sh` still pass an absolute `API_BASE_URL` (LAN IP) because there web (:54180)
and API (:8080) are *different* origins — that path is unchanged.

**3 workflows → 1.** Deleted `ci-build-push.yml`, `ci.go-api.yml`,
`ci.flutter-web.yml`; added `.github/workflows/ci.yml`: two parallel lanes
(`api`, `web`), each test-then-build in ONE job (one toolchain setup, and the test
steps gate the build for free since steps are sequential). PR → build without push
(still a Dockerfile gate, works for forks — no secrets needed); push to main → push
`:<sha>` + `:latest` to GHCR; final `deploy-command` job prints the manual helm line.

**Biggest speed win — web image no longer builds Flutter inside Docker.** CI already
sets up the SDK to analyze/test, so it now runs `flutter build web` on the runner and
packages the result with new `anmates_flutter/Dockerfile.prebuilt` (nginx + COPY,
seconds) instead of pulling the ~4 GB `ghcr.io/cirruslabs/flutter:stable` image and
recompiling from scratch. `anmates_flutter/Dockerfile` (self-contained build) is kept
for `docker compose`/`start.sh` so local dev still needs no Flutter installed.
Because the repo `.dockerignore` excludes `build/`, added
`Dockerfile.prebuilt.dockerignore` (BuildKit prefers `<dockerfile>.dockerignore`).

Other trims: golangci-lint runs on PRs only (on main it re-checks what the PR proved);
gha layer cache scoped per lane (`scope=api`/`scope=web`) so lanes stop evicting each
other; no layer cache on the web image (its COPY layer changes every build, caching
would only add upload time); dropped the PR `build/web` artifact upload; dropped the
`dart format` step — it was a **no-op gate** (missing `--set-exit-if-changed`) and 35
files are currently unformatted, so enabling it properly would have failed CI on the
first run.

**Verified:** `flutter analyze` 0 errors · `flutter test` 23/23 ·
`flutter build web --release` with NO `API_BASE_URL` succeeds (~37s local) and the
bundle has no stale/broken baked URL · `go vet` + `go test` (minus smoke) pass ·
`ci.yml` parses and the job graph is as intended. Docker builds NOT run locally
(no daemon on this machine) — first CI run is the real proof.

**Caveat for the user:** if branch protection requires status checks by name, the old
names (`Lint + Test`, `Docker build (no push)`, `Analyze + Test + Build web`, …) no
longer exist — update required checks to `Go API` and `Flutter Web`.

Docs synced: plan H4/H6, `values-prod.yaml` comment, plus OUTDATED banners on
`.github/CI-CD.md` and `.github/WORKFLOW-ARCHITECTURE.md` (both already described the
dead Cloud Run/Firebase era).
