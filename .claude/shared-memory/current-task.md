# Current Task

**Status:** in-progress (FE-UI-007 ✅ Screen 03 in-review — next: FE-UI-008 Screen 04)
**Owner:** main-assistant
**Started at:** 2026-05-26
**Last updated:** 2026-05-28
**Jira:** SCRUM-13 (FE-UI-007) In Progress | SCRUM-7 (FE-UI-001 audit) In Progress
**Goal:** Refactor TOÀN BỘ UI Flutter app (`anmates_flutter/`) khớp 24 design HTML mới nhất (`plan/lastest/design/`) + animation spec chi tiết trong `design-system.md`. Phased delivery (8 phases). This session covers **Phase 0 (Foundation) + Phase 1 (Onboarding screens 01-07)**.

## Most recent progress (2026-05-27)

Onboarding screen 02 "Chọn quán" refactored end-to-end: polaroid cards with real cartoon PNG illustrations (Lẩu/Cafe chill/Đồ nướng/Ăn vặt), tightly-stacked layout, full animation suite (staggered entry + ambient float + hover lift + press), responsive sizing for iPhone SE through 14, swipe enabled on touch + mouse + trackpad + stylus. ~400 lines of dead CustomPainter code removed. Visual confirmation pending. See [sessions/2026-05-26-onboard-02-chon-quan-polaroid-cards.md](sessions/2026-05-26-onboard-02-chon-quan-polaroid-cards.md) for full multi-iteration log.

**Blocked on user decision:** how to interpret the `food_card.png` re-crop request (food-art-only vs whole-polaroid + Flutter chrome refactor).

## Scope (this session)

- **Phase 0** — Foundation primitives + theme extension + assets
  - Brand primitives: `AppButton` (Primary/Secondary/Outline/Danger/Ghost), `AppChip` (Filter/Tag/Mood/State), `AppCard` (Restaurant/Mate/Booking), `AppInput` (Text/Phone/OTP/Search), `Avatar` (with optional TrustBadge ring), `VibeRing` (0–100 circular), `TrustBadge` (Perfect/Trusted/Limited), `AppLoader` (3 modes: splash / overlay / top-bar), `Sparkle` (twinkle SVG)
  - Theme extension: spacing tokens, semantic colors, reduce-motion provider, haptic helper
  - Assets folder skeleton: `assets/sparkles/` (CustomPainter fallback if no SVG)
- **Phase 1** — Onboarding (Screens 01–07)
  - 01 Splash (full animation timeline)
  - 02/03/04 Onboard carousel (3 educational screens with hero animations)
  - 05 Đăng nhập (phone + Apple ID — keep existing Firebase wiring)
  - 06 OTP (6-digit auto-advance — keep existing Firebase wiring)
  - 07 Face verify (liveness mock — UI only, no real ML)

## Out of scope (next sessions)

- Phase 2 (08, 09a, 10a — profile setup)
- Phase 3 (09b, 10b, 11 — discovery)
- Phase 4 (12, 13 — match)
- Phase 5 (14, 15, 16, 17 — chat + booking)
- Phase 6 (18-22 — kèo/letter/tracking/review)
- Phase 7 (23, 24 — tab Mình + trust)
- N1-N7 screens (no design yet — design-team blocker)
- Phase 2 IAP screens (25-28)
- Backend Go changes

## Acceptance criteria (this session)

- [ ] Phase 0 primitives in `lib/widgets/anm/` — all 9 primitives implemented + exported from a barrel file
- [ ] Theme extended with spacing/semantic tokens; reduce-motion + haptic helpers in `lib/services/`
- [ ] `pubspec.yaml` updated (`flutter_svg` added; `lottie` only if needed)
- [ ] Phase 1 screens 01-07 rewritten end-to-end matching reference HTML + design-system.md animation timelines
- [ ] Existing Firebase OTP wiring preserved (no regression on R-001 fix)
- [ ] Vietnamese diacritics render OK on all copy
- [ ] Hit targets ≥44×44px on every tappable element
- [ ] Reduce-motion mode covers all animated screens
- [ ] `flutter analyze` clean (0 errors, ≤5 warnings)
- [ ] `flutter test` passes (existing tests must continue to pass; no new tests required this session)
- [ ] QA report saved to `qa-reports/2026-05-26-phase-0-1.md`

## Key references

- HTML designs: `plan/lastest/design/01 _ Splash.html` … `07 _ Face verify.html` + `Brand system.html` (READ FIRST) + `Logo studies.html`
- Animation timelines: `.claude/shared-memory/design-system.md` lines ~200–700 (AppLoader, Sparkle, Splash, Onboard 02/03/04, Auth 05/06/07)
- Existing legacy code to REPLACE: `lib/views/splash/splash_screen.dart`, `lib/views/onboarding/onboarding_view.dart`, `lib/views/auth/auth_view.dart`, `lib/views/auth/phone_input_view.dart`, `lib/views/auth/otp_view.dart`
- Brand tokens (LOCKED — do not invent new shades): `lib/theme/app_theme.dart` `AppColors`
- Firebase OTP code (must keep wiring): `auth_error_messages.dart`, services hitting Firebase Phone Auth

## Loop policy

Max 3 coder→qa cycles for Phase 1. If still failing after 3, mark blocked and escalate to user.
