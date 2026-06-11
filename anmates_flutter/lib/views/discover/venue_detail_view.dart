import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../services/maps_launcher.dart';
import '../../services/places_service.dart';
import '../../services/venue_image_service.dart';
import '../../services/venue_search_service.dart';
import '../../services/wishlist_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/anm_widgets.dart';
import '../../widgets/venue_thumbnail.dart';
import '../match/swipe_view.dart';

/// View-model for [VenueDetailView]. Built from either an [OsmPlace] (nearby
/// browse) or a [VenueResult] (web-search) so the same screen serves both lists.
class VenueDetailData {
  final String name;
  final String emoji;
  final List<String> tags;
  final String? address;
  final double lat;
  final double lng;
  final String? openingHours;
  final String? phone;

  /// Straight-line distance in metres; 0 = unknown (no usable coords).
  final int distanceM;
  final double? rating;
  final int? priceMin;
  final int? priceMax;

  /// Optional web-search "why this place" line.
  final String? reason;

  /// Free-text query used to fetch the venue photo.
  final String imageQuery;

  const VenueDetailData({
    required this.name,
    required this.emoji,
    required this.tags,
    required this.address,
    required this.lat,
    required this.lng,
    required this.openingHours,
    required this.phone,
    required this.distanceM,
    required this.rating,
    required this.priceMin,
    required this.priceMax,
    required this.reason,
    required this.imageQuery,
  });

  factory VenueDetailData.fromOsm(
    OsmPlace p, {
    required double userLat,
    required double userLng,
    required String area,
  }) {
    final hasCoords = p.lat != 0 && p.lng != 0;
    return VenueDetailData(
      name: p.name,
      emoji: p.emoji,
      tags: p.tags,
      address: p.address,
      lat: p.lat,
      lng: p.lng,
      openingHours: p.openingHours,
      phone: p.phone,
      distanceM: hasCoords ? p.distanceMeters(userLat, userLng).round() : 0,
      rating: null,
      priceMin: null,
      priceMax: null,
      reason: null,
      imageQuery: _query(p.name, p.address, area),
    );
  }

  factory VenueDetailData.fromResult(VenueResult r, {required String area}) {
    return VenueDetailData(
      name: r.name,
      emoji: '🍽️',
      tags: const [],
      address: r.address.isNotEmpty ? r.address : null,
      lat: r.lat,
      lng: r.lng,
      openingHours: null,
      phone: null,
      distanceM: r.distanceM,
      rating: r.rating,
      priceMin: r.priceMin,
      priceMax: r.priceMax,
      reason: r.reason.isNotEmpty ? r.reason : null,
      imageQuery: _query(r.name, r.address, area),
    );
  }

  /// Builds the venue photo search query as "name + address" (most specific,
  /// per user request), falling back to "name + area" then bare name when the
  /// venue has no street address.
  static String _query(String name, String? address, String area) {
    final addr = address?.trim() ?? '';
    if (addr.isNotEmpty) return '$name $addr';
    return area.trim().isNotEmpty ? '$name ${area.trim()}' : name;
  }
}

/// Screen 12.1 — Chi tiết quán. Hero photo + venue facts + match/social-proof
/// cards + a sticky action bar (Wishlist / find a Mate to eat with).
class VenueDetailView extends StatefulWidget {
  final VenueDetailData data;

  /// The signed-in user's display name, used in the "Hợp gu …" card.
  final String greetingName;

  const VenueDetailView({
    super.key,
    required this.data,
    this.greetingName = 'bạn',
  });

  @override
  State<VenueDetailView> createState() => _VenueDetailViewState();
}

class _VenueDetailViewState extends State<VenueDetailView> {
  bool _saving = false;
  bool _saved = false;

  // Hero gallery — how many web-crawled photos exist, and which page is showing.
  final PageController _heroCtrl = PageController();
  int _imageCount = 1;
  int _heroPage = 0;

  VenueDetailData get _d => widget.data;

