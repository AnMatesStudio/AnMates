import 'api_client.dart';

/// Facts the agentic crawl extracted for a venue. Every field is optional — only
/// what the live web actually stated is filled (the agent must not invent data).
class VenueEnrichInfo {
  final String cuisine;
  final String address;
  final String description;
  final String openingHours;
  final String phone;
  final double? rating;
  final int? priceMin;
  final int? priceMax;

  const VenueEnrichInfo({
    this.cuisine = '',
    this.address = '',
    this.description = '',
    this.openingHours = '',
    this.phone = '',
    this.rating,
    this.priceMin,
    this.priceMax,
  });

  static const empty = VenueEnrichInfo();

  factory VenueEnrichInfo.fromJson(Map<String, dynamic> j) => VenueEnrichInfo(
    cuisine: (j['cuisine'] ?? '').toString(),
    address: (j['address'] ?? '').toString(),
    description: (j['description'] ?? '').toString(),
    openingHours: (j['opening_hours'] ?? '').toString(),
    phone: (j['phone'] ?? '').toString(),
    rating: _toDouble(j['rating']),
    priceMin: _toInt(j['price_min']),
    priceMax: _toInt(j['price_max']),
  );
}

/// Result of the agentic realtime crawl for one venue: LLM-verified photos of
/// *this food venue* (already wrapped as image-proxy URLs ready for
/// `Image.network`) plus the extracted facts.
class VenueEnrichment {
  final List<String> imageUrls;
  final VenueEnrichInfo info;
  final bool isFoodVenue;
  final String intro;

  const VenueEnrichment({
    required this.imageUrls,
    required this.info,
    required this.isFoodVenue,
    required this.intro,
  });

  static const empty = VenueEnrichment(
    imageUrls: [],
    info: VenueEnrichInfo.empty,
    isFoodVenue: false,
    intro: '',
  );

  bool get hasImages => imageUrls.isNotEmpty;
}

/// Calls the backend's agentic enrichment endpoint (`/api/v1/venues/enrich`),
/// which drives a headless Google crawl + LLM verification in the sidecar. Used
/// by the detail screen to get realtime, relevant photos + facts. Degrades to
/// [VenueEnrichment.empty] on any error so the caller keeps the Bing thumbnail.
class VenueEnrichService {
  Future<VenueEnrichment> enrich({
    required String name,
    String address = '',
    String city = '',
    double lat = 0,
    double lng = 0,
  }) async {
    final n = name.trim();
    if (n.length < 2) return VenueEnrichment.empty;

    final params = <String, String>{'q': n};
    if (address.trim().isNotEmpty) params['address'] = address.trim();
    if (city.trim().isNotEmpty) params['city'] = city.trim();
    if (lat != 0) params['lat'] = lat.toString();
    if (lng != 0) params['lng'] = lng.toString();
    final qs = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');

    try {
      final data = await ApiClient().get('/api/v1/venues/enrich?$qs');
      if (data is! Map) return VenueEnrichment.empty;

      final images = <String>[];
      for (final raw in (data['images'] as List? ?? const [])) {
        if (raw is Map) {
          final proxied = ApiClient.imageProxyUrl((raw['url'] ?? '').toString());
          if (proxied.isNotEmpty) images.add(proxied);
        }
      }
      final infoMap = (data['info'] as Map?)?.cast<String, dynamic>() ?? const {};
      return VenueEnrichment(
        imageUrls: images,
        info: VenueEnrichInfo.fromJson(infoMap),
        isFoodVenue: data['is_food_venue'] == true,
        intro: (data['intro'] ?? '').toString(),
      );
    } catch (_) {
      // Sidecar offline / crawl blocked → caller falls back to the Bing path.
      return VenueEnrichment.empty;
    }
  }
}

double? _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int? _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}
