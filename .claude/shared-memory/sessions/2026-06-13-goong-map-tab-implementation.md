# 2026-06-13 — "Bản đồ" tab: in-app Goong vector map with restaurant markers

## TL;DR
Built the **new "Bản đồ" bottom tab** — a full-screen interactive **Goong Maptiles**
map that drops personalized restaurant **markers** (same data as the Discovery list).
Tap a pin → mini-card → existing `VenueDetailView`. Code done + static-verified
(`flutter analyze` clean on changed files, `flutter build web` GREEN). Live in-app
visual confirm PENDING (user `./start.sh`).

## Decisions / findings
- **Goong Maptiles is VECTOR-only** (style `goong_map_web.json` 200; raster `.png`
  404). Sources: `base` (low-zoom) + `composite` (city-zoom roads/POI/labels, pbf,
  minzoom5/maxzoom16). Rendered in **flutter_map** via the **`vector_map_tiles`**
  plugin pointed at the Goong MapLibre style.
- **Plugin version is critical**: `vector_map_tiles 10.x` needs `flutter_gpu` +
  Flutter **main channel** + Impeller → NOT usable on our stable, web-first build.
  Pinned **`>=9.0.0-beta.9 <10.0.0`** → 9.0.0-beta.9 uses the mature CPU/canvas
  renderer `vector_tile_renderer 6.1.0` (web-compatible) and keeps flutter_map at
  8.3.0 (no downgrade).
- **Key plumbing** (verified live with the real Maptiles key): pass
  `StyleReader(uri: '…goong_map_web.json?api_key={key}', apiKey: kGoongMaptilesKey)` —
  `StyleUriMapper` swaps the literal `{key}` token, and Goong bakes the same key into
  the source/tile/sprite URLs it returns. `TileOffset.mapbox` (512px scheme).
- **Markers ARE the recommendations**: reuse `PlacesService.getNearby` (backend Goong
  provider, personalized by onboarding tags) — zero new backend.

## Files
- NEW `lib/views/map/map_view.dart` — `MapView`: FutureBuilder<Style> → `FlutterMap`
  + `VectorTileLayer` (Goong style) + `MarkerLayer` (venue pins + user dot) + Goong
  attribution. Loads venues+location like Discovery (web geolocation poll), recenter
  FAB, tap pin → bottom mini-card (`VenueThumbnail` + `OpenNowBadge`) → `VenueDetailView`.
  Blank-key notice + style-error retry. `kGoongMaptilesKey =
  String.fromEnvironment('GOONG_MAPTILES_KEY')`.
- `lib/views/main_tab_view.dart` — inserted `MapView()` at index 1.
- `lib/widgets/anm_widgets.dart` — `AnmTabBar` 4→5 items (added "Bản đồ",
  `Icons.map_outlined`) at index 1. Order: Khám phá · Bản đồ · Wishlist · Chat · Ăn Match.
- `pubspec.yaml` — `vector_map_tiles: ">=9.0.0-beta.9 <10.0.0"`.
- **Local dev dart-define chain** (mirrors API_BASE_URL): `anmates_flutter/Dockerfile`
  (`ARG GOONG_MAPTILES_KEY` + `--dart-define`), `docker-compose.yml` flutter_web build
  arg `GOONG_MAPTILES_KEY: ${GOONG_MAPTILES_KEY:-}`, `start.sh` exports it from `.env`.
- (CI/CD for the Maptiles key already done earlier today — see
  2026-06-13-goong-maptiles-ci-cd.md.)

## Verification
- `flutter analyze lib/` → 0 issues in changed files (9 infos are PRE-EXISTING in
  untouched booking_service/places_service/venue_search_service/ai_venue_card).
- `flutter build web --release --dart-define=GOONG_MAPTILES_KEY=…` → **✓ Built
  build/web** (exit 0; Wasm dry-run also passed). Confirms vector_map_tiles compiles
  for web + correct StyleReader/VectorTileLayer API usage.
- Tile pipeline live-probed earlier: style JSON 200, composite pbf 200 at HCM zooms,
  sprite/glyphs 200.

## PENDING (user)
- `./start.sh` (rebuilds flutter_web with the key) → log in → tap **Bản đồ** tab →
  confirm Goong tiles render + pins at real venues + tap pin → card → detail.
- When confirmed → migrate both 2026-06-13 Goong-map sessions into a resolution
  (tags: goong, maptiles, vector-tiles, flutter-map, vector_map_tiles, dart-define,
  bottom-tab, map-ui).

## Follow-ups / notes
- No widget test yet (MapView depends on StyleReader network) — optional follow-up.
- Maptiles key is embedded in the web bundle (normal for client map SDKs) → user
  should set a **referrer/domain restriction** in the Goong console.
- v1 has NO filter chips on the map (YAGNI; filters stay on Khám phá) — easy to add.
