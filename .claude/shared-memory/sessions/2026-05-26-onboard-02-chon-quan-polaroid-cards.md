# Session — Onboard Screen 02 "Chọn quán" polaroid cards + food illustrations

**Date:** 2026-05-26 → 2026-05-27 (multi-iteration)
**Owner:** main-assistant
**Status:** Implemented — final visual confirmation pending. Real cartoon assets in place. Cropping from `food_card.png` (polaroid mockup) was started then user interrupted.

## TL;DR

Refactored Onboarding Step 1 (screen 02 "Chọn quán") to match the reference at `plan/screenshot/02_Onboard_Chon_quan.png`. Final state: polaroid cards with hand-drawn cartoon food illustrations (Lẩu / Cafe chill / Đồ nướng / ăn vặt), tightly-packed stacked layout, full animations (entry stagger + ambient float + hover lift + press feedback), responsive scaling for small iPhones, swipe-enabled `PageView` across all input devices.

## Final state — what ships

- 4 PNG assets in `anmates_flutter/assets/food/` (553×353 each, cropped from `plan/screenshot/food_reference.png`): `lau.png`, `cafe.png`, `nuong.png`, `vat.png`
- `pubspec.yaml` declares `assets: - assets/food/`
- Polaroid card design: white frame + shadow, `Image.asset(...)` photo area (`BoxFit.cover`), bottom caption with `Be Vietnam Pro` bold
- Stage: `FittedBox(BoxFit.contain)` wrapper with intrinsic 300×340 so it scales to fit any screen
- Cards positioned tightly: top row `top:0/6`, bottom row `top:170/162` (overlapping like a polaroid stack while keeping all captions visible)
- Animations on the card frame:
  - **Entry stagger** — 0/90/180/270 ms delays per card, `Curves.elasticOut` scale (0.72→1.0) + `Curves.easeOutCubic` slide-up (36→0) + fade
  - **Ambient float** — ±4px out-of-sync per card, starts after entry settles
  - **Hover** — scale 1.08, accent-color glow, rotation snaps toward upright (×0.35 of base angle), image scales additional 1.08
  - **Press** — scale 0.94 with quick bounce-back
- Animated `Sparkle` decoration top-right of the stage
- `ScrollConfiguration` wraps `PageView` enabling drag for `touch + mouse + trackpad + stylus` (Flutter web disables mouse drag by default); `BouncingScrollPhysics` for tactile edge feel

## Files changed

### `anmates_flutter/lib/views/onboarding/onboarding_view.dart`

- Added `import 'package:flutter/gestures.dart' show PointerDeviceKind;`
- Updated body copy to match screenshot: "Khám phá theo Genre & Vibe — lẩu sùng sục, cafe khuất hẻm, quán nướng xì xèo... Bookmark vào Wishlist để tính sau."
- Rewrote `_Step1Page` / `_Step1Illustration`
- Introduced `_FoodKind` enum + `_CardSpec` data class
- Rewrote `_FoodCard` / `_FoodCardState` (`TickerProviderStateMixin`) with full animation stack
- Added `_assetFor(_FoodKind)` helper mapping to asset paths
- Wrapped `PageView` in `ScrollConfiguration` with `dragDevices: {touch, mouse, trackpad, stylus}`
- Made `_StepLayout` responsive via `MediaQuery` — "compact" mode triggers when width ≤ 380pt or height ≤ 700pt (covers iPhone SE / 12 mini / 11/12/13/14):
  - Illustration top pad `88 → 56`, bottom pad `120 → 100`
  - Title `32 → 28`, body `15 → 14`
  - Horizontal pad `28 → 22`
- Migrated all in-file `withOpacity` → `withValues(alpha:)` (per velocity rule)
- **Deleted ~400 lines of dead code** after switching to assets: `_DiagonalStripesPainter`, `_FoodIllustration`, `_LauPainter`, `_CafePainter`, `_NuongPainter`, `_VatPainter`, `_shade`, `dart:math` import

### `anmates_flutter/pubspec.yaml`
- Added `assets: - assets/food/` under `flutter:` section

### New files
- `anmates_flutter/assets/food/lau.png` (284 KB)
- `anmates_flutter/assets/food/cafe.png` (216 KB)
- `anmates_flutter/assets/food/nuong.png` (310 KB)
- `anmates_flutter/assets/food/vat.png` (257 KB)
- `scripts/crop_food_reference.py` — re-runnable; crops a 2×2 reference into 4 individual food illustrations (drops bottom label band 22%, inner pad 3%, center-crops 72% width to focus on food)
- `plan/screenshot/food_reference.png` — user-saved 4-up cartoon reference (1.4 MB)
- `plan/screenshot/food_card.png` — user-saved polaroid mockup (924 KB; cropping deferred — see Open follow-ups)

## Iteration history

### Iter 0 — Initial implementation
- Polaroid cards with `_DiagonalStripesPainter` background + `GoogleFonts.caveat` cursive label + CustomPainter food (hotpot/coffee/grill/snack bowl) + bottom caption

### Iter 1 — Top-row captions covered by bottom row
- Cause: cards at `top:8/0` (top row) and `top:138/130` (bottom row) — only 8px gap, insufficient with ±8/10° rotation
- Fix: bumped bottom row to `top:188/180`, stage `300 → 360`
- Also added `ScrollConfiguration` for cross-device swipe

