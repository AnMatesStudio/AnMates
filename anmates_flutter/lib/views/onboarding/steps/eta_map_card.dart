import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';

/// Dark-mode ETA map card used inside Step 4 (location permission flow).
///
/// Renders a stylised mini-map: grid backdrop, dashed route that marches
/// toward the destination, a motorbike marker that rides the route, and
/// in-card BẠN / HAIDILAO labels with ETA. All animation values are
/// driven externally so a single parent [AnimationController] can
/// coordinate the whole scene.
class EtaMapCard extends StatelessWidget {
  /// 0→1 — how much of the dashed route has drawn in.
  final double lineProgress;

  /// 1.0–1.4 — destination bubble pulse after the route arrives.
  final double destPulse;

  /// 0→1 looping — motorbike ride + dash-pattern shift.
  final double travelT;

  const EtaMapCard({
    required this.lineProgress,
    required this.destPulse,
    required this.travelT,
    super.key,
  });

  static const double _cardH = 196;
  static const Color _cardBg = Color(0xFF1A1A2A);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        const h = _cardH;
        // Route endpoints as fractions of the card so it scales with width.
        final origin = Offset(w * 0.17, h * 0.52);
        final dest = Offset(w * 0.80, h * 0.28);

        // Motorbike position + heading along the route (loops via travelT).
        final bikePos = Offset.lerp(origin, dest, travelT)!;
        final routeVec = dest - origin;
        final bikeAngle = math.atan2(routeVec.dy, routeVec.dx);
        // Fade at the very start/end of each loop to hide the reset jump.
        double bikeOpacity;
        if (travelT < 0.12) {
          bikeOpacity = travelT / 0.12;
        } else if (travelT > 0.88) {
          bikeOpacity = (1 - travelT) / 0.12;
        } else {
          bikeOpacity = 1.0;
        }
        bikeOpacity = (bikeOpacity * lineProgress).clamp(0.0, 1.0);

        return Container(
          width: double.infinity,
          height: h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: _cardBg,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.34),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                // Grid backdrop
                CustomPaint(size: Size(w, h), painter: _MapGridPainter()),
                // Bottom scrim so the in-card labels stay legible over the grid
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 78,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [_cardBg.withValues(alpha: 0.0), _cardBg],
                      ),
                    ),
                  ),
                ),
                // Animated dashed line (marches toward dest with travelT)
                CustomPaint(
                  size: Size(w, h),
                  painter: _DashedRoutePainter(
                    start: origin,
                    end: dest,
                    progress: lineProgress,
                    phase: travelT,
                  ),
                ),
                // Purple dot — BẠN (origin)
                Positioned(
                  left: origin.dx - 9,
                  top: origin.dy - 9,
                  child: _RouteDot(color: AppColors.wisteria, pulseScale: 1.0),
                ),
                // Destination bubble — food spot (pulses on arrival)
                Positioned(
                  left: dest.dx - 23,
                  top: dest.dy - 23,
                  child: Opacity(
                    opacity: lineProgress.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: lineProgress >= 0.95 ? destPulse : 1.0,
                      child: const _DestBubble(),
                    ),
                  ),
                ),
                // Motorbike riding origin → destination (loops)
                Positioned(
                  left: bikePos.dx - 15,
                  top: bikePos.dy - 15,
                  child: Opacity(
                    opacity: bikeOpacity,
                    child: Transform.rotate(
                      angle: bikeAngle,
                      child: const _MotorbikeMarker(),
                    ),
                  ),
                ),
                // In-card labels along the bottom
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 16,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      _CardLabel(
                        eyebrow: 'BẠN',
                        value: 'ETA 12 phút',
                        alignRight: false,
                      ),
                      _CardLabel(
                        eyebrow: 'HAIDILAO Q.1',
                        value: 'Hẹn 19:00',
                        alignRight: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Destination bubble: glowing ring + food icon ───────────────────────────
class _DestBubble extends StatelessWidget {
  const _DestBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.berry.withValues(alpha: 0.20),
        border: Border.all(color: AppColors.berry, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.berry.withValues(alpha: 0.55),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.ramen_dining, color: Colors.white, size: 22),
    );
  }
}

// ─── Small motorbike marker that rides the ETA route ─────────────────────────
class _MotorbikeMarker extends StatelessWidget {
  const _MotorbikeMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.berry.withValues(alpha: 0.6),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.two_wheeler, color: AppColors.berry, size: 17),
    );
  }
}

// ─── In-card route label (uppercase eyebrow + bold value) ────────────────────
class _CardLabel extends StatelessWidget {
  final String eyebrow;
  final String value;
  final bool alignRight;

  const _CardLabel({
    required this.eyebrow,
    required this.value,
    required this.alignRight,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.42),
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

// ─── Map grid backdrop ────────────────────────────────────────────────────────
class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.055)
      ..strokeWidth = 1.0;

    // Horizontal lines
    for (double y = 0; y < size.height; y += 22) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Vertical lines
    for (double x = 0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_MapGridPainter _) => false;
}

// ─── Dashed route line (draws in from start→end per progress 0→1) ─────────
class _DashedRoutePainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final double progress; // 0→1 draw-in
  final double phase; // 0→1 marches dashes toward the destination

  const _DashedRoutePainter({
    required this.start,
    required this.end,
    required this.progress,
    this.phase = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final vec = end - start;
    final totalLen = vec.distance;
    if (totalLen == 0) return;

    final dir = vec / totalLen;
    final drawnLen = totalLen * progress;

    const dashLen = 7.0;
    const gapLen = 5.0;
    const pattern = dashLen + gapLen;
    const marchCycles =
        4; // full dash-pattern shifts per travel loop (seamless)

    final paint = Paint()
      ..color = AppColors.berry.withValues(alpha: 0.88)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Shift the whole pattern forward so the dashes march toward the dest.
    final shift = ((phase * marchCycles) % 1.0) * pattern;
    double d = shift - pattern;
    while (d < drawnLen) {
      final segStart = math.max(d, 0.0);
      final segEnd = math.min(d + dashLen, drawnLen);
      if (segEnd > segStart) {
        canvas.drawLine(start + dir * segStart, start + dir * segEnd, paint);
      }
      d += pattern;
    }
  }

  @override
  bool shouldRepaint(_DashedRoutePainter old) =>
      old.progress != progress ||
      old.phase != phase ||
      old.start != start ||
      old.end != end;
}

// ─── Route dot (pulsing ring + solid core) ───────────────────────────────────
class _RouteDot extends StatelessWidget {
  final Color color;
  final double pulseScale;
  const _RouteDot({required this.color, this.pulseScale = 1.0});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: pulseScale,
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow halo ring
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.28),
            ),
          ),
          // Bright core
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.65),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
