import 'package:flutter/material.dart';

// ─── ANM Brand Tokens ───────────────────────────────────────────────────────
class AppColors {
  // Core palette
  static const berry = Color(0xFFB8336A);
  static const berryDeep = Color(0xFF8E1F4D);
  static const ocean = Color(0xFF534BA8);
  static const oceanDeep = Color(0xFF2E2870);
  static const wisteria = Color(0xFFC490D1);
  static const wisteriaDeep = Color(0xFF9B6FA8);
  static const glaucous = Color(0xFF7D8CC4);
  static const mint = Color(0xFFF1FFF8);
  static const mintWarm = Color(0xFFFAF6F0);

  /// Soft berry-tinted background — Screen 03 Social Proof bg (#FAF1F5)
  static const berryTint = Color(0xFFFAF1F5);

  // Ink
  static const ink = Color(0xFF121212);
  static const ink70 = Color(0xB3121212);
  static const ink50 = Color(0x80121212);
  static const ink30 = Color(0x4D121212);
  static const ink10 = Color(0x1A121212);

  // Semantic
  static const background = mint;
  static const surface = Colors.white;
  static const primary = berry;
}

// ─── Typography ─────────────────────────────────────────────────────────────
class AppTextStyles {
  // Display / UI — Plus Jakarta Sans (bundled, no network fetch)
  static TextStyle display({
    double size = 44,
    FontWeight weight = FontWeight.w800,
    Color color = AppColors.ink,
    double letterSpacing = -1.5,
    double? height,
  }) => TextStyle(
    fontFamily: 'PlusJakartaSans',
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );

  // Body / Vietnamese — Be Vietnam Pro (bundled, no network fetch)
  static TextStyle body({
    double size = 15,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.ink,
    double? height,
  }) => TextStyle(
    fontFamily: 'BeVietnamPro',
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height ?? 1.55,
  );

  // Mono / Data — JetBrains Mono (bundled, no network fetch)
  static TextStyle mono({
    double size = 11,
    FontWeight weight = FontWeight.w500,
    Color color = AppColors.ink50,
    double letterSpacing = 1.5,
  }) => TextStyle(
    fontFamily: 'JetBrainsMono',
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
  );

  // Convenience
  static TextStyle heading1({Color color = AppColors.ink}) => display(
    size: 30,
    weight: FontWeight.w800,
    color: color,
    letterSpacing: -1.0,
    height: 1.1,
  );

  static TextStyle heading2({Color color = AppColors.ink}) => display(
    size: 24,
    weight: FontWeight.w800,
    color: color,
    letterSpacing: -0.8,
    height: 1.15,
  );

  static TextStyle label({Color color = AppColors.ink50}) =>
      mono(size: 10, weight: FontWeight.w700, color: color, letterSpacing: 2.0);

  static TextStyle eyebrow({Color color = AppColors.berry}) =>
      mono(size: 10, weight: FontWeight.w600, color: color, letterSpacing: 2.0);

  static TextStyle cta({Color color = Colors.white}) => display(
    size: 17,
    weight: FontWeight.w700,
    color: color,
    letterSpacing: -0.3,
  );

  static TextStyle chip({bool active = false, Color? color}) => TextStyle(
        fontFamily: 'BeVietnamPro',
        fontSize: 13,
        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
        color: active ? Colors.white : (color ?? AppColors.ink),
      );
}

// ─── Theme ───────────────────────────────────────────────────────────────────
class AppTheme {
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: AppColors.berry,
      secondary: AppColors.ocean,
      surface: AppColors.mint,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.ink,
    ),
    scaffoldBackgroundColor: AppColors.mint,
    textTheme: _buildTextTheme(),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.mint,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: AppTextStyles.display(size: 18, weight: FontWeight.w700),
      iconTheme: const IconThemeData(color: AppColors.ink),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.berry,
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
        textStyle: AppTextStyles.cta(),
        elevation: 0,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: AppColors.ink10),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: AppColors.ink10),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.berry, width: 1.5),
      ),
    ),
  );

  static TextTheme _buildTextTheme() => TextTheme(
    displayLarge: AppTextStyles.display(size: 44),
    displayMedium: AppTextStyles.display(size: 36),
    displaySmall: AppTextStyles.display(size: 28),
    headlineLarge: AppTextStyles.heading1(),
    headlineMedium: AppTextStyles.heading2(),
    headlineSmall: AppTextStyles.display(size: 20, weight: FontWeight.w700),
    titleLarge: AppTextStyles.display(size: 18, weight: FontWeight.w700),
    titleMedium: AppTextStyles.display(size: 15, weight: FontWeight.w700),
    titleSmall: AppTextStyles.display(size: 13, weight: FontWeight.w700),
    bodyLarge: AppTextStyles.body(size: 16),
    bodyMedium: AppTextStyles.body(size: 14),
    bodySmall: AppTextStyles.body(size: 12),
    labelLarge: AppTextStyles.mono(size: 11),
    labelMedium: AppTextStyles.mono(size: 10),
    labelSmall: AppTextStyles.mono(size: 9),
  );
}

// Legacy ThemeNotifier kept for compatibility
class ThemeNotifier extends ChangeNotifier {}
