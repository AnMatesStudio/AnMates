import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Shimmer-style skeleton placeholder used while content loads.
///
/// Why a custom widget (not the `shimmer` package)?
/// - One AnimationController shared across the app via [TickerProvider]
///   from the surrounding [State] — small and dependency-free.
/// - Uses [LinearGradient] swept across with [SlidingGradientTransform]
///   so the shimmer is purely paint, no extra widgets per frame.
class AnmSkeleton extends StatefulWidget {
  /// Width of the skeleton. Null = fill parent.
  final double? width;

  /// Height of the skeleton. Null = fill parent.
  final double? height;

  /// Border radius. Defaults to 12 (matches AppCard).
  final BorderRadius borderRadius;

  /// Shape — use [BoxShape.circle] for avatars.
  final BoxShape shape;

  const AnmSkeleton({
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.shape = BoxShape.rectangle,
    super.key,
  });

  /// Convenience constructor for avatar shimmer.
  const AnmSkeleton.circle({double? size, super.key})
    : width = size,
      height = size,
      borderRadius = const BorderRadius.all(Radius.circular(0)),
      shape = BoxShape.circle;

  @override
  State<AnmSkeleton> createState() => _AnmSkeletonState();
}

class _AnmSkeletonState extends State<AnmSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Honour reduce-motion accessibility setting.
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) {
      return _staticBox();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.shape == BoxShape.rectangle
                ? widget.borderRadius
                : null,
            shape: widget.shape,
            gradient: LinearGradient(
              colors: const [
                Color(0xFFEDEDED),
                Color(0xFFF7F7F7),
                Color(0xFFEDEDED),
              ],
              stops: const [0.1, 0.5, 0.9],
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
              transform: _SlidingGradientTransform(_controller.value),
            ),
          ),
        );
      },
    );
  }

  Widget _staticBox() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: AppColors.ink10,
        borderRadius: widget.shape == BoxShape.rectangle
            ? widget.borderRadius
            : null,
        shape: widget.shape,
      ),
    );
  }
}

/// Sweeps the gradient horizontally from -1 to +1 (full width).
class _SlidingGradientTransform extends GradientTransform {
  final double progress;
  const _SlidingGradientTransform(this.progress);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * (progress * 2 - 1), 0, 0);
  }
}
