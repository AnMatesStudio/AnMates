import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AnmAvatar extends StatelessWidget {
  final double size;
  final int hue;
  final Color? ringColor;

  const AnmAvatar({super.key, this.size = 48, this.hue = 0, this.ringColor});

  static const _grads = [
    [AppColors.berry, AppColors.wisteria],
    [AppColors.ocean, AppColors.glaucous],
    [AppColors.wisteriaDeep, AppColors.berry],
    [AppColors.glaucous, AppColors.wisteria],
    [AppColors.berryDeep, AppColors.ocean],
    [AppColors.ocean, AppColors.wisteriaDeep],
  ];

  @override
  Widget build(BuildContext context) {
    final g = _grads[hue % _grads.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: g,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: ringColor != null
            ? Border.all(color: ringColor!, width: 2.5)
            : null,
      ),
    );
  }
}
