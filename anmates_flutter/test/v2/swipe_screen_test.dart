import 'package:anmates/views/v2/v2_app.dart';
import 'package:anmates/views/v2/v2_mate_mapper.dart';
import 'package:anmates/views/v2/v2_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_match_api.dart';

/// Quẹt through the real shell; only the API server is faked.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<V2State> pumpSwipe(WidgetTester tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final s = V2State()..go(V2Screen.swipe);
    await s.loadCandidates();
    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider<V2State>.value(value: s, child: const V2AppBody()),
    ));
    await tester.pump(const Duration(milliseconds: 300)); // past the cross-fade
    return s;
  }

  /// Past the card's fly-off animation and the state update after it.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(); // the ticker starts counting on this frame
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
  }

  testWidgets('the sample deck is labelled and counts through', (tester) async {
    serveMatchApi(candidates: const []);
    await pumpSwipe(tester);
    expect(find.text('Dữ liệu mẫu'), findsWidgets);
    expect(find.text('1 / 10'), findsOneWidget);
    expect(find.text('Minh Anh'), findsOneWidget);

    await tester.tap(find.text('Gửi lời mời đi ăn'));
    await settle(tester);
    expect(find.text('Hợp gu rồi!'), findsOneWidget); // Minh Anh invites back

    await tester.tap(find.text('Quẹt tiếp'));
    await tester.pump();
    expect(find.text('Hợp gu rồi!'), findsNothing);
    expect(find.text('2 / 10'), findsOneWidget);
    expect(find.text('Hoàng Nam'), findsOneWidget);
  });

  testWidgets('signed out, the sample deck says to sign in for real mates', (tester) async {
    serveMatchApi(listStatus: 401);
    await pumpSwipe(tester);

    expect(find.textContaining('Đăng nhập'), findsOneWidget);
  });

  testWidgets('dragging the card right invites, left skips; undo brings it back', (tester) async {
    final calls = serveMatchApi(candidates: [
      candidate('u1', 'Hạnh'), candidate('u2', 'Khoa'), candidate('u3', 'Linh'),
    ]);
    await pumpSwipe(tester);
    expect(find.text('1 / 3'), findsOneWidget);

    await tester.drag(find.byKey(const Key('swipe-top-card')), const Offset(260, 0));
    await settle(tester);
    expect(calls.last, contains('"target_id":"u1","liked":true'));
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.drag(find.byKey(const Key('swipe-top-card')), const Offset(-260, 0));
    await settle(tester);
    expect(calls.last, contains('"target_id":"u2","liked":false'));
    expect(find.text('Linh'), findsOneWidget);

    await tester.tap(find.byKey(const Key('swipe-undo')));
    await settle(tester);
    expect(calls.last, startsWith('POST /api/v1/swipes/undo'));
    expect(find.text('Khoa'), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);
  });

  test('card text: food keys in words, initials from first and last word', () {
    for (final (tag, want) in [('lau', 'Lẩu'), ('trang_mieng', 'Tráng miệng'), ('bun bo hue', 'Bun bo hue'), ('late_night', 'Late night')]) {
      expect(tasteLabel(tag), want, reason: tag);
    }
    expect(tasteArt('spicy'), isNull);
    expect(tasteArt('lau'), isNotNull);
    for (final (name, want) in [('Hạnh', 'H'), ('Minh Anh', 'MA'), ('Nguyễn Minh Khoa', 'NK'), ('  ', '?')]) {
      expect(initialsOf(name), want, reason: name);
    }
  });
}
