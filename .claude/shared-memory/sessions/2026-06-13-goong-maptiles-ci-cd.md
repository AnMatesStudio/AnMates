# 2026-06-13 — Goong Maptiles key → CI/CD (Flutter web) wiring

## TL;DR
Kicked off the **"Bản đồ" (in-app Goong map)** feature. User picked **Goong tiles only** +
a **new 5th bottom tab**. First slice delivered: **CI/CD now injects `GOONG_MAPTILES_KEY`
into the Flutter web build** so the deployed map can render. Map UI itself NOT built yet
(next phase). Config-only; pending the user creating the GH repo secret.

## Context / decision
- The Discovery list already uses Goong **REST** (`GOONG_API_KEY`, server-side) for venue
  data. Rendering an **interactive map** needs Goong **Maptiles** — a *different* key type.
- Live-probed with the keys in `.env`:
  - REST key (`GOONG_API_KEY`): Place autocomplete ✅ 200, geocode ✅ 200; tiles ✗ 403.
  - **Maptiles key (`GOONG_MAPTILES_KEY=…ViTL`): `tiles.goong.io/assets/goong_map_web.json`
    ✅ 200 (vector style JSON).** Raster `.png` paths → 404 ⇒ **Goong Maptiles is VECTOR**,
    not raster XYZ. Flutter side will render via a vector style (e.g. `vector_map_tiles` +
    the Goong style JSON), NOT a plain `TileLayer(urlTemplate:…png)`. (For the IMPL phase.)
- Maptiles key is consumed **client-side** (baked into the web bundle), so it must reach the
  Flutter build via `--dart-define`, and CI/CD must supply it from a GH secret.

## Changes (this session — CI/CD + docs only)
- `.github/workflows/cd.flutter-web.yml` (prod) — `flutter build web` step: added
  `--dart-define=GOONG_MAPTILES_KEY=${{ secrets.GOONG_MAPTILES_KEY }}`.
- `.github/workflows/ci.flutter-web.yml` (deploy-dev, same-repo PR) — same dart-define added.
- `.env.example` — documented `GOONG_MAPTILES_KEY` (distinct from `GOONG_API_KEY`; Maptiles
  Key from account.goong.io; empty = blank map since "Goong tiles only", no OSM fallback).
- `.github/CI-CD.md` — added `GOONG_MAPTILES_KEY` row to the repo-secrets table.

Chose **secret** (not var) for consistency with `GOONG_API_KEY`/`TOMTOM_API_KEY` and because
it gates billable quota. Empty-when-unset → `${{ secrets… }}` expands to "" → build passes,
map blank (safe-before-secret-exists pattern, same as the earlier TomTom add).

## Verification
- Both Flutter-web workflows parse as valid YAML (js-yaml). Edits are plain text inside the
  existing `run: |` block scalar (shell line-continuation) — no structural change.
- Tile feasibility confirmed live: style JSON 200 with the real Maptiles key.

## PENDING
1. **User:** create GH repo secret `GOONG_MAPTILES_KEY` (Settings → Secrets and variables →
   Actions). Without it, deployed map is blank.
2. **Local dev wiring (next):** pass `--dart-define=GOONG_MAPTILES_KEY` in `start.sh` /
   `docker-compose.yml` for the local Flutter web container.
3. **Feature impl (next phase):** new `views/map/map_view.dart`, 5th "Bản đồ" tab in
   `MainTabView` + `AnmTabBar` (4→5), Goong **vector** style render via flutter_map, markers
   from existing `PlacesService.getNearby`, tap pin → mini-card → `VenueDetailView`. Design
   approved in-chat; spec doc still to be written (brainstorming → writing-plans).
