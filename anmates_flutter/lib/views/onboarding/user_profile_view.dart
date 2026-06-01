import 'dart:math' as math;
import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/onboarding_draft.dart';
import '../../theme/app_theme.dart';
import '../../utils/astrology.dart';
import '../../widgets/anm_widgets.dart';
import '../../widgets/horoscope_icons.dart';
import 'food_preferences_view.dart';

/// Screen 08 — Thông Tin Cá Nhân (step 3/5). Collects name, nickname, DOB and a
/// personality score, shows live astrology/numerology auto-detect, then persists
/// to the backend before advancing to Screen 09.
class UserProfileView extends StatefulWidget {
  /// Called when the WHOLE post-OTP onboarding flow completes (after Screen 09).
  final VoidCallback onComplete;

  const UserProfileView({super.key, required this.onComplete});

  @override
  State<UserProfileView> createState() => _UserProfileViewState();
}

class _UserProfileViewState extends State<UserProfileView> {
  final _draft = OnboardingDraftController.instance;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _nicknameCtrl;

  static const _minYear = 1960;
  static const _maxYear = 2009;

  @override
  void initState() {
    super.initState();
    // Seed from the client-side draft so returning to this screen (e.g. after a
    // failed final validation on Screen 10) restores what the user typed.
    _nameCtrl = TextEditingController(text: _draft.name);
    _nicknameCtrl = TextEditingController(text: _draft.nickname);
    // Rebuild button state whenever text changes.
    _nameCtrl.addListener(_onTextChanged);
    _nicknameCtrl.addListener(_onTextChanged);
    // Rebuild when another screen sets an error on this step.
    _draft.addListener(_onDraftChanged);
  }

