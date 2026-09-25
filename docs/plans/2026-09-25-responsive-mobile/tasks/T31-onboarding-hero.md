# T31 — Onboarding: hero hotpot art scales with width, shrinks on short screens

> **Phase D — do NOT run in Phase B.** Run only if the Phase C screenshots show the problem this task fixes
> (see README §6). §1.1 measured no overflow without it; this is visual polish.

**Executor:** Hermes (local) · **Depends on:** T30, and T03 (which re-points the old `design frame` tests off `FloatingArt`) · **Blocks:** —
**Working dir:** `C:\AnM\AnMatesStudio\AnMates\anmates_flutter`
**File to edit (ONLY this file):** `lib/views/v2/screens/onboarding_screen.dart`

## Edit

In `_Hero.build` (the onboarding `_Hero`, step 1), find:
```dart
                  const SizedBox(
                    width: 238, height: 238,
                    child: FloatingArt(
```
Replace it with:
```dart
                  SizedBox.square(
                    // The design's 238pt render, scaled by width; smaller on a short screen
                    // so the headline and CTA stay on screen.
                    dimension: (V2Layout.isShort(context) ? 180.0 : 238.0) * V2Layout.unit(context),
                    child: const FloatingArt(
```

Change nothing else. The closing brackets stay the same, because only the opening lines change.

## Self-check (run it and paste the real output)

```powershell
C:\src\flutter\bin\flutter.bat analyze lib/views/v2/screens/onboarding_screen.dart
```

## Caller verification

- `git diff --stat`: 1 file.
- `flutter test test/v2`: green (T03 already deleted the old scaling tests that measured `FloatingArt`).
- Matrix `onb1 @`: green at every viewport.
