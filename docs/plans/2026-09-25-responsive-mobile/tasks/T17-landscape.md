# T17 — Landscape: fix onboarding steps 3–4; icon-only nav on very short screens

**Executor:** Claude sub agent · **Depends on:** T03, T13, T30 · **Blocks:** —
**Files:** `lib/views/v2/screens/onboarding_screen.dart`, `lib/widgets/v2/glass_nav_bar.dart`, `lib/views/v2/v2_kit.dart`
**Skills to load:** `flutter-fix-layout-issues`, `flutter-adaptive-ui` (read `references/adaptive-best-practices.md`)

## Measured (README §1.1)

At 844×390 with no scale: `onb3` overflows 14px and `onb4` 23px at the bottom. Every other screen lays out,
but the 96pt glass nav covers a quarter of a 390pt-tall screen.

## Changes

1. **onb3 / onb4:** follow the skill's workflow. Read the overflow, then give the column that overflows a
   scrollable middle. `_BudgetStep` and `_TasteStep` already use `Expanded(SingleChildScrollView)` for their
   middle, so find what is still fixed-height above or below it. Keep the CTA pinned and visible. Do not shrink text.
2. **Glass nav, `V2Layout.isVeryShort(context)` (height < 500):** hide the labels (icon only, same 24pt glyphs).
   Every item keeps a ≥ 48 × 48 hit area. `navClearance` returns the matching smaller value, so screens
   pad by what the nav actually covers.
3. Do **not** branch on orientation or platform (the skills are explicit on this). Branch on available height only.

## Verify

- Matrix test: `onb3 @ landscape` and `onb4 @ landscape` green; all other `@ landscape` rows still green.
- Screenshot `landscape` column: every onboarding CTA is visible; the nav is a slim icon bar.
- `flutter analyze` clean; full `flutter test` green.
