# T14 — Shell: 48pt language toggle; hide the nav while the keyboard is up

**Executor:** Hermes (local) · **Depends on:** T02 · **Blocks:** T43
**Working dir:** `C:\AnM\AnMatesStudio\AnMates\anmates_flutter`
**File to edit (ONLY this file):** `lib/views/v2/v2_app.dart`

## Why

1. The VI/EN chips are about 25pt tall (measured), well under the 48pt tap minimum, and their text is 10.5pt.
2. When the chat keyboard opens, the floating nav stays on screen and covers the composer.

## Edits

1. After the line `import '../../theme/app_theme_v2.dart';` add:
   ```dart
   import '../../theme/v2_layout.dart';
   ```

2. In `V2AppBody.build`, find:
   ```dart
               if (s.showNav)
   ```
   Replace it with:
   ```dart
               // The keyboard owns the bottom of the screen while it is up. Read the
               // raw view: Scaffold consumes the inset before it reaches the body.
               if (s.showNav && View.of(context).viewInsets.bottom == 0)
   ```

3. Replace the **whole** `build` method of `class _LangToggle` (from `@override` down to the closing
   `}` of the method, keeping the class's `const _LangToggle({required this.s});` and `final V2State s;`) with:
   ```dart
     @override
     Widget build(BuildContext context) {
       // Each chip is drawn ~30pt tall but hit-tests over a full 48pt square; the
       // white pill is painted behind the pair rather than wrapped around them so
       // the larger hit areas don't make it visibly taller.
       Widget chip(String label, bool active, VoidCallback onTap) => GestureDetector(
             onTap: onTap,
             behavior: HitTestBehavior.opaque,
             child: ConstrainedBox(
               constraints: const BoxConstraints(
                 minWidth: V2Layout.minTap, minHeight: V2Layout.minTap,
               ),
               child: Center(
                 widthFactor: 1,
                 child: Container(
                   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                   decoration: BoxDecoration(
                     color: active ? AppColorsV2.wisteria : Colors.transparent,
                     borderRadius: BorderRadius.circular(999),
                   ),
                   child: Text(
                     label,
                     style: AppTextV2.name(
                       color: active ? Colors.white : AppColorsV2.inkA(0.5),
                       size: 11,
                     ),
                   ),
                 ),
               ),
             ),
           );

       return Stack(
         alignment: Alignment.center,
         children: [
           Positioned.fill(
             top: 9, bottom: 9,
             child: DecoratedBox(
               decoration: BoxDecoration(
                 color: AppColorsV2.whiteA(0.92),
                 borderRadius: BorderRadius.circular(999),
                 boxShadow: [
                   BoxShadow(
                     color: const Color(0xFF10366E).withValues(alpha: 0.16),
                     blurRadius: 14,
                     offset: const Offset(0, 4),
                   ),
                 ],
               ),
             ),
           ),
           Padding(
             padding: const EdgeInsets.symmetric(horizontal: 3),
             child: Row(mainAxisSize: MainAxisSize.min, children: [
               chip('VI', !s.en, () => s.setLang(false)),
               chip('EN', s.en, () => s.setLang(true)),
             ]),
           ),
         ],
       );
     }
   ```

## Do not

- Change the `Positioned(top: topInset + 8, right: 16, child: _LangToggle(s: s))` line.
  `V2Layout.contentTop` (safeTop + 56) is sized for a 48pt toggle placed at safeTop + 8.

## Self-check (run it and paste the real output)

```powershell
C:\src\flutter\bin\flutter.bat analyze lib/views/v2/v2_app.dart
```

## Caller verification

- `git diff --stat`: 1 file. `flutter test test/v2` is green.
- Matrix test: the `tap targets` failures on the VI/EN chips are gone on every screen.
- Look at `home` in the screenshot grid: the pill must look about as tall as before (~30pt), not 54.
