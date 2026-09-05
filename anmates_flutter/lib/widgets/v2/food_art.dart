import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A transparent 3D food render floating with a drop shadow.
///
/// The shadow follows the image's alpha silhouette, the way CSS
/// `filter: drop-shadow()` does. A [BoxShadow] would trace the widget's
/// rectangle instead and leave a grey slab behind every cutout.
class FoodArt extends StatelessWidget {
  const FoodArt({
    super.key,
    required this.asset,
    this.fillFraction = 1,
    this.shadowOpacity = 0.2,
    this.shadowBlur = 18,
  });

  final String asset;

  /// How much of the slot the art fills, matching the design's `width`/`height`
  /// percentages inside each bed.
  final double fillFraction;
  final double shadowOpacity;
  final double shadowBlur;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(asset, fit: BoxFit.contain);
    Widget art = image;

    if (shadowOpacity > 0) {
      art = Stack(
        fit: StackFit.passthrough,
        children: [
          Transform.translate(
            offset: Offset(0, shadowBlur * 0.55),
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: shadowBlur * 0.5,
                sigmaY: shadowBlur * 0.5,
              ),
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  const Color(0xFF0A285A).withValues(alpha: shadowOpacity),
                  BlendMode.srcATop,
                ),
                child: image,
              ),
            ),
          ),
          image,
        ],
      );
    }

    if (fillFraction >= 1) return art;
    return Center(
      child: FractionallySizedBox(
        widthFactor: fillFraction,
        heightFactor: fillFraction,
        child: art,
      ),
    );
  }
}

/// A real venue photo when one is on file; the [fallback] 3D render otherwise.
///
/// A photo is an opaque rectangular JPEG, not the transparent cutout [FoodArt]
/// is built for, so it gets a plain `Image.network` rather than the
/// drop-shadow treatment — that filter traces alpha, and a JPEG has none.
/// [fallback] also covers a transient fetch failure (`errorBuilder`), so a
/// venue never shows a broken-image icon.
class VenuePhotoOrFallback extends StatelessWidget {
  const VenuePhotoOrFallback({
    super.key,
    required this.photoUrl,
    required this.fallback,
    this.fit = BoxFit.cover,
  });

  final String? photoUrl;
  final Widget fallback;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    if (url == null || url.isEmpty) return fallback;
    return Image.network(
      url,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}

/// `@keyframes amFloat` — a 9px bob with a ±1° tilt, offset per object so a
/// collage of dishes never moves in lockstep.
class FloatingArt extends StatefulWidget {
  const FloatingArt({
    super.key,
    required this.child,
    required this.period,
    this.delay = Duration.zero,
    this.travel = 9,
  });

  final Widget child;
  final Duration period;
  final Duration delay;
  final double travel;

  @override
  State<FloatingArt> createState() => _FloatingArtState();
}

class _FloatingArtState extends State<FloatingArt> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.period ~/ 2,
  );
  late final Animation<double> _t =
      CurvedAnimation(parent: _c, curve: Curves.easeInOut);
  Timer? _start;

  @override
  void initState() {
    super.initState();
    _start = Timer(widget.delay, () => _c.repeat(reverse: true));
  }

  @override
  void dispose() {
    _start?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -widget.travel * _t.value),
        child: Transform.rotate(
          angle: (-1 + 2 * _t.value) * 0.017453, // −1° → +1°
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
