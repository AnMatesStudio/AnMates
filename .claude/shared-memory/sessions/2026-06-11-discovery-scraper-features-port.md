# 2026-06-11 — Port google-maps-scraper venue-enrichment features into Discovery (A/B/C/D)

## TL;DR
User pointed at `github.com/omkarcloud/google-maps-scraper` and asked to research + apply
suitable features. Researched the repo (Botasaurus Google-Maps scraper, 50+ fields/place:
ratings, reviews, opening hours, popular times, categories, price, photos, + a big B2B
lead-gen layer). **Two hard constraints shaped scope:** (1) its data source — **Google Maps —
is prohibited in VN** (locked decision), so only the *feature concepts* are portable, fed by
our permitted sources (TomTom/OSM + the Bing scrape infra from R-007); (2) ~half of it
(email/Apollo/lead-enrichment/carrier/ad-spend) is irrelevant to a consumer dining app → skipped.

User selected **all four** proposed features. Built A, B, C; D was a spike (no-build outcome).
User also added: "take the images belonging to that location and show in discovery + detail" —
already satisfied by the R-007 pipeline (name+address-specific query + relevance filter); C's
field-merge makes the address richer → even better photo matching.

## What shipped

### A — "Đang mở cửa" / "Đã đóng" badge (pure Flutter, no backend, no new data source)
- NEW `lib/utils/opening_hours.dart` — pragmatic OSM `opening_hours` parser. Handles `24/7`,
  `Mo-Su 08:00-22:00`, multi-rule `;`, day-lists `Mo-We,Fr`, split shifts `10:00-14:00,17:00-22:00`,
  overnight ranges `18:00-02:00` (incl. still-open-after-midnight from yesterday), bare all-day
  ranges, `off`/`closed`. Unknown/unparseable → preserves raw string. Returns `OpeningStatus`
  {state, label "Đang mở · đóng 22:00", shortLabel}.
- NEW `lib/widgets/open_now_badge.dart` — `OpenNowBadge` pill: 🟢 green open / red closed /
  neutral raw-hours fallback. Local colors (brand palette has no semantic open/closed token).
- Wired into `discover_view.dart` `_RestaurantRow` (replaced the raw `🕒 <hours>` chip) and
  `venue_detail_view.dart` (badge under the title meta + `_matchChecks` "Đang mở cửa" now uses
  the real parser instead of "hours string non-empty").
- TEST `test/opening_hours_test.dart` — 7 cases, deterministic clocks (Mon 2026-06-08 / Sat 06-13).
- ⚠️ Note: the TomTom `/venues/nearby` path doesn't populate `opening_hours` yet (nearbySearch
  doesn't return it by default) → badge currently shows on the OSM/Overpass path. Follow-up: add
  `&openingHours=nextSevenDays` to the TomTom request + convert its structured ranges to a label.

### B — Ratings ⭐ + review count + community snippets (the scraper's flagship feature, VN-legal)
- NEW `services/venue_reviews.go` — `ReviewSearcher`: keyless **Bing web** search biased to VN
  review pages (`<query> đánh giá review`), parses rating (`4,5/5` etc.), review count
  (`1.234 đánh giá`), and up to 3 result snippets. In-memory cache (24h hit / 1h empty), graceful
  empty on any failure. Reuses `ImageBrowserUA`, `significantTokens`, `adminSuffixRe` from
  venue_image.go. **Rating/count emitted ONLY when a clear pattern matches — never fabricated.**
  Snippets filtered to venue-relevant / review-flavoured text; each labelled with its source domain.
- NEW `handlers/venue_reviews.go` — `GET /api/v1/venues/reviews?q=<name+address>` (JSON envelope).
  Registered under `auth` (carries bearer token, unlike the public image `<img>` route).
- TEST `services/venue_reviews_test.go` — fixture-based parser test (rating 4.5, count 1234,
  2 relevant snippets, generic admin page filtered out) + empty + query-prep cases.
- Flutter: NEW `lib/services/venue_reviews_service.dart` (`VenueReviewInfo`/`ReviewHighlight`);
  `venue_detail_view.dart` loads reviews in initState, merges rating into the meta line
  (`⭐ 4.5 (1.2k)`), and renders a "CẢM NHẬN TỪ CỘNG ĐỒNG" section of quote cards labelled
  "Trích từ web · <domain>" (honest — not presented as verified first-party reviews).

