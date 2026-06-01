import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';
import '../widgets/step_layout.dart';

class Step2Page extends StatelessWidget {
  const Step2Page({super.key});

  @override
  Widget build(BuildContext context) {
    return const StepLayout(
      eyebrow: '02 · Match cùng quán',
      title: 'Ai cũng đang\nthèm quán này?',
      body:
          '15 người quanh đây cũng vừa chọn quán giống bạn. Quét phải để gửi lời mời đi ăn cùng — không phải hẹn hò.',
      illustration: _Step2Illustration(),
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
