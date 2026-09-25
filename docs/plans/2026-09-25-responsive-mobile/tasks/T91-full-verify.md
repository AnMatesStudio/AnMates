# T91 — Full verification + look at every screenshot

**Executor:** Claude sub agent (`qa`) · **Depends on:** all Phase B tasks

## Steps

1. `flutter analyze`, then `flutter test` (the whole suite). Paste the counts.
2. `node scripts/responsive-shots.mjs --build --out screenshots/responsive/after`. The baseline
   (`screenshots/responsive/baseline`, from T05) must already exist.
3. **Open both `index.html` contact sheets and look at every image.** Check each screen × viewport for:
   - text clipped, overlapping, or visibly smaller than on other viewports
   - an empty band at the top in the `*-safari` / `android-*` columns (the original bug)
   - content hidden behind the glass nav at the end of a scroll
   - art cut off at a screen edge where the design does not bleed it
   - `design-frame` column: compare with `plan/mobile-app-design-planning v2`. It should be the closest match
     to the design. List any visible drift (the 11pt floor from D2 is an expected drift).
   - `landscape`: a centered column, nothing clipped vertically (the screen scrolls)
4. Write `.claude/shared-memory/qa-reports/2026-09-25-responsive-mobile.md` with a table of screen ×
   viewport → OK / issue (with the image path), and the list of anything unresolved.

## Report honestly

Say which of these you did: "matrix tests pass", "I looked at N screenshots", "checked on a real
phone". T91 covers only the first two. Do not call the work done on T91 alone: T92 is the real-phone check.
