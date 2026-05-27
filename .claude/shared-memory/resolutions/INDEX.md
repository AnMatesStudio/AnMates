# Resolutions Index

**Confirmed solutions** — only entries here AFTER the user has verified the fix works in real conditions.

## How to query

Claude queries this index by:
1. **Tag match** — grep the Tags column for keywords from user's question
2. **Error code match** — check "Error keywords" section below for known strings
3. **Platform match** — filter by Platform column (web / android / ios / backend / all)
4. **Severity** — blocker > major > minor > nit

If a query matches, **read the full resolution file** before proposing a new fix. Don't re-investigate solved problems.

---

## Resolutions Table

| ID | Title | Tags | Platform | Severity | Date | Confirmed by | File |
|----|-------|------|----------|----------|------|--------------|------|
| R-001 | Firebase Phone OTP `INVALID_APP_CREDENTIAL` on web localhost | `firebase`, `phone-auth`, `otp`, `recaptcha`, `authorized-domains`, `127.0.0.1`, `localhost`, `web-dev` | web | blocker | 2026-05-26 | user | [R-001-firebase-phone-otp-web-127001.md](R-001-firebase-phone-otp-web-127001.md) |
| R-002 | Deploy Flutter Web → Firebase Hosting + Go Fiber API → Cloud Run | `flutter`, `firebase`, `go-backend`, `cloud-run`, `gcp`, `deploy`, `hosting`, `api-base-url` | web, backend | major | 2026-05-26 | user | [R-002-deploy-flutter-firebase-go-cloudrun.md](R-002-deploy-flutter-firebase-go-cloudrun.md) |

---

## Error keywords → Resolution lookup

When user reports an error matching a keyword below, jump straight to the linked resolution:

| Error keyword / message | Resolution |
|-------------------------|------------|
| `INVALID_APP_CREDENTIAL` (web) | R-001 |
| `auth/captcha-check-failed` (web) | R-001 |
| `Phone OTP` + `not sending` + `web localhost` | R-001 |
| `reCAPTCHA` + `Firebase` + `localhost` | R-001 |
| `localhost:8080` + Flutter web production | R-002 |
| `firebase deploy` + app trắng / không load | R-002 |
| `"public": "public"` + Firebase Hosting | R-002 |
| deploy Flutter Firebase Hosting | R-002 |
| deploy Go Cloud Run | R-002 |

---

## Tag glossary

| Tag | Meaning |
|-----|---------|
| `firebase` | Anything involving Firebase SDK/Console |
| `phone-auth` | Firebase Phone Number authentication |
| `otp` | One-time password / SMS verification |
| `recaptcha` | Google reCAPTCHA (v2/v3/Enterprise) |
| `authorized-domains` | Firebase Console → Auth → Settings → Authorized domains |
| `127.0.0.1` / `localhost` | Web origin / loopback addresses |
| `web-dev` | Local web development environment |
| `flutter` | Flutter framework code |
| `go-backend` | Go Fiber backend (`anmates-api`) |
| `android` | Android-specific (SHA fingerprint, Play Integrity) |
| `ios` | iOS-specific (APNs, entitlements, URL schemes) |
| `cloud-run` | Google Cloud Run deployment |
| `gcp` | Google Cloud Platform |
| `deploy` | Deployment procedures (hosting, infra) |
| `hosting` | Firebase Hosting |
| `api-base-url` | Flutter API base URL config (`String.fromEnvironment`) |

When adding a new resolution, **re-use existing tags** where possible — only add a new tag if no existing one fits.

---

## Index Maintenance Protocol

When the main assistant resolves an issue **AND the user confirms it works**:

1. Create `R-NNN-<short-kebab-slug>.md` in this folder using the [template](TEMPLATE.md).
2. Append a row to the **Resolutions Table** above. Pick the next free `R-NNN` (zero-padded, 3 digits).
3. Add Error keyword mappings if any specific error string can be matched.
4. Re-use existing tags; only add new ones to the Tag glossary if essential.
5. Append a row to `../changelog.md` mentioning the new resolution ID.

Sessions in `../sessions/` are chronological logs (may include diagnostic-only work). **Only confirmed fixes** with user verification go into `resolutions/`.
