# T21 — Home: hero collage scales with width, compresses on short screens

> **Phase D — do NOT run in Phase B.** Run only if the Phase C screenshots show the problem this task fixes
> (see README §6). §1.1 measured no overflow without it; this is visual polish.

**Executor:** Hermes (local) · **Depends on:** T20 · **Blocks:** T22
**Working dir:** `C:\AnM\AnMatesStudio\AnMates\anmates_flutter`
**File to edit (ONLY this file):** `lib/views/v2/screens/home_screen.dart`

## Why

`_Hero` is a fixed 272pt `Stack` with four food renders at fixed positions. On a 320–360pt phone the
coffee cup slides under the "mates đang thèm ăn tối nay" line. In a mobile browser (under 700pt tall),
272pt of hero pushes the CTA below the fold.

## Edit

Replace the **whole** `build` method of `class _Hero` (from its `@override` to the closing `}` of the method;
keep `const _Hero({required this.s});` and `final V2State s;`) with:

```dart
  @override
  Widget build(BuildContext context) {
    // Art scales with the screen width; the text in the middle never does. On a
    // short screen (a phone browser with its toolbars) the collage tightens
    // vertically so the CTA stays near the fold.
    final u = V2Layout.unit(context);
    final short = V2Layout.isShort(context);
    final narrow = V2Layout.width(context) < 390;

    return SizedBox(
      height: (short ? 232.0 : 272.0) * u + V2Layout.textGrowth(context, 40),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 6 * u, left: -14 * u, width: 126 * u, height: 126 * u,
            child: const FloatingArt(
              period: Duration(milliseconds: 6000),
              child: FoodArt(asset: A.burger),
            ),
          ),
          Positioned(
            top: 0, right: -10 * u, width: 142 * u, height: 130 * u,
            child: const FloatingArt(
              period: Duration(milliseconds: 6600),
              delay: Duration(milliseconds: 500),
              child: FoodArt(asset: A.ramen),
            ),
          ),
          Positioned(
            bottom: 2 * u, right: 8 * u, width: 84 * u, height: 96 * u,
            child: const FloatingArt(
              period: Duration(milliseconds: 7200),
              delay: Duration(milliseconds: 1000),
              child: FoodArt(asset: A.beer, shadowBlur: 16),
            ),
          ),
          Positioned(
            // Pushed half off the edge on narrow phones so it clears the caption.
            bottom: 10 * u, left: (narrow ? -14.0 : 10.0) * u, width: 98 * u, height: 90 * u,
            child: const FloatingArt(
              period: Duration(milliseconds: 6200),
              delay: Duration(milliseconds: 800),
              child: FoodArt(asset: A.coffee, shadowBlur: 16),
            ),
          ),
          Positioned(
            top: (short ? 62.0 : 82.0) * u, left: 0, right: 0,
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
```

The three `Text` widgets and the `ShaderMask` are copied unchanged from the current code. Check that
they match before you replace anything. If the current `_Hero` differs from what this spec assumes
(for example a fifth art piece or different text), stop and report the difference without editing.

## Self-check (run it and paste the real output)

```powershell
C:\src\flutter\bin\flutter.bat analyze lib/views/v2/screens/home_screen.dart
```

## Caller verification

- `git diff --stat`: 1 file.
- `flutter test test/v2/responsive_matrix_test.dart --plain-name "home @"`: no layout failures.
- Screenshot grid, `home` row: at `design-frame` the hero looks like the design. At `floor-320` and
  `android-hd`, the coffee cup does not cover the caption. At `iphone15-safari`, the CTA "Gom kèo tối nay"
  is visible without scrolling.
