# Plan — Post-OTP Onboarding Flow (Screens 08 + 09)

**Owner:** team-leader → coder → qa
**Date:** 2026-05-30
**Jira:** (Phase 2 onboarding — profile setup)
**Velocity preference:** ship both screens + backend in one coder pass, then QA.

---

## Goal

After OTP verification, route NEW users through 2 onboarding screens before MainTabView:
- **Screen 08** (step 3/5): User Profile — Thông Tin Cá Nhân
- **Screen 09** (step 4/5): Food Preferences — Gú Ẩm Thực

Both persist to the Go backend. RETURNING users (onboarding_done=true) skip straight to MainTabView.

New flow:
```
OtpView.onVerified → read onboarding_done from SharedPreferences (saved by _saveTokens)
  false → UserProfileView (3/5) → FoodPreferencesView (4/5) → MainTabView
  true  → MainTabView
```

---

## BACKEND (Go Fiber) — coder pass

### B1. Migration `anmates-api/db/migrations/003_onboarding.sql` (CREATE)
ALTER users: add nickname TEXT, birth_date DATE, personality_score SMALLINT,
food_tags TEXT[] NOT NULL DEFAULT '{}', vibe_tags TEXT[] NOT NULL DEFAULT '{}',
onboarding_done BOOLEAN NOT NULL DEFAULT FALSE. (All `IF NOT EXISTS`.)

### B2. `models/models.go` (MODIFY)
Add to User: Nickname *string, BirthDate *time.Time, PersonalityScore *int16,
FoodTags []string, VibeTags []string, OnboardingDone bool. (json tags per spec.)

### B3. `handlers/auth.go` (MODIFY)
Add `OnboardingDone bool json:"onboarding_done"` to userOut struct + toUserOut().

### B4. `services/interfaces.go` (MODIFY)
Add to UserServicer:
- UpdateOnboardingProfile(ctx, userID, name, nickname string, birthDate *time.Time, personalityScore *int16) (*User, error)
- UpdatePreferences(ctx, userID, foodTags, vibeTags []string) (*User, error)

### B5. `services/user.go` (MODIFY)
- Implement both methods (UPDATE ... RETURNING all new columns).
- UpdatePreferences sets onboarding_done = TRUE.
- Fix GetProfile + UpdateProfile RETURNING clauses to include new columns (and their Scan targets) so existing queries don't break.

### B6. `handlers/user.go` (MODIFY)
Add 2 handlers:
- PATCH /api/v1/profile/onboarding — onboardingProfileReq{name,nickname,birth_date "YYYY-MM-DD",personality_score *int16}. Parse birth_date → *time.Time. Get userID from JWT context. Return toUserOut.
- PATCH /api/v1/profile/preferences — preferencesReq{food_tags,vibe_tags}. Return toUserOut.

### B7. `main.go` (MODIFY)
- Add "PATCH" to CORS AllowMethods.
- Register auth.Patch("/profile/onboarding", ...) + auth.Patch("/profile/preferences", ...).

### B8. Update `api-contracts.md` with the 2 new PATCH endpoints.

---

## FLUTTER — coder pass

### F1. `lib/services/auth_service.dart` (MODIFY)
In _saveTokens persist `onboarding_done` to SharedPreferences. Add isOnboardingDone() helper.

### F2. `lib/services/profile_service.dart` (CREATE)
Singleton. saveOnboardingProfile({name,nickname,birthDate,personalityScore}) → PATCH /profile/onboarding.
savePreferences({foodTags,vibeTags}) → PATCH /profile/preferences, then set onboarding_done=true in prefs.
Use existing apiBaseUrl constant (confirm name in codebase — auth_service uses it).

### F3. `lib/utils/astrology.dart` (CREATE)
Pure Dart: zodiacSign, zodiacDateRange, lifePathNumber, napAm (30-entry table), heavenlyStem.
Use the exact Nạp Âm + zodiac + life-path-label tables from the task spec.

### F4. `lib/views/onboarding/user_profile_view.dart` (CREATE — Screen 08)
Match media/AnMates_Screens_PNG/08_ThongTinCaNhan.png. White bg. Top bar (back + THÔNG TIN CÁ NHÂN + 3/5).
Form: full name, nickname (+helper), DOB 3 dark-purple wheel cards (day 1-31 / month 01-12 / year 1960-2009),
auto-detect section (zodiac / nạp âm / numerology) AnimatedOpacity after DOB selected,
personality slider (gradient track, pink + thumb, 0-100 default 50, label Introvert/Ambivert/Extrovert).
Bottom AnmCTA "Tiếp tục →" enabled when name+nickname+dob set → saveOnboardingProfile → push FoodPreferencesView.

### F5. `lib/views/onboarding/food_preferences_view.dart` (CREATE — Screen 09)
Match media/AnMates_Screens_PNG/09_GuAmThuc.png. Top bar (back + GÚ ẨM THỰC + 4/5).
Food chips (12, multi-select) + vibe chips (5). Chip style per spec (berry selected / white unselected).
Fixed bottom bar: "N/5 đã chọn" counter + AnmCTA "Tiếp tục →" enabled when food >= 5 → savePreferences → widget.onComplete().

### F6. `lib/views/onboarding/onboarding_view.dart` (MODIFY — _navigateAway only)
Keep onAuthenticated as VoidCallback. In callback: read AuthService().isOnboardingDone();
true → pushAndRemoveUntil MainTabView; false → pushReplacement UserProfileView(onComplete: → MainTabView).
DO NOT break Firebase OTP wiring (R-001) or PhoneInputView/OtpView signatures.

---

## Constraints (HARD)
1. Don't break existing Firebase OTP wiring — OtpView + PhoneInputView still work.
2. Don't modify AppColors / AppTextStyles — use existing tokens.
3. Keep onAuthenticated as VoidCallback — read onboarding_done from SharedPreferences.
4. CORS AllowMethods must include PATCH.
5. DOB year range 1960–2009.
6. Slider default 50. Label: 0-33 Introvert / 34-66 Ambivert / 67-100 Extrovert.
7. All new Go SQL RETURNING clauses include ALL new columns.
8. food_tags / vibe_tags are TEXT[] — pgx array scanning.

## Acceptance criteria
- [ ] `go build ./...` clean in anmates-api
- [ ] `flutter analyze --no-fatal-warnings` clean (0 errors) in anmates_flutter
- [ ] New user after OTP → Screen 08 → Screen 09 → MainTabView
- [ ] Returning user (onboarding_done=true) → MainTabView directly
- [ ] DOB wheels work; auto-detect (zodiac/nạp âm/numerology) appears after DOB selected
- [ ] Personality slider 0-100, label updates live
- [ ] Screen 09 requires >= 5 food tags to continue; counter live
- [ ] Both screens persist via PATCH endpoints (200 OK)
- [ ] Firebase OTP wiring preserved (no R-001 regression)
- [ ] api-contracts.md updated with 2 new endpoints
- [ ] QA report saved to qa-reports/2026-05-30-onboarding-08-09.md

## Dispatch order
1. coder pass: backend (B1-B8) + flutter (F1-F6) together. Verify go build + flutter analyze before handoff.
2. qa pass: scope = onboarding screens 08/09 + routing + backend endpoints. Report to qa-reports/2026-05-30-onboarding-08-09.md.
3. Loop coder→qa max 3 times if fail; then escalate.

## Loop policy
Max 3 coder→qa cycles. If still failing after 3, mark blocked and escalate to user.
