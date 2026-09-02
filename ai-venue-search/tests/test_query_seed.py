"""Unit tests for the Discovery free-text query-seed helpers — the deterministic
safety net that guarantees a typed quán name surfaces even when the web-search /
LLM / geocode pipeline drops it."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from ai_venue_search.schemas import SuggestRequest, Venue
from ai_venue_search.service import (
    VenueSearchService,
    _looks_like_venue_name,
    _name_matches,
    _titlecase,
)


def test_looks_like_venue_name():
    # Specific multi-word names → seed-eligible.
    assert _looks_like_venue_name("lẩu bò giáo toàn")
    assert _looks_like_venue_name("Bún Bò Huế Giáo Toàn")
    # Long single token → eligible.
    assert _looks_like_venue_name("buffetlong")
    # Bare short dish/genre tokens → NOT seeded (structurer drives these).
    assert not _looks_like_venue_name("phở")
    assert not _looks_like_venue_name("lẩu")
    assert not _looks_like_venue_name("  ")


def test_titlecase_preserves_existing_caps():
    assert _titlecase("lẩu bò giáo toàn") == "Lẩu Bò Giáo Toàn"
    assert _titlecase("BBQ Garden") == "BBQ Garden"
    assert _titlecase("") == ""


def test_name_matches():
    # Substring either way.
    assert _name_matches("lẩu bò giáo toàn", "Lẩu Bò Giáo Toàn - Cơ Sở Thủ Đức")
    assert _name_matches("Lẩu Bò Giáo Toàn", "lẩu bò giáo toàn")
    # High token overlap (one token differs).
    assert _name_matches("lẩu bò giáo toàn", "Lẩu Bò Giáo Toàn Quán")
    # Unrelated venue → no match (so the seed is injected).
    assert not _name_matches("lẩu bò giáo toàn", "Lẩu Dê 6 Tửng")
    assert not _name_matches("lẩu bò giáo toàn", "")


def _venue(name: str) -> Venue:
    return Venue(name=name)


def test_ensure_query_venue_injects_seed_when_absent():
    req = SuggestRequest(query="lẩu bò giáo toàn", limit=6)
    seed = _venue("Lẩu Bò Giáo Toàn")
    picks = [_venue("Lẩu Dê 6 Tửng"), _venue("Ashima")]
    out = VenueSearchService._ensure_query_venue(req, seed, picks)
    assert out[0].name == "Lẩu Bò Giáo Toàn"
    assert len(out) == 3


def test_ensure_query_venue_skips_seed_when_already_present():
    req = SuggestRequest(query="lẩu bò giáo toàn", limit=6)
    seed = _venue("Lẩu Bò Giáo Toàn")
    picks = [_venue("Lẩu Bò Giáo Toàn - Thủ Đức"), _venue("Ashima")]
    out = VenueSearchService._ensure_query_venue(req, seed, picks)
    assert len(out) == 2
    assert all("6 Tửng" not in v.name for v in out)


def test_ensure_query_venue_no_seed_for_bare_dish():
    req = SuggestRequest(query="phở", limit=6)
    seed = None  # _seed_query_venue returns None for bare dish words
    picks = [_venue("Phở Lệ"), _venue("Phở Hòa")]
    out = VenueSearchService._ensure_query_venue(req, seed, picks)
    assert out == picks


def test_ensure_query_venue_trims_to_limit():
    req = SuggestRequest(query="lẩu bò giáo toàn", limit=3)
    seed = _venue("Lẩu Bò Giáo Toàn")
    picks = [_venue(f"Quán {i}") for i in range(5)]
    out = VenueSearchService._ensure_query_venue(req, seed, picks)
    assert len(out) == 3
    assert out[0].name == "Lẩu Bò Giáo Toàn"
