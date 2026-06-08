"""Offline unit tests for VenueSearchService.build_query.
Asserts query-led behaviour when `query` is set and mood-led when not.
No network, no MCP, no API keys needed."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from ai_venue_search.schemas import SuggestRequest
from ai_venue_search.service import VenueSearchService


def _req(**kw) -> SuggestRequest:
    defaults = dict(lat=10.7769, lng=106.7009, radius_m=4000, mood_tags=["lẩu"], limit=3)
    defaults.update(kw)
    return SuggestRequest(**defaults)


def test_query_led_contains_query_term():
    req = _req(query="bún bò giáo toàn")
    result = VenueSearchService.build_query(req, area="Quận 1")
    assert "bún bò giáo toàn" in result.lower()
    # query-led: the user's term should come first, not "quán ăn ngon"
    assert result.lower().startswith("bún bò giáo toàn")


def test_query_led_includes_area():
    req = _req(query="lẩu dê")
    result = VenueSearchService.build_query(req, area="Bình Thạnh")
    assert "lẩu dê" in result.lower()
    assert "bình thạnh" in result.lower()


def test_empty_query_is_mood_led():
    req = _req(query="", mood_tags=["nướng", "chill"])
    result = VenueSearchService.build_query(req, area="Quận 3")
    # mood-led: starts with "quán ăn ngon" prefix
    assert "quán ăn ngon" in result.lower()
    # and contains the mood tags
    assert "nướng" in result.lower()


def test_empty_query_no_area_uses_coords():
    req = _req(query="", mood_tags=[])
    result = VenueSearchService.build_query(req, area="")
    assert "10.7769" in result or "106.7009" in result or "sài gòn" in result.lower()


def test_query_no_area_no_coords_uses_saigon():
    req = SuggestRequest(lat=0.0, lng=0.0, query="bún bò")
    result = VenueSearchService.build_query(req, area="")
    assert "bún bò" in result.lower()
    assert "sài gòn" in result.lower()
