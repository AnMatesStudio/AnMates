import 'package:anmates/views/v2/v2_app.dart';
import 'package:anmates/views/v2/v2_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_venue_api.dart';

/// The Explore radius control through the real shell: the pill under the feed
/// title, the sheet and its slider, the hero line, and the empty feed's way
/// out. Only the API server and the location plugin are faked; the device sits
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

  /// Lets a refetch finish and the screen repaint. Not pumpAndSettle: the
  /// hero's floating art animates forever.
  Future<void> settleFeed(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('the pill opens the sheet; Áp dụng refetches with the picked radius', (tester) async {
    SharedPreferences.setMockInitialValues({'venue_radius_km': 20});
    final requests = serveCatalogue([ocHem, khoaiXien]);
    await pumpHome(tester);
    expect(find.textContaining('· trong 20 km'), findsOneWidget); // hero line
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
    expect(find.textContaining('· trong 200 km'), findsOneWidget);
  });

  testWidgets('an empty feed names the radius and offers to widen it', (tester) async {
    SharedPreferences.setMockInitialValues({'venue_radius_km': 50});
    serveCatalogue([ocHem, khoaiXien]);
    await pumpHome(tester);

    expect(find.text('Không có quán nào trong 50 km'), findsWidgets);
    await tester.tap(find.text('Mở rộng bán kính').first);
    await tester.pump();

    expect(find.text('Bán kính tìm quán'), findsOneWidget);
  });

  testWidgets('at the widest radius the empty feed points to the full list', (tester) async {
    SharedPreferences.setMockInitialValues({'venue_radius_km': 200});
    serveCatalogue([baBat]);
    final s = await pumpHome(tester);

    expect(find.text('Không có quán nào trong 200 km'), findsWidgets);
    expect(find.text('Mở rộng bán kính'), findsNothing);
    await tester.tap(find.text('Xem tất cả quán').first);
    await tester.pump();

    expect(s.screen, V2Screen.allVenues);
  });

  testWidgets('without a location the sheet says the radius needs one', (tester) async {
    GeolocatorPlatform.instance = NoLocation();
    SharedPreferences.setMockInitialValues({});
    serveCatalogue([ocHem]);
    final s = await pumpHome(tester);

    s.setRadiusSheetOpen(true);
    await tester.pump();

    expect(find.text('Bật quyền vị trí để lọc quán theo khoảng cách'), findsOneWidget);
  });
}
