import 'package:anmates/shared/widgets/anm_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnmImage', () {
    testWidgets('renders error placeholder when url is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AnmImage(url: null, width: 80, height: 80)),
        ),
      );

      expect(find.byType(AnmImageError), findsOneWidget);
      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    });

    testWidgets('renders error placeholder when url is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AnmImage(url: '', width: 80, height: 80)),
        ),
      );

      expect(find.byType(AnmImageError), findsOneWidget);
    });

    testWidgets('honours custom errorWidget override', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnmImage(
              url: null,
              width: 80,
              height: 80,
              errorWidget: Text('OFFLINE'),
            ),
          ),
        ),
      );

      expect(find.text('OFFLINE'), findsOneWidget);
      expect(find.byType(AnmImageError), findsNothing);
    });
  });

  group('AnmImageError', () {
    testWidgets('sizes itself to provided width/height', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AnmImageError(width: 50, height: 30)),
        ),
      );

      final size = tester.getSize(find.byType(AnmImageError));
      expect(size.width, 50);
      expect(size.height, 30);
    });
  });
}
