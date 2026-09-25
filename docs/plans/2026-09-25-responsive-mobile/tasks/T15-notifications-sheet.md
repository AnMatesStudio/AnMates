# T15 — Notifications sheet: position from safe area and nav, not constants

**Executor:** Hermes (local) · **Depends on:** T02 · **Blocks:** —
**Working dir:** `C:\AnM\AnMatesStudio\AnMates\anmates_flutter`
**File to edit (ONLY this file):** `lib/widgets/v2/notifications_sheet.dart`

## Why

The sheet is pinned at `top: 88, bottom: 86`. The 88 assumes a 62pt notch. In a mobile browser the notch
is 0, so the sheet leaves a gap at the top. The 86 does not follow the nav when the text size grows.

## Edits

1. Add these imports after the existing `import '../../theme/app_theme_v2.dart';` line, skipping any that
   are already present:
   ```dart
   import '../../views/v2/v2_kit.dart';
   ```

2. In `NotificationsSheet.build`, find:
   ```dart
           Positioned(
             left: 10,
             right: 10,
             top: 88,
             bottom: 86,
   ```
   Replace it with:
   ```dart
           Positioned(
             left: 10,
             right: 10,
             // 26pt under the status bar, as in the design frame (62 + 26 = 88).
             top: MediaQuery.paddingOf(context).top + 26,
             // Just above the glass nav (navClearance is 96 + inset; the design used 86).
             bottom: navClearance(context) - 10,
   ```

## Self-check (run it and paste the real output)

```powershell
C:\src\flutter\bin\flutter.bat analyze lib/widgets/v2/notifications_sheet.dart
```

## Caller verification

`git diff --stat`: 1 file. Matrix `notifs @ *` has no layout failures. On the `iphone15-safari` screenshot,
the sheet starts about 26pt from the top.
