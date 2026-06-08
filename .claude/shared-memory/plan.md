# Plan — Discovery web-search for local Saigon venues (reuse ai-venue-search sidecar)

**Owner:** coder
**Requested by:** user — search local Saigon quán via web-search (OSM misses long-tail local quán e.g. "Bún Bò Giáo Toàn"). User picked the **web-search (reuse sidecar)** option.
**Spans:** Python sidecar (`ai-venue-search/`) + Go (`anmates-api/`) + Flutter (`anmates_flutter/`). Do NOT spawn sub-agents.
**Reuse, don't rebuild:** the `ai-venue-search` sidecar already does web-search → LLM structurer → geocode for the AI Concierge. We add a free-text path and surface it in Discovery.

## Latency/cost reality (drives the UX decisions below)
Web-search is slow (2–10s, sidecar timeout 55s) and lat/lng often missing (R-006). So: fire the remote search **only on explicit submit** (Enter / search-icon tap), min query length 2, with a loading state; keep the instant OSM client-filter for typing feedback; cache results on the Go side.

---

## PART A — Sidecar (Python, `ai-venue-search/ai_venue_search/`)

### A1. `schemas.py`
- Add to `SuggestRequest`: `query: str = ""` (free-text search term; empty = concierge mode, unchanged).

### A2. `service.py` → `build_query`
- When `req.query` is set, make it query-led:
  `f"{req.query} quán ăn {where}".strip()` (where = `ở {area}` or `gần toạ độ …`, as today).
