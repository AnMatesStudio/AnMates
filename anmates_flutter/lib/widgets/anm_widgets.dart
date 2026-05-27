import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'anm_logo.dart';

// ─── CTA Button ──────────────────────────────────────────────────────────────
class AnmCTA extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final Color background;
  final Color foreground;
  final bool fullWidth;
  final double? height;

  const AnmCTA({
    super.key,
    required this.label,
    this.onTap,
    this.background = AppColors.berry,
    this.foreground = Colors.white,
    this.fullWidth = true,
    this.height,
  });

  @override
  State<AnmCTA> createState() => _AnmCTAState();
}

class _AnmCTAState extends State<AnmCTA> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isBerry = widget.background == AppColors.berry;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      child: AnimatedScale(
        scale: (_hovered && widget.onTap != null) ? 1.025 : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: widget.fullWidth ? double.infinity : null,
          height: widget.height ?? 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: isBerry
                ? [
                    BoxShadow(
                      color: AppColors.berry.withValues(
                        alpha: (_hovered && widget.onTap != null) ? 0.50 : 0.35,
                      ),
                      blurRadius: (_hovered && widget.onTap != null) ? 36 : 24,
                      offset: (_hovered && widget.onTap != null)
                          ? const Offset(0, 12)
                          : const Offset(0, 8),
                    ),
                  ]
                : const [],
          ),
          child: ElevatedButton(
            onPressed: widget.onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.background,
              foregroundColor: widget.foreground,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 0),
              elevation: 0,
              shadowColor: Colors.transparent,
            ).copyWith(overlayColor: WidgetStateProperty.all(Colors.white12)),
            child: Text(
              widget.label,
              style: AppTextStyles.cta(color: widget.foreground),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Ghost Button ─────────────────────────────────────────────────────────────
class AnmGhostBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool dark;

  const AnmGhostBtn({
    super.key,
    required this.label,
    this.onTap,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: dark ? Colors.white : AppColors.ink,
        side: BorderSide(
          color: dark ? Colors.white24 : AppColors.ink10,
          width: 1.5,
        ),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: dark ? Colors.white : AppColors.ink,
        ),
      ),
    );
  }
}

// ─── Pill Chip / Tag ──────────────────────────────────────────────────────────
class AnmChip extends StatefulWidget {
  final String label;
  final bool active;
  final Color? color;
  final bool dark;
  final bool sm;
  final VoidCallback? onTap;

  const AnmChip({
    super.key,
    required this.label,
    this.active = false,
    this.color,
    this.dark = false,
    this.sm = false,
    this.onTap,
  });

  @override
  State<AnmChip> createState() => _AnmChipState();
}

class _AnmChipState extends State<AnmChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.color ?? AppColors.ink;
    final padding = widget.sm
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 10);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        scale: _hovered ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: padding,
            decoration: BoxDecoration(
              color: widget.active
                  ? activeColor
                  : _hovered
                  ? (widget.dark
                        ? Colors.white.withValues(alpha: 0.18)
                        : activeColor.withValues(alpha: 0.08))
                  : (widget.dark ? Colors.white12 : Colors.white),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: widget.active
                    ? Colors.transparent
                    : _hovered
                    ? (widget.dark
                          ? Colors.white38
                          : activeColor.withValues(alpha: 0.35))
                    : (widget.dark ? Colors.white24 : AppColors.ink10),
                width: 1,
              ),
            ),
            child: Text(
              widget.label,
              style: AppTextStyles.chip(
                active: widget.active,
                color: widget.dark ? Colors.white : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Eyebrow label ────────────────────────────────────────────────────────────
class Eyebrow extends StatelessWidget {
  final String text;
  final Color color;

  const Eyebrow(this.text, {super.key, this.color = AppColors.berry});

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: AppTextStyles.eyebrow(color: color));
  }
}

