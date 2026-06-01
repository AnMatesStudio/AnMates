import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'anm_logo.dart';

// ─── Vibe stage definitions ────────────────────────────────────────────────
class _VibeStage {
  final int p;
  final String emoji;
  final String name;
  final bool gate;
  const _VibeStage({
    required this.p,
    required this.emoji,
    required this.name,
    this.gate = false,
  });
}

const _vibeStages = [
  _VibeStage(p: 0, emoji: '👋', name: 'Hi'),
  _VibeStage(p: 25, emoji: '💬', name: 'Tám'),
  _VibeStage(p: 50, emoji: '✨', name: 'Vibe'),
  _VibeStage(p: 70, emoji: '🍜', name: 'Date', gate: true),
  _VibeStage(p: 100, emoji: '🔥', name: 'Ăn miết'),
];

// ─── Vibe Progress Bar ─────────────────────────────────────────────────────
class VibeProgressBar extends StatelessWidget {
  final int percent;
  final bool unlocked;

  const VibeProgressBar({
    super.key,
    required this.percent,
    this.unlocked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  gradient: const LinearGradient(
                    colors: [AppColors.berry, AppColors.wisteriaDeep],
                  ),
                ),
                child: const Center(
                  child: Sparkle(size: 13, color: Colors.white, animated: true),
                ),
              ),
              const SizedBox(width: 8),
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [AppColors.ocean, AppColors.berry],
                ).createShader(b),
                child: Text(
                  'ĂN MATE VIBE CHECK',
                  style: AppTextStyles.mono(
                    size: 10,
                    weight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 1.8,
                  ),
                ),
              ),
              const Spacer(),
              ShaderMask(
                shaderCallback: (b) => LinearGradient(
                  colors: unlocked
                      ? [AppColors.berry, AppColors.berryDeep]
                      : [AppColors.wisteriaDeep, AppColors.berry],
                ).createShader(b),
                child: Text(
                  '$percent',
                  style: AppTextStyles.display(
                    size: 20,
                    weight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              Text(
                '/100',
                style: AppTextStyles.mono(size: 11, color: AppColors.ink50),
              ),
              if (unlocked)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.berry,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'UNLOCKED',
                    style: AppTextStyles.mono(
                      size: 9,
                      weight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (ctx, box) {
              final w = box.maxWidth;
              return SizedBox(
                height: 58,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 14,
                      left: 0,
                      right: 0,
                      height: 28,
                      child: CustomPaint(
                        painter: _VibeBarPainter(percent / 100),
                      ),
                    ),
                    for (final s in _vibeStages) ...[
                      Positioned(
                        left: (w * s.p / 100 - 1).clamp(0.0, w - 2),
                        top: 20,
                        child: Container(
                          width: 2,
                          height: 14,
                          decoration: BoxDecoration(
                            color: (s.p <= percent)
                                ? Colors.white.withValues(alpha: 0.7)
                                : AppColors.ink.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                      Positioned(
                        left: (w * s.p / 100 - 9).clamp(0.0, w - 18),
                        top: 44,
                        child: Text(
                          s.emoji,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      if (s.gate)
                        Positioned(
                          left: (w * s.p / 100 - 30).clamp(0.0, w - 62),
                          top: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.berry.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'FIRST DATE',
                              style: AppTextStyles.mono(
                                size: 7,
                                weight: FontWeight.w700,
                                color: AppColors.berry,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                unlocked ? '🎉' : '💌',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: AppTextStyles.body(size: 11, color: AppColors.ink70),
                    children: unlocked
                        ? [
                            const TextSpan(text: 'Vibe đã chín — '),
                            TextSpan(
                              text: 'chốt First Date',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.berry,
                              ),
                            ),
                            const TextSpan(text: ' được luôn!'),
                          ]
                        : [
                            const TextSpan(text: 'Tâm tình thêm để '),
                            TextSpan(
                              text: 'unlock First Date',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.berry,
                              ),
                            ),
                            const TextSpan(text: ' cùng Mate'),
                          ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VibeBarPainter extends CustomPainter {
  final double progress;
  _VibeBarPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final barTop = 8.0;
    final barH = 12.0;
    const radius = Radius.circular(999);

    final trackPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          AppColors.ocean,
          AppColors.glaucous,
          AppColors.wisteria,
          AppColors.berry,
          AppColors.berryDeep,
        ],
      ).createShader(Rect.fromLTWH(0, barTop, w, barH))
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, barTop, w, barH), radius),
      trackPaint..color = trackPaint.color.withValues(alpha: 0.18),
    );

    if (progress > 0) {
      final filledPaint = Paint()
        ..shader = const LinearGradient(
          colors: [
            AppColors.ocean,
            AppColors.glaucous,
            AppColors.wisteria,
            AppColors.berry,
            AppColors.berryDeep,
          ],
        ).createShader(Rect.fromLTWH(0, barTop, w, barH));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, barTop, w * progress, barH),
          radius,
        ),
        filledPaint,
      );
    }

    final thumbX = w * progress;
    final thumbPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final thumbBorderPaint = Paint()
      ..color = AppColors.berry
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(Offset(thumbX, barTop + barH / 2), 10, thumbPaint);
    canvas.drawCircle(Offset(thumbX, barTop + barH / 2), 10, thumbBorderPaint);
  }

  @override
  bool shouldRepaint(_VibeBarPainter old) => old.progress != progress;
}
