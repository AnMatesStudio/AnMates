# T02 — `V2Layout` helper

**Executor:** Claude sub agent (small; Hermes can also do it because the code is fully given) · **Depends on:** — · **Blocks:** T03 and every Phase B task
**Working dir:** `C:\AnM\AnMatesStudio\AnMates\anmates_flutter`

Every later task calls these exact names. **Do not rename anything.**

## Create `lib/theme/v2_layout.dart`

```dart
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Width classes for the v2 screens. The design was drawn at 402pt wide (`md`).
enum V2Width { xs, sm, md, lg }

/// Responsive metrics for the v2 screens.
///
/// The rule every screen follows: **text never scales** (fixed pt sizes, the user's own text scale is
/// respected); **art, decoration and fixed box sizes scale with [unit]** — by width, never by height;
/// **vertical overflow scrolls**.
abstract final class V2Layout {
  /// Width of the canvas frame every v2 metric was drawn against.
  static const double designWidth = 402;

  /// Wider than this (tablet, a phone in landscape) the app renders as a centered column.
  static const double maxContentWidth = 480;

  /// Minimum hit area for anything tappable: Android's 48dp, which also covers
  /// iOS's 44pt (one web bundle serves both). Enlarge the hit area, not the drawing.
  static const double minTap = 48;

  /// Below this height a screen is "short": heroes compress.
  static const double shortHeight = 700;

  /// Smallest font size any readable text may use.
  static const double minFont = 11;

  static double width(BuildContext context) =>
      math.min(MediaQuery.sizeOf(context).width, maxContentWidth);

  static V2Width widthClass(BuildContext context) {
    final w = width(context);
    if (w < 360) return V2Width.xs;
    if (w < 390) return V2Width.sm;
    if (w < 430) return V2Width.md;
    return V2Width.lg;
  }

  static bool isShort(BuildContext context) =>
      MediaQuery.sizeOf(context).height < shortHeight;

  /// A phone in landscape: the glass nav drops its labels.
  static bool isVeryShort(BuildContext context) =>
      MediaQuery.sizeOf(context).height < 500;

  /// Scale for art, decoration and fixed box sizes: width / 402, clamped to [0.85, 1.1].
  /// Never apply this to text.
  static double unit(BuildContext context) =>
      (width(context) / designWidth).clamp(0.85, 1.1);

  /// Where a screen's own content starts: below the status bar and the language toggle
  /// (pinned at safeTop + 8, with a 48pt hit area). Replaces the design's hard-coded 96/100/104,
  /// which assumed a 60pt notch and left that space empty in mobile browsers.
  static double contentTop(BuildContext context) =>
      MediaQuery.paddingOf(context).top + 56;

  /// Horizontal page margin: 18, or 14 on the narrowest phones.
  static double hPad(BuildContext context) =>
      widthClass(context) == V2Width.xs ? 14 : 18;

  /// Extra height a box needs to hold text that measures [base] points at text scale 1,
  /// once the user's text scale is applied.
  static double textGrowth(BuildContext context, double base) =>
      MediaQuery.textScalerOf(context).scale(base) - base;
}
```

## Create `test/v2/v2_layout_test.dart`

Pump a `MediaQuery(data: MediaQueryData(size: ..., padding: ...), child: Builder(...))` and assert:

- `unit`: 320 → 0.85 (clamped), 402 → 1.0, 440 → ≈1.0945, 800 → 480/402 = 1.1 (clamped at the top)
- `widthClass`: 359 → xs, 360 → sm, 389 → sm, 390 → md, 430 → lg
- `contentTop` with padding top 0 → 56, top 59 → 115
- `isShort`: 699 → true, 700 → false; `isVeryShort`: 499 → true, 500 → false
- `textGrowth` at textScale 1.3 with base 20 → 6

## Verify

```powershell
C:\src\flutter\bin\flutter.bat analyze lib/theme/v2_layout.dart test/v2/v2_layout_test.dart
C:\src\flutter\bin\flutter.bat test test/v2/v2_layout_test.dart
```

`git diff --stat` shows only the 2 new files.
