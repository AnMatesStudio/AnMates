import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/anm_widgets.dart';

/// Shared splash-style background gradient applied to every onboarding page
/// so the whole pre-auth flow reads as one surface.
/// Text/buttons are light on top.
const RadialGradient kOnboardGradient = RadialGradient(
  center: Alignment(0, -0.3),
  radius: 1.4,
  colors: [AppColors.wisteria, AppColors.berry, AppColors.berryDeep],
  stops: [0.0, 0.55, 1.0],
);

/// Layout primitive shared across onboarding steps 1–3.
/// Step 4 has its own bespoke layout (map + permission CTA).
///
/// Responsive scaling — small iPhones (≤375pt: SE/mini) get tighter spacing
/// and a smaller title; larger devices keep generous spacing.
class StepLayout extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String body;
  final Widget illustration;

  const StepLayout({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.illustration,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final w = media.size.width;
    final h = media.size.height;
    final isCompact = w <= 380 || h <= 700;

    final illustrationTopPad = isCompact ? 56.0 : 88.0;
    final bottomPad = isCompact ? 100.0 : 120.0;
    final titleSize = isCompact ? 28.0 : 32.0;
    final bodySize = isCompact ? 14.0 : 15.0;
    final horizontalPad = isCompact ? 22.0 : 28.0;

    return Container(
      decoration: const BoxDecoration(gradient: kOnboardGradient),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Illustration area
          Expanded(
            flex: 5,
            child: Padding(
              padding: EdgeInsets.only(
                top: illustrationTopPad,
                left: 16,
                right: 16,
              ),
              child: Center(child: illustration),
            ),
          ),
          // Text area
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPad,
              0,
              horizontalPad,
              bottomPad,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Light eyebrow on the dark gradient
                Eyebrow(eyebrow, color: AppColors.mint),
                SizedBox(height: isCompact ? 8 : 10),
                // H1: Plus Jakarta Sans w700 lh1.2 per design-system.md — white on gradient
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: titleSize,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                    letterSpacing: -1.0,
                  ),
                ),
                SizedBox(height: isCompact ? 10 : 12),
                Text(
                  body,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: bodySize,
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
