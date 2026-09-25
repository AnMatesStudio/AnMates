# T30 — Onboarding: top/bottom padding from the safe area

**Executor:** Hermes (local) · **Depends on:** T02 · **Blocks:** T31
**Working dir:** `C:\AnM\AnMatesStudio\AnMates\anmates_flutter`
**File to edit (ONLY this file):** `lib/views/v2/screens/onboarding_screen.dart`

## Why

Steps 1–4 pad with a fixed `top: 100, bottom: 26`, and the welcome step pads `vertical: 60`. In a mobile
browser that wastes ~50pt at the top. On an iPhone with a home indicator, the bottom 26 puts the CTA on
top of the indicator bar.

## Edits

1. Find:
   ```dart
   import '../../../theme/app_theme_v2.dart';
   ```
   Replace it with:
   ```dart
   import '../../../theme/app_theme_v2.dart';
   import '../../../theme/v2_layout.dart';
   ```

2. This line appears **three times** (in `_Hero`, `_SocialProof` and `_BudgetStep`):
   ```dart
           padding: const EdgeInsets.fromLTRB(24, 100, 24, 26),
   ```
   Replace **each** of them with:
   ```dart
           padding: EdgeInsets.fromLTRB(
             24, V2Layout.contentTop(context), 24, 26 + MediaQuery.paddingOf(context).bottom,
           ),
   ```

3. In `_TasteStep.build`, find:
   ```dart
           padding: const EdgeInsets.only(top: 100, bottom: 26),
   ```
   Replace it with:
   ```dart
           padding: EdgeInsets.only(
             top: V2Layout.contentTop(context),
             bottom: 26 + MediaQuery.paddingOf(context).bottom,
           ),
   ```

4. In `_Welcome.build`, find:
   ```dart
       return Padding(
         padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 60),
   ```
   Replace it with:
   ```dart
       final side = V2Layout.widthClass(context) == V2Width.xs ? 22.0 : 34.0;
       return Padding(
         padding: EdgeInsets.fromLTRB(
           side, V2Layout.contentTop(context), side, 26 + MediaQuery.paddingOf(context).bottom,
         ),
   ```

## Self-check (run it and paste the real output)

```powershell
C:\src\flutter\bin\flutter.bat analyze lib/views/v2/screens/onboarding_screen.dart
Select-String -Path lib/views/v2/screens/onboarding_screen.dart -Pattern "100, 24, 26|top: 100|vertical: 60"
```
The second command must print nothing.

## Caller verification

- `git diff --stat`: 1 file. `flutter test test/v2` is green (the onboarding SE tests included).
- Matrix `onb` (all 5 steps): the `pinned actions` check is green at every viewport.
