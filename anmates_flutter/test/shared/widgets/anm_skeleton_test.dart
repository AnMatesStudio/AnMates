import 'package:anmates/shared/widgets/anm_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnmSkeleton', () {
    testWidgets('renders with provided width and height', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AnmSkeleton(width: 100, height: 40)),
        ),
      );

      final size = tester.getSize(find.byType(AnmSkeleton));
      expect(size.width, 100);
      expect(size.height, 40);
    });

    testWidgets('circle constructor produces square box', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AnmSkeleton.circle(size: 48))),
      );

      final size = tester.getSize(find.byType(AnmSkeleton));
      expect(size.width, 48);
      expect(size.height, 48);
    });

    testWidgets('respects reduce-motion accessibility setting', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const Scaffold(body: AnmSkeleton(width: 100, height: 40)),
          ),
        ),
      );

      // When disableAnimations is true the skeleton renders as a static
      // Container with no AnimatedBuilder underneath it.
      final inSkeleton = find.descendant(
        of: find.byType(AnmSkeleton),
        matching: find.byType(AnimatedBuilder),
      );
      expect(inSkeleton, findsNothing);
    });

    testWidgets('animates when reduce-motion is off', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AnmSkeleton(width: 100, height: 40)),
        ),
      );

      final inSkeleton = find.descendant(
        of: find.byType(AnmSkeleton),
        matching: find.byType(AnimatedBuilder),
      );
      expect(inSkeleton, findsOneWidget);

      // Pump some frames to ensure animation runs without throwing.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
    });
  });
}
