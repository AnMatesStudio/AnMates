import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme_v2.dart';
import '../../../theme/v2_layout.dart';
import '../../../widgets/v2/food_art.dart';
import '../v2_data.dart';
import '../v2_kit.dart';
import '../v2_state.dart';

/// **B1 · Explore.** Where the feed is looking, a greeting, search, the
/// category tiles, then two rows of venue cards — laid out after the reference
/// picked on 2026-09-26, in the v2 palette, under the same glass nav. Every
/// card is a row from GET /api/v1/venues.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V2State>();
    final feed = s.homeVenues;
    final nearby = feed.take(5).toList();
    // The same slice of the catalogue from a different starting point, so a
    // short feed still fills both rows.
    final tonight = feed.length > 1 ? feed.skip(1).take(5).toList() : feed;
    final pad = V2Layout.hPad(context);
    // The row holds the card plus room for its shadow.
    final rowHeight = _VenueCard.height(context) + 22;

    return Stack(
      children: [
        // White radial wash lifting the feed off the aurora.
        Positioned(
          left: -58, right: -58, top: V2Layout.contentTop(context) + 8, bottom: 104,
          child: const RepaintBoundary(child: CustomPaint(painter: FeedWashPainter())),
        ),
        Positioned.fill(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              top: V2Layout.contentTop(context),
              bottom: navClearance(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: pad),
                  child: _Header(s: s),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: pad),
                  child: Text(
                    s.greetingLine,
                    style: AppTextV2.section().copyWith(fontSize: 24, letterSpacing: -0.72),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: pad),
                  child: _SearchBar(s: s),
                ),
                const SizedBox(height: 14),
                _CategoryTiles(s: s),
                _SectionHeader(title: s.sectionTitle, s: s),
                SizedBox(
                  height: rowHeight,
                  child: nearby.isEmpty ? _FeedPlaceholder(s: s) : _VenueRow(venues: nearby, s: s),
                ),
                _SectionHeader(title: s.t('Kèo mở tối nay', 'Open tables tonight'), s: s),
                SizedBox(
                  height: rowHeight,
                  child: tonight.isEmpty ? _FeedPlaceholder(s: s) : _VenueRow(venues: tonight, s: s),
                ),
                _LocalMatesCard(s: s),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Where the feed is looking — the search radius, or that location is off —
/// which opens the radius sheet; then notifications and the profile avatar.
class _Header extends StatelessWidget {
  const _Header({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: V2TapTarget(
          onTap: s.openRadiusSheet,
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  s.locationUnavailable ? Icons.location_off_rounded : Icons.place_rounded,
                  size: 18,
                  color: AppColorsV2.wisteria,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    s.locationHeadline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextV2.name(size: 14.5),
                  ),
                ),
                Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColorsV2.inkA(0.55)),
              ]),
              const SizedBox(height: 3),
              Text(
                s.t('Tìm quán ngon quanh bạn', 'Good food around you'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextV2.meta(color: AppColorsV2.inkA(0.5)),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 6),
      _NotifButton(s: s),
      V2TapTarget(
        onTap: () => s.go(V2Screen.me),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Colors.white, shape: BoxShape.circle, boxShadow: AppShadowsV2.pill,
          ),
          child: const CircleAvatar(radius: 21, backgroundImage: AssetImage(A.avatar)),
        ),
      ),
    ]);
  }
}

class _NotifButton extends StatelessWidget {
  const _NotifButton({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return V2TapTarget(
      onTap: () => s.setNotifsOpen(true),
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: Colors.white, shape: BoxShape.circle, boxShadow: AppShadowsV2.pill,
        ),
        child: Stack(alignment: Alignment.center, children: [
          Icon(Icons.notifications_none_rounded, size: 21, color: AppColorsV2.inkA(0.62)),
          Positioned(
            top: 9, right: 10,
            child: Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: AppColorsV2.alert,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Opens the search overlay; the tune icon at its end opens the mates filter
/// (C1), which used to have a button of its own here.
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: AppShadowsV2.pill,
      ),
      // Stretched, so the search half takes taps across the pill's whole
      // height rather than just the 20pt line of text.
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: GestureDetector(
            onTap: () => s.setSearchOpen(true),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(left: 18),
              child: Row(children: [
                Icon(Icons.search_rounded, size: 19, color: AppColorsV2.inkA(0.42)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.t('Tìm quán, món, khu vực', 'Search a spot, a dish, a district'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextV2.body(color: AppColorsV2.inkA(0.45), size: 13),
                  ),
                ),
              ]),
            ),
          ),
        ),
        V2TapTarget(
          onTap: () => s.go(V2Screen.filters),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Icon(Icons.tune_rounded, size: 20, color: AppColorsV2.wisteria),
          ),
        ),
      ]),
    );
  }
}

