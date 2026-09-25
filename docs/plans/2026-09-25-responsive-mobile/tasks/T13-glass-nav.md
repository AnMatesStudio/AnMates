# T13 — Glass nav: labels never wrap; narrower side margin on small phones

**Executor:** Hermes (local) · **Depends on:** T02, T10 · **Blocks:** —
**Working dir:** `C:\AnM\AnMatesStudio\AnMates\anmates_flutter`
**File to edit (ONLY this file):** `lib/widgets/v2/glass_nav_bar.dart`

## Why

After T10 the nav labels are 11pt. On a 320–344pt screen, each of the four items gets about 65pt,
and "Messages" in English can wrap onto a second line, which makes the bar taller than
`navClearance` assumes.

## Edits

1. After the line `import '../../theme/app_theme_v2.dart';` add:
   ```dart
   import '../../theme/v2_layout.dart';
   ```

2. In `GlassNavBar.build`, find:
   ```dart
       return Padding(
         padding: const EdgeInsets.fromLTRB(14, 0, 14, 22),
   ```
   Replace it with:
   ```dart
       final side = V2Layout.widthClass(context) == V2Width.xs ? 8.0 : 14.0;
       return Padding(
         padding: EdgeInsets.fromLTRB(side, 0, side, 22),
   ```

3. In `_NavItem.build`, find:
   ```dart
               Text(label, style: AppTextV2.navLabel(color: color)),
   ```
   Replace it with:
   ```dart
               Text(
                 label,
                 maxLines: 1,
                 softWrap: false,
                 overflow: TextOverflow.ellipsis,
                 style: AppTextV2.navLabel(color: color),
               ),
   ```

## Self-check (run it and paste the real output)

```powershell
C:\src\flutter\bin\flutter.bat analyze lib/widgets/v2/glass_nav_bar.dart
```

## Caller verification

- `git diff --stat`: 1 file. `flutter test test/v2` is green.
- Matrix test: `home @ floor-320` has no overflow in `GlassNavBar`, also with `setLang(true)` (English labels).
