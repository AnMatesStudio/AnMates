import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Where a square crop sits on a photo: the photo is scaled to cover a
/// [viewport]-sized square ("cover" at [zoom] 1, up to [maxZoom]) and moved by
/// [offset] — its center's distance from the viewport's center, in viewport
/// units. Every change is clamped so the photo still covers the whole square.
@immutable
class CropFrame {
  const CropFrame._(this.imageSize, this.viewport, this.zoom, this.offset);

  factory CropFrame({
    required Size imageSize,
    required double viewport,
    double zoom = 1,
    Offset offset = Offset.zero,
  }) =>
      CropFrame._(imageSize, viewport, 1, Offset.zero)._with(zoom, offset);

  static const double maxZoom = 4;

  final Size imageSize;
  final double viewport;
  final double zoom;
  final Offset offset;

  double get baseScale => viewport / math.min(imageSize.width, imageSize.height);

  /// Viewport units per photo pixel.
  double get scale => baseScale * zoom;

  /// The square of the photo, in its pixels, that shows in the viewport.
  Rect get sourceRect {
    final side = viewport / scale;
    final center = Offset(
      imageSize.width / 2 - offset.dx / scale,
      imageSize.height / 2 - offset.dy / scale,
    );
    return Rect.fromCenter(center: center, width: side, height: side);
  }

  /// Moves the photo by [delta] viewport units.
  CropFrame panBy(Offset delta) => _with(zoom, offset + delta);

  /// Zooms to [z] (kept to 1–[maxZoom]) keeping the photo point under [focal]
  /// — measured from the viewport's center — where it was.
  CropFrame zoomTo(double z, {Offset focal = Offset.zero}) {
    final next = z.clamp(1.0, maxZoom).toDouble();
    return _with(next, focal + (offset - focal) * (next / zoom));
  }

  /// The same crop in a viewport of another size.
  CropFrame withViewport(double v) =>
      CropFrame(imageSize: imageSize, viewport: v, zoom: zoom, offset: offset * (v / viewport));

  CropFrame _with(double z, Offset o) {
    final zz = z.clamp(1.0, maxZoom).toDouble();
    final s = baseScale * zz;
    final mx = math.max(0.0, (imageSize.width * s - viewport) / 2);
    final my = math.max(0.0, (imageSize.height * s - viewport) / 2);
    return CropFrame._(
      imageSize,
      viewport,
      zz,
      Offset(o.dx.clamp(-mx, mx).toDouble(), o.dy.clamp(-my, my).toDouble()),
    );
  }
}

/// Holds the crop of one photo, in a unit viewport so it doesn't depend on
/// how big the cropper is drawn. The zoom slider and buttons drive it too.
class AvatarCropController extends ChangeNotifier {
  AvatarCropController(this.image)
      : _frame = CropFrame(
          imageSize: Size(image.width.toDouble(), image.height.toDouble()),
          viewport: 1,
        );

  final ui.Image image;
  CropFrame _frame;

  CropFrame get frame => _frame;
  double get zoom => _frame.zoom;

  void zoomTo(double z, {Offset focal = Offset.zero}) => _set(_frame.zoomTo(z, focal: focal));
  void panBy(Offset delta) => _set(_frame.panBy(delta));

  void _set(CropFrame f) {
    _frame = f;
    notifyListeners();
  }
}

/// A square window on the photo with the round avatar marked out: drag to move
/// it, pinch (or scroll the mouse wheel) to zoom.
class AvatarCropper extends StatefulWidget {
  const AvatarCropper({super.key, required this.controller});

  final AvatarCropController controller;

  @override
  State<AvatarCropper> createState() => _AvatarCropperState();
}

class _AvatarCropperState extends State<AvatarCropper> {
  double _startZoom = 1;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return LayoutBuilder(builder: (context, box) {
      final side = box.maxWidth;
      Offset units(Offset px) => px / side;
      Offset fromCenter(Offset local) => units(local - Offset(side / 2, side / 2));

      return SizedBox.square(
        dimension: side,
        child: Listener(
          onPointerSignal: (e) {
            if (e is PointerScrollEvent) {
              final factor = e.scrollDelta.dy > 0 ? 1 / 1.1 : 1.1;
              c.zoomTo(c.zoom * factor, focal: fromCenter(e.localPosition));
            }
          },
          child: GestureDetector(
            onScaleStart: (_) => _startZoom = c.zoom,
            onScaleUpdate: (d) {
              c.panBy(units(d.focalPointDelta));
              if (d.scale != 1) {
                c.zoomTo(_startZoom * d.scale, focal: fromCenter(d.localFocalPoint));
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: ListenableBuilder(
                listenable: c,
                builder: (context, _) => CustomPaint(
                  size: Size.square(side),
                  painter: _CropPainter(c.image, c.frame.sourceRect),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter(this.image, this.source);

  final ui.Image image;
  final Rect source;

  @override
  void paint(Canvas canvas, Size size) {
    final all = Offset.zero & size;
    canvas.drawImageRect(image, source, all, Paint()..filterQuality = FilterQuality.medium);

    // Dim what the round avatar won't show, and ring what it will.
    final circle = Rect.fromCircle(center: all.center, radius: size.width / 2 - 6);
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(all)
        ..addOval(circle),
      Paint()..color = const Color(0x8C181430),
    );
    canvas.drawOval(
      circle,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_CropPainter old) => old.image != image || old.source != source;
}

/// Draws [source] of [image] into a [size]×[size] PNG on white — what the
/// avatar upload sends. The server re-encodes it as a JPEG.
Future<Uint8List> renderCrop(ui.Image image, Rect source, {int size = 512}) async {
  final rec = ui.PictureRecorder();
  final dst = Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());
  Canvas(rec)
    ..drawRect(dst, Paint()..color = Colors.white)
    ..drawImageRect(image, source, dst, Paint()..filterQuality = FilterQuality.high);
  final out = await rec.endRecording().toImage(size, size);
  final data = await out.toByteData(format: ui.ImageByteFormat.png);
  out.dispose();
  return data!.buffer.asUint8List();
}

/// Decodes a picked photo for cropping.
Future<ui.Image> decodeForCrop(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}
