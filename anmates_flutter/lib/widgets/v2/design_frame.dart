import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../views/v2/v2_data.dart';

/// Lays the app out in the canvas's coordinate space, then scales the result to
/// fit the real viewport.
///
/// Every v2 screen is a port of a design frame that is 402 × 874, and it is a
/// *pixel* port: fixed art sizes, fixed row heights, collages of absolutely
/// positioned food art. None of that reflows. On a phone shorter than the frame
/// — an iPhone SE is 667pt, a quarter short — the screens do not shrink, they
/// collide: art lands on top of headlines and the bottom controls fall off the
/// screen.
///
/// The arithmetic leaves no third option. To show an 874pt composition on a
/// 667pt screen without redrawing it, it has to be scaled by 0.76, so this
/// scales the whole frame at once — art, type and buttons together, in the
/// proportions the design was drawn in.
///
/// It only ever shrinks. A screen at least as tall as the frame renders 1:1 and
/// keeps the extra room, which the screens already absorb with `Expanded` and
/// `Spacer`.
class DesignFrame extends StatelessWidget {
  const DesignFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        if (!w.isFinite || !h.isFinite) return child;

        final k = math.min(1.0, h / kDesignFrameHeight);
        if (k >= 1) return child;

        // What the child gets to believe it has: the same viewport, measured in
        // frame units. Its height is the frame's by construction, so a screen
        // that fits the canvas fits here.
        final size = Size(w / k, h / k);
        final media = MediaQuery.of(context);

        return FittedBox(
          // `size` is the viewport divided by the scale, so it carries the
          // viewport's exact aspect ratio and `fill` is a uniform scale.
          fit: BoxFit.fill,
          child: SizedBox.fromSize(
            size: size,
            child: MediaQuery(
              // The device's own insets are physical, so they have to be
              // restated in frame units too — otherwise a notch or home
              // indicator shrinks along with the art it is meant to clear.
              data: media.copyWith(
                size: size,
                padding: media.padding / k,
                viewPadding: media.viewPadding / k,
                viewInsets: media.viewInsets / k,
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
