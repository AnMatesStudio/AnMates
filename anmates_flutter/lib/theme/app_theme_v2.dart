import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ─── ANM Design v2 tokens ────────────────────────────────────────────────────
/// Ported from the Claude Design project "Mobile app design planning"
/// (`AnMates.dc.html`, screen `home` — Canvas frame B1 "Explore · hero 3D collage").
///
/// This file is ADDITIVE. `app_theme.dart` (Berry/Ocean, Plus Jakarta Sans) is the
/// palette of the shipped app and stays untouched; v2 is the new Explore direction
/// and only the v2 views read these tokens.
class AppColorsV2 {
  // Accent — Wisteria is the highlight token of the new direction.
  static const wisteria = Color(0xFF8B5CF6);
  static const wisteriaTint = Color(0xFFF1EBFE);
  static const violetGlow = Color(0xFFA855F7);

  // Blues — the CTA gradient and the lower aurora lobe.
  static const blue = Color(0xFF3B82F0);
  static const blueDeep = Color(0xFF1F5BE0);
  static const cyan = Color(0xFF28D3F5);

  // Ink & surfaces
  static const ink = Color(0xFF121212);
  static const canvas = Color(0xFFF6F4FF);
  static const surface = Colors.white;

  /// Alert Red is deliberately reserved for urgency only (unread dot, "1H" tags).
  static const alert = Color(0xFFFF3B30);

  /// Rotating pastel beds behind food art — tiles cycle 4, open-table cards cycle 5.
  static const tileBeds = <Color>[
    Color(0xFFF2EEFF),
    Color(0xFFEAF4FF),
    Color(0xFFFFF3E8),
    Color(0xFFEFF8F1),
  ];
  static const cardBeds = <Color>[
    Color(0xFFEAF4FF),
    Color(0xFFFFF3E8),
    Color(0xFFF2EEFF),
    Color(0xFFEFF8F1),
    Color(0xFFFDF0F4),
  ];

  static Color inkA(double alpha) => ink.withValues(alpha: alpha);
  static Color whiteA(double alpha) => Colors.white.withValues(alpha: alpha);
}

class AppGradientsV2 {
  /// `linear-gradient(100deg, #3B82F0, #8B5CF6)` — primary CTA and sent bubbles.
  static const cta = LinearGradient(
    begin: Alignment(-1, -0.35),
    end: Alignment(1, 0.35),
    colors: [AppColorsV2.blue, AppColorsV2.wisteria],
  );
}

class AppShadowsV2 {
  /// Resting elevation for white pills and cards.
  static List<BoxShadow> get pill => [
    BoxShadow(
      color: const Color(0xFF0A285A).withValues(alpha: 0.10),
      blurRadius: 22,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get card => [
    BoxShadow(
      color: const Color(0xFF0A285A).withValues(alpha: 0.14),
      blurRadius: 22,
      offset: const Offset(0, 10),
    ),
  ];

  /// Violet-tinted lift under the CTA and the filter button.
  static List<BoxShadow> ctaGlow({double opacity = 0.38}) => [
    BoxShadow(
      color: const Color(0xFF5A50F0).withValues(alpha: opacity),
      blurRadius: 32,
      offset: const Offset(0, 14),
    ),
  ];
}

/// Be Vietnam Pro across the whole v2 surface — the design sets one family and
/// separates roles by weight/size, so there is no display/body split here.
class AppTextV2 {
  static TextStyle _f({
    required double size,
    required FontWeight weight,
    Color color = AppColorsV2.ink,
    double? height,
    double? letterSpacing,
  }) => GoogleFonts.beVietnamPro(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );

  /// Section headers — "Quán lẩu gần bạn", "Kèo mở tối nay".
  static TextStyle section({Color color = AppColorsV2.ink}) =>
      _f(size: 19, weight: FontWeight.w800, color: color, letterSpacing: -0.475);

  /// The 62px gradient number in the hero collage.
  static TextStyle heroNumber() =>
      _f(size: 62, weight: FontWeight.w800, height: 1, letterSpacing: -3.1);

  static TextStyle cta({Color color = Colors.white}) =>
      _f(size: 16, weight: FontWeight.w700, color: color);

  static TextStyle cardTitle({Color color = AppColorsV2.ink}) =>
      _f(size: 13, weight: FontWeight.w800, height: 1.25, color: color, letterSpacing: -0.195);

  static TextStyle tileTitle({Color color = AppColorsV2.ink}) =>
      _f(size: 12.5, weight: FontWeight.w700, height: 1.3, color: color);

  static TextStyle meta({Color? color}) =>
      _f(size: 10.5, weight: FontWeight.w500, color: color ?? AppColorsV2.inkA(0.45));

  static TextStyle body({Color? color, double size = 12}) =>
      _f(size: size, weight: FontWeight.w500, height: 1.5, color: color ?? AppColorsV2.inkA(0.58));

  static TextStyle name({Color color = AppColorsV2.ink, double size = 13}) =>
      _f(size: size, weight: FontWeight.w700, color: color);

  static TextStyle eyebrow({Color? color}) =>
      _f(size: 10.5, weight: FontWeight.w600, color: color ?? AppColorsV2.inkA(0.45), letterSpacing: 1.05);

  static TextStyle navLabel({required Color color}) =>
      _f(size: 9, weight: FontWeight.w700, color: color);

  static TextStyle stat({Color color = AppColorsV2.ink}) =>
      _f(size: 17, weight: FontWeight.w800, color: color);
}
