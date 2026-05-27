import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/anm_logo.dart';
import '../../widgets/anm_widgets.dart';
import '../auth/phone_input_view.dart';
import '../main_tab_view.dart';

class OnboardingView extends StatefulWidget {
  final VoidCallback? onFinished;

  const OnboardingView({super.key, this.onFinished});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const int _totalPages = 3;

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _navigateAway();
    }
  }

  void _skip() {
    _navigateAway();
  }

  void _navigateAway() {
    if (widget.onFinished != null) {
      widget.onFinished!();
    } else {
      // Capture NavigatorState BEFORE pushReplacement disposes this State —
      // otherwise the onAuthenticated callback fires against an unmounted
      // context and silently no-ops.
      final navigator = Navigator.of(context);
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => PhoneInputView(
            onAuthenticated: () => navigator.pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const MainTabView()),
              (_) => false,
            ),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          ScrollConfiguration(
            // Enable horizontal swipe via touch + mouse + trackpad + stylus
            // (Flutter web disables mouse drag on scroll widgets by default).
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: const {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
                PointerDeviceKind.stylus,
              },
              scrollbars: false,
            ),
            child: PageView(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (i) => setState(() => _currentPage = i),
              children: const [_Step1Page(), _Step2Page(), _Step3Page()],
            ),
          ),
          // Top bar overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const LogoMark(size: 32),
                  GestureDetector(
                    onTap: _skip,
                    child: Text(
                      'Bỏ qua',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.ink70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom controls overlay
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomControls(
              currentPage: _currentPage,
              totalPages: _totalPages,
              onNext: _nextPage,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bottom controls (dots + button) ─────────────────────────────────────────
class _BottomControls extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final VoidCallback onNext;

  const _BottomControls({
    required this.currentPage,
    required this.totalPages,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Dot indicators
          Row(
            children: List.generate(totalPages, (i) {
              final active = i == currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                margin: const EdgeInsets.only(right: 6),
                width: active ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: active ? AppColors.berry : AppColors.ink30,
                ),
              );
            }),
          ),
          // CTA button
          GestureDetector(
            onTap: onNext,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.berry, AppColors.berryDeep],
                ),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.berry.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Text(
                currentPage == totalPages - 1 ? 'Bắt đầu →' : 'Tiếp tục →',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared step layout ───────────────────────────────────────────────────────
class _StepLayout extends StatelessWidget {
  final Color backgroundColor;
  final String eyebrow;
  final String title;
  final String body;
  final Widget illustration;

  const _StepLayout({
    required this.backgroundColor,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.illustration,
  });

  @override
  Widget build(BuildContext context) {
    // Responsive scaling — small iPhones (≤375pt: SE/mini) get tighter spacing
    // and smaller title; larger devices (Pro Max) keep generous spacing.
    final media = MediaQuery.of(context);
    final w = media.size.width;
    final h = media.size.height;
    final isCompact = w <= 380 || h <= 700;

    final illustrationTopPad = isCompact ? 56.0 : 88.0;
    final bottomPad = isCompact ? 100.0 : 120.0;
    final titleSize = isCompact ? 28.0 : 32.0;
    final bodySize = isCompact ? 14.0 : 15.0;
    final horizontalPad = isCompact ? 22.0 : 28.0;

    return Container(
      color: backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Illustration area
          Expanded(
            flex: 5,
            child: Padding(
              padding: EdgeInsets.only(
                top: illustrationTopPad,
                left: 16,
                right: 16,
              ),
              child: Center(child: illustration),
            ),
          ),
          // Text area
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPad,
              0,
              horizontalPad,
              bottomPad,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow(eyebrow),
                SizedBox(height: isCompact ? 8 : 10),
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    height: 1.15,
                    letterSpacing: -1.2,
                  ),
                ),
                SizedBox(height: isCompact ? 10 : 12),
                Text(
                  body,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: bodySize,
                    color: AppColors.ink70,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step 1 ───────────────────────────────────────────────────────────────────
class _Step1Page extends StatelessWidget {
  const _Step1Page();

  @override
  Widget build(BuildContext context) {
    return _StepLayout(
      backgroundColor: AppColors.mint,
      eyebrow: '01 · Chọn quán trước',
      title: 'Hôm nay ăn gì?\nChạm là ra ngay.',
      body:
          'Khám phá theo Genre & Vibe — lẩu sùng sục, cafe khuất hẻm, quán nướng xì xèo... Bookmark vào Wishlist để tính sau.',
      illustration: const _Step1Illustration(),
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
              child: Sparkle(size: 26, color: AppColors.berry, animated: true),
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

// ─── Step 2 ───────────────────────────────────────────────────────────────────
class _Step2Page extends StatelessWidget {
  const _Step2Page();

  @override
  Widget build(BuildContext context) {
    return _StepLayout(
      backgroundColor: const Color(0xFFFAF1F5),
      eyebrow: '02 · Match cùng quán',
      title: 'Ai cũng đang\nthèm quán này?',
      body:
          'Xem ai trong vùng đang đói cùng món. Ghép Mate, hẹn bàn, chia bill — không còn ăn một mình.',
      illustration: const _Step2Illustration(),
    );
  }
}

class _Step2Illustration extends StatelessWidget {
  const _Step2Illustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Stacked mate cards
          Positioned(
            top: 30,
            child: Transform.rotate(
              angle: -6 * 3.14159 / 180,
              child: _MateCard(hue: 2),
            ),
          ),
          Positioned(
            top: 15,
            child: Transform.rotate(
              angle: 4 * 3.14159 / 180,
              child: _MateCard(hue: 1),
            ),
          ),
          Positioned(top: 0, child: _MateCard(hue: 0)),
          // Berry heart badge
          Positioned(
            top: 0,
            right: 20,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.berry,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.berry.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.favorite, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MateCard extends StatelessWidget {
  final int hue;
  const _MateCard({required this.hue});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.ink10,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            AnmAvatar(size: 48, hue: hue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 10,
                    width: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: AppColors.ink10,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 8,
                    width: 110,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: AppColors.ink10,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.berry.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Mate',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.berry,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Step 3 ───────────────────────────────────────────────────────────────────
class _Step3Page extends StatelessWidget {
  const _Step3Page();

  @override
  Widget build(BuildContext context) {
    return _StepLayout(
      backgroundColor: const Color(0xFFF2EEFB),
      eyebrow: '03 · Nồi lẩu tự sôi',
      title: 'Trò chuyện đủ\nấm, mới chốt kèo.',
      body:
          'Vibe check từng bước — từ chat đến bữa ăn thật. Điểm tin cậy minh bạch, không sến, không lo.',
      illustration: const _Step3Illustration(),
    );
  }
}

class _Step3Illustration extends StatelessWidget {
  const _Step3Illustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 220,
      child: Column(
        children: [
          // Hotpot illustration
          _HotpotWidget(),
          const SizedBox(height: 20),
          // Vibe progress bar at 72%
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _VibeBarSimple(percent: 72),
          ),
        ],
      ),
    );
  }
}

class _HotpotWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 120,
      child: CustomPaint(painter: _HotpotPainter()),
    );
  }
}

class _HotpotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Pot body (ocean)
    final potPaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.ocean, AppColors.oceanDeep],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(w * 0.1, h * 0.3, w * 0.8, h * 0.65));
    final potPath = Path()
      ..moveTo(w * 0.1, h * 0.38)
      ..lineTo(w * 0.9, h * 0.38)
      ..lineTo(w * 0.82, h * 0.92)
      ..quadraticBezierTo(w * 0.5, h, w * 0.18, h * 0.92)
      ..close();
    canvas.drawPath(potPath, potPaint);

    // Lid (berry)
    final lidPaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.berry, AppColors.berryDeep],
      ).createShader(Rect.fromLTWH(w * 0.05, h * 0.2, w * 0.9, h * 0.2));
    final lidPath = Path()
      ..moveTo(w * 0.05, h * 0.38)
      ..quadraticBezierTo(w * 0.5, h * 0.22, w * 0.95, h * 0.38)
      ..lineTo(w * 0.9, h * 0.38)
      ..quadraticBezierTo(w * 0.5, h * 0.26, w * 0.1, h * 0.38)
      ..close();
    canvas.drawPath(lidPath, lidPaint);

    // Handle knob
    final knobPaint = Paint()
      ..color = AppColors.mint
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.5, h * 0.2), 10, knobPaint);

    // Steam lines (wisteria)
    final steamPaint = Paint()
      ..color = AppColors.wisteria.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final steams = [0.35, 0.5, 0.65];
    for (final x in steams) {
      final path = Path()
        ..moveTo(w * x, h * 0.15)
        ..cubicTo(
          w * (x - 0.04),
          h * 0.08,
          w * (x + 0.04),
          h * 0.04,
          w * x,
          h * -0.02,
        );
      canvas.drawPath(path, steamPaint);
    }

    // Left handle
    final handlePaint = Paint()
      ..color = AppColors.oceanDeep
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromLTWH(w * -0.04, h * 0.38, w * 0.18, h * 0.22),
      3.14159 / 2,
      -3.14159,
      false,
      handlePaint,
    );
    // Right handle
    canvas.drawArc(
      Rect.fromLTWH(w * 0.86, h * 0.38, w * 0.18, h * 0.22),
      3.14159 / 2,
      3.14159,
      false,
      handlePaint,
    );
  }

  @override
  bool shouldRepaint(_HotpotPainter old) => false;
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
