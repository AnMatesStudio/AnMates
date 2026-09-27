import 'dart:ui' as ui;

import 'package:anmates/widgets/v2/avatar_cropper.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// The avatar crop: a square viewport over the photo, the photo always covering
/// it. [CropFrame] is the math; [renderCrop] draws the chosen square.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 2000×1000 photo in a 300 pt viewport: "cover" scale 0.3.
  CropFrame landscape() => CropFrame(imageSize: const Size(2000, 1000), viewport: 300);

  void expectRect(Rect got, Rect want) {
    for (final (g, w) in [(got.left, want.left), (got.top, want.top), (got.width, want.width), (got.height, want.height)]) {
      expect(g, closeTo(w, 0.01), reason: 'got $got, want $want');
    }
  }

  group('CropFrame', () {
    test('starts centered, covering the viewport with the short side', () {
      expectRect(landscape().sourceRect, const Rect.fromLTWH(500, 0, 1000, 1000));
      expectRect(CropFrame(imageSize: const Size(800, 1200), viewport: 300).sourceRect,
          const Rect.fromLTWH(0, 200, 800, 800));
    });

    test('dragging moves the photo, never past its edge', () {
      final f = landscape().panBy(const Offset(100, 0)); // photo right → see more of its left
      expectRect(f.sourceRect, Rect.fromLTWH(500 - 100 / 0.3, 0, 1000, 1000));

      expectRect(f.panBy(const Offset(5000, 5000)).sourceRect, const Rect.fromLTWH(0, 0, 1000, 1000));
      expectRect(f.panBy(const Offset(-9000, 0)).sourceRect, const Rect.fromLTWH(1000, 0, 1000, 1000));
    });

    test('zooming keeps the viewport center on the same spot of the photo', () {
      expectRect(landscape().zoomTo(2).sourceRect, const Rect.fromLTWH(750, 250, 500, 500));

      final edge = landscape().panBy(const Offset(5000, 0)).zoomTo(2);
      expectRect(edge.sourceRect, const Rect.fromLTWH(250, 250, 500, 500));
    });

    test('zooming around a finger keeps that point under it', () {
      // Photo x under the viewport's right edge (focal +150): 1000 + 150 / 0.3 = 1500.
      final f = landscape().zoomTo(2, focal: const Offset(150, 0));
      final xUnderFocal = f.sourceRect.center.dx + 150 / f.scale;
      expect(xUnderFocal, closeTo(1500, 0.01));
    });

    test('zooming back out pulls the photo back over the viewport', () {
      final f = landscape().zoomTo(2).panBy(const Offset(5000, 5000)).zoomTo(1);
      expectRect(f.sourceRect, const Rect.fromLTWH(0, 0, 1000, 1000));
    });

    test('zoom stays within 1×–4×', () {
      expect(landscape().zoomTo(0.2).zoom, 1);
      expect(landscape().zoomTo(10).zoom, CropFrame.maxZoom);
    });

    test('a new viewport size keeps the same part of the photo', () {
      final f = landscape().zoomTo(2).panBy(const Offset(60, 30));
      final g = f.withViewport(450);
      expectRect(g.sourceRect, f.sourceRect);
    });
  });

  test('renderCrop draws the chosen square at the output size', () async {
    // Left half red, right half blue.
    final rec = ui.PictureRecorder();
    Canvas(rec)
      ..drawRect(const Rect.fromLTWH(0, 0, 100, 100), Paint()..color = const Color(0xFFFF0000))
      ..drawRect(const Rect.fromLTWH(100, 0, 100, 100), Paint()..color = const Color(0xFF0000FF));
    final image = await rec.endRecording().toImage(200, 100);

    Future<Color> centerOf(Rect src) async {
      final png = await renderCrop(image, src, size: 64);
      final decoded = await (await ui.instantiateImageCodec(png)).getNextFrame();
      expect(decoded.image.width, 64);
      expect(decoded.image.height, 64);
      final px = (await decoded.image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      final i = (32 * 64 + 32) * 4;
      return Color.fromARGB(255, px.getUint8(i), px.getUint8(i + 1), px.getUint8(i + 2));
    }

    expect(await centerOf(const Rect.fromLTWH(0, 0, 100, 100)), const Color(0xFFFF0000));
    expect(await centerOf(const Rect.fromLTWH(100, 0, 100, 100)), const Color(0xFF0000FF));
  });
}
