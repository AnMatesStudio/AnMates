# 2026-06-11 — Discovery list: photo gate + cleaned image query

## TL;DR
User: use Bing with the venue **name + address from TomTom** to find the venue's real photo; if a
venue has **no suitable photo, drop it from the list**. Two Flutter-only changes: (1) clean the
over-verbose TomTom address in the image query so Bing can actually find photos; (2) gate the
Discovery list to only venues whose `/venues/images` count > 0.

## Problem seen
- Screenshot request hit **production Cloud Run** (`anmates-api-…run.app`), not the rebuilt local
  API — so local backend changes weren't even in play. Local API was also **down** at the time.
- The image query carried TomTom's full `freeformAddress`
  ("Cafe Góc Phố Đường Tam Bình, Hiệp Bình Chánh, Hồ Chí Minh, Hồ Chí Minh, 71315") → **over-specified
  → Bing 404**. TomTom confirmed earlier to have **no photos** of its own and a hard **100-result cap**.

## Changes (Flutter only — `discover_view.dart`, `venue_detail_view.dart`)
- **`venueImageQuery(place, area)` + `shortVenueAddress()`** (top-level in discover_view): trims the
  address to the first **two distinct, non-postal segments** (street + ward), dropping the repeated
  city and the postal code. `VenueDetailData._query` got the same trimming inline.
- **Photo gate:** `_photoOk` map (venue id → has-real-photo), `_scanPhotos(want)` probes
  genre/search-filtered candidates in parallel batches of 8 via `VenueImageService().count(...)`,
  recording true/false; `_withPhotos` = candidates with `_photoOk == true`. The list renders ONLY
  `_withPhotos`. Probe runs after load / on scroll / on filter change; results cached so switching
  filters never re-probes. Footer: spinner while scanning, else "Đã hiển thị N quán có ảnh gần bạn";
  empty state "Chưa tìm thấy quán có ảnh quanh đây". `_RestaurantRow._imageQuery` now uses the same
  `venueImageQuery` → cache hit + the thumbnail matches what the gate probed.

## ⚠️ Critical dependency
The gate only filters when the **backend returns count 0** for photo-less venues — i.e. only with the
latest backend where the **category-stock fallback was removed** (same-day change). The **deployed
production** API still has the fallback → returns a photo for everything → gate would filter nothing.
So Flutter + the fallback-removed backend must ship together (deploy, or run locally via `./start.sh`).

## Verification
- IDE diagnostics clean on both files. **NOT** flutter-analyzed (no host PATH) and **NOT** live-tested
  (local API down; app pointed at prod). Pending: `./start.sh` (local backend = fallback-removed) →
  Discovery list shows only photo-bearing venues, short list acceptable per user rule.

## Caveats / follow-ups
- List may be **short/sparse** in areas where few venues have findable web photos — this is the
  user's explicit rule ("không có hình thì không lấy vào list").
- Web-search result rows (`_VenueResultRow`) still use the full address query — left as-is (separate flow).
- Heavy parallel work in flight (agentic enrichment for the detail hero, reviews, TomTom+Overpass
  merge) — this change is the list-level gate, complementary to that.
