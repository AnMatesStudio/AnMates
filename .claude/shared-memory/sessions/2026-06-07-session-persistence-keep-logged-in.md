# 2026-06-07 — Keep user logged in across F5 / revisit (session persistence)

## TL;DR
User complaint: every F5 / revisit after login forced them back through onboarding.
Fixed by making the splash **restore** the persisted session instead of always
routing to onboarding, and by adding **silent token refresh on 401** so the
15-minute access token no longer kicks the user out. Returning users now stay
signed in for the full refresh-token window (~7 days).

## Root cause
- `views/splash/splash_screen.dart` had a hardcoded `Timer(2500ms) →
  pushReplacement(OnboardingView())`. It **never read the persisted tokens**.
  Tokens DO survive F5 (SharedPreferences = localStorage on web) — the splash
  just ignored them.
- Secondary: `services/api_client.dart` had no refresh-on-401. Access token TTL
  is 15m (`JWT_ACCESS_EXPIRE`), so even with the splash fixed the session would
  die after 15 minutes with no recovery.

## Backend was already correct (no change)
- Access token 15m, refresh token 168h/7d (`config/config.go`).
- `POST /api/v1/auth/refresh` rotates the pair and returns `user` (incl.
  `onboarding_done`) — `handlers/auth.go:Refresh` → `RotateRefreshToken`.

## Solution (Flutter only, 3 files)
1. **auth_service.dart**
   - `refreshSession()` → POST `/auth/refresh` with stored refresh_token, persist
     new tokens via `_saveTokens` (also re-syncs onboarding_done). Returns bool.
   - `clearSession()` → local-only wipe (no server call); `logout()` now reuses it.
2. **api_client.dart**
   - All verbs go through `_send(request)`: on HTTP 401 it calls `_refresh()`
     once and replays the request with the new token. `_refresh()` is
     single-flight (`_refreshing` future guard) so concurrent 401s share one
     refresh call. Imports `auth_service.dart` (no circular dep).
3. **splash_screen.dart**
   - Replaced the hardcoded timer with `_bootstrap()` → `_resolveStart()`:
     - not logged in → `OnboardingView`
     - logged in → `GET /profile` (ApiClient auto-refreshes on 401):
       - success → `onboarding_done ? MainTabView : resume UserProfileView`
       - 401 (refresh also expired) → `clearSession()` + `OnboardingView`
       - other/network error → fall back to locally-cached onboarding flag
         (don't punish the user; keep them in if a local session exists)
   - Minimum splash dwell (2200ms) runs concurrently with the session check.
   - Removed now-unused `dart:async` import + `_navTimer`.

## Files changed
- anmates_flutter/lib/views/splash/splash_screen.dart
- anmates_flutter/lib/services/api_client.dart
- anmates_flutter/lib/services/auth_service.dart

## Automated tests (NEW) + CI
- `test/session_persistence_test.dart` (5 tests, all green):
  - AuthService.refreshSession: valid → persists new pair + re-syncs
    onboarding_done; 401 → false; no refresh token → false + zero network.
  - ApiClient refresh-on-401: refreshes once then replays with the new bearer
    (asserts exactly 1 refresh + 2 protected calls); refresh-also-expired →
    ApiException(401) propagates.
  - Uses `package:http/testing.dart` MockClient injected via the new
    `httpClient` setters; SharedPreferences via `setMockInitialValues`.
- Testability refactor: `AuthService` + `ApiClient` gained a `@visibleForTesting
  set httpClient` and now route HTTP through an injectable `http.Client _client`.
- CI: `.github/workflows/ci.flutter-web.yml` already runs `flutter test` on PRs
  touching `anmates_flutter/**` → the new file is picked up automatically (no
  workflow edit needed). `flutter test` convention globs `test/*_test.dart`.
- Fixed pre-existing smoke test: SplashScreen now reads the session on startup,
  so `widget_test.dart` seeds `SharedPreferences.setMockInitialValues({})`.
  Also switched the splash min-dwell from `Future.delayed` to a cancellable
  `Timer` (cancelled in dispose) so it never leaks a pending timer in tests.

## Verification — DONE on host (C:\src\flutter)
- `flutter test` → **11/11 passed** (5 new + 6 existing).
- `flutter analyze --no-fatal-infos` on changed files → **No issues found**.
- `dart format` applied to all changed files.
- TODO (user): run `./start.sh`, log in at http://127.0.0.1:54180, then F5 →
  should land straight in the app (not onboarding). Wait >15 min and act → should
  refresh silently rather than log out. After 7 days idle → back to onboarding.

## Key facts
- Web: SharedPreferences is backed by localStorage → tokens already persist F5.
- The "thời gian nhất định" (how long you stay logged in) = refresh-token TTL,
  tunable via `JWT_REFRESH_EXPIRE` env (default 168h). No client constant.
- WebSocket (chat) auth does NOT auto-refresh — out of scope here; REST + splash
  cover the reported issue.
