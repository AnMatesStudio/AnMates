import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../services/location_service.dart';
import '../../services/places_service.dart';
import '../../services/profile_service.dart';
import '../../services/venue_search_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/anm_logo.dart';
import '../../widgets/anm_widgets.dart';
import '../../widgets/venue_thumbnail.dart';
import '../profile/profile_view.dart';
import 'venue_detail_view.dart';

// Fallback coords: Quận 1 center — always yields real OSM data on web when
// location permission is denied.
const double _kFallbackLat = 10.7769;
const double _kFallbackLng = 106.7009;

class DiscoverView extends StatefulWidget {
  const DiscoverView({super.key});

  @override
  State<DiscoverView> createState() => _DiscoverViewState();
}

class _DiscoverViewState extends State<DiscoverView> {
  // --- profile ---
  String _greetingName = 'bạn';
  String? _avatarUrl;

  // --- location ---
  double _userLat = _kFallbackLat;
  double _userLng = _kFallbackLng;
  bool _usingFallbackLocation = true;
  String _locationLabel = 'TP.HCM';

  // --- venues ---
  List<OsmPlace> _places = [];
  bool _loadingPlaces = true;
  String? _placesError;

  // --- filters ---
  String? _activeGenre; // null = no filter
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;

  // --- remote web-search results (Discovery path, submit-only) ---
  List<VenueResult>? _searchResults; // null = not yet searched / cleared
  bool _searchLoading = false;
  String? _searchError;

