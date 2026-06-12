import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

import 'api_client.dart';

class OsmPlace {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String amenity;
  final String? cuisine;
  final String? address;
  final String? phone;
  final String? openingHours;
  // Ambiance signals consumed by the Discover vibe filters. OSM tags these
  // sparsely, so the filters also fall back to name/cuisine heuristics — see
  // DiscoverView._matchesVibe.
  final String? airConditioning; // OSM air_conditioning = yes/no
  final String? outdoorSeating; // OSM outdoor_seating = yes/no/only
  final String? stars; // OSM stars (upscale signal)

  const OsmPlace({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.amenity,
    this.cuisine,
    this.address,
    this.phone,
    this.openingHours,
    this.airConditioning,
    this.outdoorSeating,
    this.stars,
  });

  String get emoji {
    final c = (cuisine ?? '').toLowerCase();
    if (c.contains('viet') || c.contains('pho') || c.contains('bun'))
      return '🍜';
    if (c.contains('coffee') || c.contains('tea') || amenity == 'cafe')
      return '☕';
    if (c.contains('japanese') || c.contains('sushi') || c.contains('ramen'))
      return '🍣';
    if (c.contains('pizza') || c.contains('italian')) return '🍕';
    if (c.contains('korean')) return '🥘';
    if (c.contains('chinese') ||
        c.contains('dim_sum') ||
        c.contains('cantonese'))
      return '🥡';
    if (c.contains('thai')) return '🌶️';
    if (c.contains('seafood') || c.contains('fish')) return '🦐';
    if (c.contains('burger') ||
        c.contains('american') ||
        amenity == 'fast_food')
      return '🍔';
    if (amenity == 'bar') return '🍺';
    return '🍽️';
  }

  List<String> get tags {
    final result = <String>[];
    if (cuisine != null) {
      result.add(cuisine!.split(';').first.trim().replaceAll('_', ' '));
    }
    switch (amenity) {
      case 'cafe':
        result.add('Cà phê');
      case 'bar':
        result.add('Bar');
      case 'fast_food':
        result.add('Fast food');
      case 'restaurant':
        if (result.isEmpty) result.add('Nhà hàng');
    }
    return result.isEmpty ? ['Ẩm thực'] : result;
  }

