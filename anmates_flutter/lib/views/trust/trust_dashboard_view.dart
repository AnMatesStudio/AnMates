import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/anm_logo.dart';
import '../../widgets/anm_widgets.dart';

// ─── Trust event model ────────────────────────────────────────────────────────

class _TrustEvent {
  final String icon;
  final String description;
  final String when;
  final int delta;
  final Color color;
  const _TrustEvent({
    required this.icon,
    required this.description,
    required this.when,
    required this.delta,
    required this.color,
  });
}

// ─── TrustDashboardView ───────────────────────────────────────────────────────

class TrustDashboardView extends StatelessWidget {
  const TrustDashboardView({super.key});

  static const int _score = 96;
  static const double _percent = 0.96;

  static const _events = [
    _TrustEvent(
      icon: '✓',
      description: 'Check-in đúng giờ · Ramen Q1',
      when: 'hôm qua',
      delta: 2,
      color: AppColors.ocean,
    ),
    _TrustEvent(
      icon: '📝',
      description: 'Review chi tiết kèm hình',
      when: 'hôm qua',
      delta: 3,
      color: AppColors.berry,
    ),
    _TrustEvent(
      icon: '⭐',
      description: 'Khánh đánh giá 5★ · lịch sự',
      when: 'hôm qua',
      delta: 1,
      color: AppColors.wisteria,
    ),
    _TrustEvent(
      icon: '🐢',
      description: 'Trễ 18\' · tắc đường (miễn 1 phần)',
      when: '3 ngày trước',
      delta: -2,
      color: AppColors.glaucous,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mint,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                children: [
                  _buildHeroRing(),
                  const SizedBox(height: 16),
                  _buildTierLadder(),
                  const SizedBox(height: 16),
                  _buildActivityLog(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.ink10)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: AppColors.ink,
            onPressed: () => Navigator.maybePop(context),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('TRUST SCORE'),
              const SizedBox(height: 2),
              Text(
                'Hồ sơ uy tín',
                style: AppTextStyles.display(
                  size: 16,
                  weight: FontWeight.w700,
                  color: AppColors.ink,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.ink10,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.help_outline_rounded,
              size: 18,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero ring ──────────────────────────────────────────────────────────────

  Widget _buildHeroRing() {
    return Center(
      child: Column(
        children: [
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer sparkle decoration
                Positioned(
                  top: 10,
                  right: 14,
                  child: Sparkle(size: 20, color: AppColors.wisteria),
                ),
                Positioned(
                  bottom: 14,
                  left: 12,
                  child: Sparkle(
                    size: 14,
                    color: AppColors.berry.withValues(alpha: 0.5),
                  ),
                ),
                // Ring
                CustomPaint(
                  size: const Size(180, 180),
                  painter: _TrustScoreRingPainter(progress: _percent),
                ),
                // Center content
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ShaderMask(
                      shaderCallback: (b) => const LinearGradient(
                        colors: [AppColors.wisteria, AppColors.berry],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(b),
                      child: Text(
                        '$_score',
                        style: AppTextStyles.display(
                          size: 56,
                          weight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -2,
                        ),
                      ),
                    ),
                    Text(
                      '/100 ĐIỂM',
                      style: AppTextStyles.mono(
                        size: 11,
                        color: AppColors.ink50,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Badge pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.berry.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.berry.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Sparkle(size: 14, color: AppColors.berry),
                const SizedBox(width: 6),
                Text(
                  'PERFECT MATE · Top 8%',
                  style: AppTextStyles.mono(
                    size: 11,
                    weight: FontWeight.w700,
                    color: AppColors.berry,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tier ladder ────────────────────────────────────────────────────────────

  Widget _buildTierLadder() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.ink10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('NGƯỠNG UY TÍN'),
          const SizedBox(height: 14),
          // Progress track
          _TierProgressTrack(progress: _percent),
          const SizedBox(height: 14),
          // Legend
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.ink10,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LegendRow('≥90', 'Perfect', AppColors.berry),
                const SizedBox(height: 4),
                _LegendRow('80–89', 'Trusted', AppColors.ocean),
                const SizedBox(height: 4),
                _LegendRow('<80', 'Giới hạn 1 phòng chat', AppColors.glaucous),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Activity log ───────────────────────────────────────────────────────────

  Widget _buildActivityLog() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('HOẠT ĐỘNG GẦN ĐÂY'),
        const SizedBox(height: 10),
        ..._events.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _EventCard(event: e),
          ),
        ),
      ],
    );
  }
}

// ─── Trust Score Ring Painter ─────────────────────────────────────────────────

class _TrustScoreRingPainter extends CustomPainter {
  final double progress;
  const _TrustScoreRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const strokeWidth = 14.0;

    // Track
    final trackPaint = Paint()
      ..color = AppColors.ink10
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Gradient arc
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweepAngle = 2 * math.pi * progress;

    // Build gradient shader along the arc path
    final gradientPaint = Paint()
      ..shader = const SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + 2 * math.pi,
        colors: [AppColors.wisteria, AppColors.berry, AppColors.berryDeep],
        stops: [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, gradientPaint);
  }

  @override
  bool shouldRepaint(_TrustScoreRingPainter old) => old.progress != progress;
}

// ─── Tier Progress Track ──────────────────────────────────────────────────────

class _TierProgressTrack extends StatelessWidget {
  final double progress;
  const _TierProgressTrack({required this.progress});

  @override
  Widget build(BuildContext context) {
    const milestones = [0, 80, 90, 96, 100];

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return Column(
          children: [
            SizedBox(
              height: 28,
              child: CustomPaint(
                size: Size(w, 28),
                painter: _TierTrackPainter(progress: progress),
              ),
            ),
            const SizedBox(height: 6),
            // Milestone labels
            SizedBox(
              height: 16,
              child: Stack(
                children: milestones.map((m) {
                  final x = (m / 100) * w;
                  final isYou = m == 96;
                  return Positioned(
                    left: x - (isYou ? 16 : 10),
                    child: Column(
                      children: [
                        Text(
                          isYou ? 'YOU' : '$m',
                          style: AppTextStyles.mono(
                            size: isYou ? 9 : 8,
                            weight: isYou ? FontWeight.w700 : FontWeight.w500,
                            color: isYou ? AppColors.berry : AppColors.ink50,
                            letterSpacing: isYou ? 0.5 : 0,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TierTrackPainter extends CustomPainter {
  final double progress;
  const _TierTrackPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    const barTop = 8.0;
    const barH = 12.0;
    const r = Radius.circular(999);

    // Background track
    final trackPaint = Paint()
      ..color = AppColors.ink10
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, barTop, w, barH), r),
      trackPaint,
    );

    // Filled gradient
    final filledPaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.ocean, AppColors.berry],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(0, barTop, w, barH))
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, barTop, w * progress, barH), r),
      filledPaint,
    );

    // Milestone dots at 0, 80, 90, 100
    const milestones = [0, 80, 90, 100];
    for (final m in milestones) {
      final x = (m / 100) * w;
      final dotPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      final borderPaint = Paint()
        ..color = m <= (progress * 100).round()
            ? AppColors.berry
            : AppColors.ink30
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(Offset(x, barTop + barH / 2), 5, dotPaint);
      canvas.drawCircle(Offset(x, barTop + barH / 2), 5, borderPaint);
    }

    // YOU marker at 96%
    final youX = w * progress;
    final youPaint = Paint()
      ..color = AppColors.berry
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(youX, barTop + barH / 2), 7, youPaint);
    final youBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(youX, barTop + barH / 2), 7, youBorderPaint);
  }

  @override
  bool shouldRepaint(_TierTrackPainter old) => old.progress != progress;
}

// ─── Legend Row ───────────────────────────────────────────────────────────────

class _LegendRow extends StatelessWidget {
  final String range;
  final String label;
  final Color color;
  const _LegendRow(this.range, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$range: ',
          style: AppTextStyles.mono(
            size: 10,
            weight: FontWeight.w700,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.body(size: 12, color: AppColors.ink70),
        ),
      ],
    );
  }
}

// ─── Event Card ───────────────────────────────────────────────────────────────

class _EventCard extends StatelessWidget {
  final _TrustEvent event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final isPositive = event.delta >= 0;
    final deltaColor = isPositive ? AppColors.ocean : AppColors.berryDeep;
    final deltaStr = isPositive ? '+${event.delta}' : '${event.delta}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.ink10),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: event.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(event.icon, style: const TextStyle(fontSize: 17)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.description,
                  style: AppTextStyles.body(
                    size: 13,
                    weight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  event.when,
                  style: AppTextStyles.mono(
                    size: 10,
                    color: AppColors.ink50,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: deltaColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              deltaStr,
              style: AppTextStyles.mono(
                size: 12,
                weight: FontWeight.w700,
                color: deltaColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
