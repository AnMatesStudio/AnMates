import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'anm_skeleton.dart';

/// Cached, resolution-aware network image with consistent placeholder + error UI.
///
/// Why not raw [Image.network]?
/// - [Image.network] has no disk cache → re-downloads on every cold start.
/// - Decodes at source resolution → a 1200×900 photo at 200×150 wastes ~10×
///   the RAM. [memCacheWidth] tells Flutter to downscale during decode.
///
/// Usage:
/// ```dart
/// AnmImage(
///   url: place.imageUrl,
///   width: 200,
///   height: 150,
///   borderRadius: BorderRadius.circular(12),
/// );
/// ```
class AnmImage extends StatelessWidget {
  /// Remote URL. If null/empty, renders [AnmImageError].
  final String? url;

  /// Render width (logical pixels). Used to compute [memCacheWidth].
  final double? width;

  /// Render height (logical pixels). Used to compute [memCacheHeight].
  final double? height;

  /// How the image fits its box. Defaults to [BoxFit.cover].
  final BoxFit fit;

  /// Optional border radius. When set, paints via [DecorationImage] so
  /// rounded corners clip without an additional [ClipRRect] layer.
  final BorderRadius? borderRadius;

  /// Optional placeholder override. Defaults to [AnmSkeleton].
  final Widget? placeholder;

  /// Optional error widget override.
  final Widget? errorWidget;

  const AnmImage({
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return errorWidget ??
          AnmImageError(width: width, height: height, radius: borderRadius);
    }

    final dpr = MediaQuery.devicePixelRatioOf(context);

    return CachedNetworkImage(
      imageUrl: url!,
      width: width,
      height: height,
      fit: fit,
      // memCacheWidth/Height tell the image cache to decode at display size,
      // not source size. For a 1200x900 photo rendered at 200x150 this is
      // a ~10x RAM reduction per cached image.
      memCacheWidth: width != null ? (width! * dpr).toInt() : null,
      memCacheHeight: height != null ? (height! * dpr).toInt() : null,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, __) =>
          placeholder ??
          AnmSkeleton(
            width: width,
            height: height,
            borderRadius: borderRadius ?? BorderRadius.zero,
          ),
      errorWidget: (_, __, ___) =>
          errorWidget ??
          AnmImageError(width: width, height: height, radius: borderRadius),
      imageBuilder: borderRadius == null
          ? null
          : (_, imageProvider) => DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                image: DecorationImage(image: imageProvider, fit: fit),
              ),
            ),
    );
  }
}

/// Error fallback rendered when [AnmImage] has no URL or fetch fails.
class AnmImageError extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? radius;

  const AnmImageError({this.width, this.height, this.radius, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.ink10,
        borderRadius: radius ?? BorderRadius.zero,
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported_outlined,
        size: 28,
        color: AppColors.ink50,
      ),
    );
  }
}
