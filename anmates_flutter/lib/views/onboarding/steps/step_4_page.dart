import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/anm_logo.dart';
import '../widgets/step_layout.dart';

// Tracks all possible states of the location permission gate.
enum _LocState { checking, serviceOff, denied, deniedForever, granted }

// ─── Step 4: Quyền An Toàn — Định vị nền ────────────────────────────────────
class Step4Page extends StatefulWidget {
  final VoidCallback onFinished;
  final VoidCallback onBack;

  const Step4Page({required this.onFinished, required this.onBack, super.key});

  @override
  State<Step4Page> createState() => _Step4PageState();
}

class _Step4PageState extends State<Step4Page>
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