  // --- vibe chips (visual-only; OSM has no reliable mapping) ---
  final Set<String> _activeVibes = {'❄️ Máy lạnh'};

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadNearby();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      final q = _searchCtrl.text.trim();
      setState(() {
        _searchQuery = q.toLowerCase();
        // Clearing the box → return to OSM nearby browse.
        if (q.isEmpty) {
          _searchResults = null;
          _searchError = null;
        }
      });
    });
  }

  Future<void> _submitSearch(String raw) async {
    final q = raw.trim();
    if (q.runes.length < 2) return;
    setState(() {
      _searchLoading = true;
      _searchError = null;
      _searchResults = null;
    });
    try {
      final results = await VenueSearchService().search(
        q,
        lat: _usingFallbackLocation ? null : _userLat,
        lng: _usingFallbackLocation ? null : _userLng,
      );
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _searchLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searchLoading = false;
        _searchError = q;
      });
    }
  }

  Future<void> _loadProfile() async {
    try {
      final u = await ProfileService().getProfile();
      if (!mounted) return;
      setState(() {
        final nick = (u['nickname'] as String?)?.trim();
        final name = (u['name'] as String?)?.trim();
        _greetingName = (nick != null && nick.isNotEmpty)
            ? nick
            : (name != null && name.isNotEmpty ? name : 'bạn');
        final avatar = (u['avatar_url'] as String?)?.trim();
        _avatarUrl = (avatar != null && avatar.isNotEmpty) ? avatar : null;
      });
    } catch (_) {
      // Offline / not-yet-onboarded — keep placeholder greeting.
    }
  }

  Future<void> _loadNearby() async {
    if (!mounted) return;
    setState(() {
      _loadingPlaces = true;
      _placesError = null;
    });

    try {
      final coords = await LocationService().currentLatLng();
      if (!mounted) return;

      final lat = coords?.lat ?? _kFallbackLat;
      final lng = coords?.lng ?? _kFallbackLng;
      final usingFallback = coords == null;

      final places = await PlacesService().getNearby(lat, lng);
      if (!mounted) return;

      places.sort(
        (a, b) =>
            a.distanceMeters(lat, lng).compareTo(b.distanceMeters(lat, lng)),
      );

      setState(() {
        _userLat = lat;
        _userLng = lng;
        _usingFallbackLocation = usingFallback;
        _places = places;
        _loadingPlaces = false;
      });

      // Async label — don't block the list on it.
      _reverseGeocode(lat, lng);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingPlaces = false;
        _placesError = e.toString();
      });
    }
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final url =
          'https://nominatim.openstreetmap.org/reverse'
          '?format=json&lat=$lat&lon=$lng&accept-language=vi';
      final res = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'AnMatesApp/1.0'},
      );
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final addr = data['address'] as Map<String, dynamic>?;
      if (addr == null) return;

      // R-006: Nominatim district for HCM can be wrong — use suburb/city_district
      // as a display hint only; fall back to "Gần bạn" on any doubt.
      final suburb =
          (addr['suburb'] as String?) ??
          (addr['city_district'] as String?) ??
          (addr['city'] as String?);

      if (!mounted) return;
      setState(() {
        _locationLabel = (suburb != null && suburb.isNotEmpty)
            ? suburb
            : (_usingFallbackLocation ? 'TP.HCM' : 'Gần bạn');
      });
    } catch (_) {
      // Silent — label stays at its last value.
    }
  }

  List<OsmPlace> get _filteredPlaces {
    var list = _places;

    // Genre filter
    if (_activeGenre != null) {
      list = list.where((p) => _matchesGenre(p, _activeGenre!)).toList();
    }

    // Search filter (client-side, no refetch)
    if (_searchQuery.isNotEmpty) {
      list = list.where((p) {
        final name = p.name.toLowerCase();
        final cuisine = (p.cuisine ?? '').toLowerCase();
        final tags = p.tags.join(' ').toLowerCase();
        return name.contains(_searchQuery) ||
            cuisine.contains(_searchQuery) ||
            tags.contains(_searchQuery);
      }).toList();
    }

    return list;
  }

  bool _matchesGenre(OsmPlace p, String genre) {
    final c = (p.cuisine ?? '').toLowerCase();
    final a = p.amenity.toLowerCase();
    final n = p.name.toLowerCase();
    switch (genre) {
      case 'Lẩu sùng sục':
        return c.contains('hotpot') ||
            c.contains('lau') ||
            n.contains('lẩu') ||
            (c.contains('vietnamese') && n.contains('lẩu'));
      case 'Nướng xì xèo':
        return c.contains('barbecue') ||
            c.contains('bbq') ||
            c.contains('korean') ||
            c.contains('grill') ||
            n.contains('nướng');
      case 'Cafe chill':
        return a == 'cafe' || c.contains('coffee') || c.contains('tea');
      case 'Ăn vặt phố':
        return a == 'fast_food' ||
            c.contains('street_food') ||
            n.contains('ăn vặt');
      default:
        return true;
    }
  }

  // Area hint appended to venue image queries. The reverse-geocode placeholder
  // "Gần bạn" isn't a place name, so fall back to the city for better matches.
  String get _imageArea =>
      _locationLabel == 'Gần bạn' ? 'TP.HCM' : _locationLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mint,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(),
            const SizedBox(height: 12),
            _buildSearchBar(),
            const SizedBox(height: 24),
            _buildGenreSection(),
            const SizedBox(height: 24),
            _buildVibeSection(),
            const SizedBox(height: 24),
            _buildHotNearbySection(),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const LogoMark(size: 32, float: true),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '📍 ',
                      style: AppTextStyles.mono(
                        size: 10,
                        weight: FontWeight.w600,
                        color: AppColors.ink50,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      _locationLabel.toUpperCase(),
                      style: AppTextStyles.mono(
                        size: 10,
                        weight: FontWeight.w600,
                        color: AppColors.ink50,
                        letterSpacing: 1.2,
                      ),
                    ),
                    if (_usingFallbackLocation)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          '(vị trí mặc định)',
                          style: AppTextStyles.mono(
                            size: 9,
                            color: AppColors.ink50,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Hôm nay ăn gì, $_greetingName?',
                  style: AppTextStyles.body(
                    size: 15,
                    weight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileView()),
              ),
              child: _avatarUrl != null
                  ? Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.ocean, width: 2),
                        image: DecorationImage(
                          image: NetworkImage(_avatarUrl!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  : TrustRing(score: 96, size: 42),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 48,
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
        child: Row(
          children: [
            const SizedBox(width: 16),
            const Text('🔍', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                style: AppTextStyles.body(size: 14, color: AppColors.ink),
                textInputAction: TextInputAction.search,
                onSubmitted: _submitSearch,
                decoration: InputDecoration(
                  hintText: 'Tìm quán, món, vibe…',
                  hintStyle: AppTextStyles.body(
                    size: 14,
                    color: AppColors.ink50,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const Text('🎙️', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildGenreSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Eyebrow('BẠN THÈM GENRE GÌ?'),
              const Spacer(),
              Text(
                'Xem tất cả',
                style: AppTextStyles.body(
                  size: 12,
                  weight: FontWeight.w600,
                  color: AppColors.berry,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _HorizontalDraggableGenreList(
          activeGenre: _activeGenre,
          onGenreTap: (label) {
            setState(() {
              _activeGenre = (_activeGenre == label) ? null : label;
            });
          },
          items: [
            (
              'Lẩu sùng sục',
              '🍲',
              const LinearGradient(
                colors: [AppColors.berry, AppColors.berryDeep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            (
              'Nướng xì xèo',
              '🥩',
              const LinearGradient(
                colors: [AppColors.wisteria, AppColors.wisteriaDeep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            (
              'Cafe chill',
              '☕',
              const LinearGradient(
                colors: [AppColors.ocean, AppColors.oceanDeep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            (
              'Ăn vặt phố',
              '🍢',
              LinearGradient(
                colors: [
                  AppColors.glaucous,
                  AppColors.glaucous.withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVibeSection() {
    final vibes = [
      '❄️ Máy lạnh',
      '🌿 Vỉa hè',
      '🔇 Khuất hẻm',
      '✨ Sang chảnh',
      '🌙 Ngồi khuya',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Eyebrow('… HAY MUỐN VIBE NÀO?'),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          // Vibe chips are visual-only toggles. OSM has no reliable tag mapping
          // for ambiance (máy lạnh, vỉa hè, etc.) — wire to data in a future sprint.
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: vibes.map((v) {
              final active = _activeVibes.contains(v);
              return AnmChip(
                label: v,
                active: active,
                color: AppColors.ocean,
                onTap: () {
                  setState(() {
                    if (active) {
                      _activeVibes.remove(v);
                    } else {
                      _activeVibes.add(v);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildHotNearbySection() {
    final now = TimeOfDay.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final sectionLabel =
        (_searchResults != null || _searchLoading || _searchError != null)
            ? 'TÌM KIẾM WEB'
            : 'HOT QUANH BẠN · $timeStr';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Eyebrow(sectionLabel),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildNearbyContent(),
        ),
      ],
    );
  }

  Widget _buildNearbyContent() {
    // Remote search path: show results when a submit has been triggered.
    if (_searchLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_searchError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Text(
                'Lỗi tìm kiếm — thử lại',
                style: AppTextStyles.body(size: 14, color: AppColors.ink50),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _submitSearch(_searchError!),
                child: Text(
                  'Thử lại',
                  style: AppTextStyles.body(
                    size: 14,
                    weight: FontWeight.w600,
                    color: AppColors.berry,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_searchResults != null) {
      return _buildSearchResults(_searchResults!);
    }

    // OSM browse path (typing / no submit yet).
    if (_loadingPlaces) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_placesError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              Text(
                'Không tải được quán — thử lại',
                style: AppTextStyles.body(
                  size: 14,
                  color: AppColors.ink50,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _loadNearby,
                child: Text(
                  'Thử lại',
                  style: AppTextStyles.body(
                    size: 14,
                    weight: FontWeight.w600,
                    color: AppColors.berry,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final visible = _filteredPlaces.take(6).toList();

    if (visible.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'Chưa tìm thấy quán quanh đây',
            style: AppTextStyles.body(size: 14, color: AppColors.ink50),
          ),
        ),
      );
    }

    return Column(
      children: visible.indexed.map((entry) {
        final (i, place) = entry;
        return Padding(
          padding: EdgeInsets.only(bottom: i < visible.length - 1 ? 10 : 0),
          child: _RestaurantRow(
            place: place,
            userLat: _userLat,
            userLng: _userLng,
            area: _imageArea,
            greetingName: _greetingName,
            isNearest: i == 0 && _activeGenre == null && _searchQuery.isEmpty,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSearchResults(List<VenueResult> results) {
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'Không tìm thấy "${_searchCtrl.text.trim()}"',
            style: AppTextStyles.body(size: 14, color: AppColors.ink50),
          ),
        ),
      );
    }

    final sorted = List<VenueResult>.from(results)
      ..sort((a, b) => a.distanceM.compareTo(b.distanceM));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'KẾT QUẢ TÌM KIẾM',
            style: AppTextStyles.mono(
              size: 10,
              weight: FontWeight.w700,
              color: AppColors.ink50,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...sorted.indexed.map((entry) {
          final (i, result) = entry;
          return Padding(
            padding: EdgeInsets.only(bottom: i < sorted.length - 1 ? 10 : 0),
            child: _VenueResultRow(
              result: result,
              area: _imageArea,
              greetingName: _greetingName,
              showDistance: result.lat != 0 && result.lng != 0,
            ),
          );
        }),
      ],
    );
  }
}

class _HorizontalDraggableGenreList extends StatefulWidget {
  final List<(String label, String emoji, LinearGradient gradient)> items;
  final String? activeGenre;
  final void Function(String label) onGenreTap;

  const _HorizontalDraggableGenreList({
    required this.items,
    required this.activeGenre,
    required this.onGenreTap,
  });

  @override
  State<_HorizontalDraggableGenreList> createState() =>
      _HorizontalDraggableGenreListState();
}

class _HorizontalDraggableGenreListState
    extends State<_HorizontalDraggableGenreList> {
  late final ScrollController _scrollCtrl;
  bool _isDragging = false;
  double _dragStart = 0;
  double _scrollStart = 0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onMouseDown(PointerDownEvent event) {
    setState(() => _isDragging = true);
    _dragStart = event.position.dx;
    _scrollStart = _scrollCtrl.offset;
  }

  void _onMouseMove(PointerMoveEvent event) {
    if (!_isDragging) return;
    final delta = event.position.dx - _dragStart;
    _scrollCtrl.jumpTo(_scrollStart - delta);
  }

  void _onMouseUp(PointerUpEvent event) {
    setState(() => _isDragging = false);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onMouseDown,
      onPointerMove: _onMouseMove,
      onPointerUp: _onMouseUp,
      child: MouseRegion(
        cursor: _isDragging
            ? SystemMouseCursors.grabbing
            : SystemMouseCursors.grab,
        child: SizedBox(
          height: 90,
          child: SingleChildScrollView(
            controller: _scrollCtrl,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  ...widget.items.indexed.map((indexed) {
                    final (i, (label, emoji, gradient)) = indexed;
                    return Row(
                      children: [
                        if (i > 0) const SizedBox(width: 10),
                        _GenreCard(
                          label: label,
                          emoji: emoji,
                          gradient: gradient,
                          isActive: widget.activeGenre == label,
                          onTap: () => widget.onGenreTap(label),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GenreCard extends StatefulWidget {
  final String label;
  final String emoji;
  final LinearGradient gradient;
  final bool isActive;
  final VoidCallback onTap;

  const _GenreCard({
    required this.label,
    required this.emoji,
    required this.gradient,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_GenreCard> createState() => _GenreCardState();
}

class _GenreCardState extends State<_GenreCard>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late final AnimationController _emojiCtrl;
  late final Animation<double> _emojiFloat;

  @override
  void initState() {
    super.initState();
    final durationMs = 1800 + (widget.emoji.hashCode.abs() % 500);
    _emojiCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    );
    _emojiFloat = Tween<double>(
      begin: 0.0,
      end: -7.0,
    ).animate(CurvedAnimation(parent: _emojiCtrl, curve: Curves.easeInOut));
    final delayMs = (widget.label.length * 160) % 700;
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) _emojiCtrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _emojiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovered ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 140,
            height: 90,
            decoration: BoxDecoration(
              gradient: widget.gradient,
              borderRadius: BorderRadius.circular(18),
              border: widget.isActive
                  ? Border.all(color: Colors.white, width: 2.5)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: widget.gradient.colors.first.withValues(
                    alpha: (_hovered || widget.isActive) ? 0.48 : 0.30,
                  ),
                  blurRadius: (_hovered || widget.isActive) ? 20 : 10,
                  offset: Offset(0, (_hovered || widget.isActive) ? 8 : 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: 10,
                  top: 10,
                  child: AnimatedBuilder(
                    animation: _emojiFloat,
                    builder: (_, child) => Transform.translate(
                      offset:
                          Offset(0, _hovered ? -7 : _emojiFloat.value),
                      child: child,
                    ),
                    child: Text(
                      widget.emoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: Text(
                    widget.label,
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
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

class _RestaurantRow extends StatefulWidget {
  final OsmPlace place;
  final double userLat;
  final double userLng;
  final String area;
  final String greetingName;
  final bool isNearest;

  const _RestaurantRow({
    required this.place,
    required this.userLat,
    required this.userLng,
    required this.area,
    required this.greetingName,
    required this.isNearest,
  });

  @override
  State<_RestaurantRow> createState() => _RestaurantRowState();
}

class _RestaurantRowState extends State<_RestaurantRow> {
  bool _hovered = false;

  String get _tagLine {
    final tags = widget.place.tags.take(2).join(' · ');
    final dist = widget.place.distanceLabel(widget.userLat, widget.userLng);
    return '${widget.place.emoji} $tags · $dist';
  }

  String? get _hoursLabel {
    final h = widget.place.openingHours;
    if (h == null || h.isEmpty) return null;
    return '🕒 $h';
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VenueDetailView(
              data: VenueDetailData.fromOsm(
                widget.place,
                userLat: widget.userLat,
                userLng: widget.userLng,
                area: widget.area,
              ),
              greetingName: widget.greetingName,
            ),
          ),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(12),
          transform: Matrix4.translationValues(0, _hovered ? -3 : 0, 0),
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFFF8FFFB) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(
                  alpha: _hovered ? 0.09 : 0.05,
                ),
                blurRadius: _hovered ? 20 : 12,
                offset: Offset(0, _hovered ? 8 : 4),
              ),
            ],
          ),
          child: Row(
            children: [
              VenueThumbnail(
                query: '${widget.place.name} ${widget.area}'.trim(),
                width: 68,
                height: 68,
                radius: 14,
                placeholderLabel: widget.place.emoji,
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
                            widget.place.name,
                            style: AppTextStyles.body(
                              size: 14,
                              weight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.isNearest)
                          const Text(
                            '🔥',
                            style: TextStyle(fontSize: 14),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _tagLine,
                      style: AppTextStyles.body(
                        size: 12,
                        color: AppColors.ink50,
                      ),
                    ),
                    if (_hoursLabel != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.ocean.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _hoursLabel!,
                          style: AppTextStyles.mono(
                            size: 9,
                            weight: FontWeight.w600,
                            color: AppColors.ocean,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.ink10, width: 1),
                ),
                child: const Center(
                  child: Text(
                    '→',
                    style: TextStyle(fontSize: 16, color: AppColors.ink),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Row for a VenueResult from the Discovery web-search path.
class _VenueResultRow extends StatefulWidget {
  final VenueResult result;
  final String area;
  final String greetingName;
  final bool showDistance;

  const _VenueResultRow({
    required this.result,
    required this.area,
    required this.greetingName,
    required this.showDistance,
  });

  @override
  State<_VenueResultRow> createState() => _VenueResultRowState();
}

class _VenueResultRowState extends State<_VenueResultRow> {
  bool _hovered = false;

  String get _subLine {
    if (widget.showDistance && widget.result.distanceM > 0) {
      final km = widget.result.distanceM / 1000.0;
      final distStr = km >= 1.0 ? '${km.toStringAsFixed(1)} km' : '${widget.result.distanceM} m';
      return '$distStr · ${widget.result.address}';
    }
    return widget.result.address.isNotEmpty
        ? widget.result.address
        : widget.result.reason;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VenueDetailView(
              data: VenueDetailData.fromResult(
                widget.result,
                area: widget.area,
              ),
              greetingName: widget.greetingName,
            ),
          ),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(12),
          transform: Matrix4.translationValues(0, _hovered ? -3 : 0, 0),
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFFF8FFFB) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: _hovered ? 0.09 : 0.05),
                blurRadius: _hovered ? 20 : 12,
                offset: Offset(0, _hovered ? 8 : 4),
              ),
            ],
          ),
          child: Row(
            children: [
              VenueThumbnail(
                query: '${widget.result.name} ${widget.area}'.trim(),
                width: 68,
                height: 68,
                radius: 14,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.result.name,
                      style: AppTextStyles.body(
                        size: 14,
                        weight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _subLine,
                      style: AppTextStyles.body(size: 12, color: AppColors.ink50),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.result.reason.isNotEmpty &&
                        widget.result.reason != _subLine) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.berry.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          widget.result.reason,
                          style: AppTextStyles.mono(
                            size: 9,
                            weight: FontWeight.w600,
                            color: AppColors.berry,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.ink10, width: 1),
                ),
                child: const Center(
                  child: Text(
                    '→',
                    style: TextStyle(fontSize: 16, color: AppColors.ink),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
