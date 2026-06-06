"""Free, keyless geocoding via Photon (komoot) — an OpenStreetMap-based geocoder
that handles business POIs and Vietnamese addresses far better than Nominatim's
plain search (empirically: Nominatim returns nothing for "45 Cô Giang, Q.1",
Photon resolves both the street and nearby restaurants).

Two uses:
  * reverse — midpoint coords → place name (district + city). A place name makes
    web search far better than a bare "10.77,106.70".
  * forward — a venue name/address → real lat/lng + display address, so the chat
    card's map pins land on the actual restaurant, not the midpoint.

Both are best-effort: they return "" / None on any failure so the caller degrades
gracefully. Photon has no API key and no hard rate limit, but we stay polite."""

from __future__ import annotations

import logging
import re
from typing import Optional, Tuple

log = logging.getLogger("ai_venue_search.geocode")

_PHOTON = "https://photon.komoot.io"
_HEADERS = {"User-Agent": "anmates-ai-venue-search/0.1 (https://github.com/AnMatesStudio)"}

# Common Vietnamese address abbreviations that hurt geocoder recall.
_ABBREV = [
    (re.compile(r"\bTP\.?\s*HCM\b", re.IGNORECASE), "Hồ Chí Minh"),
    (re.compile(r"\bTP\.?\s*HN\b", re.IGNORECASE), "Hà Nội"),
    (re.compile(r"\bQ\.?\s*(\d+)\b"), r"Quận \1"),
    (re.compile(r"\bP\.?\s*(\d+)\b"), r"Phường \1"),
    (re.compile(r"\bĐ\.\s*"), "Đường "),
]


def _normalize(q: str) -> str:
    for pat, repl in _ABBREV:
        q = pat.sub(repl, q)
    return re.sub(r"\s+", " ", q).strip(" ,")


# Photon result granularities too coarse to be a useful map pin (a city/region
# centroid would stack every venue on one point). We reject these.
_COARSE_TYPES = {"city", "county", "state", "region", "country", "locality", "postcode", "continent"}


def _display(props: dict) -> str:
    parts = []
    for key in ("name", "street", "district", "city"):
        v = props.get(key)
        if v and v not in parts:
            parts.append(v)
    return ", ".join(parts)


async def reverse_area(lat: float, lng: float, timeout: float = 8.0) -> str:
    """Return a short "<district>, <city>" string for the coordinate, or ""."""
    import httpx

    params = {"lat": lat, "lon": lng, "limit": 1}
    try:
        async with httpx.AsyncClient(timeout=timeout, headers=_HEADERS) as client:
            resp = await client.get(f"{_PHOTON}/reverse", params=params)
            resp.raise_for_status()
            feats = (resp.json() or {}).get("features", [])
    except Exception as e:  # noqa: BLE001 — best-effort; caller falls back to coords
        log.warning("reverse geocode failed: %s", e)
        return ""

    if not feats:
        return ""
    props = feats[0].get("properties", {})
    parts = []
    for key in ("district", "city", "county", "state"):
        v = props.get(key)
        if v and v not in parts:
            parts.append(v)
    return ", ".join(parts[:2])


async def forward_geocode(
    query: str,
    bias_lat: Optional[float] = None,
    bias_lng: Optional[float] = None,
    timeout: float = 8.0,
) -> Optional[Tuple[float, float, str]]:
    """Resolve a place query (venue name and/or address) to
    (lat, lng, display_name), or None if not found / on error. When a bias point is
    given, Photon ranks nearby results first — essential to avoid matching a
    same-named street in another city."""
    import httpx

    params: dict = {"q": _normalize(query), "limit": 1}
    if bias_lat is not None and bias_lng is not None:
        params["lat"], params["lon"] = bias_lat, bias_lng
    try:
        async with httpx.AsyncClient(timeout=timeout, headers=_HEADERS) as client:
            resp = await client.get(f"{_PHOTON}/api", params=params)
            resp.raise_for_status()
            feats = (resp.json() or {}).get("features", [])
    except Exception as e:  # noqa: BLE001 — best-effort
        log.warning("forward geocode failed for %r: %s", query, e)
        return None

    if not feats:
        return None
    feat = feats[0]
    props = feat.get("properties", {})
    if props.get("type") in _COARSE_TYPES:
        return None  # a city/region centroid — not a usable per-venue pin
    try:
        lng, lat = feat["geometry"]["coordinates"][:2]  # GeoJSON order is [lon, lat]
        return float(lat), float(lng), _display(props)
    except (KeyError, TypeError, ValueError, IndexError):
        return None
