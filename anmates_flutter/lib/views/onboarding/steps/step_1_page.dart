import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/anm_logo.dart';
import '../widgets/step_layout.dart';

class Step1Page extends StatelessWidget {
  const Step1Page({super.key});

  @override
  Widget build(BuildContext context) {
    return const StepLayout(
      eyebrow: '01 · Chọn quán trước',
      title: 'Hôm nay ăn gì?\nChạm là ra ngay.',
      body:
          'Khám phá theo Genre & Vibe — lẩu sùng sục, cafe khuất hẻm, quán nướng xì xèo... Bookmark vào Wishlist để tính sau.',
      illustration: _Step1Illustration(),
    );
  }
}

enum _FoodKind { lau, cafe, nuong, vat }

class _Step1Illustration extends StatelessWidget {
  const _Step1Illustration();

  static const _cards = <_CardSpec>[
    _CardSpec(
      label: 'LẨU',
      display: 'Lẩu',
      kind: _FoodKind.lau,
      angleDeg: -8.0,
      top: 0.0,
      left: 14.0,
      accent: AppColors.berry,
      delayMs: 0,
    ),
    _CardSpec(
      label: 'CAFE CHILL',
      display: 'Cafe chill',
      kind: _FoodKind.cafe,
      angleDeg: 6.0,
      top: 6.0,
      left: 148.0,
      accent: AppColors.wisteriaDeep,
      delayMs: 90,
    ),
    _CardSpec(
      label: 'ĐỒ NƯỚNG',
      display: 'Đồ nướng',
      kind: _FoodKind.nuong,
      angleDeg: -4.0,
      top: 170.0,
      left: 24.0,
      accent: AppColors.berryDeep,
      delayMs: 180,
    ),
    _CardSpec(
      label: 'ĂN VẶT',
      display: 'ăn vặt',
      kind: _FoodKind.vat,
      angleDeg: 10.0,
      top: 162.0,
      left: 158.0,
      accent: AppColors.ocean,
      delayMs: 270,
    ),
  ];

  // Intrinsic dimensions of the polaroid stage — FittedBox scales it down
  // on small screens (iPhone 11/12/13 logical width 375pt).
  static const double _stageW = 300;
  static const double _stageH = 340;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.contain,
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: _stageW,
        height: _stageH,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Sparkle accent (top-right, near Cafe chill card)
            const Positioned(
              top: -8,
              right: 6,
              child: Sparkle(size: 26, color: Colors.white, animated: true),
            ),
            for (int i = 0; i < _cards.length; i++)
              Positioned(
                top: _cards[i].top,
                left: _cards[i].left,
                child: _FoodCard(spec: _cards[i]),
              ),
          ],
        ),
      ),
    );
  }
}

class _CardSpec {
  final String label;
  final String display;
  final _FoodKind kind;
  final double angleDeg;
  final double top;
  final double left;
  final Color accent;
  final int delayMs;

  const _CardSpec({
    required this.label,
    required this.display,
    required this.kind,
    required this.angleDeg,
    required this.top,
    required this.left,
    required this.accent,
    required this.delayMs,
  });
}

class _FoodCard extends StatefulWidget {
  final _CardSpec spec;

  const _FoodCard({required this.spec});

  @override
  State<_FoodCard> createState() => _FoodCardState();
}

class _FoodCardState extends State<_FoodCard> with TickerProviderStateMixin {
  bool _hovered = false;
  bool _pressed = false;

  late final AnimationController _floatCtrl;
  late final Animation<double> _floatAnim;

  late final AnimationController _enterCtrl;
  late final Animation<double> _enterScale;
  late final Animation<double> _enterFade;
  late final Animation<double> _enterOffset;

  @override
  void initState() {
    super.initState();

    // Ambient float (out-of-sync per card)
    final floatMs = 2200 + (widget.spec.label.hashCode.abs() % 800);
    _floatCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: floatMs),
    );
    _floatAnim = Tween<double>(
      begin: -4.0,
      end: 4.0,
    ).animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    // Staggered drop-in entry
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _enterScale = Tween<double>(
      begin: 0.72,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.elasticOut));
    _enterFade = CurvedAnimation(
      parent: _enterCtrl,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );
    _enterOffset = Tween<double>(
      begin: 36.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: widget.spec.delayMs), () {
      if (!mounted) return;
      _enterCtrl.forward().then((_) {
        final floatDelay = (widget.spec.label.length * 90) % 600;
        Future.delayed(Duration(milliseconds: floatDelay), () {
          if (mounted) _floatCtrl.repeat(reverse: true);
        });
      });
    });
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _enterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Slightly straighten when hovered (snap to upright reads as "selecting")
    final liveAngleDeg = _hovered
        ? widget.spec.angleDeg * 0.35
        : widget.spec.angleDeg;
    final scale = _pressed
        ? 0.94
        : _hovered
        ? 1.08
        : 1.0;

    return AnimatedBuilder(
      animation: Listenable.merge([_floatCtrl, _enterCtrl]),
      builder: (_, child) {
        return Opacity(
          opacity: _enterFade.value,
          child: Transform.translate(
            offset: Offset(0, _floatAnim.value + _enterOffset.value),
            child: Transform.scale(scale: _enterScale.value, child: child),
          ),
        );
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedRotation(
            turns: liveAngleDeg / 360,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutBack,
            child: AnimatedScale(
              scale: scale,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                width: 122,
                height: 156,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: widget.spec.accent.withValues(
                        alpha: _hovered ? 0.42 : 0.18,
                      ),
                      blurRadius: _hovered ? 28 : 16,
                      offset: Offset(0, _hovered ? 14 : 8),
                    ),
                  ],
                  border: Border.all(
                    color: _hovered
                        ? widget.spec.accent.withValues(alpha: 0.45)
                        : AppColors.ink10,
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  child: Column(
                    children: [
                      // Polaroid photo area — illustrated food asset
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              AnimatedScale(
                                scale: _hovered ? 1.08 : 1.0,
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOut,
                                child: Image.asset(
                                  _assetFor(widget.spec.kind),
                                  fit: BoxFit.cover,
                                  filterQuality: FilterQuality.medium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Polaroid caption (formal label)
                      Text(
                        widget.spec.display,
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Food kind → asset path ──────────────────────────────────────────────────
String _assetFor(_FoodKind kind) {
  switch (kind) {
    case _FoodKind.lau:
      return 'assets/food/lau.png';
    case _FoodKind.cafe:
      return 'assets/food/cafe.png';
    case _FoodKind.nuong:
      return 'assets/food/nuong.png';
    case _FoodKind.vat:
      return 'assets/food/vat.png';
  }
}
