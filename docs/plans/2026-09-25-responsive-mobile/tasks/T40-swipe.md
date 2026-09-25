# T40 — Swipe: top from safe area, 11pt eyebrow

**Executor:** Hermes (local) · **Depends on:** T02 · **Blocks:** —
**Working dir:** `C:\AnM\AnMatesStudio\AnMates\anmates_flutter`
**File to edit (ONLY this file):** `lib/views/v2/screens/swipe_screen.dart`

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

2. In `SwipeScreen.build`, find:
   ```dart
         padding: EdgeInsets.fromLTRB(18, 104, 18, navClearance(context)),
   ```
   Replace it with:
   ```dart
         padding: EdgeInsets.fromLTRB(
           V2Layout.hPad(context), V2Layout.contentTop(context),
           V2Layout.hPad(context), navClearance(context),
         ),
   ```

3. In `_Overlap.build`, find:
   ```dart
               style: AppTextV2.eyebrow().copyWith(fontSize: 10),
   ```
   Replace it with:
   ```dart
               style: AppTextV2.eyebrow(),
   ```
   (`eyebrow` is 11pt after T10.)

## Self-check (run it and paste the real output)

```powershell
C:\src\flutter\bin\flutter.bat analyze lib/views/v2/screens/swipe_screen.dart
```

## Caller verification

- `git diff --stat`: 1 file.
- Matrix `swipe @` (with seeded candidates): all green. `pinned actions` means both the ✕ button and
  "Gửi lời mời đi ăn" are on screen at `se-safari` and `android-16x9`.