### C — Richer, deduped nearby list (merge TomTom + OSM)
- `lib/services/places_service.dart`: `getNearby` was TomTom-**or**-Overpass (either/or). Now
  fetches **both concurrently** and merges. NEW public `mergeNearbyPlaces(primary, secondary)` +
  `normalizeVenueName` + `OsmPlace.mergeFill` — dedup by normalized name within 250m; the matching
  secondary entry only fills blank fields (e.g. TomTom phone + OSM opening_hours on one record);
  secondary venues with no match are appended (TomTom's fresh close-in POIs + OSM's wider 5km
  coverage → fuller list). Overpass fetch extracted to `_getFromOverpass` (returns null on error;
  a real "couldn't load" error only surfaces when Overpass errors AND nothing else returned).
- TEST `test/places_merge_test.dart` — normalize + dedup-and-fill + keep-unique + same-name-far-apart.

### D — Popular times / "busy hours" — SPIKE, intentionally NOT built
- Finding: popular-times data is fundamentally Google-derived (Google Popular Times / `populartimes`
  GitHub scraper / Outscraper all read Google → prohibited in VN) OR commercial foot-traffic APIs
  (BestTime.app, Foursquare, Placer) which are **paid + sparse VN coverage**. No free VN-legal source.
- Decision: **don't fabricate a busy-hours chart** (violates the project's honesty principle, cf.
  R-007 "accuracy over prettiness"). The real-data slice of the same user need ("can I go now?")
  is already delivered by the A open-now badge. Revisit only if user accepts paying for BestTime.app.

### Images belonging to the location (user follow-up)
- Already correct via R-007: discovery rows + detail gallery both query Bing with **name + address**
  (most specific) and run the relevance filter (drops photos whose haystack doesn't mention a
  distinctive venue token). No code change needed; C's field-merge enriches `address`, which makes
  the image query more specific → better photo accuracy as a side benefit.

## Files changed
**Backend (anmates-api):** services/venue_reviews.go (new), services/venue_reviews_test.go (new),
handlers/venue_reviews.go (new), main.go (route registration).
**Flutter (anmates_flutter):** utils/opening_hours.dart (new), widgets/open_now_badge.dart (new),
services/venue_reviews_service.dart (new), services/places_service.dart (merge), views/discover/
venue_detail_view.dart (badge + reviews), views/discover/discover_view.dart (badge),
test/opening_hours_test.dart (new), test/places_merge_test.dart (new).

## Verification
- Go (golang:1.25, Docker): `go build ./...` clean, `go vet ./...` clean, `go test ./services/...`
  **ok** (incl. new venue_reviews_test.go). Docker daemon had to be started this session.
- Flutter (C:\src\flutter): `flutter analyze` on all changed files → only 5 PRE-EXISTING `info`
  lints in the untouched `OsmPlace.emoji` getter; new code clean. `flutter test` opening_hours +
  places_merge → **11/11 pass**.
- Host has no Go/Flutter on PATH (Docker for Go; C:\src\flutter for Dart).

## Open follow-ups
- LIVE confirm (pending user, run `./start.sh` → http://127.0.0.1:54180):
  - A badge renders on OSM-sourced rows + detail; correct open/closed vs current time.
  - B "CẢM NHẬN TỪ CỘNG ĐỒNG" populates for a known venue (e.g. "Lẩu Bò Giáo Toàn") — Bing scrape
    can be sparse/blank for obscure quán; degrades to no section. Rating only shows when parseable.
  - C list is fuller / no visible duplicates once TOMTOM_API_KEY is set (merge active; without the
    key it's OSM-only = prior behaviour).
- TomTom path: add opening_hours (so A works there too) — see A note.
- Bing web-result HTML structure can drift → reviews parser may need a refresh; it fails safe (empty).
- When user confirms → migrate to a resolution (next free R-008): tags
  `venue-reviews`/`opening-hours`/`web-search`/`bing`/`discovery`/`flutter`/`go-backend`.
