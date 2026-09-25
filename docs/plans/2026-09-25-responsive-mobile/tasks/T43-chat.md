# T43 — Chat: header from the safe area; composer drops to the bottom when the keyboard is up

**Executor:** Hermes (local) · **Depends on:** T02, T14 (T14 hides the nav while the keyboard is up) · **Blocks:** —
**Working dir:** `C:\AnM\AnMatesStudio\AnMates\anmates_flutter`
**File to edit (ONLY this file):** `lib/views/v2/screens/chat_screen.dart`

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

2. In `_Header.build`, find:
   ```dart
             padding: const EdgeInsets.fromLTRB(14, 96, 14, 10),
   ```
   Replace it with:
   ```dart
             padding: EdgeInsets.fromLTRB(14, V2Layout.contentTop(context), 14, 10),
   ```

3. In `_Composer.build`, find:
   ```dart
       return Padding(
         padding: EdgeInsets.fromLTRB(14, 0, 14, navClearance(context) - 12),
   ```
   Replace it with:
   ```dart
       // With the keyboard up the nav is hidden (see V2AppBody), so the composer
       // sits just above the keyboard instead of above a nav that isn't there.
       final keyboardUp = View.of(context).viewInsets.bottom > 0;
       return Padding(
         padding: EdgeInsets.fromLTRB(14, 0, 14, keyboardUp ? 10 : navClearance(context) - 12),
   ```

## Self-check (run it and paste the real output)

```powershell
C:\src\flutter\bin\flutter.bat analyze lib/views/v2/screens/chat_screen.dart
```

## Caller verification

- `git diff --stat`: 1 file. Matrix `chat @`: all green.
- In a throwaway widget test, set `tester.view.viewInsets = FakeViewPadding(bottom: 300)` and check that
  the composer's bottom edge is ≥ 290pt above the screen bottom and that `GlassNavBar` is not in the tree.
- **The real keyboard behaviour on iOS Safari cannot be tested in a widget test.** It stays in the T92 checklist.
