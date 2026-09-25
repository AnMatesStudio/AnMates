# T10 — Raise the smallest text tokens to 11pt

**Executor:** Hermes (local) · **Depends on:** decision D2 in README §5 · **Blocks:** T13
**Working dir:** `C:\AnM\AnMatesStudio\AnMates\anmates_flutter`
**File to edit (ONLY this file):** `lib/theme/app_theme_v2.dart`

## Why

Three text tokens are below the 11pt readability floor even at 1:1: `meta` 10.5, `eyebrow` 10.5 and
`navLabel` 9. Every screen uses them, so fixing them here fixes most call sites at once.

## Edits (inside `class AppTextV2`)

1. In `static TextStyle meta(...)` change `size: 10.5` to `size: 11.5`.
2. In `static TextStyle eyebrow(...)` change `size: 10.5` to `size: 11`.
3. In `static TextStyle navLabel(...)` change `size: 9` to `size: 11`.
4. Directly above `class AppTextV2 {`, the doc comment ends with the line
   `/// separates roles by weight/size, so there is no display/body split here.`
   Add these lines after it:
   ```dart
   ///
   /// Nothing readable goes below 11pt: the design's 9–10.5pt labels were raised
   /// to that floor (docs/plans/2026-09-25-responsive-mobile, decision D2).
   ```

Change nothing else. Leave `letterSpacing`, `weight` and `height` as they are.

## Do not

- Edit any other file, even ones that pass their own explicit small sizes (those are T23, T40–T46).

## Self-check (run it and paste the real output)

```powershell
C:\src\flutter\bin\flutter.bat analyze lib/theme/app_theme_v2.dart
```

## Caller verification

- `git diff` shows only 3 numbers changed plus the comment.
- `flutter test test/v2`: the existing 7 tests must stay green. Bigger text can cause overflow: if a
  test reports `RenderFlex overflowed`, note which screen it is. That screen's Phase 2 task handles it,
  so do not revert the token.
