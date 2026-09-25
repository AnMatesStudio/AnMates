# T22 — Home: the two horizontal venue rows size from width + text scale

> **Phase D — do NOT run in Phase B.** Run only if the Phase C screenshots show the problem this task fixes
> (see README §6). §1.1 measured no overflow without it; this is visual polish.

**Executor:** Hermes (local) · **Depends on:** T21 · **Blocks:** T23
**Working dir:** `C:\AnM\AnMatesStudio\AnMates\anmates_flutter`
**File to edit (ONLY this file):** `lib/views/v2/screens/home_screen.dart`

## Why

The rows are fixed-height boxes (`198`, `194`) that hold fixed-width cards (`132`, `138`) with text inside.
Once `meta` grows to 11.5pt (T10), or the user raises their text size, the text no longer fits and is clipped.

## Edits

1. In `HomeScreen.build`, find:
   ```dart
                 SizedBox(
                   height: 198,
   ```
   Replace it with:
   ```dart
                 SizedBox(
                   // Tile art scales with width; the two text lines under it do not.
                   height: 120 * V2Layout.unit(context) + 80 + V2Layout.textGrowth(context, 48),
   ```

2. In `HomeScreen.build`, find:
   ```dart
                 SizedBox(
                   height: 194,
   ```
   Replace it with:
   ```dart
                 SizedBox(
                   height: 172 * V2Layout.unit(context) + 22 + V2Layout.textGrowth(context, 48),
   ```

3. In `_TileRow.build`, directly after the line `  Widget build(BuildContext context) {`, insert:
   ```dart
       final u = V2Layout.unit(context);
   ```
   then find:
   ```dart
             width: 132,
   ```
   Replace it with:
   ```dart
             width: 132 * u,
   ```
   and find (it is inside `_TileRow`, just below the previous one):
   ```dart
                   height: 120,
   ```
   Replace it with:
   ```dart
                   height: 120 * u,
   ```

4. In `_CardRow.build`, directly after the line `  Widget build(BuildContext context) {`, insert:
   ```dart
       final u = V2Layout.unit(context);
       final grow = V2Layout.textGrowth(context, 48);
   ```
   then find:
   ```dart
             width: 138, height: 172,
   ```
   Replace it with:
   ```dart
             width: 138 * u, height: 172 * u + grow,
   ```
   and find:
   ```dart
                 left: 0, right: 0, top: 14, height: 84,
   ```
   Replace it with:
   ```dart
                 left: 0, right: 0, top: 14 * u, height: 84 * u,
   ```

## Self-check (run it and paste the real output)

```powershell
C:\src\flutter\bin\flutter.bat analyze lib/views/v2/screens/home_screen.dart
```

## Caller verification

- `git diff --stat`: 1 file.
- Matrix `home @` with no layout failures at any viewport, **including `@1.3`**.
- Because the feed is empty in tests (no network), seed 3 venues in a throwaway test, or check the
  screenshot grid against a running API. The tile titles must not be cut off at `iphone15-safari@1.3`.
