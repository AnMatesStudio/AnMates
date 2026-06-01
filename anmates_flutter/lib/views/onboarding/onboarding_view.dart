import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../../widgets/anm_logo.dart';
import '../auth/phone_input_view.dart';
import '../main_tab_view.dart';
import 'steps/step_1_page.dart';
import 'steps/step_2_page.dart';
import 'steps/step_3_page.dart';
import 'steps/step_4_page.dart';
import 'widgets/bottom_controls.dart';

/// Top-level onboarding flow coordinator.
///
/// Each step lives in its own file under `steps/`. This widget owns:
///   - the PageController + current page index
///   - the top "Bỏ qua" overlay (steps 1–3)
///   - the bottom dot indicators + CTA (steps 1–3)
///   - navigation to phone-input on finish
///
/// Step 4 builds its own top bar and CTA (location-permission flow), so the
/// overlays here are hidden on that page.
class OnboardingView extends StatefulWidget {
  final VoidCallback? onFinished;

  const OnboardingView({super.key, this.onFinished});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const int _totalPages = 4;

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _navigateAway();
    }
  }

  void _goBack() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _skip() => _navigateAway();

  void _navigateAway() {
    if (widget.onFinished != null) {
      widget.onFinished!();
    } else {
      // Capture NavigatorState BEFORE pushReplacement disposes this State —
      // otherwise the onAuthenticated callback fires against an unmounted
      // context and silently no-ops.
      final navigator = Navigator.of(context);
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => PhoneInputView(
            onAuthenticated: () => navigator.pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const MainTabView()),
              (_) => false,
            ),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          ScrollConfiguration(
            // Enable horizontal swipe via touch + mouse + trackpad + stylus
            // (Flutter web disables mouse drag on scroll widgets by default).
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: const {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
                PointerDeviceKind.stylus,
              },
              scrollbars: false,
            ),
            child: PageView(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (i) => setState(() => _currentPage = i),
              children: [
                const Step1Page(),
                const Step2Page(),
                const Step3Page(),
                Step4Page(onFinished: _navigateAway, onBack: _goBack),
              ],
            ),
          ),
          // Top bar overlay — hidden on last page (it renders its own)
          if (_currentPage < _totalPages - 1)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const LogoMark(
                      size: 32,
                      fill: Colors.white,
                      accent: AppColors.mint,
                    ),
                    GestureDetector(
                      onTap: _skip,
                      child: Text(
                        'Bỏ qua',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Bottom controls overlay — hidden on last page
          if (_currentPage < _totalPages - 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: BottomControls(
                currentPage: _currentPage,
                totalPages: _totalPages,
                onNext: _nextPage,
              ),
            ),
        ],
      ),
    );
  }
}
