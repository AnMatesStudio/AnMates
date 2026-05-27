import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/anm_logo.dart';
import '../onboarding/onboarding_view.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progressController;
  late final Animation<double> _progressAnim;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _progressAnim = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    );

    _progressController.forward();

    _navTimer = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingView()),
      );
    });
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.4,
            colors: [AppColors.wisteria, AppColors.berry, AppColors.berryDeep],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Corner sparkles
            Positioned(
              top: 56,
              left: 32,
              child: Opacity(
                opacity: 0.35,
                child: Sparkle(size: 36, color: Colors.white, animated: true),
              ),
            ),
            Positioned(
              top: 80,
              right: 44,
              child: Opacity(
                opacity: 0.25,
                child: Sparkle(size: 52, color: Colors.white, animated: true),
              ),
            ),
            Positioned(
              bottom: 130,
              left: 28,
              child: Opacity(
                opacity: 0.4,
                child: Sparkle(size: 28, color: Colors.white, animated: true),
              ),
            ),
            Positioned(
              bottom: 160,
              right: 36,
              child: Opacity(
                opacity: 0.30,
                child: Sparkle(size: 44, color: Colors.white, animated: true),
              ),
            ),

            // Main centered content
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LogoMark(
                    size: 130,
                    fill: Colors.white,
                    accent: AppColors.berry,
                    float: true,
                  ),
                  const SizedBox(height: 20),
                  // Wordmark: "Ăn" white, "Mates" mint
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Ăn',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -1.5,
                          ),
                        ),
                        TextSpan(
                          text: 'Mates',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            color: AppColors.mint,
                            letterSpacing: -1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Tagline
                  Opacity(
                    opacity: 0.85,
                    child: Text(
                      'MỘT CHẠM · MỘT VA · ĂN MIẾT',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        letterSpacing: 2.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom progress area
            Positioned(
              left: 32,
              right: 32,
              bottom: 52,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress bar
                  AnimatedBuilder(
                    animation: _progressAnim,
                    builder: (context, _) {
                      // Target 65% fill
                      final filled = _progressAnim.value * 0.65;
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          height: 4,
                          color: Colors.white.withValues(alpha: 0.2),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: filled,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                gradient: const LinearGradient(
                                  colors: [AppColors.mint, Colors.white],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Đang nhóm lửa nồi lẩu…',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.70),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
