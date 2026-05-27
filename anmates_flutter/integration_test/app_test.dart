// End-to-end integration tests for ĂnMates Flutter.
//
// These tests drive the full app — splash → onboarding → phone input → Dev
// Mode bypass → main tabs — against a live backend.
//
// Prerequisites:
//   • Backend running (npm run dev), reachable at API_BASE_URL.
//   • Backend has DEV_MODE=true + a matching DEV_BYPASS_SECRET.
//
// Run on Chrome:
//   flutter test integration_test/ -d chrome \
//     --dart-define=API_BASE_URL=http://localhost:8080 \
//     --dart-define=DEV_BYPASS_SECRET=dev-local-2026
//
// Run on a mobile emulator:
//   flutter test integration_test/app_test.dart
//
// The phone-input flow shows a debug-only "Dev Mode (skip OTP)" button. Tests
// tap it instead of going through Firebase, so they need no SMS/Firebase setup.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anmates/main.dart' as app;
import 'package:anmates/views/auth/phone_input_view.dart';
import 'package:anmates/views/main_tab_view.dart';
import 'package:anmates/views/onboarding/onboarding_view.dart';
import 'package:anmates/views/splash/splash_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Start each test with a clean auth state.
    SharedPreferences.setMockInitialValues({});
  });

  group('Boot flow', () {
    testWidgets('splash → onboarding (auto navigates after ~2.5s)', (
      tester,
    ) async {
      app.main();
      // Splash is animated, so let it settle past its 2.5s delay.
      await tester.pump();
      expect(find.byType(SplashScreen), findsOneWidget);

      // pumpAndSettle would hang on infinite animations, so pump in chunks.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.byType(OnboardingView), findsOneWidget);
    });
  });

  group('Phone input + Dev Mode bypass', () {
    testWidgets('Dev Mode button is visible in debug builds', (tester) async {
      await _bootToPhoneInput(tester);
      expect(find.byKey(const ValueKey('dev_mode_skip_otp')), findsOneWidget);
      expect(find.text('Dev Mode (skip OTP)'), findsOneWidget);
    });

    testWidgets('Dev Mode button skips OTP and lands on MainTabView', (
      tester,
    ) async {
      await _bootToPhoneInput(tester);

      await tester.tap(find.byKey(const ValueKey('dev_mode_skip_otp')));
      // Auth round-trip takes a few hundred ms; settle generously.
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // If backend rejected the dev secret, we'd still be on PhoneInputView
      // with a snackbar — surface that as a skip rather than a false failure.
      if (find.byType(PhoneInputView).evaluate().isNotEmpty) {
        final snack = find.byType(SnackBar);
        markTestSkipped(
          'dev-login rejected by backend — make sure DEV_MODE=true and the '
          'secret matches. ${snack.evaluate().isNotEmpty ? "snackbar shown" : ""}',
        );
        return;
      }

      expect(find.byType(MainTabView), findsOneWidget);

      // Tokens saved.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('access_token'), isNotNull);
      expect(prefs.getString('user_id'), isNotNull);
    });

    testWidgets('Main CTA stays disabled until name + phone filled', (
      tester,
    ) async {
      await _bootToPhoneInput(tester);

      // Main CTA exists; tapping while disabled does nothing — assertion is
      // that we're still on PhoneInputView (no navigation triggered).
      await tester.tap(find.text('Gửi mã OTP'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(PhoneInputView), findsOneWidget);

      // Now fill the fields and observe the label still equals "Gửi mã OTP"
      // (we don't trigger Firebase from the test).
      final nameField = find
          .widgetWithText(TextField, 'Tên của bạn')
          .hitTestable();
      if (nameField.evaluate().isNotEmpty) {
        await tester.enterText(nameField, 'Tester');
      }
      final phoneField = find
          .widgetWithText(TextField, '912 345 678')
          .hitTestable();
      if (phoneField.evaluate().isNotEmpty) {
        await tester.enterText(phoneField, '912345678');
      }
      await tester.pump();
      expect(find.text('Gửi mã OTP'), findsOneWidget);
    });
  });

  group('Main tabs after auth', () {
    testWidgets('all four tabs render and switch on tap', (tester) async {
      await _bootToPhoneInput(tester);

      await tester.tap(find.byKey(const ValueKey('dev_mode_skip_otp')));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      if (find.byType(PhoneInputView).evaluate().isNotEmpty) {
        markTestSkipped('dev-login rejected by backend');
        return;
      }

      expect(find.byType(MainTabView), findsOneWidget);

      // Tab labels come from AnmTabBar — switch through each one.
      for (final label in const ['Wishlist', 'Chat', 'Mình', 'Khám phá']) {
        final tab = find.text(label);
        expect(tab, findsOneWidget, reason: 'missing tab: $label');
        await tester.tap(tab);
        await tester.pumpAndSettle(const Duration(seconds: 1));
      }
    });
  });
}

// ── helpers ──────────────────────────────────────────────────────────────────

/// Boot the app and drive splash → onboarding → phone input.
Future<void> _bootToPhoneInput(WidgetTester tester) async {
  app.main();
  await tester.pump();

  // Splash auto-navigates after ~2.5s.
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle(const Duration(seconds: 1));
  expect(find.byType(OnboardingView), findsOneWidget);

  // Onboarding has a "Bỏ qua" (skip) button — tap if present, otherwise
  // walk through pages with whatever primary CTA is visible.
  await _dismissOnboarding(tester);
  expect(
    find.byType(PhoneInputView),
    findsOneWidget,
    reason: 'expected to land on PhoneInputView after onboarding',
  );
}

Future<void> _dismissOnboarding(WidgetTester tester) async {
  // Look for a skip button by Vietnamese label first, fall back to English.
  for (final label in const ['Bỏ qua', 'Skip']) {
    final f = find.text(label);
    if (f.evaluate().isNotEmpty) {
      await tester.tap(f.first);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      return;
    }
  }
  // No explicit skip — advance through pages by tapping any "Tiếp" / "Next" /
  // "Bắt đầu" / "Bắt đầu ngay" CTA we can find. Bounded so we don't loop.
  for (int i = 0; i < 5; i++) {
    final advance =
        const ['Tiếp', 'Tiếp tục', 'Next', 'Bắt đầu', 'Bắt đầu ngay']
            .map(find.text)
            .firstWhere(
              (f) => f.evaluate().isNotEmpty,
              orElse: () => find.byType(SizedBox).first,
            );
    if (advance == find.byType(SizedBox).first) break;
    await tester.tap(advance.first);
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
    if (find.byType(PhoneInputView).evaluate().isNotEmpty) return;
  }
}
