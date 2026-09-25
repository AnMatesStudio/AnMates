# T11 — Clamp text scale; keep phones in landscape out of the desktop frame

**Executor:** Hermes (local) · **Depends on:** — · **Blocks:** —
**Working dir:** `C:\AnM\AnMatesStudio\AnMates\anmates_flutter`
**File to edit (ONLY this file):** `lib/main.dart`

## Why

1. A user's large-text setting should be respected, but only up to 1.3×. Beyond that, the pill-shaped
   controls cannot hold the text.
2. `_webFrameBuilder` switches to the desktop phone frame whenever `width > 600`. A phone in landscape
   (844×390) is wider than 600, so it gets a 600-tall frame on a 390-tall screen, and the bottom is cut off.

## Edits

1. In `AnMatesApp.build`, find:
   ```dart
         builder: _webFrameBuilder,
   ```
   Replace it with:
   ```dart
         builder: (context, child) => _webFrameBuilder(
           context,
           // Respect the user's text size, up to the point the pill controls can hold it.
           MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3, child: child!),
         ),
   ```

2. In `_webFrameBuilder`, find:
   ```dart
     if (mq.size.width <= 600) return child!;
   ```
   Replace it with:
   ```dart
     // Only a real desktop window gets the phone frame. A phone held sideways is
     // also wider than 600, but far too short for a frame at least 600 tall.
     if (mq.size.width <= 600 || mq.size.height < 700) return child!;
   ```

3. Find the doc comment line directly above `Widget _webFrameBuilder`:
   ```dart
   /// 402 × 874 artboard. Below 600px wide (a real phone) it renders edge to edge.
   ```
   Replace it with:
   ```dart
   /// 402 × 874 artboard. Below 600px wide or 700px tall (a phone, in either
   /// orientation) it renders edge to edge.
   ```

## Self-check (run it and paste the real output)

```powershell
C:\src\flutter\bin\flutter.bat analyze lib/main.dart
```

## Caller verification

- `git diff --stat` shows 1 file.
- `flutter test test/v2` is green.
- Landscape check: after T05 exists, `node scripts/responsive-shots.mjs --viewports landscape --screens home`.
  The screenshot must show no dark desktop background around a phone frame.
