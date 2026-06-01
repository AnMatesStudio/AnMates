import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Horoscope / numerology icon library for Screen 08 (Thông Tin Cá Nhân).
///
/// Three badge families, one visual language:
///   • ZodiacIcon   — 12 western zodiac signs (Unicode glyphs, auto-centered)
///   • NguHanhIcon  — 5 elements (Kim/Mộc/Thủy/Hỏa/Thổ) with traditional colors
///   • ThanSoIcon   — life-path numeral 1–33

// ─── Zodiac glyph map ────────────────────────────────────────────────────────

const Map<String, String> _zodiacGlyphs = {
  'Bạch Dương': '♈',
  'Kim Ngưu': '♉',
  'Song Tử': '♊',
  'Cự Giải': '♋',
  'Sư Tử': '♌',
  'Xử Nữ': '♍',
  'Thiên Bình': '♎',
  'Bọ Cạp': '♏',
  'Nhân Mã': '♐',
  'Ma Kết': '♑',
  'Bảo Bình': '♒',
  'Song Ngư': '♓',
};

String zodiacGlyph(String viName) => _zodiacGlyphs[viName] ?? '✦';

// ─── Ngũ Hành map ────────────────────────────────────────────────────────────

typedef ElementVisual = ({IconData icon, Color color});

const Map<String, ElementVisual> _elementVisuals = {
  'Kim': (icon: Icons.diamond_outlined,              color: Color(0xFFCAA53D)),
  'Mộc': (icon: Icons.park_outlined,                 color: Color(0xFF3FA66A)),
  'Thủy': (icon: Icons.water_drop_outlined,          color: Color(0xFF2D9CDB)),
  'Hỏa': (icon: Icons.local_fire_department_outlined,color: Color(0xFFE8553C)),
  'Thổ': (icon: Icons.terrain_outlined,              color: Color(0xFFB07A3C)),
};

String elementOf(String napAmName) {
  for (final key in _elementVisuals.keys) {
    if (napAmName.endsWith(key)) return key;
  }
  return 'Thổ';
}

ElementVisual elementVisual(String element) =>
    _elementVisuals[element] ?? _elementVisuals['Thổ']!;

// ─── Shared badge container ───────────────────────────────────────────────────

class _IconBadge extends StatelessWidget {
  final Widget child;
  final Color tint;
  final double size;
  const _IconBadge({required this.child, required this.tint, this.size = 34});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

// ─── Zodiac badge ─────────────────────────────────────────────────────────────

/// Light-purple rounded square badge. The glyph is painted via [CustomPainter]
/// using [TextPainter.getBoxesForSelection] to get this specific character's
/// tight cell bounds, so every sign centers precisely with zero hardcoded offsets.
class ZodiacIcon extends StatelessWidget {
  final String viName;
  final double size;
  const ZodiacIcon({super.key, required this.viName, this.size = 34});

  static const _purple = Color(0xFF8878C8);

  @override
  Widget build(BuildContext context) {
    return _IconBadge(
      tint: _purple,
      size: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _GlyphCenterPainter(
          glyph: zodiacGlyph(viName),
          color: _purple,
          fontSize: size * 0.60,
        ),
      ),
    );
  }
}

/// Paints a Unicode glyph centered on the canvas using the character's own
/// selection-box bounds — the most accurate measure of its rendered cell.
///
/// [getBoxesForSelection] returns the rectangle Flutter actually allocated for
/// this character. Centering on (b.right-b.left) × (b.bottom-b.top) rather
/// than on [TextPainter.width] × [TextPainter.height] removes the extra
/// ascender/descender padding that differs per glyph and causes visual offset.
class _GlyphCenterPainter extends CustomPainter {
  final String glyph;
  final Color color;
  final double fontSize;

  const _GlyphCenterPainter({
    required this.glyph,
    required this.color,
    required this.fontSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final tp = TextPainter(
      text: TextSpan(
        text: glyph,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          height: 1.0,
          // Four sub-pixel shadow offsets thicken the thin Unicode glyph.
          shadows: [
            Shadow(color: color, offset: const Offset(0.6, 0)),
            Shadow(color: color, offset: const Offset(-0.6, 0)),
            Shadow(color: color, offset: const Offset(0, 0.6)),
            Shadow(color: color, offset: const Offset(0, -0.6)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final boxes = tp.getBoxesForSelection(
      const TextSelection(baseOffset: 0, extentOffset: 1),
    );

    final double dx, dy;
    if (boxes.isNotEmpty) {
      final b = boxes.first;
      // Shift the paint origin so the character cell lands at canvas center.
      dx = (size.width  - (b.right  - b.left)) / 2 - b.left;
      dy = (size.height - (b.bottom - b.top))  / 2 - b.top;
    } else {
      dx = (size.width  - tp.width)  / 2;
      dy = (size.height - tp.height) / 2;
    }

    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(_GlyphCenterPainter old) =>
      old.glyph != glyph || old.color != color || old.fontSize != fontSize;
}

// ─── Ngũ Hành badge ───────────────────────────────────────────────────────────

class NguHanhIcon extends StatelessWidget {
  final String element;
  final double size;
  const NguHanhIcon({super.key, required this.element, this.size = 34});

  @override
  Widget build(BuildContext context) {
    final v = elementVisual(element);
    return _IconBadge(
      tint: v.color,
      size: size,
      child: Icon(v.icon, size: size * 0.52, color: v.color),
    );
  }
}

// ─── Thần Số Học badge ────────────────────────────────────────────────────────

class ThanSoIcon extends StatelessWidget {
  final int number;
  final double size;
  const ThanSoIcon({super.key, required this.number, this.size = 34});

  @override
  Widget build(BuildContext context) {
    return _IconBadge(
      tint: AppColors.berry,
      size: size,
      child: Text(
        '$number',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: size * 0.52,
          fontWeight: FontWeight.w800,
          color: AppColors.berry,
          height: 1.0,
        ),
      ),
    );
  }
}
