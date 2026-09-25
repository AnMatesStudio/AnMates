# T44–T49 — Filters, Rate, Bill, Pay, Trust, Local: same pattern, one Hermes session per file

**Executor:** Hermes (local), **one session per file**. Run them one after another, never several files in one session.
**Depends on:** T02 · **Working dir:** `C:\AnM\AnMatesStudio\AnMates\anmates_flutter`

| id | File (the ONLY file for that session) | Extra edit |
|---|---|---|
| T44 | `lib/views/v2/screens/filters_screen.dart` | — |
| T45 | `lib/views/v2/screens/rate_screen.dart` | — |
| T46 | `lib/views/v2/screens/bill_screen.dart` | E2 |
| T47 | `lib/views/v2/screens/pay_screen.dart` | uses P2 instead of P1 |
| T48 | `lib/views/v2/screens/trust_screen.dart` | E3 |
| T49 | `lib/views/v2/screens/local_screen.dart` | — |

Prompt per session (change the id and file):
```
Read the task spec C:\AnM\AnMatesStudio\AnMates\docs\plans\2026-09-25-responsive-mobile\tasks\T44-49-simple-screens.md and apply the row for T44 only, to lib/views/v2/screens/filters_screen.dart only. When done, run the self-check command and paste its real output.
```

## Edits for every file

**I1 — import.** Find:
```dart
import '../../../theme/app_theme_v2.dart';
```
Replace it with:
```dart
import '../../../theme/app_theme_v2.dart';
import '../../../theme/v2_layout.dart';
```

**P1 — page padding** (every file except pay). Find:
```dart
      padding: EdgeInsets.fromLTRB(18, 104, 18, navClearance(context)),
```
Replace it with:
```dart
      padding: EdgeInsets.fromLTRB(
        V2Layout.hPad(context), V2Layout.contentTop(context),
        V2Layout.hPad(context), navClearance(context),
      ),
```

**P2 — page padding, pay only.** Find:
```dart
      padding: const EdgeInsets.fromLTRB(18, 104, 18, 40),
```
Replace it with:
```dart
      padding: EdgeInsets.fromLTRB(
        V2Layout.hPad(context), V2Layout.contentTop(context),
        V2Layout.hPad(context), 40 + MediaQuery.paddingOf(context).bottom,
      ),
```

## Extra edits

**E2 — bill only.** Find:
```dart
                style: AppTextV2.name(color: AppColorsV2.wisteria, size: 9.5)
```
Replace it with:
```dart
                style: AppTextV2.name(color: AppColorsV2.wisteria, size: 11)
```

**E3 — trust only.** Find:
```dart
              width: 122, height: 122,
```
Replace it with:
```dart
              width: 122 * V2Layout.unit(context), height: 122 * V2Layout.unit(context),
```
If analyze then says `const` is not allowed on a widget that encloses this line, remove only that `const` keyword.

## Self-check (run it and paste the real output; use the file of this session)

```powershell
C:\src\flutter\bin\flutter.bat analyze lib/views/v2/screens/<file>.dart
Select-String -Path lib/views/v2/screens/<file>.dart -Pattern "18, 104"
```
The second command must print nothing.

## Caller verification, after each session

- `git diff --stat`: exactly the one file from that row.
- `flutter test test/v2/responsive_matrix_test.dart --plain-name "<screen> @"`, where `<screen>` is
  filters, rate, bill, pay, trust or local. Anything still red after this edit (usually a tap target or a
  fixed-size box inside the screen) goes to a Claude sub agent, together with the failure output.