### Iter 2 — File reverted between turns
- Discovery: my changes from Iter 1 were not on disk when user shared next screenshot. Cause unknown (likely IDE/git auto-revert)
- Fix: re-applied Iter 1 edits + further bumped bottom row to `top:220/212`, stage `360 → 390` for safety margin

### Iter 3 — Cards too spread apart vs reference
- User shared image showing cards tightly stacked (polaroid pile look)
- Fix: pulled bottom row back to `top:170/162` (overlapping with rotation-extended top-row bounds — intentional stack effect), stage `390 → 340`
- Added `FittedBox(BoxFit.contain)` wrapper + `MediaQuery`-driven compact-device sizing in `_StepLayout`

### Iter 4 — User wants real cartoon illustrations
- User saved cartoon reference at `plan/screenshot/food_reference.png`
- Wrote `scripts/crop_food_reference.py` (Pillow); auto-installed Pillow first
- 1st crop pass: 769×353 each (too wide for square card slot)
- 2nd crop pass: added 72% center-width crop → 553×353
- Wired pubspec + swapped `CustomPainter` body for `Image.asset(BoxFit.cover)` in `_FoodCard`
- Deleted all dead CustomPainter classes + `dart:math` import
- `flutter pub get` ✅, `flutter analyze` ✅ clean

### Iter 5 (in-progress, INTERRUPTED)
- User saved `plan/screenshot/food_card.png` — a polaroid mockup screenshot (1024×1536)
- User asked to crop 4 squares from it and **replace** assets/food/
- I generated first-guess crops at approximate coords:
  - `lau`: (90, 220) → (470, 540)
  - `cafe`: (480, 235) → (870, 575)
  - `nuong`: (110, 580) → (480, 920)
  - `vat`: (500, 600) → (880, 950)
- Saved temp preview crops to `plan/screenshot/_guess_*.png` (since deleted) — they showed each card still had **polaroid frame + cursive label + bottom caption baked in**, which would double-frame against my Flutter card chrome
- **User interrupted before resolution**. Two interpretations remain ambiguous:
  - (a) Extract just the FOOD ART INSIDE each polaroid (matches current asset shape, replaces with screen-rendered versions)
  - (b) Extract the WHOLE POLAROID (with frame + labels baked in) and refactor `_FoodCard` to drop its Container chrome and show only the asset
- **Decision needed from user** before proceeding (see Open follow-ups)

## Verification

- `flutter analyze lib/views/onboarding/onboarding_view.dart` → **No issues found** (after each iteration)
- `flutter pub get` → succeeded after pubspec assets entry
- Full project analyze: 108 pre-existing `withOpacity` info warnings in OTHER files (out of scope)
- **Visual confirmation in browser:** pending

## Design decisions

- **Real cartoon assets over CustomPainter** — once user provided AI-generated illustrations, dropping ~400 lines of CustomPainter code was a net win. Painters were already an acknowledged compromise; real art matches brand intent.
- **`FittedBox(BoxFit.contain)`** for the stage — simplest responsive primitive that preserves intrinsic proportions on any screen without bespoke breakpoint logic.
- **Compact-device sizing in `_StepLayout`** — only two tiers (default vs compact at ≤380pt or ≤700pt). Avoids per-device hacks; captures iPhone SE through iPhone 14 transition naturally.
- **Swipe via `ScrollConfiguration` not custom `GestureDetector`** — adding all 4 `PointerDeviceKind` values to `dragDevices` is the canonical Flutter pattern. Avoids reinventing inertia/snap.
- **Tightly stacked cards (not grid)** — the brand reference shows polaroid pile, not Pinterest grid. Top row at `0/6`, bottom row at `170/162` overlaps slightly due to rotation — that overlap IS the design.

## Out of scope (left as-is this session)

- Steps 2 (Match) & 3 (Vibe/Hotpot) illustrations — no screenshot provided
- Top bar pin/X logo — currently `LogoMark(size: 32)`; screenshot shows a pin-shaped logo with X marker
- Bottom page dots — current widening-pill style (active = 24×8) vs screenshot's equal dots; kept as-is

## Open follow-ups

- **Decision needed** on `food_card.png` cropping intent (see Iter 5 above) before completing the asset swap
- User to visually verify the final result in browser (`http://127.0.0.1:54180`, hard refresh)
- Steps 2/3 may benefit from real illustration assets too — similar workflow can be re-used (`scripts/crop_*.py`)
- The repeated mid-session revert (Iter 2) is unresolved — if it recurs, investigate IDE source-control behavior or `.gitignore` interactions

## Key facts

- Card dimensions: `122 × 156` (white frame, 8px padding all sides)
- Stage intrinsic: `300 × 340`, rendered via `FittedBox(BoxFit.contain)`
- Card positions (top/left within stage):
  - LẨU: `0 / 14`, angle `-8°`
  - CAFE CHILL: `6 / 148`, angle `+6°`
  - ĐỒ NƯỚNG: `170 / 24`, angle `-4°`
  - ĂN VẶT: `162 / 158`, angle `+10°`
- Asset format: PNG, ~250-310 KB each, 553×353 (will be center-cropped to ~square by `BoxFit.cover`)
- Re-cropping: `python scripts/crop_food_reference.py` (reads `plan/screenshot/food_reference.png`)
