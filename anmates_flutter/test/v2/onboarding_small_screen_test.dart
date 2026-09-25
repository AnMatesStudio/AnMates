import 'package:anmates/views/v2/v2_app.dart';
import 'package:anmates/views/v2/v2_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Every v2 screen is a port of a 402 × 874 canvas frame. An iPhone SE is
/// 375 × 667 — a quarter shorter. Nothing is scaled to fit any more (see
/// [DesignFrame]): the screens scroll, and the bottom-pinned CTAs must still
/// land on screen.
///
/// A RenderFlex that overflows reports through the binding, so these fail on
/// their own if a screen stops fitting; the geometry assertions cover the case
/// where content is merely pushed out of view rather than overflowing.
void main() {
  const iPhoneSE = Size(375, 667);

  Future<V2State> pumpAt(
    WidgetTester tester,
    Size size, {
    int step = 0,
    V2Screen? screen,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final state = V2State();
    for (var i = 0; i < step; i++) {
      state.nextStep();
    }
    if (screen != null) state.go(screen);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<V2State>.value(
          value: state,
          child: const V2AppBody(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return state;
  }

  /// Paint bounds in screen coordinates — [WidgetTester.getRect] resolves the
  /// frame's transform, so this is what the viewer actually sees.
  bool isOnScreen(WidgetTester tester, Finder finder, Size screen) {
    final r = tester.getRect(finder);
    return r.top >= 0 &&
        r.left >= 0 &&
        r.bottom <= screen.height &&
        r.right <= screen.width;
  }

  group('onboarding', () {
    testWidgets('taste step keeps its CTA on screen at iPhone SE size',
        (tester) async {
      await pumpAt(tester, iPhoneSE, step: 4);

      final cta = find.text('Vào Ăn Mates');
      expect(cta, findsOneWidget);
      expect(
        isOnScreen(tester, cta, iPhoneSE),
        isTrue,
        reason: 'the CTA must not be pushed below the fold on a short screen',
      );
    });

    testWidgets('budget step keeps its CTA on screen at iPhone SE size',
        (tester) async {
      await pumpAt(tester, iPhoneSE, step: 3);

      final cta = find.text('Tiếp tục');
      expect(cta, findsOneWidget);
      expect(isOnScreen(tester, cta, iPhoneSE), isTrue);
    });

    testWidgets('every step lays out at iPhone SE size', (tester) async {
      for (var step = 0; step <= 4; step++) {
        await pumpAt(tester, iPhoneSE, step: step);
        expect(tester.takeException(), isNull, reason: 'step $step overflowed');
      }
    });
  });

  group('design frame', () {
    testWidgets('every screen lays out at iPhone SE size', (tester) async {
      for (final screen in V2Screen.values) {
        await pumpAt(tester, iPhoneSE, screen: screen);
        expect(
          tester.takeException(),
          isNull,
          reason: '$screen overflowed at iPhone SE size',
        );
      }
    });
  });
}
