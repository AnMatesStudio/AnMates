# Session: Discovery Location-Aware Search Ranking

**Date:** 2026-06-10  
**Owner:** main-assistant  
**Status:** Completed (code-only, waiting for e2e verification)

## Goal
Implement location-aware ranking for web-search venue results in the Discovery board. Ensure results are sorted by distance to user (nearest first) and optionally filtered by max distance.

## Current Status
Web-search discovery (`discover_view.dart`) was already implemented with `/api/v1/venues/search` endpoint, but results were returned in web-search order (relevance, not proximity). Users at a given location saw distant venues ranked above nearby ones.

## Changes Implemented

### Backend — Go Handler
**File:** `anmates-api/handlers/venue.go`

Added two new query parameters:
- `sort_by_distance` (bool, default=true) — sort by distance ascending (nearest first)
- `max_distance_m` (int, default=10000) — filter out venues >X meters away

Added `filterAndSortPicks()` helper that:
1. Filters results to exclude venues beyond max distance threshold
2. Sorts filtered list by `distanceM` (ascending) if `sort_by_distance=true`
3. Returns sorted/filtered picks to client

Applied to both cached and fresh search results.

### Frontend — Flutter Discovery View
**File:** `anmates_flutter/lib/views/discover/discover_view.dart`

In `_buildSearchResults()`:
- Create sorted copy of results before display: `List<VenueResult>.from(results)..sort((a, b) => a.distanceM.compareTo(b.distanceM))`
- Display sorted results in indexed loop (nearest result first)
- Provides defense-in-depth (client-side sort even if backend sorting is disabled)

### Frontend — Service Layer
**File:** `anmates_flutter/lib/services/venue_search_service.dart`

Updated `search()` method signature:
- Added `sortByDistance` parameter (bool, default=true)
- Added `maxDistanceM` parameter (int, default=10000)
- Passes both as query params to `/api/v1/venues/search` endpoint
- Future-proofs API for user-facing distance filters (e.g., "≤5km" chip)

## How It Works

**Search Flow:**
```
User types "phở" → TextField submit → _submitSearch("phở")
  → VenueSearchService.search("phở", lat=10.77, lng=106.70)
    → GET /api/v1/venues/search?q=phở&lat=10.77&lng=106.70&sort_by_distance=true&max_distance_m=10000
      → Go handler filters & sorts picks by distance
        → DuckDuckGo web search → structurer → forward-geocode (already calculates distanceM)
        → filterAndSortPicks([...]) → sorted by distanceM
      → Returns [Venue{name:"Phở Hòa Nha", distance_m: 450}, Venue{name:"Phở Lệ", distance_m: 890}, ...]
    → Flutter receives sorted list
    → _buildSearchResults() re-sorts locally (idempotent, ensures display order)
    → _VenueResultRow displays with distance label (already shown via _subLine)
```

## Verification (Pending)

### E2E Test
- Search "phở" near user location (lat=10.77, lng=106.70, Quận 1)
- Verify results are sorted by distance ascending (1st result ≤ 2nd result ≤ 3rd...)
- Verify all results have distance_m ≤ 10,000m (default max)

### Manual Test
- Open Discovery board
- Search "lẩu" (should return 6-10 lẩu venues)
- Verify first result is closest (distance in km shown)
- Verify order by distance (no 5km venue appearing before 1km venue)

### Test max_distance_m filtering
- Search with `max_distance_m=3000` (3km)
- Verify no results show distance > 3km

## Files Changed
1. `anmates-api/handlers/venue.go` — added sort/filter params + filterAndSortPicks()
2. `anmates_flutter/lib/views/discover/discover_view.dart` — client-side sort in _buildSearchResults()
3. `anmates_flutter/lib/services/venue_search_service.dart` — added params to search() signature

## Notes
- **No sidecar changes needed** — Python `ai-venue-search` already calculates `distanceM` via haversine in `_enrich_coords()`
- **Cache impact** — Go cache now stores pre-sorted results; multiple clients with same query see identical order (correct)
- **Backward compatible** — default params ensure existing callers (if any) get nearest-first behavior automatically
- **Client-side re-sort** — Flutter sorts again locally (idempotent + defense-in-depth)

## Next Steps (User)
1. Verify e2e: run `.dev-e2e/` tests or manual Discovery search
2. If approved → write resolution R-007
3. Consider UI enhancement: optional "distance filter" chip (≤5km / ≤10km / All)
