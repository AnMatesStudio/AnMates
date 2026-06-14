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
| R-003 | Screen 08 UserProfileView — full implementation + nav bug fix (UserProfileView popped back to PhoneInputView) | `flutter`, `onboarding`, `screen-08`, `navigation`, `profile`, `astrology`, `slider`, `dob-picker`, `custom-widget` | android, ios, web | major | 2026-05-31 | user | [R-003-screen08-profile-view-implementation.md](R-003-screen08-profile-view-implementation.md) |
| R-004 | Screen 11 "Hoàn tất" crash + validation mismatch + culture_tags missing — full onboarding submit fix | `flutter`, `firebase`, `web-dev`, `onboarding`, `storage`, `culture-tags`, `validation`, `loading-overlay` | web | blocker | 2026-06-01 | user | [R-004-screen11-onboarding-submit-full-fix.md](R-004-screen11-onboarding-submit-full-fix.md) |
| R-005 | CI deploy lên GitHub Environment `dev` — PR testing trực tiếp tại dev-anmates-studio.web.app | `flutter`, `go-backend`, `deploy`, `hosting`, `cloud-run`, `firebase`, `gcp`, `github-actions`, `ci-cd`, `web-dev` | web, backend | major | 2026-06-01 | user | [R-005-ci-dev-environment-deploy.md](R-005-ci-dev-environment-deploy.md) |
| R-006 | AI Concierge card: fake/out-of-area coords + wrong area name in intro + api container stuck "unhealthy" | `ai-concierge`, `web-search`, `geocode`, `grounding`, `healthcheck`, `docker`, `ipv6`, `go-backend`, `ai-venue-search`, `concurrency` | backend | major | 2026-06-08 | user | [R-006-ai-concierge-grounding-healthcheck.md](R-006-ai-concierge-grounding-healthcheck.md) |
| R-007 | Venue photo proxy — Bing source + 401/429/404/502 fixes + relevance filter + category stock fallback + swipe gallery | `venue-image`, `bing-images`, `go-backend`, `fiber-routing`, `rate-limit`, `image-proxy`, `relevance`, `category-fallback`, `flutter`, `gallery`, `web-search`, `docker` | backend, web, android, ios | major | 2026-06-11 | user | [R-007-venue-image-bing-relevance-fallback.md](R-007-venue-image-bing-relevance-fallback.md) |
| R-008 | Google Maps Platform APIs unusable for AnMates — VN-gated billing (Cloud Storage works in same project) | `gcp`, `google-maps`, `places-api`, `billing`, `vietnam`, `geo-policy`, `api-key`, `web-search`, `venue-image` | backend | major | 2026-06-14 | user | [R-008-google-maps-api-unusable-vn-billing-blocked.md](R-008-google-maps-api-unusable-vn-billing-blocked.md) |

---

## Error keywords → Resolution lookup

When user reports an error matching a keyword below, jump straight to the linked resolution:

| Error keyword / message | Resolution |
|-------------------------|------------|
| `Value 'dev' is not valid` + GitHub Actions environment | R-005 |
| `Value 'production' is not valid` + GitHub Actions environment | R-005 |
| CI deploy PR → `dev-anmates-studio.web.app` | R-005 |
| `firebase target:apply hosting dev` + `deploy --only hosting:dev` | R-005 |
| `production-web` / `production-api` → gộp 1 env `production` | R-005 |
| `INVALID_APP_CREDENTIAL` (web) | R-001 |
| `auth/captcha-check-failed` (web) | R-001 |
| `Phone OTP` + `not sending` + `web localhost` | R-001 |
| `reCAPTCHA` + `Firebase` + `localhost` | R-001 |
| `localhost:8080` + Flutter web production | R-002 |
| `firebase deploy` + app trắng / không load | R-002 |
| `"public": "public"` + Firebase Hosting | R-002 |
| deploy Flutter Firebase Hosting | R-002 |
| deploy Go Cloud Run | R-002 |
| UserProfileView + back button + PhoneInputView | R-003 |
| `pushReplacement` + onboarding + back-stack | R-003 |
| `onboarding_done` + SharedPreferences + routing | R-003 |
| Nạp Âm + pairIndex + năm sinh | R-003 |
| TextPainter + Material icon + canvas + color | R-003 |
| `GO111MODULE=off` + `go build` + false errors | R-003 |
| CORS + PATCH + 405 | R-003 |
| `Null check operator used on a null value` + Flutter web + Storage + no network request | R-004 |
| `TypeError: Cannot read properties of undefined (reading 'getStorage')` | R-004 |
| `window.firebase_storage` + undefined + web | R-004 |
| `firebase_storage_web` + `getStorage` + crash before upload | R-004 |
| `index.html` + `firebase-storage.js` + missing pre-load | R-004 |
| `food_tags must have between 5 and 10 items` | R-004 |
| `culture_tags` + not saved + onboarding | R-004 |
| `wget: can't connect to remote host: Connection refused` + container unhealthy | R-006 |
| docker healthcheck `localhost` + Go listens IPv4 + connection refused | R-006 |
| AI venue card `distance_m` wrong / venue far but shown near midpoint | R-006 |
| concierge intro wrong area name / `khu vực Xuân Hòa` | R-006 |
| `ai-venue-search http 502` + prewarm + fire concurrent | R-006 (B1) |
| `GET /api/v1/venues/image` + 401 Unauthorized | R-007 |
| `venues/image` + 429 / `RATE_LIMITED` on thumbnails | R-007 |
| `venues/image` + 404 Not Found every venue | R-007 |
| `venues/image?...&i=N` + 502 Bad Gateway (some gallery pages) | R-007 |
| venue shows wrong / irrelevant / NSFW photo | R-007 |
| `Unfortunately, bots use DuckDuckGo too` (server-side scrape CAPTCHA) | R-007 |
| Bing `murl` parsing / venue photo blank hero | R-007 |
| `api.Use(jwtMW)` catch-all hits public `app.Get` route | R-007 |
| `${DB_PASS}` not set / db unhealthy when `docker compose` run from `anmates-api/` subdir | R-007 (gotcha) |
| `The caller does not have permission` + `places.googleapis.com` (all config correct) | R-008 |
| `You must enable Billing on the Google Cloud Project` (billing IS active) | R-008 |
| `API_KEY_SERVICE_BLOCKED` / `API_KEY_HTTP_REFERRER_BLOCKED` + Maps API | R-008 |
| Google Maps / Places / Geocoding API blocked in Vietnam / VN | R-008 |
| Cloud Storage works but Maps Platform "enable billing" in same project | R-008 |
| "can we use Google Maps / Places API" for AnMates | R-008 (no — VN-gated) |

