# 2026-06-11 — Onboarding photo upload fails for Email-OTP users (Firebase anon fix)

## TL;DR
Final onboarding step (Screen 11 photo upload) threw "Gửi hồ sơ thất bại: Phiên đăng nhập Firebase
đã hết hạn. Vui lòng đăng nhập lại." Root cause is NOT an expired session — the newly-added
**Email-OTP login path never creates a Firebase session**, so `FirebaseAuth.instance.currentUser`
is null and the Firebase-Storage upload (rules need `request.auth.uid`) is rejected. Fixed by
signing in **anonymously** as a fallback before upload (user chose this over backend-proxy / custom
token). Requires enabling the Anonymous provider in Firebase Console.

## Root cause
- `storage_service.dart uploadPhoto` uploads straight to Firebase Storage; path
  `user_photos/{firebaseUid}/...`, rule `allow write: if request.auth.uid == uid`.
- Phone-OTP login establishes a Firebase session; **Email-OTP** (`auth_service.verifyEmailOtp`) and
  dev-login only persist the backend JWT — no Firebase sign-in → `currentUser == null` → the code
  threw the misleading "session expired" message. So **every email-OTP user is blocked at onboarding**.
- The `kDebugMode` bypass in `photo_upload_view.dart` doesn't fire in the docker web (release) build,
  so the real error shows.

## Fix (user chose: Firebase Anonymous fallback — quickest, no backend change)
- `services/storage_service.dart` — when `currentUser == null`, call
  `FirebaseAuth.instance.signInAnonymously()` and proceed; photo lands under the anonymous uid and
  its public download URL is saved to the backend profile (all the app needs). Surfaces a clear
  error if anonymous sign-in fails (provider not enabled).
- Storage rules unchanged — an anonymous user writing to its own `{uid}` folder still satisfies
  `request.auth.uid == uid`.

## ⚠️ Required manual step (user)
Firebase Console (project **anmates-studio**) → Authentication → Sign-in method → **Anonymous → Enable**.
Without it `signInAnonymously` fails and the new error message says so.

## Verification
- Flutter-only change; IDE diagnostics clean. **PENDING:** enable Anonymous provider + rebuild
  flutter_web (or hot restart) → log in via Email OTP → complete onboarding photo upload.

## Follow-ups / alternatives (not taken)
- Backend-proxied upload (JWT-auth, server-side storage) = the robust long-term fix that fully
  removes the client's Firebase-Auth dependency; revisit if moving further off Firebase.
- Or mint a Firebase custom token after email OTP (keeps a real per-user Firebase identity in Storage).
- Anonymous-uid photos aren't linked to the real user inside Storage (only via the saved URL) —
  acceptable for MVP.
