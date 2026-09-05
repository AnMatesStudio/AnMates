import 'api_client.dart';

/// A row of AnMates' own venue table, as served by `GET /api/v1/venues`.
///
/// This is the app's only venue source — everything, including photos
/// (`venue_photos` blobs), lives in the DB. No external venue search exists.
class CatalogVenue {
  const CatalogVenue({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.cuisineTags,
    required this.photoUrls,
    required this.source,
    required this.wantCount,
    this.address,
    this.district,
    this.priceMin,
    this.priceMax,
    this.rating,
    this.distanceM,
  });

  final String id;
  final String name;
  final String? address;
  final String? district;
  final double lat;
  final double lng;
  final List<String> cuisineTags;
  final int? priceMin;
  final int? priceMax;
  final double? rating;

  /// Absolute URLs of this venue's stored photos (`ApiClient.venuePhotoUrl`),
  /// built here from the API's `photo_count` — the API never sends a raw URL
  /// for a photo, only how many slots it has. Empty means no photo on file,
  /// not a fetch failure; callers should fall back to placeholder art, never
  /// retry or show a broken-image icon.
  final List<String> photoUrls;
  final String source;

  /// Metres from the query point — null when the request carried no location.
  final int? distanceM;

  /// Users whose wishlist category matches one of [cuisineTags]. The schema has
  /// no venue-level wishlist, so this is the only real demand signal available;
  /// 0 is honest, not a placeholder.
  final int wantCount;

  factory CatalogVenue.fromJson(Map<String, dynamic> json) {
    String? str(String k) {
      final v = json[k];
      return (v is String && v.trim().isNotEmpty) ? v.trim() : null;
    }

    final id = (json['id'] ?? '').toString();
    final photoCount = (json['photo_count'] as num?)?.toInt() ?? 0;

    return CatalogVenue(
      id: id,
      name: str('name') ?? 'Không tên',
      address: str('address'),
      district: str('district'),
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      cuisineTags: (json['cuisine_tags'] as List?)?.whereType<String>().toList() ?? const [],
      priceMin: (json['price_min'] as num?)?.toInt(),
      priceMax: (json['price_max'] as num?)?.toInt(),
      rating: (json['rating'] as num?)?.toDouble(),
      photoUrls: id.isEmpty
          ? const []
          : [for (var i = 0; i < photoCount; i++) ApiClient.venuePhotoUrl(id, i)],
      source: str('source') ?? 'seed',
      distanceM: (json['distance_m'] as num?)?.toInt(),
      wantCount: (json['want_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class VenueCatalogService {
  static final VenueCatalogService _instance = VenueCatalogService._();
  VenueCatalogService._();
  factory VenueCatalogService() => _instance;

  /// Fetches the active catalogue. Passing [lat]/[lng] filters by [radiusM] and
  /// sorts nearest-first; omitting them returns everything, name-sorted.
  ///
  /// Throws [ApiException] on a non-2xx so callers can render a real error
  /// rather than silently showing an empty feed.
  Future<List<CatalogVenue>> list({
    double? lat,
    double? lng,
    int? radiusM,
    String? cuisine,
    String? q,
    int limit = 60,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (lat != null && lng != null) {
      params['lat'] = '$lat';
      params['lng'] = '$lng';
      if (radiusM != null) params['radius_m'] = '$radiusM';
    }
    if (cuisine != null && cuisine.isNotEmpty) params['cuisine'] = cuisine;
    // Free-text search over name/address — matched diacritic-insensitively
    // server-side (foldVN in venue_catalog.go), so "bun bo" finds "Bún Bò".
    if (q != null && q.trim().isNotEmpty) params['q'] = q.trim();

    final qs = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');

    final data = await ApiClient().get('/api/v1/venues?$qs');
    final list = (data is Map ? data['venues'] : null);
    if (list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(CatalogVenue.fromJson)
        .where((v) => v.name.isNotEmpty)
        .toList();
  }
}
