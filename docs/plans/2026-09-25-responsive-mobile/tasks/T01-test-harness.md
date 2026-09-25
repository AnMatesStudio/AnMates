# T01 — Viewport matrix + responsive matrix test

**Executor:** Claude sub agent · **Depends on:** T03 (scaling removed) · **Blocks:** every Phase 1–2 task
**Working dir:** `C:\AnM\AnMatesStudio\AnMates\anmates_flutter` · Flutter: `C:\src\flutter\bin\flutter.bat`

## Goal

A test file that shows, per screen and per viewport, exactly what is still broken. When this task is
done the test is expected to be **red**: its failures are the Phase 1–2 to-do list. Each later task
turns its own screen green.

## Files to create

### `test/v2/support/viewports.dart`

```dart
class V2Viewport {
  const V2Viewport(this.id, this.width, this.height, {this.top = 0, this.bottom = 0, this.textScale = 1});
  final String id; final double width, height, top, bottom, textScale;
}
```

Include the 14 viewports from README §3.3, using the ids, sizes and safe insets listed there, plus three
entries with `textScale: 1.3`: `se-safari@1.3`, `iphone15-safari@1.3` and `widest@1.3`. Export
`const kV2Viewports = <V2Viewport>[...]`.

### `test/v2/responsive_matrix_test.dart`

For every `V2Screen` value (including `allVenues`), plus two overlay pseudo-screens `search` (home + `setSearchOpen(true)`) and
`notifs` (home + `setNotifsOpen(true)`), and onboarding split per step as `onb0`…`onb4`, × every viewport:
one `group('<name> @ <viewport.id>')`
(the `@` naming is what later tasks filter on with `--plain-name "home @"`) with these tests:

1. **`layout`** — pump the app and `expect(tester.takeException(), isNull)`.
2. **`min font`** — walk every `RenderParagraph` whose global paint rect intersects the screen. Effective size =
   `style.fontSize × textScaler.scale(1) × getTransformTo(null).getMaxScaleOnAxis()`. Require ≥ 11.0 (0.05 tolerance).
   **Exempt:** text made only of emoji or symbols such as `★ ‹ › ✕`, and any paragraph ≥ 40pt (hero numbers). The failure
   message lists the offending strings with their sizes, so the executor sees what to fix.
3. **`tap targets`** — call `final sem = tester.ensureSemantics();` before pumping (without it both guidelines
   pass vacuously; this was measured) and dispose it at the end. Then
   `await expectLater(tester, meetsGuideline(androidTapTargetGuideline));` (48dp, which also covers iOS 44pt).
4. **`pinned actions`** — only for screens and steps with actions pinned to the bottom, check that the widget is
   fully inside `Rect.fromLTWH(0, 0, width, height)`:
   - onboarding steps 3 and 4: `'Tiếp tục'` and `'Vào Ăn Mates'` (reuse `pumpAt(step:)` from `onboarding_small_screen_test.dart`)
   - swipe (when candidates are seeded): `'Gửi lời mời đi ăn'`
   - chat: the composer's text field

Pump helper, same pattern as `onboarding_small_screen_test.dart`:

```dart
tester.view.physicalSize = Size(v.width, v.height);
tester.view.devicePixelRatio = 1;
tester.view.padding = FakeViewPadding(top: v.top, bottom: v.bottom);
tester.platformDispatcher.textScaleFactorTestValue = v.textScale;
addTearDown(tester.view.reset); addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
await tester.pumpWidget(MaterialApp(home: ChangeNotifierProvider<V2State>.value(
  value: state, child: const V2AppBody())));
await tester.pump(const Duration(milliseconds: 300));
```

Do not call `loadVenues()` / `loadCandidates()` (no network in tests). **Seed data instead:** 6 venues
(names of 12–40 characters, some with a `photoUrl` of null so the art fallback renders) and 3 mate candidates,
through `@visibleForTesting` setters. An empty feed hides the card rows, and §1.1 of the README only measured that empty state.

If `V2State` has no seeding hook, add `@visibleForTesting` setters in `v2_state.dart`. That is the only `lib/` edit allowed in this task.

## Verify (paste real output)

```powershell
C:\src\flutter\bin\flutter.bat analyze test/v2
C:\src\flutter\bin\flutter.bat test test/v2/responsive_matrix_test.dart --reporter expanded 2>&1 | Select-String "\+\d+.*-\d+:|All tests"
C:\src\flutter\bin\flutter.bat test test/v2/onboarding_small_screen_test.dart test/v2/v2_render_test.dart   # must stay 7/7 green
```

**Prove the checks can fail.** Before T10/T23 land, `min font` must go red for `home @ iphone15-safari`
(the 9.5pt greeting), and `tap targets` must go red on every screen for the VI/EN chips (~25pt tall).
If either is green at this point, the check is broken.

Report: a pass/fail count per screen, as a 12 × 17 table (screens × viewports) or a summary of it. That table
is the baseline for Phase 1–2.
