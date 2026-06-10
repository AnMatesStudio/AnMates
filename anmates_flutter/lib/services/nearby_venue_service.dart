/// Discovery "HOT QUANH BẠN" nearby venues.
/// Mirrors services.NearbyVenue JSON from the Go backend (/api/v1/venues/nearby).

import 'api_client.dart';

class NearbyVenue {
  final String name;
  final double lat;
  final double lng;
  final int distanceM;
  final double? rating;
  final int? priceLevel; // 0..4
  final bool? openNow;
  final String address;
  final List<String> tags;

  const NearbyVenue({
    required this.name,
    required this.lat,
    required this.lng,
    required this.distanceM,
    this.rating,
    this.priceLevel,
    this.openNow,
    this.address = '',
    this.tags = const [],
  });

  factory NearbyVenue.fromJson(Map<String, dynamic> j) => NearbyVenue(
        name: (j['name'] as String?) ?? '',
        lat: (j['lat'] as num?)?.toDouble() ?? 0.0,
        lng: (j['lng'] as num?)?.toDouble() ?? 0.0,
        distanceM: (j['distance_m'] as num?)?.toInt() ?? 0,
        rating: (j['rating'] as num?)?.toDouble(),
        priceLevel: (j['price_level'] as num?)?.toInt(),
        openNow: j['open_now'] as bool?,
        address: (j['address'] as String?) ?? '',
        tags: ((j['tags'] as List<dynamic>?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );

  /// "420m" under 1km, "1.2km" beyond. Empty when distance unknown (0).
  String get distanceLabel {
    if (distanceM <= 0) return '';
    return distanceM < 1000
        ? '${distanceM}m'
        : '${(distanceM / 1000).toStringAsFixed(1)}km';
  }

  String get emoji {
    final t = tags.join(' ').toLowerCase();
    if (t.contains('cafe') || t.contains('coffee') || t.contains('tea')) {
      return '☕';
    }
    if (t.contains('korean') || t.contains('bbq')) return '🥘';
    if (t.contains('japanese') || t.contains('sushi') || t.contains('ramen')) {
      return '🍣';
    }
    if (t.contains('pizza') || t.contains('italian')) return '🍕';
    if (t.contains('seafood')) return '🦐';
    if (t.contains('bar')) return '🍺';
    if (t.contains('fast_food') || t.contains('burger')) return '🍔';
    return '🍽️';
  }

  /// Display tags (max 2), cleaned of underscores.
  List<String> get displayTags {
    if (tags.isEmpty) return ['Ẩm thực'];
    return tags.take(2).map((t) => t.replaceAll('_', ' ')).toList();
  }
}

class NearbyVenueService {
  Future<List<NearbyVenue>> getNearby(double lat, double lng,
      {int limit = 8}) async {
    final data = await ApiClient()
        .get('/api/v1/venues/nearby?lat=$lat&lng=$lng&limit=$limit');
    if (data == null) return [];
    return (data as List)
        .map((e) => NearbyVenue.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
