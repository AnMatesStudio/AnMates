import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TrustRing extends StatelessWidget {
  final int score;
  final double size;

  const TrustRing({super.key, this.score = 96, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final color = score >= 90
        ? AppColors.ocean
        : score >= 80
        ? AppColors.wisteriaDeep
        : AppColors.berry;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _TrustRingPainter(score / 100, color),
          ),
          Positioned(
            top: 4,
            left: 4,
            right: 4,
            bottom: 4,
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.wisteria, AppColors.berry],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                '$score',
                style: AppTextStyles.mono(
                  size: 10,
                  weight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  _TrustRingPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;
    final trackPaint = Paint()
      ..color = AppColors.ink10
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, trackPaint);

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_TrustRingPainter old) =>
      old.progress != progress || old.color != color;
}