// ─── Screen title + subtitle ─────────────────────────────────────────────────
class ScreenTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool dark;
  final TextAlign align;

  const ScreenTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.dark = false,
    this.align = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align == TextAlign.center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.heading1(
            color: dark ? Colors.white : AppColors.ink,
          ),
          textAlign: align,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: AppTextStyles.body(
              size: 15,
              color: dark
                  ? Colors.white.withValues(alpha: 0.7)
                  : AppColors.ink70,
              height: 1.4,
            ),
            textAlign: align,
          ),
        ],
      ],
    );
  }
}

// ─── Photo Slot (placeholder) ─────────────────────────────────────────────────
class PhotoSlot extends StatelessWidget {
  final double? width;
  final double height;
  final String label;
  final double radius;
  final bool dark;

  const PhotoSlot({
    super.key,
    this.width,
    this.height = 180,
    this.label = 'PHOTO',
    this.radius = 20,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: dark
            ? const LinearGradient(
                colors: [Color(0xFF1A1A2E), Color(0xFF2E2870)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [
                  AppColors.wisteria.withValues(alpha: 0.3),
                  AppColors.mint,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        border: Border.all(
          color: dark ? Colors.white24 : AppColors.ink10,
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: AppTextStyles.mono(
            size: 10,
            color: dark ? Colors.white54 : AppColors.ink50,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}

// ─── Gradient Avatar ──────────────────────────────────────────────────────────
class AnmAvatar extends StatelessWidget {
  final double size;
  final int hue;
  final Color? ringColor;

  const AnmAvatar({super.key, this.size = 48, this.hue = 0, this.ringColor});

  static const _grads = [
    [AppColors.berry, AppColors.wisteria],
    [AppColors.ocean, AppColors.glaucous],
    [AppColors.wisteriaDeep, AppColors.berry],
    [AppColors.glaucous, AppColors.wisteria],
    [AppColors.berryDeep, AppColors.ocean],
    [AppColors.ocean, AppColors.wisteriaDeep],
  ];

  @override
  Widget build(BuildContext context) {
    final g = _grads[hue % _grads.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: g,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: ringColor != null
            ? Border.all(color: ringColor!, width: 2.5)
            : null,
      ),
    );
  }
}

// ─── Trust Score Ring ─────────────────────────────────────────────────────────
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

// ─── Vibe Progress Bar ────────────────────────────────────────────────────────
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
          // Title row
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
          // Progress bar with milestone overlays
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
          // Helper text
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

    // Track
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

    // Filled
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

    // Thumb
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

// ─── Bottom tab bar ───────────────────────────────────────────────────────────
class AnmTabBar extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int>? onTap;

  const AnmTabBar({super.key, this.activeIndex = 0, this.onTap});

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        icon: Icons.explore_outlined,
        activeIcon: Icons.explore,
        label: 'Khám phá',
      ),
      (
        icon: Icons.favorite_border,
        activeIcon: Icons.favorite,
        label: 'Wishlist',
      ),
      (
        icon: Icons.chat_bubble_outline,
        activeIcon: Icons.chat_bubble,
        label: 'Chat',
      ),
      (icon: Icons.person_outline, activeIcon: Icons.person, label: 'Mình'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.ink10, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final item = items[i];
              return _TabItem(
                icon: item.icon,
                activeIcon: item.activeIcon,
                label: item.label,
                active: i == activeIndex,
                onTap: () => onTap?.call(i),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    this.onTap,
  });

  @override
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.active
        ? AppColors.berry
        : _hovered
        ? AppColors.berry.withValues(alpha: 0.55)
        : AppColors.ink50;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _pressed
              ? 0.88
              : _hovered
              ? 1.10
              : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: SizedBox(
            width: 72,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    widget.active ? widget.activeIcon : widget.icon,
                    key: ValueKey(widget.active),
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 160),
                  style: AppTextStyles.body(
                    size: 11,
                    weight: widget.active ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                  ),
                  child: Text(widget.label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
