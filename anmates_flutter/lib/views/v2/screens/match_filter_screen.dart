import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme_v2.dart';
import '../../../widgets/v2/area_picker.dart';
import '../../../widgets/v2/filter_parts.dart';
import '../v2_data.dart';
import '../v2_kit.dart';
import '../v2_state.dart';

/// **C1 · Match filter** — narrows Quẹt's deck: distance, area, price tier,
/// life vibe. Opened from Quẹt; Explore's tune icon opens the venue filter
/// (venue_filter_screen.dart) instead. The design's fourth filter, "Trust
/// Score ≥ 90", is gone along with the rest of that mechanic (see
/// trust_screen.dart) — there was never a real score to filter on.
class MatchFilterScreen extends StatelessWidget {
  const MatchFilterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V2State>();

    return FilterLayout(
      header: FilterHeader(
        title: s.t('Match filter', 'Match filter'),
        resetLabel: s.t('Đặt lại', 'Reset'),
        onBack: () => s.go(V2Screen.swipe),
        onReset: s.resetFilters,
      ),
      cta: V2Cta(
        label: s.filterCta,
        height: 54,
        radius: 20,
        fontSize: 15.5,
        onTap: () => s.go(V2Screen.swipe),
      ),
      sheet: V2Sheet(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(child: _label(s.t('Khoảng cách', 'Distance'))),
                Text(
                  s.t('≤ ${s.matchRadiusKm.round()} km', '≤ ${s.matchRadiusKm.round()} km'),
                  style: AppTextV2.name(color: AppColorsV2.wisteria, size: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColorsV2.wisteria,
                thumbColor: Colors.white,
                inactiveTrackColor: AppColorsV2.inkA(0.08),
                overlayColor: AppColorsV2.wisteria.withValues(alpha: 0.12),
              ),
              child: Slider(
                key: const Key('filter-radius'),
                value: s.matchRadiusKm,
                min: 0,
                max: kMaxMatchRadiusKm,
                divisions: 40,
                label: '${s.matchRadiusKm.round()} km',
                onChanged: s.setMatchRadius,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              s.t(
                'Kéo để chỉnh bán kính 0–200 km. Người chưa bật vị trí vẫn hiện.',
                'Drag to set a 0–200 km radius. People without a location still show.',
              ),
              style: AppTextV2.meta(color: AppColorsV2.inkA(0.42)).copyWith(fontSize: 11),
            ),
            const SizedBox(height: 22),
            _label(s.t('Khu vực / Quận', 'Area / district')),
            const SizedBox(height: 11),
            // Districts that actually appear in the loaded catalogue, so
            // the sheet can't offer a filter that matches nothing.
            AreaPicker(
              names: s.areaNames,
              selected: {
                for (final i in s.areas)
                  if (i < s.areaNames.length) s.areaNames[i],
              },
              onToggle: (name) => s.toggleArea(s.areaNames.indexOf(name)),
              en: s.en,
            ),
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
          ],
        ),
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
    return V2TapTarget(
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
