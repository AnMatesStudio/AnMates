import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/onboarding_draft.dart';
import '../../theme/app_theme.dart';
import '../../widgets/anm_widgets.dart';
import 'photo_upload_view.dart';

/// Screen 10 — Thích Vibe Nào (step 5/6).
/// Section 1: Nền văn minh yêu thích (culture, min 2 – max 5).
/// Section 2: Vibe buổi ăn (vibe, min 2 – max 5).
/// Không call API — lưu vào draft đến Screen 11 "Hoàn tất".
class VibePreferencesView extends StatefulWidget {
  final VoidCallback onComplete;
  const VibePreferencesView({super.key, required this.onComplete});

  @override
  State<VibePreferencesView> createState() => _VibePreferencesViewState();
}

class _VibePreferencesViewState extends State<VibePreferencesView> {
  final _draft = OnboardingDraftController.instance;

  // ── Section 1: Nền văn minh ───────────────────────────────────────────────
  // Format: key → (code, name) — code renders smaller, name renders bold.
  static const _cultureTags = <String, (String, String)>{
    'vn': ('vn', 'Việt Nam'),
    'kr': ('KR', 'Oppa'),
    'jp': ('JP', 'Konichiwa'),
    'th': ('TH', 'Khap khun'),
    'tw': ('TW', 'Taiwan'),
    'cn': ('CN', 'Tý Tý · Tổng Đài'),
    'us': ('US', 'miền Tây'),
  };

  // ── Section 2: Vibe buổi ăn ───────────────────────────────────────────────
  static const _vibeTags = <String, String>{
    'party':   'Tám tới bến',
    'quiet':   'Yên tĩnh thư giãn',
    'street':  'Vỉa hè bụi bặm',
    'explore': 'Khám phá quán mới',
    'fancy':   'Sang chảnh check-in',
    'yolo':    'Đại đại đi',
    'chill':   'Sao cũng được',
  };

  @override
  void initState() {
    super.initState();
    _draft.addListener(_onDraftChanged);
  }

