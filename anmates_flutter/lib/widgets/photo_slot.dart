import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PhotoSlot extends StatelessWidget {
  final double? width;
  final double height;
  final String label;
  final double radius;
  final bool dark;

  const PhotoSlot({
    super.key,
    this.width,
    this.height = 180,
    this.label = 'PHOTO',
    this.radius = 20,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: dark
            ? const LinearGradient(
                colors: [Color(0xFF1A1A2E), Color(0xFF2E2870)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [
                  AppColors.wisteria.withValues(alpha: 0.3),
                  AppColors.mint,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        border: Border.all(
          color: dark ? Colors.white24 : AppColors.ink10,
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: AppTextStyles.mono(
            size: 10,
            color: dark ? Colors.white54 : AppColors.ink50,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}
