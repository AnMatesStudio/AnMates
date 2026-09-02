"""Request/response contracts. Mirrors the Go `WebSearchProvider` client and the
Flutter `ai_venue_card` model — keep field names in sync across all three."""

from __future__ import annotations

from typing import List, Optional

from pydantic import BaseModel, Field


class SuggestRequest(BaseModel):
    """What the Go concierge asks for: where to look + the shared taste/budget.

    `query` is a free-text search term for the Discovery web-search path.
    Empty string (the default) = concierge mode — behaviour is unchanged.
    Mirror field name: search_client.go `searchReq.Query`, venue_search_service.dart."""

    lat: float = 0.0
    lng: float = 0.0
    radius_m: int = 4000
    budget_min: int = 0
    budget_max: int = 0
    mood_tags: List[str] = Field(default_factory=list)
    limit: int = 3
    query: str = ""


class Venue(BaseModel):
    """One restaurant pick. `lat`/`lng` are approximate (from web search), and
    `distance_m` is recomputed server-side by the Go caller from the midpoint."""

    name: str
    address: str = ""
    rating: Optional[float] = None
    price_min: Optional[int] = None
    price_max: Optional[int] = None
    lat: float = 0.0
    lng: float = 0.0
    distance_m: int = 0
    reason: str = ""


class SuggestResponse(BaseModel):
    intro: str = ""
    picks: List[Venue] = Field(default_factory=list)
    cost_tokens: int = 0
    provider: str = ""  # which search/structurer combo produced this (debug)


# --- Agentic venue enrichment (detail screen: realtime Google crawl) ----------


class EnrichRequest(BaseModel):
    """Ask the agent to crawl the live web for ONE specific venue's photos + facts.

    Sent by the Go backend when a user opens the detail screen. `address`/`city`
    sharpen the search so a generic name resolves to the right place; `lat`/`lng`
    are optional context only (the agent works from the name + address)."""

    name: str
    address: str = ""
    city: str = ""
    lat: float = 0.0
    lng: float = 0.0
    max_images: int = 6


class EnrichedImage(BaseModel):
    """One verified venue photo. `url` is the direct remote image (the Go proxy
    re-fetches the bytes); `source` is the page it was found on; `caption` is the
    alt/title text used to judge relevance."""

    url: str
    source: str = ""
    caption: str = ""


class EnrichedInfo(BaseModel):
    """Structured facts the agent extracted from the crawled pages. Every field is
    optional — only what the web actually stated is filled (honesty over guessing)."""

    cuisine: str = ""
    address: str = ""
    description: str = ""
    opening_hours: str = ""
    phone: str = ""
    rating: Optional[float] = None
    price_min: Optional[int] = None
    price_max: Optional[int] = None


class EnrichResponse(BaseModel):
    """What the agent returns: LLM-verified photos of *this food venue* + facts.

    `is_food_venue` is the agent's verdict — false (or empty images) means the
    crawl found nothing that is genuinely this eatery, so the client shows an
    honest placeholder rather than an unrelated photo (the "surgeon" bug)."""

    images: List[EnrichedImage] = Field(default_factory=list)
    info: EnrichedInfo = Field(default_factory=EnrichedInfo)
    is_food_venue: bool = True
    intro: str = ""
    cost_tokens: int = 0
    provider: str = ""  # which scraper/LLM combo produced this (debug)
    iterations: int = 0  # how many agentic search rounds it took
