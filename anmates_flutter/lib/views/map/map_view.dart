import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

import '../../services/location_service.dart';
import '../../services/places_search_service.dart';
import '../../services/places_service.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/anm_logo.dart';
import '../../widgets/open_now_badge.dart';
import '../../widgets/venue_thumbnail.dart';
import '../discover/discover_view.dart' show venueImageQuery;
import '../discover/venue_detail_view.dart';

// Fallback coords: Quận 1 center — always yields venues when location is denied.
const double _kFallbackLat = 10.7769;
const double _kFallbackLng = 106.7009;
const int _kNearbyRadiusM = 5000;

/// Goong Maptiles key — baked in at build time via
/// `--dart-define=GOONG_MAPTILES_KEY=...` (CI/CD + start.sh). It is a DIFFERENT
/// key from the server-side `GOONG_API_KEY` (REST). Empty when not configured →
/// we show a setup notice instead of a broken/grey map (user chose "Goong tiles
/// only", so there is intentionally no OSM fallback basemap).
const String kGoongMaptilesKey = String.fromEnvironment('GOONG_MAPTILES_KEY');

/// The Goong MapLibre vector style. `{key}` is substituted by StyleReader; Goong
/// then bakes the same key into the source/tile URLs it returns.
const String _goongStyleUri =
    'https://tiles.goong.io/assets/goong_map_web.json?api_key={key}';

