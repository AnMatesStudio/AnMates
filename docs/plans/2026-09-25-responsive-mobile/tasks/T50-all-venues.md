# T50 — All-venues list: top from the safe area, 11pt photo badge

**Executor:** Hermes (local) · **Depends on:** T02 · **Blocks:** —
**Working dir:** `C:\AnM\AnMatesStudio\AnMates\anmates_flutter`
**File to edit (ONLY this file):** `lib/views/v2/screens/all_venues_screen.dart`

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

2. Find:
   ```dart
             padding: const EdgeInsets.fromLTRB(18, 104, 18, 6),
   ```
   Replace it with:
   ```dart
             padding: EdgeInsets.fromLTRB(
               V2Layout.hPad(context), V2Layout.contentTop(context), V2Layout.hPad(context), 6,
             ),
   ```

3. Find:
   ```dart
                             style: AppTextV2.name(color: Colors.white, size: 9)),
   ```
   Replace it with:
   ```dart
                             style: AppTextV2.name(color: Colors.white, size: 11)),
   ```

## Self-check (run it and paste the real output)

```powershell
C:\src\flutter\bin\flutter.bat analyze lib/views/v2/screens/all_venues_screen.dart
```
If analyze says `const` is not allowed on a widget that encloses the padding you changed, remove only that `const` keyword.

## Caller verification

`git diff --stat`: 1 file. Matrix `allVenues @`: layout and font green.
