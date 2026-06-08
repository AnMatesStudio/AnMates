---
id: R-006
title: AI Concierge venue card — fake/out-of-area coords + wrong area name in intro + api container stuck "unhealthy"
tags: [ai-concierge, web-search, geocode, grounding, healthcheck, docker, ipv6, go-backend, ai-venue-search, concurrency]
platforms: [backend]
severity: major
status: confirmed
date_resolved: 2026-06-08
confirmed_by: user
related_sessions: [sessions/2026-06-08-e2e-full-flow-issues.md]
related_blockers: []
---

# R-006: AI Concierge grounding (fake coords + wrong area name) + api healthcheck stuck "unhealthy"

## TL;DR
Three defects found by running the full-flow E2E and inspecting the real AI venue card +
container state. **A1:** out-of-area venues got fabricated near-midpoint coordinates
(a Thủ Đức BBQ ~13 km away shown 184 m from a central-HCMC midpoint). **A2:** the card
intro named a wrong neighbourhood ("khu vực Xuân Hòa") because OSM/Photon **and**
Nominatim both mislabel that HCMC midpoint's district. **B2:** the api container was
permanently `unhealthy` (busybox `wget localhost` → IPv6 `::1`, Go listens IPv4). Fixes
live in the Python sidecar + docker-compose; no Go/Dart changes for A1/A2/B2.

## Symptoms
- AI card pick with `"address":"…Quận Thủ Đức"` (≈13 km away) but `lat/lng` placed `distance_m=184` from the midpoint; all picks had `restaurant_id:""`.
- Card intro: *"Gặp gỡ chill tại **khu vực Xuân Hòa**…"* for a midpoint at `10.781,106.695` (central HCMC, not Vĩnh Phúc's Xuân Hòa).
- `docker inspect anmates-api-1` → `Status: unhealthy`, `FailingStreak: 301`; healthcheck log `wget: can't connect to remote host: Connection refused`. Yet `/health` returns 200 from the host and from inside the container via `127.0.0.1`.

## Root Cause
- **A2:** `reverse_area()` (Photon `/reverse`) returns `district="Phường Xuân Hòa, Thủ Đức"` for that central midpoint — confirmed Nominatim returns the same, so it is **OSM data** (post-2025 ward reform / mislabel), not a one-provider bug. The name was prepended to the model context (`"Khu vực điểm giữa: {area}"`) so the LLM parroted it into the intro.
- **A1:** anti-hallucination (validate id ⊂ candidates + copy facts from DB) only runs on the **DB path**; the `WebSearchProvider` trusts the sidecar. The sidecar forward-geocodes each pick **biased to the midpoint** with a loose `_MAX_GEO_KM=60` accept guard, so a fuzzy name match (e.g. "Subin BBQ" → a different nearby BBQ) or a far street address snapped to a near-midpoint point and shipped a confidently-wrong pin.
- **B2:** compose healthcheck used `http://localhost:8080/health`. Busybox `wget` resolves `localhost` to IPv6 `::1` first; the Go server (`app.Listen(":8080")`) binds IPv4 `0.0.0.0` only → `::1` refused → healthcheck never passes.

## Solution

### Steps
1. **B2** — `docker-compose.yml` api healthcheck: `http://localhost:8080/health` → `http://127.0.0.1:8080/health` (force IPv4).
2. **A2** — `ai-venue-search`: stop prepending the reverse-geocoded area to the model context; add a system-prompt rule that the intro must **not** name a specific ward/district (location wording must come from the venue addresses in the search results). `area` still steers the web search.
3. **A1** — `ai-venue-search`: replace the fixed 60 km accept with a radius-derived guard `accept_km = max(6, radius_m/1000 × 1.5)`; when a pick has a street address, **trust only that** (a hit beyond the radius → drop to `lat/lng=0`, no fuzzy name fallback that would borrow another venue's coords); use name geocoding only when there is no address.

### Code changes
| File | Change |
|------|--------|
| `docker-compose.yml` | api healthcheck `localhost`→`127.0.0.1` (IPv4) |
| `ai-venue-search/ai_venue_search/service.py` | drop area-prepend; `_accept_radius_km()`; street-only trust + radius guard in `_geocode_venue`/`_enrich_coords` |
| `ai-venue-search/ai_venue_search/providers/structurer.py` | system prompt: intro must not name a ward/district |
| `ai-venue-search/tests/test_geocode_radius.py` | new — 6 offline cases for the radius guard |

## Verification
- `pytest tests/` in the sidecar = **11 passed**.
- Rebuilt `ai_venue_search` + recreated `api` → `State.Health.Status = healthy` (B2).
- `node .dev-e2e/e2e_full_flow.js` = **20/20**; the real card: King BBQ 1.10 km, PandaBBQ 1.96 km, Mini Candy 2.85 km (all in-area, `distance_m` consistent), intro *"…giữa 2 bạn"* (no wrong area name).
- **Live "current address" test (user in Thủ Đức):** with the correct Thủ Đức coords the card returned only Thủ Đức venues (King BBQ Buffet 216 Võ Văn Ngân, Sumo Yakiniku Kha Vạn Cân, Buffet Sống Sắc), intro *"…khu vực Thủ Đức…"*; far/vague venues → `lat/lng=0` (no fake pin). Video recorded.

## Why this fix works (for future-Claude)
The web-search path can't be made to "know" a venue's true coordinate, so the fix shifts to **honesty over coverage**: only ship a pin we can verify is in the meet-in-the-middle radius from its own street address; otherwise ship `0,0` and let the card show name+address (Maps deep-link by text still works). The wrong-area-name leak is cut at the source (don't feed the model an unreliable OSM label; forbid it in the intro). The healthcheck "connection refused while the app is clearly up" signature is the classic IPv6-`localhost` vs IPv4-bind mismatch — always probe `127.0.0.1` in container healthchecks.

## Gotchas / Related issues
- **Coverage tradeoff:** more picks now have `lat/lng=0` (no pin) when the address is a mall/vague string. This surfaced **ISSUE-9** (Flutter card showed "0m" for un-geocoded picks) — fixed in `ai_venue_card.dart` `distanceLabel` (empty when `lat==0 && lng==0`).
- **`restaurant_id` still empty** on the web-search path (no DB grounding) — would need a venue-ingest step; deferred.
- **B1 (sidecar 502 under warm+fire concurrency):** fixed in the same session — `ConciergeService.fire` now waits for an in-flight prewarm (channel in `warming` map) instead of launching a second concurrent LLM call. Verified with `SETTLE_MS=0` (no e2e pause) → card still fires 20/20.
- OSM area labels for HCMC are unreliable after the 2025 ward reform — do not surface raw reverse-geocoded ward/district names to users.

## References
- Session: [sessions/2026-06-08-e2e-full-flow-issues.md](../sessions/2026-06-08-e2e-full-flow-issues.md)
- Photon geocoder: https://photon.komoot.io · Nominatim: https://nominatim.openstreetmap.org