- When `req.query` empty → current mood-led behavior (don't break concierge).

### A3. `providers/structurer.py` → `_user_prompt`
- Additive: if `req.query`, prepend a line:
  `f'NGƯỜI DÙNG ĐANG TÌM: "{req.query}" — ưu tiên các quán đúng món/tên này từ kết quả search.\n'`
- Do NOT change `_SYSTEM_PROMPT` rules (the anti-hallucination + "bóc tên quán cụ thể, không dùng tiêu đề bài viết" + no-CJK + no-ward-name rules all still apply and are what we want). Concierge sends empty query → prompt unchanged.

### A4. `app.py`
- Add `POST /search` (response_model `SuggestResponse`) that just calls `service.suggest(req)` (thin wrapper; same 502-on-error mapping as `/suggest`). Lets the Go client be explicit and future-tunable.

### A5. tests
- Add a pytest in `ai-venue-search/tests/` asserting `build_query` is query-led when `query` set (e.g. contains "bún bò giáo toàn") and mood-led when not. Keep it offline (no network).

---

## PART B — Go backend (`anmates-api/`)

### B1. `services/search_client.go`
- Add `Query string \`json:"query"\`` to `searchReq`.
- Refactor the pick-mapping loop in `Suggest` into a shared helper `mapPicks(parsed searchResp, origin LatLng) []CardPick` (recompute distance from `origin` when coords present — reuse existing logic).
- Add method:
  `func (p *WebSearchProvider) SearchText(ctx context.Context, query string, loc LatLng, radiusM, limit int) ([]CardPick, error)`
  → POST `p.baseURL+"/search"` with `searchReq{Query: query, Lat: loc.Lat, Lng: loc.Lng, RadiusM: radiusM, MoodTags: []string{}, Limit: limit}` → parse → `mapPicks(parsed, loc)`.

### B2. New handler `handlers/venue.go`
- `type Venue struct { provider *services.WebSearchProvider; cache ... }` with `NewVenue(provider)`.
- `func (h *Venue) Search(c *fiber.Ctx) error` for `GET /api/v1/venues/search`:
  - `q := strings.TrimSpace(c.Query("q"))`; require `len([]rune(q)) >= 2` else 400 "query too short".
  - parse `lat`/`lng` floats (optional; default 0,0 → sidecar still searches by text, just no distance). `radius_m` default 4000, `limit` default 6 (cap 10).
  - Simple in-memory cache (map + mutex) keyed by `lower(q)|round(lat,3)|round(lng,3)`, TTL ~10 min, to avoid repeat slow/expensive calls. Evict on TTL.
  - `ctx` timeout ~60s. Call `provider.SearchText`. On error → 502 `httputil.Err(... "search failed")`. On success → `httputil.OK(c, picks)`.

### B3. `main.go`
- Where the concierge is wired (`if cfg.AISearchURL != ""`), also build the web provider once and register:
  ```go
  if cfg.AISearchURL != "" {
      webProvider := services.NewWebSearchProvider(cfg.AISearchURL) // or reuse the one made for concierge
      venueH := handlers.NewVenue(webProvider)
      auth.Get("/venues/search", venueH.Search)
  }
  ```
  (Keep concierge wiring intact. If the concierge already constructs a WebSearchProvider, reuse that instance.)
- This route is **authenticated** (under the `auth` group) — verify it returns 401 without a token (auth gate was just fixed in BLOCKER-005).

### B4. tests
- Extend `services/search_client_test.go` (httptest) with a `/search` case: stub the sidecar returning 1 venue → assert `SearchText` parses + distance recompute. No live network.

---

## PART C — Flutter (`anmates_flutter/`)

### C1. New `lib/services/venue_search_service.dart`
- Model `VenueResult { name, address, lat, lng, distanceM, rating, priceMin, priceMax, reason }` with `fromJson`.
- `Future<List<VenueResult>> search(String q, {double? lat, double? lng})` → `ApiClient().get('/api/v1/venues/search?q=...&lat=...&lng=...')`. Throw/propagate ApiException; caller handles.

### C2. `views/discover/discover_view.dart`
- Keep the current OSM nearby browse + instant client-filter while typing.
- Add **remote search on submit**: `TextField.onSubmitted` (and/or tapping the 🔍) → if `q.length >= 2`, call `VenueSearchService().search(q, _userLat, _userLng)`:
  - show a loading state ("Đang tìm quán trên web…"),
  - on success render results as `_RestaurantRow`s in the list area (a "KẾT QUẢ TÌM KIẾM" section header), with empty ("Không tìm thấy '<q>'") and error ("Lỗi tìm kiếm — thử lại") states,
  - **distance guard:** show distance only when `lat/lng != 0` (ISSUE-9); otherwise show `address` text instead of a bogus "0m".
  - tap a result → `MapsLauncher.open(name, address, lat, lng)`.
- Clearing the search box → return to OSM nearby browse.
- Don't fire remote search on every keystroke (cost/latency) — submit-only.

---

## Constraints
- Concierge / booking / matching / AI card behavior must stay identical (empty `query` = old path).
- Keep the sidecar's anti-hallucination + no-ward-name + no-CJK rules (don't weaken `_SYSTEM_PROMPT`).
- Mirror field names across schemas.py ↔ search_client.go ↔ venue_search_service.dart (the file headers say to keep them in sync).

## Verification gate (coder runs before finishing)
1. Sidecar: `pytest` in `ai-venue-search/` (new build_query test passes); rebuild `docker compose build ai_venue_search`.
2. Go: `docker compose build api` (rc=0) + `go test ./services/... ./middleware/...` pass.
3. Flutter: `flutter analyze` 0 errors + build web; rebuild `docker compose build flutter_web`.
4. **Live E2E (LM Studio must be up — it is):** with a dev-login token,
   `GET /api/v1/venues/search?q=bún%20bò%20giáo%20toàn&lat=10.7769&lng=106.7009` → 200 with picks (report exactly what venues come back — this is the user's acceptance test). Also try `q=lẩu dê` to sanity-check a common term.
   - And `GET /api/v1/venues/search` with NO token → 401.
5. `docker compose up -d` all rebuilt services; confirm healthy.
6. Append a `changelog.md` row; update `api-contracts.md` with the new `GET /venues/search` endpoint.

## Notes / future (out of scope)
- If web-search proves too slow/unreliable for a search box at scale, Goong Places is the upgrade path (accurate coords, <300ms) — defer.
- Coords from web-search are best-effort; missing-coord results are expected and handled by the distance guard.
