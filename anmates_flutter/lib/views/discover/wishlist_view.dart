import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/anm_widgets.dart';

class WishlistView extends StatefulWidget {
  const WishlistView({super.key});

  @override
  State<WishlistView> createState() => _WishlistViewState();
}

class _WishlistViewState extends State<WishlistView> {
  String _activeDistrict = 'Tất cả · 34';

  static const _districtFilters = [
    '📍 Tất cả · 34',
    'Quận 1 · 12',
    'Quận 3 · 8',
    'Quận 5 · 6',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mint,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildMemoryFilmStrip()),
          SliverToBoxAdapter(child: _buildDistrictFilters()),
          SliverToBoxAdapter(
            child: _buildDistrictSection(
              district: 'QUẬN 1',
              count: 12,
              accentColor: AppColors.berry,
              cards: _q1Cards,
            ),
          ),
          SliverToBoxAdapter(
            child: _buildDistrictSection(
              district: 'QUẬN 3',
              count: 8,
              accentColor: AppColors.ocean,
              cards: _q3Cards,
            ),
          ),
          SliverToBoxAdapter(
            child: _buildDistrictSection(
              district: 'QUẬN 5',
              count: 6,
              accentColor: AppColors.wisteria,
              cards: _q5Cards,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('WISHLIST CỦA VY'),
                const SizedBox(height: 6),
                Text(
                  '34 quán',
                  style: AppTextStyles.display(
                    size: 30,
                    weight: FontWeight.w800,
                    color: AppColors.ink,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.ink10),
            ),
            child: const Icon(Icons.sort, size: 18, color: AppColors.ink70),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.berry,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, size: 20, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryFilmStrip() {
    final memories = [
      _MemoryData(
        restaurant: 'Ramen Q1',
        mate: 'Khánh',
        date: '24.05',
        stars: 5,
      ),
      _MemoryData(
        restaurant: 'Cafe Phố Cũ',
        mate: 'Linh',
        date: '18.05',
        stars: 4,
      ),
      _MemoryData(
        restaurant: 'Lẩu Hai Bà',
        mate: 'Trang',
        date: '11.05',
        stars: 5,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Text('🎞️', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Eyebrow('CÁC KÈO ĐÃ ĐI QUA'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: memories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) => _MemoryCard(data: memories[i]),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildDistrictFilters() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: _districtFilters.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final label = _districtFilters[i];
            final key = label.replaceAll('📍 ', '');
            final active = _activeDistrict == key;
            return GestureDetector(
              onTap: () => setState(() => _activeDistrict = key),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: active ? AppColors.ink : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: active ? Colors.transparent : AppColors.ink10,
                  ),
                ),
                child: Text(
                  label,
                  style: AppTextStyles.body(
                    size: 13,
                    weight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? Colors.white : AppColors.ink,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDistrictSection({
    required String district,
    required int count,
    required Color accentColor,
    required List<_WishlistCardData> cards,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                district,
                style: AppTextStyles.body(
                  size: 14,
                  weight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count quán',
                  style: AppTextStyles.mono(
                    size: 9,
                    weight: FontWeight.w700,
                    color: accentColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: AppColors.ink10, height: 1),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.75,
            children: cards
                .map((c) => _WishlistCard(data: c, accentColor: accentColor))
                .toList(),
          ),
        ],
      ),
    );
  }

  static const _q1Cards = [
    _WishlistCardData(
      name: 'Tiệm mì Ramen Q1',
      genre: '🍜 Mì',
      vibe: '🔇 Khuất hẻm',
      price: '80–250k',
      priceLevel: r'$$',
      hot: true,
    ),
    _WishlistCardData(
      name: 'Bò tơ nướng đá',
      genre: '🥩 Nướng',
      vibe: null,
      price: '80–250k',
      priceLevel: r'$$$',
      hot: false,
    ),
    _WishlistCardData(
      name: 'Cafe Phố Cũ',
      genre: '☕ Cafe',
      vibe: null,
      price: '40–90k',
      priceLevel: r'$',
      hot: false,
    ),
  ];

  static const _q3Cards = [
    _WishlistCardData(
      name: 'Bún chả Đắc Kim',
      genre: '🥢 Bún',
      vibe: null,
      price: '40–80k',
      priceLevel: r'$',
      hot: false,
    ),
    _WishlistCardData(
      name: 'Lẩu Thái Hai Bà',
      genre: '🍲 Lẩu',
      vibe: null,
      price: '150–400k',
      priceLevel: r'$$$',
      hot: true,
    ),
  ];

  static const _q5Cards = [
    _WishlistCardData(
      name: 'Dim Sum Tân Hải Vân',
      genre: '🥟 Dim sum',
      vibe: null,
      price: '100–300k',
      priceLevel: r'$$$$',
      hot: false,
    ),
    _WishlistCardData(
      name: 'Chè Hà Ký',
      genre: '🍰 Tráng miệng',
      vibe: null,
      price: '20–60k',
      priceLevel: r'$',
      hot: false,
    ),
  ];
}

class _MemoryData {
  final String restaurant;
  final String mate;
  final String date;
  final int stars;
  const _MemoryData({
    required this.restaurant,
    required this.mate,
    required this.date,
    required this.stars,
  });
}

class _MemoryCard extends StatelessWidget {
  final _MemoryData data;
  const _MemoryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 116,
      height: 130,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              PhotoSlot(width: 116, height: 72, radius: 14, label: '📸'),
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    data.date,
                    style: AppTextStyles.mono(
                      size: 9,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -10,
                right: 8,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.berry, AppColors.wisteria],
                    ),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
            child: Text(
              data.restaurant,
              style: AppTextStyles.body(
                size: 11,
                weight: FontWeight.w700,
                color: AppColors.ink,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Text(
                  'w/ ${data.mate}  ',
                  style: AppTextStyles.body(size: 10, color: AppColors.ink50),
                ),
                Text(
                  List.generate(data.stars, (_) => '★').join(),
                  style: AppTextStyles.body(size: 10, color: AppColors.berry),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WishlistCardData {
  final String name;
  final String genre;
  final String? vibe;
  final String price;
  final String priceLevel;
  final bool hot;
  const _WishlistCardData({
    required this.name,
    required this.genre,
    this.vibe,
    required this.price,
    required this.priceLevel,
    required this.hot,
  });
}

class _WishlistCard extends StatelessWidget {
  final _WishlistCardData data;
  final Color accentColor;

  const _WishlistCard({required this.data, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              PhotoSlot(
                width: double.infinity,
                height: 110,
                radius: 18,
                label: '📸',
              ),
              if (data.hot)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.berry,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'HOT 🔥',
                      style: AppTextStyles.mono(
                        size: 8,
                        weight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_border,
                    size: 14,
                    color: AppColors.berry,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.name,
                  style: AppTextStyles.body(
                    size: 12,
                    weight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    _MiniTag(label: data.genre, color: accentColor),
                    if (data.vibe != null)
                      _MiniTag(label: data.vibe!, color: AppColors.glaucous),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      data.price,
                      style: AppTextStyles.body(
                        size: 11,
                        color: AppColors.ink50,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        data.priceLevel,
                        style: AppTextStyles.mono(
                          size: 9,
                          weight: FontWeight.w700,
                          color: accentColor,
                          letterSpacing: 0.5,
                        ),
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
  }
}

class _MiniTag extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.beVietnamPro(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
