# T23 — Home: last sub-11pt text, equal stat cards, 48pt "See all"

**Executor:** Hermes (local) · **Depends on:** T20 (and T10) · **Blocks:** —
**Working dir:** `C:\AnM\AnMatesStudio\AnMates\anmates_flutter`
**File to edit (ONLY this file):** `lib/views/v2/screens/home_screen.dart`

## Edits

1. In `_ProfilePill.build`, find:
   ```dart
                     style: AppTextV2.meta(color: AppColorsV2.inkA(0.42)).copyWith(fontSize: 9.5),
   ```
   Replace it with:
   ```dart
                     style: AppTextV2.meta(color: AppColorsV2.inkA(0.42)).copyWith(fontSize: 11),
   ```

2. In `_TileRow.build`, find:
   ```dart
                         child: Text('★ ${v.rating}', style: AppTextV2.name(size: 9)),
   ```
   Replace it with:
   ```dart
                         child: Text('★ ${v.rating}', style: AppTextV2.name(size: 11)),
   ```

3. In `HomeScreen.build`, the two stat cards sit in a `Row`. Their labels wrap differently, which gives
   the cards different heights. Find:
   ```dart
                       const SizedBox(height: 12),
                       Row(children: [
   ```
   Replace it with:
   ```dart
                       const SizedBox(height: 12),
                       // Same height whichever label wraps to two lines.
                       IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
   ```
   and close it: the same `Row` currently ends with
   ```dart
                       )),
                     ]),
                   ]),
                 ),
   ```
   where the first `)),` closes the second `_StatCard`. Change the `]),` directly after it to `])),`:
   ```dart
                       )),
                     ])),
                   ]),
                 ),
   ```

4. In `HomeScreen.build`, find the "See all" link:
   ```dart
                       GestureDetector(
                         onTap: s.openAllVenues,
                         child: Text(
                           s.t('Xem tất cả', 'See all'),
                           style: AppTextV2.name(color: AppColorsV2.wisteria, size: 11.5),
                         ),
                       ),
   ```
   Replace it with:
   ```dart
                       GestureDetector(
                         onTap: s.openAllVenues,
                         behavior: HitTestBehavior.opaque,
                         child: ConstrainedBox(
                           constraints: const BoxConstraints(
                             minWidth: V2Layout.minTap, minHeight: V2Layout.minTap,
                           ),
                           child: Align(
                             alignment: Alignment.centerRight,
                             widthFactor: 1,
                             heightFactor: 1,
                             child: Text(
                               s.t('Xem tất cả', 'See all'),
                               style: AppTextV2.name(color: AppColorsV2.wisteria, size: 11.5),
                             ),
                           ),
                         ),
                       ),
   ```

## Self-check (run it and paste the real output)

```powershell
C:\src\flutter\bin\flutter.bat analyze lib/views/v2/screens/home_screen.dart
```

## Caller verification

- `git diff --stat`: 1 file.
- `flutter test test/v2/responsive_matrix_test.dart --plain-name "home @"`: **all four checks green at
  every viewport.** This is the task that should close out home. If anything is still red, give the
  output to a Claude sub agent. Do not run another Hermes round.
