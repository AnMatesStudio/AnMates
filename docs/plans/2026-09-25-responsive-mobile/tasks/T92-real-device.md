# T92 — Real phones: iPhone Safari, iPhone PWA, Android Chrome

**Executor:** Claude sub agent + the user (the user holds the phones) · **Depends on:** T91

Emulated viewports cannot show these behaviours. This is the only task that can.

## Setup

Serve the build to the phones without touching production: use `start.sh` with a LAN IP (same Wi-Fi),
or the existing Cloudflare Tunnel workflow (`.claude/shared-memory/sessions/2026-09-03-v2-feed-real-db-data.md`).
**Deploying to `app.anmates.site` is a separate step and needs the user's explicit OK.**

## Checklist (the user sends a screenshot for each line)

| # | Device / mode | Check |
|---|---|---|
| 1 | iPhone, Safari | Home: no empty band at top, text reads comfortably, CTA visible without scrolling |
| 2 | iPhone, Safari | Scroll home down and up so the toolbar collapses and expands. **The UI must not zoom in and out** (the old `k` rescale) |
| 3 | iPhone, Safari | Chat: tap the composer, the keyboard opens, the composer stays visible above it, the nav is hidden |
| 4 | iPhone, "Add to Home Screen" (PWA standalone) | Content does not sit under the status bar or clock. Flutter web may not read `env(safe-area-inset-*)`. If it overlaps, fix it in `web/index.html` as a follow-up task |
| 5 | iPhone, Settings › Display › Text Size largest | Nothing overflows (the 1.3× clamp) |
| 6 | Android (Samsung A or Redmi), Chrome | Same as 1–3 |
| 7 | Any phone, rotate to landscape | A centered column, nothing clipped, no dark desktop frame |
| 8 | Smallest phone available | Onboarding steps 1–5: every CTA is reachable |

## Close-out

- User confirms → Path A in the repo `CLAUDE.md`: write a resolution `R-NNN` in `.claude/shared-memory/resolutions/`,
  update `INDEX.md`, `changelog.md` and `current-task.md`.
- Any line fails → a new task file in `tasks/`, with the screenshot and the viewport.
