import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/app_theme_v2.dart';
import '../../views/v2/v2_data.dart';

/// The four-lobe aurora wash + film grain that every v2 screen sits on.
///
/// Ports the shell background of `AnMates.dc.html`:
/// ```
/// radial-gradient(78% 42% at 50%  -4%, #A855F7 …)
/// radial-gradient(86% 40% at 50% 104%, #1F5BE0 → #3B82F0 …)
/// radial-gradient(60% 30% at  8%  16%, #28D3F5 …)
/// radial-gradient(58% 28% at 94%  88%, #8B5CF6 …)
/// ```
/// Flows B–D run the wash 30% softer so cards and glass read cleanly, which is
/// why [washOpacity] defaults to the design's `SOFT_BG` values rather than 0.8/0.24.
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({
    super.key,
    this.washOpacity = 0.56,
    this.grainOpacity = 0.18,
  });

  final double washOpacity;
  final double grainOpacity;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: AppColorsV2.canvas),
          Opacity(
            opacity: washOpacity,
            child: const CustomPaint(painter: _AuroraPainter()),
          ),
          // `background-image:url(assets/grain.png); background-size:120px 120px`
          Opacity(
            opacity: grainOpacity,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: ExactAssetImage(
                    A.grain,
                    scale: kGrainSourceSize / kGrainTileSize,
                  ),
                  repeat: ImageRepeat.repeat,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One CSS `radial-gradient(<rx> <ry> at <cx> <cy>, …)` lobe, all values fractional.
class _Lobe {
  const _Lobe(this.rx, this.ry, this.cx, this.cy, this.colors, this.stops);

  final double rx;
  final double ry;
  final double cx;
  final double cy;
  final List<Color> colors;
  final List<double> stops;
}

/// The onboarding blob (A1–A4): a separate gradient stack from the shell wash —
/// deeper blue at the bottom, cyan on the left, violet top-right — masked to an
/// ellipse so it reads as a glow floating on white.
class AuroraBlob extends StatelessWidget {
  const AuroraBlob({super.key, this.grainOpacity = 0.3});

  final double grainOpacity;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(fit: StackFit.expand, children: [
        CustomPaint(painter: _AuroraPainter(lobes: _BlobPainter.lobes)),
        Opacity(
          opacity: grainOpacity,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: ExactAssetImage(
                  A.grain,
                  scale: kGrainSourceSize / kGrainTileSize,
                ),
                repeat: ImageRepeat.repeat,
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _BlobPainter {
  static const lobes = <_Lobe>[
    _Lobe(0.96, 0.58, 0.50, 0.88, [
      AppColorsV2.blueDeep,
      AppColorsV2.blue,
      Color(0x003B82F0),
    ], [0.0, 0.32, 0.74]),
    _Lobe(0.70, 0.44, 0.15, 0.44, [
      AppColorsV2.cyan,
      Color(0xB828D3F5),
      Color(0x0028D3F5),
    ], [0.0, 0.32, 0.72]),
    _Lobe(0.64, 0.42, 0.89, 0.27, [
      AppColorsV2.violetGlow,
      Color(0xADA855F7),
      Color(0x00A855F7),
    ], [0.0, 0.34, 0.74]),
    _Lobe(0.56, 0.32, 0.62, 0.62, [
      Color(0xFF22B8F0),
      Color(0x0022B8F0),
    ], [0.0, 0.72]),
  ];
}

class _AuroraPainter extends CustomPainter {
  const _AuroraPainter({this.lobes = _shellLobes});

  final List<_Lobe> lobes;

  static const _shellLobes = <_Lobe>[
    _Lobe(0.78, 0.42, 0.50, -0.04, [
      AppColorsV2.violetGlow,
      Color(0xB8A855F7), // rgba(168,85,247,.72)
      Color(0x00A855F7),
    ], [0.0, 0.34, 0.76]),
    _Lobe(0.86, 0.40, 0.50, 1.04, [
      AppColorsV2.blueDeep,
      AppColorsV2.blue,
      Color(0x003B82F0),
    ], [0.0, 0.32, 0.78]),
    _Lobe(0.60, 0.30, 0.08, 0.16, [
      AppColorsV2.cyan,
      Color(0x0028D3F5),
    ], [0.0, 0.72]),
    _Lobe(0.58, 0.28, 0.94, 0.88, [
      AppColorsV2.wisteria,
      Color(0x008B5CF6),
    ], [0.0, 0.74]),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // CSS paints the first gradient on top; Flutter paints last-drawn on top.
    for (final lobe in lobes.reversed) {
      final center = Offset(lobe.cx * size.width, lobe.cy * size.height);
      final rx = lobe.rx * size.width;
      final ry = lobe.ry * size.height;
      if (rx <= 0 || ry <= 0) continue;

      // Gradient.radial is circular; squash the circle of radius rx into an
      // rx × ry ellipse about the lobe centre.
      final squash = Matrix4.identity()
        ..translateByDouble(center.dx, center.dy, 0, 1)
        ..scaleByDouble(1, ry / rx, 1, 1)
        ..translateByDouble(-center.dx, -center.dy, 0, 1);

      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(
            center,
            rx,
            lobe.colors,
            lobe.stops,
            TileMode.clamp,
            squash.storage,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) => oldDelegate.lobes != lobes;
}
