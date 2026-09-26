import 'package:anmates/views/v2/v2_data.dart';
import 'package:anmates/views/v2/v2_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_venue_api.dart';

/// Explore's state beyond loading: the category tiles, the greeting, and the
/// header asking for the location again. Real V2State/VenueCatalogService/
/// ApiClient; only the API server and the location plugin are faked.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'venue_radius_km': 200});
    GeolocatorPlatform.instance = FixedLocation(farLat, farLng);
  });

  int category(String vi) => kFeedCategories.indexWhere((c) => c.label(false) == vi);

  group('category tiles', () {
    test('filter the feed to the category and name the section after it', () async {
      // nearby: lau · ocHem: pho, bbq, oc, seafood, trang_mieng · khoaiXien: banh_mi, pho, bbq
      serveCatalogue([nearby, ocHem, khoaiXien]);
      final s = V2State();
      await s.loadVenues();

      expect(s.homeVenues.map((v) => v.name),
          ['Lẩu Mắm Đầu Hẻm', 'Ốc Hẻm 239/29A Seafood Restaurant', 'Khoai Xiên Nướng']);
      expect(s.sectionTitle, 'Quán gần bạn');

      s.setFeedCategory(category('Lẩu'));
      expect(s.homeVenues.map((v) => v.name), ['Lẩu Mắm Đầu Hẻm']);
      expect(s.sectionTitle, 'Quán lẩu gần bạn');

      s.setFeedCategory(category('Nướng'));
      expect(s.homeVenues.map((v) => v.name),
          ['Ốc Hẻm 239/29A Seafood Restaurant', 'Khoai Xiên Nướng']);

      s.setFeedCategory(category('Cà phê'));
      expect(s.homeVenues, isEmpty);

      s.setFeedCategory(category('Tất cả'));
      expect(s.homeVenues, hasLength(3));
    });
  });

  test('the greeting follows the time of day', () {
    for (final (hour, want) in [
      (4, 'Chào buổi tối'), (5, 'Chào buổi sáng'), (10, 'Chào buổi sáng'),
      (11, 'Chào buổi trưa'), (12, 'Chào buổi trưa'), (13, 'Chào buổi chiều'),
      (17, 'Chào buổi chiều'), (18, 'Chào buổi tối'), (23, 'Chào buổi tối'),
    ]) {
      expect(greetingFor(hour, en: false), want, reason: '$hour:00');
    }
  });

  group('a location that was unavailable', () {
    test('is asked for again when a radius is applied', () async {
      GeolocatorPlatform.instance = NoLocation();
      final requests = serveCatalogue([ocHem]);
      final s = V2State();
      await s.loadVenues();
      expect(requests.single, {'limit': '60'});
      expect(s.locationUnavailable, isTrue);

      // The user allows location in the browser; no reload.
      GeolocatorPlatform.instance = FixedLocation(farLat, farLng);
      await s.setRadiusKm(100);

      expect(requests.last, {'limit': '60', 'lat': '$farLat', 'lng': '$farLng', 'radius_m': '100000'});
      expect(s.locationUnavailable, isFalse);
    });

    test('is asked for again when the header opens the radius sheet', () async {
      GeolocatorPlatform.instance = NoLocation();
      final requests = serveCatalogue([ocHem]);
      final s = V2State();
      await s.loadVenues();

      GeolocatorPlatform.instance = FixedLocation(farLat, farLng);
      await s.openRadiusSheet();

      expect(s.radiusSheetOpen, isTrue);
      expect(requests.last['radius_m'], '200000');
      expect(s.locationUnavailable, isFalse);
    });

    test('still unavailable, keeps the feed and says so', () async {
      GeolocatorPlatform.instance = NoLocation();
      final requests = serveCatalogue([ocHem]);
      final s = V2State();
      await s.loadVenues();

      await s.openRadiusSheet();

      expect(s.radiusSheetOpen, isTrue);
      expect(s.locationUnavailable, isTrue);
      expect(requests.last, {'limit': '60'});
      expect(s.homeVenues, hasLength(1));
    });
  });
}
