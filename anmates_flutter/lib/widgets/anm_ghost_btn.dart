import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class AnmGhostBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool dark;

  const AnmGhostBtn({
    super.key,
    required this.label,
    this.onTap,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: dark ? Colors.white : AppColors.ink,
        side: BorderSide(
          color: dark ? Colors.white24 : AppColors.ink10,
          width: 1.5,
        ),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: dark ? Colors.white : AppColors.ink,
        ),
      ),
    );
  }
}
