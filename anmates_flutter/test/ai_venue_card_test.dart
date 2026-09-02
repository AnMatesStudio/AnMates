import 'package:flutter_test/flutter_test.dart';
import 'package:anmates/models/ai_venue_card.dart';

const _sampleJson = '''
{"intro":"2 đứa hợp gu rồi nè!","midpoint":{"lat":10.778,"lng":106.695},
 "picks":[
   {"restaurant_id":"r1","name":"Bún Bò Giáo Toàn","rating":4.6,"price_min":50000,"price_max":90000,"lat":10.78,"lng":106.68,"distance_m":480,"reason":"Yên tĩnh"},
   {"restaurant_id":"r2","name":"Cộng Cà Phê","rating":4.3,"price_min":45000,"price_max":90000,"lat":10.77,"lng":106.70,"distance_m":650,"reason":"Chill"}
 ]}''';

void main() {
  group('AiVenueCardContent.tryParse', () {
    test('parses a valid ai_venue_card payload', () {
      final c = AiVenueCardContent.tryParse(_sampleJson);
      expect(c, isNotNull);
      expect(c!.picks, hasLength(2));
      expect(c.picks.first.name, 'Bún Bò Giáo Toàn');
      expect(c.picks.first.priceLabel, '50k–90k');
      expect(c.picks.first.distanceLabel, '480m');
    });

    test('distanceLabel is empty for an un-geocoded pick (ISSUE-9)', () {
      // lat/lng=0 means the venue couldn't be placed → no misleading "0m".
      const json = '{"intro":"x","midpoint":{"lat":10.78,"lng":106.7},'
          '"picks":[{"restaurant_id":"","name":"Quán Mơ Hồ","lat":0,"lng":0,"distance_m":0,"reason":"r"}]}';
      final c = AiVenueCardContent.tryParse(json);
      expect(c, isNotNull);
      expect(c!.picks.first.distanceLabel, '');
    });

    test('returns null for non-json', () {
      expect(AiVenueCardContent.tryParse('not json'), isNull);
    });

    test('returns null when there are no picks', () {
      expect(AiVenueCardContent.tryParse('{"intro":"x","picks":[]}'), isNull);
    });
  });
}
