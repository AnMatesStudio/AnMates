# QA Report — AI Concierge + First Date Booking (UI, video)

**Date:** 2026-06-08
**Tester:** main-assistant (QA role)
**Build:** full stack `docker compose up -d --build` (api trigger 70, web-search + LM Studio)
**Driver:** `.dev-e2e/qa_full_flow.js` (Playwright, real Flutter web UI, API-asserted)
**Verdict:** ✅ **PASS — 5/5 steps**

## Scope
Headline flow exercised on the real CanvasKit UI, each step asserted against the API:
chat → Vibe climb → AI Concierge venue card (grounded) → First Date booking propose.

## Results
| # | Step | Result |
|---|------|--------|
| 1 | Seed demo match @ 68 pts (Thủ Đức, onboarded users + locations) | ✓ |
| 2 | Open chat via dev deep-link (An) | ✓ |
| 3 | Send 2 messages → Vibe climbs to **70** | ✓ (points=70) |
| 4 | **AI Concierge `ai_venue_card` fires** | ✓ King BBQ Buffet (Thủ Đức) |
| 5 | Tap "Chốt First Date — mở rồi!" → **BookingView** opens (venue pre-filled from card) | ✓ |
| 6 | Tap propose CTA → **booking proposed** | ✓ status=proposed (King BBQ Buffet) |

## Fix verification (today's changes, visually confirmed)
- **A2 (wrong area name):** intro = *"Ghé ngay khu vực giữa hai bạn, thưởng thức BBQ và lẩu…"* — no bogus ward/district name. ✓
- **A1 (grounding):** venue is in Thủ Đức (user's real area), not a far/fake-coord pick. ✓
- **ISSUE-9 (0m):** card shows no misleading "0m" distance. ✓
- **Booking:** CTA unlocks at Vibe 70, BookingView calendar is the real current month (Tháng 6 · 2026, today=8), venue carried from the latest AI card, propose creates a `proposed` row + "ĐÃ ĐỀ XUẤT … Chờ Bình xác nhận" banner. ✓

## Artifacts
- 🎥 Video: `videos/qa-first-date-flow.webm` (~1.2 MB)
- 🖼️ Screenshots: `videos/qa_01_chat.png`, `qa_02_card.png`, `qa_03_booking_form.png`, `qa_04_proposed.png`

## Notes / not covered here
- Booking **confirm** (the partner Bình confirming) is covered by the API e2e (`e2e_full_flow.js` step 13, confirm-own→409 + confirm→confirmed) but not in this single-phone video; a 2-phone pass would show it live.
- AI card returned 1 venue this run (web-search variance) — not a regression; grounding/anti-fake-pin is the fixed behaviour.
- UI taps are coordinate-based (CanvasKit has no DOM); stable here but recalibrate if layout changes.

## Regressions
None observed. Prior automated suites still green: sidecar pytest 11/11, Go vet+test, `e2e_full_flow.js` 31/31, `e2e_card_buttons.js` PASS, `e2e_booking_ui.js` PASS.
