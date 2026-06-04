import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anmates/models/ai_venue_card.dart';
import 'package:anmates/widgets/ai_venue_card.dart';

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
      expect(c.picks.first.priceLabel, '50–90k');
      expect(c.picks.first.distanceLabel, '480m');
    });

    test('returns null for non-json', () {
      expect(AiVenueCardContent.tryParse('not json'), isNull);
    });

    test('returns null when there are no picks', () {
      expect(AiVenueCardContent.tryParse('{"intro":"x","picks":[]}'), isNull);
    });
  });

  testWidgets('AiVenueCard renders picks and fires onSuggest', (tester) async {
    final content = AiVenueCardContent.tryParse(_sampleJson)!;
    AiVenuePick? tapped;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AiVenueCard(
              content: content,
              onSuggest: (p) => tapped = p,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Bún Bò Giáo Toàn'), findsOneWidget);
    expect(find.text('Cộng Cà Phê'), findsOneWidget);
    expect(find.text('Gợi ý cho Mate →'), findsNWidgets(2));
    expect(find.text('TRỢ LÝ ĂNMATES'), findsOneWidget);

    await tester.tap(find.text('Gợi ý cho Mate →').first);
    await tester.pump();
    expect(tapped, isNotNull);
    expect(tapped!.name, 'Bún Bò Giáo Toàn');
  });
}
