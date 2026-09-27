# AnMates — E2E test cases

Scope: the v2 app (`anmates_flutter/lib/views/v2`) against the real API. **Auto** = automated in
`anmates-api/e2e/e2e_test.go` (runs against a live API + Postgres; see the package comment for the
command). **UI** = checked by hand in the web build at `http://127.0.0.1:54180` (a phone-sized window
is enough). "NEW" = feature added 2026-09-27 (it did not exist when this list was written).

## UI review — what was missing for a food-mate app

| Area | Before | Now |
|---|---|---|
| Unmatch | none — a match could never be ended | `DELETE /matches/:id` (NEW) |
| Block | none — a harasser could keep messaging | `POST/GET/DELETE /blocks` (NEW) |
| Report | none — no way to flag no-shows, fake profiles, harassment | `POST /reports` (NEW) |
| Meal rating (D4 Rate screen) | UI only, nothing saved ("no ratings table") | `POST/GET /matches/:id/rating`, private until both rate (NEW) |
| Me screen stats | hardcoded "24 bữa đã ăn" | `GET /profile/stats` (NEW) |
| Onboarding → deck | v2 onboarding saved nothing; new accounts never entered anyone's swipe deck | tastes sent via `PATCH /profile/preferences` after sign-in/sign-up (round 3) |
| Edit profile | no way to change name/bio/prefs after sign-up | Me → "Sửa hồ sơ" sheet + `GET/PATCH /profile/match-prefs` (round 3) |
| Match filters | chips changed nothing | area/vibe/price filter the deck; unknowns kept (round 3) |
| Delete account | impossible | `DELETE /profile` + Me button (round 3) |
| Notifications | empty sheet, bell dot always on | DB triggers → `GET /notifications`, badge only when unread, tap opens chat (round 3) |
| Trust Score | placeholder | `GET /profile/trust`: 80 + 4·meals + 2·(4★+ received) − 20·no-show reporters − 10·other reporters (round 3) |
| Visits / reviews (Me) | placeholders | `GET /profile/history` from confirmed bookings + ratings given (round 3) |
| Local Mates | placeholder | `GET /locals`: ≤5 km, ≥1 real meal, invite = like (round 3) |
| Chat photos | text only | attach button → Firebase Storage → `image` message + bubble (round 3) |
| Pay tiers, bill split OCR, push | placeholders | NOT built — need a payment merchant, an OCR service, FCM server keys |

## Journeys

| ID | Journey | Steps | Expected | How |
|---|---|---|---|---|
| E2E-01 | Match → chat → book a meal | A and B share ≥2 foods; A likes B; B likes A; A proposes a venue + time; A tries to confirm; B confirms | Match only after the 2nd like; both inboxes show it; A's own confirm → 409; B's → `confirmed` | Auto |
| E2E-02 | Outsider locked out | C reads A–B messages / booking | 404 `MATCH_NOT_FOUND` | Auto |
| E2E-03 | Auth required | profile / conversations / deck without token | 401 | Auto |
| E2E-10 | Unmatch (NEW) | A unmatches B; outsider tries; bad id; B unmatches again | 200; gone from both inboxes; B's history 404; outsider 404; bad id 400; repeat 404 | Auto |
| E2E-11 | Block (NEW) | A blocks B (while matched); self-block; block twice; both like again; list; unblock | 201 (idempotent); match gone for both; neither in the other's deck; likes never re-match; list = [B]; unblock empties it; self 400 | Auto |
| E2E-12 | Report (NEW) | A reports B `no_show` with note; bad reason; self; bad id; 501-char note; no token | 201 + id; 400 ×4; 401 | Auto |
| E2E-13 | Meal rating (NEW) | A rates 5★; both read; B rates 4★; A re-rates 4★; outsider rates/reads; stars 0/6; long note | A sees only own; B sees nothing; after both: both see both (`both_rated`); re-rate updates; outsider 404; 400 on bad input | Auto |
| E2E-14 | Profile stats (NEW) | fresh match; then confirmed booking | meals 0 / matches 1 → meals 1 / matches 1; no token 401 | Auto |
| E2E-15 | Onboarded user reaches deck + prefs | onboard A,B; B sets vibe/price/location; bad prefs | B in A's deck with district + price_tier; 400 on bad vibe / >3 / tier 4 | Auto |
| E2E-16 | Delete account | no token; delete; read profile; partner inbox | 401; 200; 401/404; conversation gone | Auto |
| E2E-17 | Notifications | match; propose+confirm; rating; mark read | right kinds to the right person (never your own proposal); actor name; unread → 0 | Auto |
| E2E-18 | Trust Score | fresh; +meal; +5★; 2 no-show reports by 1 person + 1 harassment | 80 → 84 → 86 → 56; partner 84 | Auto |
| E2E-19 | History | fresh; confirmed booking + rating with note | empty → 1 visit (venue, partner) + 1 review (stars, note, venue) | Auto |
| E2E-20 | Local Mates | no location; near ×2 with meals, far, near without meal; block | [] → only the 2 near with meals, nearest first ~1.1 km; blocked disappears | Auto |

