# T16 — Search overlay: page margins follow the width class

**Executor:** Hermes (local) · **Depends on:** T02 · **Blocks:** —
**Working dir:** `C:\AnM\AnMatesStudio\AnMates\anmates_flutter`
**File to edit (ONLY this file):** `lib/widgets/v2/search_overlay.dart`

## Edits

1. Add after the existing `import '../../theme/app_theme_v2.dart';` line:
   ```dart
   import '../../theme/v2_layout.dart';
   ```

2. In `_SearchOverlayState.build`, find:
   ```dart
                   padding: const EdgeInsets.fromLTRB(18, 46, 18, 0),
   ```
   Replace it with:
   ```dart
                   padding: EdgeInsets.fromLTRB(
                     V2Layout.hPad(context), 46, V2Layout.hPad(context), 0,
                   ),
   ```

3. Search the same file for every other `EdgeInsets` whose left **and** right value is `18`
   (for example `EdgeInsets.symmetric(horizontal: 18)` or `EdgeInsets.fromLTRB(18, x, 18, y)`).
   Replace each `18` on the horizontal axis with `V2Layout.hPad(context)`, and remove the `const` keyword
   in front of that `EdgeInsets` only. Leave vertical values as they are. List every line you changed
   in your final reply.

## Self-check (run it and paste the real output)

```powershell
C:\src\flutter\bin\flutter.bat analyze lib/widgets/v2/search_overlay.dart
```

## Caller verification

`git diff --stat`: 1 file. Matrix `search @ *` is green except for font or tap failures inside result rows.
If any of those remain, give them to a Claude sub agent together with the failure output. Do not
re-run Hermes on them.
