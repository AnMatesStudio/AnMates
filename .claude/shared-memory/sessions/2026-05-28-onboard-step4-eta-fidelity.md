# 2026-05-28 — Onboard Step 4 "Định vị nền" visual fidelity pass (NEW_ETA_Maps.png)

## TL;DR
User reported the local web UI for the ETA / location-permission screen did NOT match
`plan/screenshot/NEW_ETA_Maps.png`. Root finding: the running **WSL** dev server (port
54180, relayed to Windows via wslrelay/Docker) was serving a **stale build** — the browser
showed the OLD carousel slide, predating even the 2026-05-28 `_Step4Page` redesign. On top of
that, the committed `_Step4Page` code had several real fidelity gaps vs. the target design.
Refactored `_Step4Page` element-by-element to match. `flutter analyze` clean; web build
compiles + serves OK. **Visual confirmation by user still pending.**

## Files changed
- `anmates_flutter/lib/views/onboarding/onboarding_view.dart`

## Changes (to match NEW_ETA_Maps.png)
1. **Top bar** — back `←` and help `?` are now **white filled circles** (44×44, soft shadow)
   instead of a bare icon / bordered circle. Title sizes bumped (`QUYỀN AN TOÀN` 11px ls2.2,
   `Định vị nền` 17px).
2. **Heading + subtext centered** — content column `crossAxisAlignment` → center, both texts
   `textAlign: TextAlign.center`. Bold span widened to "45 phút trước giờ hẹn". Heading 29px w800.
   (Feature bullets keep left text because each is a Row with an `Expanded` child → full width.)
3. **Pin icon** rewrote `_GlowLocationPin` → bigger 96px pink-gradient rounded tile
   (`Color(0xFFE886AE)`→`berryDeep`, radius 28) with a new `_PushpinPainter` (glossy 3D red
   sphere + metallic needle) replacing the flat white `Icons.location_on_rounded`.
4. **Feature bullets** — `_LocationBullet` icon container square→**circle** (40px); all three
   unified to pink (`berry @10%` bg + `berry` icon). Icons: lock_outline / schedule / shield_outlined.
5. **ETA map card** rewrote `_EtaMapCard` → **full-width** (LayoutBuilder, endpoints as
   fractions of card size), taller (196px). Labels **moved INSIDE the dark card** (bottom, with a
   bottom scrim for legibility) via new `_CardLabel` (white value + faded white eyebrow).
   Destination dot replaced with new `_DestBubble` (glowing berry ring + `Icons.ramen_dining`).
   Removed now-unused `_RouteLabel` class.

## Verification
- `flutter analyze lib/views/onboarding/onboarding_view.dart` → **No issues found**.
- `flutter run -d web-server --web-port 8090` → compiled, "is being served at http://127.0.0.1:8090".
- Pixel-level comparison vs. design: NOT done by an automated screenshot (no Playwright in main
  session). **Pending user visual confirmation.**

## Key facts / gotchas
- **Flutter SDK on this Windows box:** `C:\src\flutter\bin\flutter.bat` (NOT on PATH; CLAUDE.md's
  `/opt/homebrew/bin/flutter` is the old macOS path).
- **Flutter project dir is `anmates_flutter/`** (CLAUDE.md still says `AnMatesApp/` — stale).
- **Dev server runs inside WSL**, port 54180 relayed to Windows by wslrelay + com.docker.backend.
  The main-session Bash tool is **Git Bash (MINGW64)**, NOT WSL — can't see/restart the WSL
  `flutter run` from here. To pick up these edits the user must **hot-RESTART** (press `R`, not `r`
  — changes are structural / new classes) in their WSL terminal, or use the parallel verification
  server at `http://127.0.0.1:8090`.
- Step 4 is the **last** onboarding page; its own top bar + CTA render and the PageView
  logo/dots/skip overlay is hidden on the last page.

## Open follow-ups
- User to visually confirm match. If confirmed → migrate to a resolution (Path A).
- Pushpin is CustomPainter-drawn (no asset). If design wants the exact 3D asset, swap later.
