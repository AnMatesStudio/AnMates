import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme_v2.dart';
import '../../../widgets/v2/food_art.dart';
import '../v2_data.dart';
import '../v2_kit.dart';
import '../v2_state.dart';

/// **B2 · Chi tiết quán** — the venue's own columns from `GET /api/v1/venues`,
/// one line each, with a missing price flagged in red.
class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V2State>();
    final place = s.place;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 300,
            child: Stack(children: [
              _PhotoCarousel(place: place),
              Positioned(
                top: 104, left: 18,
                child: V2BackButton(size: 40, onTap: () => s.go(V2Screen.home)),
              ),
            ]),
          ),
          Transform.translate(
            offset: const Offset(0, -96),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
              child: Column(children: [
                const SizedBox(height: 104),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColorsV2.inkA(0.06)),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0A285A).withValues(alpha: 0.08),
                        blurRadius: 26,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        place.name,
                        style: AppTextV2.section()
                            .copyWith(fontSize: 25, height: 1.14, letterSpacing: -0.75),
                      ),
                      const SizedBox(height: 6),
                      Text(s.tr(place.meta),
                          style: AppTextV2.body(color: AppColorsV2.inkA(0.48), size: 12.5)),
                      const SizedBox(height: 16),
                      _AiSummary(s: s),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(child: _Stat(
                          value: s.wantingLabel,
                          color: AppColorsV2.wisteria,
                          label: s.t('người muốn đi tối nay', 'want to go tonight'),
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: _Stat(
                          value: s.tr(place.group),
                          color: AppColorsV2.ink,
                          label: s.t('nhóm tối ưu để chia món', 'ideal group to split this'),
                        )),
                      ]),
                      const SizedBox(height: 16),
                      V2Cta(
                        label: s.t('Tìm mates đi quán này', 'Find mates for this spot'),
                        radius: 20,
                        onTap: () => s.go(V2Screen.swipe),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiSummary extends StatelessWidget {
  const _AiSummary({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F3FF),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: AppColorsV2.wisteria,
                borderRadius: BorderRadius.circular(8),
              ),
              // These lines are the venue's own DB columns, not a generated
              // summary — the old "AI CULINARY SUMMARY" badge would now be
              // claiming something the content doesn't do.
              child: Text(
                s.t('THÔNG TIN QUÁN', 'VENUE DETAILS'),
                style: AppTextV2.name(color: Colors.white, size: 9.5)
                    .copyWith(letterSpacing: 0.76),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(s.tr(s.place.reviews),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: AppTextV2.meta(color: AppColorsV2.inkA(0.42))
                      .copyWith(fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 12),
          for (final l in s.place.lines) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 82,
                  child: Text(s.tr(l.key),
                      style: AppTextV2.meta(color: AppColorsV2.inkA(0.42))
                          .copyWith(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.tr(l.value),
                    style: AppTextV2.body(color: l.color ?? AppColorsV2.ink, size: 13)
                        .copyWith(fontWeight: FontWeight.w600, height: 1.45),
                  ),
                ),
              ],
            ),
            if (l != s.place.lines.last) const SizedBox(height: 9),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.color, required this.label});

  final String value;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7FD),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTextV2.stat(color: color).copyWith(fontSize: 21)),
          const SizedBox(height: 3),
          Text(label, style: AppTextV2.meta().copyWith(
            fontWeight: FontWeight.w600, height: 1.35,
          )),
        ],
      ),
    );
  }
}

/// A TikTok/Instagram-story-style full-bleed carousel of the venue's own
/// photos: swipe or tap the left/right edge to step through, with a
/// segmented progress bar standing in for dots. Falls back to [_DetailArt]
/// when the venue has no stored photos, or per-photo on a network error.
class _PhotoCarousel extends StatefulWidget {
  const _PhotoCarousel({required this.place});
  final Place place;

  @override
  State<_PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<_PhotoCarousel> {
  final _controller = PageController();
  int _index = 0;

  @override
  void didUpdateWidget(covariant _PhotoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different venue means a different photo set — restart at photo 1
    // rather than carrying over an index that may not exist any more.
    if (oldWidget.place.name != widget.place.name) {
      _index = 0;
      if (_controller.hasClients) _controller.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _step(int delta) {
    final last = widget.place.photoUrls.length - 1;
    final next = (_index + delta).clamp(0, last);
    if (next == _index) return;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    final photos = place.photoUrls;

    if (photos.isEmpty) {
      return Positioned.fill(
        child: Stack(fit: StackFit.expand, children: [_DetailArt(place: place)]),
      );
    }

    return Positioned.fill(
      child: Stack(fit: StackFit.expand, children: [
        PageView.builder(
          controller: _controller,
          itemCount: photos.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (context, i) => Image.network(
            photos[i],
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Stack(fit: StackFit.expand, children: [_DetailArt(place: place)]),
          ),
        ),
        if (photos.length > 1) ...[
          Positioned(
            left: 0, top: 0, bottom: 0, width: 60,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => _step(-1),
            ),
          ),
          Positioned(
            right: 0, top: 0, bottom: 0, width: 60,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => _step(1),
            ),
          ),
          Positioned(
            top: 58, left: 18, right: 18,
            child: Row(children: [
              for (var i = 0; i < photos.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 3,
                    decoration: BoxDecoration(
                      color: i <= _index ? Colors.white : Colors.white.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ]),
          ),
        ],
      ]),
    );
  }
}

/// The bottom-anchored floating 3D render — the hero's fallback when the
/// venue has no stored photo, and the shape a photo replaces entirely rather
/// than sitting alongside.
class _DetailArt extends StatelessWidget {
  const _DetailArt({required this.place});
  final Place place;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0, right: 0, bottom: 34, height: 230,
      child: FloatingArt(
        period: const Duration(milliseconds: 6000),
        child: FoodArt(
          asset: place.img, fillFraction: 0.76,
          shadowOpacity: 0.26, shadowBlur: 26,
        ),
      ),
    );
  }
}
