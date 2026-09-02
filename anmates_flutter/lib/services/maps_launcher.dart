import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a venue in Google Maps from the AI venue card.
///
/// Cross-platform behaviour (per product requirement):
///   - Web      → opens Google Maps in a NEW browser tab.
///   - Mobile   → opens the Google Maps APP if installed (Android intent / iOS
///                universal link), otherwise falls back to Google Maps on web.
///
/// We use the official cross-platform Maps URL
/// (https://www.google.com/maps/search/?api=1&query=...). On Android this
/// resolves to the Google Maps app; on iOS the Google Maps app claims the
/// google.com/maps universal link, so it opens the app when installed and
/// Safari otherwise — giving the "app, else web" behaviour for free.
class MapsLauncher {
  const MapsLauncher._();

  /// Builds the best query: precise coordinates when we have them (a real pin),
  /// else the venue name + address text so Maps can resolve it by search.
  static Uri buildUri({
    required String name,
    String address = '',
    double lat = 0,
    double lng = 0,
  }) {
    final String query;
    if (lat != 0 || lng != 0) {
      // Coordinates are the most reliable; append the name so the place sheet
      // shows the venue rather than a bare dropped pin.
      query = '$lat,$lng${name.isNotEmpty ? ' ($name)' : ''}';
    } else {
      query = [name, address].where((s) => s.trim().isNotEmpty).join(', ');
    }
    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });
  }

  /// Returns true if the maps app/tab was launched.
  static Future<bool> open({
    required String name,
    String address = '',
    double lat = 0,
    double lng = 0,
  }) {
    final uri = buildUri(name: name, address: address, lat: lat, lng: lng);
    if (kIsWeb) {
      // New tab so the chat stays open behind it.
      return launchUrl(uri, webOnlyWindowName: '_blank');
    }
    // externalApplication → hand off to the Google Maps app (or browser if the
    // app isn't installed) instead of an in-app webview.
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Opens Google Maps turn-by-turn directions from [fromLat]/[fromLng] to
  /// [toLat]/[toLng]. On mobile opens the Maps app; on web opens a new tab.
  static Future<bool> openDirections({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    String travelMode = 'driving',
  }) {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'origin': '$fromLat,$fromLng',
      'destination': '$toLat,$toLng',
      'travelmode': travelMode,
    });
    if (kIsWeb) {
      return launchUrl(uri, webOnlyWindowName: '_blank');
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
