import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme_v2.dart';
import '../../../widgets/v2/area_picker.dart';
import '../../../widgets/v2/filter_parts.dart';
import '../v2_data.dart';
import '../v2_kit.dart';
import '../v2_state.dart';

/// **B1a · Lọc quán** — narrows Explore's feed: the radius (the same one the
/// header sets), the dish tile, districts and spend per person. Everything
/// but the radius is applied on the device over the venues already loaded.
/// The mates filter is its own screen, opened from Quẹt.
class VenueFilterScreen extends StatelessWidget {
  const VenueFilterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V2State>();
    final areas = s.venueAreaNames;

    return FilterLayout(
      header: FilterHeader(
        title: s.t('Lọc quán', 'Filter spots'),
        resetLabel: s.t('Đặt lại', 'Reset'),
        onBack: () => s.go(V2Screen.home),
        onReset: s.resetVenueFilters,
      ),
      cta: V2Cta(
        label: s.venueFilterCta,
        height: 54,
        radius: 20,
        fontSize: 15.5,
        onTap: () => s.go(V2Screen.home),
      ),
      sheet: V2Sheet(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RadiusSection(s: s),
            const SizedBox(height: 22),
            _label(s.t('Món ăn', 'Dish')),
            const SizedBox(height: 11),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (var i = 0; i < kFeedCategories.length; i++)
                V2Chip(
                  label: s.tr(kFeedCategories[i].label),
                  selected: s.feedCategory == i,
                  onTap: () => s.setFeedCategory(i),
                ),
            ]),
            const SizedBox(height: 22),
            _label(s.t('Khu vực / Quận', 'Area / district')),
            const SizedBox(height: 11),
            if (areas.isEmpty)
              _hint(s.t('Chưa có quán nào trong bán kính để chọn khu vực.',
                  'No spots in range to pick an area from.'))
            else
              // Districts of the venues in range, so a chip always matches something.
              AreaPicker(
                names: areas,
                selected: s.venueAreas,
                onToggle: s.toggleVenueArea,
                en: s.en,
              ),
            const SizedBox(height: 22),
            _label(s.t('Khoảng giá / người', 'Spend per person')),
            const SizedBox(height: 11),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (var i = 0; i < kPrices.length; i++)
                V2Chip(
                  label: kPrices[i],
                  selected: s.venuePrices.contains(i),
                  onTap: () => s.toggleVenuePrice(i),
                ),
            ]),
            const SizedBox(height: 8),
            _hint(s.t(
              'Theo khoảng giá thực đơn của quán. Quán chưa có giá sẽ ẩn khi chọn mức giá.',
              "By the venue's menu prices. Spots with no price on file hide once you pick one.",
            )),
          ],
        ),
      ),
    );
  }

  static Widget _label(String text) => Text(text, style: AppTextV2.name(size: 13));

  static Widget _hint(String text) => Text(
        text,
        style: AppTextV2.meta(color: AppColorsV2.inkA(0.42)).copyWith(fontSize: 11),
      );
}

/// The feed radius, as in the Explore header's sheet: the value follows the
/// finger and the feed is refetched once, when the drag ends.
class _RadiusSection extends StatefulWidget {
  const _RadiusSection({required this.s});
  final V2State s;

  @override
  State<_RadiusSection> createState() => _RadiusSectionState();
}

class _RadiusSectionState extends State<_RadiusSection> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final km = (_drag ?? s.radiusKm.toDouble()).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: VenueFilterScreen._label(s.t('Khoảng cách', 'Distance'))),
            Text(
              '≤ $km km',
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
            key: const Key('venue-filter-radius'),
            value: km.toDouble(),
            min: kRadiusMinKm.toDouble(),
            max: kRadiusMaxKm.toDouble(),
            divisions: (kRadiusMaxKm - kRadiusMinKm) ~/ kRadiusStepKm,
            label: '$km km',
            onChanged: (v) => setState(() => _drag = v),
            onChangeEnd: (v) {
              setState(() => _drag = null);
              // Same radius with the location off still asks for the location.
              if (v.round() != s.radiusKm || s.locationUnavailable) s.setRadiusKm(v.round());
            },
          ),
        ),
        const SizedBox(height: 8),
        VenueFilterScreen._hint(s.locationUnavailable
            ? s.t('Chưa bật vị trí nên đang hiện mọi quán. Kéo thanh để bật vị trí và lọc theo khoảng cách.',
                'Location is off, so every spot shows. Drag to turn it on and filter by distance.')
            : s.t('Chỉ hiện quán trong bán kính này.', 'Only spots within this radius show.')),
      ],
    );
  }
}
