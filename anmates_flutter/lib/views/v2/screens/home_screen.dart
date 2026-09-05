import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme_v2.dart';
import '../../../widgets/v2/food_art.dart';
import '../v2_data.dart';
import '../v2_state.dart';

/// **B1 · Explore — hero 3D collage.** The design's single home surface:
/// "Đã chốt Home C làm Explore duy nhất."
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V2State>();
    // Straight from GET /api/v1/venues. The two rows show different slices of
    // the same catalogue, and both shrink gracefully when the DB holds fewer
    // venues than the design's six.
    final all = s.venues;
    final tiles = all.take(4).toList();
    final cards = all.length > 1 ? all.skip(1).take(5).toList() : all;

    return Stack(
      children: [
        // White radial wash lifting the feed off the aurora.
        const Positioned(
          left: -58, right: -58, top: 104, bottom: 104,
          child: RepaintBoundary(child: CustomPaint(painter: FeedWashPainter())),
        ),
        Positioned.fill(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 96, bottom: 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(children: [
                    Expanded(child: _ProfilePill(s: s)),
                    const SizedBox(width: 10),
                    _NotifButton(s: s),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                  child: Row(children: [
                    Expanded(child: _SearchPill(s: s)),
                    const SizedBox(width: 9),
                    _FilterButton(s: s),
                  ]),
                ),
                const SizedBox(height: 2),
                _Hero(s: s),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(children: [
                    _Cta(s: s),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _StatCard(
                        value: s.openTables,
                        valueColor: AppColorsV2.wisteria,
                        label: s.t('kèo đang mở gần bạn', 'open tables near you'),
                        onTap: () => s.go(V2Screen.swipe),
                      )),
                      const SizedBox(width: 10),
                      // The design's second stat was Trust Score — no
                      // trust_score column exists anywhere in the schema, so
                      // it's replaced with a real number: how many candidates
                      // GET /api/v1/matches actually returned.
                      Expanded(child: _StatCard(
                        value: '${s.candidates.length}',
                        valueColor: AppColorsV2.ink,
                        label: s.t('mates hợp gu', 'matching mates'),
                        onTap: () => s.go(V2Screen.swipe),
                      )),
                    ]),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 26, 18, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(child: Text(s.sectionTitle, style: AppTextV2.section())),
                      GestureDetector(
                        onTap: () => s.go(V2Screen.filters),
                        child: Text(
                          s.t('Xem tất cả', 'See all'),
                          style: AppTextV2.name(color: AppColorsV2.wisteria, size: 11.5),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 198,
                  child: tiles.isEmpty
                      ? _FeedPlaceholder(s: s)
                      : _TileRow(tiles: tiles, s: s),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 26, 18, 0),
                  child: Text(
                    s.t('Kèo mở tối nay', 'Open tables tonight'),
                    style: AppTextV2.section(),
                  ),
                ),
                SizedBox(
                  height: 194,
                  child: cards.isEmpty
                      ? _FeedPlaceholder(s: s)
                      : _CardRow(cards: cards, s: s),
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

class _ProfilePill extends StatelessWidget {
  const _ProfilePill({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => s.go(V2Screen.me),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: AppShadowsV2.pill,
        ),
        child: Row(children: [
          const CircleAvatar(radius: 19, backgroundImage: AssetImage(A.avatar)),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  s.t('Chào buổi tối', 'Good evening'),
                  style: AppTextV2.meta(color: AppColorsV2.inkA(0.42)).copyWith(fontSize: 9.5),
                ),
                Text(s.profileName.isEmpty ? '—' : s.profileName, style: AppTextV2.name()),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _NotifButton extends StatelessWidget {
  const _NotifButton({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => s.setNotifsOpen(true),
      child: Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          color: Colors.white, shape: BoxShape.circle, boxShadow: AppShadowsV2.pill,
        ),
        child: Stack(alignment: Alignment.center, children: [
          Icon(Icons.notifications_none_rounded, size: 22, color: AppColorsV2.inkA(0.62)),
          Positioned(
            top: 11, right: 12,
            child: Container(
              width: 9, height: 9,
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

class _SearchPill extends StatelessWidget {
  const _SearchPill({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => s.setSearchOpen(true),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 17),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: AppShadowsV2.pill,
        ),
        child: Row(children: [
          Icon(Icons.search_rounded, size: 17, color: AppColorsV2.inkA(0.4)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              s.t('Tìm quán, món, khu vực', 'Search a spot, a dish, a district'),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: AppTextV2.body(color: AppColorsV2.inkA(0.45), size: 12.5),
            ),
          ),
        ]),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => s.go(V2Screen.filters),
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: AppColorsV2.wisteria,
          shape: BoxShape.circle,
          boxShadow: AppShadowsV2.ctaGlow(opacity: 0.36),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final w in [17.0, 12.0, 7.0]) ...[
              Container(
                width: w, height: 2,
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (w != 7.0) const SizedBox(height: 3.5),
            ],
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 272,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            top: 6, left: -14, width: 126, height: 126,
            child: FloatingArt(
              period: Duration(milliseconds: 6000),
              child: FoodArt(asset: A.burger),
            ),
          ),
          const Positioned(
            top: 0, right: -10, width: 142, height: 130,
            child: FloatingArt(
              period: Duration(milliseconds: 6600),
              delay: Duration(milliseconds: 500),
              child: FoodArt(asset: A.ramen),
            ),
          ),
          const Positioned(
            bottom: 2, right: 8, width: 84, height: 96,
            child: FloatingArt(
              period: Duration(milliseconds: 7200),
              delay: Duration(milliseconds: 1000),
              child: FoodArt(asset: A.beer, shadowBlur: 16),
            ),
          ),
          const Positioned(
            bottom: 10, left: 10, width: 98, height: 90,
            child: FloatingArt(
              period: Duration(milliseconds: 6200),
              delay: Duration(milliseconds: 800),
              child: FoodArt(asset: A.coffee, shadowBlur: 16),
            ),
          ),
          Positioned(
            top: 82, left: 0, right: 0,
            child: Column(children: [
              Text(s.locationLabel, style: AppTextV2.body(color: AppColorsV2.inkA(0.5))),
              const SizedBox(height: 5),
              ShaderMask(
                shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment(-1, -0.6), end: Alignment(1, 0.6),
                  colors: [AppColorsV2.blue, AppColorsV2.wisteria],
                ).createShader(rect),
                child: Text(
                  s.cravingCount,
                  style: AppTextV2.heroNumber().copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                s.t('mates đang thèm ăn tối nay', 'mates are craving food tonight'),
                style: AppTextV2.name(size: 12.5),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Cta extends StatelessWidget {
  const _Cta({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => s.go(V2Screen.swipe),
      child: Container(
        height: 56, alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: AppGradientsV2.cta,
          borderRadius: BorderRadius.circular(999),
          boxShadow: AppShadowsV2.ctaGlow(),
        ),
        child: Text(
          s.t('Gom kèo tối nay', 'Gather a table tonight'),
          style: AppTextV2.cta(),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value, required this.valueColor,
    required this.label, required this.onTap,
  });

  final String value;
  final Color valueColor;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: AppShadowsV2.pill,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: AppTextV2.stat(color: valueColor)),
            const SizedBox(height: 5),
            Text(label, style: AppTextV2.meta().copyWith(
              height: 1.35, fontWeight: FontWeight.w600,
            )),
          ],
        ),
      ),
    );
  }
}

class _TileRow extends StatelessWidget {
  const _TileRow({required this.tiles, required this.s});
  final List<Venue> tiles;
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
      itemCount: tiles.length,
      separatorBuilder: (_, _) => const SizedBox(width: 11),
      itemBuilder: (context, i) {
        final v = tiles[i];
        return GestureDetector(
          onTap: () => s.openVenueNamed(v.name),
          child: SizedBox(
            width: 132,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 120,
                  child: Stack(children: [
                    Positioned.fill(
                      // ClipRRect (not just BoxDecoration.borderRadius, which
                      // doesn't clip a child) so a real cover-fit photo can't
                      // spill past the rounded corners the color bed implies.
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColorsV2.tileBeds[i % AppColorsV2.tileBeds.length],
                          ),
                          child: VenuePhotoOrFallback(
                            photoUrl: v.photoUrl,
                            fallback: FoodArt(
                              asset: v.img, fillFraction: 0.76,
                              shadowOpacity: 0.16, shadowBlur: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColorsV2.whiteA(0.94),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('★ ${v.rating}', style: AppTextV2.name(size: 9)),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 9),
                Text(v.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: AppTextV2.tileTitle()),
                const SizedBox(height: 3),
                Text(v.tileMeta, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: AppTextV2.meta()),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({required this.cards, required this.s});
  final List<Venue> cards;
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      itemCount: cards.length,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (context, i) {
        final v = cards[i];
        return GestureDetector(
          onTap: () => s.openVenueNamed(v.name),
          child: Container(
            width: 138, height: 172,
            decoration: BoxDecoration(
              color: AppColorsV2.cardBeds[i % AppColorsV2.cardBeds.length],
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: AppShadowsV2.card,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(children: [
              Positioned(
                left: 0, right: 0, top: 14, height: 84,
                child: VenuePhotoOrFallback(
                  photoUrl: v.photoUrl,
                  fallback: FoodArt(
                    asset: v.img, fillFraction: 0.86,
                    shadowOpacity: 0.18, shadowBlur: 12,
                  ),
                ),
              ),
              Positioned(
                left: 11, right: 11, bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: AppTextV2.cardTitle()),
                    const SizedBox(height: 3),
                    Text(v.cardWhere, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: AppTextV2.meta(color: AppColorsV2.inkA(0.5))
                            .copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _LocalMatesCard extends StatelessWidget {
  const _LocalMatesCard({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 0),
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
/// fetch failed, or when the DB simply holds no active venues. The feed never
/// falls back to sample rows — an empty catalogue reads as empty.
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              failed
                  ? s.t('Không tải được danh sách quán', "Couldn't load venues")
                  : s.t('Chưa có quán nào trong khu vực này',
                      'No venues in the catalogue yet'),
              textAlign: TextAlign.center,
              style: AppTextV2.name(size: 13),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => s.loadVenues(force: true),
              child: Text(
                s.t('Thử lại', 'Retry'),
                style: AppTextV2.name(color: AppColorsV2.wisteria, size: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
