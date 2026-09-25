import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme_v2.dart';
import '../../../widgets/v2/food_art.dart';
import '../v2_data.dart';
import '../v2_kit.dart';
import '../v2_state.dart';

/// Flutter's default [ScrollBehavior] only treats touch/stylus as a drag
/// gesture — on web/desktop a mouse drag falls through as nothing, so the
/// photo `PageView`s never see a swipe. This adds mouse and trackpad so the
/// same left/right swipe works with a cursor.
class _DragScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

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
                // Level with the language toggle, which sits at safeTop + 8.
                top: MediaQuery.paddingOf(context).top + 8, left: 18,
                child: V2BackButton(size: 40, onTap: () => s.go(s.detailBack)),
              ),
            ]),
          ),
          Transform.translate(
            offset: Offset.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
              child: Column(children: [
                const SizedBox(height: 8),
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
                style: AppTextV2.name(color: Colors.white, size: 11)
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

/// A full-bleed carousel of the venue's own photos: swipe to step through,
/// dots at the bottom track position, tap opens [_PhotoViewer]. Falls back to
/// [_DetailArt] when the venue has no stored photos, or per-photo on a
/// network error.
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

  Future<void> _openViewer() async {
    final landed = await showGeneralDialog<int>(
      context: context,
      barrierLabel: 'photo-viewer',
      barrierColor: Colors.black.withValues(alpha: 0.94),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) =>
          _PhotoViewer(photos: widget.place.photoUrls, initialIndex: _index),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    );
    // Land the carousel on whichever photo the viewer was closed on.
    if (!mounted || landed == null || landed == _index) return;
    setState(() => _index = landed);
    _controller.jumpToPage(landed);
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
        ScrollConfiguration(
          behavior: _DragScrollBehavior(),
          child: PageView.builder(
            controller: _controller,
            itemCount: photos.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => GestureDetector(
              onTap: _openViewer,
              // A venue with real DB photos never falls back to the 3D
              // illustration mid-swipe — a broken slide gets a neutral
              // placeholder instead, so it can't be mistaken for another
              // venue's "no photo on file" art.
              child: Image.network(
                photos[i],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const _BrokenPhoto(),
              ),
            ),
          ),
        ),
        if (photos.length > 1)
          Positioned(
            left: 16, right: 16, bottom: 14,
            child: IgnorePointer(child: _Dots(count: photos.length, index: _index)),
          ),
      ]),
    );
  }
}

/// A neutral stand-in for a photo that failed to load — distinct from
/// [_DetailArt]'s food illustration, so a broken slide in a venue's own
/// photo carousel is never mistaken for "this venue has no photos on file".
class _BrokenPhoto extends StatelessWidget {
  const _BrokenPhoto();

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: ColoredBox(
        color: AppColorsV2.canvas,
        child: Center(
          child: Icon(Icons.broken_image_outlined, color: AppColorsV2.inkA(0.28), size: 40),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == index ? Colors.white : Colors.white.withValues(alpha: 0.45),
              // Keeps the white dots readable over bright photos.
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4),
              ],
            ),
          ),
      ]),
    );
  }
}

/// Full-screen photo viewer: pinch / scroll-wheel to zoom, swipe between
/// photos, close with the X or a tap outside the photo. Pops with the index
/// it was closed on so the carousel can follow.
class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.photos, required this.initialIndex});

  final List<String> photos;
  final int initialIndex;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  bool _zoomed = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop(_index);

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(children: [
        ScrollConfiguration(
          behavior: _DragScrollBehavior(),
          child: PageView.builder(
            controller: _pages,
            // Panning a zoomed photo must not flip to the next one.
            physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() {
              _index = i;
              _zoomed = false;
            }),
            itemBuilder: (context, i) => _ZoomablePhoto(
              url: widget.photos[i],
              onTapOutside: _close,
              onZoomChanged: (z) {
                if (z != _zoomed) setState(() => _zoomed = z);
              },
            ),
          ),
        ),
        if (widget.photos.length > 1)
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 18,
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _zoomed ? 0 : 1,
                child: _Dots(count: widget.photos.length, index: _index),
              ),
            ),
          ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 12,
          right: 12,
          child: GestureDetector(
            onTap: _close,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
            ),
          ),
        ),
      ]),
    );
  }
}

class _ZoomablePhoto extends StatefulWidget {
  const _ZoomablePhoto({
    required this.url,
    required this.onTapOutside,
    required this.onZoomChanged,
  });

  final String url;
  final VoidCallback onTapOutside;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto> with SingleTickerProviderStateMixin {
  final _zoom = TransformationController();
  late final AnimationController _zoomAnimController =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  Animation<Matrix4>? _zoomAnim;

  // The size InteractiveViewer hands its child — captured off the
  // LayoutBuilder below so a double tap can zoom centered on the middle of
  // the viewport without needing the tap's exact position.
  Size _viewportSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _zoom.addListener(() => widget.onZoomChanged(_zoom.value.getMaxScaleOnAxis() > 1.01));
    _zoomAnimController.addListener(() {
      final anim = _zoomAnim;
      if (anim != null) _zoom.value = anim.value;
    });
  }

  @override
  void dispose() {
    _zoomAnimController.dispose();
    _zoom.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    final zoomedIn = _zoom.value.getMaxScaleOnAxis() > 1.01;
    Matrix4 target;
    if (zoomedIn) {
      target = Matrix4.identity();
    } else {
      const scale = 2.5;
      final cx = _viewportSize.width / 2;
      final cy = _viewportSize.height / 2;
      target = Matrix4.identity()
        ..translateByDouble(-cx * (scale - 1), -cy * (scale - 1), 0, 1)
        ..scaleByDouble(scale, scale, scale, 1);
    }
    _zoomAnim = Matrix4Tween(begin: _zoom.value, end: target).animate(
      CurveTween(curve: Curves.easeOut).animate(_zoomAnimController),
    );
    _zoomAnimController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    // The outer detector catches taps on the dark letterbox around the photo;
    // the inner one swallows taps on the photo itself so they don't close,
    // and owns the double-tap-to-zoom gesture.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTapOutside,
      child: InteractiveViewer(
        transformationController: _zoom,
        minScale: 1,
        maxScale: 5,
        child: LayoutBuilder(
          builder: (context, constraints) {
            _viewportSize = constraints.biggest;
            return Center(
              child: GestureDetector(
                onTap: () {},
                onDoubleTap: _onDoubleTap,
                child: Image.network(
                  widget.url,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.broken_image_outlined, color: Colors.white54, size: 48,
                  ),
                ),
              ),
            );
          },
        ),
      ),
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
