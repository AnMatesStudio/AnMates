import 'dart:math' as math;

import 'package:anmates/services/match_service.dart';
import 'package:anmates/services/venue_catalog_service.dart';
import 'package:anmates/views/v2/v2_app.dart';
import 'package:anmates/views/v2/v2_data.dart';
import 'package:anmates/views/v2/v2_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/viewports.dart';

/// Every v2 screen × every viewport in README §3.3, with seeded data.
///
/// This file is the to-do list of the responsive work: when it was written it
/// was expected to be red, and each Phase B task turns its own screen green.
/// Filter one screen with `--plain-name "home @"`.
///
/// Checks per screen and viewport (README §4):
/// * `layout` — no overflow or exception while laying out.
/// * `min font` — every visible paragraph renders at ≥ 11pt once text scale and
///   any paint transform are applied.
/// * `tap targets` — every tappable semantics node is at least 48 × 48
///   (`androidTapTargetGuideline`).
/// * `pinned actions` — bottom-pinned CTAs and the chat composer sit fully on
///   screen (only on the screens that have them).
///
/// `min font` and `tap targets` look at the screen at every scroll position,
/// half a viewport apart. The tap-target guideline skips any node not fully
/// inside the view, so checking only the first frame would silently pass
/// everything below the fold (measured: home's "Xem tất cả" link, 16pt tall,
/// sits below a 668pt viewport and was never evaluated).
void main() {
  for (final screen in _screens) {
    for (final v in kV2Viewports) {
      group('${screen.name} @ ${v.id}', () {
        testWidgets('layout', (tester) async {
          await _pump(tester, screen, v);
          expect(tester.takeException(), isNull);
        });

        testWidgets('min font', (tester) async {
          await _pump(tester, screen, v);
          // A layout failure is the `layout` test's to report.
          tester.takeException();

          final small = <String>{};
          await _atEveryScrollPosition(tester, () async => small.addAll(_smallText(tester, v)));
          tester.takeException();
          expect(
            small,
            isEmpty,
            reason: 'text below ${_minFont}pt on ${screen.name} @ $v:\n'
                '${(small.toList()..sort()).join('\n')}',
          );
        });

        testWidgets('tap targets', (tester) async {
          // Without semantics on, the guideline finds no nodes and passes
          // vacuously (measured, README §1.1).
          final sem = tester.ensureSemantics();
          try {
            await _pump(tester, screen, v);
            tester.takeException();

            // A node the scroll view clips at one step (a back button half
            // scrolled away) reports its clipped size there. A failing node
            // whose top or bottom edge sits exactly on a vertical scroll
            // view's edge is being cut by it, so it is judged at the steps
            // where it is shown whole instead.
            final small = <String>{};
            await _atEveryScrollPosition(tester, () async {
              // Android's 48dp; it also covers iOS's 44pt.
              final e = await androidTapTargetGuideline.evaluate(tester);
              if (e.passed) return;
              final edges = _verticalScrollViewRects(tester);
              for (final (rect, line) in _tapFailures(e.reason ?? '')) {
                final cut = rect != null &&
                    edges.any((vp) =>
                        (rect.top - vp.top).abs() < 0.5 ||
                        (rect.bottom - vp.bottom).abs() < 0.5);
                if (!cut) small.add(line);
              }
            });
            tester.takeException();
            expect(
              small,
              isEmpty,
              reason: 'tap targets below 48×48 on ${screen.name} @ $v:\n'
                  '${(small.toList()..sort()).join('\n')}',
            );
          } finally {
            sem.dispose();
          }
        });

        final pinned = screen.pinned;
        if (pinned != null) {
          testWidgets('pinned actions', (tester) async {
            await _pump(tester, screen, v);
            tester.takeException();

            final finder = pinned();
            expect(finder, findsOneWidget);
            final r = tester.getRect(finder);
            const eps = 0.01;
            expect(
              r.left >= -eps && r.top >= -eps && r.right <= v.width + eps && r.bottom <= v.height + eps,
              isTrue,
              reason: '$finder is at $r, outside the $v viewport',
            );
          });
        }
      });
    }
  }
}

// ── Screens ─────────────────────────────────────────────────────────────────

