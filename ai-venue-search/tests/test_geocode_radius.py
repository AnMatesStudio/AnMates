"""Offline tests for the radius-bound geocode enrichment (A1 fix): an out-of-area
venue must be dropped (lat/lng=0) rather than shown with a fabricated near-midpoint
coordinate, and a venue with a real street address must NOT fall through to a fuzzy
name match. No network: forward_geocode is monkeypatched.

Run: `pytest tests/test_geocode_radius.py` from the ai-venue-search dir."""

import asyncio
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

os.environ["SEARCH_PROVIDER"] = "mock"
os.environ["STRUCTURER"] = "mock"
os.environ["GEOCODE_ENABLED"] = "1"

from ai_venue_search import config, service as service_mod  # noqa: E402
from ai_venue_search.schemas import Venue  # noqa: E402
from ai_venue_search.service import VenueSearchService, _accept_radius_km  # noqa: E402

MID_LAT, MID_LNG = 10.78145, 106.69545  # central HCMC midpoint from the e2e run


def _svc():
    return VenueSearchService(config.load())


def test_accept_radius_scales_with_request_radius():
    assert _accept_radius_km(4000) == 6.0          # floor wins for the default radius
    assert _accept_radius_km(8000) == 12.0         # 8km * 1.5
    assert _accept_radius_km(1000) == 6.0          # never below the floor


def _enrich(venues, geo_for):
    """Run _enrich_coords with forward_geocode stubbed by a {query-substring: (lat,lng,disp)}
    map. Patches the module attribute directly (with restore) — the production code
    resolves `forward_geocode` from the service module globals."""
    import unicodedata
    nfc = lambda s: unicodedata.normalize("NFC", s)  # noqa: E731 — guard NFC/NFD literal drift

    async def fake_forward(query, blat=None, blng=None, timeout=8.0):
        q = nfc(query)
        for key, val in geo_for.items():
            if nfc(key) in q:
                return val
        return None

    # Force geocoding on at call time: another test module (test_mock_smoke) sets
    # GEOCODE_ENABLED=0 at import, and config.load() reads the shared os.environ.
    # Save/restore so we don't pollute that module's expectation in return.
    prev_geo = os.environ.get("GEOCODE_ENABLED")
    os.environ["GEOCODE_ENABLED"] = "1"
    orig = service_mod.forward_geocode
    service_mod.forward_geocode = fake_forward
    try:
        svc = _svc()
        return asyncio.run(svc._enrich_coords(venues, area="", blat=MID_LAT, blng=MID_LNG, radius_m=4000))
    finally:
        service_mod.forward_geocode = orig
        if prev_geo is None:
            os.environ.pop("GEOCODE_ENABLED", None)
        else:
            os.environ["GEOCODE_ENABLED"] = prev_geo


def test_far_street_address_is_dropped():
    # Subin BBQ: real Thủ Đức street ~10 km from the central midpoint → out of area.
    v = Venue(name="Subin BBQ", address="216 Võ Văn Ngân, Phường Bình Thọ, Quận Thủ Đức")
    out = _enrich([v], {"Võ Văn Ngân": (10.8511, 106.7565, "Thủ Đức")})
    assert (out[0].lat, out[0].lng) == (0.0, 0.0)  # dropped, not pinned near midpoint


def test_far_street_does_not_fall_through_to_name():
    # Even if a fuzzy name match exists near the midpoint, a venue with a real (far)
    # street address must NOT borrow another place's coords.
    v = Venue(name="Subin BBQ", address="216 Võ Văn Ngân, Quận Thủ Đức")
    out = _enrich([v], {
        "Võ Văn Ngân": (10.8511, 106.7565, "Thủ Đức"),   # far (street) — rejected
        "Subin BBQ": (10.7820, 106.6960, "near midpoint"),  # fuzzy name — must be ignored
    })
    assert (out[0].lat, out[0].lng) == (0.0, 0.0)


def test_near_street_address_is_kept():
    # King BBQ: central Q1 street ~1 km from midpoint → kept.
    v = Venue(name="King BBQ", address="70 Lê Thánh Tôn, Bến Nghé, Quận 1")
    out = _enrich([v], {"Lê Thánh Tôn": (10.7817, 106.7055, "Quận 1")})
    assert out[0].lat == 10.7817 and out[0].lng == 106.7055


def test_no_address_uses_name_within_radius():
    v = Venue(name="Quán Lẩu Gần Đây", address="")
    out = _enrich([v], {"Quán Lẩu Gần Đây": (10.7800, 106.6970, "near")})
    assert out[0].lat == 10.7800 and out[0].lng == 106.6970


def test_no_address_far_name_is_dropped():
    v = Venue(name="Quán Xa", address="")
    out = _enrich([v], {"Quán Xa": (10.9000, 106.8500, "far")})  # ~20km
    assert (out[0].lat, out[0].lng) == (0.0, 0.0)


if __name__ == "__main__":
    import pytest
    sys.exit(pytest.main([__file__, "-v"]))
