import 'package:flutter/material.dart';

import '../services/api_client.dart';
import 'anm_widgets.dart';

/// Loads a web-searched venue photo through the backend image proxy and renders
/// it, falling back to the gradient [PhotoSlot] placeholder while loading or
/// when no photo is found (404 / network error). Use it anywhere a venue needs a
/// thumbnail — the Discovery list rows and the detail-screen hero share it.
class VenueThumbnail extends StatelessWidget {
  /// Free-text query used to find the photo (e.g. "Tiệm mì Ramen Q1 Quận 1").
  /// Used only when [imageUrl] is null (the keyless Bing fallback path).
  final String query;

  /// A direct, ready-to-render image URL (e.g. an agentic-enrich proxy URL).
  /// When set it takes precedence over [query]+[index].
  final String? imageUrl;

  /// Which crawled photo to show (0 = primary). The detail-screen gallery passes
  /// 0..count-1 to render multiple photos of the same venue.
  final int index;
  final double? width;
  final double height;
  final double radius;
  final BoxFit fit;

  /// Emoji/text shown in the placeholder while loading or on failure.
  final String placeholderLabel;

  const VenueThumbnail({
    super.key,
    this.query = '',
    this.imageUrl,
    this.index = 0,
    this.width,
    this.height = 68,
    this.radius = 14,
    this.fit = BoxFit.cover,
    this.placeholderLabel = '📸',
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = PhotoSlot(
      width: width,
      height: height,
      radius: radius,
      label: placeholderLabel,
    );

    final url = (imageUrl != null && imageUrl!.isNotEmpty)
        ? imageUrl!
        : ApiClient.imageUrl(query, index: index);
    if (url.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        gaplessPlayback: true,
        // Keep the last good frame so the browser cache makes re-renders instant.
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : placeholder,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: child,
          );
        },
        errorBuilder: (context, error, stack) => placeholder,
      ),
    );
  }
}