/// The category tiles: a 3D render (an icon for "all") over the label, the
/// selected one in Wisteria. Picking one narrows both rows below.
class _CategoryTiles extends StatelessWidget {
  const _CategoryTiles({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    final u = V2Layout.unit(context);
    final pad = V2Layout.hPad(context);
    final tileHeight = 92 * u + V2Layout.textGrowth(context, 16);

    return SizedBox(
      // Tile plus room for the selected tile's glow.
      height: tileHeight + 18,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(pad, 4, pad, 14),
        itemCount: kFeedCategories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final c = kFeedCategories[i];
          final on = s.feedCategory == i;
          final ink = on ? Colors.white : AppColorsV2.inkA(0.72);
          return GestureDetector(
            onTap: () => s.setFeedCategory(i),
            child: Container(
              width: 80 * u,
              decoration: BoxDecoration(
                color: on ? AppColorsV2.wisteria : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: on ? AppShadowsV2.ctaGlow(opacity: 0.3) : AppShadowsV2.pill,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox.square(
                    dimension: 42 * u,
                    child: c.art == null
                        ? Icon(Icons.restaurant_menu_rounded, size: 26 * u,
                            color: on ? Colors.white : AppColorsV2.wisteria)
                        : FoodArt(asset: c.art!, shadowOpacity: 0.14, shadowBlur: 8),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    s.tr(c.label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTextV2.name(color: ink, size: 12).copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A section title with the reference's "see all →" pill.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.s});
  final String title;
  final V2State s;

  @override
  Widget build(BuildContext context) {
    final pad = V2Layout.hPad(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 12, pad, 0),
      child: Row(children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextV2.section(),
          ),
        ),
        const SizedBox(width: 8),
        V2TapTarget(
          onTap: s.openAllVenues,
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 7, 9, 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              boxShadow: AppShadowsV2.pill,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(
                s.t('Xem tất cả', 'See all'),
                style: AppTextV2.name(color: AppColorsV2.wisteria, size: 12),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_rounded, size: 15, color: AppColorsV2.wisteria),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _VenueRow extends StatelessWidget {
  const _VenueRow({required this.venues, required this.s});
  final List<Venue> venues;
  final V2State s;

  @override
  Widget build(BuildContext context) {
    final pad = V2Layout.hPad(context);
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.fromLTRB(pad, 8, pad, 14),
      itemCount: venues.length,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (context, i) => _VenueCard(
        venue: venues[i],
        bed: i,
        onTap: () => s.openVenueNamed(venues[i].name),
      ),
    );
  }
}

/// A venue the way the reference draws it: the photo on top, then the name
/// (and rating, when the DB has one), then where it is and how far.
class _VenueCard extends StatelessWidget {
  const _VenueCard({required this.venue, required this.bed, required this.onTap});
  final Venue venue;
  final int bed;
  final VoidCallback onTap;

  static double width(BuildContext context) => 262 * V2Layout.unit(context);
  static double photoHeight(BuildContext context) => 136 * V2Layout.unit(context);

  /// Photo plus the two text lines, which grow with the user's text size.
  static double height(BuildContext context) =>
      photoHeight(context) + 66 + V2Layout.textGrowth(context, 34);

  @override
  Widget build(BuildContext context) {
    final v = venue;
    final meta = AppTextV2.meta(color: AppColorsV2.inkA(0.55));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width(context),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: AppShadowsV2.card,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: photoHeight(context),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColorsV2.tileBeds[bed % AppColorsV2.tileBeds.length],
                ),
                child: VenuePhotoOrFallback(
                  photoUrl: v.photoUrl,
                  fallback: FoodArt(
                    asset: v.img, fillFraction: 0.7, shadowOpacity: 0.16, shadowBlur: 12,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(13, 9, 13, 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          v.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextV2.cardTitle().copyWith(fontSize: 14),
                        ),
                      ),
                      // Most rows carry no rating yet; a dash would be noise.
                      if (v.rating != '—') ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.star_rounded, size: 16, color: AppColorsV2.ink),
                        const SizedBox(width: 2),
                        Text(v.rating, style: AppTextV2.name(size: 12)),
                      ],
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.place_rounded, size: 14, color: AppColorsV2.wisteria),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(v.area, maxLines: 1, overflow: TextOverflow.ellipsis, style: meta),
                      ),
                      if (v.dist.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.near_me_rounded, size: 13, color: AppColorsV2.inkA(0.45)),
                        const SizedBox(width: 3),
                        Text(v.dist, style: meta),
                      ],
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalMatesCard extends StatelessWidget {
  const _LocalMatesCard({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    final pad = V2Layout.hPad(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 18, pad, 0),
      child: GestureDetector(
        onTap: () => s.go(V2Screen.local),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColorsV2.ink,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(children: [
            const SizedBox(
              width: 46, height: 46,
              child: FoodArt(asset: A.coffee, shadowOpacity: 0),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.t('Mới đến thành phố? Tìm Local Mates', 'New in town? Find Local Mates'),
                    style: AppTextV2.name(color: Colors.white, size: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.t('Người bản địa dẫn đi quán chuẩn vị.',
                        'Locals who take you to the real thing.'),
                    style: AppTextV2.body(color: AppColorsV2.whiteA(0.66), size: 11)
                        .copyWith(height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('›', style: AppTextV2.name(color: AppColorsV2.wisteria, size: 19)),
          ]),
        ),
      ),
    );
  }
}

/// Two stacked white radial washes behind the feed, matching the design's
/// `radial-gradient(closest-side …)` pair — elliptical, so a plain circular
/// [RadialGradient] would leave the top and bottom too exposed.
class FeedWashPainter extends CustomPainter {
  const FeedWashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = size.center(Offset.zero);
    final rx = size.width / 2;
    final ry = size.height / 2;
    if (rx <= 0 || ry <= 0) return;

    final squash = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(1, ry / rx, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);

    void wash(List<Color> colors, List<double> stops) {
      canvas.drawRect(
        rect,
        Paint()..shader = _radial(center, rx, colors, stops, squash),
      );
    }

    wash([AppColorsV2.whiteA(0.72), AppColorsV2.whiteA(0.5), AppColorsV2.whiteA(0)],
        [0, 0.58, 1]);
    wash([
      Colors.white, Colors.white,
      AppColorsV2.whiteA(0.9), AppColorsV2.whiteA(0.5), AppColorsV2.whiteA(0),
    ], [0, 0.48, 0.66, 0.84, 1]);
  }

  /// `Gradient.radial` is circular; the matrix squashes it into the ellipse the
  /// CSS `closest-side` wash actually describes.
  static Shader _radial(
    Offset center, double r, List<Color> colors, List<double> stops, Matrix4 m,
  ) =>
      ui.Gradient.radial(center, r, colors, stops, TileMode.clamp, m.storage);

  @override
  bool shouldRepaint(FeedWashPainter oldDelegate) => false;
}

/// Shown in place of a venue row while the catalogue is loading, when the
/// fetch failed, or when nothing matched. The feed never falls back to sample
/// rows, nor to venues outside the picked radius — empty reads as empty, with
/// the one action that can change it.
class _FeedPlaceholder extends StatelessWidget {
  const _FeedPlaceholder({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    if (s.venuesLoading) {
      return const Center(
        child: SizedBox(
          width: 22, height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColorsV2.wisteria),
        ),
      );
    }

    final failed = s.venuesError != null && s.venuesError != 'empty';
    // Venues in range, just none under the selected tile.
    final cat = s.feedCategory != 0 && s.venues.isNotEmpty
        ? kFeedCategories[s.feedCategory].label
        : null;
    final (message, action, onAction) = switch (s.feedRadiusKm) {
      _ when failed => (
          s.t('Không tải được danh sách quán', "Couldn't load venues"),
          s.t('Thử lại', 'Retry'),
          () => s.loadVenues(force: true),
        ),
      final r when cat != null => (
          r == null
              ? s.t('Không có quán ${cat(false).toLowerCase()} nào',
                  'No ${cat(true).toLowerCase()} spots yet')
              : s.t('Không có quán ${cat(false).toLowerCase()} nào trong $r km',
                  'No ${cat(true).toLowerCase()} within $r km'),
          s.t('Xem tất cả món', 'Show every dish'),
          () => s.setFeedCategory(0),
        ),
      // No location, so this was the whole catalogue.
      null => (
          s.t('Chưa có quán nào', 'No venues in the catalogue yet'),
          s.t('Thử lại', 'Retry'),
          () => s.loadVenues(force: true),
        ),
      final r when r < kRadiusMaxKm => (
          s.t('Không có quán nào trong $r km', 'No venues within $r km'),
          s.t('Mở rộng bán kính', 'Widen the radius'),
          () => s.setRadiusSheetOpen(true),
        ),
      // Already as wide as the slider goes.
      final r => (
          s.t('Không có quán nào trong $r km', 'No venues within $r km'),
          s.t('Xem tất cả quán', 'See all venues'),
          s.openAllVenues,
        ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, style: AppTextV2.name(size: 13)),
            const SizedBox(height: 2),
            V2TapTarget(
              onTap: onAction,
              child: Text(action, style: AppTextV2.name(color: AppColorsV2.wisteria, size: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
