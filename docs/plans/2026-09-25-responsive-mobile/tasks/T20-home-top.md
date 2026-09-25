# T20 — Home: content starts under the toggle, not at a fixed 96

**Executor:** Hermes (local) · **Depends on:** T02 · **Blocks:** T21
**Working dir:** `C:\AnM\AnMatesStudio\AnMates\anmates_flutter`
**File to edit (ONLY this file):** `lib/views/v2/screens/home_screen.dart`

## Why

The feed is padded with `top: 96` and the background wash starts at `top: 104`. Both assume a 60pt notch.
In mobile Safari the notch inset is 0, so the top ~60pt of the screen is empty. The user's screenshot shows this.

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
   and find:
   ```dart
   import '../v2_data.dart';
   ```
   Replace it with:
   ```dart
   import '../v2_data.dart';
   import '../v2_kit.dart';
   ```

2. In `HomeScreen.build`, find:
   ```dart
           const Positioned(
             left: -58, right: -58, top: 104, bottom: 104,
             child: RepaintBoundary(child: CustomPaint(painter: FeedWashPainter())),
           ),
   ```
   Replace it with:
   ```dart
           Positioned(
             left: -58, right: -58, top: V2Layout.contentTop(context) + 8, bottom: 104,
             child: const RepaintBoundary(child: CustomPaint(painter: FeedWashPainter())),
           ),
   ```

3. In `HomeScreen.build`, find:
   ```dart
               padding: const EdgeInsets.only(top: 96, bottom: 96),
   ```
   Replace it with:
   ```dart
               padding: EdgeInsets.only(
                 top: V2Layout.contentTop(context),
                 bottom: navClearance(context),
               ),
   ```

## Do not

- Touch `_Hero`, `_TileRow`, `_CardRow` or any other class. Those are T21–T23.

## Self-check (run it and paste the real output)

```powershell
C:\src\flutter\bin\flutter.bat analyze lib/views/v2/screens/home_screen.dart
```

## Caller verification

- `git diff --stat`: 1 file. `flutter test test/v2` is green.
- Matrix `home @ iphone15-safari`: the profile pill's top edge is at 56 ± 2 (it was 96 before).
