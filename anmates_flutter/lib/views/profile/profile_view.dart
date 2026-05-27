import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/anm_widgets.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mint,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top bar ──────────────────────────────────────────────
              _TopBar(),
              const SizedBox(height: 20),

              // ── Avatar + info row ────────────────────────────────────
              _AvatarInfoRow(),
              const SizedBox(height: 20),

              // ── Astrology card ───────────────────────────────────────
              _AstrologyCard(),
              const SizedBox(height: 16),

              // ── Stats grid ───────────────────────────────────────────
              _StatsGrid(),
              const SizedBox(height: 20),

              // ── Photo album ──────────────────────────────────────────
              _PhotoAlbumSection(),
              const SizedBox(height: 20),

              // ── Food preferences ─────────────────────────────────────
              _FoodPrefsSection(),
              const SizedBox(height: 20),

              // ── Subscription section ─────────────────────────────────
              _SubscriptionSection(),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top Bar
// ─────────────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Eyebrow('HỒ SƠ CỦA TÔI', color: AppColors.ink50),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink10,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Text('⚙️', style: TextStyle(fontSize: 18)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Avatar + Info Row
// ─────────────────────────────────────────────────────────────────────────────
class _AvatarInfoRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trust ring avatar
          TrustRing(score: 96, size: 88),
          const SizedBox(width: 16),

          // Name + info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Vy, 24',
                  style: AppTextStyles.display(
                    size: 22,
                    weight: FontWeight.w800,
                    color: AppColors.ink,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Designer · Quận 1 · 🇻🇳',
                  style: AppTextStyles.body(size: 13, color: AppColors.ink70),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    AnmChip(
                      label: '✓ Verified',
                      active: true,
                      color: AppColors.berry,
                      sm: true,
                    ),
                    AnmChip(
                      label: '👑 Gold member',
                      active: true,
                      color: AppColors.wisteria,
                      sm: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Astrology Card
// ─────────────────────────────────────────────────────────────────────────────
class _AstrologyCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink10,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _AstrologyCell(
                  icon: '♊',
                  label: 'CUNG',
                  name: 'Song Tử',
                  tintColor: AppColors.ocean,
                  showDivider: true,
                ),
              ),
              Expanded(
                child: _AstrologyCell(
                  icon: '金',
                  label: 'MỆNH',
                  name: 'Bạch Lạp Kim',
                  tintColor: AppColors.wisteria,
                  showDivider: true,
                ),
              ),
              Expanded(
                child: _AstrologyCell(
                  icon: '5',
                  label: 'THẦN SỐ',
                  name: 'Tự do',
                  tintColor: AppColors.berry,
                  showDivider: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AstrologyCell extends StatelessWidget {
  final String icon;
  final String label;
  final String name;
  final Color tintColor;
  final bool showDivider;

  const _AstrologyCell({
    required this.icon,
    required this.label,
    required this.name,
    required this.tintColor,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: showDivider
          ? BoxDecoration(
              border: Border(
                right: BorderSide(color: AppColors.ink10, width: 1),
              ),
            )
          : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tintColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                icon,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: tintColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTextStyles.mono(
              size: 9,
              weight: FontWeight.w700,
              color: tintColor.withValues(alpha: 0.7),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            name,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(
              size: 12,
              weight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats Grid
// ─────────────────────────────────────────────────────────────────────────────
class _StatsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              value: '12',
              label: 'Buổi ăn',
              color: AppColors.berry,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              value: '34',
              label: 'Wishlist',
              color: AppColors.ocean,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              value: '4',
              label: 'Best Mates',
              color: AppColors.wisteria,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.display(
              size: 26,
              weight: FontWeight.w800,
              color: color,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(
              size: 11,
              color: AppColors.ink50,
              weight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Photo Album Section
// ─────────────────────────────────────────────────────────────────────────────
class _PhotoAlbumSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('ALBUM ĂN UỐNG'),
          const SizedBox(height: 12),
          // Custom 2fr/1fr/1fr grid with 2 rows
          LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              final gap = 8.0;
              // 2fr / 1fr / 1fr — big col takes ~half, two small cols share the rest
              final bigWidth = (totalWidth - 2 * gap) * 0.5;
              final row1Height = 110.0;
              final row2Height = 80.0;

              return SizedBox(
                height: row1Height + gap + row2Height,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left big column: spans both rows
                    PhotoSlot(
                      width: bigWidth,
                      height: row1Height + gap + row2Height,
                      label: 'HERO',
                      radius: 16,
                    ),
                    const SizedBox(width: 8),
                    // Right two columns
                    Expanded(
                      child: Column(
                        children: [
                          // Row 1: two small slots
                          Row(
                            children: [
                              Expanded(
                                child: PhotoSlot(
                                  height: row1Height,
                                  label: 'PHOTO',
                                  radius: 12,
                                  dark: true,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: PhotoSlot(
                                  height: row1Height,
                                  label: 'PHOTO',
                                  radius: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Row 2: two small slots
                          Row(
                            children: [
                              Expanded(
                                child: PhotoSlot(
                                  height: row2Height,
                                  label: 'PHOTO',
                                  radius: 12,
                                  dark: true,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: PhotoSlot(
                                  height: row2Height,
                                  label: '+12',
                                  radius: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Food Preferences Section
// ─────────────────────────────────────────────────────────────────────────────
class _FoodPrefsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow('GU ẨM THỰC', color: AppColors.ocean),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AnmChip(
                label: '🌶️ Cay 3',
                active: true,
                color: AppColors.berry,
                sm: true,
              ),
              AnmChip(
                label: '🥩 Beef',
                active: true,
                color: AppColors.ocean,
                sm: true,
              ),
              AnmChip(
                label: '🦐 Hải sản',
                active: true,
                color: AppColors.wisteria,
                sm: true,
              ),
              AnmChip(
                label: '🚫 Không hành',
                active: true,
                color: AppColors.glaucous,
                sm: true,
              ),
              AnmChip(
                label: '☕ Cafe đen',
                active: true,
                color: AppColors.berryDeep,
                sm: true,
              ),
              AnmChip(
                label: '🍣 Sushi',
                active: true,
                color: AppColors.ocean,
                sm: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Subscription Section
// ─────────────────────────────────────────────────────────────────────────────
class _SubscriptionSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Eyebrow('GÓI ĂN MATES', color: AppColors.berry),
              GestureDetector(
                onTap: () {},
                child: Text(
                  'Quản lý →',
                  style: AppTextStyles.body(
                    size: 13,
                    weight: FontWeight.w600,
                    color: AppColors.berry,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Current plan banner (GOLD)
          _CurrentPlanBanner(),
          const SizedBox(height: 10),

          // ULTIMATE tier row
          _TierRow(
            tag: 'ULTIMATE',
            icon: '✨',
            title: 'Đẳng Cấp VVIP',
            price: '99.000đ',
            buttonLabel: 'Nâng cấp →',
            gradient: const LinearGradient(
              colors: [AppColors.berry, AppColors.berryDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            buttonStyle: _TierButtonStyle.whiteSolid,
          ),
          const SizedBox(height: 8),

          // PLUS tier row
          _TierRow(
            tag: 'PLUS',
            icon: '🎓',
            title: 'Cứu Kèo Học Đường',
            price: '29.000đ',
            buttonLabel: 'Xem thử',
            gradient: null,
            buttonStyle: _TierButtonStyle.berryOutline,
          ),
        ],
      ),
    );
  }
}

class _CurrentPlanBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.wisteria, AppColors.wisteriaDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.wisteria.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Glass icon square
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: const Center(
              child: Text('👑', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 14),

          // Text block
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ĐANG DÙNG · GOLD',
                  style: AppTextStyles.mono(
                    size: 9,
                    weight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.75),
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Vũ Trụ Ăn Kèo',
                  style: AppTextStyles.display(
                    size: 16,
                    weight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Còn 18 ngày · gia hạn 59k/tháng',
                  style: AppTextStyles.body(
                    size: 11,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),

          // Active pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Text(
              'Active',
              style: AppTextStyles.body(
                size: 11,
                weight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _TierButtonStyle { whiteSolid, berryOutline }

class _TierRow extends StatelessWidget {
  final String tag;
  final String icon;
  final String title;
  final String price;
  final String buttonLabel;
  final LinearGradient? gradient;
  final _TierButtonStyle buttonStyle;

  const _TierRow({
    required this.tag,
    required this.icon,
    required this.title,
    required this.price,
    required this.buttonLabel,
    required this.gradient,
    required this.buttonStyle,
  });

  @override
  Widget build(BuildContext context) {
    final hasBg = gradient != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: gradient,
        color: hasBg ? null : AppColors.mint,
        borderRadius: BorderRadius.circular(16),
        border: hasBg ? null : Border.all(color: AppColors.ink10, width: 1.5),
        boxShadow: hasBg
            ? [
                BoxShadow(
                  color: AppColors.berry.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: hasBg
                  ? Colors.white.withValues(alpha: 0.2)
                  : AppColors.ink10,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(icon, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),

          // Tag + name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tag,
                  style: AppTextStyles.mono(
                    size: 9,
                    weight: FontWeight.w700,
                    color: hasBg
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppColors.ink50,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: AppTextStyles.body(
                    size: 13,
                    weight: FontWeight.w700,
                    color: hasBg ? Colors.white : AppColors.ink,
                  ),
                ),
              ],
            ),
          ),

          // Price + button
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: AppTextStyles.body(
                  size: 12,
                  weight: FontWeight.w700,
                  color: hasBg ? Colors.white : AppColors.ink70,
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: buttonStyle == _TierButtonStyle.whiteSolid
                        ? Colors.white
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    border: buttonStyle == _TierButtonStyle.berryOutline
                        ? Border.all(color: AppColors.berry, width: 1.5)
                        : null,
                  ),
                  child: Text(
                    buttonLabel,
                    style: AppTextStyles.body(
                      size: 12,
                      weight: FontWeight.w700,
                      color: buttonStyle == _TierButtonStyle.whiteSolid
                          ? AppColors.berry
                          : AppColors.berry,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
