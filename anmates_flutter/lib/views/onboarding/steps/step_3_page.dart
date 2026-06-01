import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';
import '../widgets/step_layout.dart';

class Step3Page extends StatelessWidget {
  const Step3Page({super.key});

  @override
  Widget build(BuildContext context) {
    return const StepLayout(
      eyebrow: '03 · Nồi lẩu tự sôi',
      title: 'Trò chuyện đủ\nấm, mới chốt kèo.',
      body:
          'Vibe check từng bước — từ chat đến bữa ăn thật. Điểm tin cậy minh bạch, không sến, không lo.',
      illustration: _Step3Illustration(),
    );
  }
}

class _Step3Illustration extends StatelessWidget {
  const _Step3Illustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 265,
      child: Column(
        children: [
          const _HotpotWidget(),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _VibeBarSimple(percent: 72),
          ),
        ],
      ),
    );
  }
}

// ─── Animated boiling hotpot ──────────────────────────────────────────────────
class _HotpotWidget extends StatefulWidget {
  const _HotpotWidget();

  @override
  State<_HotpotWidget> createState() => _HotpotWidgetState();
}

class _HotpotWidgetState extends State<_HotpotWidget>
    with TickerProviderStateMixin {
  late final AnimationController _shakeCtrl;
  late final AnimationController _lidCtrl;
  late final AnimationController _steamCtrl;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
    )..repeat(reverse: true);

    _lidCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 660),
    )..repeat(reverse: true);

    _steamCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat();
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _lidCtrl.dispose();
    _steamCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return SizedBox(
        width: 190,
        height: 195,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: CustomPaint(
            size: const Size(170, 128),
            painter: const _HotpotPainter(),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_shakeCtrl, _lidCtrl, _steamCtrl]),
      builder: (context, _) {
        final shakeX = math.sin(_shakeCtrl.value * math.pi * 2) * 2.8;
        final shakeAngle = math.sin(_shakeCtrl.value * math.pi * 2) * 0.026;
        final lidY = Curves.easeInOut.transform(_lidCtrl.value) * -9.0;

        return SizedBox(
          width: 190,
          height: 195,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 10,
                bottom: 0,
                child: Transform.translate(
                  offset: Offset(shakeX, 0),
                  child: Transform.rotate(
                    angle: shakeAngle,
                    child: CustomPaint(
                      size: const Size(170, 128),
                      painter: _HotpotPainter(
                        lidOffsetY: lidY,
                        steamPhase: _steamCtrl.value,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Painter: original pot colors + animated flames + blurred steam ──────────
class _HotpotPainter extends CustomPainter {
  final double lidOffsetY;
  final double steamPhase;

  const _HotpotPainter({this.lidOffsetY = 0, this.steamPhase = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final potRect = Rect.fromLTWH(w * 0.1, h * 0.38, w * 0.8, h * 0.6);
    final potPath = Path()
      ..moveTo(w * 0.1, h * 0.38)
      ..lineTo(w * 0.9, h * 0.38)
      ..lineTo(w * 0.82, h * 0.93)
      ..quadraticBezierTo(w * 0.5, h, w * 0.18, h * 0.93)
      ..close();

    // Pot body
    final potPaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.ocean, AppColors.oceanDeep],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(potRect);
    canvas.drawPath(potPath, potPaint);

    // Side handles
    final handlePaint = Paint()
      ..color = AppColors.oceanDeep
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromLTWH(w * -0.04, h * 0.38, w * 0.18, h * 0.22),
      math.pi / 2,
      -math.pi,
      false,
      handlePaint,
    );
    canvas.drawArc(
      Rect.fromLTWH(w * 0.86, h * 0.38, w * 0.18, h * 0.22),
      math.pi / 2,
      math.pi,
      false,
      handlePaint,
    );

    // Steam (before lid so it appears from the gap)
    _drawSteam(canvas, size, steamPhase, lidOffsetY);

    // Lid (animated)
    canvas.save();
    canvas.translate(0, lidOffsetY);

    final lidPaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.berry, AppColors.berryDeep],
      ).createShader(Rect.fromLTWH(w * 0.05, h * 0.18, w * 0.9, h * 0.22));
    final lidPath = Path()
      ..moveTo(w * 0.05, h * 0.38)
      ..quadraticBezierTo(w * 0.5, h * 0.22, w * 0.95, h * 0.38)
      ..lineTo(w * 0.9, h * 0.38)
      ..quadraticBezierTo(w * 0.5, h * 0.26, w * 0.1, h * 0.38)
      ..close();
    canvas.drawPath(lidPath, lidPaint);

    // Knob
    final knobPaint = Paint()
      ..color = AppColors.mint
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.5, h * 0.2), 10, knobPaint);

    canvas.restore();
  }

  // 6 staggered blurred puffs rising from the lid gap
  void _drawSteam(Canvas canvas, Size size, double phase, double lidY) {
    final w = size.width;
    final h = size.height;
    final emitY = h * 0.30 + lidY;

    const puffConfigs = [
      (xFrac: 0.30, phaseOff: 0.00, driftAmp: 0.09, driftFreq: 2.3),
      (xFrac: 0.50, phaseOff: 0.17, driftAmp: -0.07, driftFreq: 2.8),
      (xFrac: 0.42, phaseOff: 0.33, driftAmp: 0.08, driftFreq: 2.0),
      (xFrac: 0.60, phaseOff: 0.50, driftAmp: -0.06, driftFreq: 3.1),
      (xFrac: 0.36, phaseOff: 0.66, driftAmp: 0.07, driftFreq: 2.5),
      (xFrac: 0.54, phaseOff: 0.83, driftAmp: -0.05, driftFreq: 1.8),
    ];

    for (final cfg in puffConfigs) {
      final raw = (phase + cfg.phaseOff) % 1.0;
      final opacity = raw < 0.18
          ? (raw / 0.18)
          : math.pow(1.0 - (raw - 0.18) / 0.82, 1.8).toDouble();
      final y = emitY - raw * h * 0.98;
      final radius = 7.0 + raw * 26.0;
      final x =
          w * cfg.xFrac +
          math.sin(raw * math.pi * cfg.driftFreq) * w * cfg.driftAmp;
      final blurSigma = 3.0 + raw * 16.0;

      final steamPaint = Paint()
        ..color = Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0) * 0.70)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: radius * 2.4,
          height: radius * 2.0,
        ),
        steamPaint,
      );
    }

    // Persistent soft base cloud at the lid gap
    final baseOpacity = 0.15 + math.sin(phase * math.pi * 2) * 0.08;
    final basePaint = Paint()
      ..color = Colors.white.withValues(alpha: baseOpacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, emitY - 4),
        width: w * 0.60,
        height: 20,
      ),
      basePaint,
    );
  }

  @override
  bool shouldRepaint(_HotpotPainter old) =>
      old.lidOffsetY != lidOffsetY || old.steamPhase != steamPhase;
}

class _VibeBarSimple extends StatelessWidget {
  final int percent;
  const _VibeBarSimple({required this.percent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.wisteria.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('VIBE CHECK', style: AppTextStyles.eyebrow()),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '$percent',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.berry,
                      ),
                    ),
                    TextSpan(
                      text: '/100',
                      style: AppTextStyles.mono(
                        size: 11,
                        color: AppColors.ink50,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 8,
              color: AppColors.ink10,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: percent / 100,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.ocean,
                        AppColors.wisteria,
                        AppColors.berry,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
