import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme_v2.dart';
import '../../../theme/v2_layout.dart';
import '../v2_data.dart';
import '../v2_kit.dart';
import '../v2_state.dart';

/// **C1 · Match filter** — distance, area, price tier, life vibe. The design's
/// fourth filter, "Trust Score ≥ 90", is gone along with the rest of that
/// mechanic (see trust_screen.dart) — there was never a real score to filter on.
class FiltersScreen extends StatelessWidget {
  const FiltersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V2State>();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        V2Layout.hPad(context), V2Layout.contentTop(context),
        V2Layout.hPad(context), navClearance(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          V2ScreenTitle(
            title: s.t('Match filter', 'Match filter'),
            size: 26,
            trailing: V2TapTarget(
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
                _AreaSection(s: s),
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

class _AreaSection extends StatefulWidget {
  const _AreaSection({required this.s});

  final V2State s;

  @override
  State<_AreaSection> createState() => _AreaSectionState();
}

class _AreaSectionState extends State<_AreaSection> {
  static const _collapsedCount = 6;

  final TextEditingController _controller = TextEditingController();
  bool _expanded = false;
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final names = widget.s.areaNames;

    final q = _fold(_query.trim());
    final List<int> shown;
    if (q.isNotEmpty) {
      shown = [for (var i = 0; i < names.length; i++) if (_fold(names[i]).contains(q)) i];
    } else if (_expanded) {
      shown = [for (var i = 0; i < names.length; i++) i];
    } else {
      shown = [
        for (var i = 0; i < names.length; i++)
          if (i < _collapsedCount || widget.s.areas.contains(i)) i,
      ];
    }

    final hidden = names.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 42,
          child: TextField(
            key: const Key('area-search'),
            controller: _controller,
            onChanged: (v) => setState(() => _query = v),
            textInputAction: TextInputAction.search,
            style: AppTextV2.body(size: 13.5),
            decoration: InputDecoration(
              isDense: true,
              hintText: widget.s.t('Tìm khu vực…', 'Search areas…'),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 18,
                color: AppColorsV2.inkA(0.42),
              ),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded, size: 16),
                      tooltip: widget.s.t('Xoá', 'Clear'),
                      onPressed: () => setState(() {
                        _controller.clear();
                        _query = '';
                      }),
                    )
                  : null,
              filled: true,
              fillColor: AppColorsV2.inkA(0.04),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (_query.isNotEmpty && shown.isEmpty)
          Text(
            widget.s.t('Không tìm thấy khu vực "$_query"',
                'No area matches "$_query"'),
            style: AppTextV2.body(color: AppColorsV2.inkA(0.5), size: 12.5),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final i in shown)
                V2Chip(
                  label: names[i],
                  selected: widget.s.areas.contains(i),
                  onTap: () => widget.s.toggleArea(i),
                ),
              if (_query.isEmpty && names.length > _collapsedCount)
                if (_expanded)
                  V2Chip(
                    key: const Key('area-less'),
                    label: widget.s.t('Thu gọn', 'Show less'),
                    selected: false,
                    onTap: () => setState(() => _expanded = false),
                  )
                else
                  V2Chip(
                    key: const Key('area-more'),
                    label: widget.s.t('+ Thêm ($hidden)', '+ More ($hidden)'),
                    selected: false,
                    onTap: () => setState(() => _expanded = true),
                  ),
            ],
          ),
      ],
    );
  }
}

/// Lower-cases and strips Vietnamese diacritics so "quan 1" finds "Quận 1" and
/// "thu duc" finds "Thủ Đức". `đ` has no Unicode decomposition — map it explicitly.
String _fold(String s) {
  const groups = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ', 'e': 'èéẹẻẽêềếệểễ', 'i': 'ìíịỉĩ', 'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ', 'y': 'ỳýỵỷỹ', 'd': 'đ',
  };
  final out = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    var mapped = ch;
    for (final e in groups.entries) {
      if (e.value.contains(ch)) {
        mapped = e.key;
        break;
      }
    }
    out.write(mapped);
  }
  return out.toString();
}
