import 'dart:async';

import 'package:anmates/views/v2/v2_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_venue_api.dart';

/// [V2State]'s home feed and the radius that bounds it, through the real
/// VenueCatalogService and ApiClient — only the API server and the location
/// plugin are faked (support/fake_venue_api.dart). The device sits far from
/// every venue, 83.6 km from the nearest.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GeolocatorPlatform.instance = FixedLocation(farLat, farLng);
  });

  group('the feed', () {
    test('holds only the venues inside the radius, from one request', () async {
      final requests = serveCatalogue([nearby, ocHem, khoaiXien]);
      final s = V2State();

      await s.loadVenues();

      expect(s.venues.map((v) => v.name), ['Lẩu Mắm Đầu Hẻm']);
      expect(requests, hasLength(1));
    });

    test('stays empty when nothing is inside the radius — nothing from further out', () async {
      SharedPreferences.setMockInitialValues({'venue_radius_km': 50});
      final requests = serveCatalogue([ocHem, khoaiXien]);
      final s = V2State();

      await s.loadVenues();

      expect(s.venues, isEmpty);
      expect(s.venuesError, 'empty');
      expect(s.feedRadiusKm, 50);
      expect(requests.single['radius_m'], '50000');
    });

    test('without a location is the whole catalogue, with no radius', () async {
      GeolocatorPlatform.instance = NoLocation();
      final requests = serveCatalogue([ocHem, khoaiXien]);
      final s = V2State();

      await s.loadVenues();

      expect(s.venues, hasLength(2));
      expect(s.feedRadiusKm, isNull);
      expect(s.locationUnavailable, isTrue);
      expect(requests.single, {'limit': '60'});
    });
  });

  group('picking a radius', () {
    test('widening it refetches and shows what it now reaches', () async {
      SharedPreferences.setMockInitialValues({'venue_radius_km': 20});
      final requests = serveCatalogue([ocHem, khoaiXien, baBat]);
      final s = V2State();
      await s.loadVenues();
      expect(s.venues, isEmpty);

      await s.setRadiusKm(100);

      expect(requests.last['radius_m'], '100000');
      expect(s.venues.map((v) => v.name),
          ['Ốc Hẻm 239/29A Seafood Restaurant', 'Khoai Xiên Nướng']);
      expect(s.venuesError, isNull);
      expect(s.feedRadiusKm, 100);
    });

    test('is remembered across restarts', () async {
      final requests = serveCatalogue([ocHem]);
      await V2State().setRadiusKm(35);

      final next = V2State();
      await next.loadVenues();

      expect(next.radiusKm, 35);
      expect(requests.last['radius_m'], '35000');
    });

    test('is kept to 5–200 km in 5 km steps', () async {
      serveCatalogue([ocHem]);
      final s = V2State();

      for (final (picked, kept) in [(1, 5), (37, 35), (38, 40), (500, 200)]) {
        await s.setRadiusKm(picked);
        expect(s.radiusKm, kept, reason: 'picked $picked km');
      }
    });

    test('a saved radius outside 5–200 km is kept inside it too', () async {
      SharedPreferences.setMockInitialValues({'venue_radius_km': 250});
      final requests = serveCatalogue([ocHem]);
      final s = V2State();

      await s.loadVenues();

      expect(requests.single['radius_m'], '200000');
    });

    test('picked while the previous load is still in flight, it wins', () async {
      SharedPreferences.setMockInitialValues({'venue_radius_km': 20});
      final slow = Completer<void>();
      final requests = serveCatalogue([ocHem, khoaiXien], hold: {'20000': slow.future});
      final s = V2State();

      final first = s.loadVenues();
      while (requests.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      await s.setRadiusKm(100);
      slow.complete(); // the 20 km answer (empty) lands last
      await first;

      expect(s.venues.map((v) => v.name),
          ['Ốc Hẻm 239/29A Seafood Restaurant', 'Khoai Xiên Nướng']);
      expect(s.feedRadiusKm, 100);
      expect(s.venuesLoading, isFalse);
    });
  });
}
