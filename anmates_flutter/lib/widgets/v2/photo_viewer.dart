import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Opens [photos] full screen over a dark scrim, on [initialIndex]. Returns the
/// index it was closed on (null if dismissed some other way).
Future<int?> showPhotoViewer(BuildContext context, List<String> photos, {int initialIndex = 0}) =>
    showGeneralDialog<int>(
      context: context,
      barrierLabel: 'photo-viewer',
      barrierColor: Colors.black.withValues(alpha: 0.94),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) =>
          PhotoViewer(photos: photos, initialIndex: initialIndex),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    );

/// Lets a mouse or trackpad drag a PageView too (web), not only touch.
class DragScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

/// The page dots under a photo carousel / viewer.
class PhotoDots extends StatelessWidget {
  const PhotoDots({super.key, required this.count, required this.index});

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
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({super.key, required this.photos, this.initialIndex = 0});

  final List<String> photos;
  final int initialIndex;

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
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
          behavior: DragScrollBehavior(),
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
                child: PhotoDots(count: widget.photos.length, index: _index),
              ),
            ),
          ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 12,
          right: 12,
          child: Semantics(
            button: true,
            label: MaterialLocalizations.of(context).closeButtonLabel,
            child: GestureDetector(
            key: const Key('photo-viewer-close'),
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
