# T03 — Remove the height scaling; centered 480 column on wide screens

**Executor:** Claude sub agent · **Depends on:** T02 · **Blocks:** T01 and all of Phase B
**Files:** `lib/widgets/v2/design_frame.dart`, `lib/views/v2/v2_data.dart`, `test/v2/onboarding_small_screen_test.dart`
**Skills to load:** `flutter-build-responsive-layout`, `flutter-fix-layout-issues`

## Why

README §1: shrinking the whole 402 × 874 frame by `height / 874` makes every phone browser render text and
controls 16–37 % smaller. README §1.1: with the scale forced to 1, all 12 screens plus 5 onboarding steps lay out
without overflow at 320×568 … 440×956. There is no reason to keep it. No transitional flag: work directly
(the user asked to push to `main`), and Phase C verifies before the push.

## Changes

1. `DesignFrame.build`: delete the scaling path entirely (`k`, `FittedBox`, the `MediaQuery` rewrite by `/ k`).
   New behaviour:
   - `constraints.maxWidth <= V2Layout.maxContentWidth` → return `child` unchanged.
   - Wider → `Center(child: SizedBox(width: V2Layout.maxContentWidth, child: MediaQuery(data: media.copyWith(size:
     Size(V2Layout.maxContentWidth, media.size.height)), child: child)))`. Rewriting `size` keeps every
     `MediaQuery.sizeOf` call inside the column (for example the chat bubble's `width * 0.74`) consistent with the
     column instead of the window. The skill `flutter-build-responsive-layout` covers why.
   - Rewrite the class doc comment. Explain the rule: text never scales, vertical overflow scrolls, and wide windows
     get a 480 column. Explain why height scaling was removed, citing the numbers in README §1 and §1.1.
     Keep the class name so `v2_app.dart` needs no change.
2. `v2_data.dart`: delete `kDesignFrameHeight` and its comment, after `git grep kDesignFrameHeight` confirms that only the
   frame and the test use it.
3. `onboarding_small_screen_test.dart`: delete the `design frame` group's two scaling tests
   (`scales the whole frame down…`, `leaves a screen at least as tall…`). Keep `every screen lays out at iPhone SE size`
   and the whole `onboarding` group. They must still pass without the scale; §1.1 says they will.

## Verify (paste real output)

```powershell
C:\src\flutter\bin\flutter.bat analyze lib test
C:\src\flutter\bin\flutter.bat test
git grep -n "kDesignFrameHeight" -- anmates_flutter     # must print nothing
```

Then add a throwaway widget test at 393×668 that checks the `'Khám phá'` nav label's rendered height is 13.0
(unscaled; it was ~9.9 with the scale). Run it, then delete it.
