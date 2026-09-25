# T05 — Screenshot grid: 12 screens × 14 viewports

**Executor:** Claude sub agent · **Depends on:** T04 · **Used by:** T91, and before/after every Phase 2 task
**File:** `scripts/responsive-shots.mjs` (repo root `AnMates/scripts/`, next to `run-flutter.mjs`)

## Behaviour

```
node scripts/responsive-shots.mjs [--build] [--screens home,swipe] [--viewports se-safari,iphone15-safari] [--out screenshots/responsive/<label>]
```

1. `--build`: `flutter build web --release --dart-define=V2_DEBUG_NAV=true` in `anmates_flutter/`.
   Resolve Flutter the way `run-flutter.mjs` does (`C:\src\flutter\bin\flutter.bat` is on this machine).
2. Serve `anmates_flutter/build/web` on a free port with a small `node:http` static server. Do not
   add dependencies.
3. Playwright: use the global install (`C:\Users\Admin\AppData\Roaming\npm\node_modules\playwright`,
   1.60, as used in `C:\AnM\_hermes_pw_test`). **WebKit** for the iPhone viewports, **Chromium** for Android
   and landscape. Use the viewports and ids from README §3.3, `isMobile: true`, `hasTouch: true`,
   `deviceScaleFactor: 2`, and the text-scale variants skipped.
4. For each screen, open `/?v2screen=<name>` (onboarding: `v2screen=onb&v2step=0..4`, 5 shots). Wait for
   `flt-glass-pane` or `flutter-view`, then wait another 1500 ms for fonts and animations, then take the screenshot.
5. Write `<out>/<viewport>/<screen>.png` and a `<out>/index.html` contact sheet: one row per screen,
   one column per viewport, each image at 1/3 size, labelled.

## Verify (look at the output, don't just count files)

- Run it against **current `main`**, before any Phase 1 change: `--out screenshots/responsive/baseline`.
  The `iphone15-safari/home.png` must show the same problems as the user's screenshot (tiny text,
  empty band at the top). If it looks correct, the harness is wrong and does not reproduce the bug. Stop and investigate.
- Open `index.html` and read the images. Report any screen that failed to load (blank or onboarding
  instead of the target screen).
- Commit the script, **not** the PNGs (check `.gitignore` covers `screenshots/responsive/`, add it if not).
