import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anmates/main.dart';
import 'package:anmates/theme/app_theme.dart';

void main() {
  testWidgets('AnMates app smoke test', (WidgetTester tester) async {
    // SplashScreen reads the persisted session on startup; give it an empty
    // (logged-out) store so it resolves to onboarding without hitting network.
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeNotifier(),
        child: const AnMatesApp(),
      ),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
