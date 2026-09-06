import 'package:anmates/views/v2/v2_app.dart';
import 'package:anmates/views/v2/v2_data.dart';
import 'package:anmates/views/v2/v2_state.dart';
import 'package:anmates/widgets/v2/food_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Every v2 screen is a pixel port of a 402 × 874 canvas frame. An iPhone SE is
/// 375 × 667 — a quarter shorter — and nothing in those screens reflows, so
/// without [DesignFrame] the art lands on the headlines and the bottom controls
/// fall off the screen.
///
/// A RenderFlex that overflows reports through the binding, so these fail on
/// their own if a screen stops fitting; the geometry assertions cover the case
/// where content is merely pushed out of view rather than overflowing.
void main() {
  const iPhoneSE = Size(375, 667);
  const designFrame = Size(402, 874);

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
    testWidgets('scales the whole frame down on a short screen',
        (tester) async {
      // The hotpot art is 238pt in the canvas frame. It keeps that size at the
      // frame's own height and has to render smaller on a shorter phone.
      await pumpAt(tester, designFrame, step: 1);
      final atFrame = tester.getRect(find.byType(FloatingArt).first);
      expect(atFrame.height, closeTo(238, 0.5));

      await pumpAt(tester, iPhoneSE, step: 1);
      final onSE = tester.getRect(find.byType(FloatingArt).first);

      expect(onSE.height, lessThan(atFrame.height));
      // Uniformly, by the height ratio — not squashed on one axis.
      final k = iPhoneSE.height / kDesignFrameHeight;
      expect(onSE.height, closeTo(238 * k, 1));
      expect(onSE.width / onSE.height, closeTo(1, 0.01));
    });

    testWidgets('leaves a screen at least as tall as the frame untouched',
        (tester) async {
      await pumpAt(tester, const Size(402, 900), step: 1);
      expect(
        tester.getRect(find.byType(FloatingArt).first).height,
        closeTo(238, 0.5),
      );
    });

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
