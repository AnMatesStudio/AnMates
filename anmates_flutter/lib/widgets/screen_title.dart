import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ScreenTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool dark;
  final TextAlign align;

  const ScreenTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.dark = false,
    this.align = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align == TextAlign.center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.heading1(
            color: dark ? Colors.white : AppColors.ink,
          ),
          textAlign: align,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: AppTextStyles.body(
              size: 15,
              color: dark
                  ? Colors.white.withValues(alpha: 0.7)
                  : AppColors.ink70,
              height: 1.4,
            ),
            textAlign: align,
          ),
        ],
      ],
    );
  }
}
