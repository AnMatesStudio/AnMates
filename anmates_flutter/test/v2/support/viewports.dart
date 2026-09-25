/// One logical viewport the v2 screens must work in: the size Flutter actually
/// receives, the safe-area insets, and the user's text scale.
///
/// Browser rows (`*-safari`, `android-*`, `pixel`) are the area left once the
/// toolbar is expanded, so their insets are 0: a mobile browser reports no safe
/// area to Flutter. See docs/plans/2026-09-25-responsive-mobile/README.md §3.3.
class V2Viewport {
  const V2Viewport(
    this.id,
    this.width,
    this.height, {
    this.top = 0,
    this.bottom = 0,
    this.textScale = 1,
  });

  final String id;
  final double width, height, top, bottom, textScale;

  @override
  String toString() => '$id (${width.toInt()}×${height.toInt()}'
      '${textScale == 1 ? '' : ', text ×$textScale'})';
}

/// README §3.3: 14 viewports covering the edges and the largest user groups,
/// plus the three 1.3× text-scale variants.
const kV2Viewports = <V2Viewport>[
  V2Viewport('floor-320', 320, 568, top: 20),
  V2Viewport('fold-cover', 344, 882, top: 24, bottom: 16),
  V2Viewport('android-16x9', 360, 560),
  V2Viewport('android-hd', 360, 680),
  V2Viewport('se-safari', 375, 553),
  V2Viewport('se-app', 375, 667, top: 20),
  V2Viewport('iphone14-safari', 390, 664),
  V2Viewport('iphone15-safari', 393, 668),
  V2Viewport('iphone15-app', 393, 852, top: 59, bottom: 34),
  V2Viewport('design-frame', 402, 874, top: 62, bottom: 34),
  V2Viewport('pixel', 412, 800),
  V2Viewport('promax-safari', 430, 750),
  V2Viewport('widest', 440, 956, top: 62, bottom: 34),
  V2Viewport('landscape', 844, 390),
  V2Viewport('se-safari@1.3', 375, 553, textScale: 1.3),
  V2Viewport('iphone15-safari@1.3', 393, 668, textScale: 1.3),
  V2Viewport('widest@1.3', 440, 956, top: 62, bottom: 34, textScale: 1.3),
];