---

## Tag glossary

| Tag | Meaning |
|-----|---------|
| `github-actions` | GitHub Actions workflows (ci.*, cd.*, reusable) |
| `ci-cd` | CI/CD pipeline setup, triggers, environments, deploy steps |
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
| `onboarding` | Post-auth onboarding screens (08-09) |
| `screen-08` | Screen Thông Tin Cá Nhân (UserProfileView) |
| `navigation` | Flutter Navigator stack / routing |
| `profile` | User profile data + backend endpoints |
| `astrology` | Zodiac / Nạp Âm / life-path numerology calculations |
| `slider` | Flutter SliderThemeData / custom SliderComponentShape |
| `dob-picker` | ListWheelScrollView DOB 3-column picker |
| `custom-widget` | Reusable Flutter widget files (horoscope_icons.dart etc.) |
| `storage` | Firebase Storage upload/download |
| `culture-tags` | Screen 10 nền văn minh yêu thích — DB column + full stack |
| `validation` | Flutter ↔ backend validation bounds mismatch |
| `loading-overlay` | Submit/async loading UX overlay widget |
| `ai-concierge` | AI Concierge venue suggestion flow (trigger 70, prewarm/fire, card) |
| `ai-venue-search` | Python sidecar (MCP web-search + geocode + LLM structurer) |
| `web-search` | Web-search venue discovery path (vs DB+LLM) |
| `geocode` | Forward/reverse geocoding (Photon/Nominatim/OSM) |
| `grounding` | Anti-hallucination / making venue facts match reality |
| `healthcheck` | Container/Cloud Run health probe |
| `docker` | docker-compose / Dockerfile / container runtime |
| `ipv6` | IPv6 vs IPv4 bind/resolve mismatch (localhost ::1) |
| `concurrency` | Concurrent calls / single-flight / race conditions |
| `venue-image` | Discovery venue photo proxy/gallery (`/api/v1/venues/image`) |
| `bing-images` | Bing Images keyless scrape (`murl` JSON in results HTML) |
| `fiber-routing` | Fiber v2 route/middleware registration order (`group.Use` catch-all) |
| `rate-limit` | Per-IP API rate limiter + path exemptions |
| `image-proxy` | Server proxies remote image bytes (anti-hotlink Referer/UA) |
| `relevance` | Filtering search results by token overlap with the venue name |
| `category-fallback` | On-theme category stock photo when no real venue photo exists |
| `gallery` | Swipeable hero photo gallery (PageView + touch/mouse drag) |
| `google-maps` | Google Maps Platform APIs (Places/Geocoding/Static/Time Zone/etc.) |
| `places-api` | Place search/details/photos provider APIs (Google Places, Foursquare Places) |
| `billing` | Cloud provider billing accounts / payment methods / linkage |
| `vietnam` | VN-specific constraints (mapping regulation, country-gated services) |
| `geo-policy` | Country/legal restrictions on geographic/mapping data or services |
| `api-key` | API key auth, restrictions (application/API), key↔project association |

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
