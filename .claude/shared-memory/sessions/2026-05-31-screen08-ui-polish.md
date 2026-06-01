# Session: 2026-05-31 — Screen 08 Thông Tin Cá Nhân — Full implementation + UI polish

## TL;DR

Implemented Screen 08 (UserProfileView, step 3/5) end-to-end: backend migration + PATCH API + Flutter UI. Then iterated through multiple rounds of user-directed UI polish (icons, colors, slider, DOB picker) until confirmed. Also fixed a critical navigation bug where UserProfileView could be popped back to PhoneInputView.

---

## What was built / changed

### Backend (team-leader session, 2026-05-30)
| File | Change |
|------|--------|
| `anmates-api/db/migrations/003_onboarding.sql` | 6 new columns: `nickname`, `birth_date`, `personality_score`, `food_tags[]`, `vibe_tags[]`, `onboarding_done` |
| `anmates-api/models/models.go` | New fields on User struct |
| `anmates-api/handlers/auth.go` | `userOut` + `toUserOut` now emit `onboarding_done` |
| `anmates-api/services/user.go` | `UpdateOnboardingProfile` + `UpdatePreferences` |
| `anmates-api/handlers/user.go` | `PATCH /api/v1/profile/onboarding` + `PATCH /api/v1/profile/preferences` |
| `anmates-api/main.go` | CORS `AllowMethods` + `PATCH`; 2 new routes |

### Flutter (team-leader session, 2026-05-30)
| File | Change |
|------|--------|
| `lib/services/auth_service.dart` | Persist `onboarding_done` after auth; `isOnboardingDone()` helper |
| `lib/services/api_client.dart` | `patch()` method |
| `lib/services/profile_service.dart` | `saveOnboardingProfile()` + `savePreferences()` |
| `lib/utils/astrology.dart` | Zodiac, Nạp Âm (30-entry table), life-path numerology |
| `lib/views/onboarding/user_profile_view.dart` | Screen 08 — full name, nickname, DOB picker, auto-detect, personality slider |
| `lib/views/onboarding/food_preferences_view.dart` | Screen 09 — food/vibe tag selection |
| `lib/views/onboarding/onboarding_view.dart` | `_routeAfterAuth`: new user → Screen 08; returning user → MainTabView |

### New widget library (this session, 2026-05-31)
| File | Change |
|------|--------|
| `lib/widgets/horoscope_icons.dart` | `ZodiacIcon` (Unicode glyphs), `NguHanhIcon` (element colors), `ThanSoIcon` (gradient circle) |

---

## Critical bug fixed — Navigation stack (UserProfileView → PhoneInputView back)

**Symptom:** After OTP success, UserProfileView opened but could be popped (back button or Android back) to PhoneInputView.

**Root cause:** `_routeAfterAuth` used `navigator.pushReplacement(UserProfileView)` which replaced only OtpView, leaving `[PhoneInputView, UserProfileView]` on the stack.

**Fix:** Changed to `navigator.pushAndRemoveUntil(UserProfileView, (_) => false)` — clears entire back-stack.

---

## UI polish decisions (user-confirmed, 2026-05-31)

### DOB picker cards
- Background: gradient `topLeft: wisteria (#C490D1) → bottomRight: berry (#B8336A)` — matches ThanSoIcon
- Height: 132px, `borderRadius: 20`
- Uses `ListWheelScrollView` with `useMagnifier: true`, `magnification: 1.45`, `overAndUnderCenterOpacity: 0.38`

### Auto-detect section (ĂN MATES TỰ NHẬN DIỆN)
- 3 cards in `IntrinsicHeight` Row so all cards are same height
- Card layout: label (colored by category) → icon → value text → sub text (6px gap)
- Icons: `ZodiacIcon` (berry), `NguHanhIcon` (element color), `ThanSoIcon` (pink gradient)
- ThanSoIcon gradient: `wisteria → berry` (purple-to-pink), NOT the `#D4789A → #B8336A` pink variant

### Personality slider (TÍNH CÁCH BÀN ĂN)
- Section wrapped in card: border `berry 0.18 alpha`, `borderRadius: 20`, shadow
- Thumb: `_PlusThumbShape` custom `SliderComponentShape`, radius 12, white border ring 2.5px, shadow blur 9
- Thumb icon: `Icons.restaurant` (fork & knife) via `TextPainter`, white, 14px — drawn on canvas
- Overlay radius: 20 (proportional to thumb radius 12)
- Animated zone badge: pill shows `Introvert/Ambivert/Extrovert · value`, color shifts ocean→berry
- Zone labels with icons: Introvert `Icons.nights_stay_rounded` (ocean), Ambivert `Icons.brightness_medium_rounded` (berry), Extrovert `Icons.wb_sunny_rounded` (berry)
- Zone sub-text: Introvert "Tám 1-1", Ambivert "Cân bằng", Extrovert "Bàn 6+"

### TÍNH CÁCH BÀN ĂN label
- `Icons.restaurant_rounded` (13px, berry) prepended to label text

---

## Astrology formulas (verified correct)

### Nạp Âm Ngũ Hành
```dart
// pairIndex = ((year-4) % 60) ~/ 2 → lookup in 30-entry table
// Verified: 2001 (Tân Tị) → pairIndex 8 → Bạch Lạp Kim ✓
// Shortcut element-only: canVal = (canIdx ~/ 2) + 1; chiVal = (chiIdx % 6) ~/ 2; sum = canVal+chiVal; if >5 subtract 5
```

### Zodiac / Life-path numerology
- Zodiac: month+day range lookup
- Life-path: sum all digits of DDMMYYYY, reduce to 1-9 (preserve master 11/22/33)

---

## Jira
- Epic: TECH-6 (Auth & Profile UI/UX)
- Story: TECH-7 (Implement UI New User Profile) — created this session

---

## Verification
User tested iteratively via hot reload throughout the session. Each UI change was visually confirmed before proceeding to next. Navigation bug confirmed fixed. Build: `flutter analyze` → 0 errors; `go build` → rc=0.
