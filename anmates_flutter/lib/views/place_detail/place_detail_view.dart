import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../sheets/date_scheduling_sheet.dart';
import '../sheets/review_checkin_sheet.dart';
import '../sheets/dining_group_sheet.dart';
import '../sheets/ai_food_suggestion_sheet.dart';
import '../sheets/invite_partner_sheet.dart';

class PlaceDetailView extends StatelessWidget {
  final Place place;
  const PlaceDetailView({super.key, required this.place});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Hero
              SliverToBoxAdapter(
                child: Container(
                  height: 280,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: place.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          place.emoji,
                          style: const TextStyle(fontSize: 100),
                        ),
                      ),
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 28,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: place.vibeTags.length,
                                itemBuilder: (_, i) => Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    place.vibeTags[i],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              place.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.yellow,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  place.rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  ' · ${place.reviewCount} đánh giá · ${place.priceRange}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Quick actions
                    Row(
                      children: [
                        _QuickActionBtn(
                          icon: Icons.map,
                          label: 'Chỉ đường',
                          color: const Color(0xFF00B894),
                          onTap: () {},
                        ),
                        _QuickActionBtn(
                          icon: Icons.phone,
                          label: 'Gọi',
                          color: AppColors.ocean,
                          onTap: () {},
                        ),
                        _QuickActionBtn(
                          icon: Icons.group,
                          label: 'Rủ bạn',
                          color: AppColors.berry,
                          onTap: () => _showSheet(
                            context,
                            InvitePartnerSheet(place: place),
                          ),
                        ),
                        _QuickActionBtn(
                          icon: Icons.calendar_today,
                          label: 'Đặt hẹn',
                          color: AppColors.berry,
                          onTap: () => _showSheet(
                            context,
                            DateSchedulingSheet(place: place),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Info card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E2E),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _InfoRow(
                            icon: Icons.location_on,
                            label: 'Địa chỉ',
                            value: place.address,
                          ),
                          const Divider(color: Color(0xFF2D2D42)),
                          _InfoRow(
                            icon: Icons.phone,
                            label: 'Số điện thoại',
                            value: place.phone,
                          ),
                          const Divider(color: Color(0xFF2D2D42)),
                          _InfoRow(
                            icon: Icons.access_time,
                            label: 'Giờ mở cửa',
                            value: place.openingHours,
                          ),
                          const Divider(color: Color(0xFF2D2D42)),
                          _InfoRow(
                            icon: Icons.label,
                            label: 'Loại',
                            value: place.category.label,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description
                    const Text(
                      'Giới thiệu',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      place.detailDescription,
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 16),

                    // Vibe check
                    const Text(
                      'Vibe Check',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 3.5,
                      children: const [
                        _VibeStat(emoji: '💕', label: 'Romantic', count: 42),
                        _VibeStat(
                          emoji: '📸',
                          label: 'Instagrammable',
                          count: 67,
                        ),
                        _VibeStat(emoji: '🎉', label: 'Lively', count: 28),
                        _VibeStat(emoji: '🤫', label: 'Quiet', count: 12),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // CTA buttons
                    _CTAButton(
                      title: '📝 Check-in & Viết Review',
                      subtitle: 'Kiếm +30 AnPoints',
                      gradient: const [Color(0xFFfdcb6e), Color(0xFFe17055)],
                      onTap: () =>
                          _showSheet(context, ReviewCheckinSheet(place: place)),
                    ),
                    const SizedBox(height: 10),
                    _CTAButton(
                      title: '👥 Tạo Nhóm Đi Ăn',
                      subtitle: 'Tối đa 4 người · Mời thêm bạn',
                      gradient: const [AppColors.berry, AppColors.wisteria],
                      onTap: () =>
                          _showSheet(context, DiningGroupSheet(place: place)),
                    ),
                    const SizedBox(height: 10),
                    _CTAButton(
                      title: '🤖 AI Gợi Ý Món',
                      subtitle: 'Dựa trên nhóm, mood & ngân sách',
                      gradient: const [Color(0xFF00B894), Color(0xFF00CEC9)],
                      onTap: () => _showSheet(
                        context,
                        AIFoodSuggestionSheet(place: place),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Reviews
                    Row(
                      children: [
                        Text(
                          'Đánh giá (${place.reviewCount})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'Xem tất cả',
                          style: TextStyle(
                            color: AppColors.wisteria,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...place.reviews.map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ReviewRow(review: r),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ]),
                ),
              ),
            ],
          ),

          // Top bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.more_horiz,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSheet(BuildContext context, Widget sheet) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => sheet,
    );
  }
}

class _QuickActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.wisteria, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VibeStat extends StatelessWidget {
  final String emoji;
  final String label;
  final int count;
  const _VibeStat({
    required this.emoji,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$count lượt',
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CTAButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;
  const _CTAButton({
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final PlaceReview review;
  const _ReviewRow({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(review.authorEmoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.authorName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      review.timeAgo,
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < review.rating ? Icons.star : Icons.star_border,
                    color: Colors.yellow,
                    size: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review.content,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: review.vibeTags
                .map(
                  (t) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D2D42),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      t,
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