  void _onDraftChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _draft.removeListener(_onDraftChanged);
    super.dispose();
  }

  // Radio behavior — chỉ 1 nền văn minh tại 1 thời điểm.
  void _toggleCulture(String key) {
    setState(() {
      if (_draft.culture.contains(key)) {
        _draft.culture.remove(key);
      } else {
        _draft.culture
          ..clear()
          ..add(key);
      }
      _draft.cultureError = null;
    });
  }

  void _toggleVibe(String key) {
    setState(() {
      if (_draft.vibe.contains(key)) {
        _draft.vibe.remove(key);
        _draft.vibeError = null;
      } else {
        if (_draft.vibe.length >= OnboardingDraftController.maxVibe) {
          _draft.vibeError =
              'Chọn tối đa ${OnboardingDraftController.maxVibe} thẻ';
          return;
        }
        _draft.vibe.add(key);
        _draft.vibeError = null;
      }
    });
  }

  Future<void> _continue() async {
    if (!_draft.validateVibeScreen()) return;
    await _draft.persist();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'onb_photos'),
        builder: (_) => PhotoUploadView(onComplete: widget.onComplete),
      ),
    );
  }

  bool get _canContinue =>
      _draft.culture.isNotEmpty &&
      _draft.vibe.length >= OnboardingDraftController.minVibe;

  int get _totalSelected => _draft.vibe.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(step: 5, total: 6),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bạn thích vibe nào?',
                      style: AppTextStyles.display(
                        size: 28,
                        weight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Nền văn minh ẩm thực + không khí buổi ăn — để ĂnMates '
                      'đề xuất quán đúng vibe (chọn tối đa '
                      '${OnboardingDraftController.maxVibe} thẻ mỗi mục).',
                      style: AppTextStyles.body(
                        size: 14,
                        color: AppColors.ink70,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Section 1: Nền văn minh (single-select) ─────────────
                    _SectionCard(
                      label: 'CHỌN NỀN VĂN MINH YÊU THÍCH',
                      count: _draft.culture.length,
                      max: 1,
                      error: _draft.cultureError,
                      chips: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _cultureTags.entries.map((e) {
                          final (code, name) = e.value;
                          return _CultureTag(
                            code: code,
                            name: name,
                            selected: _draft.culture.contains(e.key),
                            onTap: () => _toggleCulture(e.key),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Section 2: Vibe buổi ăn ─────────────────────────────
                    _SectionCard(
                      label: 'VIBE BUỔI ĂN',
                      count: _draft.vibe.length,
                      max: OnboardingDraftController.maxVibe,
                      error: _draft.vibeError,
                      color: AppColors.ocean,
                      chips: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _vibeTags.entries.map((e) {
                          return _SimpleTag(
                            label: e.value,
                            selected: _draft.vibe.contains(e.key),
                            onTap: () => _toggleVibe(e.key),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _BottomBar(
              selected: _totalSelected,
              max: OnboardingDraftController.maxVibe,
              enabled: _canContinue,
              onTap: _continue,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section card — rounded border box containing label + chips + error ────────
class _SectionCard extends StatelessWidget {
  final String label;
  final int count;
  final int max;
  final String? error;
  final Widget chips;
  /// Accent color for label text, border, and count badge. Default: berry.
  final Color? color;

  const _SectionCard({
    required this.label,
    required this.count,
    required this.max,
    required this.chips,
    this.error,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.berry;
    final hasError = error != null;
    final borderColor = hasError
        ? Colors.red.shade300
        : accent.withValues(alpha: 0.20);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: label + count badge
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.mono(
                    size: 10,
                    weight: FontWeight.w700,
                    color: hasError ? Colors.red.shade600 : accent,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: count > 0
                      ? accent.withValues(alpha: 0.10)
                      : AppColors.ink10,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count / $max',
                  style: AppTextStyles.mono(
                    size: 10,
                    weight: FontWeight.w700,
                    color: count > 0 ? accent : AppColors.ink50,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          chips,
          if (hasError) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline,
                    size: 14, color: Colors.red.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    error!,
                    style: AppTextStyles.body(
                      size: 12,
                      color: Colors.red.shade600,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Culture tag chip (code prefix + name) ────────────────────────────────────
class _CultureTag extends StatelessWidget {
  final String code;
  final String name;
  final bool selected;
  final VoidCallback onTap;
  const _CultureTag({
    required this.code,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.berry : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.berry : AppColors.ink10,
            width: 1.3,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.berry.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$code ',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Colors.white.withValues(alpha: 0.75)
                      : AppColors.ink30,
                  letterSpacing: 0.5,
                ),
              ),
              TextSpan(
                text: name,
                style: GoogleFonts.beVietnamPro(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Simple tag chip ──────────────────────────────────────────────────────────
class _SimpleTag extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SimpleTag({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.berry : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.berry : AppColors.ink10,
            width: 1.3,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.berry.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.beVietnamPro(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }
}


// ─── Top bar ──────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final int step;
  final int total;
  const _TopBar({required this.step, required this.total});

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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: step / total,
                minHeight: 5,
                backgroundColor: AppColors.ink10,
                valueColor: const AlwaysStoppedAnimation(AppColors.berry),
              ),
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

// ─── Bottom bar ───────────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final int selected;
  final int max;
  final bool enabled;
  final VoidCallback onTap;

  const _BottomBar({
    required this.selected,
    required this.max,
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
      child: Row(
        children: [
          Text(
            '$selected / $max đã chọn',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: enabled ? AppColors.berry : AppColors.ink50,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: AnmCTA(
              label: 'Tiếp tục  →',
              onTap: enabled ? onTap : null,
              background: enabled ? AppColors.berry : AppColors.ink30,
            ),
          ),
        ],
      ),
    );
  }
}
