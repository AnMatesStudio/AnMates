import 'package:anmates/theme/v2_layout.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// [V2Layout] reads everything from the nearest [MediaQuery], so each case pumps
/// one with the size, insets and text scale under test and reads the helper
/// back from inside it.
void main() {
  Future<T> measure<T>(
    WidgetTester tester,
    T Function(BuildContext context) read, {
    Size size = const Size(402, 874),
    EdgeInsets padding = EdgeInsets.zero,
    double textScale = 1,
  }) async {
    late T value;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: size,
          padding: padding,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Builder(
          builder: (context) {
            value = read(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return value;
  }

  group('unit', () {
    testWidgets('clamps to 0.85 on the narrowest phones', (tester) async {
      expect(
        await measure(tester, V2Layout.unit, size: const Size(320, 568)),
        0.85,
      );
    });

    testWidgets('is exactly 1 at the design width', (tester) async {
      expect(
        await measure(tester, V2Layout.unit, size: const Size(402, 874)),
        1.0,
      );
    });

    testWidgets('scales by width between the clamps', (tester) async {
      expect(
        await measure(tester, V2Layout.unit, size: const Size(440, 956)),
        closeTo(440 / 402, 1e-9),
      );
      expect(440 / 402, closeTo(1.0945, 1e-4));
    });

    testWidgets('clamps to 1.1 once the width is capped at the 480 column',
        (tester) async {
      // 800 is capped to 480 first; 480 / 402 = 1.194 then clamps to 1.1.
      expect(
        await measure(tester, V2Layout.unit, size: const Size(800, 390)),
        1.1,
      );
    });

    testWidgets('never depends on height', (tester) async {
      final tall = await measure(tester, V2Layout.unit, size: const Size(393, 852));
      final short = await measure(tester, V2Layout.unit, size: const Size(393, 400));
      expect(short, tall);
    });
  });

  group('widthClass', () {
    const cases = <(double, V2Width)>[
      (359, V2Width.xs),
      (360, V2Width.sm),
      (389, V2Width.sm),
      (390, V2Width.md),
      (429, V2Width.md),
      (430, V2Width.lg),
    ];
    for (final (width, expected) in cases) {
      testWidgets('$width → ${expected.name}', (tester) async {
        expect(
          await measure(tester, V2Layout.widthClass, size: Size(width, 800)),
          expected,
        );
      });
    }
  });

  group('contentTop', () {
    testWidgets('is 56 below a zero safe area (mobile browser)', (tester) async {
      expect(await measure(tester, V2Layout.contentTop), 56);
    });

    testWidgets('follows the safe area (notch 59)', (tester) async {
      expect(
        await measure(
          tester,
          V2Layout.contentTop,
          padding: const EdgeInsets.only(top: 59),
        ),
        115,
      );
    });
  });

  group('isShort / isVeryShort', () {
    testWidgets('isShort flips at 700', (tester) async {
      expect(await measure(tester, V2Layout.isShort, size: const Size(393, 699)), isTrue);
      expect(await measure(tester, V2Layout.isShort, size: const Size(393, 700)), isFalse);
    });

    testWidgets('isVeryShort flips at 500', (tester) async {
      expect(await measure(tester, V2Layout.isVeryShort, size: const Size(844, 499)), isTrue);
      expect(await measure(tester, V2Layout.isVeryShort, size: const Size(844, 500)), isFalse);
    });
  });

  group('hPad', () {
    testWidgets('is 14 on xs and 18 from sm up', (tester) async {
      expect(await measure(tester, V2Layout.hPad, size: const Size(320, 568)), 14);
      expect(await measure(tester, V2Layout.hPad, size: const Size(360, 640)), 18);
    });
  });

  group('textGrowth', () {
    testWidgets('is 6 for a 20pt line at text scale 1.3', (tester) async {
      expect(
        await measure(tester, (c) => V2Layout.textGrowth(c, 20), textScale: 1.3),
        closeTo(6, 1e-9),
      );
    });

    testWidgets('is 0 at text scale 1', (tester) async {
      expect(await measure(tester, (c) => V2Layout.textGrowth(c, 20)), 0);
    });
  });
}
