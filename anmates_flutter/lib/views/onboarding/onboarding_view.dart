import 'dart:math' as math;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'package:geolocator/geolocator.dart';
import '../../widgets/anm_logo.dart';
import '../../widgets/anm_widgets.dart';
import '../auth/phone_input_view.dart';
import '../main_tab_view.dart';

// Shared splash-style background gradient applied to every onboarding page so
// the whole pre-auth flow reads as one surface. Text/buttons are light on top.
const RadialGradient kOnboardGradient = RadialGradient(
  center: Alignment(0, -0.3),
  radius: 1.4,
  colors: [AppColors.wisteria, AppColors.berry, AppColors.berryDeep],
  stops: [0.0, 0.55, 1.0],
);

class OnboardingView extends StatefulWidget {
  final VoidCallback? onFinished;

  const OnboardingView({super.key, this.onFinished});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const int _totalPages = 4;

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

  void _goBack() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
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
              children: [
                const _Step1Page(),
                const _Step2Page(),
                const _Step3Page(),
                _Step4Page(onFinished: _navigateAway, onBack: _goBack),
              ],
            ),
          ),
          // Top bar overlay — hidden on last page (it renders its own)
          if (_currentPage < _totalPages - 1)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const LogoMark(
                      size: 32,
                      fill: Colors.white,
                      accent: AppColors.mint,
                    ),
                    GestureDetector(
                      onTap: _skip,
                      child: Text(
                        'Bỏ qua',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Bottom controls overlay — hidden on last page
          if (_currentPage < _totalPages - 1)
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
                  color: active
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.35),
                ),
              );
            }),
          ),
          // CTA button — white fill + berry text pops on the gradient
          GestureDetector(
            onTap: onNext,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
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
                  color: AppColors.berry,
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
  final String eyebrow;
  final String title;
  final String body;
  final Widget illustration;

  const _StepLayout({
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
      decoration: const BoxDecoration(gradient: kOnboardGradient),
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
                // Light eyebrow on the dark gradient
                Eyebrow(eyebrow, color: AppColors.mint),
                SizedBox(height: isCompact ? 8 : 10),
                // H1: Plus Jakarta Sans w700 lh1.2 per design-system.md — white on gradient
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                    letterSpacing: -1.0,
                  ),
                ),
                SizedBox(height: isCompact ? 10 : 12),
                Text(
                  body,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: bodySize,
                    color: Colors.white.withValues(alpha: 0.82),
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

// ─── Location permission feature bullet ──────────────────────────────────────
class _LocationBullet extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String text;

  const _LocationBullet({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Icon(icon, color: iconColor, size: 19),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.beVietnamPro(
              fontSize: 13.5,
              color: Colors.white.withValues(alpha: 0.88),
              height: 1.4,
            ),
          ),
        ),
      ],
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
      eyebrow: '02 · Match cùng quán',
      title: 'Ai cũng đang\nthèm quán này?',
      body:
          '15 người quanh đây cũng vừa chọn quán giống bạn. Quét phải để gửi lời mời đi ăn cùng — không phải hẹn hò.',
      illustration: const _Step2Illustration(),
    );
  }
}

// ─── Mock mate profiles (Screen 03 Social Proof) ────────────────────────────
class _MateProfile {
  final String name;
  final int age;
  final List<String> chips;

  /// Local asset path — place images in assets/avatars/
  final String asset;
  const _MateProfile(this.name, this.age, this.chips, this.asset);
}

const _kMates = [
  _MateProfile('Vy', 24, ['🌶️ Cay 3', '💬 Tám'], 'assets/avatars/vy.jpg'),
  _MateProfile('Minh', 22, ['☕ Cafe', '🎵 Chill'], 'assets/avatars/minh.jpg'),
  _MateProfile('Nam', 25, ['🏃 Chạy bộ', '💪 Gym'], 'assets/avatars/nam.jpg'),
  _MateProfile('Linh', 23, ['🌃 Sài Gòn', '📸 Ảnh'], 'assets/avatars/linh.jpg'),
];

// ─── Screen 03 Illustration — Tinder-style swipeable card stack ──────────────
class _Step2Illustration extends StatefulWidget {
  const _Step2Illustration();

