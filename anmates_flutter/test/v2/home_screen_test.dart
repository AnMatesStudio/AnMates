import 'package:anmates/views/v2/v2_app.dart';
import 'package:anmates/views/v2/v2_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_venue_api.dart';

/// Explore through the real shell: the category tiles and the venue cards.
/// Only the API server and the location plugin are faked; the radius is 200 km
/// so the whole fixture catalogue is in range.
void main() {
  setUp(() {
    GeolocatorPlatform.instance = FixedLocation(farLat, farLng);
    SharedPreferences.setMockInitialValues({'venue_radius_km': 200});
  });

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

  Future<void> tapInFeed(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();
  }

  testWidgets('a category tile narrows the feed and retitles it', (tester) async {
    // nearby: lau · ocHem: pho, bbq, oc, seafood, trang_mieng · khoaiXien: banh_mi, pho, bbq
    serveCatalogue([nearby, ocHem, khoaiXien]);
    await pumpHome(tester);
    expect(find.text('Quán gần bạn'), findsOneWidget);
    expect(find.text('Khoai Xiên Nướng'), findsWidgets);

    await tapInFeed(tester, find.text('Lẩu'));

    expect(find.text('Quán lẩu gần bạn'), findsOneWidget);
    expect(find.text('Lẩu Mắm Đầu Hẻm'), findsWidgets);
    expect(find.text('Khoai Xiên Nướng'), findsNothing);
  });

  testWidgets('a category with nothing in range offers every dish instead', (tester) async {
    serveCatalogue([nearby, ocHem, khoaiXien]);
    await pumpHome(tester);

    // Sixth tile: past the screen edge until the row scrolls to it.
    await tapInFeed(tester, find.text('Cà phê', skipOffstage: false));
    expect(find.text('Không có quán cà phê nào trong 200 km'), findsWidgets);

    await tapInFeed(tester, find.text('Xem tất cả món').first);
    expect(find.text('Quán gần bạn'), findsOneWidget);
    expect(find.text('Khoai Xiên Nướng'), findsWidgets);
  });

  testWidgets('a venue card says where it is and how far', (tester) async {
    serveCatalogue([ocHem]);
    await pumpHome(tester);

    expect(find.text('Ốc Hẻm 239/29A Seafood Restaurant'), findsWidgets);
    expect(find.text('Quận 6'), findsWidgets);
    expect(find.text('83,6 km'), findsWidgets);
  });
}
