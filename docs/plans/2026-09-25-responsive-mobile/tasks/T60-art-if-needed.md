# T60 — Phase D: swipe portrait and detail header art (only if screenshots show the need)

> **Phase D — do NOT run in Phase B.** README §1.1 measured no overflow without these. Run a part only when a
> Phase C screenshot shows the problem it fixes (the card or photo pushing actions below the fold on `se-safari` or `android-16x9`).

**Executor:** Hermes (local), **one session per file** · **Depends on:** T02, T40 / T41
**Working dir:** `C:\AnM\AnMatesStudio\AnMatesnmates_flutter`

## Part A — ONLY `lib/views/v2/screens/swipe_screen.dart`

1. In `_Portrait.build`, find:
   ```dart
         height: 172,
   ```
   Replace it with:
   ```dart
         // Shorter on a short screen so the card and both buttons fit without scrolling.
         height: (V2Layout.isShort(context) ? 132.0 : 172.0) * V2Layout.unit(context),
   ```


## Part B — ONLY `lib/views/v2/screens/detail_screen.dart`

1. In `DetailScreen.build`, find:
   ```dart
             SizedBox(
               height: 300,
   ```
   Replace it with:
   ```dart
             SizedBox(
               height: (V2Layout.isShort(context) ? 240.0 : 300.0) * V2Layout.unit(context),
   ```


2. In `_DetailArt.build`, find:
   ```dart
         left: 0, right: 0, bottom: 34, height: 230,
   ```
   Replace it with:
   ```dart
         left: 0, right: 0, bottom: 34,
         height: (V2Layout.isShort(context) ? 180.0 : 230.0) * V2Layout.unit(context),
   ```


## Self-check (run it and paste the real output; use the file of this session)

```powershell
C:\srclutterinlutter.bat analyze lib/views/v2/screens/<file>.dart
```
