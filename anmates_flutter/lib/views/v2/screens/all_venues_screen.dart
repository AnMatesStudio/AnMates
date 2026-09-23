import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/venue_catalog_service.dart';
import '../../../theme/app_theme_v2.dart';
import '../../../widgets/v2/food_art.dart';
import '../v2_kit.dart';
import '../v2_state.dart';
import '../v2_venue_mapper.dart';

/// **Xem tất cả** — every active venue in the DB, [kAllVenuesPageSize] at a
/// time: the next page is fetched as the list nears its end, until the API
/// reports nothing more. Tapping a row opens its photos and details.
class AllVenuesScreen extends StatefulWidget {
  const AllVenuesScreen({super.key});

  @override
  State<AllVenuesScreen> createState() => _AllVenuesScreenState();
}

class _AllVenuesScreenState extends State<AllVenuesScreen> {
  /// How close to the bottom (px) the next page starts loading, so it usually
  /// lands before the user actually hits the end.
  static const _prefetchExtent = 320.0;

  late final V2State _s = context.read<V2State>();
  late final ScrollController _scroll =
      ScrollController(initialScrollOffset: _s.allVenuesScrollOffset);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scroll.position;
    _s.allVenuesScrollOffset = pos.pixels;
    if (pos.pixels >= pos.maxScrollExtent - _prefetchExtent) {
      _s.loadMoreAllVenues();
    }
  }

  /// A page that doesn't fill the viewport never produces a scroll event, so
  /// the listener alone would stall there — check once the frame is laid out.
  void _fillViewportIfShort() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (_scroll.position.maxScrollExtent <= _prefetchExtent) _s.loadMoreAllVenues();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V2State>();
    final items = s.allVenues;

    if (s.allHasMore && !s.allLoading && s.allError == null && items.isNotEmpty) {
      _fillViewportIfShort();
    }

    final total = s.allTotal;
    final subtitle = total == null
        ? s.t('Đang tải…', 'Loading…')
        : s.t('Đã tải ${items.length} / $total quán', 'Loaded ${items.length} of $total');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 104, 18, 6),
          child: Row(children: [
            V2BackButton(size: 40, onTap: () => s.go(V2Screen.home)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.t('Tất cả quán', 'All venues'),
                    style: AppTextV2.section()
                        .copyWith(fontSize: 25, height: 1.1, letterSpacing: -0.75),
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle, style: AppTextV2.meta()),
                ],
              ),
            ),
          ]),
        ),
        Expanded(
          child: items.isEmpty
              ? _EmptyOrFirstLoad(s: s)
              : ListView.separated(
                  controller: _scroll,
                  padding: EdgeInsets.fromLTRB(
                      18, 12, 18, 24 + MediaQuery.paddingOf(context).bottom),
                  itemCount: items.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => i < items.length
                      ? _VenueRow(
                          venue: items[i],
                          bed: i,
                          onTap: () => s.openCatalogVenue(items[i]),
                        )
                      : _ListFooter(s: s),
                ),
        ),
      ],
    );
  }
}

class _VenueRow extends StatelessWidget {
  const _VenueRow({required this.venue, required this.bed, required this.onTap});

  final CatalogVenue venue;
  final int bed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final v = venueFromCatalog(venue);
    final photos = venue.photoUrls.length;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: AppShadowsV2.card,
        ),
        child: Row(children: [
          SizedBox(
            width: 88,
            height: 88,
            child: Stack(children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColorsV2.tileBeds[bed % AppColorsV2.tileBeds.length],
                    ),
                    child: VenuePhotoOrFallback(
                      photoUrl: v.photoUrl,
                      fallback: FoodArt(
                        asset: v.img, fillFraction: 0.78,
                        shadowOpacity: 0.14, shadowBlur: 10,
                      ),
                    ),
                  ),
                ),
              ),
              // Hints that the detail screen has a carousel to swipe through.
              if (photos > 1)
                Positioned(
                  right: 5,
                  bottom: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.photo_library_outlined, size: 10, color: Colors.white),
                      const SizedBox(width: 3),
                      Text('$photos',
                          style: AppTextV2.name(color: Colors.white, size: 9)),
                    ]),
                  ),
                ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.name,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: AppTextV2.tileTitle()),
                const SizedBox(height: 4),
                Text(v.cardWhere,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: AppTextV2.meta()),
                const SizedBox(height: 6),
                Row(children: [
                  Flexible(
                    child: Text(
                      v.price,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: AppTextV2.name(color: AppColorsV2.wisteria, size: 11.5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('★ ${v.rating}', style: AppTextV2.name(size: 11)),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: AppColorsV2.inkA(0.3)),
        ]),
      ),
    );
  }
}

/// Spinner while a page is in flight, a retry on failure, and an explicit
/// "that's everything" once the DB is exhausted.
class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    if (s.allLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(
            width: 22, height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColorsV2.wisteria),
          ),
        ),
      );
    }
    if (s.allError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(children: [
          Text(s.t('Không tải được thêm quán', "Couldn't load more venues"),
              style: AppTextV2.meta()),
          const SizedBox(height: 8),
          _RetryPill(s: s),
        ]),
      );
    }
    if (!s.allHasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            s.t('Đã hiển thị tất cả ${s.allVenues.length} quán',
                'Showing all ${s.allVenues.length} venues'),
            style: AppTextV2.meta(),
          ),
        ),
      );
    }
    return const SizedBox(height: 40);
  }
}

class _EmptyOrFirstLoad extends StatelessWidget {
  const _EmptyOrFirstLoad({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    if (s.allLoading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2.6, color: AppColorsV2.wisteria),
      );
    }
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(
          s.allError != null
              ? s.t('Không tải được danh sách quán', "Couldn't load venues")
              : s.t('Chưa có quán nào', 'No venues yet'),
          style: AppTextV2.name(color: AppColorsV2.inkA(0.5), size: 13),
        ),
        if (s.allError != null) ...[
          const SizedBox(height: 10),
          _RetryPill(s: s),
        ],
      ]),
    );
  }
}

class _RetryPill extends StatelessWidget {
  const _RetryPill({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: s.loadMoreAllVenues,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: AppShadowsV2.pill,
        ),
        child: Text(s.t('Thử lại', 'Retry'),
            style: AppTextV2.name(color: AppColorsV2.wisteria, size: 11.5)),
      ),
    );
  }
}
