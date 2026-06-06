"""Offline smoke test: mock search + mock structurer must return venues with no
network, no MCP server, no API key. Run: `pytest` from the ai-venue-search dir.
Also runnable directly: `python tests/test_mock_smoke.py`."""

import asyncio
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Force fully-offline providers regardless of the developer's env.
os.environ["SEARCH_PROVIDER"] = "mock"
os.environ["STRUCTURER"] = "mock"
os.environ["MCP_SERVER_CMD"] = ""
os.environ["ANTHROPIC_API_KEY"] = ""
os.environ["GEOCODE_ENABLED"] = "0"  # no network: mock venues already carry coords

from ai_venue_search import config  # noqa: E402
from ai_venue_search.schemas import SuggestRequest  # noqa: E402
from ai_venue_search.service import VenueSearchService  # noqa: E402


def _run():
    svc = VenueSearchService(config.load())
    req = SuggestRequest(lat=10.77, lng=106.70, budget_min=80000, budget_max=150000,
                         mood_tags=["lẩu", "chill"], limit=3)
    return asyncio.run(svc.suggest(req))


def test_mock_returns_venues():
    resp = _run()
    assert resp.provider == "mock+mock"
    assert 1 <= len(resp.picks) <= 3
    first = resp.picks[0]
    assert first.name
    assert first.reason
    # mock jitters coordinates around the requested midpoint
    assert abs(first.lat - 10.77) < 0.01


if __name__ == "__main__":
    r = _run()
    print(f"provider={r.provider} intro={r.intro!r}")
    for p in r.picks:
        print(f"  - {p.name} | {p.price_min}-{p.price_max} | ★{p.rating} | {p.reason}")
    assert r.picks, "expected at least one pick"
    print("OK")
