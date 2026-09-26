import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/app_theme_v2.dart';
import '../../views/v2/v2_kit.dart';

/// Liquid-glass sheet for the Explore feed's radius: a slider over
/// [minKm]–[maxKm] in [stepKm] steps, and an apply button. Glass, scrim and
/// insets match [NotificationsSheet]; it hugs the bottom, just above the nav.
///
/// The value stays local while dragging and reaches [onApply] only on "Áp
/// dụng", so the feed isn't refetched at every step of the drag.
class RadiusSheet extends StatefulWidget {
  const RadiusSheet({
    super.key,
    required this.en,
    required this.radiusKm,
    required this.minKm,
    required this.maxKm,
    required this.stepKm,
    required this.locationOff,
    required this.onApply,
    required this.onClose,
  });

  final bool en;
  final int radiusKm;
  final int minKm;
  final int maxKm;
  final int stepKm;

  /// No device location: the radius can't filter anything until there is one.
  final bool locationOff;

  final ValueChanged<int> onApply;
  final VoidCallback onClose;

  @override
  State<RadiusSheet> createState() => _RadiusSheetState();
}

class _RadiusSheetState extends State<RadiusSheet> {
  late double _km = widget.radiusKm.toDouble();

  String _t(String vi, String en) => widget.en ? en : vi;

  @override
  Widget build(BuildContext context) {
    final km = _km.round();

    return Stack(
      children: [
        GestureDetector(
          onTap: widget.onClose,
          child: Container(color: const Color(0xFF181430).withValues(alpha: 0.28)),
        ),
        Positioned(
          left: 10,
          right: 10,
          top: MediaQuery.paddingOf(context).top + 26,
          bottom: navClearance(context) - 10,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(34),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(34),
                    border: Border.all(color: AppColorsV2.whiteA(0.8)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColorsV2.whiteA(0.9), AppColorsV2.whiteA(0.8)],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      V2TapTarget(
                        onTap: widget.onClose,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 11, bottom: 3),
                          child: Center(
                            child: Container(
                              width: 38,
                              height: 5,
                              decoration: BoxDecoration(
                                color: AppColorsV2.inkA(0.16),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Scrolls on a phone held sideways; the button below
                      // stays in view either way.
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                          child: _body(km),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                        child: V2Cta(
                          label: _t('Áp dụng', 'Apply'),
                          height: 54,
                          radius: 20,
                          fontSize: 15.5,
                          onTap: () => widget.onApply(km),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _body(int km) {
    final hint = AppTextV2.meta(color: AppColorsV2.inkA(0.5));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _t('Bán kính tìm quán', 'Search radius'),
          style: AppTextV2.section().copyWith(fontSize: 22, letterSpacing: -0.66),
        ),
        const SizedBox(height: 3),
        Text(_t('Chỉ hiện quán trong khoảng cách này', 'Only venues within this distance'),
            style: hint),
        const SizedBox(height: 14),
        Text(
          '$km km',
          textAlign: TextAlign.center,
          style: AppTextV2.section(color: AppColorsV2.wisteria)
              .copyWith(fontSize: 30, letterSpacing: -0.9),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 8,
            activeTrackColor: AppColorsV2.wisteria,
            inactiveTrackColor: const Color(0xFFEDF1F7),
            thumbColor: Colors.white,
            overlayColor: AppColorsV2.wisteria.withValues(alpha: 0.12),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12, elevation: 3),
            // 48pt tall, the app's minimum hit size.
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
            trackShape: const RoundedRectSliderTrackShape(),
            tickMarkShape: SliderTickMarkShape.noTickMark,
            showValueIndicator: ShowValueIndicator.never,
          ),
          child: Slider(
            value: _km,
            min: widget.minKm.toDouble(),
            max: widget.maxKm.toDouble(),
            divisions: (widget.maxKm - widget.minKm) ~/ widget.stepKm,
            semanticFormatterCallback: (v) => '${v.round()} km',
            onChanged: (v) => setState(() => _km = v),
          ),
        ),
        Row(children: [
          Text('${widget.minKm} km', style: hint),
          const Spacer(),
          Text('${widget.maxKm} km', style: hint),
        ]),
        if (widget.locationOff) ...[
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_off_rounded, size: 16, color: AppColorsV2.inkA(0.5)),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _t('Bật quyền vị trí để lọc quán theo khoảng cách',
                      'Turn on location to filter venues by distance'),
                  style: hint,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
