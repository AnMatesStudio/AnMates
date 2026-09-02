# Agentic venue enrichment — realtime Google crawl + LLM-verified photos (cache off)

**Date:** 2026-06-11 · **Owner:** main-assistant · **Status:** code done, static-verified, PENDING live confirm

## TL;DR
User opened a venue detail ("Surgeon Bbq Curry", North Bridge Road Singapore) and the hero photo was an **operating room** — totally unrelated to a food venue. Ask: **(1) turn off the image cache, (2) build an agentic AI that crawls images + venue info realtime from Google search.** User explicitly chose **headless-browser scraping** (Playwright) for the Google access method (warned: datacenter IPs hit CAPTCHA → graceful fallback).

## Root cause
The Bing image path (`services/venue_image.go`) used a **string-match** relevance filter (`filterRelevantImages` on `significantTokens`). The token `surgeon` literally matches surgery photos → they pass. String matching can't know the venue should be *food*. Only an LLM (semantic) can. Also the venue is fake/seed data (Singapore, weird name) → no real photos exist, so the honest outcome is a **placeholder**, not an operating room.

## Solution — a 3-layer vertical slice

### Sidecar (ai-venue-search/) — the agentic core
- **`providers/google_scrape.py`** `GoogleCrawler`: headless Chromium (Playwright) drives **google.com web search** to FIND a venue's own pages → fetches them with httpx → extracts photos (`og:image` + content `<img>` w/ alt) + body text. Sourcing images **only from food-relevant venue pages** structurally avoids the surgeon bug (we never crawl an operating-room page for a restaurant). Handles consent interstitial + `/sorry/` CAPTCHA → returns empty; **Bing httpx web-search fallback** when Google is blocked. Reuses `_blocked_domain/_food_relevant/_looks_like_error` from `search.py`.
- **`enrich.py`** `VenueEnricher`: agentic loop — `_plan_queries` (most-specific first) → crawl → **LLM verify+extract** (`_llm_judge`, strict json_schema over the existing Ollama/LLM_BASE_URL): given venue identity + per-page context + numbered candidate images, returns `is_food_venue`, `keep_image_indices` (rejects non-food), and extracted `info` (cuisine/address/description/hours/phone/rating/price). **Reflect/retry** with the next query when too few candidates. Heuristic fallback (keep food-page images) when LLM down — still safe because candidates were sourced from food pages only.
- **`schemas.py`**: `EnrichRequest`, `EnrichedImage`, `EnrichedInfo`, `EnrichResponse` (`is_food_venue` verdict).
- **`app.py`**: `POST /enrich` — never 502s, returns empty payload on failure.
- **`config.py`**: `ENRICH_*` knobs (headless, nav timeout, max pages, max iterations, bing fallback).
- **`requirements.txt`** + **`Dockerfile`**: add `playwright` + `playwright install --with-deps chromium || true` (best-effort; falls back to Bing if missing).
- **`docker-compose.yml`**: `ENRICH_*` env on `ai_venue_search`.
- **Tests** `tests/test_enrich.py` (12): query planning, image extraction (og + content, junk/data-uri drop, dedup, relative absolutize), Bing SERP parse, hit dedup (drops engine-internal), visible-text strip, LLM-verdict JSON parse, candidate flattening. **35/35 sidecar pytest GREEN.**

### Go backend (anmates-api/)
- **`services/venue_enrich.go`** `VenueEnricher`: HTTP client → sidecar `/enrich` (80s timeout for Playwright+LLM). `Enabled()` gates on `AISearchURL`. **No cache here — realtime by design.**
- **`services/venue_image.go`**: **cache OFF** — `ImageSearcher.ttl` now from `VENUE_IMAGE_CACHE_TTL` (default **0 = disabled**; the old hardcoded 24h `imageCacheTTL` is gone). Added **`IsPublicHTTPImageURL(ctx, raw)`** SSRF guard (scheme http(s) + context-aware DNS resolve, rejects loopback/RFC1918/link-local/multicast/ULA/unspecified incl. cloud-metadata 169.254.169.254).
- **`handlers/venue_image.go`**: `Serve` now resolves via `resolveRemote(ctx, c)` — **new `?u=<base64url remote>` mode** (SSRF-guarded, streams that exact image → realtime + consistent, no cache) alongside legacy `?q=&i=` Bing path. `decodeProxyURL` accepts raw + padded base64url.
- **`handlers/venue_enrich.go`** `VenueEnrich.Serve`: `GET /api/v1/venues/enrich?q=&address=&city=&lat=&lng=` → `httputil.OK(EnrichResult)`. Public router (before jwtMW), degrades to empty (never 5xx).
- **`main.go`**: register `/api/v1/venues/enrich` next to the image proxy; wire `NewVenueEnricher(cfg.AISearchURL)`.
- **Tests**: `TestIsPublicHTTPImageURL` (public IP literals pass; loopback/private/link-local/ULA/unspecified/non-http/cloud-metadata blocked). **build + vet + golangci-lint v2.12.2 = 0 issues; services/handlers/middleware unit tests GREEN.**

