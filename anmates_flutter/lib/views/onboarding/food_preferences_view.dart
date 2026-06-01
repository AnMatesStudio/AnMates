import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/onboarding_draft.dart';
import '../../theme/app_theme.dart';
import '../../widgets/anm_widgets.dart';
import 'vibe_preferences_view.dart';

/// Screen 09 — Gú Ẩm Thực (step 4/6). Chọn 2–5 thẻ ẩm thực.
/// Không call API — lưu vào client draft đến khi Screen 10 "Hoàn tất".
class FoodPreferencesView extends StatefulWidget {
  final VoidCallback onComplete;
  const FoodPreferencesView({super.key, required this.onComplete});

  @override
  State<FoodPreferencesView> createState() => _FoodPreferencesViewState();
}

class _FoodPreferencesViewState extends State<FoodPreferencesView> {
  final _draft = OnboardingDraftController.instance;

  static const _tags = <String, String>{
    'fwb':      '🍺 FWB · Food with beer',
    'ons':      '🧋 ONS · Olong nướng sữa',
    '419':      '🍜 419 · Bún mọc chín',
    'sgbb':     '🍈 SGBB · Sầu riêng bỡ béo',
    'sgdd':     '🍗 SGDD · Súp gà đùi dê',
    'ck':       '☕ CK · Cafe kem',
    'vk':       '🌱 VK · Vegetarian Kho Chay',
    'ex':       '🐸 EX · Ếch xiên',
    'bx':       '🥩 BX · Bò Xào (Beef lover)',
    'ox':       '🦪 OX · Ốc xào (Seafood lover)',
    'spicy':    '🌶️ Ăn cay',
    'sweetie':  '🍰 Sweetie',
    'no_onion': '🚫 Không hành',
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

  void _toggle(String key) {
    setState(() {
      if (_draft.food.contains(key)) {
        _draft.food.remove(key);
        _draft.foodError = null;
      } else {
        if (_draft.food.length >= OnboardingDraftController.maxFood) {
          _draft.foodError =
              'Chọn tối đa ${OnboardingDraftController.maxFood} thẻ';
          return;
        }
        _draft.food.add(key);
        _draft.foodError = null;
      }
    });
  }

  Future<void> _continue() async {
    if (!_draft.validateStep09()) return;
    await _draft.persist();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'onb_vibe'),
        builder: (_) => VibePreferencesView(onComplete: widget.onComplete),
      ),
    );
  }

  bool get _canContinue =>
      _draft.food.length >= OnboardingDraftController.minFood;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(step: 4, total: 6),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bạn ăn kiểu gì?',
                      style: AppTextStyles.display(
                        size: 28,
                        weight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Chọn từ ${OnboardingDraftController.minFood}–'
                      '${OnboardingDraftController.maxFood} thẻ — để ĂnMates '
                      'ghép bạn với những Mate cùng vibe.',
                      style: AppTextStyles.body(
                        size: 14,
                        color: AppColors.ink70,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'GU ẨM THỰC',
                      style: AppTextStyles.mono(
                        size: 10,
                        weight: FontWeight.w700,
                        color: AppColors.berry,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _tags.entries.map((e) {
                        return _FoodTag(
                          label: e.value,
                          selected: _draft.food.contains(e.key),
                          onTap: () => _toggle(e.key),
                        );
                      }).toList(),
                    ),
                    if (_draft.foodError != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error_outline,
                              size: 14, color: Colors.red.shade600),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _draft.foodError!,
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
              ),
            ),
            _BottomBar(
              selected: _draft.food.length,
              max: OnboardingDraftController.maxFood,
              enabled: _canContinue,
              onTap: _continue,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Food tag chip ────────────────────────────────────────────────────────────
class _FoodTag extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FoodTag({
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
