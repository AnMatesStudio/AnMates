# AnMates AI Venue Search

A small, modular Python service that replaces the Go backend's map/DB venue
ingest for the AI Concierge. Given a midpoint + mood + budget it runs an **MCP
web-search**, lets a structurer turn the raw results into restaurant picks, and
returns them as JSON. No Goong/Maps ingest, no `restaurants` table to seed.

```
SuggestRequest
   │  reverse-geocode midpoint → area name (better query)
   ▼
build query ─▶ SearchProvider (MCP search + fetch top pages) ─▶ raw text
                                                                  │
                              Structurer (Pollinations→LM Studio) ◀┘   names + reasons
                                   │
                                   ▼
              forward-geocode each pick (name/address → real lat/lng, biased to
              midpoint, wrong-city results rejected)
                                   │
                                   ▼
              SuggestResponse  ──▶  Go ConciergeService ──▶ ai_venue_card
```

## 100% free, no API keys, no local model
The defaults cost nothing, need no keys, and need nothing running locally:
- **web search** → DuckDuckGo via MCP (`uvx duckduckgo-mcp-server`)
- **structurer** → **Pollinations** free OpenAI-compatible endpoint
  (`https://text.pollinations.ai/openai`, anonymous ≈1 req/15s) — sourced from
  [zebbern/no-cost-ai](https://github.com/zebbern/no-cost-ai).

Prefer a private / un-rate-limited model? Set `STRUCTURER=openai` to use a local
**LM Studio / Ollama** instead (still free, no key). `STRUCTURER=anthropic` uses
Claude (paid).

## Why two layers
- **SearchProvider** is dumb: query string → raw web text. Swap the MCP server
  (DuckDuckGo / Brave / Tavily / …) by changing `MCP_SERVER_CMD` — no code change.
- **Structurer** is the only part that "understands" venues: raw text → `Venue[]`.
  Swap the local model (or Claude) the same way via `STRUCTURER` / `LLM_BASE_URL`.

Either layer falls back to a **mock** automatically when its dependency is
missing (no MCP command → mock search; no local model URL / no Anthropic key →
mock structurer), so the service boots and answers with zero configuration.

## Grounding (so picks aren't hallucinated blog titles)
Raw web-search snippets are mostly listicle titles ("Top 20 quán lẩu…"), and a text
model can't know a venue's coordinates. Two enrichment steps fix this, all free:
- **Page fetch** (`MCP_FETCH_TOP_N`): after searching, the top result pages are
  fetched via the MCP `fetch_content` tool so the model sees real restaurant names +
  addresses, not just titles. The prompt forbids using article titles as venue names.
- **Geocoding** (`GEOCODE_ENABLED`, OpenStreetMap **Photon**, keyless): the midpoint is
  reverse-geocoded to a place name (better query), and each pick is forward-geocoded by
  name/address to a **real lat/lng**, biased toward the midpoint. A hit farther than
  60 km (wrong-city, same-named street) is rejected → the pick ships `lat/lng = 0`
  rather than a wrong pin.

### Known limits (free, no-API tradeoff — accepted by design)
- Some picks may still come back with `lat/lng = 0` when free geocoding can't place
  them confidently (better an empty pin than a wrong one).
- Venue names are grounded in fetched pages but not 100% guaranteed; ratings/prices are
  often null. This is the cost of using web search instead of a paid Places API.
- Pollinations' anonymous tier is heavily rate-limited (429); the LM Studio fallback
  carries it. For this project, `STRUCTURER=openai` makes LM Studio primary.

## Run

```bash
cd ai-venue-search
python -m venv .venv && . .venv/Scripts/activate   # Windows PowerShell: .venv\Scripts\Activate.ps1
pip install -r requirements.txt
cp .env.example .env   # free defaults — no keys to fill in

uvicorn ai_venue_search.app:app --port 8090
```

Free setup checklist: just have `uv` installed so `uvx duckduckgo-mcp-server` can
launch. The default Pollinations structurer needs no local model and no key. (If
you switch to `STRUCTURER=openai`, also run LM Studio/Ollama at `LLM_BASE_URL`.)

Point the Go backend at it with `AI_SEARCH_URL=http://127.0.0.1:8090` (or
`http://host.docker.internal:8090` from inside Docker).

## API

`POST /suggest`
```json
{ "lat": 10.77, "lng": 106.70, "radius_m": 4000,
  "budget_min": 80000, "budget_max": 150000,
  "mood_tags": ["lẩu", "chill"], "limit": 3 }
```
→
```json
{ "intro": "2 đứa hợp gu rồi nè! ...",
  "picks": [ { "name": "...", "address": "...", "rating": 4.6,
               "price_min": 120000, "price_max": 180000,
               "lat": 10.77, "lng": 106.70, "distance_m": 0, "reason": "..." } ],
  "cost_tokens": 0, "provider": "mcp+openai" }
```
`distance_m` is recomputed by the Go caller from the midpoint, so it may be 0 here.

`GET /health` → reports the effective providers.

## Config
See [.env.example](.env.example). Key vars: `SEARCH_PROVIDER`, `MCP_SERVER_CMD`,
`MCP_SEARCH_TOOL`, `STRUCTURER`, `LLM_BASE_URL`, `LLM_MODEL`. All default to the
free, keyless setup.
