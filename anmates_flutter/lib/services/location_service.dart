import 'package:geolocator/geolocator.dart';
import 'api_client.dart';

/// Pushes the user's last-known coarse location to the backend so the AI
/// Concierge can compute the meetup midpoint (see ai-concierge-chat-spec §9).
/// Coarse accuracy by design — we never share a precise position.
class LocationService {
  static final LocationService _instance = LocationService._();
  factory LocationService() => _instance;
  LocationService._();

  final _api = ApiClient();

  /// Best-effort: pushes current location if permission is available.
  /// Returns false (silently) when location is off/denied — never throws.
  Future<bool> pushCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return false;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
      await _api.put(
        '/api/v1/me/location',
        body: {'lat': pos.latitude, 'lng': pos.longitude},
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