/// A thing to put on screen: a real [V2Screen], an onboarding step, or home
/// with an overlay open.
class _Screen {
  const _Screen(this.name, this.setUp, {this.pinned});

  final String name;
  final void Function(V2State s) setUp;

  /// The bottom-pinned control that must stay fully on screen, if any.
  final Finder Function()? pinned;
}

final List<_Screen> _screens = [
  for (var step = 0; step <= 4; step++)
    _Screen(
      'onb$step',
      (s) {
        for (var i = 0; i < step; i++) {
          s.nextStep();
        }
      },
      pinned: switch (step) {
        3 => () => find.text('Tiếp tục'),
        4 => () => find.text('Vào Ăn Mates'),
        _ => null,
      },
    ),
  for (final screen in V2Screen.values)
    if (screen != V2Screen.onb)
      _Screen(
        screen.name,
        (s) => s.go(screen),
        pinned: switch (screen) {
          V2Screen.swipe => () => find.text('Gửi lời mời đi ăn'),
          V2Screen.chat => () => find.byType(TextField),
          _ => null,
        },
      ),
  _Screen('search', (s) => s..go(V2Screen.home)..setSearchOpen(true)),
  _Screen('notifs', (s) => s..go(V2Screen.home)..setNotifsOpen(true)),
  _Screen(
    'radius',
    (s) => s..go(V2Screen.home)..setRadiusSheetOpen(true),
    pinned: () => find.text('Áp dụng'),
  ),
  // Nothing inside the radius: both rows show the "widen it" placeholder.
  _Screen('home-empty', (s) => s..seedVenues(const [], radiusKm: 20)..go(V2Screen.home)),
  // No real candidate: the labelled sample deck, signed-out banner included.
  _Screen(
    'swipe-samples',
    (s) => s..go(V2Screen.swipe)..seedSampleDeck(signedOut: true),
    pinned: () => find.text('Gửi lời mời đi ăn'),
  ),
  _Screen('swipe-match', (s) => s..go(V2Screen.swipe)..seedMatchReveal(kSampleMates.first)),
  _Screen('swipe-done', (s) => s..seedCandidates(const [])..go(V2Screen.swipe)),
];

// ── Pumping ─────────────────────────────────────────────────────────────────

Future<V2State> _pump(WidgetTester tester, _Screen screen, V2Viewport v) async {
  tester.view.physicalSize = Size(v.width, v.height);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(top: v.top, bottom: v.bottom);
  tester.view.viewPadding = FakeViewPadding(top: v.top, bottom: v.bottom);
  tester.platformDispatcher.textScaleFactorTestValue = v.textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  // No loadVenues()/loadCandidates(): tests have no network. Seeded instead,
  // because an empty feed hides every card row.
  final state = V2State()
    ..seedVenues(_venues)
    ..seedCandidates(_candidates);
  screen.setUp(state);

  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider<V2State>.value(
        value: state,
        child: const V2AppBody(),
      ),
    ),
  );
  // Past the 260ms screen cross-fade, so only the target screen is painted.
  await tester.pump(const Duration(milliseconds: 300));
  return state;
}

// ── Scrolling ───────────────────────────────────────────────────────────────

/// Runs [check] on the first frame, then again at every half-viewport step of
/// each vertical scrollable on screen, so everything below the fold is seen
/// fully inside the view at least once. Leaves each scrollable back at the top.
Future<void> _atEveryScrollPosition(
  WidgetTester tester,
  Future<void> Function() check,
) async {
  await check();
  final scrollables = tester
      .stateList<ScrollableState>(find.byType(Scrollable))
      .where((s) =>
          axisDirectionToAxis(s.axisDirection) == Axis.vertical &&
          s.position.hasContentDimensions &&
          s.position.maxScrollExtent > 0)
      .toList();
  for (final s in scrollables) {
    final pos = s.position;
    final step = pos.viewportDimension / 2;
    if (step <= 0) continue;
    for (var offset = pos.minScrollExtent + step;; offset += step) {
      final to = math.min(offset, pos.maxScrollExtent);
      pos.jumpTo(to);
      await tester.pump();
      await check();
      if (to >= pos.maxScrollExtent) break;
    }
    pos.jumpTo(pos.minScrollExtent);
    await tester.pump();
  }
}

// ── Tap targets ─────────────────────────────────────────────────────────────

