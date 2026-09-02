import 'api_client.dart';

/// One Goong Place AutoComplete suggestion (a venue name OR an address).
class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  const PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> j) => PlacePrediction(
        placeId: (j['place_id'] as String?) ?? '',
        description: (j['description'] as String?) ?? '',
        mainText: (j['main_text'] as String?) ?? '',
        secondaryText: (j['secondary_text'] as String?) ?? '',
      );

  String get title => mainText.isNotEmpty ? mainText : description;
  String get subtitle =>
      secondaryText.isNotEmpty ? secondaryText : (mainText.isNotEmpty ? description : '');
}

/// A place resolved via Place Detail — has coordinates so the map can fly to it.
class PlaceLocation {
  final String placeId;
  final String name;
  final String address;
  final double lat;
  final double lng;

  const PlaceLocation({
    required this.placeId,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
  });

  factory PlaceLocation.fromJson(Map<String, dynamic> j) => PlaceLocation(
        placeId: (j['place_id'] as String?) ?? '',
        name: (j['name'] as String?) ?? '',
        address: (j['address'] as String?) ?? '',
        lat: (j['lat'] as num?)?.toDouble() ?? 0.0,
        lng: (j['lng'] as num?)?.toDouble() ?? 0.0,
      );

  bool get hasCoords => lat != 0 || lng != 0;
}

/// Backend proxy for the map search bar. The server holds the Goong REST key;
/// the client only ever holds the Maptiles key. All calls degrade to empty/null
/// (never throw) so a transient miss just shows no results.
class PlacesSearchService {
  final _api = ApiClient();

  /// Autocomplete predictions for [query], biased toward [lat]/[lng] (map center).
  Future<List<PlacePrediction>> autocomplete(
    String query, {
    double? lat,
    double? lng,
  }) async {
    final q = query.trim();
    if (q.runes.length < 2) return [];
    final sb =
        StringBuffer('/api/v1/places/autocomplete?q=${Uri.encodeQueryComponent(q)}');
    if (lat != null && lng != null && (lat != 0 || lng != 0)) {
      sb.write('&lat=$lat&lng=$lng');
    }
    try {
      final data = await _api.get(sb.toString());
      final list = (data?['predictions'] as List?) ?? const [];
      return list
          .map((e) => PlacePrediction.fromJson(e as Map<String, dynamic>))
          .where((p) => p.placeId.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Resolves a prediction to coordinates. Null on any miss.
  Future<PlaceLocation?> detail(String placeId) async {
    if (placeId.isEmpty) return null;
    try {
      final data = await _api
          .get('/api/v1/places/detail?place_id=${Uri.encodeQueryComponent(placeId)}');
      final p = data?['place'];
      if (p == null) return null;
      return PlaceLocation.fromJson(p as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
