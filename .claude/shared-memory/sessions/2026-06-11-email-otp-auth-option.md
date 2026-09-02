# 2026-06-11 — Email OTP as a 2nd auth option (alongside phone OTP, no captcha)

## TL;DR
User wanted a login path that avoids Firebase phone-OTP's reCAPTCHA. Decision: **keep
phone OTP, ADD passwordless email OTP** (Gmail SMTP) as a second option. Backend mints a
6-digit code, emails it, verifies it, upserts a user by email, and issues the existing app
JWT pair — no Firebase, no captcha. Flutter gets an "Đăng nhập bằng email" button on the
phone screen → email input → 6-digit entry (same UX as phone OTP). **Build/vet/test GREEN,
flutter analyze clean. PENDING live verify** (needs real `SMTP_*` env or DEV_MODE log sender).

## Why email OTP has no captcha
reCAPTCHA is Firebase Phone Auth's *web* app-attestation; it's mandatory there and can't be
disabled. Email OTP is fully our own backend flow (no Firebase) → no captcha. Anti-abuse is
handled by: per-email resend cooldown (60s), max wrong-code attempts (5), code expiry (10m),
plus the existing global per-IP rate limiter.

## Backend (Go) — additive, phone flow untouched
- **Migration** `db/migrations/012_email_otp.sql` — `email_otps` table (email, code_hash,
  expires_at, consumed_at, attempts) + idx on (email, created_at DESC) and expires_at.
- **`services/email.go`** (NEW) — `EmailSender` interface; `SMTPSender` (net/smtp
  `SendMail`, auto-STARTTLS, PLAIN auth — tuned for Gmail 587 + App Password); `LogSender`
  dev fallback (logs the code). `Send` runs SMTP on a goroutine so a cancelled request ctx
  unblocks.
- **`services/auth.go`** — `AuthService` gained `emailSender` + `EmailOTPOptions`
  (Expire/ResendCooldown/MaxAttempts), `SetEmailOTP()`, `EmailOTPEnabled()`. New methods:
  `RequestEmailOTP` (cooldown check → 6-digit `randomNumericCode` via crypto/rand → store
  sha256 hash → email), `VerifyEmailOTP` (newest unconsumed+unexpired row → attempt count →
  hash compare → consume → `upsertEmailUser`), `upsertEmailUser` (find-by-email else INSERT
  passwordless user, name = email local-part; unique-violation race re-reads). Added imports
  `math/big`, `strings`.
- **`services/errors.go`** — `ErrRateLimited`.
- **`services/interfaces.go`** — `AuthServicer` += RequestEmailOTP / VerifyEmailOTP /
  EmailOTPEnabled.
- **`handlers/auth.go`** — `RequestEmailOTP` (always 200 on a valid email so it can't probe
  which emails exist; 429 on cooldown), `VerifyEmailOTP` (401 on bad/expired → else IssueTokens
  → tokensJSON).
- **`config/config.go`** — `SMTP_HOST/PORT/USERNAME/PASSWORD/FROM/FROM_NAME`,
  `EMAIL_OTP_EXPIRE` (10m), `EMAIL_OTP_RESEND_COOLDOWN` (60s), `EMAIL_OTP_MAX_ATTEMPTS` (5).
- **`main.go`** — builds sender: real SMTP when `SMTP_HOST`+`SMTP_USERNAME` set; else
  `LogSender` only in DEV_MODE; else disabled. Routes `POST /api/v1/auth/email/request-otp`
  + `/verify-otp` registered only when `EmailOTPEnabled()`.
- **`.env.example`** — documented the `SMTP_*` + `EMAIL_OTP_*` block (incl. Gmail App
  Password note).

## Flutter — additive
- **`services/auth_service.dart`** — `requestEmailOtp(email)` + `verifyEmailOtp(email, code)`
  (uses overridable `_client`, persists tokens via `_saveTokens` like `phoneVerify`).
- **`views/auth/email_input_view.dart`** (NEW) — email entry, regex-validated, "Gửi mã OTP"
  → request → push `EmailOtpView`. Mirrors phone screen's gradient/logo/title chrome.
- **`views/auth/email_otp_view.dart`** (NEW) — 6-box + custom numeric keypad (same look as
  phone `OtpView`), hardware-keyboard support, 90s resend timer calling `requestEmailOtp`,
  `verifyEmailOtp` on full code → `onVerified`.
- **`views/auth/phone_input_view.dart`** — added secondary `_EmailLoginButton`
  ("Đăng nhập bằng email") below the OTP CTA → pushes `EmailInputView` with the same
  `onAuthenticated`. Phone flow otherwise unchanged.

## Verification
- `go build ./...` + `go vet ./services ./handlers ./config` → **BUILD_VET_OK** (golang:1.25).
- `go test ./services ./handlers ./config` → **ok** (services + handlers pass).
- `flutter analyze lib/views/auth lib/services/auth_service.dart` → **No issues found**.
- gofmt flags every repo file (CRLF artifact on Windows) → not touched.