  double distanceMeters(double fromLat, double fromLng) {
    const r = 6371000.0;
    final dLat = (lat - fromLat) * pi / 180;
    final dLng = (lng - fromLng) * pi / 180;
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(fromLat * pi / 180) *
            cos(lat * pi / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return 2 * r * asin(sqrt(a));
  }

  String distanceLabel(double fromLat, double fromLng) {
    final d = distanceMeters(fromLat, fromLng);
    return d < 1000 ? '${d.round()}m' : '${(d / 1000).toStringAsFixed(1)}km';
  }

  /// Returns a copy of this place with any blank field filled in from [other].
  /// Used when the same venue is found in two sources (e.g. TomTom has the
  /// phone, OSM has the opening hours) — see [mergeNearbyPlaces].
  OsmPlace mergeFill(OsmPlace other) {
    bool blank(String? s) => s == null || s.trim().isEmpty;
    return OsmPlace(
      id: id,
      name: name,
      lat: lat != 0 ? lat : other.lat,
      lng: lng != 0 ? lng : other.lng,
      amenity: (amenity.isNotEmpty && amenity != 'restaurant')
          ? amenity
          : (other.amenity.isNotEmpty ? other.amenity : amenity),
      cuisine: blank(cuisine) ? other.cuisine : cuisine,
      address: blank(address) ? other.address : address,
      phone: blank(phone) ? other.phone : phone,
      openingHours: blank(openingHours) ? other.openingHours : openingHours,
      airConditioning:
          blank(airConditioning) ? other.airConditioning : airConditioning,
      outdoorSeating:
          blank(outdoorSeating) ? other.outdoorSeating : outdoorSeating,
      stars: blank(stars) ? other.stars : stars,
    );
  }

  /// Builds a place from the backend `/venues/nearby` (TomTom) normalized shape:
  /// `{id,name,lat,lng,amenity,cuisine,address,phone,opening_hours}`.
  factory OsmPlace.fromBackend(Map<String, dynamic> json) {
    String? str(String k) {
      final v = json[k];
      return (v is String && v.trim().isNotEmpty) ? v : null;
    }

    return OsmPlace(
      id: (json['id'] ?? '').toString(),
      name: str('name') ?? 'Không tên',
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      amenity: str('amenity') ?? 'restaurant',
      cuisine: str('cuisine'),
      address: str('address'),
      phone: str('phone'),
      openingHours: str('opening_hours'),
    );
  }

  factory OsmPlace.fromJson(Map<String, dynamic> json) {
    final tags = (json['tags'] as Map<String, dynamic>? ?? {});
    final type = json['type'] as String;

    double lat, lng;
    if (type == 'node') {
      lat = (json['lat'] as num).toDouble();
      lng = (json['lon'] as num).toDouble();
    } else {
      final center = json['center'] as Map<String, dynamic>;
      lat = (center['lat'] as num).toDouble();
      lng = (center['lon'] as num).toDouble();
    }

    final parts = <String>[];
    final houseNum = tags['addr:housenumber'] as String?;
    final street = tags['addr:street'] as String?;
    if (houseNum != null) parts.add(houseNum);
    if (street != null) parts.add(street);
    final addr = parts.isNotEmpty
        ? parts.join(' ')
        : tags['addr:full'] as String?;

    return OsmPlace(
      id: '${type}_${json['id']}',
      name: (tags['name:vi'] ?? tags['name'] ?? 'Không tên') as String,
      lat: lat,
      lng: lng,
      amenity: (tags['amenity'] ?? '') as String,
      cuisine: tags['cuisine'] as String?,
      address: addr,
      phone: (tags['phone'] ?? tags['contact:phone']) as String?,
      openingHours: tags['opening_hours'] as String?,
      airConditioning: tags['air_conditioning'] as String?,
      outdoorSeating: tags['outdoor_seating'] as String?,
      stars: tags['stars']?.toString(),
    );
  }
}

/// Normalizes a venue name for cross-source duplicate detection: lowercase,
/// punctuation → space, whitespace collapsed. Keeps Unicode letters (so VN
/// names compare correctly).
String normalizeVenueName(String s) {
  final lowered = s.toLowerCase();
  final buf = StringBuffer();
  for (final r in lowered.runes) {
    final c = String.fromCharCode(r);
    // Keep letters/digits (incl. VN diacritics), turn everything else to space.
    if (RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(c)) {
      buf.write(c);
    } else {
      buf.write(' ');
    }
  }
  return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Merges two nearby-venue lists, treating entries with the same normalized name
/// within [dupRadiusM] metres as the same venue. [primary] wins on conflicts and
/// keeps its position; the matching [secondary] entry only fills in blank fields.
/// Secondary venues with no match are appended — so the combined list is fuller
/// (e.g. TomTom's fresh close-in POIs + OSM's wider coverage) without duplicates.
List<OsmPlace> mergeNearbyPlaces(
  List<OsmPlace> primary,
  List<OsmPlace> secondary, {
  double dupRadiusM = 250,
}) {
  final out = List<OsmPlace>.from(primary);
  final keys = out.map((p) => normalizeVenueName(p.name)).toList();

  for (final s in secondary) {
    final sk = normalizeVenueName(s.name);
    var dupIdx = -1;
    if (sk.isNotEmpty) {
      for (var i = 0; i < out.length; i++) {
        if (keys[i] == sk &&
            s.lat != 0 &&
            out[i].lat != 0 &&
            out[i].distanceMeters(s.lat, s.lng) < dupRadiusM) {
          dupIdx = i;
          break;
        }
      }
    }
    if (dupIdx >= 0) {
      out[dupIdx] = out[dupIdx].mergeFill(s);
    } else {
      out.add(s);
      keys.add(sk);
    }
  }
  return out;
}

class PlacesService {
  static final PlacesService _instance = PlacesService._();
  PlacesService._();
  factory PlacesService() => _instance;

  List<OsmPlace> _cache = [];
  double? _cacheLat, _cacheLng;

  void clearCache() {
    _cache = [];
    _cacheLat = null;
    _cacheLng = null;
  }

  /// Tries the backend TomTom proxy. Returns null on any failure (disabled /
  /// offline / error) so the caller falls back to Overpass.
  Future<List<OsmPlace>?> _getNearbyFromApi(
    double lat,
    double lng,
    int radiusM,
  ) async {
    try {
      final data = await ApiClient().get(
        '/api/v1/venues/nearby?lat=$lat&lng=$lng&radius=$radiusM',
      );
      final list = (data is Map ? data['venues'] : null);
      if (list is! List) return null;
      return list
          .whereType<Map<String, dynamic>>()
          .map(OsmPlace.fromBackend)
          .where((p) => p.lat != 0 && p.lng != 0)
          .toList();
    } catch (_) {
      return null; // route absent (no key) / network / parse → Overpass fallback
    }
  }

  static Future<Map<String, dynamic>> httpGet(String url) async {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<OsmPlace>> getNearby(
    double lat,
    double lng, {
    int radiusM = 1500,
  }) async {
    if (_cache.isNotEmpty &&
        _cacheLat != null &&
        (lat - _cacheLat!).abs() < 0.005 &&
        (lng - _cacheLng!).abs() < 0.005) {
      return _cache;
    }

    // Fetch both sources concurrently and merge them (Feature C): the backend
    // TomTom proxy (fresher VN data, but close-in and key-gated → null when
    // disabled) and Overpass/OSM (wider 5km coverage). Combining them yields a
    // fuller, deduped list where each venue carries whichever source has the
    // richer fields (e.g. TomTom phone + OSM opening_hours).
    final results = await Future.wait([
      _getNearbyFromApi(lat, lng, radiusM),
      _getFromOverpass(lat, lng, radiusM),
    ]);
    final tomtom = results[0] ?? const <OsmPlace>[];
    final osm = results[1] ?? const <OsmPlace>[];

    final List<OsmPlace> merged;
    if (tomtom.isEmpty) {
      merged = osm;
    } else if (osm.isEmpty) {
      merged = tomtom;
    } else {
      merged = mergeNearbyPlaces(tomtom, osm);
    }

    // Only a real failure (Overpass errored AND nothing else returned) surfaces
    // as an error; an empty-but-successful fetch just shows "no venues".
    if (merged.isEmpty && results[1] == null) {
      throw Exception('Không tải được quán quanh đây');
    }

    _cache = merged;
    _cacheLat = lat;
    _cacheLng = lng;
    return _cache;
  }

  /// OSM/Overpass nearby fetch. Returns null on any network/parse error so the
  /// caller can decide whether to surface an error (only when no source had data).
  Future<List<OsmPlace>?> _getFromOverpass(
    double lat,
    double lng,
    int radiusM,
  ) async {
    final query =
        '''
[out:json][timeout:20];
(
  node["amenity"~"restaurant|cafe|fast_food|bar"]["name"](around:$radiusM,$lat,$lng);
  way["amenity"~"restaurant|cafe|fast_food|bar"]["name"](around:$radiusM,$lat,$lng);
);
out center 100;
''';

    try {
      final res = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'data=${Uri.encodeComponent(query)}',
      );
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final elements = data['elements'] as List<dynamic>;
      return elements
          .map((e) {
            try {
              return OsmPlace.fromJson(e as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<OsmPlace>()
          .toList();
    } catch (_) {
      return null;
    }
  }
}
