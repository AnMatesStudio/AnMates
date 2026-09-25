# T18 — Remaining tap targets, driven by the matrix test output

**Executor:** Claude sub agent · **Depends on:** T01, T12, T14 · **Blocks:** T91
**Skills to load:** `ui-ux-pro-max` (read `references/pro-rules.md`, "Touch target minimum" and "Touch Spacing")

## Input

Run `flutter test test/v2/responsive_matrix_test.dart --plain-name "tap targets"` and work from its failure
list. After T12 (back buttons, `V2Chip`) and T14 (VI/EN), README §1.1 predicts these remain:

- onboarding step 1: `"Đã có tài khoản? Đăng nhập"` link (19pt tall)
- filters: `"Đặt lại"` and any chip that is not a `V2Chip`
- rate: the ★ buttons and the tag chips
- chat: header buttons
- home: `"Xem tất cả"` (T23 handles this one; skip it if T23 is done), the `"Thử lại"` retry link
- all-venues: whatever the test reports

## Rule

**Enlarge the hit area to ≥ 48 × 48 without changing what is drawn.** Wrap the tappable in a
`GestureDetector(behavior: HitTestBehavior.opaque)` or give it a `ConstrainedBox(minWidth/minHeight: V2Layout.minTap)`
with a `Center`/`Align(widthFactor: 1, heightFactor: 1)` inside. Keep adjacent targets at least 8pt apart
(skill: "Touch Spacing"). Where a row of ★ cannot reach 48 each without overlapping, spread the row or grow the
spacing; do not shrink the icons. Say in the report which you chose and why.

## Verify

The `tap targets` group is green for every screen at every viewport. The screenshots at `design-frame` look the
same as before this task: compare the images, don't assume.
