---
id: R-003
title: Screen 08 UserProfileView — full implementation + nav bug fix (UserProfileView popped back to PhoneInputView)
tags: [flutter, onboarding, screen-08, navigation, profile, astrology, slider, dob-picker, custom-widget]
platforms: [android, ios, web]
severity: major
status: confirmed
date_resolved: 2026-05-31
confirmed_by: user
related_sessions: [sessions/2026-05-31-screen08-ui-polish.md]
related_blockers: []
---

# R-003: Screen 08 UserProfileView — full implementation + nav bug fix

## TL;DR

Implemented Screen 08 (Thông Tin Cá Nhân, step 3/5) with DOB picker, astrology auto-detect, and personality slider. Fixed a critical nav bug where `pushReplacement` left `PhoneInputView` in the back-stack, letting users escape onboarding via the back button. Fixed with `pushAndRemoveUntil`.

## Symptoms

- **Nav bug:** After OTP success, UserProfileView opened. Pressing back (top-bar ← or Android back) returned to PhoneInputView instead of being blocked.
- **Observable:** "UI nhập profile tự động out ra ngoài màn hình nhập SĐT OTP"

## Root Cause

`_routeAfterAuth` used `navigator.pushReplacement(UserProfileView)` which only replaced the OtpView at the top of the stack. Stack after: `[PhoneInputView, UserProfileView]`. Back button on UserProfileView popped to PhoneInputView.

## Solution

### Steps

1. In `onboarding_view.dart` → `_routeAfterAuth`, change `pushReplacement` to `pushAndRemoveUntil` with `(_) => false` predicate to clear the entire back-stack.

### Code changes
| File | Change |
|------|--------|
| `lib/views/onboarding/onboarding_view.dart` | `navigator.pushReplacement(UserProfileView)` → `navigator.pushAndRemoveUntil(UserProfileView, (_) => false)` |

### Key implementation details

**Backend (003_onboarding.sql):**
```sql
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS nickname TEXT,
  ADD COLUMN IF NOT EXISTS birth_date DATE,
  ADD COLUMN IF NOT EXISTS personality_score SMALLINT,
  ADD COLUMN IF NOT EXISTS food_tags TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS vibe_tags TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS onboarding_done BOOLEAN NOT NULL DEFAULT FALSE;
```

**New routes:**
- `PATCH /api/v1/profile/onboarding` — saves name, nickname, birth_date, personality_score
- `PATCH /api/v1/profile/preferences` — saves food_tags, vibe_tags, sets onboarding_done=true
- Add `"PATCH"` to CORS `AllowMethods` in `main.go`

**Routing flow:**
```
OtpView.onVerified → _routeAfterAuth(navigator)
  isOnboardingDone() == false → pushAndRemoveUntil(UserProfileView)  ← fix here
  isOnboardingDone() == true  → pushAndRemoveUntil(MainTabView)
```

**Astrology formulas (astrology.dart):**
```dart
// Nạp Âm: pairIndex = ((year-4) % 60) ~/ 2 → 30-entry lookup table
// Verified: year 2001 → Tân Tị → index 8 → "Bạch Lạp Kim" ✓
// Zodiac: month+day range lookup → 12 signs
// Life-path: sum digits of DDMMYYYY, reduce to 1-9 (master: 11/22/33)
```

**DOB picker (`_WheelCard`):**
```dart
decoration: BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.wisteria, AppColors.berry],
  ),
  borderRadius: BorderRadius.circular(20),
),
// ListWheelScrollView: useMagnifier: true, magnification: 1.45,
// overAndUnderCenterOpacity: 0.38, itemExtent: 30, height: 132
```

**Custom slider thumb (`_PlusThumbShape`):**
```dart
// SliderComponentShape radius=12, white border ring 2.5px, shadow blur 9
// Icon: Icons.restaurant via TextPainter(fontSize:14, color:white)
// overlayRadius: 20
```

**Horoscope icon widgets (`lib/widgets/horoscope_icons.dart`):**
- `ZodiacIcon(viName)` — Unicode glyph (♈-♓) in berry tinted badge
- `NguHanhIcon(element)` — Material icon in element's traditional color (Kim=gold, Mộc=green, Thủy=blue, Hỏa=red, Thổ=brown)
- `ThanSoIcon(number)` — numeral in gradient circle (wisteria → berry)
- `elementOf(napAmName)` — extracts element word from Nạp Âm name

**Zone label icons:**
```dart
_ZoneLabel(icon: Icons.nights_stay_rounded, title: 'Introvert', sub: 'Tám 1-1', activeColor: AppColors.ocean)
_ZoneLabel(icon: Icons.brightness_medium_rounded, title: 'Ambivert', sub: 'Cân bằng', activeColor: AppColors.berry)
_ZoneLabel(icon: Icons.wb_sunny_rounded, title: 'Extrovert', sub: 'Bàn 6+', activeColor: AppColors.berry)
```

## Verification

User hot-reloaded and visually confirmed each iteration. Navigation fix verified by observing back button no longer exits onboarding. `flutter analyze` → 0 errors. `go build ./...` → rc=0.

## Why this fix works (for future-Claude)

`pushAndRemoveUntil` with `(_) => false` removes ALL routes from the navigator stack before pushing the new one. This makes `UserProfileView` the root of the stack — `maybePop()` returns false (nothing to pop), so back button is a no-op. This pattern should be used for ALL post-auth onboarding screens to prevent accidental escape.

## Gotchas / Related issues

- `onboarding_done` is read from SharedPreferences (set during `_saveTokens` after OTP success). If SharedPreferences is stale from a previous test session, `isOnboardingDone()` may return `true` for a new user — clear app data to reset.
- The `navigator` object is captured in `OnboardingView._navigateAway()` BEFORE `pushReplacement` (to survive widget disposal). This captured reference is valid as long as `MaterialApp` is in the tree.
- `PATCH` method must be added to CORS `AllowMethods` in `main.go` — forgetting this causes 405 from web browsers.
- `GO111MODULE=off` in shell profile causes `go build` to spam false errors about missing packages. Always run with `GO111MODULE=on`.
- Drawing Material icons on canvas: use `TextPainter` with `String.fromCharCode(icon.codePoint)`, `fontFamily: icon.fontFamily`, `package: icon.fontPackage` — this allows setting `color` which emoji cannot do.

## References
- Session: [sessions/2026-05-31-screen08-ui-polish.md](../sessions/2026-05-31-screen08-ui-polish.md)
- Jira: TECH-7 (Implement UI New User Profile) in epic TECH-6 (Auth & Profile UI/UX)
