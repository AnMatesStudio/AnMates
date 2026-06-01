import 'dart:async';

import 'package:anmates/core/network/connectivity_service.dart';
import 'package:anmates/shared/widgets/connectivity_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockConnectivityService extends Mock implements ConnectivityService {}

void main() {
  group('ConnectivityBanner', () {
    late MockConnectivityService service;
    late StreamController<bool> stream;

    setUp(() {
      service = MockConnectivityService();
      stream = StreamController<bool>.broadcast();
      when(() => service.connectivityStream).thenAnswer((_) => stream.stream);
      when(() => service.isOnline).thenAnswer((_) async => true);
    });

    tearDown(() async => stream.close());

    testWidgets('does not show offline bar when online', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectivityBanner(
              service: service,
              child: const SizedBox(width: 200, height: 100),
            ),
          ),
        ),
      );
      // Let initial isOnline future resolve.
      await tester.pump(const Duration(milliseconds: 50));

      // The offline bar widget itself exists in the tree but is animated off
      // screen with opacity 0 — the user can't see or interact with it.
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      final opacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(opacity.opacity, 0.0);
    });

    testWidgets('slides in when connectivity is lost', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectivityBanner(
              service: service,
              child: const SizedBox(width: 200, height: 100),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      stream.add(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final opacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(opacity.opacity, 1.0);
      expect(
        find.text('Mất kết nối — đang dùng dữ liệu đã lưu'),
        findsOneWidget,
      );
    });

    testWidgets('slides back out when connectivity returns', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectivityBanner(
              service: service,
              child: const SizedBox(width: 200, height: 100),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      stream.add(false);
      await tester.pump();
      stream.add(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final opacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(opacity.opacity, 0.0);
    });

    testWidgets('respects MediaQuery.disableAnimations', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: ConnectivityBanner(
                service: service,
                child: const SizedBox(width: 200, height: 100),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // Animation duration should be Duration.zero when reduce-motion is on.
      final slide = tester.widget<AnimatedSlide>(find.byType(AnimatedSlide));
      expect(slide.duration, Duration.zero);
    });
  });
}
