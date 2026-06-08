# 2026-06-04 — AI Concierge: swap map/DB venue source → MCP web-search

## TL;DR
User: "đổi chỗ vụ lấy API map của AI gợi ý đi ăn thành dùng MCP websearch, trả kết quả
để đỡ phải làm ba vụ API". Decision (via AskUserQuestion): build a **separate modular
Python API** that calls **MCP web-search**, and **drop** the anti-hallucination DB rule
(trust web-search data). Go concierge now calls that service instead of the
`restaurants` table + LLM ranking.

## What changed

### New: `ai-venue-search/` Python microservice (FastAPI)
- `POST /suggest {lat,lng,radius_m,budget_min,budget_max,mood_tags,limit}` →
  `{intro, picks:[{name,address,rating,price_min,price_max,lat,lng,distance_m,reason}], cost_tokens, provider}`.
- Two pluggable layers, each with an env-driven factory + automatic mock fallback:
  - **SearchProvider** (`providers/search.py`): `MCPWebSearchProvider` spawns an MCP
    web-search server over **stdio** (`MCP_SERVER_CMD`, e.g. Brave/Tavily) and calls its
    tool (`MCP_SEARCH_TOOL`/`MCP_QUERY_ARG`); `MockSearchProvider` for offline. Falls back
    to mock when `MCP_SERVER_CMD` empty.
  - **Structurer** (`providers/structurer.py`): default `OpenAICompatStructurer` (FREE,
    no key — calls local LM Studio/Ollama at `LLM_BASE_URL`, reasoning_content fallback);
    `AnthropicStructurer` (optional, paid, needs `ANTHROPIC_API_KEY`); `MockStructurer`
    (regex parse of the mock blob). Falls back to mock when its backend isn't configured.

### FREE / NO-KEY update (same session)
User: "tôi muốn làm free hết, không api key gì". Changed defaults to be 100% free/keyless:
- Web search default `MCP_SERVER_CMD=uvx duckduckgo-mcp-server` (DuckDuckGo MCP, free,
  no key; tool `search`, arg `query`). `uv` added to requirements for `uvx`.
- Structurer default `STRUCTURER=openai` → local LM Studio/Ollama
  (`LLM_BASE_URL=http://host.docker.internal:1234/v1`, `LLM_MODEL=qwen2.5-7b-instruct`,
  empty `LLM_API_KEY`). Anthropic demoted to optional (commented out in requirements).
- `.env.example`, README, Dockerfile (dropped Node, rely on `uv`) updated. No API keys
  anywhere in the default path.

### Applied github.com/zebbern/no-cost-ai (same session)
User shared the repo (a curated index of ~80 free AI services) and asked to apply it.
Most useful finding: **Pollinations** exposes a free, keyless, OpenAI-compatible chat
endpoint `https://text.pollinations.ai/openai` (anonymous ≈1 req/15s; models openai/
mistral/searchgpt). Applied:
- New structurer preset `STRUCTURER=pollinations` → reuses `OpenAICompatStructurer`
  (refactored to take an explicit full `chat_url` since Pollinations has no
  `/chat/completions` suffix) pointed at the Pollinations URL. **Now the DEFAULT** —
  needs no local model AND no key (only `uv` for the DDG MCP search server).
- Config: `POLLINATIONS_MODEL` (default "openai"), `POLLINATIONS_TOKEN` (optional, lifts
  rate limit). `STRUCTURER` default openai→pollinations.
- LM Studio (`STRUCTURER=openai`) kept as the robust/private/un-rate-limited option;
  Anthropic kept as paid option.
- Tradeoffs noted: Pollinations free tier is rate-limited (~1 req/15s) and lower quality
  than a dedicated model — fine for the once-per-match concierge fire; switch to LM
  Studio if load grows or for privacy. `searchgpt` model is a possible future
  single-call search+structure path (not implemented).
- `service.py` orchestrates query-build → search → structure. `app.py` = FastAPI.
- Boots with **zero config** in full mock mode (`/health` reports effective providers).
- `requirements.txt`, `Dockerfile` (python:3.12 + node for npx MCP servers), `.env.example`,
  `README.md`, `tests/test_mock_smoke.py`.