final RegExp _tapFailure = RegExp(
  r'^(SemanticsNode#\d+)\((?:.*?label: "([^"]*)")?.*?\): expected tap target size of at least .*?, but found Size\(([\d.]+), ([\d.]+)\)',
  multiLine: true,
);

/// Failing nodes of a guideline report: the node's global rect (looked up by
/// id in the current frame; the report itself prints a parent-relative rect)
/// and a `"label" W×H` line.
List<(Rect?, String)> _tapFailures(String reason) {
  final global = _globalSemanticsRects();
  return [
    for (final m in _tapFailure.allMatches(reason))
      (
        global[int.parse(m.group(1)!.split('#').last)],
        '  "${(m.group(2) ?? '').replaceAll(r'\n', ' ')}" '
            '${_pt(double.parse(m.group(3)!))}×${_pt(double.parse(m.group(4)!))}',
      ),
    if (!_tapFailure.hasMatch(reason)) (null, reason),
  ];
}

/// Every semantics node's rect in screen coordinates, by id.
Map<int, Rect> _globalSemanticsRects() {
  // Each view has its own pipeline owner; the root owner holds no semantics.
  final root = RendererBinding.instance.renderViews.first.owner?.semanticsOwner?.rootSemanticsNode;
  final out = <int, Rect>{};
  void visit(SemanticsNode node) {
    var rect = node.rect;
    for (SemanticsNode? n = node; n != null; n = n.parent) {
      if (n.transform != null) rect = MatrixUtils.transformRect(n.transform!, rect);
    }
    out[node.id] = rect;
    node.visitChildren((c) {
      visit(c);
      return true;
    });
  }
  if (root != null) visit(root);
  return out;
}

/// Global rects of the vertical scroll views on screen.
List<Rect> _verticalScrollViewRects(WidgetTester tester) => [
      for (final s in tester.stateList<ScrollableState>(find.byType(Scrollable)))
        if (axisDirectionToAxis(s.axisDirection) == Axis.vertical)
          MatrixUtils.transformRect(
            s.context.findRenderObject()!.getTransformTo(null),
            Offset.zero & (s.context.findRenderObject()! as RenderBox).size,
          ),
    ];


// ── Min font ────────────────────────────────────────────────────────────────

const double _minFont = 11;

/// Emoji, arrows, stars, bullets: nothing a reader has to *read*.
final RegExp _readable = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// Every visible run of readable text rendered below [_minFont], as
/// `"text" 9.5pt` lines, one per distinct string and size.
List<String> _smallText(WidgetTester tester, V2Viewport v) {
  final screenRect = Rect.fromLTWH(0, 0, v.width, v.height);
  final out = <String>{};

  for (final p in tester.allRenderObjects.whereType<RenderParagraph>()) {
    if (!p.attached || !p.hasSize || p.size.isEmpty || _isHidden(p)) continue;

    final transform = p.getTransformTo(null);
    final rect = MatrixUtils.transformRect(transform, Offset.zero & p.size);
    if (!rect.overlaps(screenRect)) continue;

    final k = _paintScale(transform);
    // Scaled to nothing (an entry animation at its first frame): not visible.
    if (k < 0.01) continue;
    _visitRuns(p.text, null, (text, fontSize) {
      if (!_readable.hasMatch(text)) return;
      final shown = p.textScaler.scale(fontSize) * k;
      // Hero numbers and display type. Declared ≥ 40 also exempts the 40pt
      // "AM" wordmark inside the onboarding orbit art, which shrinks with the
      // art on short screens: it is a logo, not text anyone has to read.
      if (shown >= 40 || fontSize >= 40) return;
      if (shown < _minFont - 0.05) {
        final label = text.trim().replaceAll('\n', ' ');
        final clipped = label.length > 48 ? '${label.substring(0, 48)}…' : label;
        out.add('  "$clipped" ${_pt(shown)}pt'
            '${fontSize == shown ? '' : ' (declared ${_pt(fontSize)})'}');
      }
    });
  }
  return out.toList()..sort();
}

