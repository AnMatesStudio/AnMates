# 2026-06-01 — Screen 11 "Gửi hồ sơ" fails: "Null check operator used on a null value"

## TL;DR
Submit on the final onboarding screen (Screen 11 / step 6/6 "Show bản thân nào",
[photo_upload_view.dart](../../anmates_flutter/lib/views/onboarding/photo_upload_view.dart) `_finish`)
crashed with snackbar **"Gửi hồ sơ thất bại: Null check operator used on a null value"**.
Root cause = **Firebase Storage bucket had NO CORS policy**, so the web upload from
`http://127.0.0.1:54180` was blocked by the browser; the JS SDK rejected with a `null`
error which tripped a `null!` in flutterfire's web exception guard. Fixed by setting a
CORS policy on `gs://anmates-studio.firebasestorage.app`.

## Investigation (systematic-debugging)
- Error string is a Dart `!`-on-null. Audited the whole submit chain — **all app code is
  null-safe**: `OnboardingDraftController`, `StorageService`, `ProfileService`,
  `ApiClient`, `AuthService` (no reachable `!`).
- Traced into the only package on the path that can throw it on web:
  `firebase_storage_web 3.11.7` → `guard()` → `_flutterfire_internals 1.3.59`
  `guardWebExceptions` → **`_testException(Object? o) { final e = o! as JSError; ... }`**
  ([_flutterfire_internals.dart:94](file:///Users/thanhit/.pub-cache/hosted/pub.dev/_flutterfire_internals-1.3.59/lib/_flutterfire_internals.dart#L94)).
  When a Storage Future rejects with `null`/`undefined` (classic browser CORS/network
  failure — the response is opaque), `o!` throws "Null check operator used on a null value".
- Corroborated with env: `gcloud storage buckets describe gs://anmates-studio.firebasestorage.app`
  → **`cors_config: null`**. Dev runs Flutter **web** on `:54180` (start.sh), accessed via
  `127.0.0.1` per R-001. No CORS ⇒ cross-origin upload blocked ⇒ null error ⇒ the mask.

## Fix applied
- Added [anmates_flutter/storage.cors.json](../../anmates_flutter/storage.cors.json)
  (dev `127.0.0.1:54180` + `localhost:54180` + prod `*.web.app` / `*.firebaseapp.com`).
- `gcloud storage buckets update gs://anmates-studio.firebasestorage.app --cors-file=storage.cors.json`
  → verified `cors_config` now populated.

## Verification — PENDING user
User to re-run web app via `http://127.0.0.1:54180`, complete onboarding, tap Hoàn tất.

### UPDATE 2026-06-01 (round 2) — CORS was NOT the root cause
- Tested preflight: `firebasestorage.googleapis.com/v0/b/.../o` returns
  `access-control-allow-origin: *` **built-in** — the Firebase Storage upload endpoint
  does NOT depend on bucket-level GCS CORS. So my CORS fix was harmless but irrelevant to
  the upload. (Bucket CORS only matters for direct `storage.googleapis.com` downloads.)
- A denied upload (no/invalid auth) returns a **clean 403 JSON** `{"error":{"code":403,
  "message":"Permission denied."}}` → firebase JS SDK maps to `storage/unauthorized`
  (clear message), NOT the null-check. So rules/auth denial is NOT the cause either.
- Deployed Storage Rules verified CORRECT (Rules API): `user_photos/{uid}` write allowed
  for owner. Bucket exists. storageBucket configured. User is signed in (else the VN
  "phiên hết hạn" message would show).
- **Backend probe:** `PATCH /api/v1/profile/complete-onboarding`
  - LOCAL `localhost:8080` → **400 VALIDATION_ERROR** (endpoint EXISTS, reaches handler)
  - Cloud Run (Flutter's default `API_BASE_URL`) → **404 "Cannot PATCH ..."** — onboarding
    code NOT deployed to Cloud Run. start.sh overrides `API_BASE_URL=http://<LAN_IP>:8080`,
    so via start.sh the app uses local backend where it works.
- **Key clue:** storage_service.dart comment says a previous session already hit this
  null-check with `putData` and switched to `putString` to avoid it — and it STILL happens.
  ⇒ not a success-path interop bug; the upload REQUEST is failing and firebase_storage_web
  swallows the real error into `null` → flutterfire `_testException(null)` → `null!`.
- DB user (+84999999999, id a42ee29e-...) was created at AUTH (phone-verify), NOT at
  complete-onboarding — confirms the crash happens at the photo-upload step, BEFORE the API.

### Leading hypothesis (round 2): browser-level block (adblock/extension) or web interop
Next test = run in Incognito (extensions off) OR read the failed request status in
DevTools Network tab for `firebasestorage.googleapis.com`. Awaiting user.

### ROOT CAUSE CONFIRMED (round 3) — Firebase Storage JS SDK not loaded on web
User reported: NO network request to `firebasestorage.googleapis.com` before the error.
Added temp `debugPrint('SUBMIT_FAIL >>> $e\n$st')` in `_finish` catch → browser console
showed the JS stack:
```
TypeError: Cannot read properties of undefined (reading 'getStorage')
```
- `firebase_storage_web` interop binds to global `@JS('firebase_storage')`
  (storage_interop.dart:8) and calls `window.firebase_storage.getStorage(...)`.
- `firebase_core_web` (firebase_core_web.dart:179): **if `window.firebase_core != null`
  it returns early and SKIPS injecting ALL Firebase service scripts.**
- `web/index.html` pre-loads ONLY `firebase-app.js` + `firebase-auth.js` and sets
  `window.firebase_core` / `window.firebase_auth` (legacy workaround so core_web skips its
  TrustedTypes-based injection). Storage was never pre-loaded ⇒ `window.firebase_storage`
  undefined ⇒ `getStorage` undefined ⇒ JS TypeError ⇒ Dart surfaces "Null check operator
  used on a null value". No network call happens because the SDK isn't even loaded.

### FIX (round 3)
[web/index.html](../../anmates_flutter/web/index.html): added
`import * as firebaseStorage from ".../12.13.0/firebase-storage.js"` +
`window.firebase_storage = firebaseStorage;` (same 12.13.0 as core/auth).
Removed the temp debugPrint. `flutter analyze` clean.

**REBUILD REQUIRED** — index.html is build-time, not hot-reloadable. Stop flutter, rebuild
web (`./start.sh` docker `--build`, or restart `flutter run`), hard-refresh browser.

### Verification — PENDING user (round 3)
CORS / rules / backend were all red herrings. Real fix = load firebase-storage JS module.
When user confirms upload works → promote to resolution R-004; note tag for
"firebase web SDK pre-load must include EVERY product used (auth + storage + ...)".

## Open follow-ups
1. **Storage Rules** — confirm `user_photos/{uid}/...` allows `write: if request.auth.uid == uid`.
   If missing, next failure will be a clear `storage/unauthorized` (NOT the null-check).
2. **Backend** — `PATCH /api/v1/profile/complete-onboarding` must be deployed on Cloud Run
   (current-task flagged Go build UNVERIFIED). A 404 there surfaces as ApiException, not this bug.
3. **Code resilience (optional)** — `StorageService.uploadPhoto` could catch and rethrow a
   human-readable message so a future null-error failure isn't cryptic.
4. **Data gap (unrelated)** — `_draft.culture` is collected (validateVibeScreen) but never sent
   in `completeOnboarding` (only food + vibe). Confirm intended.

## Key facts
- bucket: `gs://anmates-studio.firebasestorage.app` (firebasestorage.app domain)
- the `!`-on-null is a flutterfire-internals masking bug; real failures on web with a null
  rejection (CORS/network) always surface as this cryptic message.
