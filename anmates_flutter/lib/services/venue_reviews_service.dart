import 'api_client.dart';

/// One community review excerpt + the site it came from. Shown on the venue
/// detail card, labelled as a web excerpt (not a verified first-party review).
class ReviewHighlight {
  final String text;
  final String source;
  const ReviewHighlight({required this.text, required this.source});

  factory ReviewHighlight.fromJson(Map<String, dynamic> j) => ReviewHighlight(
        text: (j['text'] as String?)?.trim() ?? '',
        source: (j['source'] as String?)?.trim() ?? '',
      );
}

/// Best-effort review signal for a venue (rating + count + snippets), scraped
/// keylessly server-side from Bing (no Google Maps — prohibited in VN). All
/// fields optional; [isEmpty] when nothing was found.
class VenueReviewInfo {
  final double? rating;
  final int? reviewCount;
  final List<ReviewHighlight> highlights;

  const VenueReviewInfo({this.rating, this.reviewCount, this.highlights = const []});

  static const empty = VenueReviewInfo();

  bool get isEmpty =>
      rating == null && reviewCount == null && highlights.isEmpty;
}

class VenueReviewsService {
  /// Fetches review signal for [query] (typically "name + address"). Returns
  /// [VenueReviewInfo.empty] on any error so the detail card simply shows less.
  Future<VenueReviewInfo> fetch(String query) async {
    final q = query.trim();
    if (q.length < 2) return VenueReviewInfo.empty;
    try {
      final data = await ApiClient()
          .get('/api/v1/venues/reviews?q=${Uri.encodeQueryComponent(q)}');
      if (data is! Map) return VenueReviewInfo.empty;

      final r = (data['rating'] as num?)?.toDouble();
      final c = (data['review_count'] as num?)?.toInt();
      final hs = (data['highlights'] as List?) ?? const [];

      return VenueReviewInfo(
        rating: (r != null && r > 0) ? r : null,
        reviewCount: (c != null && c > 0) ? c : null,
        highlights: hs
            .whereType<Map<String, dynamic>>()
            .map(ReviewHighlight.fromJson)
            .where((h) => h.text.isNotEmpty)
            .toList(),
      );
    } catch (_) {
      return VenueReviewInfo.empty;
    }
  }
}
