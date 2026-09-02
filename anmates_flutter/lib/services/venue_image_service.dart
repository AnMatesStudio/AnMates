import 'api_client.dart';

/// How many web-crawled photos the backend found for a venue. The detail-screen
/// hero gallery uses this to decide how many swipeable pages to render (each page
/// is `ApiClient.imageUrl(query, index: i)`). Falls back to 0 on any error so the
/// gallery degrades to a single image / placeholder.
class VenueImageService {
  Future<int> count(String query, {double? lat, double? lng}) async {
    final q = query.trim();
    if (q.length < 2) return 0;
    try {
      var path = '/api/v1/venues/images?q=${Uri.encodeQueryComponent(q)}';
      // Match the Serve call's cache key so the count and the per-index photos
      // come from the same (Foursquare-aware) resolution.
      if (lat != null && lng != null && (lat != 0 || lng != 0)) {
        path += '&lat=$lat&lng=$lng';
      }
      final data = await ApiClient().get(path);
      if (data is Map && data['count'] is int) return data['count'] as int;
    } catch (_) {
      // Sidecar blocked / offline — caller shows the single primary image.
    }
    return 0;
  }
}
