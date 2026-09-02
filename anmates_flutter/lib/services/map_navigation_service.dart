import 'package:flutter/foundation.dart';
import 'places_service.dart';

/// A navigation request to fly the in-app map to a specific venue and show
/// it as the selected pin. Consumed once by MapView; cleared after use.
class MapNavigationRequest {
  final OsmPlace venue;
  const MapNavigationRequest(this.venue);
}

/// Singleton that bridges VenueDetailView (or any screen) with the Bản đồ
/// tab. Call [navigateTo] to request a map fly-to; MainTabView listens and
/// switches to the map tab; MapView listens and flies the camera.
class MapNavigationService {
  MapNavigationService._();
  static final MapNavigationService instance = MapNavigationService._();

  final ValueNotifier<MapNavigationRequest?> pending = ValueNotifier(null);

  void navigateTo(OsmPlace venue) =>
      pending.value = MapNavigationRequest(venue);

  void consume() => pending.value = null;
}
