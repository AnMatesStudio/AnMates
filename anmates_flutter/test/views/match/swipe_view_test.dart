import 'package:anmates/views/match/swipe_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SwipeView', () {
    testWidgets('renders restaurant name in top bar', (tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(home: SwipeView(restaurantName: 'Quán Test')),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Quán Test'), findsOneWidget);
    });

    testWidgets('tapping the heart button fires the fling animation', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: SwipeView()));
      await tester.pump(const Duration(milliseconds: 100));

      // The heart button is the only Icons.favorite in the tree.
      expect(find.byIcon(Icons.favorite), findsOneWidget);

      await tester.tap(find.byIcon(Icons.favorite));

      // Drive the fling animation forward — _flingCtrl duration is 320ms.
      // Pumping >320ms lets it complete, then whenComplete callback runs
      // setState to reset _dragOffset. No timers should remain pending.
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 50));

      // The view is still on screen (deck reset, ready for next card).
      expect(find.byType(SwipeView), findsOneWidget);
    });

    testWidgets('tapping the pass button fires the fling animation', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: SwipeView()));
      await tester.pump(const Duration(milliseconds: 100));

      // Find the close '✕' icon — the pass button uses an emoji Text widget.
      // It's distinct from the rewind Icon (Icons.replay) and the like
      // button (Icons.favorite).
      expect(find.text('✕'), findsOneWidget);

      await tester.tap(find.text('✕'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(SwipeView), findsOneWidget);
    });
  });
}
