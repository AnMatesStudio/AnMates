import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/app_theme_v2.dart';
import '../../views/v2/v2_data.dart';

enum NavTab { discover, swipe, tables, me }

/// Frosted pill nav from the design shell — it floats 74px up into the content
/// (`margin:-74px 14px 22px`) so the feed scrolls under the glass.
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
    super.key,
    required this.current,
    required this.onSelect,
    required this.en,
  });

  final NavTab current;
  final ValueChanged<NavTab> onSelect;
  final bool en;

  /// Mirrors the design's `navDef` table, bilingual labels included.
  static const _items = <(NavTab, T)>[
    (NavTab.discover, T('Khám phá', 'Discover')),
    (NavTab.swipe, T('Quẹt', 'Swipe')),
    (NavTab.tables, T('Tin nhắn', 'Messages')),
    (NavTab.me, T('Tôi', 'Me')),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 22),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColorsV2.whiteA(0.66)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColorsV2.whiteA(0.66), AppColorsV2.whiteA(0.44)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0A285A).withValues(alpha: 0.20),
                  blurRadius: 36,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Row(
                children: [
                  for (final (tab, label) in _items)
                    Expanded(
                      child: _NavItem(
                        tab: tab,
                        label: label(en),
                        active: tab == current,
                        onTap: () => onSelect(tab),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final NavTab tab;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColorsV2.wisteria : AppColorsV2.inkA(0.45);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.fromLTRB(2, 8, 2, 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: active
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColorsV2.whiteA(0.98), AppColorsV2.whiteA(0.86)],
                )
              : null,
          boxShadow: active
              ? [
                  BoxShadow(
                    color: const Color(0xFF0A285A).withValues(alpha: 0.14),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: const Size(24, 24),
              painter: _NavIconPainter(tab: tab, color: color, stroke: active ? 1.9 : 1.7),
            ),
            const SizedBox(height: 5),
            Text(label, style: AppTextV2.navLabel(color: color)),
          ],
        ),
      ),
    );
  }
}

/// The four glyphs from the design's `NAV_PATHS` table, drawn with canvas
/// primitives — Flutter has no SVG path parser in the framework and the shapes
/// are all circles, straight runs and one rounded ticket outline.
class _NavIconPainter extends CustomPainter {
  _NavIconPainter({required this.tab, required this.color, required this.stroke});

  final NavTab tab;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    // Design glyphs are authored on a 24×24 viewBox.
    final s = size.width / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    Offset p(double x, double y) => Offset(x * s, y * s);

    switch (tab) {
      case NavTab.discover:
        canvas.drawCircle(p(12, 12), 9.4 * s, paint);
        canvas.drawPath(
          Path()
            ..moveTo(15.4 * s, 8.6 * s)
            ..lineTo(13.3 * s, 13.4 * s)
            ..lineTo(8.6 * s, 15.5 * s)
            ..lineTo(10.7 * s, 10.7 * s)
            ..close(),
          paint,
        );

      case NavTab.swipe:
        // Tilted card: the design skews it via a 3-degree-ish path; a rotated
        // rounded rect reproduces it without the hand-rolled transform.
        canvas.save();
        canvas.translate(15 * s, 11.5 * s);
        canvas.rotate(-0.32);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: 7.4 * s, height: 12.6 * s),
            Radius.circular(1.6 * s),
          ),
          paint,
        );
        canvas.restore();
        for (final (y, x1, x2) in [(9.4, 3.4, 6.2), (12.6, 4.2, 7.0), (15.8, 5.2, 8.0)]) {
          canvas.drawLine(p(x1, y), p(x2, y), paint);
        }

      case NavTab.tables:
        // Speech bubble with a tail and three dots.
        canvas.drawOval(
          Rect.fromCenter(center: p(12, 11), width: 17.6 * s, height: 14.8 * s),
          paint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(8.2 * s, 16.9 * s)
            ..lineTo(5.4 * s, 20.4 * s)
            ..lineTo(10.0 * s, 18.6 * s),
          paint,
        );
        final dot = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        for (final x in [8.6, 12.0, 15.4]) {
          canvas.drawCircle(p(x, 11), 0.95 * s, dot);
        }

      case NavTab.me:
        canvas.drawCircle(p(12, 12), 9.2 * s, paint);
        canvas.drawCircle(p(12, 9.7), 2.7 * s, paint);
        canvas.drawArc(
          Rect.fromCircle(center: p(12, 18.6), radius: 5.6 * s),
          math.pi,
          math.pi,
          false,
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(_NavIconPainter old) =>
      old.tab != tab || old.color != color || old.stroke != stroke;
}
