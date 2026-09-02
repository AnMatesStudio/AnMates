import 'package:flutter/material.dart';

import '../../theme/app_theme_v2.dart';

/// Small building blocks repeated across the v2 screens — pill chips, the
/// gradient CTA, the circular back button, the white sheet card. Keeping them
/// here stops each screen from re-deriving the same shadow and radius values.

/// Vertical space the floating glass nav covers at the bottom of the screen,
/// including the device's own inset.
///
/// Feed screens (Explore, Profile) deliberately scroll *under* the glass — that
/// is what the blur is for. Screens whose own controls sit at the bottom pad by
/// this instead, so nothing ends up unreachable behind the bar.
double navClearance(BuildContext context) =>
    96 + MediaQuery.paddingOf(context).bottom;

/// The design's `chip(on)` helper: Wisteria when selected, hairline when not.
class V2Chip extends StatelessWidget {
  const V2Chip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColorsV2.wisteria : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColorsV2.wisteria : AppColorsV2.inkA(0.12),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: AppTextV2.name(
            color: selected ? Colors.white : AppColorsV2.inkA(0.6),
            size: 12.5,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Primary action: the blue→wisteria gradient with its violet lift.
class V2Cta extends StatelessWidget {
  const V2Cta({
    super.key,
    required this.label,
    required this.onTap,
    this.height = 56,
    this.radius = 999,
    this.fontSize = 16,
  });

  final String label;
  final VoidCallback onTap;
  final double height;
  final double radius;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          gradient: AppGradientsV2.cta,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: AppShadowsV2.ctaGlow(),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextV2.cta().copyWith(fontSize: fontSize),
        ),
      ),
    );
  }
}

/// The round white back chevron used on detail, bill, trust and plans.
class V2BackButton extends StatelessWidget {
  const V2BackButton({super.key, required this.onTap, this.size = 38, this.radius});

  final VoidCallback onTap;
  final double size;

  /// Onboarding uses a rounded square instead of a circle.
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: radius == null ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: radius == null ? null : BorderRadius.circular(radius!),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0A285A).withValues(alpha: 0.13),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Text(
          '‹',
          style: AppTextV2.name(size: size > 40 ? 19 : 16)
              .copyWith(height: 1, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// The tall white sheet every settings-style screen sits inside.
class V2Sheet extends StatelessWidget {
  const V2Sheet({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 28,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10366E).withValues(alpha: 0.18),
            blurRadius: 34,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Screen title + optional trailing action, at the design's 25/26px weight 800.
class V2ScreenTitle extends StatelessWidget {
  const V2ScreenTitle({super.key, required this.title, this.trailing, this.size = 25});

  final String title;
  final Widget? trailing;
  final double size;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      title,
      style: AppTextV2.section().copyWith(fontSize: size, letterSpacing: size * -0.03),
    );
    if (trailing == null) return text;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [Expanded(child: text), trailing!],
    );
  }
}

/// Small caps label above a group of controls.
class V2Eyebrow extends StatelessWidget {
  const V2Eyebrow(this.label, {super.key, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      Text(label, style: AppTextV2.eyebrow(color: color));
}
