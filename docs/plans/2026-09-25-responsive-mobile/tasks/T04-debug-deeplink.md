# T04 — Debug-only deep link `?v2screen=<name>&v2step=<n>`

**Executor:** Hermes (local) · **Depends on:** — · **Blocks:** T05
**Working dir:** `C:\AnM\AnMatesStudio\AnMates\anmates_flutter`
**File to edit (ONLY this file):** `lib/views/v2/v2_state.dart`

## Why

The screenshot script (T05) must open each screen directly in a browser. The app has no URL routing:
the current screen is the field `_screen` in `V2State`.

## Edits

1. Find this line (near line 29):
   ```dart
     V2Screen _screen = V2Screen.onb;
   ```
   Replace it with:
   ```dart
     V2Screen _screen = _initialScreen();
   ```

2. Find this line (near line 31):
   ```dart
     int _step = 0;
   ```
   Replace it with:
   ```dart
     int _step = _initialStep();
   ```

3. Directly below the `int _step = _initialStep();` line, insert:
   ```dart

     /// Debug-only deep link for layout screenshots: `?v2screen=home&v2step=2`.
     /// Compiled in only with `--dart-define=V2_DEBUG_NAV=true`; every other build
     /// starts on onboarding exactly as before.
     static const _debugNav = bool.fromEnvironment('V2_DEBUG_NAV');

     static V2Screen _initialScreen() {
       if (!_debugNav) return V2Screen.onb;
       final name = Uri.base.queryParameters['v2screen'];
       return V2Screen.values.firstWhere((s) => s.name == name, orElse: () => V2Screen.onb);
     }

     static int _initialStep() {
       if (!_debugNav) return 0;
       return (int.tryParse(Uri.base.queryParameters['v2step'] ?? '') ?? 0).clamp(0, 4);
     }
   ```

## Do not

- Edit any other line or any other file. Do not reformat the file.

## Self-check (run it and paste the real output)

```powershell
C:\src\flutter\bin\flutter.bat analyze lib/views/v2/v2_state.dart
```

## Caller verification

- `git diff --stat` shows exactly 1 file.
- `flutter test test/v2` is still green: without the define, behaviour is unchanged.
- `flutter build web --dart-define=V2_DEBUG_NAV=true`, serve `build/web`, open `/?v2screen=home` and
  confirm that the home screen shows, not onboarding. Open `/` and confirm onboarding.