  void _onDraftChanged() {
    if (mounted) setState(() {});
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  bool get _fieldsReady =>
      _nameCtrl.text.trim().isNotEmpty &&
      _nicknameCtrl.text.trim().isNotEmpty;

  @override
  void dispose() {
    _draft.removeListener(_onDraftChanged);
    _nameCtrl.removeListener(_onTextChanged);
    _nicknameCtrl.removeListener(_onTextChanged);
    _nameCtrl.dispose();
    _nicknameCtrl.dispose();
    super.dispose();
  }

  String get _personalityLabel {
    final v = _draft.personality.round();
    if (v <= 33) return 'Introvert';
    if (v <= 66) return 'Ambivert';
    return 'Extrovert';
  }

  // No API here — Screen 08 only validates + stores into the client draft, then
  // advances to Screen 09. The single submit happens on Screen 10 ("Hoàn tất").
  Future<void> _continue() async {
    _draft.name = _nameCtrl.text;
    _draft.nickname = _nicknameCtrl.text;
    if (!_draft.validateStep08()) return; // sets red errors + rebuilds
    await _draft.persist();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'onb_food'),
        builder: (_) => FoodPreferencesView(onComplete: widget.onComplete),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final underage = _draft.dobTouched && _draft.ageYears < OnboardingDraftController.minAge;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(title: 'THÔNG TIN CÁ NHÂN', step: 3, total: 6),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('THÔNG TIN CÁ NHÂN'),
                    const SizedBox(height: 8),
                    Text(
                      'Bạn là ai trên bàn ăn?',
                      style: AppTextStyles.display(
                        size: 28,
                        weight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Chỉ ĂnMates dùng để ghép Mate hợp vía — không bao '
                      'giờ public số tử vi của bạn.',
                      style: AppTextStyles.body(
                        size: 14,
                        color: AppColors.ink70,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _FieldLabel('TÊN ĐẦY ĐỦ'),
                    const SizedBox(height: 8),
                    _TextField(
                      controller: _nameCtrl,
                      hint: 'Nguyễn Thảo Vy',
                      errorText: _draft.nameError,
                      onChanged: (v) {
                        _draft.name = v;
                        if (_draft.nameError != null) {
                          setState(() => _draft.nameError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 18),
                    _FieldLabel('GỌI THÂN MẬT'),
                    const SizedBox(height: 8),
                    _TextField(
                      controller: _nicknameCtrl,
                      hint: 'Vy',
                      helper: 'Mates sẽ thấy tên này trong chat',
                      errorText: _draft.nicknameError,
                      onChanged: (v) {
                        _draft.nickname = v;
                        if (_draft.nicknameError != null) {
                          setState(() => _draft.nicknameError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    _FieldLabel('NGÀY THÁNG NĂM SINH'),
                    const SizedBox(height: 10),
                    _DobWheels(
                      day: _draft.day,
                      month: _draft.month,
                      year: _draft.year,
                      minYear: _minYear,
                      maxYear: _maxYear,
                      onChanged: (d, m, y) {
                        setState(() {
                          _draft.day = d;
                          _draft.month = m;
                          _draft.year = y;
                          _draft.dobTouched = true;
                          _draft.dobError = null;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    _AgeNotice(underage: underage, error: _draft.dobError),
                    const SizedBox(height: 14),
                    _AutoDetect(dob: _draft.dob),
                    const SizedBox(height: 24),
                    _PersonalitySection(
                      value: _draft.personality,
                      label: _personalityLabel,
                      onChanged: (v) => setState(() => _draft.personality = v),
                    ),
                  ],
                ),
              ),
            ),
            _BottomCta(
              loading: false,
              enabled: _fieldsReady,
              onTap: _continue,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 16+ age notice (info by default, red when underage / unset) ─────────────
class _AgeNotice extends StatelessWidget {
  final bool underage;
  final String? error;
  const _AgeNotice({required this.underage, required this.error});

  @override
  Widget build(BuildContext context) {
    final isError = error != null;
    final color = isError ? AppColors.berry : AppColors.ink50;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isError ? Icons.error_outline : Icons.info_outline,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            error ?? 'ĂnMates chỉ dành cho người từ 16 tuổi trở lên.',
            style: AppTextStyles.body(
              size: 12,
              color: color,
              height: 1.35,
              weight: isError ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Shared top bar (back + title + progress) ────────────────────────────────
class _TopBar extends StatelessWidget {
  final String title;
  final int step;
  final int total;
  const _TopBar({required this.title, required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink10,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back,
                size: 20,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.mono(
                    size: 11,
                    weight: FontWeight.w700,
                    color: AppColors.ink50,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: step / total,
                    minHeight: 5,
                    backgroundColor: AppColors.ink10,
                    valueColor: const AlwaysStoppedAnimation(AppColors.berry),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$step/$total',
            style: AppTextStyles.mono(
              size: 12,
              weight: FontWeight.w700,
              color: AppColors.ink50,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppTextStyles.mono(
      size: 10,
      weight: FontWeight.w700,
      color: AppColors.berry,
      letterSpacing: 1.6,
    ),
  );
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? helper;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  const _TextField({
    required this.controller,
    required this.hint,
    this.helper,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    final base = hasError ? Colors.red.shade600 : AppColors.berry;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          onChanged: onChanged,
          textCapitalization: TextCapitalization.words,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.ink30,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: base, width: 1.4),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: hasError ? base : base.withValues(alpha: 0.45),
                width: 1.4,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: base, width: 1.8),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: AppTextStyles.body(
              size: 12,
              color: Colors.red.shade600,
              weight: FontWeight.w600,
            ),
          ),
        ] else if (helper != null) ...[
          const SizedBox(height: 6),
          Text(
            helper!,
            style: AppTextStyles.body(size: 12, color: AppColors.ink50),
          ),
        ],
      ],
    );
  }
}

// ─── DOB wheel pickers ───────────────────────────────────────────────────────
class _DobWheels extends StatelessWidget {
  final int day, month, year, minYear, maxYear;
  final void Function(int day, int month, int year) onChanged;

  const _DobWheels({
    required this.day,
    required this.month,
    required this.year,
    required this.minYear,
    required this.maxYear,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _WheelCard(
            label: 'NGÀY',
            count: 31,
            selectedIndex: day - 1,
            itemLabel: (i) => (i + 1).toString().padLeft(2, '0'),
            onSelected: (i) => onChanged(i + 1, month, year),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _WheelCard(
            label: 'THÁNG',
            count: 12,
            selectedIndex: month - 1,
            itemLabel: (i) => (i + 1).toString().padLeft(2, '0'),
            onSelected: (i) => onChanged(day, i + 1, year),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _WheelCard(
            label: 'NĂM',
            count: maxYear - minYear + 1,
            selectedIndex: year - minYear,
            itemLabel: (i) => (minYear + i).toString(),
            onSelected: (i) => onChanged(day, month, minYear + i),
          ),
        ),
      ],
    );
  }
}

class _WheelCard extends StatefulWidget {
  final String label;
  final int count;
  final int selectedIndex;
  final String Function(int index) itemLabel;
  final ValueChanged<int> onSelected;

  const _WheelCard({
    required this.label,
    required this.count,
    required this.selectedIndex,
    required this.itemLabel,
    required this.onSelected,
  });

  @override
  State<_WheelCard> createState() => _WheelCardState();
}

class _WheelCardState extends State<_WheelCard> {
  late final FixedExtentScrollController _ctrl;
  bool _dragging = false;
  static const _kItemExtent = 30.0;

  @override
  void initState() {
    super.initState();
    _ctrl = FixedExtentScrollController(initialItem: widget.selectedIndex);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _snapToNearest() {
    if (!_ctrl.hasClients) return;
    final item = (_ctrl.offset / _kItemExtent)
        .round()
        .clamp(0, widget.count - 1);
    _ctrl.animateToItem(
      item,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: _dragging
          ? SystemMouseCursors.grabbing
          : SystemMouseCursors.grab,
      child: Listener(
        // Scroll wheel: one item per tick, stays snapped
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            final dir = event.scrollDelta.dy > 0 ? 1 : -1;
            final next = (_ctrl.selectedItem + dir).clamp(0, widget.count - 1);
            _ctrl.animateToItem(
              next,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
            );
          }
        },
        child: GestureDetector(
          // Click + drag: kéo lên = giá trị tăng, kéo xuống = giá trị giảm
          onVerticalDragStart: (_) => setState(() => _dragging = true),
          onVerticalDragUpdate: (d) {
            if (!_ctrl.hasClients) return;
            final newOffset = (_ctrl.offset - d.delta.dy)
                .clamp(0.0, (widget.count - 1) * _kItemExtent);
            _ctrl.jumpTo(newOffset);
          },
          onVerticalDragEnd: (_) {
            setState(() => _dragging = false);
            _snapToNearest();
          },
          onVerticalDragCancel: () {
            setState(() => _dragging = false);
            _snapToNearest();
          },
          child: Container(
            height: 132,
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                center: Alignment.center,
                radius: 0.85,
                colors: [Color(0xFFC96098), Color(0xFF8E3572)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Text(
                  widget.label,
                  style: AppTextStyles.mono(
                    size: 9,
                    weight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.65),
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: ListWheelScrollView.useDelegate(
                    controller: _ctrl,
                    itemExtent: _kItemExtent,
                    useMagnifier: true,
                    magnification: 1.45,
                    overAndUnderCenterOpacity: 0.38,
                    perspective: 0.003,
                    diameterRatio: 1.5,
                    // GestureDetector + Listener xử lý toàn bộ input
                    physics: const NeverScrollableScrollPhysics(),
                    onSelectedItemChanged: widget.onSelected,
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: widget.count,
                      builder: (context, i) => Center(
                        child: Text(
                          widget.itemLabel(i),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Auto-detect (zodiac / nạp âm / numerology) ──────────────────────────────
class _AutoDetect extends StatelessWidget {
  final DateTime dob;
  const _AutoDetect({required this.dob});

  @override
  Widget build(BuildContext context) {
    final z = zodiacSign(dob);
    final lp = lifePathNumber(dob);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.berryTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.berry.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 14,
                color: AppColors.berry,
              ),
              const SizedBox(width: 6),
              Text(
                'ĂN MATES TỰ NHẬN DIỆN',
                style: AppTextStyles.mono(
                  size: 10,
                  weight: FontWeight.w700,
                  color: AppColors.berry,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _DetectCard(
                    icon: ZodiacIcon(viName: z.vi),
                    label: 'CUNG HOÀNG ĐẠO',
                    labelColor: AppColors.berry,
                    value: z.vi,
                    sub: '${z.en} · ${z.range}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DetectCard(
                    icon: NguHanhIcon(element: elementOf(napAm(dob.year))),
                    label: 'MỆNH NGŨ HÀNH',
                    labelColor: elementVisual(elementOf(napAm(dob.year))).color,
                    value: napAm(dob.year),
                    sub: '${canChi(dob.year)} · ${dob.year}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DetectCard(
                    icon: ThanSoIcon(number: lp),
                    label: 'THẦN SỐ HỌC',
                    labelColor: AppColors.wisteria,
                    value: 'Số $lp',
                    sub: lifePathLabel(lp),
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

class _DetectCard extends StatelessWidget {
  final Widget icon;
  final String label;
  final Color labelColor;
  final String value;
  final String sub;
  const _DetectCard({
    required this.icon,
    required this.label,
    required this.labelColor,
    required this.value,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.ink10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.mono(
              size: 7.5,
              weight: FontWeight.w700,
              color: labelColor,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          icon,
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(
              size: 9.5,
              color: AppColors.ink50,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Custom "+" thumb ────────────────────────────────────────────────────────
class _PlusThumbShape extends SliderComponentShape {
  const _PlusThumbShape();
  static const _r = 12.0;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(_r + 3);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    bool isDiscrete = false,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    TextDirection? textDirection,
    double value = 0,
    double textScaleFactor = 1.0,
    Size sizeWithOverflow = Size.zero,
  }) {
    final canvas = context.canvas;

    // Drop shadow
    canvas.drawCircle(
      center + const Offset(0, 4),
      _r,
      Paint()
        ..color = AppColors.berry.withValues(alpha: 0.40)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );

    // White border ring
    canvas.drawCircle(center, _r + 2.5, Paint()..color = Colors.white);

    // Berry fill
    canvas.drawCircle(center, _r, Paint()..color = AppColors.berry);

    // 4-pointed sparkle star (elongated diamond points, like ✦)
    _drawSparkle(canvas, center, radius: _r * 0.62);
  }

  /// Draws a 4-pointed sparkle star centered at [center].
  /// Each point is a sharp diamond spike; [radius] is the outer point length.
  /// Inner pinch radius = radius * 0.18 gives the elongated ✦ look.
  static void _drawSparkle(Canvas canvas, Offset center, {required double radius}) {
    const pointCount = 4;
    final innerR = radius * 0.18;
    final path = Path();

    for (int i = 0; i < pointCount * 2; i++) {
      // Points alternate between outer (spike tips) and inner (pinch between spikes).
      // Rotate -π/2 so the first spike points straight up.
      final angle = (i * math.pi / pointCount) - math.pi / 2;
      final r = i.isEven ? radius : innerR;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
  }
}

// ─── Personality slider ───────────────────────────────────────────────────────
class _PersonalitySection extends StatelessWidget {
  final double value;
  final String label;
  final ValueChanged<double> onChanged;

  const _PersonalitySection({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  // Badge color tracks the gradient: ocean left → berry right
  Color get _badgeColor {
    if (value <= 33) return AppColors.ocean;
    return AppColors.berry;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.berry.withValues(alpha: 0.18),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x09000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.restaurant_rounded,
                    size: 13,
                    color: AppColors.berry,
                  ),
                  const SizedBox(width: 5),
                  _FieldLabel('TÍNH CÁCH BÀN ĂN'),
                ],
              ),
              // Animated pill badge
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _badgeColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$label · ${value.round()}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Gradient track + custom thumb
          SizedBox(
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Gradient bar drawn slightly inside the thumb margins
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 19),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.ocean,    // Introvert  ←
                          AppColors.wisteria, // Ambivert center
                          AppColors.berry,    // Extrovert  →
                        ],
                      ),
                    ),
                  ),
                ),
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 8,
                    activeTrackColor: Colors.transparent,
                    inactiveTrackColor: Colors.transparent,
                    overlayColor: AppColors.berry.withValues(alpha: 0.12),
                    thumbShape: const _PlusThumbShape(),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 20),
                  ),
                  child: Slider(
                    value: value,
                    min: 0,
                    max: 100,
                    onChanged: onChanged,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Zone labels — color + weight animate with active zone
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ZoneLabel(
                icon: Icons.nights_stay_rounded,
                title: 'Introvert',
                sub: 'Tám 1-1',
                active: label == 'Introvert',
                activeColor: AppColors.ocean,
              ),
              _ZoneLabel(
                icon: Icons.brightness_medium_rounded,
                title: 'Ambivert',
                sub: 'Cân bằng',
                active: label == 'Ambivert',
                activeColor: AppColors.berry,
                center: true,
              ),
              _ZoneLabel(
                icon: Icons.wb_sunny_rounded,
                title: 'Extrovert',
                sub: 'Bàn 6+',
                active: label == 'Extrovert',
                activeColor: AppColors.berry,
                end: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ZoneLabel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final bool active;
  final Color activeColor;
  final bool center;
  final bool end;

  const _ZoneLabel({
    required this.icon,
    required this.title,
    required this.sub,
    required this.active,
    required this.activeColor,
    this.center = false,
    this.end = false,
  });

  @override
  Widget build(BuildContext context) {
    final cross = center
        ? CrossAxisAlignment.center
        : end
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start;
    final align = center
        ? TextAlign.center
        : end
            ? TextAlign.right
            : TextAlign.left;
    return Column(
      crossAxisAlignment: cross,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          child: Icon(
            icon,
            size: active ? 18 : 15,
            color: active ? activeColor : AppColors.ink30,
          ),
        ),
        const SizedBox(height: 4),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 240),
          style: GoogleFonts.plusJakartaSans(
            fontSize: active ? 12 : 10.5,
            fontWeight: active ? FontWeight.w800 : FontWeight.w500,
            color: active ? activeColor : AppColors.ink30,
          ),
          child: Text(title, textAlign: align),
        ),
        const SizedBox(height: 2),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 240),
          style: AppTextStyles.body(
            size: 9,
            color:
                active ? activeColor.withValues(alpha: 0.62) : AppColors.ink30,
          ),
          child: Text(sub, textAlign: align),
        ),
      ],
    );
  }
}

// ─── Bottom CTA ──────────────────────────────────────────────────────────────
class _BottomCta extends StatelessWidget {
  final bool loading;
  final bool enabled;
  final VoidCallback onTap;
  const _BottomCta({
    required this.loading,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.ink10, width: 0.5)),
      ),
      child: AnmCTA(
        label: loading ? 'Đang lưu…' : 'Tiếp tục  →',
        onTap: enabled ? onTap : null,
        background: enabled ? AppColors.berry : AppColors.ink30,
      ),
    );
  }
}
