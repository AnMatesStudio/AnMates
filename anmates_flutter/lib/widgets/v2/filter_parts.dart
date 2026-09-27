import 'package:flutter/material.dart';

import '../../theme/app_theme_v2.dart';
import '../../theme/v2_layout.dart';
import '../../views/v2/v2_kit.dart';

/// Layout of the venue and mates filters: the header and the sheet scroll,
/// the apply button stays pinned below them — its live count is in view while
/// chips are picked.
class FilterLayout extends StatelessWidget {
  const FilterLayout({super.key, required this.header, required this.sheet, required this.cta});

  final Widget header;
  final Widget sheet;
  final Widget cta;

  @override
  Widget build(BuildContext context) {
    final pad = V2Layout.hPad(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(pad, V2Layout.contentTop(context), pad, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [header, const SizedBox(height: 16), sheet],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 4, pad, 14 + MediaQuery.paddingOf(context).bottom),
          child: cta,
        ),
      ],
    );
  }
}

/// Title row of the venue and mates filters: back to the screen the filter
/// narrows, the title, and a "Đặt lại" pill.
class FilterHeader extends StatelessWidget {
  const FilterHeader({
    super.key,
    required this.title,
    required this.resetLabel,
    required this.onBack,
    required this.onReset,
  });

  final String title;
  final String resetLabel;
  final VoidCallback onBack;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      V2BackButton(size: 40, onTap: onBack),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextV2.section().copyWith(fontSize: 26, letterSpacing: 26 * -0.03),
        ),
      ),
      V2TapTarget(
        onTap: onReset,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: AppShadowsV2.pill,
          ),
          child: Text(
            resetLabel,
            style: AppTextV2.name(color: AppColorsV2.wisteria, size: 11.5),
          ),
        ),
      ),
    ]);
  }
}

/// The number of filters switched on, as a small wisteria badge over a
/// filter button. Nothing when [count] is 0.
class FilterCountBadge extends StatelessWidget {
  const FilterCountBadge({super.key, required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return child;
    return Stack(clipBehavior: Clip.none, children: [
      child,
      Positioned(
        top: -4,
        right: -4,
        child: Container(
          constraints: const BoxConstraints(minWidth: 17),
          height: 17,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColorsV2.wisteria,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: Text(
            '$count',
            style: AppTextV2.name(color: Colors.white, size: 9.5).copyWith(height: 1),
          ),
        ),
      ),
    ]);
  }
}
