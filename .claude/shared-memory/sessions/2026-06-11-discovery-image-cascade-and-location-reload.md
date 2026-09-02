# 2026-06-11 — Discovery: revert photo-gate → guaranteed image cascade + location reload

## TL;DR
Two user asks: (1) revert the "drop venues without photos" gate; instead **guarantee every venue has
an image** via a priority cascade (real venue photo → website → category-relevant F&B photo →
never NSFW/non-F&B); (2) on first web visit the location-permission prompt resolves AFTER the initial
venue load, so venues loaded at the fallback city and never refreshed — **reload the API once
permission is granted**.

## Task 1 — image cascade (always an image)
- **Reverted the Flutter photo-gate** (`_photoOk`/`_scanPhotos`/`_withPhotos` removed; list shows
  all `_filteredPlaces` again). Kept the **cleaned query** (`venueImageQuery`/`shortVenueAddress` —
  name + first 2 distinct non-postal address segments) since it helps find real photos.
- **Restored the category fallback** in `services/venue_image.go` `crawl`: real venue photos
  (relevance-filtered) → if none, `crawlCategory` (generic F&B query per `categoryStockQuery`, rotated
  per-venue via `rotateByKey` to avoid identical thumbnails). Every branch of `categoryStockQuery` is
  food/drink → fallback is always F&B-relevant.
- **Safety (rule 4):** added NSFW/adult markers to `junkImageMarkers`
  (porn/xxx/sex/nude/nsfw/adult/erotic/pornhub/onlyfans/…) → such images are dropped from both the
  real and fallback paths.
- **Reliability fix (the key one):** caching was OFF (`VENUE_IMAGE_CACHE_TTL` default 0, set by a
  parallel session for "realtime"). With caching off, each render re-crawls Bing live → flaky `count:0`
  (observed 1,1,0). Fixes: (a) `store()` now **never caches an empty result** (a transient miss can't
  pin a venue to "no image"); (b) set **`VENUE_IMAGE_CACHE_TTL=24h`** in `.env`/`.env.example` so the
  list thumbnail path is cached → first successful resolve sticks. The agentic DETAIL hero stays
  uncached/realtime (separate path). Removed now-unused `imageEmptyCacheTTL`.
- Note: "Google Maps photo" (priority 1) isn't separately scrapable for the list; the name+address
  Bing search surfaces the venue's web/Maps-indexed photos when they exist, and the detail screen has
  the parallel agentic Google crawl.

## Task 2 — reload venues after location grant (`discover_view.dart`)
- `_loadNearby` gained an optional `coordsOverride`. NEW `_initLocationAndLoad` (called from
  initState instead of `_loadNearby`): does the fast first load (fallback city if permission not yet
  granted), then **polls `LocationService().currentLatLng()` once/sec up to 12×**; the moment a real
  position is available (user tapped "Allow"), it **reloads venues at the real coords** and stops.
  Stops early once `_usingFallbackLocation` is false. On web, `requestPermission()` can return before
  the user decides, so this catches the late grant. `PlacesService` cache tolerance (0.005°) means the
  real-coord reload refetches (different location).

## Verification
- Go `gofmt` + build + services tests GREEN (golang:1.25). api rebuilt + restarted (project `anmates`).
- After cache on: "Café Nhạc Tình Nhi" → count **1,1,1,1** (was flaky 1,1,0). Nga Tea→1, Cơm Tấm→5.
- Flutter: IDE diagnostics clean; gate refs fully removed. **NOT** flutter-analyzed (no host PATH).
- **PENDING (user):** `./start.sh` (local API = these changes) → every list venue shows an image;
  grant location late → list reloads at real position. ⚠️ Screenshot earlier hit **production** Cloud
  Run — deploy or run local to see changes.

## Caveats
- Category fallback shows a real F&B photo that is NOT the actual venue (priority 3, by design).
- Heavy parallel work in flight (agentic enrichment detail hero, reviews, TomTom+Overpass merge) — this
  change is the list image cascade + location reload, complementary.
