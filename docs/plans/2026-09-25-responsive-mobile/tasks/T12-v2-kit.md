# T12 — `v2_kit.dart`: nav clearance follows text size; 48pt hit areas

**Executor:** Hermes (local) · **Depends on:** T02 · **Blocks:** —
**Working dir:** `C:\AnM\AnMatesStudio\AnMates\anmates_flutter`
**File to edit (ONLY this file):** `lib/views/v2/v2_kit.dart`

## Edits

1. Replace the import block at the top of the file:
   ```dart
   import 'package:flutter/material.dart';

   import '../../theme/app_theme_v2.dart';
   ```
   with:
   ```dart
   import 'dart:math' as math;

   import 'package:flutter/material.dart';

   import '../../theme/app_theme_v2.dart';
   import '../../theme/v2_layout.dart';
   ```

2. Find:
   ```dart
   double navClearance(BuildContext context) =>
       96 + MediaQuery.paddingOf(context).bottom;
   ```
   Replace it with:
   ```dart
   double navClearance(BuildContext context) =>
       96 +
       // The nav's label grows with the user's text size (about 14pt of label line).
       V2Layout.textGrowth(context, 14) +
       MediaQuery.paddingOf(context).bottom;
   ```

3. In `class V2Chip`, method `build`, find the start of the returned widget:
   ```dart
       return GestureDetector(
         onTap: onTap,
         child: Container(
           padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
   ```
   Replace it with:
   ```dart
       return GestureDetector(
         onTap: onTap,
         behavior: HitTestBehavior.opaque,
         // The chip is drawn ~37pt tall; the hit area is padded out to 48.
         child: ConstrainedBox(
           constraints: const BoxConstraints(minHeight: V2Layout.minTap),
           child: Center(
             widthFactor: 1,
             child: Container(
           padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
   ```
   Then, at the end of that same `build` method, the return statement currently ends with:
   ```dart
           ),
         ),
       );
     }
   }

   /// Primary action: the blue→wisteria gradient with its violet lift.
   ```
   Change it to (two extra `),` for the `Center` and `ConstrainedBox` you opened):
   ```dart
           ),
         ),
           ),
         ),
       );
     }
   }

   /// Primary action: the blue→wisteria gradient with its violet lift.
   ```

4. In `class V2BackButton`, method `build`, find:
   ```dart
       return GestureDetector(
         onTap: onTap,
         child: Container(
           width: size,
           height: size,
   ```
   Replace it with:
   ```dart
       return GestureDetector(
         onTap: onTap,
         behavior: HitTestBehavior.opaque,
         // Drawn at [size]; the hit area never goes under 48.
         child: SizedBox.square(
           dimension: math.max(size, V2Layout.minTap),
           child: Center(
             child: Container(
           width: size,
           height: size,
   ```
   and close it the same way: the return statement currently ends with
   ```dart
           ),
         ),
       );
     }
   }

   /// The tall white sheet every settings-style screen sits inside.
   ```
   Change it to:
   ```dart
           ),
         ),
           ),
         ),
       );
     }
   }

   /// The tall white sheet every settings-style screen sits inside.
   ```

## Self-check (run it and paste the real output)

```powershell
C:\src\flutter\bin\flutter.bat analyze lib/views/v2/v2_kit.dart
C:\src\flutter\bin\flutter.bat format lib/views/v2/v2_kit.dart --output none --set-exit-if-changed
```
(The format check only reports. If it says a file would change, that is fine: the indentation of the
wrapped widgets is off by design. Do **not** run the formatter on the whole project.)

## Caller verification

- `git diff --stat`: 1 file. `flutter analyze` is clean. `flutter test test/v2` is green.
- Matrix test: the `tap targets` failures that come from chips and back buttons go away on
  `filters @`, `detail @`, `onb3 @` and `onb4 @`.
