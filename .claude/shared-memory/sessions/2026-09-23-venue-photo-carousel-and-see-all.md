# 2026-09-23 — Venue photo carousel, full-screen viewer, AM favicon, "Xem tất cả" paged list

## TL;DR
- Detail screen hero is now a swipeable carousel over **all** of a venue's DB photos (was `photoUrls.first` only), with dots at the bottom and a full-screen viewer on tap (pinch/scroll/double-tap zoom, swipe, close via X or tap outside, dots).
- Web: mouse/trackpad drag now swipes both carousels (custom `ScrollBehavior`).
- Web favicon + PWA icons replaced with the "AM" logo.
- New **"Xem tất cả"** screen: whole DB catalogue, 10 per request, lazy-loaded on scroll until the API says there is no more; tap a row → detail (back returns to the list at the same scroll position).
- Backend `GET /api/v1/venues` gained `offset` + response `total` / `has_more`.

## Key decisions / facts
- `Place.photoUrl` (single) → `Place.photoUrls` (list). `Venue.photoUrl` (home tiles) is unchanged.
- A photo that fails to load inside a venue's carousel shows a neutral `_BrokenPhoto` placeholder, **not** the 3D food illustration — the illustration only appears when the venue has zero photos (user asked that illustration never mix with real photos while swiping).
- "Xem tất cả" previously pointed at `V2Screen.filters` (match filters) — a wrong target; now `V2Screen.allVenues`.
- Paging is sort-then-slice in Go (`pageOf` helper). Sort ties are broken by id: the SQL has no ORDER BY, so without the tie-break equal-distance/equal-name rows could swap between pages. Verified: paging 18 venues 10 at a time tiles the full ordered list exactly (no dup, no gap).
- The list uses no radius (all DB rows) but passes lat/lng when available → nearest-first + distances. Location is resolved once per list session so the server-side order can't shift between pages.
- Detail opened from the list reads `V2State._openedPlace` (list venues may not be in the home feed's `_places`); `detailBack` decides where the back button returns.

## Files changed
- anmates-api: `services/venue_catalog.go` (`Offset`, `ListVenuesPage`, `pageOf`, deterministic sort), `services/venue_catalog_test.go` (+`TestPageOf*`), `handlers/venue_catalog.go` (`offset`, `total`, `has_more`), `main.go` (route comment).
- anmates_flutter: `lib/views/v2/v2_data.dart`, `v2_venue_mapper.dart`, `v2_state.dart`, `v2_app.dart`, `screens/detail_screen.dart`, `screens/home_screen.dart`, `screens/all_venues_screen.dart` (new), `lib/services/venue_catalog_service.dart` (`VenuePage`, `page()`), `test/venue_catalog_test.dart`, `web/favicon.png`, `web/icons/*`.

## Verification
- `flutter analyze` clean (2 pre-existing infos in booking_service.dart), `flutter test` 57/57.
- Go: build + vet + `go test ./services ./handlers` pass (run in `golang:1.25-alpine` — local Go is 1.23 in GOPATH mode, can't build this module).
- Live API: offset 0/10/20 → 10/8/0 rows, total 18, has_more true/false/false.
- **UI not yet confirmed by the user** (no browser automation here).

## Gotchas hit
- A `docker compose up --build ... | grep | tail` pipeline hides the real exit code: a transient Docker Hub TLS timeout left the *old* image serving while the port check said "ready". Check `docker images anmates-flutter_web` recency.
- OrbStack quit mid-session once (socket vanished); `open -a OrbStack` restored it and containers came back healthy.

## Open follow-ups
- Native iOS/Android launcher icons still the Flutter default (only web icons changed).
- Local DB currently has 18 venues, all `photo_count = 0` — carousel/list photo paths need a DB with photos to eyeball.
