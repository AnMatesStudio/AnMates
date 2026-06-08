---
name: 2026-06-03-meetup-map-master-plan
description: Authored the Meetup & Dining Map master plan (18-section design doc) for matched-user venue selection → booking → meetup.
metadata:
  type: session
  date: 2026-06-03
  status: delivered-pending-review
---

# Session — Meetup & Dining Map Master Plan

## TL;DR
Produced `docs/meetup-map-master-plan.md` — a complete cross-functional design (Product, UX, Flutter, Architecture, Backend, QA, Growth) for a map-based meetup planning experience. The map's job: help matched users *find → evaluate → agree on → book → meet* a restaurant. Doc-only deliverable, no code.

## Why
ĂnMates is place-first matchmaking; the biggest drop-off is "where do we actually meet?" after a match. Free-text venue negotiation in chat stalls matches. The map turns that into structured, tappable artifacts (restaurant cards) that can be suggested, accepted, and booked in a few taps.

## Confirmed decisions (asked user)
1. **Architecture — pragmatic incremental.** Riverpod + feature-first for NEW `map/restaurants/booking` features only; coexists with existing Provider/Navigator-1.0 under one root `ProviderScope`. No full-app refactor.
2. **Map RENDER SDK — flutter_map + OSM tiles for MVP** ($0, already in pubspec, web-friendly, brand-styleable). **Mapbox Directions/Matrix** introduced in V2 for ETA + midpoint, gated on cost telemetry. (Not Google/HERE/Bing for render.)

### Data-source decision (follow-up, same session)
**Render SDK ≠ data provider.** OSM/Overpass has poor coverage of VN long-tail local eateries — specific shops like *"Bún Bò Giáo Toàn"* aren't mapped. User confirmed **"pay for quality coverage."** So:
- **MVP restaurant DATA = Google Places API** (Text/Nearby Search) → Go server-side ingest worker → `restaurants` table, gated by admin curation (`status='active'`). ToS-compliant: store `place_id`→`source_ref`, TTL-refresh dynamic fields, **no scraping / no bulk-mirror**. OSM = free fallback only.
- **REJECTED — Playwright scrape of Google Maps:** violates Google Maps Platform ToS, brittle (DOM churn, IP/CAPTCHA bans), legal/redistribution exposure, unverified noise vs safety model.
- **REJECTED — Bing Maps:** retiring (free/Basic shut down 2025-06-30, full retirement 2028-06-30; Microsoft → Azure Maps).
- **REJECTED — Azure Maps:** TomTom POI data, weak VN long-tail coverage.
- **Foursquare** kept as optional cheaper supplement.
- Cost stance: render/tiles stay $0; we **pay for data** (Google Places). Favour seed + TTL-refresh ingest over live per-search calls to bound cost.
3. **Map scope — core MVP now.** Supersedes the prior "no full map in Phase 1" handoff decision; interactive Map Discovery becomes MVP, reusing existing geofence/booking/match foundations.

## What the doc covers (18 sections)
Exec summary · why maps matter · MVP/V2/V3 feature strategy · 9 user journeys (Mermaid) · 5 screens (Map Discovery, Restaurant Detail, Venue Suggestion, Booking Map, Meetup Day) with states+nav · midpoint engine + scoring algo · discovery system · Flutter architecture (feature-first tree) · SDK comparison matrix · backend API specs (httputil envelopes + JWT) · DB design + ERD (PostGIS) · performance · privacy & safety · analytics taxonomy · QA strategy · roadmap (Gantt) · tickets (6 EPICs) · final recommendation.

## Grounded in real repo
- Reuse: `anmates_flutter/lib/services/places_service.dart` (Overpass), `.../services/api_client.dart`, locked tokens in `.../theme/app_theme.dart` (Berry `#B8336A` etc.), existing chat WS hub + scheduling sheets + geofence design.
- Backend extends: Go Fiber `/api/v1`, raw SQL `pgxpool`, embedded migrations (next: `006`→`011`), `middleware.UserID(c)`, `httputil.OK/Err`. New tables: restaurants (PostGIS geom), venue_suggestions, bookings, user_locations, favorite_restaurants, meetup_recommendations, location_sessions.

### AI Concierge decision (follow-up, same session)
User asked to turn the experience into an **AI agent** monetized by **subscription + token limit**. Refined together into a much better shape:
- **Mechanic (user's VN vision):** when 2 people chat and the **Vibe meter (`noi_lau_progress`) crosses the trust threshold (70)**, the AI **auto-jumps into chat** and posts **top-3 venues** that are ① within both budgets, ② matching both moods/vibes, ③ at the **midpoint between them**. One-tap "Gợi ý cho Mate" → existing booking flow.
- It's a **triggered/proactive agent, NOT a chatbot** → naturally bounds cost (~1 run per match milestone) and turns the Vibe-unlock into a magical payoff.
- **Built on Claude:** tool-use loop, Haiku-first + Sonnet escalation, prompt caching, streaming, strict JSON output. Tools = the master-plan APIs (§6 midpoint, §7 search, §10 suggest/book). **Anti-hallucination:** venue IDs only from tool results, post-validated.
- **Monetization (key cautions I gave):** (1) **DON'T expose tokens to users** — wrong/anxiety-inducing mental model for VN dating consumers; sell **outcomes/quotas** ("trợ lý AI không giới hạn", "5 lượt gợi ý lại/ngày"); token budget stays **internal cost-control**. (2) **Respect locked Phase 1 no-paywall** — ship concierge FREE in MVP, monetize premium *extras* (re-roll/refine/plan-whole-date) in Phase 2.
- User decisions: limit UX = consumer quota/event-based; timing = MVP free → monetize later; deliverable = **separate doc** `docs/ai-concierge-plan.md`.
- New data: `ai_concierge_runs`, `ai_concierge_picks`, `user_prefs_budget` (budget field is a current gap). EPIC-AI-CONCIERGE = 8 tickets. Gate to Phase 2 monetization on proven AI-vs-manual conversion lift + a COGS model.

## Files changed
- `docs/meetup-map-master-plan.md` (new — the deliverable; later amended: §7 Google Places data source, §9 render-vs-data split, V3 AI cross-link)
- `docs/ai-concierge-plan.md` (new — AI Concierge & Monetization plan, 19 sections)
- `.claude/shared-memory/changelog.md`, `current-task.md` (updated)

## Verification (pending)
- Not yet rendered in a Mermaid preview by user; not yet reviewed by team. No code/tests run (design-only).

## Open follow-ups / risks
- ⚠️ Verify Cloud SQL PostGIS availability before MAP-R-1 (week-1 spike); Haversine + bbox fallback if unavailable.
- OSM data quality/safety → curate + verify before exposing (`status='active'` gate).
- Mapbox cost creep in V2 → cache Matrix per OD-pair, Haversine fallback.
- Riverpod/Provider coexistence smoke-test on existing flows.

## Migrate to resolution when confirmed
If user confirms the plan is adopted, promote to an `R-NNN` (tags: planning, maps, architecture, postgis, riverpod).
