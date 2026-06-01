# Session 2026-05-31 — Onboarding flow refactor (Screens 08→09→10→11)

**Status:** implemented, NOT user-confirmed yet (Path B). Flutter `flutter analyze` clean; Go build UNVERIFIED (no Go toolchain on the Windows dev box — build on Mac/CI).

## TL;DR

Reworked post-OTP onboarding from "each screen calls its own PATCH" into a
single deferred submit:

- **Screen 08 / 09** now only validate + write to a **client-side draft** (no API).
- **Screen 10** (NEW — photo upload "Show bản thân") validates all 3 steps on
  "Hoàn tất", uploads photos to **Firebase Storage**, then submits everything in
  one call `PATCH /api/v1/profile/complete-onboarding`.
- **Screen 11** (Discover/home) now GETs `/profile` and shows nickname + avatar.
- New DB table **`user_photos`** for the gallery (main avatar stays in
  `users.avatar_url`).

## Decisions (user-chosen via AskUserQuestion)

1. **Photo storage = Firebase Storage** (client uploads via `firebase_storage`,
   DB stores download URLs). Bucket `anmates-studio.firebasestorage.app`.
2. **Photos schema = dedicated `user_photos` table** (id, user_id FK, url,
   caption, position, created_at). Normalized; supports captions + order.

## DB adequacy verdict

`users` already covered every text field (name, nickname, birth_date,
personality_score, food_tags[], vibe_tags[], avatar_url, onboarding_done).
Astrology (zodiac/Nạp Âm/thần số) is derived from birth_date — not stored. The
**only gap was the multi-photo gallery + captions** → solved by `user_photos`.

## Files changed

### Backend (anmates-api) — UNVERIFIED build
- `db/migrations/004_user_photos.sql` (new) — `user_photos` table + index.
- `models/models.go` — added `UserPhoto` struct.
- `services/user.go` — `ListPhotos`, `OnboardingInput`, `CompleteOnboarding`
  (single tx: UPDATE users + DELETE/INSERT user_photos + onboarding_done=true).
- `services/interfaces.go` — added `CompleteOnboarding` + `ListPhotos` to `UserServicer`.
- `handlers/auth.go` — `userOut.Photos []photoOut`, `photoOut`, `toPhotosOut`.
- `handlers/user.go` — `CompleteOnboarding` handler (validates name/avatar
  required, food 5–10, vibe 2–5); `GetProfile` now includes photos. +models import.
- `main.go` — route `auth.Patch("/profile/complete-onboarding", ...)`. (CORS already had PATCH.)

### Flutter (anmates_flutter) — analyze clean
- `pubspec.yaml` — added `firebase_storage: ^13.0.0`, `image_picker: ^1.1.2`.
- `services/onboarding_draft.dart` (new) — `OnboardingDraftController`
  (ChangeNotifier singleton): all 08/09/10 data + per-section error strings +
  `validateStep08/09/10` + SharedPreferences mirror (`persist`/`load`). Holds
  `DraftPhoto` (bytes + caption + uploadedUrl).
- `services/storage_service.dart` (new) — `StorageService.uploadPhoto` →
  `FirebaseStorage.ref('user_photos/{uid}/{slot}_{ts}.jpg').putData(...)` →
  download URL (putData so web+mobile share one path).
- `services/profile_service.dart` — replaced per-screen methods with
  `completeOnboarding(...)` + `getProfile()`.
- `views/onboarding/user_profile_view.dart` (Screen 08) — draft-backed;
  name/nickname **letters-only** validation (`RegExp(r"^[\p{L} ]+$", unicode)`),
  **16+** age check + always-visible 16+ notice; red inline errors; no API.
- `views/onboarding/food_preferences_view.dart` (Screen 09) — food **5–10**,
  vibe **2–5** validation; `'no_onion' → '🚫 Không hành'`; **"Vibe buổi ăn"
  label + selected vibe chips = blue (AppColors.ocean)**; draft, no API.
- `views/onboarding/photo_upload_view.dart` (NEW Screen 10) — main (required)
  + 2 optional gallery photos w/ captions, tips card, Chụp mới/Thư viện/
  Instagram sources, "Bỏ qua"/"Hoàn tất". `_finish()` validates all 3 →
  jumps back via `popUntil(ModalRoute.withName('onb_profile'|'onb_food'))` →
  uploads → `completeOnboarding` → `onComplete()`.
- `views/onboarding/onboarding_view.dart` — Screen 08 route named
  `'onb_profile'`; `OnboardingDraftController.instance.reset()` on entry.
- `views/discover/discover_view.dart` (Screen 11) — loads `/profile`, greeting
  uses nickname, top-right shows avatar (NetworkImage) when present.

## Routing / jump-back design

Stack after OTP (new user): `[08 'onb_profile', 09 'onb_food', 10 'onb_photos']`.
Incremental validation means 08/09 are already valid by the time you reach 10;
"Hoàn tất" re-validates as a safety net. Errors are set on the shared
ChangeNotifier so the (still-mounted, lower-in-stack) earlier screen rebuilds to
show the red message, then `popUntil` brings it forward.

## ⚠️ REQUIRED before this works end-to-end

1. **Firebase Console → Storage**: enable Storage + add rules allowing
   authenticated writes to `user_photos/{uid}/**`, e.g.:
   ```
   match /user_photos/{uid}/{file} {
     allow read: if true;
     allow write: if request.auth != null;  // (uid match if using Firebase Auth uid)
   }
   ```
   Without this, uploads fail with permission-denied (mirror of the Phone-OTP
   console setup in R-001).
2. **Build the Go backend** on Mac/CI (`GO111MODULE=on go build ./...`) — migration
   004 auto-applies on startup via the embed+advisory-lock migrator.

## Open follow-ups
- Verify web upload path (image_picker camera source is limited on web → gallery).
- Caption editing is per-extra-photo only (main has fixed "Ảnh chính" label).
- Consider age `CHECK`/score `CHECK` constraints in SQL (currently app-enforced).
- `/profile/onboarding` + `/profile/preferences` endpoints now unused by the app
  (kept for backward-compat; can deprecate later).
