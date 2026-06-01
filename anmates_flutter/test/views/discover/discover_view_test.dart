import 'package:anmates/views/discover/discover_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiscoverView', () {
    testWidgets('renders top bar, search, sections without errors', (
      tester,
    ) async {
      // Use a tall test surface so all sections fit without forcing scroll.
      tester.view.physicalSize = const Size(400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: DiscoverView()));
      // Genre cards schedule Future.delayed(0..700ms) in initState to stagger
      // their emoji float animation. Pump >700ms so those timers fire and
      // become long-running periodic AnimationControllers (which the test
      // binding accepts), instead of pending one-shot timers (which it
      // doesn't).
      await tester.pump(const Duration(milliseconds: 800));

      // Top bar copy
      expect(find.text('📍 QUẬN 1, TP.HCM'), findsOneWidget);
      expect(find.text('Hôm nay ăn gì, Vy?'), findsOneWidget);

      // Search bar placeholder
      expect(find.text('Tìm quán, món, vibe…'), findsOneWidget);

      // Section headings
      expect(find.text('BẠN THÈM GENRE GÌ?'), findsOneWidget);
      expect(find.text('… HAY MUỐN VIBE NÀO?'), findsOneWidget);
      expect(find.text('HOT QUANH BẠN · 18:00'), findsOneWidget);

      // Restaurant rows from SliverList.builder
      expect(find.text('Tiệm mì Ramen Q1'), findsOneWidget);
      expect(find.text('Bò tơ nướng đá tảng'), findsOneWidget);
    });

    testWidgets('uses CustomScrollView (not SingleChildScrollView)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: DiscoverView()));
      // Let the staggered Future.delayed timers in _GenreCardState fire.
      await tester.pump(const Duration(milliseconds: 800));

      // The whole point of Phase 4b: the outer scroll must be a sliver
      // viewport, not a SingleChildScrollView + Column. This test
      // documents that architectural decision so it can't silently regress.
      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsWidgets);
      // (The genre carousel is still a SingleChildScrollView internally,
      // which is fine — that's a tiny fixed-height horizontal strip.)
    });
  });
}
