# T42 — Me: header follows the safe area; stickers scale with width; 11pt stats

**Executor:** Hermes (local) · **Depends on:** T02 · **Blocks:** —
**Working dir:** `C:\AnM\AnMatesStudio\AnMates\anmates_flutter`
**File to edit (ONLY this file):** `lib/views/v2/screens/me_screen.dart`

## Why

The header is a fixed 268pt `Stack`: back/upgrade row at `top: 104`, food stickers at fixed x/y from
`kMeStickers` (drawn for 402pt wide). In a browser the whole header sits 52pt too low. On a 320pt phone the
right-hand stickers (x = 272–352) crowd the edge.

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

2. In `MeScreen.build`, find:
   ```dart
       final s = context.watch<V2State>();
   ```
   (the first line of `MeScreen.build`). Replace it with:
   ```dart
       final s = context.watch<V2State>();
       // The header was drawn with its content starting at 104; move all of it by
       // however far the real content top is from that. Stickers also scale by width.
       final dy = V2Layout.contentTop(context) - 104;
       final u = V2Layout.unit(context);
   ```

3. Find:
   ```dart
         padding: const EdgeInsets.only(bottom: 96),
   ```
   Replace it with:
   ```dart
         padding: EdgeInsets.only(bottom: navClearance(context)),
   ```

4. Find:
   ```dart
             height: 268,
   ```
   Replace it with:
   ```dart
             height: 268 + dy,
   ```

5. Find:
   ```dart
                   left: st.left, top: st.top, width: st.size, height: st.size,
   ```
   Replace it with:
   ```dart
                   left: st.left * u, top: st.top + dy, width: st.size * u, height: st.size * u,
   ```

6. Find:
   ```dart
                 top: 104, left: 16, right: 16,
   ```
   Replace it with:
   ```dart
                 top: 104 + dy, left: 16, right: 16,
   ```

7. In `_MiniStat.build`, find:
   ```dart
               fontSize: 10, fontWeight: FontWeight.w600,
   ```
   Replace it with:
   ```dart
               fontSize: 11, fontWeight: FontWeight.w600,
   ```

## Self-check (run it and paste the real output)

```powershell
C:\src\flutter\bin\flutter.bat analyze lib/views/v2/screens/me_screen.dart
```
If analyze reports that `const` cannot be used with `dy` or `u`, remove only the `const` keyword that the
message points to, then run analyze again.

## Caller verification

- `git diff --stat`: 1 file. Matrix `me @`: all green.
- Screenshot grid: at `design-frame` the stickers flank the avatar as in the baseline. At `floor-320` no
  sticker is cut off at the right edge.
