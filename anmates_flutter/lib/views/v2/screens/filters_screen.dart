import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme_v2.dart';
import '../v2_data.dart';
import '../v2_kit.dart';
import '../v2_state.dart';

/// **C1 · Lọc bể match** — area, price tier, life vibe and the Trust ≥ 90 gate.
class FiltersScreen extends StatelessWidget {
  const FiltersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V2State>();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(18, 104, 18, navClearance(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          V2ScreenTitle(
            title: s.t('Lọc bể match', 'Match filters'),
            size: 26,
            trailing: GestureDetector(
              onTap: s.resetFilters,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: AppShadowsV2.pill,
                ),
                child: Text(
                  s.t('Đặt lại', 'Reset'),
                  style: AppTextV2.name(color: AppColorsV2.wisteria, size: 11.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          V2Sheet(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _label(s.t('Khu vực / Quận', 'Area / district')),
                const SizedBox(height: 11),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (var i = 0; i < kAreaNames.length; i++)
                    V2Chip(
                      label: kAreaNames[i],
                      selected: s.areas.contains(i),
                      onTap: () => s.toggleArea(i),
                    ),
                ]),
                const SizedBox(height: 22),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(child: _label(s.t('Khoảng giá / người', 'Spend per person'))),
                    Text(s.priceLabel,
                        style: AppTextV2.name(color: AppColorsV2.wisteria, size: 13)),
                  ],
                ),
                const SizedBox(height: 12),
                _PriceTrack(s: s),
                const SizedBox(height: 8),
                Text(
                  s.t('Bấm vào thanh để đổi mức', 'Tap the track to cycle tiers'),
                  style: AppTextV2.meta(color: AppColorsV2.inkA(0.42)).copyWith(fontSize: 11),
                ),
                const SizedBox(height: 22),
                _label(s.t('Vibe sống', 'Life vibe')),
                const SizedBox(height: 11),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (var i = 0; i < kVibeTags.length; i++)
                    V2Chip(
                      label: s.tr(kVibeTags[i]),
                      selected: s.vibeTags.contains(i),
                      onTap: () => s.toggleVibeTag(i),
                    ),
                ]),
                const SizedBox(height: 22),
                _TrustToggle(s: s),
                const SizedBox(height: 22),
                V2Cta(
                  label: s.filterCta,
                  height: 54,
                  radius: 20,
                  fontSize: 15.5,
                  onTap: () => s.go(V2Screen.swipe),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _label(String text) => Text(text, style: AppTextV2.name(size: 13));
}

class _PriceTrack extends StatelessWidget {
  const _PriceTrack({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: s.cyclePrice,
      child: SizedBox(
        height: 22,
        child: LayoutBuilder(
          builder: (context, c) {
            final x = c.maxWidth * s.pricePct;
            return Stack(clipBehavior: Clip.none, children: [
              Positioned(
                left: 0, right: 0, top: 6,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF1F7),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Positioned(
                left: 0, top: 6,
                child: Container(
                  width: x, height: 10,
                  decoration: BoxDecoration(
                    color: AppColorsV2.wisteria,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Positioned(
                left: x - 11, top: 0,
                child: Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10366E).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

class _TrustToggle extends StatelessWidget {
  const _TrustToggle({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F3FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: s.toggleTrustOnly,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 46, height: 28,
            decoration: BoxDecoration(
              color: s.trustOnly ? AppColorsV2.wisteria : const Color(0xFFDDE4EE),
              borderRadius: BorderRadius.circular(99),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              alignment: s.trustOnly ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 22, height: 22,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            s.t('Chỉ mates có Trust Score ≥ 90', 'Only mates with Trust Score ≥ 90'),
            style: AppTextV2.body(color: AppColorsV2.ink, size: 12)
                .copyWith(fontWeight: FontWeight.w600, height: 1.45),
          ),
        ),
      ]),
    );
  }
}