/// How much [m] shrinks or grows what it paints on screen, in 2D.
///
/// Not `Matrix4.getMaxScaleOnAxis`: that includes the z axis, which a 2D scale
/// such as `FittedBox` leaves at 1, so it reports 1.0 for any downscale — it
/// could never have caught the old height scaling. The smaller of the x and y
/// scales is what the reader gets.
double _paintScale(Matrix4 m) {
  final s = m.storage;
  final sx = math.sqrt(s[0] * s[0] + s[1] * s[1]);
  final sy = math.sqrt(s[4] * s[4] + s[5] * s[5]);
  return math.min(sx, sy);
}

/// Calls [visit] with each text run of [span] and its inherited font size.
void _visitRuns(
  InlineSpan span,
  double? inherited,
  void Function(String text, double fontSize) visit,
) {
  final size = span.style?.fontSize ?? inherited ?? 14;
  if (span is TextSpan) {
    final text = span.text;
    if (text != null && text.trim().isNotEmpty) visit(text, size);
    for (final child in span.children ?? const <InlineSpan>[]) {
      _visitRuns(child, size, visit);
    }
  }
}

/// Laid out but not painted: offstage, or under a fully transparent opacity.
bool _isHidden(RenderObject node) {
  for (RenderObject? n = node; n != null; n = n.parent) {
    if (n is RenderOffstage && n.offstage) return true;
    if (n is RenderOpacity && n.opacity == 0) return true;
    if (n is RenderAnimatedOpacity && n.opacity.value == 0) return true;
    if (n is RenderSliverOpacity && n.opacity == 0) return true;
  }
  return false;
}

String _pt(double v) => v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1);

// ── Seed data ───────────────────────────────────────────────────────────────

/// Six venues, names 12–40 characters. Two carry a photo URL — it cannot load
/// in a test, so they exercise the error fallback — and four have none, which
/// renders the 3D-art fallback.
final List<CatalogVenue> _venues = [
  _venue('v1', 'Lẩu Trứ Danh Sài Gòn', ['lau', 'vietnamese'], 'Q1', 420, 65000, 180000, photo: true),
  _venue('v2', 'Bánh Mì Huỳnh Hoa', ['banh_mi'], 'Q1', 850, 45000, 70000),
  _venue('v3', 'Quán Nướng Ngói Đỏ Phú Nhuận Chi Nhánh 2', ['bbq', 'nuong'], 'PN', 2400, 150000, 320000, rating: 4.6),
  _venue('v4', 'Phở Hòa Pasteur', ['pho'], 'Q3', 1300, 60000, 95000, photo: true, rating: 4.4),
  _venue('v5', 'Cà Phê Vợt Cây Si Gò Vấp', ['cafe'], 'GV', 5100, 20000, null),
  _venue('v6', 'Ốc Đào Nguyễn Trãi Quận Năm', ['oc', 'hai_san'], 'Q5', 3700, null, null, wantCount: 7),
];

CatalogVenue _venue(
  String id,
  String name,
  List<String> tags,
  String district,
  int distanceM,
  int? priceMin,
  int? priceMax, {
  bool photo = false,
  double? rating,
  int wantCount = 2,
}) =>
    CatalogVenue(
      id: id,
      name: name,
      address: '${distanceM ~/ 10} Nguyễn Trãi, Phường 2',
      district: district,
      lat: 10.77,
      lng: 106.70,
      cuisineTags: tags,
      photoUrls: photo ? ['https://example.invalid/venues/$id/photos/0'] : const [],
      source: 'seed',
      wantCount: wantCount,
      priceMin: priceMin,
      priceMax: priceMax,
      rating: rating,
      distanceM: distanceM,
    );

final List<MatchCandidate> _candidates = [
  MatchCandidate(
    userId: 'u1',
    name: 'Hạnh',
    age: 26,
    tags: ['spicy', 'loud', 'late_night'],
    overlapCount: 3,
    overlapFoods: ['lau', 'bun_bo', 'oc'],
    score: 0.92,
  ),
  MatchCandidate(
    userId: 'u2',
    name: 'Nguyễn Minh Khoa',
    tags: ['chill', 'coffee'],
    overlapCount: 1,
    overlapFoods: ['cafe'],
    score: 0.61,
  ),
  MatchCandidate(
    userId: 'u3',
    name: 'Linh',
    age: 31,
    tags: [],
    overlapCount: 0,
    overlapFoods: [],
    score: 0.2,
  ),
];
