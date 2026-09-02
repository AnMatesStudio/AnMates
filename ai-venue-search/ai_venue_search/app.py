"""FastAPI entrypoint. Run: `uvicorn ai_venue_search.app:app --port 8090`."""

from __future__ import annotations

import logging

from fastapi import FastAPI, HTTPException

from . import __version__, config
from .enrich import VenueEnricher
from .schemas import EnrichRequest, EnrichResponse, SuggestRequest, SuggestResponse
from .service import VenueSearchService

logging.basicConfig(level=logging.INFO)

settings = config.load()
app = FastAPI(title="AnMates AI Venue Search", version=__version__)
service = VenueSearchService(settings)
enricher = VenueEnricher(settings)


@app.get("/health")
async def health() -> dict:
    return {
        "status": "ok",
        "search": settings.effective_search_provider(),
        "structurer": settings.effective_structurer(),
    }


@app.post("/suggest", response_model=SuggestResponse)
async def suggest(req: SuggestRequest) -> SuggestResponse:
    try:
        return await service.suggest(req)
    except Exception as e:  # noqa: BLE001 — surface a clean 502 to the Go caller
        logging.exception("suggest failed")
        raise HTTPException(status_code=502, detail=f"venue search failed: {e}") from e


@app.post("/search", response_model=SuggestResponse)
async def search(req: SuggestRequest) -> SuggestResponse:
    """Free-text Discovery path. Thin wrapper over suggest; `req.query` must be set
    by the caller (Go SearchText). Same 502-on-error semantics as /suggest."""
    try:
        return await service.suggest(req)
    except Exception as e:  # noqa: BLE001
        logging.exception("search failed")
        raise HTTPException(status_code=502, detail=f"venue search failed: {e}") from e


@app.post("/enrich", response_model=EnrichResponse)
async def enrich(req: EnrichRequest) -> EnrichResponse:
    """Agentic realtime crawl for ONE venue (detail screen): LLM-verified photos +
    facts from the live web. Never 502s — a failed/blocked crawl returns an empty
    payload (is_food_venue=false) so the Go caller falls back to its Bing path and
    the client shows an honest placeholder rather than an unrelated photo."""
    try:
        return await enricher.enrich(req)
    except Exception:  # noqa: BLE001 — enrichment is best-effort, degrade to empty
        logging.exception("enrich failed")
        return EnrichResponse(is_food_venue=False, provider="error")