## PENDING (live verify — blocked on user)
1. ✅ Local SMTP CONFIRMED — user received a real OTP email (Gmail, anmates.studio@gmail.com).
2. Full round-trip not yet confirmed: tap "Đăng nhập bằng email" → enter email → enter the
   6 digits → lands in app (new email users route through onboarding).
3. Branded HTML email: visually preview by triggering a FRESH OTP (the screenshotted email
   was the old plain-text version).
4. Deployed API: create GH vars `SMTP_HOST` + `SMTP_USERNAME` + secret `SMTP_PASSWORD`, then a
   deploy will carry SMTP to Cloud Run.
5. Commit/push this branch (`feat/implement-quan-detail`) — changes are still in the working
   tree, CI (incl. the now-fixed golangci-lint) runs on push.
6. When the full login round-trip is confirmed → migrate this session to a resolution
   (R-007 or next free): tags `email-otp`, `auth`, `smtp`, `passwordless`, `go-backend`,
   `flutter`, `ci-cd`.

## Addendum — branded HTML email (2026-06-11, after user got live SMTP working)
User asked to make the OTP email look professional. Upgraded the transport + content:
- **`services/email.go`** — `EmailSender.Send` signature now `(ctx, to, subject, textBody,
  htmlBody)`. `buildMessage` emits **multipart/alternative** (text + HTML) when htmlBody is
  set (text-only clients still get the plain version); added `encodeHeaderWord` (RFC 2047
  base64 for the UTF-8 Subject/From so "ĂnMates" + diacritics render) and `randomBoundary`.
  `LogSender` + `SMTPSender` updated to the new signature.
- **`services/auth.go`** — new `emailOTPHTML(code, mins)`: table-based, inline-styled
  responsive email (only reliable approach across Gmail/Outlook/Apple Mail), ĂnMates brand
  gradient header (berry #B8336A → berryDeep #8E1F4D), big spaced OTP pill, expiry + security
  note + footer. `RequestEmailOTP` now sends both `text` and `html`.
- Re-verified: go build/vet/test GREEN. To preview: trigger a fresh OTP (the old plain-text
  email predates this change).

## Addendum — CI/CD passes SMTP env to Cloud Run (2026-06-11)
Local SMTP works (user received a real branded OTP email). For the DEPLOYED API to also send,
the deploy must inject SMTP env — `gcloud run deploy --set-env-vars` REPLACES the whole env
set, so anything omitted is wiped (same gotcha as AI_SEARCH_URL in R-006).
- Added 3 `--set-env-vars` to BOTH `.github/workflows/cd.go-api.yml` (prod, push main) and
  `.github/workflows/ci.go-api.yml` `deploy-dev` job (PR → shared dev Cloud Run):
  - `SMTP_HOST=${{ vars.SMTP_HOST || 'smtp.gmail.com' }}` (GH **var**, has default)
  - `SMTP_USERNAME=${{ vars.SMTP_USERNAME }}` (GH **var**, non-sensitive)
  - `SMTP_PASSWORD=${{ secrets.SMTP_PASSWORD }}` (GH **secret**, Gmail App Password)
- `SMTP_FROM` defaults to username, `SMTP_FROM_NAME` defaults to "ĂnMates" in config → these 3
  are enough.
- **User action**: create GH **vars** `SMTP_HOST` + `SMTP_USERNAME` and **secret**
  `SMTP_PASSWORD` (repo-level, or per-environment in both `production` + `dev`).
- ⚠️ Security: a real-looking Gmail App Password is currently committed in `.env.example`
  (tracked) — should be replaced with a placeholder + the password revoked/rotated. Flagged to
  user, not yet actioned.

## Addendum — golangci-lint CI fix (2026-06-11)
CI step `golangci-lint-action@v7` (v2.12.2) failed with 11 issues, blocking merge. Fixed to 0:
- From this feature: `main.go` if-else-chain → `switch` (gocritic ifElseChain);
  `services/auth.go` `randomNumericCode` local `max` → `upper` (gocritic builtinShadow).
- Pre-existing on this branch (venue work, fixed together): `handlers/venue.go` local `sort`
  → `sortParam` (importShadow); `handlers/venue_image.go` + `services/venue_image.go`
  request body `nil` → `http.NoBody` ×4 (httpNoBody) and `defer resp.Body.Close()` +
  `//nolint:errcheck` ×4 (errcheck) — matching the existing convention in `services/auth.go`.
- Verified: `golangci-lint run` (v2.12.2 in docker) → **0 issues**; go build + test GREEN.
- Decision: **KEEP Bing** as the venue image source — user asked about switching to Google but
  server-side Google Images scraping would hit the same CAPTCHA/429 wall that retired DDG
  (the "proper" Google path needs the Custom Search JSON API + key, deferred).

## Key facts
- Routes only exist when an email sender is configured (`EmailOTPEnabled()`), so prod without
  SMTP simply won't expose them.
- Email users have `email` set, `phone`/`firebase_uid` null — satisfies the
  `users_identity_check` (email OR phone) from migration 002.
- `tokensJSON` returns `onboarding_done`; brand-new email users get false → Flutter routes
  them through Screen 08/09 onboarding exactly like new phone users.
