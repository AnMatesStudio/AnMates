"""Request/response contracts. Mirrors the Go `WebSearchProvider` client and the
Flutter `ai_venue_card` model — keep field names in sync across all three."""

from __future__ import annotations

from typing import List, Optional

from pydantic import BaseModel, Field


class SuggestRequest(BaseModel):
    """What the Go concierge asks for: where to look + the shared taste/budget."""

    lat: float
    lng: float
    radius_m: int = 4000
    budget_min: int = 0
    budget_max: int = 0
    mood_tags: List[str] = Field(default_factory=list)
    limit: int = 3


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
