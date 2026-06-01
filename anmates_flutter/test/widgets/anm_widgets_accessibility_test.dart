import 'package:anmates/widgets/anm_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnmCTA accessibility', () {
    testWidgets('exposes button semantics with enabled state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnmCTA(label: 'Gửi mã OTP', onTap: () {}),
          ),
        ),
      );

      // Find the explicit Semantics node we added.
      final ctaSemantics = tester.getSemantics(
        find.bySemanticsLabel('Gửi mã OTP'),
      );
      expect(ctaSemantics.hasFlag(SemanticsFlag.isButton), true);
      expect(ctaSemantics.hasFlag(SemanticsFlag.hasEnabledState), true);
      expect(ctaSemantics.hasFlag(SemanticsFlag.isEnabled), true);
    });

    testWidgets('disabled state propagates to semantics', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AnmCTA(label: 'Đang gửi…', onTap: null)),
        ),
      );

      final ctaSemantics = tester.getSemantics(
        find.bySemanticsLabel('Đang gửi…'),
      );
      expect(ctaSemantics.hasFlag(SemanticsFlag.isButton), true);
      expect(ctaSemantics.hasFlag(SemanticsFlag.isEnabled), false);
    });

    testWidgets('meets minimum touch target height (≥48pt material guidance)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnmCTA(label: 'Tiếp tục', onTap: () {}),
          ),
        ),
      );

      final size = tester.getSize(find.byType(AnmCTA));
      // Default AnmCTA height is 56pt — well above the 48pt material minimum
      // and the 44pt iOS HIG minimum.
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });

  group('AnmChip accessibility', () {
    testWidgets('inactive chip reports unselected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnmChip(label: 'Cay 3', active: false, onTap: () {}),
          ),
        ),
      );

      final chipSemantics = tester.getSemantics(find.bySemanticsLabel('Cay 3'));
      expect(chipSemantics.hasFlag(SemanticsFlag.isButton), true);
      expect(chipSemantics.hasFlag(SemanticsFlag.hasSelectedState), true);
      expect(chipSemantics.hasFlag(SemanticsFlag.isSelected), false);
    });

    testWidgets('active chip reports selected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnmChip(label: 'Máy lạnh', active: true, onTap: () {}),
          ),
        ),
      );

      final chipSemantics = tester.getSemantics(
        find.bySemanticsLabel('Máy lạnh'),
      );
      expect(chipSemantics.hasFlag(SemanticsFlag.isSelected), true);
    });

    testWidgets('uses opaque hit-test so padding area is tappable', (
      tester,
    ) async {
      var tapped = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnmChip(label: 'Tag', onTap: () => tapped++),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(AnmChip));
      await tester.pump();
      expect(tapped, 1);
    });
  });
}
