# API Contracts (Live Mirror)

> **Canonical source:** [api-contracts-summary.md](api-contracts-summary.md) — Phase 1 endpoint catalog per handoff §5.
>
> This file mirrors the **implemented** subset that the `coder` agent has actually shipped, so the `qa` agent can smoke-test against current code. Coder updates this file as endpoints land in the Go backend; the canonical catalog above stays the design-time source of truth.

Base URL: `http://localhost:8080/api/v1` (dev) · `https://api.anmates.io/api/v1` (prod)

**Auth header:** `Authorization: Bearer <access_jwt>`

**Standard error response:**
```json
{ "error": "code_string", "message": "Vietnamese message", "details": {} }
```

---

## Implemented Endpoints

| Method | Path | Auth | Request | Response (200) | Notes |
|--------|------|------|---------|----------------|-------|
| POST | `/auth/otp/request` | none | `{phone}` | `{request_id, expires_at}` | TTL 90s · 3/15min/phone |
| POST | `/auth/otp/verify` | none | `{request_id, code}` | `{access_token, refresh_token, user_id, onboarding_step}` | 5 attempts max |
| POST | `/auth/refresh` | refresh | `{refresh_token}` | `{access_token, refresh_token}` | rotates refresh |

| PATCH | `/profile/onboarding` | access | `{name, nickname, birth_date "YYYY-MM-DD", personality_score}` | `userOut` (incl. `onboarding_done`) | Screen 08 — name required; score clamped 0-100 |
| PATCH | `/profile/preferences` | access | `{food_tags:[], vibe_tags:[]}` | `userOut` (`onboarding_done`=true) | Screen 09 — sets onboarding_done=TRUE |
| POST | `/matches/:id/concierge/suggest` | access | `{anchor:"midpoint"\|"me"\|"mate"}` | `CardContent {intro, midpoint{lat,lng}, picks[]}` | AI venue re-suggest centered on midpoint / requester / mate. Member-only. NOT posted to chat (private re-roll). Only when concierge enabled. 400 bad anchor · 409 missing location |
| POST | `/matches/:id/booking` | access | `{restaurant_name, restaurant_address?, lat?, lng?, scheduled_at "RFC3339"}` | `Booking` (201, status `proposed`) | First Date proposal. Member-only. Re-proposing cancels the prior active one. 400 past time / no venue |
| GET | `/matches/:id/booking` | access | — | `Booking` (latest) | Member-only. 404 if none yet |
| POST | `/matches/:id/booking/confirm` | access | — | `Booking` (status `confirmed`) | Member-only. Only the NON-proposer may confirm → 409 if proposer confirms own · 404 no active proposal |
| POST | `/matches/:id/booking/cancel` | access | — | `Booking` (status `cancelled`) | Member-only. Either member. 404 no active booking |
| GET | `/venues/search` | access | `?q=<text>&lat=&lng=&radius_m=&limit=` | `CardPick[]` | Free-text Discovery web-search. `q` min 2 runes else 400. `lat`/`lng` optional (default 0). `limit` max 10. 10-min TTL cache. 60s timeout. Only when `AI_SEARCH_URL` configured. |

> ✅ Implemented + build-verified 2026-05-30 (`GO111MODULE=on go build ./...` rc=0; `go vet` rc=0; `flutter analyze` 0 errors). Functional QA still pending.
>
> Add rows above as endpoints ship. Match exact path + body shape from `api-contracts-summary.md`.

## Update Protocol

When **coder** ships or modifies an endpoint:
1. Add/update its row in the table above (only **implemented** endpoints).
2. If response shape is complex, attach JSON example below in `### Schema details`.
3. Verify it matches the canonical catalog in `api-contracts-summary.md` — if it diverges, flag in `blockers.md` for architect review.
4. Bump the `Last updated` line at the bottom.

## Schema details

_(Empty — add JSON examples when needed.)_

---
**Last updated:** 2026-06-08 (added GET /venues/search — Discovery web-search)
