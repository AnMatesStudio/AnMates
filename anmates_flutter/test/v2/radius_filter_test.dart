import 'package:anmates/views/v2/v2_app.dart';
import 'package:anmates/views/v2/v2_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_venue_api.dart';

/// The Explore radius control through the real shell: the header that shows
/// and opens it, the sheet and its slider, and the empty feed's way out. Only the API server and the location plugin are faked; the device sits
/// far from every venue, 83.6 km from the nearest.
void main() {
  setUp(() {
    GeolocatorPlatform.instance = FixedLocation(farLat, farLng);
  });

  /// Explore on a design-size phone, with the feed already loaded.
  Future<V2State> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final s = V2State()..go(V2Screen.home);
    await s.loadVenues();
    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider<V2State>.value(value: s, child: const V2AppBody()),
    ));
    await tester.pump(const Duration(milliseconds: 300)); // past the cross-fade
    return s;
  }

  /// Taps [finder] after scrolling it to the top of the feed. The glass nav
  /// floats over the bottom of the screen, so a target left at the fold can be
  /// under it and the tap lands on a tab instead.
  Future<void> tapInFeed(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
  }

  /// Lets a refetch finish and the screen repaint. Not pumpAndSettle: the
  /// hero's floating art animates forever.
  Future<void> settleFeed(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('the header opens the sheet; Áp dụng refetches with the picked radius', (tester) async {
    SharedPreferences.setMockInitialValues({'venue_radius_km': 20});
    final requests = serveCatalogue([ocHem, khoaiXien]);
    await pumpHome(tester);
    expect(find.text('Bán kính tìm quán'), findsNothing);

    await tester.tap(find.text('Trong 20 km'));
    await tester.pump();
    expect(find.text('Bán kính tìm quán'), findsOneWidget);

    await tester.drag(find.byType(Slider), const Offset(600, 0)); // to the far end
    await tester.pump();
    await tester.tap(find.text('Áp dụng'));
    await settleFeed(tester);

    expect(find.text('Bán kính tìm quán'), findsNothing);
    expect(requests.last['radius_m'], '200000');
    expect(find.text('Ốc Hẻm 239/29A Seafood Restaurant'), findsWidgets);
    expect(find.text('Trong 200 km'), findsOneWidget);
  });

  testWidgets('an empty feed names the radius and offers to widen it', (tester) async {
    SharedPreferences.setMockInitialValues({'venue_radius_km': 50});
    serveCatalogue([ocHem, khoaiXien]);
    await pumpHome(tester);

    expect(find.text('Không có quán nào trong 50 km'), findsWidgets);
    await tapInFeed(tester, find.text('Mở rộng bán kính').first);
    await tester.pump();

    expect(find.text('Bán kính tìm quán'), findsOneWidget);
  });

  testWidgets('at the widest radius the empty feed points to the full list', (tester) async {
    SharedPreferences.setMockInitialValues({'venue_radius_km': 200});
    serveCatalogue([baBat]);
    final s = await pumpHome(tester);

    expect(find.text('Không có quán nào trong 200 km'), findsWidgets);
    expect(find.text('Mở rộng bán kính'), findsNothing);
    await tapInFeed(tester, find.text('Xem tất cả quán').first);
    await tester.pump();

    expect(s.screen, V2Screen.allVenues);
  });

  testWidgets('without a location the header says so; the sheet says what to do', (tester) async {
    GeolocatorPlatform.instance = NoLocation();
    SharedPreferences.setMockInitialValues({});
    serveCatalogue([ocHem]);
    await pumpHome(tester);

    await tester.tap(find.text('Chưa bật vị trí'));
    await settleFeed(tester);

    expect(find.text('Bật quyền vị trí để lọc quán theo khoảng cách'), findsOneWidget);
  });
}