## UI checks

**Auto-UI** = `anmates_flutter/tool/e2e/ui_flows.js`, **Auto-UI3** = `anmates_flutter/tool/e2e/ui_flows_round3.js` (Playwright on the real web build; setup in each header).

| ID | Screen | Steps | Expected |
|---|---|---|---|
| UI-01 | Onboarding → Auth | fresh browser, go through A0–A4, register with email | lands on Home; name from `/profile`, not "Yuna" |
| UI-02 | Home | allow location, move radius slider | feed only venues in radius; empty radius offers to widen |
| UI-03 | Swipe | drag right on a real candidate who already liked you | match sheet appears; conversation in Inbox |
| UI-04 | Chat | send a message from two browsers | appears live on the other side; "Đã gửi" / read avatar |
| UI-05 | Chat menu (NEW) | ⋮ → Bỏ ghép | confirm dialog; back to Inbox; row gone for both — **Auto-UI** |
| UI-06 | Chat menu (NEW) | ⋮ → Chặn | confirm; row gone; that person never appears in Swipe again — verified by hand 2026-09-27 |
| UI-07 | Chat menu (NEW) | ⋮ → Báo cáo → pick reason | "Đã gửi báo cáo" toast above the nav bar; stays in chat; row in `user_reports` — **Auto-UI** |
| UI-08 | Bill → Rate (NEW) | confirmed booking → "Đánh giá bữa ăn" → send | "waiting for mate" until both rate; then "<mate> đã rate ★…" and "Cả hai đã rate" — **Auto-UI** |
| UI-09 | Me (NEW) | open after a confirmed booking; unblock someone | real counts; "Đã chặn" list; unblock asks, then removes — **Auto-UI** |
| UI-11 | Sign-up (NEW) | register through the auth screen | `onboarding_done` + tastes saved in DB — **Auto-UI3** |
| UI-12 | Filters (NEW) | toggle "Yên tĩnh", then "Ồn vui" | CTA count drops by the one mismatching mate; deselect restores — **Auto-UI3** |
| UI-13 | Notifications (NEW) | bell with unread → open sheet → tap rating row | badge; list; unread 0 in API; chat opens; image bubble + photo button — **Auto-UI3** |
| UI-14 | Me (NEW) | after a confirmed, rated meal | visit + review listed; Trust 86 row — **Auto-UI3** |
| UI-15 | Edit profile (NEW) | change name, bio, add "Săn deal" | saved in API; chip on Me — **Auto-UI3** |
| UI-16 | Trust (NEW) | open Trust Score | same score as API + breakdown — **Auto-UI3** |
| UI-17 | Local Mates (NEW) | Explore → "Tìm Local Mates" → "Mời đi ăn" | nearby local listed; toast; like row in DB — **Auto-UI3** |
| UI-18 | Delete account (NEW) | Me → Xoá tài khoản → Xoá | user row gone — **Auto-UI3** |
| UI-10 | Every screen | 360×640 and 402×874 viewports, VI and EN | no overflow stripes, no untranslated string |