### Go (`anmates-api`)
- `services/concierge.go`: new `VenueProvider` interface
  `Suggest(ctx, mid, mood, budgetMin, budgetMax, radiusM, limit) (intro, []cardPick, cost, err)`.
  `ConciergeService` now holds a `provider VenueProvider` (was `llm`+`venues`); `fire()`
  calls `provider.Suggest`, drops in-flow `SearchCandidates`/`Rank`/`validatePicks`.
  Constructor signature changed → `NewConciergeService(pool, provider, hub, cfg, log)`.
- `services/search_client.go` (new): `WebSearchProvider` — HTTP client to the Python
  service. **Recomputes distance_m from the midpoint** (Haversine), drops empty-name
  picks, cleans reason via existing `safeReason` (CJK guard + clip). No DB id / no
  anti-hallucination (trusts web data, per user).
- `services/venue_provider.go` (new): `DBLLMVenueProvider` wraps the **legacy** path
  (restaurants table + LLM rank + `validatePicks`) — kept as fallback so existing tests
  + `venue.go`/`llm.go` stay live.
- `config/config.go`: new `AISearchURL` (`AI_SEARCH_URL`). Selection: `AI_SEARCH_URL` set
  ⇒ web-search; else `AI_BASE_URL` ⇒ legacy DB+LLM; neither ⇒ concierge disabled.
- `main.go`: wiring builds the right provider + logs `mode`.
- `services/search_client_test.go` (new): httptest coverage (mapping, distance recompute,
  empty-pick drop, non-200 → error).

### Flutter
- Only a doc-comment update in `lib/widgets/ai_venue_card.dart` (source is now MCP
  web-search, not DB). **JSON contract unchanged** (`intro`+`midpoint`+`picks`), so the
  model/widget/test need no functional change; `restaurant_id` already defaults to ''.

## LIVE VERIFICATION (Docker, 2026-06-04) — sidecar CONFIRMED WORKING
Built + ran the `ai-venue-search` image (Docker 28.5.1 on host) and hit `POST /suggest`
with a HCMC midpoint. End-to-end result: **HTTP 200, picks=3 then picks=2, clean
Vietnamese**, `provider=mcp+pollinations+openai`. Pipeline proven:
- DuckDuckGo MCP search (`uvx duckduckgo-mcp-server`, tool `search`) → real `html.duckduckgo.com` 200.
- Reverse geocode (Nominatim) → "Phường Sài Gòn, TP Hồ Chí Minh".
- Pollinations primary → **429 every time** (anonymous free tier is globally throttled).
- Fallback → LM Studio (`host.docker.internal:1234`, qwen/qwen3.5-9b) → 200, valid JSON.
- After prompt tuning, model returns concrete venue names ("Lẩu Dê 6 Tửng", "Ashima")
  instead of listicle titles.

Fixes made DURING live debugging (all in this session):
1. `geocode.py` — Nominatim reverse-geocode midpoint → district/city; query uses the
   place name (raw lat/lng gave near-useless DDG results). Best-effort, "" on failure.
2. `FallbackStructurer` — ordered chain pollinations→LM Studio; first success with ≥1
   venue wins. Needed because Pollinations anon 429s constantly.
3. LM Studio path uses a **strict `json_schema`** response_format (`_VENUE_SCHEMA`),
   NOT `json_object` (LM Studio returned 400 on json_object). Matches llm.go's approach.
4. Dockerfile pre-installs the DDG MCP server so first request doesn't pay the uvx
   download (would blow the caller timeout).

