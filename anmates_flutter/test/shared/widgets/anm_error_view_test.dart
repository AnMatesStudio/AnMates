import 'package:anmates/shared/widgets/anm_error_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnmErrorView', () {
    testWidgets('shows default message when no override', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AnmErrorView())),
      );

      expect(find.text('Có lỗi xảy ra. Vui lòng thử lại.'), findsOneWidget);
    });

    testWidgets('shows custom message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AnmErrorView(message: 'Mất kết nối')),
        ),
      );

      expect(find.text('Mất kết nối'), findsOneWidget);
    });

    testWidgets('hides retry button when onRetry is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AnmErrorView())),
      );

      expect(find.text('Thử lại'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('shows retry button when onRetry is provided', (tester) async {
      int retryCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AnmErrorView(onRetry: () => retryCount++)),
        ),
      );

      expect(find.text('Thử lại'), findsOneWidget);

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(retryCount, 1);
    });

    testWidgets('uses provided icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AnmErrorView(icon: Icons.wifi_off)),
        ),
      );

      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_outlined), findsNothing);
    });
  });
}
