import 'dart:convert';

/// Parsed contents of an `ai_venue_card` chat message.
///
/// Mirrors the backend contract in docs/specs/ai-concierge-chat-spec.md §6 —
/// the JSON stored in `messages.content` when the AI Concierge fires.
class AiVenueCardContent {
  final String intro;
  final double midpointLat;
  final double midpointLng;
  final List<AiVenuePick> picks;

  const AiVenueCardContent({
    required this.intro,
    required this.midpointLat,
    required this.midpointLng,
    required this.picks,
  });

  factory AiVenueCardContent.fromJson(Map<String, dynamic> j) {
    final mid = (j['midpoint'] as Map<String, dynamic>?) ?? const {};
    final rawPicks = (j['picks'] as List<dynamic>?) ?? const [];
    return AiVenueCardContent(
      intro: j['intro'] as String? ?? '',
      midpointLat: (mid['lat'] as num?)?.toDouble() ?? 0,
      midpointLng: (mid['lng'] as num?)?.toDouble() ?? 0,
      picks: rawPicks
          .whereType<Map<String, dynamic>>()
          .map(AiVenuePick.fromJson)
          .toList(),
    );
  }

  /// Parses the raw `messages.content` string. Returns null if it is not a
  /// valid AI venue card (so callers can fall back to a plain bubble).
  static AiVenueCardContent? tryParse(String content) {
    try {
      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) return null;
      final card = AiVenueCardContent.fromJson(decoded);
      return card.picks.isEmpty ? null : card;
    } catch (_) {
      return null;
    }
  }
}

class AiVenuePick {
  final String restaurantId;
  final String name;
  final double? rating;
  final int? priceMin;
  final int? priceMax;
  final double lat;
  final double lng;
  final int distanceM;
  final String reason;

  const AiVenuePick({
    required this.restaurantId,
    required this.name,
    required this.rating,
    required this.priceMin,
    required this.priceMax,
    required this.lat,
    required this.lng,
    required this.distanceM,
    required this.reason,
  });

  factory AiVenuePick.fromJson(Map<String, dynamic> j) => AiVenuePick(
    restaurantId: j['restaurant_id'] as String? ?? '',
    name: j['name'] as String? ?? '',
    rating: (j['rating'] as num?)?.toDouble(),
    priceMin: (j['price_min'] as num?)?.toInt(),
    priceMax: (j['price_max'] as num?)?.toInt(),
    lat: (j['lat'] as num?)?.toDouble() ?? 0,
    lng: (j['lng'] as num?)?.toDouble() ?? 0,
    distanceM: (j['distance_m'] as num?)?.toInt() ?? 0,
    reason: j['reason'] as String? ?? '',
  );

  /// "80–150k" / "120k" / "" — human-friendly VND band.
  String get priceLabel {
    String k(int v) => '${(v / 1000).round()}k';
    if (priceMin != null && priceMax != null) return '${k(priceMin!)}–${k(priceMax!)}';
    if (priceMax != null) return k(priceMax!);
    if (priceMin != null) return k(priceMin!);
    return '';
  }

  /// "320m" / "1.2km".
  String get distanceLabel =>
      distanceM < 1000 ? '${distanceM}m' : '${(distanceM / 1000).toStringAsFixed(1)}km';
}