## LIMITATIONS ADDRESSED (2026-06-04, "xử lý hạn chế" — pre-Codex-review)
The three quality gaps above were then fixed and re-verified live:
1. **Grounded names/addresses** — `MCPWebSearchProvider` now also calls the DDG
   `fetch_content` tool on the top `MCP_FETCH_TOP_N` (default 2) result URLs and appends
   the page bodies (capped `MCP_FETCH_CHAR_CAP`) to the raw text. The prompt forbids
   using listicle titles as venue names. Result: real names (Haidilao, Kichi Kichi,
   Lẩu Lil' Sago) with real street addresses.
2. **Real, distinct map coordinates** — `geocode.py` switched Nominatim → **Photon**
   (komoot; OSM-based but resolves VN POIs/addresses Nominatim returns nothing for).
   `service._enrich_coords` ALWAYS forward-geocodes each pick (model coords are just the
   echoed midpoint), trying cleaned-street-address then "<name>, <area>". Photon results
   are biased to the midpoint (`lat`/`lon` params), coarse types (city/locality) are
   rejected, and a **haversine > 60 km guard** drops wrong-city matches (e.g. a "Lê Văn
   Sỹ" street in Hà Nội for a HCMC midpoint) → that pick ships `lat/lng=0` instead.
   `_clean_address` strips "Tầng…/Lầu…/B3…" and mall-name prefixes.
3. **Pollinations 429** — already covered by the FallbackStructurer → LM Studio.
Timeouts widened for the longer pipeline: sidecar `REQUEST_TIMEOUT_S=55`, Go
`WebSearchProvider` http client 70s, concierge fire context 75s.
Offline mock smoke test runs green inside the image (`GEOCODE_ENABLED=0`).

REMAINING LIMITATIONS (accepted free/no-API tradeoff):
- A pick can still come back `lat/lng=0` when Photon can't confidently place it (better
  empty than wrong). Go's WebSearchProvider leaves distance=0 for those.
- Ratings/prices often null; names grounded-in-page but not 100% guaranteed.
- Pollinations anon tier ≈unusable (429) — `STRUCTURER=openai` (set in repo .env) makes
  LM Studio primary and skips the wasted call.

## docker-compose integration (done)
- New service `ai_venue_search` (build ./ai-venue-search, 127.0.0.1:8090, python healthcheck,
  `extra_hosts: host.docker.internal:host-gateway`). Provider env vars overridable.
- `api` gets `AI_SEARCH_URL=http://ai_venue_search:8090` (env block, overrides .env) +
  `depends_on: ai_venue_search (healthy)`.
- `.env` + `.env.example` set/document `AI_SEARCH_URL`; legacy `AI_BASE_URL` commented.
- Run the whole stack: `./start.sh` or `docker compose up --build`.

## Verification (Go side still PENDING — host has neither Go nor Python on PATH)
Static checks done: no leftover `s.llm`/`s.venues` refs; `NewConciergeService` only built
in main.go; concierge.go imports all still used; new files' imports/symbols resolve.
Must run via Docker/CI:
- `cd anmates-api && GO111MODULE=on go build ./... && go vet ./... && go test ./...`
- `cd ai-venue-search && pip install -r requirements.txt && python tests/test_mock_smoke.py`
  (or `uvicorn ai_venue_search.app:app --port 8090` then curl `/suggest`).
- Flutter: `flutter analyze` / `flutter test` (no functional change expected).

## How to run end-to-end (dev)
1. `cd ai-venue-search`; set `.env` (mock works with nothing; for real: `MCP_SERVER_CMD`
   for a web-search MCP server + `ANTHROPIC_API_KEY`). `uvicorn ai_venue_search.app:app --port 8090`.
2. Backend env: `AI_SEARCH_URL=http://host.docker.internal:8090` (Docker) or
   `http://127.0.0.1:8090` (bare). `AI_BASE_URL` no longer needed for the web-search path.
3. 2 users + match + push locations + chat to points≥70 → expect one `ai_venue_card`.

## Open follow-ups
- Pick/confirm a concrete MCP web-search server (Brave needs `BRAVE_API_KEY`, Tavily needs
  `TAVILY_API_KEY`) and set `MCP_SERVER_CMD` accordingly.
- Coordinates from web search are approximate → midpoint distance is a rough estimate;
  fine for MVP. Map pins rely on the model returning lat/lng (mock jitters around midpoint).
- Legacy `restaurants` table / migration 006 + `venue.go` now unused by the live path but
  retained for the fallback; can be removed later if web-search becomes the only path.
- Spec `docs/specs/ai-concierge-chat-spec.md` still describes the DB anti-hallucination
  rule — update when this is user-confirmed.

## Key facts
- The Go backend cannot "use MCP" itself at runtime; MCP is a client/host protocol, so the
  MCP call lives in the Python sidecar. Go just speaks plain HTTP/JSON to it.
- Anti-hallucination guarantee was intentionally dropped on the web-search path per user
  ("Bỏ luôn, tin dữ liệu web search"); still enforced on the legacy DB path.
