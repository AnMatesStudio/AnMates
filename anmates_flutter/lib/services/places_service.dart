import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

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
    );
  }
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

    final query =
        '''
[out:json][timeout:20];
(
  node["amenity"~"restaurant|cafe|fast_food|bar"]["name"](around:$radiusM,$lat,$lng);
  way["amenity"~"restaurant|cafe|fast_food|bar"]["name"](around:$radiusM,$lat,$lng);
);
out center 100;
''';

    final res = await http.post(
      Uri.parse('https://overpass-api.de/api/interpreter'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'data=${Uri.encodeComponent(query)}',
    );

    if (res.statusCode != 200) {
      throw Exception('Overpass API lỗi: ${res.statusCode}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final elements = data['elements'] as List<dynamic>;

    _cache = elements
        .map((e) {
          try {
            return OsmPlace.fromJson(e as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<OsmPlace>()
        .toList();

    _cacheLat = lat;
    _cacheLng = lng;
    return _cache;
  }
}