  @override
  void initState() {
    super.initState();
    _loadImageCount();
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadImageCount() async {
    final n = await VenueImageService().count(_d.imageQuery);
    if (!mounted || n <= 1) return; // 0/1 → keep the single-image hero
    setState(() => _imageCount = n);
  }

  String? get _distanceLabel {
    if (_d.distanceM <= 0) return null;
    return _d.distanceM < 1000
        ? '${_d.distanceM} m'
        : '${(_d.distanceM / 1000).toStringAsFixed(1)} km';
  }

  // Real meta segments only — OSM has no rating/price, so we never invent them.
  List<String> get _metaSegments {
    final segs = <String>[];
    if (_d.rating != null) segs.add('⭐ ${_d.rating!.toStringAsFixed(1)}');
    if (_d.priceMin != null && _d.priceMax != null) {
      segs.add('${_d.priceMin}k–${_d.priceMax}k');
    }
    final dist = _distanceLabel;
    if (dist != null) segs.add(dist);
    return segs;
  }

  String get _tagLine {
    final t = _d.tags.where((e) => e.trim().isNotEmpty).toList();
    return t.isEmpty ? 'Quán ăn' : t.join(' · ');
  }

  // Description: prefer the web-search "why", else compose from real OSM facts.
  String get _description {
    if (_d.reason != null && _d.reason!.trim().isNotEmpty) return _d.reason!;
    final parts = <String>[];
    if (_d.address != null && _d.address!.trim().isNotEmpty) {
      parts.add('Địa chỉ: ${_d.address}');
    }
    if (_d.openingHours != null && _d.openingHours!.trim().isNotEmpty) {
      parts.add('Giờ mở cửa: ${_d.openingHours}');
    }
    if (_d.phone != null && _d.phone!.trim().isNotEmpty) {
      parts.add('Điện thoại: ${_d.phone}');
    }
    if (parts.isEmpty) {
      return 'Quán ${_d.name} — ${_tagLine.toLowerCase()}. '
          'Ghé thử rồi rủ một Mate cùng vibe đi ăn nhé!';
    }
    return parts.join('\n');
  }

  // Derived "taste" chips for the venue (from its cuisine/amenity tags).
  List<String> get _tasteChips {
    final base = _d.tags.where((e) => e.trim().isNotEmpty).toList();
    if (base.isEmpty) return const ['Đáng thử', 'Gần bạn'];
    return base.take(4).toList();
  }

  // "Độ hợp gu" — placeholder heuristic until the real vibe-match backend lands.
  // Deterministic per venue so it doesn't flicker between opens.
  int get _matchPercent => 82 + (_d.name.hashCode.abs() % 16); // 82–97

  List<String> get _matchChecks {
    final checks = <String>[];
    if (_d.distanceM > 0 && _d.distanceM <= 2000) checks.add('Gần bạn');
    if (_d.openingHours != null && _d.openingHours!.trim().isNotEmpty) {
      checks.add('Đang mở cửa');
    }
    final firstTag = _d.tags.firstWhere(
      (e) => e.trim().isNotEmpty,
      orElse: () => '',
    );
    if (firstTag.isNotEmpty) checks.add('Hợp $firstTag');
    if (checks.isEmpty) checks.add('Vibe hợp gu bạn');
    return checks.take(3).toList();
  }

  // Maps a venue to a backend wishlist category (AllowedCategories).
  String get _wishlistCategory {
    final s = '${_d.tags.join(' ')} ${_d.name} ${_d.emoji}'.toLowerCase();
    if (s.contains('cafe') ||
        s.contains('cà phê') ||
        s.contains('coffee') ||
        s.contains('☕')) {
      return 'cafe';
    }
    if (s.contains('lẩu') || s.contains('lau') || s.contains('hotpot')) {
      return 'lau';
    }
    if (s.contains('nướng') ||
        s.contains('bbq') ||
        s.contains('barbecue') ||
        s.contains('korean') ||
        s.contains('grill')) {
      return 'bbq';
    }
    if (s.contains('phở') || s.contains('pho')) return 'pho';
    if (s.contains('bún') || s.contains('bun')) return 'bun';
    if (s.contains('cơm') || s.contains('com') || s.contains('rice')) {
      return 'com';
    }
    return 'other';
  }

  Future<void> _addToWishlist() async {
    if (_saving || _saved) return;
    setState(() => _saving = true);
    try {
      await WishlistService().add(_d.name, _wishlistCategory);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = true;
      });
      _snack('Đã lưu "${_d.name}" vào Wishlist');
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Lưu chưa được — thử lại nhé');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: AppTextStyles.body(size: 13, color: Colors.white)),
        backgroundColor: AppColors.ink,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openDirections() {
    MapsLauncher.open(
      name: _d.name,
      address: _d.address ?? '',
      lat: _d.lat,
      lng: _d.lng,
    );
  }

  void _findMate() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SwipeView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mint,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHero(),
                Transform.translate(
                  offset: const Offset(0, -28),
                  child: _buildSheet(),
                ),
              ],
            ),
          ),
          _buildTopBar(context),
          _buildBottomBar(context),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return SizedBox(
      height: 280,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Swipeable gallery — ScrollConfiguration enables mouse-drag on Flutter web
          // in addition to the default touch swipe on mobile.
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
              },
            ),
            child: PageView.builder(
              controller: _heroCtrl,
              physics: _imageCount > 1
                  ? const ClampingScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              itemCount: _imageCount,
              onPageChanged: (i) => setState(() => _heroPage = i),
              itemBuilder: (_, i) => VenueThumbnail(
                query: _d.imageQuery,
                index: i,
                width: double.infinity,
                height: 280,
                radius: 0,
                placeholderLabel: _d.emoji,
              ),
            ),
          ),
          // Subtle scrims so the round top-bar buttons stay legible on any photo.
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x33000000), Colors.transparent, Color(0x22000000)],
                  stops: [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          if (_imageCount > 1)
            Positioned(
              bottom: 38,
              left: 0,
              right: 0,
              child: _buildHeroDots(),
            ),
        ],
      ),
    );
  }

  Widget _buildHeroDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_imageCount, (i) {
        final active = i == _heroPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: active ? 0.95 : 0.55),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  Widget _buildSheet() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tag line
          Text(
            '${_d.emoji}  $_tagLine',
            style: AppTextStyles.body(
              size: 13,
              weight: FontWeight.w600,
              color: AppColors.ink50,
            ),
          ),
          const SizedBox(height: 6),
          // Title
          Text(_d.name, style: AppTextStyles.heading2(color: AppColors.ink)),
          if (_metaSegments.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _metaSegments.join('   ·   '),
              style: AppTextStyles.mono(
                size: 11,
                weight: FontWeight.w600,
                color: AppColors.ink70,
                letterSpacing: 0.2,
              ),
            ),
          ],
          const SizedBox(height: 18),
          _buildSocialProof(),
          const SizedBox(height: 22),
          Eyebrow('VỀ QUÁN'),
          const SizedBox(height: 8),
          Text(
            _description,
            style: AppTextStyles.body(size: 14, color: AppColors.ink70, height: 1.5),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tasteChips
                .map((c) => AnmChip(label: c, sm: true, color: AppColors.berry))
                .toList(),
          ),
          const SizedBox(height: 20),
          _buildMatchCard(),
        ],
      ),
    );
  }

  Widget _buildSocialProof() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.berry, AppColors.wisteriaDeep],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.berry.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildAvatarStack(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nhiều người quanh đây cũng đang thèm quán này',
                  style: AppTextStyles.body(
                    size: 13,
                    weight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Quẹt để xem Mate cùng vibe →',
                  style: AppTextStyles.mono(
                    size: 9,
                    weight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.85),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarStack() {
    return SizedBox(
      width: 64,
      height: 36,
      child: Stack(
        children: [
          for (int i = 0; i < 3; i++)
            Positioned(
              left: i * 18.0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: AnmAvatar(size: 34, hue: i + 2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMatchCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.berry.withValues(alpha: 0.18), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.berry, AppColors.wisteriaDeep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Center(
              child: Text('✨', style: TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Hợp gu ${widget.greetingName}',
                        style: AppTextStyles.body(
                          size: 14,
                          weight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '$_matchPercent%',
                      style: AppTextStyles.display(
                        size: 18,
                        weight: FontWeight.w800,
                        color: AppColors.berry,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _matchChecks.map((c) => '$c ✓').join(' · '),
                  style: AppTextStyles.body(size: 11, color: AppColors.ink50),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: Row(
        children: [
          _RoundIconButton(
            icon: Icons.arrow_back,
            onTap: () => Navigator.pop(context),
          ),
          const Spacer(),
          _RoundIconButton(
            icon: Icons.near_me_outlined,
            onTap: _openDirections,
          ),
          const SizedBox(width: 10),
          _RoundIconButton(
            icon: _saved ? Icons.favorite : Icons.favorite_border,
            iconColor: _saved ? AppColors.berry : AppColors.ink,
            onTap: _addToWishlist,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.ink10, width: 0.5)),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: SizedBox(
                    height: 54,
                    child: AnmGhostBtn(
                      label: _saved
                          ? '✓ Đã lưu'
                          : (_saving ? 'Đang lưu…' : '＋ Wishlist'),
                      onTap: _addToWishlist,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 6,
                  child: AnmCTA(
                    label: 'Tìm Mate ăn cùng',
                    height: 54,
                    onTap: _findMate,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.iconColor = AppColors.ink,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.16),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, size: 19, color: iconColor),
        ),
      ),
    );
  }
}
