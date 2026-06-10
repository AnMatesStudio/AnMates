import 'package:flutter_test/flutter_test.dart';
import 'package:anmates/services/nearby_venue_service.dart';

void main() {
  test('NearbyVenue.fromJson parses fields + derives label/emoji', () {
    final v = NearbyVenue.fromJson({
      'name': 'Quán Gần',
      'lat': 10.77,
      'lng': 106.70,
      'distance_m': 420,
      'rating': 4.3,
      'open_now': true,
      'address': '12 Lê Lợi',
      'tags': ['cafe'],
    });
    expect(v.name, 'Quán Gần');
    expect(v.distanceM, 420);
    expect(v.distanceLabel, '420m');
    expect(v.rating, 4.3);
    expect(v.openNow, true);
    expect(v.emoji, '☕');
  });

  test('distanceLabel switches to km past 1000m', () {
    final v = NearbyVenue.fromJson(
        {'name': 'X', 'lat': 1, 'lng': 1, 'distance_m': 1200});
    expect(v.distanceLabel, '1.2km');
  });
}
