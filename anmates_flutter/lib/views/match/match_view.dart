import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/anm_logo.dart';
import '../../widgets/anm_widgets.dart';

class MatchView extends StatelessWidget {
  final String mateName;
  final String restaurantName;
  final VoidCallback? onChat;
  final VoidCallback? onContinue;

  const MatchView({
    super.key,
    this.mateName = 'Khánh',
    this.restaurantName = 'Tiệm mì Ramen Q1',
    this.onChat,
    this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.6,
            colors: [AppColors.wisteria, AppColors.berryDeep],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Floating sparkles
              ..._buildSparkles(),
              // Main content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 48),
                    // Eyebrow
                    Text(
                      'VA TRÚNG MATE',
                      style: AppTextStyles.mono(
                        size: 11,
                        weight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.7),
                        letterSpacing: 2.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Headline
                    Text(
                      'Có Mate rồi!',
                      style: AppTextStyles.display(
                        size: 44,
                        weight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -1.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Sub text
                    Text(
                      'Cả hai đều thèm $restaurantName — vào chat làm nóng nồi lẩu nào.',
                      style: AppTextStyles.body(
                        size: 15,
                        color: Colors.white.withValues(alpha: 0.82),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    // Overlapping photo cards
                    _buildPhotoStack(),
                    const Spacer(),
                    // CTAs
                    AnmCTA(
                      label: "Nói 'Hello' trước đi 👋",
                      onTap: onChat ?? () => Navigator.maybePop(context),
                      background: AppColors.berry,
                      foreground: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed:
                            onContinue ?? () => Navigator.maybePop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(
                            color: Colors.white38,
                            width: 1.5,
                          ),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          'Tiếp tục quẹt',
                          style: AppTextStyles.cta(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoStack() {
    return SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Left photo — Vy, rotated -6°
          Positioned(
            left: 20,
            child: Transform.rotate(
              angle: -6 * 3.14159 / 180,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: PhotoSlot(
                  width: 140,
                  height: 180,
                  radius: 16,
                  label: 'VY',
                ),
              ),
            ),
          ),
          // Right photo — Khánh, rotated +6°
          Positioned(
            right: 20,
            child: Transform.rotate(
              angle: 6 * 3.14159 / 180,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: PhotoSlot(
                  width: 140,
                  height: 180,
                  radius: 16,
                  label: mateName.toUpperCase(),
                ),
              ),
            ),
          ),
          // Center heart circle
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.berry.withValues(alpha: 0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.favorite, color: AppColors.berry, size: 30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSparkles() {
    // (top, left_or_null, right_or_null, size, opacity)
    final configs = <(double, double?, double?, double, double)>[
      (60.0, 24.0, null, 18.0, 0.60),
      (80.0, 80.0, null, 10.0, 0.40),
      (40.0, null, 30.0, 22.0, 0.70),
      (110.0, null, 70.0, 12.0, 0.45),
      (200.0, 40.0, null, 14.0, 0.35),
      (240.0, null, 40.0, 16.0, 0.50),
      (160.0, 160.0, null, 8.0, 0.30),
      (300.0, null, 20.0, 20.0, 0.40),
    ];

    return configs.map((c) {
      return Positioned(
        top: c.$1,
        left: c.$2,
        right: c.$3,
        child: Opacity(
          opacity: c.$5,
          child: Sparkle(size: c.$4, color: Colors.white),
        ),
      );
    }).toList();
  }
}