### Flutter (anmates_flutter/)
- **`services/api_client.dart`**: `imageProxyUrl(remote)` — base64url-unpadded encode → `…/venues/image?u=…` (matches Go `RawURLEncoding`).
- **`services/venue_enrich_service.dart`** (new): `VenueEnrichment{imageUrls, info, isFoodVenue, intro}` + `VenueEnrichInfo`; calls `/venues/enrich`, wraps remote URLs via `imageProxyUrl`, degrades to `.empty` on error.
- **`widgets/venue_thumbnail.dart`**: optional `imageUrl` param (direct URL takes precedence over `query`+`index`); `query` now optional.
- **`views/discover/venue_detail_view.dart`**: `_d` now **mutable** (was `get => widget.data`); `initState` calls `_loadEnrichment()` → if `hasImages`, hero gallery switches to verified photos (`imageUrl:` per page) + `_d = _d.withEnrichment(info)` (fills only blank fields, on-device values win); **else falls back to the old Bing `_loadImageCount` gallery**. New `VenueDetailData.withEnrichment`.

## Data flow (detail open)
Flutter `VenueEnrichService.enrich` → `GET /venues/enrich` → Go `VenueEnricher` → sidecar `POST /enrich` → headless Google crawl (Bing fallback) → LLM verify/extract → `{images:[remote url], info, is_food_venue}` → Flutter wraps each remote in `?u=` proxy URL → hero gallery renders bytes via SSRF-guarded proxy. **No server cache anywhere on this path.**

## Verification
- Sidecar: **35/35 pytest** GREEN (Docker python:3.12-slim); `py_compile` all changed modules OK.
- Go: **build + vet GREEN**, **golangci-lint v2.12.2 → 0 issues**, services/handlers/middleware unit tests pass (the 4 `smoke` failures need a live :8080 — expected in a build container).
- Flutter: **NOT analyzed on host** (no Flutter PATH) — verify via `./start.sh`.

## PENDING (user)
- `./start.sh` (rebuilds sidecar w/ Chromium — first build pulls ~300MB + the model) → open a **real** venue's detail → confirm the hero shows real, relevant food photos + enriched facts; open the fake "Surgeon Bbq Curry" → confirm it now shows a **placeholder** (no operating room).
- When confirmed → migrate to **R-008** (tags: `venue-image`, `agentic`, `playwright`, `google-scrape`, `llm-verify`, `ssrf`, `cache`, `flutter`).

## Key facts / caveats
- **Enabled by default in docker** (compose sets `AI_SEARCH_URL=http://ai_venue_search:8090`). To re-enable a short image cache: `VENUE_IMAGE_CACHE_TTL=10m`.
- **Cloud Run / prod**: datacenter IP → Google likely CAPTCHAs → **Bing httpx fallback** kicks in, and the **LLM still verifies** those candidates (so the surgeon bug stays fixed regardless of source). Playwright Chromium adds ~300MB to the sidecar image; if `playwright install` fails the service still boots (Bing-only).
- LLM verify reuses the same Ollama (`LLM_BASE_URL`) the structurer uses — no new model needed. Quality of the verdict scales with the model (qwen2.5:3b default; bump `OLLAMA_MODEL` for sharper extraction).
- Honesty preserved: a venue with no real food photos → empty → placeholder, never a misleading stock image. Related: [[R-007]] (Bing relevance/fallback path this supersedes for the detail hero).
