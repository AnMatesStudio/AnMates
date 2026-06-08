/// Discovery web-search service.
/// Mirrors field names from schemas.py SuggestRequest / Go searchReq.
/// See plan.md PART C — C1.

import 'api_client.dart';

class VenueResult {
  final String name;
  final String address;
  final double lat;
  final double lng;
  final int distanceM;
  final double? rating;
  final int? priceMin;
  final int? priceMax;
  final String reason;

  const VenueResult({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.distanceM,
    this.rating,
    this.priceMin,
    this.priceMax,
    required this.reason,
  });

  factory VenueResult.fromJson(Map<String, dynamic> j) => VenueResult(
        name: (j['name'] as String?) ?? '',
        address: (j['address'] as String?) ?? '',
        lat: (j['lat'] as num?)?.toDouble() ?? 0.0,
        lng: (j['lng'] as num?)?.toDouble() ?? 0.0,
        distanceM: (j['distance_m'] as num?)?.toInt() ?? 0,
        rating: (j['rating'] as num?)?.toDouble(),
        priceMin: (j['price_min'] as num?)?.toInt(),
        priceMax: (j['price_max'] as num?)?.toInt(),
        reason: (j['reason'] as String?) ?? '',
      );
}

class VenueSearchService {
  /// Search for venues by free text.
  /// [lat] and [lng] may be null or 0 when the user has no location (ISSUE-9
  /// guard — distance is shown only when both are non-zero).
  Future<List<VenueResult>> search(String q, {double? lat, double? lng}) async {
    final params = StringBuffer('/api/v1/venues/search?q=${Uri.encodeQueryComponent(q)}');
    if (lat != null && lng != null) {
      params.write('&lat=$lat&lng=$lng');
    }
    final data = await ApiClient().get(params.toString());
    if (data == null) return [];
    return (data as List).map((e) => VenueResult.fromJson(e as Map<String, dynamic>)).toList();
  }
}
