import 'package:flutter/material.dart';

import '../../theme/v2_layout.dart';

/// Hosts the v2 app at the real viewport's size, and on wide windows narrows it
/// to a centered phone-width column.
///
/// The rule every v2 screen follows:
///
/// * **Text never scales.** Type is set in fixed points; the only multiplier is
///   the user's own text scale.
/// * **Vertical overflow scrolls.** A phone shorter than the 402 × 874 design
///   frame gets the same layout with less of it on screen at once.
/// * **Wide windows get a [V2Layout.maxContentWidth] column.** A tablet, a phone
///   in landscape or a desktop browser renders the app centered at 480 wide
///   instead of stretching phone layouts across the window. The column also
///   rewrites [MediaQueryData.size] to its own width, so every
///   `MediaQuery.sizeOf` below it (the chat bubble's `width * 0.74`, for one)
///   measures the column and not the window around it.
///
/// This used to scale the whole frame by `min(1, height / 874)`. Looking only
/// at height, it shrank every mobile browser, because the browser's toolbar
/// eats the height: an iPhone 15 in Safari (393 × 668) rendered at 0.754, an
/// iPhone SE (375 × 553) at 0.627. The 9pt nav labels came out at 6.8pt and
/// 5.6pt, 48pt buttons at 36pt, and the layout believed it was 521–598pt
/// wide, wider than any phone. Safari also resizes its toolbar while
/// scrolling, which changed the scale mid-scroll. With the scale forced to 1,
/// all 12 screens and the 5 onboarding steps lay out without overflow from
/// 320 × 568 to 440 × 956, because they already scroll
/// (docs/plans/2026-09-25-responsive-mobile/README.md §1, §1.1).
class DesignFrame extends StatelessWidget {
  const DesignFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= V2Layout.maxContentWidth) return child;

        final media = MediaQuery.of(context);
        return Center(
          child: SizedBox(
            width: V2Layout.maxContentWidth,
            child: MediaQuery(
              data: media.copyWith(
                size: Size(V2Layout.maxContentWidth, media.size.height),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
