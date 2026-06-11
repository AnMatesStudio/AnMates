import 'package:flutter_test/flutter_test.dart';
import 'package:anmates/services/places_service.dart';

OsmPlace _p(
  String name,
  double lat,
  double lng, {
  String? phone,
  String? hours,
  String? address,
}) =>
    OsmPlace(
      id: name,
      name: name,
      lat: lat,
      lng: lng,
      amenity: 'restaurant',
      phone: phone,
      openingHours: hours,
      address: address,
    );

void main() {
  group('normalizeVenueName', () {
    test('lowercases, strips punctuation, collapses whitespace', () {
      expect(normalizeVenueName('Tara  Coffee!'), 'tara coffee');
      expect(normalizeVenueName('Quán Lẩu Bò — Q.1'), 'quán lẩu bò q 1');
    });
  });

  group('mergeNearbyPlaces', () {
    test('dedups same venue and fills blank fields from secondary', () {
      final tom = [_p('Tara Coffee', 10.0, 106.0, phone: '0909')];
      final osm = [_p('Tara Coffee', 10.00001, 106.00001, hours: 'Mo-Su 08:00-22:00')];

      final merged = mergeNearbyPlaces(tom, osm);

      expect(merged.length, 1);
      expect(merged.first.phone, '0909'); // primary value kept
      expect(merged.first.openingHours, 'Mo-Su 08:00-22:00'); // filled from OSM
    });

    test('keeps venues unique to each source', () {
      final merged = mergeNearbyPlaces(
        [_p('A', 10.0, 106.0)],
        [_p('B', 10.001, 106.001)],
      );
      expect(merged.length, 2);
    });

    test('same name but far apart is not merged', () {
      final merged = mergeNearbyPlaces(
        [_p('Highlands Coffee', 10.0, 106.0)],
        [_p('Highlands Coffee', 10.05, 106.05)], // ~7 km away
      );
      expect(merged.length, 2);
    });
  });
}