  @override
  State<_Step2Illustration> createState() => _Step2IllustrationState();
}

class _Step2IllustrationState extends State<_Step2Illustration>
    with TickerProviderStateMixin {
  // ── Persistent animations ──────────────────────────────────────────────────
  late final AnimationController _entryCtrl;
  late final Animation<double> _entryFade;
  late final Animation<Offset> _entrySlide;
  late final AnimationController _floatCtrl;
  late final Animation<double> _floatAnim;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  // ── Fly-out / snap-back (duration set per use) ────────────────────────────
  late final AnimationController _moveCtrl;
  Animation<Offset> _moveAnim = const AlwaysStoppedAnimation(Offset.zero);

  // ── Drag state ─────────────────────────────────────────────────────────────
  int _topIdx = 0;
  Offset _dragOffset = Offset.zero; // live position delta while dragging
  bool _isDragging = false;
  bool _isFlying = false; // true while fly-out animation plays

  static const double _kThreshold = 90.0; // px to commit swipe
  static const double _kVThreshold = 350.0; // velocity px/s to commit

  // ── Computed live position ─────────────────────────────────────────────────
  Offset get _liveOffset {
    if (_isDragging) return _dragOffset;
    if (_moveCtrl.isAnimating) return _moveAnim.value;
    return _dragOffset;
  }

  /// 0 = cards stacked, 1 = fully promoted (front gone)
  double get _promotionT {
    if (_isFlying) return 1.0;
    return (_liveOffset.dx.abs() / _kThreshold).clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.14),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _floatAnim = Tween<double>(
      begin: -7.0,
      end: 7.0,
    ).animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _pulseAnim = Tween<double>(
      begin: 1.0,
      end: 1.14,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _moveCtrl = AnimationController(vsync: this);

    Future.delayed(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      _entryCtrl.forward();
      _floatCtrl.repeat(reverse: true);
      _pulseCtrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _floatCtrl.dispose();
    _pulseCtrl.dispose();
    _moveCtrl.dispose();
    super.dispose();
  }

  // ── Gesture handlers ───────────────────────────────────────────────────────
  void _onPanStart(DragStartDetails _) {
    if (_isFlying) return;
    _moveCtrl.stop();
    _floatCtrl.stop();
    setState(() {
      _isDragging = true;
      _dragOffset = Offset.zero;
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_isFlying) return;
    setState(() => _dragOffset += d.delta);
  }

  void _onPanEnd(DragEndDetails d) {
    if (_isFlying) return;
    final vx = d.velocity.pixelsPerSecond.dx;
    final committed =
        _dragOffset.dx.abs() > _kThreshold || vx.abs() > _kVThreshold;
    setState(() => _isDragging = false);

    if (committed) {
      final dir = (_dragOffset.dx >= 0 || vx >= 0) ? 1.0 : -1.0;
      _flyOut(dir);
    } else {
      _snapBack();
    }
  }

  // Tap still works as a quick right-swipe
  void _onTap() {
    if (_isFlying || _isDragging) return;
    _flyOut(1.0);
  }

  // ── Fly-out: card launches in `dir` direction with easeIn acceleration ─────
  Future<void> _flyOut(double dir) async {
    setState(() => _isFlying = true);
    _floatCtrl.stop();
    final start = _dragOffset;
    final end = Offset(dir * 500.0, start.dy + 50.0);
    _moveAnim = Tween<Offset>(
      begin: start,
      end: end,
    ).animate(CurvedAnimation(parent: _moveCtrl, curve: Curves.easeInCubic));
    _moveCtrl
      ..duration = const Duration(milliseconds: 700)
      ..reset();
    await _moveCtrl.forward();
    if (!mounted) return;
    setState(() {
      _topIdx = (_topIdx + 1) % _kMates.length;
      _dragOffset = Offset.zero;
      _isFlying = false;
    });
    _moveCtrl.reset();
    _floatCtrl.repeat(reverse: true);
  }

  // ── Snap-back: elastic spring return to center ─────────────────────────────
  Future<void> _snapBack() async {
    final start = _dragOffset;
    _moveAnim = Tween<Offset>(
      begin: start,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _moveCtrl, curve: Curves.elasticOut));
    _moveCtrl
      ..duration = const Duration(milliseconds: 750)
      ..reset();
    await _moveCtrl.forward();
    if (!mounted) return;
    setState(() => _dragOffset = Offset.zero);
    _moveCtrl.reset();
    _floatCtrl.repeat(reverse: true);
  }

  static double _l(double a, double b, double t) => a + (b - a) * t;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _entryFade,
      child: SlideTransition(
        position: _entrySlide,
        child: AnimatedBuilder(
          animation: Listenable.merge([_floatCtrl, _moveCtrl, _pulseCtrl]),
          builder: (_, _) {
            final live = _liveOffset;
            final t = _promotionT;
            // Float: only when card is at rest
            final float = (_isDragging || _isFlying || _moveCtrl.isAnimating)
                ? 0.0
                : _floatAnim.value;

            // Rotation proportional to horizontal drag (Tinder-style tilt)
            final frontAngle = live.dx * 0.0022; // ~0.13°/px

            // Behind cards promote toward front as front card is dragged away
            final backAngle = _l(-9, 5, t) * math.pi / 180;
            final backTop = _l(18, 10, t);
            final backLeft = _l(0, 12, t);
            final backAlpha = _l(0.50, 0.75, t);
            final midAngle = _l(5, 0, t) * math.pi / 180;
            final midTop = _l(10, 0, t);
            final midLeft = _l(12, 20, t);
            final midAlpha = _l(0.75, 1.0, t);

            // Front card fades only well past threshold (not during snap-back)
            final dxAbs = live.dx.abs();
            final frontAlpha = dxAbs < _kThreshold * 1.8
                ? 1.0
                : _l(
                    1.0,
                    0.0,
                    ((dxAbs - _kThreshold * 1.8) / (_kThreshold * 1.2)).clamp(
                      0.0,
                      1.0,
                    ),
                  );

            return Transform.translate(
              offset: Offset(0, float),
              child: SizedBox(
                width: 240,
                height: 310,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // ── Back card ─────────────────────────────────────────────
                    Positioned(
                      top: backTop,
                      left: backLeft,
                      child: Transform.rotate(
                        angle: backAngle,
                        child: Opacity(
                          opacity: backAlpha.clamp(0.0, 1.0),
                          child: _MateProfileCard(
                            profile: _kMates[(_topIdx + 2) % _kMates.length],
                          ),
                        ),
                      ),
                    ),
                    // ── Mid card ──────────────────────────────────────────────
                    Positioned(
                      top: midTop,
                      left: midLeft,
                      child: Transform.rotate(
                        angle: midAngle,
                        child: Opacity(
                          opacity: midAlpha.clamp(0.0, 1.0),
                          child: _MateProfileCard(
                            profile: _kMates[(_topIdx + 1) % _kMates.length],
                          ),
                        ),
                      ),
                    ),
                    // ── Front card — drag to swipe (or tap) ───────────────────
                    Positioned(
                      top: live.dy,
                      left: 20 + live.dx,
                      child: GestureDetector(
                        onTap: _onTap,
                        onPanStart: _onPanStart,
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: _onPanEnd,
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedScale(
                          // Card lifts slightly as user picks it up
                          scale: _isDragging ? 1.04 : 1.0,
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOut,
                          child: Transform.rotate(
                            angle: frontAngle,
                            child: Opacity(
                              opacity: frontAlpha.clamp(0.0, 1.0),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  _MateProfileCard(
                                    profile: _kMates[_topIdx % _kMates.length],
                                  ),
                                  // ── LIKE badge (drag right) ─────────────────
                                  if (live.dx > 20)
                                    Positioned(
                                      top: 22,
                                      left: 16,
                                      child: Opacity(
                                        opacity: ((live.dx - 20) / 70).clamp(
                                          0.0,
                                          1.0,
                                        ),
                                        child: const _SwipeBadge(
                                          text: 'LIKE ♥',
                                          color: Color(0xFF2ECC71),
                                        ),
                                      ),
                                    ),
                                  // ── NOPE badge (drag left) ──────────────────
                                  if (live.dx < -20)
                                    Positioned(
                                      top: 22,
                                      right: 16,
                                      child: Opacity(
                                        opacity: ((-live.dx - 20) / 70).clamp(
                                          0.0,
                                          1.0,
                                        ),
                                        child: const _SwipeBadge(
                                          text: 'NOPE',
                                          color: Color(0xFFE74C3C),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // ── Pulsing heart badge ───────────────────────────────────
                    Positioned(
                      top: -14,
                      right: 0,
                      child: Transform.scale(
                        scale: _pulseAnim.value,
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [AppColors.berry, AppColors.berryDeep],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.berry.withValues(alpha: 0.45),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.favorite,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Mate profile card (photo area + name + chips) ───────────────────────────
class _MateProfileCard extends StatelessWidget {
  final _MateProfile profile;
  const _MateProfileCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 196,
      height: 268,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.berry.withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          const BoxShadow(
            color: AppColors.ink10,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Photo area — local asset avatar ───────────────────────────
          Expanded(
            flex: 11,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: Image.asset(
                profile.asset,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                filterQuality: FilterQuality.medium,
                // Falls back to diagonal stripes if asset missing
                errorBuilder: (_, _, _) => Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(painter: _DiagonalStripesPainter()),
                    Center(
                      child: Text(
                        profile.name.toUpperCase(),
                        style: AppTextStyles.mono(
                          size: 11,
                          weight: FontWeight.w600,
                          color: AppColors.wisteria.withValues(alpha: 0.8),
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── Info area ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${profile.name}, ${profile.age}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    for (int i = 0; i < profile.chips.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      _InfoChip(profile.chips[i]),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Small info chip inside profile card ─────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final String label;
  const _InfoChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.berry.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.berry.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.beVietnamPro(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.ink70,
        ),
      ),
    );
  }
}

// ─── Diagonal stripe painter (photo placeholder) ─────────────────────────────
class _DiagonalStripesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = AppColors.berryTint,
    );
    // Diagonal stripes
    final stripePaint = Paint()
      ..color = AppColors.wisteria.withValues(alpha: 0.20)
      ..strokeWidth = 20
      ..style = PaintingStyle.stroke;
    final span = size.width + size.height;
    for (double x = -size.height; x < span; x += 32) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        stripePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_DiagonalStripesPainter _) => false;
}

// Tracks all possible states of the location permission gate on Step 4.
enum _LocState { checking, serviceOff, denied, deniedForever, granted }

// ─── Step 4: Quyền An Toàn — Định vị nền ────────────────────────────────────
class _Step4Page extends StatefulWidget {
  final VoidCallback onFinished;
  final VoidCallback onBack;

  const _Step4Page({required this.onFinished, required this.onBack});

  @override
  State<_Step4Page> createState() => _Step4PageState();
}

class _Step4PageState extends State<_Step4Page>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  _LocState _locState = _LocState.checking;
  bool _requesting = false;

  late final AnimationController _glowCtrl;
  late final Animation<double> _glowAnim;
  late final AnimationController _pinCtrl;
  late final Animation<double> _pinScale;
  late final Animation<double> _pinFade;
  late final AnimationController _cardCtrl;
  late final Animation<double> _cardFade;
  late final Animation<double> _cardSlide;
  late final AnimationController _lineCtrl;
  late final Animation<double> _lineProgress;
  late final AnimationController _destPulseCtrl;
  late final Animation<double> _destPulse;
  // Loops the motorbike's ride (origin → destination) + dash marching.
  late final AnimationController _travelCtrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAnimations();
    _checkPermission();
  }

  void _initAnimations() {
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _glowAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _pinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    );
    _pinScale = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pinCtrl, curve: Curves.elasticOut));
    _pinFade = CurvedAnimation(
      parent: _pinCtrl,
      curve: const Interval(0.0, 0.38, curve: Curves.easeOut),
    );

    _cardCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 540),
    );
    _cardFade = CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOut);
    _cardSlide = Tween<double>(
      begin: 32.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOutCubic));

    _lineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 980),
    );
    _lineProgress = CurvedAnimation(parent: _lineCtrl, curve: Curves.easeInOut);

    _destPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    );
    _destPulse = Tween<double>(
      begin: 1.0,
      end: 1.40,
    ).animate(CurvedAnimation(parent: _destPulseCtrl, curve: Curves.easeInOut));

    // Linear so the bike moves at constant speed and the dashes march evenly.
    _travelCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    Future.delayed(const Duration(milliseconds: 140), () {
      if (!mounted) return;
      _pinCtrl.forward().then((_) {
        if (!mounted) return;
        _glowCtrl.repeat(reverse: true);
        Future.delayed(const Duration(milliseconds: 160), () {
          if (!mounted) return;
          _cardCtrl.forward().then((_) {
            if (!mounted) return;
            Future.delayed(const Duration(milliseconds: 300), () {
              if (!mounted) return;
              _lineCtrl.forward().then((_) {
                if (!mounted) return;
                _destPulseCtrl.repeat(reverse: true);
                _travelCtrl.repeat();
              });
            });
          });
        });
      });
    });
  }

  Future<void> _checkPermission() async {
    // Check GPS switch first — permission can be granted yet GPS still off.
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) {
      if (mounted) setState(() => _locState = _LocState.serviceOff);
      return;
    }
    final perm = await Geolocator.checkPermission();
    if (mounted) setState(() => _locState = _permToState(perm));
  }

  _LocState _permToState(LocationPermission perm) => switch (perm) {
    LocationPermission.always ||
    LocationPermission.whileInUse => _LocState.granted,
    LocationPermission.deniedForever => _LocState.deniedForever,
    _ => _LocState.denied, // denied + unableToDetermine
  };

  Future<void> _handleCta() async {
    switch (_locState) {
      case _LocState.checking:
        return; // still loading — ignore tap
      case _LocState.granted:
        widget.onFinished();
        return;
      case _LocState.serviceOff:
        // GPS switch is off: take user to system location settings
        await Geolocator.openLocationSettings();
        return;
      case _LocState.deniedForever:
        // Can't re-ask: take user to app settings
        await Geolocator.openAppSettings();
        return;
      case _LocState.denied:
        break; // fall through to request
    }
    setState(() => _requesting = true);
    try {
      final perm = await Geolocator.requestPermission();
      if (!mounted) return;
      final next = _permToState(perm);
      setState(() {
        _requesting = false;
        _locState = next;
      });
      if (next == _LocState.granted) widget.onFinished();
    } catch (_) {
      // Unexpected platform exception (e.g. custom ROM)
      if (!mounted) return;
      setState(() {
        _requesting = false;
        _locState = _LocState.denied;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check after user returns from Settings (may have changed permission there)
    if (state == AppLifecycleState.resumed) _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _glowCtrl.dispose();
    _pinCtrl.dispose();
    _cardCtrl.dispose();
    _lineCtrl.dispose();
    _destPulseCtrl.dispose();
    _travelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final topPad = MediaQuery.of(context).padding.top;
    final buttonLabel = switch (_locState) {
      _LocState.checking => 'Đang kiểm tra...',
      _LocState.serviceOff => 'Bật GPS',
      _LocState.denied => 'Bật "Luôn cho phép"',
      _LocState.deniedForever => 'Mở Cài đặt',
      _LocState.granted => 'Bắt đầu',
    };
    final String? hintText = switch (_locState) {
      _LocState.deniedForever =>
        'Vào Cài đặt → AnMates → Vị trí → Luôn cho phép',
      _LocState.serviceOff => 'GPS đang tắt — bật để dùng tính năng ETA',
      _ => null,
    };
    final buttonEnabled = _locState != _LocState.checking && !_requesting;

    return Container(
      decoration: const BoxDecoration(gradient: kOnboardGradient),
      child: Column(
        children: [
          // ── Custom top bar ────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(16, topPad + 27, 16, 4),
            child: Row(
              children: [
                GestureDetector(
                  onTap: widget.onBack,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.ink10,
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 16,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                Expanded(
                  // Title group nudged down 10px relative to the side buttons
                  child: Transform.translate(
                    offset: const Offset(0, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'QUYỀN AN TOÀN',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.mint,
                            letterSpacing: 2.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Định vị nền',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.ink10,
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Text(
                    '?',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink70,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Content — scales down to fit any viewport height ──────────────
          Expanded(
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _pinCtrl,
                _glowCtrl,
                _cardCtrl,
                _lineCtrl,
                _destPulseCtrl,
                _travelCtrl,
              ]),
              builder: (_, _) => LayoutBuilder(
                builder: (context, constraints) => FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth,
                      maxWidth: constraints.maxWidth,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 10),
                          // Location pin icon with glow
                          Opacity(
                            opacity: _pinFade.value.clamp(0.0, 1.0),
                            child: Transform.scale(
                              scale: _pinScale.value,
                              child: _GlowLocationPin(glowT: _glowAnim.value),
                            ),
                          ),
                          const SizedBox(height: 11),
                          // Heading
                          Text(
                            'Bật định vị nền\nđể gặp Mates an toàn',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 29,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.18,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 17),
                          // Subtext with bold "45 phút trước giờ hẹn"
                          Text.rich(
                            TextSpan(
                              style: GoogleFonts.beVietnamPro(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.82),
                                height: 1.55,
                              ),
                              children: [
                                const TextSpan(text: 'Chỉ chạy '),
                                TextSpan(
                                  text: '45 phút trước giờ hẹn',
                                  style: GoogleFonts.beVietnamPro(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const TextSpan(
                                  text:
                                      ' để xác minh hai bạn đều đang trên đường (hạn chế nạn bùng kèo).',
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 17),
                          // ETA map card
                          Opacity(
                            opacity: _cardFade.value.clamp(0.0, 1.0),
                            child: Transform.translate(
                              offset: Offset(0, _cardSlide.value),
                              child: _EtaMapCard(
                                lineProgress: _lineProgress.value,
                                destPulse: _destPulse.value,
                                travelT: _travelCtrl.value,
                              ),
                            ),
                          ),
                          const SizedBox(height: 27),
                          // Feature bullets
                          _LocationBullet(
                            icon: Icons.lock_outline,
                            iconColor: Colors.white,
                            iconBg: Colors.white.withValues(alpha: 0.16),
                            text:
                                'Nói không với chia sẻ vị trí liên tục - Chỉ chia sẻ vị trí khi đến Kèo của cả hai.',
                          ),
                          const SizedBox(height: 14),
                          _LocationBullet(
                            icon: Icons.schedule,
                            iconColor: Colors.white,
                            iconBg: Colors.white.withValues(alpha: 0.16),
                            text:
                                'Tự tắt chia sẻ vị trí sau khi check-in tại điểm hẹn',
                          ),
                          const SizedBox(height: 14),
                          _LocationBullet(
                            icon: Icons.shield_outlined,
                            iconColor: Colors.white,
                            iconBg: Colors.white.withValues(alpha: 0.16),
                            text: 'Không lo bùng kèo - Giữ vững uy tín',
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // ── Hint text (shown for serviceOff / deniedForever) ─────────────
          if (hintText != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 6),
              child: Text(
                hintText,
                textAlign: TextAlign.center,
                style: GoogleFonts.beVietnamPro(
                  fontSize: 12,
                  color: _locState == _LocState.deniedForever
                      ? AppColors.mint
                      : Colors.white.withValues(alpha: 0.7),
                  height: 1.4,
                ),
              ),
            ),
          // ── CTA button ────────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, bottomPad + 20),
            child: GestureDetector(
              onTap: buttonEnabled ? _handleCta : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 56,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: buttonEnabled
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: buttonEnabled ? 0.20 : 0.08,
                      ),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: (_requesting || _locState == _LocState.checking)
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: AppColors.berry,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        buttonLabel,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.berry,
                          letterSpacing: -0.2,
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

// ─── Location pin tile: pushpin + breathing glow + radar ripple + sparkles ───
class _GlowLocationPin extends StatefulWidget {
  /// 0→1 breathing-glow value from the parent's glow controller
  final double glowT;
  const _GlowLocationPin({required this.glowT});

  @override
  State<_GlowLocationPin> createState() => _GlowLocationPinState();
}

class _GlowLocationPinState extends State<_GlowLocationPin>
    with SingleTickerProviderStateMixin {
  // Drives the outward radar ripples (forward-repeat, not reverse).
  late final AnimationController _rippleCtrl;

  @override
  void initState() {
    super.initState();
    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _rippleCtrl.dispose();
    super.dispose();
  }

  // One ring expanding outward and fading; t in 0..1.
  Widget _ripple(double t) {
    final scale = 0.55 + t * 0.95;
    final opacity = (1.0 - t) * 0.45;
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final glowT = widget.glowT;
    return SizedBox(
      width: 164,
      height: 164,
      child: AnimatedBuilder(
        animation: _rippleCtrl,
        builder: (context, child) => Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Two staggered radar ripples
            _ripple(_rippleCtrl.value),
            _ripple((_rippleCtrl.value + 0.5) % 1.0),
            child!,
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Breathing glow rings (driven by glowT)
            Container(
              width: 134,
              height: 134,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: glowT * 0.10),
              ),
            ),
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: glowT * 0.14),
              ),
            ),
            // Pink gradient rounded-square tile + pushpin
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  colors: [Color(0xFFE886AE), AppColors.berryDeep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.berry.withValues(
                      alpha: 0.30 + glowT * 0.28,
                    ),
                    blurRadius: 26 + glowT * 18,
                    offset: const Offset(0, 14),
                    spreadRadius: glowT * 2,
                  ),
                ],
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(48, 58),
                  painter: _PushpinPainter(),
                ),
              ),
            ),
            // Twinkling sparkles around the tile (self-animated)
            const Positioned(
              top: 8,
              right: 18,
              child: Sparkle(size: 18, color: Colors.white, animated: true),
            ),
            const Positioned(
              bottom: 18,
              left: 14,
              child: Sparkle(size: 13, color: AppColors.mint, animated: true),
            ),
            const Positioned(
              top: 38,
              left: 10,
              child: Sparkle(size: 10, color: Colors.white, animated: true),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Glossy 3D red pushpin (matches 📍 in NEW_ETA_Maps.png) ──────────────────
class _PushpinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final headCenter = Offset(w * 0.46, h * 0.37);
    final headR = w * 0.34;
    final tip = Offset(w * 0.66, h * 0.98);

    // Metallic needle from head to tip (drawn first, behind the sphere)
    final needlePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFF2F2F2), Color(0xFF8C8C8C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(w * 0.4, h * 0.4, w * 0.35, h * 0.6))
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.11
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(headCenter, tip, needlePaint);

    // Soft contact shadow under the tip
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawOval(
      Rect.fromCenter(center: tip, width: w * 0.30, height: h * 0.07),
      shadowPaint,
    );

    // Glossy red sphere head
    final spherePaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.45, -0.55),
        radius: 1.05,
        colors: [Color(0xFFFF7A6B), Color(0xFFD41E12)],
      ).createShader(Rect.fromCircle(center: headCenter, radius: headR));
    canvas.drawCircle(headCenter, headR, spherePaint);

    // Specular highlight
    final highlightPaint = Paint()..color = Colors.white.withValues(alpha: 0.6);
    canvas.drawCircle(
      Offset(headCenter.dx - headR * 0.34, headCenter.dy - headR * 0.42),
      headR * 0.26,
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(_PushpinPainter _) => false;
}

// ─── ETA Map Card: dark bg + grid + dashed route + in-card labels ───────────
class _EtaMapCard extends StatelessWidget {
  final double lineProgress; // 0→1 as line draws in
  final double destPulse; // 1→1.4 pulsing after arrival
  final double travelT; // 0→1 looping: motorbike ride + dash marching

  const _EtaMapCard({
    required this.lineProgress,
    required this.destPulse,
    required this.travelT,
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

// ─── Swipe direction badge (LIKE / NOPE) ─────────────────────────────────────
class _SwipeBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _SwipeBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.38, // slight CCW tilt
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color, width: 2.5),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          text,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 1.2,
          ),
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
