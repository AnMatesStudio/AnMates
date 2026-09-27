import 'package:anmates/services/venue_catalog_service.dart';
import 'package:anmates/views/v2/v2_app.dart';
import 'package:anmates/views/v2/v2_data.dart';
import 'package:anmates/views/v2/v2_kit.dart';
import 'package:anmates/views/v2/v2_state.dart';
import 'package:anmates/views/v2/v2_venue_mapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_match_api.dart';

/// The Explore tune icon opens a filter for venues (district, spend per
/// person, dish, radius); the mates filter moved to Quẹt, next to the deck it
/// narrows.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'venue_radius_km': 200}));

  CatalogVenue row(String name, {String? district, int? min, int? max, List<String> tags = const []}) =>
      CatalogVenue.fromJson({
        'id': name,
        'name': name,
        'district': district,
        'lat': 10.77,
        'lng': 106.70,
        'cuisine_tags': tags,
        'price_min': min,
        'price_max': max,
        'source': 'pipeline',
        'distance_m': 1500,
        'want_count': 0,
      });

  // Q1 cheap hotpot · Q3 mid · Q1 pricey · no district, no price.
  final cheap = row('Rẻ', district: 'Q1', min: 30000, max: 45000, tags: ['lau']);
  final mid = row('Vừa', district: 'Q3', min: 60000, max: 120000, tags: ['bbq']);
  final pricey = row('Sang', district: 'Q1', min: 200000, max: 400000, tags: ['lau']);
  final unknown = row('Chưa rõ giá');

  V2State seeded() => V2State()..seedVenues([cheap, mid, pricey, unknown], radiusKm: 200);
  List<String> names(V2State s) => s.homeVenues.map((v) => v.name).toList();

  group('venueInPriceTier', () {
    test('matches a venue whose price band touches the tier', () {
      // Tiers: <50k · 50–150k · 150–350k · >350k
      bool inTiers(int? min, int? max, List<int> want) {
        final got = [for (var t = 0; t < kPrices.length; t++) if (venueInPriceTier(min, max, t)) t];
        expect(got, want, reason: 'price $min–$max');
        return true;
      }

      inTiers(30000, 45000, [0]);
      inTiers(60000, 150000, [1, 2]); // 150k is on both labels
      inTiers(8000, 620000, [0, 1, 2, 3]); // a menu from snacks to set menus
      inTiers(450000, 900000, [3]);
      // Only "từ 45k": the one price we know.
      inTiers(45000, null, [0]);
      inTiers(null, 90000, [1]);
      inTiers(null, null, []);
    });
  });

  group('the venue filter', () {
    test('starts empty and counts every venue in the feed', () {
      final s = seeded();
      expect(names(s), ['Rẻ', 'Vừa', 'Sang', 'Chưa rõ giá']);
      expect(s.venueFilterCount, 0);
      expect(s.venueFilterCta, 'Xem 4 quán phù hợp');
    });

    test('spend chips add up, and hide venues with no price on file', () {
      final s = seeded();
      s.toggleVenuePrice(0);
      expect(names(s), ['Rẻ']);
      s.toggleVenuePrice(3);
      expect(names(s), ['Rẻ', 'Sang']);
      expect(s.venueFilterCount, 2);
      expect(s.venueFilterCta, 'Xem 2 quán phù hợp');

      s.toggleVenuePrice(0);
      s.toggleVenuePrice(3);
      expect(names(s), hasLength(4));
    });

    test('district chips are by name and narrow the feed', () {
      final s = seeded();
      // No "Chưa rõ" chip: a venue without a district is no place to go.
      expect(s.venueAreaNames, ['Quận 1', 'Quận 3']);

      s.toggleVenueArea('Quận 1');
      expect(names(s), ['Rẻ', 'Sang']);
      s.toggleVenueArea('Quận 3');
      expect(names(s), ['Rẻ', 'Vừa', 'Sang']);
      expect(s.venueAreas, {'Quận 1', 'Quận 3'});
    });

    test('a picked district stays listed when a new radius drops it', () {
      final s = seeded()..toggleVenueArea('Quận 3');
      s.seedVenues([cheap], radiusKm: 5);

      expect(s.venueAreaNames, ['Quận 1', 'Quận 3']);
      expect(names(s), isEmpty);
    });

    test('works with the dish tile, and reset clears all of it', () {
      final s = seeded()
        ..toggleVenueArea('Quận 1')
        ..setFeedCategory(kFeedCategories.indexWhere((c) => c.label(false) == 'Lẩu'))
        ..toggleVenuePrice(0);
      expect(names(s), ['Rẻ']);

      s.resetVenueFilters();
      expect(names(s), hasLength(4));
      expect(s.feedCategory, 0);
      expect(s.venueFilterCount, 0);
    });

    test('never touches the mates deck', () {
      final s = seeded()
        ..toggleVenueArea('Quận 1')
        ..toggleVenuePrice(0);
      expect(s.areas, isEmpty);
      expect(s.filterCta, 'Xem 0 mates phù hợp');
    });
  });

  group('screens', () {
    Future<V2State> pump(WidgetTester tester, V2State s) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider<V2State>.value(value: s, child: const V2AppBody()),
      ));
      await tester.pump(const Duration(milliseconds: 300)); // past the cross-fade
      return s;
    }

    Future<void> tap(WidgetTester tester, Finder f) async {
      await tester.ensureVisible(f);
      await tester.pump();
      await tester.tap(f);
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets("Explore's tune icon opens the venue filter, not the mates one", (tester) async {
      final s = await pump(tester, seeded()..go(V2Screen.home));

      // On screen as the feed opens; ensureVisible would park it under the VI/EN toggle.
      await tester.tap(find.byKey(const Key('home-filter')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(s.screen, V2Screen.venueFilter);
      expect(find.text('Lọc quán'), findsOneWidget);
      expect(find.text('Match filter'), findsNothing);
      expect(find.text('Vibe sống'), findsNothing);
      expect(find.text('Khu vực / Quận'), findsOneWidget);
      expect(find.text('Khoảng giá / người'), findsOneWidget);
      expect(find.text('Xem 4 quán phù hợp'), findsOneWidget);
    });

    testWidgets('picking chips updates the count; the button goes back to the feed', (tester) async {
      final s = await pump(tester, seeded()..go(V2Screen.venueFilter));

      await tap(tester, find.text('Quận 3'));
      expect(find.text('Xem 1 quán phù hợp'), findsOneWidget);

      await tap(tester, find.text('Xem 1 quán phù hợp'));
      expect(s.screen, V2Screen.home);
      expect(find.text('Vừa'), findsWidgets);
      expect(find.text('Rẻ'), findsNothing);
      // The tune icon shows how many filters are on.
      expect(find.descendant(of: find.byKey(const Key('home-filter')), matching: find.text('1')),
          findsOneWidget);
    });

    testWidgets('the back button returns to Explore', (tester) async {
      final s = await pump(tester, seeded()..go(V2Screen.venueFilter));
      await tap(tester, find.byType(V2BackButton));
      expect(s.screen, V2Screen.home);
    });

    testWidgets('an empty filtered feed offers to clear the filters', (tester) async {
      final s = await pump(tester, seeded()
        ..toggleVenueArea('Quận 3')
        ..toggleVenuePrice(3)
        ..go(V2Screen.home));

      expect(find.text('Không có quán nào khớp bộ lọc'), findsWidgets);
      await tap(tester, find.text('Xoá bộ lọc').first);
      expect(s.venueFilterCount, 0);
      expect(find.text('Rẻ'), findsWidgets);
    });

    testWidgets('Quẹt has its own filter button, opening the mates filter', (tester) async {
      serveMatchApi(candidates: const []);
      final s = V2State()..go(V2Screen.swipe);
      await s.loadCandidates();
      await pump(tester, s);

      await tap(tester, find.byKey(const Key('swipe-filter')));

      expect(s.screen, V2Screen.matchFilter);
      expect(find.text('Match filter'), findsOneWidget);
      expect(find.text('Vibe sống'), findsOneWidget);

      // Its back button returns to the deck.
      await tap(tester, find.byType(V2BackButton));
      expect(s.screen, V2Screen.swipe);
    });
  });
}
