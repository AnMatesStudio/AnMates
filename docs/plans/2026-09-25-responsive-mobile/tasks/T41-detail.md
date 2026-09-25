# T41 — Detail: back button by safe area, remove the ±96 offset trick, 11pt badge

**Executor:** Hermes (local) · **Depends on:** T02 · **Blocks:** —
**Working dir:** `C:\AnM\AnMatesStudio\AnMates\anmates_flutter`
**File to edit (ONLY this file):** `lib/views/v2/screens/detail_screen.dart`

## Why

- The back button sits at `top: 104` for a 60pt notch. In a browser it floats 60pt down the photo.
- The card below is `Transform.translate(-96)` plus a 104pt spacer. Visually that nets +8, but the
  layout still reserves 96pt of empty scroll at the bottom.

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

2. In `DetailScreen.build`, find:
   ```dart
                 top: 104, left: 18,
   ```
   Replace it with:
   ```dart
                 // Level with the language toggle, which sits at safeTop + 8.
                 top: MediaQuery.paddingOf(context).top + 8, left: 18,
   ```

3. In `DetailScreen.build`, find:
   ```dart
               offset: const Offset(0, -96),
   ```
   Replace it with:
   ```dart
               offset: Offset.zero,
   ```
   and find:
   ```dart
                   const SizedBox(height: 104),
   ```
   Replace it with:
   ```dart
                   const SizedBox(height: 8),
   ```
   (The card lands in the same place: −96 + 104 = +8. The 96pt of dead scroll at the bottom goes away.)

4. In the same file, find:
   ```dart
                   style: AppTextV2.name(color: Colors.white, size: 9.5)
   ```
   Replace it with:
   ```dart
                   style: AppTextV2.name(color: Colors.white, size: 11)
   ```

## Self-check (run it and paste the real output)

```powershell
C:\src\flutter\bin\flutter.bat analyze lib/views/v2/screens/detail_screen.dart
```

## Caller verification

- `git diff --stat`: 1 file. Matrix `detail @`: all green.
- Screenshot grid at `design-frame`: the white info card starts 8pt under the header image, the same as before.
  Compare it with the baseline shot.
