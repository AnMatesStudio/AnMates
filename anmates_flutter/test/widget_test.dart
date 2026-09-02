import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anmates/main.dart';

void main() {
  testWidgets('AnMates app boots on the onboarding welcome screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AnMatesApp());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Ăn Mates'), findsOneWidget);
  });
}
