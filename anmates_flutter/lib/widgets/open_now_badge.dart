import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/opening_hours.dart';

/// A compact pill that shows whether a venue is open right now, derived from its
/// OSM `opening_hours` string (Feature A). When the hours can't be parsed it
/// falls back to showing the raw string in a neutral chip — never blank, never
/// a misleading green/red.
class OpenNowBadge extends StatelessWidget {
  final String? openingHours;

  /// `true` → full "Đang mở · đóng 22:00"; `false` → compact "Đang mở".
  final bool detailed;

  const OpenNowBadge({super.key, required this.openingHours, this.detailed = false});

  // Local tokens — the brand palette has no semantic open/closed colors.
  static const _openInk = Color(0xFF1B7F4B);
  static const _openBg = Color(0x1A1B9E5A);
  static const _closedInk = Color(0xFFB23B3B);
  static const _closedBg = Color(0x14B23B3B);

  @override
  Widget build(BuildContext context) {
    final status = parseOpeningHours(openingHours);

    switch (status.state) {
      case OpenNow.open:
        return _pill('🟢 ${detailed ? status.label : status.shortLabel}', _openInk, _openBg);
      case OpenNow.closed:
        return _pill(detailed ? status.label : status.shortLabel, _closedInk, _closedBg);
      case OpenNow.unknown:
        final raw = openingHours?.trim();
        if (raw == null || raw.isEmpty) return const SizedBox.shrink();
        return _pill('🕒 $raw', AppColors.ocean, AppColors.ocean.withValues(alpha: 0.10));
    }
  }

  Widget _pill(String text, Color ink, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: AppTextStyles.mono(
          size: 9,
          weight: FontWeight.w600,
          color: ink,
          letterSpacing: 0.3,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
