"""Orchestration: build the search query, run search → structurer → geocode
enrichment, and return a SuggestResponse. Stateless and provider-agnostic."""

from __future__ import annotations

import asyncio
import logging
import math
import re
from typing import List

from .config import Settings
from .geocode import forward_geocode, reverse_area
from .providers import build_search_provider, build_structurer
from .schemas import SuggestRequest, SuggestResponse, Venue

log = logging.getLogger("ai_venue_search.service")

# Photon has no hard rate limit; a small gap keeps us a polite citizen.
_GEOCODE_GAP_S = 0.3
# Geocodes are accepted only within this distance of the midpoint. Tie it to the
# search radius (so it scales with the request) but keep a floor for geocoder
# imprecision and venues that sit just outside the nominal radius. Anything farther
# is out of the meet-in-the-middle area (or a wrong same-named match) → dropped.
_GEO_ACCEPT_FLOOR_KM = 6.0
_GEO_ACCEPT_RADIUS_FACTOR = 1.5


def _accept_radius_km(radius_m: int) -> float:
    """Max distance (km) a geocoded pin may sit from the midpoint to be trusted."""
    return max(_GEO_ACCEPT_FLOOR_KM, (radius_m / 1000.0) * _GEO_ACCEPT_RADIUS_FACTOR)


def _haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(min(1.0, math.sqrt(a)))


class VenueSearchService:
    def __init__(self, settings: Settings):
        self._settings = settings
        self._search = build_search_provider(settings)
        self._structurer = build_structurer(settings)

    @staticmethod
    def build_query(req: SuggestRequest, area: str = "") -> str:
        budget = f" tầm {req.budget_min // 1000}k-{req.budget_max // 1000}k" if req.budget_max else ""
        # A place name yields far better web-search results than raw coordinates.
        where = f"ở {area}" if area else (
            f"gần toạ độ {req.lat},{req.lng}" if (req.lat or req.lng) else "Sài Gòn"
        )
        if req.query:
            # Discovery / free-text path: query-led so the specific quán name anchors
            # the search. Concierge sends empty query → mood-led path unchanged.
            return f"{req.query} quán ăn {where}{budget}".strip()
        mood = " ".join(req.mood_tags)
        return f"quán ăn ngon {mood} {where}{budget}".strip()

    async def suggest(self, req: SuggestRequest) -> SuggestResponse:
        area = await self._reverse_area(req.lat, req.lng)
        query = self.build_query(req, area)
        raw = await self._search.search(query)
        # NOTE: we deliberately do NOT prepend the reverse-geocoded area name to the
        # model context. OSM/Photon often mislabels HCMC micro-areas (e.g. a central
        # Q1/Q3 midpoint comes back as "Phường Xuân Hòa, Thủ Đức"), and handing that
        # name to the model makes it parrot a wrong neighbourhood into the intro. The
        # area still steers the web search (build_query); the structurer derives any
        # location wording from the real venue addresses in the search results.

        intro, venues, cost = await self._structurer.structure(req, raw)
        venues = await self._enrich_coords(venues[: req.limit], area, req.lat, req.lng, req.radius_m)

        log.info("suggest: query=%r picks=%d cost=%d geocoded=%d", query, len(venues), cost,
                 sum(1 for v in venues if v.lat or v.lng))
        return SuggestResponse(
            intro=intro,
            picks=venues,
            cost_tokens=cost,
            provider=f"{self._search.name}+{self._structurer.name}",
        )

    async def _reverse_area(self, lat: float, lng: float) -> str:
        if not self._settings.geocode_enabled:
            return ""
        return await reverse_area(lat, lng)

    async def _enrich_coords(self, venues: List[Venue], area: str, blat: float, blng: float, radius_m: int) -> List[Venue]:
        """Forward-geocode each pick → real lat/lng, so the chat card's map pins land
        on the actual restaurant. We always geocode (rather than trust model coords):
        a text model can't know a venue's real lat/lng and tends to echo the midpoint,
        which would stack every pin on one spot. Results are biased toward (blat,blng)
        — the midpoint — and rejected if they land beyond the meet-in-the-middle
        radius, so an out-of-area venue is dropped (lat/lng=0) rather than shown with
        a fabricated near-midpoint distance."""
        if not self._settings.geocode_enabled:
            return venues
        accept_km = _accept_radius_km(radius_m)
        first = True
        for v in venues:
            if not v.name:
                continue
            if not first:
                await asyncio.sleep(_GEOCODE_GAP_S)
            first = False
            geo = await self._geocode_venue(v, area, blat, blng, accept_km)
            if geo:
                v.lat, v.lng, display = geo
                if not v.address:
                    v.address = display
            else:
                v.lat, v.lng = 0.0, 0.0  # couldn't place it in-area — don't ship a fake coord
        return venues

    async def _geocode_venue(self, v: Venue, area: str, blat: float, blng: float, accept_km: float):
        """Resolve a pick to real coords, trusting the most specific signal available
        and rejecting anything outside the meet-in-the-middle radius.

        If the model gave a street address, we trust ONLY that: a hit within radius is
        the venue; a hit outside radius means the venue is genuinely out of area, so we
        return None (do NOT fall through to a fuzzy name match — that would mislabel
        another restaurant's location as this venue, the exact bug where a Thủ Đức BBQ
        was pinned 184 m from a central-HCMC midpoint). Only when there is no usable
        address do we best-effort by name (still radius-bound, lower confidence)."""
        street = _clean_address(v.address)
        if street:
            geo = await forward_geocode(street, blat, blng)
            if geo and _haversine_km(blat, blng, geo[0], geo[1]) <= accept_km:
                return geo
            return None
        # No address → best-effort by name; forward_geocode rejects coarse centroids,
        # and the radius guard drops far/wrong matches.
        candidates = [f"{v.name}, {area}"] if area else []
        candidates.append(v.name)
        for i, q in enumerate(dict.fromkeys(c for c in candidates if c)):  # dedup, keep order
            if i:
                await asyncio.sleep(_GEOCODE_GAP_S)
            geo = await forward_geocode(q, blat, blng)
            if geo and _haversine_km(blat, blng, geo[0], geo[1]) <= accept_km:
                return geo
        return None


# Floor / basement / unit lead-ins that derail an address geocode.
_UNIT_LEAD = re.compile(r"(?i)^(tầng hầm|tầng|lầu|floor|tret|trệt|b\d+|kiosk|kios|lô)\b")


def _clean_address(addr: str) -> str:
    """Reduce a messy venue address to the geocodable street part: prefer the segment
    after a mall-name "… - <street>" dash, then drop leading floor/unit segments.
    e.g. "Tầng hầm B3 … - 45A Lý Tự Trọng, Bến Nghé, Quận 1" → "45A Lý Tự Trọng, Bến Nghé, Quận 1"."""
    addr = (addr or "").strip()
    if not addr:
        return ""
    if " - " in addr:
        addr = addr.split(" - ", 1)[1]
    segs = [s.strip() for s in addr.split(",")]
    segs = [s for s in segs if s and not _UNIT_LEAD.match(s)]
    return ", ".join(segs)
