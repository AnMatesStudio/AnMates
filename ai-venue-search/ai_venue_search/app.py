"""FastAPI entrypoint. Run: `uvicorn ai_venue_search.app:app --port 8090`."""

from __future__ import annotations

import logging

from fastapi import FastAPI, HTTPException

from . import __version__, config
from .schemas import SuggestRequest, SuggestResponse
from .service import VenueSearchService

logging.basicConfig(level=logging.INFO)

settings = config.load()
app = FastAPI(title="AnMates AI Venue Search", version=__version__)
service = VenueSearchService(settings)


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