/// Full-screen interactive Goong map with personalized restaurant markers.
///
/// Reuses the exact same data pipeline as the Discovery list
/// ([PlacesService.getNearby] → backend Goong provider, personalized by the
/// user's onboarding tags), so the pins ARE the recommendations. Tapping a pin
/// opens a mini-card → the existing [VenueDetailView].
class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final MapController _mapController = MapController();

  // Goong vector style (fetched once). Null while the key is missing.
  Future<Style>? _styleFuture;

  // Location
  double _userLat = _kFallbackLat;
  double _userLng = _kFallbackLng;
  bool _usingFallbackLocation = true;

  // Venues
  List<OsmPlace> _venues = [];
  bool _loadingVenues = true;
  String? _venuesError;

  // Profile (for the detail-screen greeting)
  String _greetingName = 'bạn';

  // Currently tapped venue → shows the bottom card.
  OsmPlace? _selected;

  // --- search bar (find a quán or address) ---
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _searchDebounce;
  List<PlacePrediction> _predictions = [];
  bool _searching = false;
  // The place picked from search → rendered as a distinct pin on the map.
  OsmPlace? _searchedPlace;

  bool get _hasKey => kGoongMaptilesKey.trim().isNotEmpty;

  // Image-query area hint; Goong venues carry an address so this is only a
  // fallback. Kept simple on purpose.
  String get _area => _usingFallbackLocation ? 'TP.HCM' : 'Gần bạn';

  bool get _hasVenuesError => _venuesError != null && _venues.isEmpty;

  String get _subtitle {
    if (_loadingVenues) return 'Đang tìm quán quanh bạn…';
    if (_hasVenuesError) return 'Không tải được quán — chạm để thử lại';
    return 'Bản đồ ${_venues.length} quán gợi ý';
  }

  @override
  void initState() {
    super.initState();
    if (_hasKey) {
      _styleFuture = StyleReader(uri: _goongStyleUri, apiKey: kGoongMaptilesKey)
          .read();
    }
    _loadProfile();
    _initLocationAndVenues();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // --- search ----------------------------------------------------------------

  void _onSearchChanged(String raw) {
    _searchDebounce?.cancel();
    final q = raw.trim();
    if (q.runes.length < 2) {
      setState(() {
        _predictions = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 300), () => _runSearch(q));
  }

  Future<void> _runSearch(String q) async {
    final results = await PlacesSearchService()
        .autocomplete(q, lat: _userLat, lng: _userLng);
    if (!mounted) return;
    setState(() {
      _predictions = results;
      _searching = false;
    });
  }

  Future<void> _onPredictionTap(PlacePrediction pred) async {
    _searchFocus.unfocus();
    setState(() {
      _searchCtrl.text = pred.title;
      _predictions = [];
      _searching = true;
    });
    final place = await PlacesSearchService().detail(pred.placeId);
    if (!mounted) return;
    setState(() => _searching = false);
    if (place == null || !place.hasCoords) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm được toạ độ địa điểm này')),
      );
      return;
    }
    // Reuse the venue model so the searched place flows through the existing
    // selection → card → detail path.
    final osm = OsmPlace(
      id: 'goong_${place.placeId}',
      name: place.name.isNotEmpty ? place.name : pred.title,
      lat: place.lat,
      lng: place.lng,
      amenity: 'restaurant',
      address: place.address.isNotEmpty ? place.address : pred.subtitle,
    );
    setState(() {
      _searchedPlace = osm;
      _selected = osm;
    });
    try {
      _mapController.move(LatLng(place.lat, place.lng), 16);
    } catch (_) {}
  }

  void _clearSearch() {
    _searchFocus.unfocus();
    setState(() {
      _searchCtrl.clear();
      _predictions = [];
      _searching = false;
      if (identical(_selected, _searchedPlace)) _selected = null;
      _searchedPlace = null;
    });
  }

  Future<void> _loadProfile() async {
    try {
      final u = await ProfileService().getProfile();
      if (!mounted) return;
      final nick = (u['nickname'] as String?)?.trim();
      final name = (u['name'] as String?)?.trim();
      setState(() {
        _greetingName = (nick != null && nick.isNotEmpty)
            ? nick
            : (name != null && name.isNotEmpty ? name : 'bạn');
      });
    } catch (_) {
      // Not onboarded / offline — keep the placeholder greeting.
    }
  }

  /// Loads venues fast at the best-known position, then (on web, where the
  /// geolocation prompt often resolves late) polls briefly and reloads at the
  /// real position the moment permission is granted.
  Future<void> _initLocationAndVenues() async {
    await _loadVenues();
    for (var i = 0; i < 12; i++) {
      if (!mounted || !_usingFallbackLocation) return;
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      final coords = await LocationService().currentLatLng();
      if (coords != null && mounted) {
        await _loadVenues(coordsOverride: coords);
        return;
      }
    }
  }

  Future<void> _loadVenues({({double lat, double lng})? coordsOverride}) async {
    if (!mounted) return;
    setState(() {
      _loadingVenues = true;
      _venuesError = null;
    });
    try {
      final coords = coordsOverride ?? await LocationService().currentLatLng();
      final lat = coords?.lat ?? _kFallbackLat;
      final lng = coords?.lng ?? _kFallbackLng;
      final usingFallback = coords == null;

      final places =
          await PlacesService().getNearby(lat, lng, radiusM: _kNearbyRadiusM);
      if (!mounted) return;

      places.sort((a, b) =>
          a.distanceMeters(lat, lng).compareTo(b.distanceMeters(lat, lng)));

      setState(() {
        _userLat = lat;
        _userLng = lng;
        _usingFallbackLocation = usingFallback;
        _venues = places.where((p) => p.lat != 0 || p.lng != 0).toList();
        _loadingVenues = false;
      });
      _recenter(animate: false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingVenues = false;
        _venuesError = e.toString();
      });
    }
  }

  void _recenter({bool animate = true}) {
    // Guard: MapController throws if the map isn't mounted yet.
    try {
      _mapController.move(LatLng(_userLat, _userLng), 15);
    } catch (_) {
      // Map not ready on first load — initialCenter already covers it.
    }
  }

  void _selectVenue(OsmPlace p) {
    setState(() => _selected = p);
    try {
      _mapController.move(LatLng(p.lat, p.lng), _mapController.camera.zoom);
    } catch (_) {}
  }

  void _openDetail(OsmPlace p) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VenueDetailView(
          data: VenueDetailData.fromOsm(
            p,
            userLat: _userLat,
            userLng: _userLng,
            area: _area,
          ),
          greetingName: _greetingName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mint,
      body: Stack(
        children: [
          Positioned.fill(child: _buildMapOrNotice()),
          _buildTopBar(),
          if (_selected != null) _buildVenueCard(_selected!),
          _buildRecenterButton(),
        ],
      ),
    );
  }

  Widget _buildMapOrNotice() {
    if (!_hasKey) return const _MapKeyMissingNotice();
    return FutureBuilder<Style>(
      future: _styleFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError || !snap.hasData) {
          return _MapStyleError(onRetry: () {
            setState(() {
              _styleFuture =
                  StyleReader(uri: _goongStyleUri, apiKey: kGoongMaptilesKey)
                      .read();
            });
          });
        }
        return _buildMap(snap.data!);
      },
    );
  }

  Widget _buildMap(Style style) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(_userLat, _userLng),
        initialZoom: 15,
        minZoom: 5,
        maxZoom: 18,
        onTap: (_, _) {
          _searchFocus.unfocus();
          if (_selected != null || _predictions.isNotEmpty) {
            setState(() {
              _selected = null;
              _predictions = [];
            });
          }
        },
      ),
      children: [
        VectorTileLayer(
          tileProviders: style.providers,
          theme: style.theme,
          sprites: style.sprites,
          // Goong/Mapbox use 512px tiles → offset the zoom by one.
          tileOffset: TileOffset.mapbox,
          maximumZoom: 18,
        ),
        MarkerLayer(markers: _buildMarkers()),
        const RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          attributions: [
            TextSourceAttribution('© Goong'),
            TextSourceAttribution('© OpenStreetMap'),
          ],
        ),
      ],
    );
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[
      // User location dot.
      Marker(
        point: LatLng(_userLat, _userLng),
        width: 26,
        height: 26,
        child: const _UserDot(),
      ),
    ];
    for (final p in _venues) {
      final selected = identical(p, _selected);
      markers.add(
        Marker(
          point: LatLng(p.lat, p.lng),
          width: selected ? 52 : 44,
          height: selected ? 52 : 44,
          child: GestureDetector(
            onTap: () => _selectVenue(p),
            child: _VenuePin(emoji: p.emoji, selected: selected),
          ),
        ),
      );
    }
    // Place picked from the search bar — a distinct ocean pin on top.
    final sp = _searchedPlace;
    if (sp != null) {
      markers.add(
        Marker(
          point: LatLng(sp.lat, sp.lng),
          width: 50,
          height: 50,
          child: GestureDetector(
            onTap: () => _selectVenue(sp),
            child: const _SearchedPin(),
          ),
        ),
      );
    }
    return markers;
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.mint.withValues(alpha: 0.96),
                  AppColors.mint.withValues(alpha: 0.0),
                ],
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const LogoMark(size: 30, float: true),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _usingFallbackLocation
                                ? '📍 TP.HCM (vị trí mặc định)'
                                : '📍 QUÁN QUANH BẠN',
                            style: AppTextStyles.mono(
                              size: 10,
                              weight: FontWeight.w600,
                              color: AppColors.ink50,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          GestureDetector(
                            onTap: _hasVenuesError ? () => _loadVenues() : null,
                            child: Text(
                              _subtitle,
                              style: AppTextStyles.body(
                                size: 15,
                                weight: FontWeight.w700,
                                color: _hasVenuesError
                                    ? AppColors.berry
                                    : AppColors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_loadingVenues)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildSearchField(),
              ],
            ),
          ),
          if (_predictions.isNotEmpty) _buildPredictions(),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    final hasText = _searchCtrl.text.trim().isNotEmpty;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Text('🔍', style: TextStyle(fontSize: 15)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              style: AppTextStyles.body(size: 14, color: AppColors.ink),
              decoration: InputDecoration(
                hintText: 'Tìm quán hoặc địa chỉ…',
                hintStyle: AppTextStyles.body(size: 14, color: AppColors.ink50),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_searching)
            const Padding(
              padding: EdgeInsets.only(right: 14),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (hasText)
            GestureDetector(
              onTap: _clearSearch,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.close_rounded, size: 20, color: AppColors.ink50),
              ),
            )
          else
            const SizedBox(width: 14),
        ],
      ),
    );
  }

  Widget _buildPredictions() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      constraints: const BoxConstraints(maxHeight: 320),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 6),
        shrinkWrap: true,
        itemCount: _predictions.length,
        separatorBuilder: (_, _) =>
            Divider(height: 1, color: AppColors.ink10, indent: 48),
        itemBuilder: (context, i) {
          final p = _predictions[i];
          return InkWell(
            onTap: () => _onPredictionTap(p),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.place_outlined, size: 20, color: AppColors.berry),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.title,
                          style: AppTextStyles.body(
                            size: 14,
                            weight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (p.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            p.subtitle,
                            style: AppTextStyles.body(
                              size: 12,
                              color: AppColors.ink50,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecenterButton() {
    return Positioned(
      right: 16,
      bottom: _selected != null ? 168 : 28,
      child: FloatingActionButton.small(
        heroTag: 'map_recenter',
        backgroundColor: Colors.white,
        foregroundColor: AppColors.berry,
        elevation: 4,
        tooltip: 'Về vị trí của tôi',
        onPressed: () => _recenter(),
        child: const Icon(Icons.my_location_rounded, size: 22),
      ),
    );
  }

  Widget _buildVenueCard(OsmPlace p) {
    final dist = p.distanceLabel(_userLat, _userLng);
    final tags = p.tags.take(2).join(' · ');
    return Positioned(
      left: 16,
      right: 16,
      bottom: 24,
      child: GestureDetector(
        onTap: () => _openDetail(p),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.16),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              VenueThumbnail(
                query: venueImageQuery(p, _area),
                lat: p.lat,
                lng: p.lng,
                width: 64,
                height: 64,
                radius: 14,
                placeholderLabel: p.emoji,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      p.name,
                      style: AppTextStyles.body(
                        size: 15,
                        weight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${p.emoji} $tags · $dist',
                      style:
                          AppTextStyles.body(size: 12, color: AppColors.ink50),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (p.openingHours != null &&
                        p.openingHours!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      OpenNowBadge(openingHours: p.openingHours),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _selected = null),
                    child: Icon(Icons.close_rounded,
                        size: 20, color: AppColors.ink50),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.mint,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.ink10, width: 1),
                    ),
                    child: const Center(
                      child: Text('→',
                          style:
                              TextStyle(fontSize: 16, color: AppColors.ink)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular venue marker with the cuisine emoji, centered on the venue point.
class _VenuePin extends StatelessWidget {
  final String emoji;
  final bool selected;
  const _VenuePin({required this.emoji, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.berry : AppColors.berry.withValues(alpha: 0.55),
          width: selected ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: selected ? 0.28 : 0.16),
            blurRadius: selected ? 14 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(emoji, style: TextStyle(fontSize: selected ? 22 : 18)),
      ),
    );
  }
}

/// The place picked from the search bar — a distinct ocean pin so it stands out
/// from the berry venue pins.
class _SearchedPin extends StatelessWidget {
  const _SearchedPin();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.ocean,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.ocean.withValues(alpha: 0.45),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Center(
        child: Icon(Icons.place, color: Colors.white, size: 26),
      ),
    );
  }
}

/// User's own position — a blue dot with a white ring.
class _UserDot extends StatelessWidget {
  const _UserDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.ocean,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.ocean.withValues(alpha: 0.45),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

/// Shown when `GOONG_MAPTILES_KEY` wasn't provided at build time.
class _MapKeyMissingNotice extends StatelessWidget {
  const _MapKeyMissingNotice();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🗺️', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 16),
            Text(
              'Bản đồ chưa sẵn sàng',
              style: AppTextStyles.body(
                size: 17,
                weight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Thiếu GOONG_MAPTILES_KEY khi build. Thêm key (Maptiles) vào '
              '--dart-define rồi chạy lại để hiện bản đồ Goong.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body(size: 13, color: AppColors.ink50),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapStyleError extends StatelessWidget {
  final VoidCallback onRetry;
  const _MapStyleError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Không tải được bản đồ Goong',
            style: AppTextStyles.body(size: 14, color: AppColors.ink50),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
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
    );
  }
}
