"""Unit tests for the agentic venue-enrichment helpers — the pure parsing /
planning logic that runs with no browser and no LLM. The headless crawl and the
LLM verdict are integration concerns verified live via ./start.sh."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from ai_venue_search.enrich import _flatten_candidates, _parse_verify_json, _plan_queries
from ai_venue_search.providers.google_scrape import (
    PageContent,
    _dedup_hits,
    _extract_images,
    _is_junk_image,
    _parse_bing_serp,
    _visible_text,
)
from ai_venue_search.schemas import EnrichRequest


# --- query planning ----------------------------------------------------------


def test_plan_queries_most_specific_first():
    req = EnrichRequest(name="Lẩu Bò Giáo Toàn", address="123 Lê Văn Việt", city="Thủ Đức")
    qs = _plan_queries(req)
    assert qs[0] == "Lẩu Bò Giáo Toàn 123 Lê Văn Việt nhà hàng quán ăn"
    assert any("restaurant" in q for q in qs)
    # No duplicates, no empties.
    assert len(qs) == len(set(q.lower() for q in qs))
    assert all(q.strip() for q in qs)


def test_plan_queries_handles_missing_address_city():
    qs = _plan_queries(EnrichRequest(name="Surgeon Bbq Curry"))
    assert qs[0].startswith("Surgeon Bbq Curry")
    assert all(q.strip() for q in qs)


# --- image extraction (the structural anti-"surgeon-photo" guard) ------------


def test_extract_images_pulls_og_and_content_imgs():
    html = (
        '<html><head><title>Quán Lẩu Bò</title>'
        '<meta property="og:image" content="https://cdn.vn/hero.jpg"></head>'
        '<body>'
        '<img src="/photos/mon-an.jpg" alt="món bò nướng">'
        '<img src="https://cdn.vn/logo.png" alt="logo">'  # junk by marker
        '<img src="data:image/gif;base64,AAAA" alt="spacer">'  # data uri skipped
        '<img src="https://cdn.vn/khong-gian.webp" alt="không gian quán">'
        '</body></html>'
    )
    imgs = _extract_images(html, "https://blog.vn/lau-bo")
    urls = [u for u, _ in imgs]
    assert "https://cdn.vn/hero.jpg" in urls  # og:image first
    assert "https://blog.vn/photos/mon-an.jpg" in urls  # relative absolutized
    assert "https://cdn.vn/khong-gian.webp" in urls
    assert all("logo" not in u for u in urls)  # junk dropped
    assert all(not u.startswith("data:") for u in urls)  # data uri dropped
    # og:image inherits the page title as caption.
    assert dict(imgs)["https://cdn.vn/hero.jpg"] == "Quán Lẩu Bò"
    assert dict(imgs)["https://blog.vn/photos/mon-an.jpg"] == "món bò nướng"


def test_extract_images_dedupes():
    html = (
        '<img src="https://cdn.vn/a.jpg" alt="x">'
        '<img src="https://cdn.vn/a.jpg" alt="y">'
    )
    assert len(_extract_images(html, "https://x.vn")) == 1


def test_is_junk_image():
    assert _is_junk_image("https://x.vn/assets/logo.png")
    assert _is_junk_image("https://x.vn/favicon.ico")
    assert _is_junk_image("https://x.vn/img/lazy-placeholder.webp")
    assert not _is_junk_image("https://mia.vn/uploads/lau-bo-giao-toan-1.jpg")


# --- search-result parsing + dedup -------------------------------------------


def test_parse_bing_serp():
    html = (
        '<li class="b_algo"><h2><a href="https://foody.vn/lau-bo">Lẩu Bò Giáo Toàn | Foody</a></h2></li>'
        '<li class="b_algo"><h2><a href="https://blog.vn/review">Review quán</a></h2></li>'
    )
    hits = _parse_bing_serp(html)
    assert [h.url for h in hits] == ["https://foody.vn/lau-bo", "https://blog.vn/review"]
    assert hits[0].title == "Lẩu Bò Giáo Toàn | Foody"


def test_dedup_hits_drops_engine_internal_and_dupes():
    raw = [
        {"title": "A", "url": "https://foody.vn/a"},
        {"title": "A dup", "url": "https://foody.vn/a"},  # dup url
        {"title": "G", "url": "https://www.google.com/search?q=x"},  # engine-internal
        {"title": "B", "url": "https://bing.com/images"},  # engine-internal
        {"title": "C", "url": "https://blog.vn/c"},
    ]
    hits = _dedup_hits(raw)
    assert [h.url for h in hits] == ["https://foody.vn/a", "https://blog.vn/c"]


def test_visible_text_strips_scripts_and_tags():
    html = "<style>.x{}</style><script>var a=1</script><h1>Quán Lẩu</h1><p>Ngon</p>"
    text = _visible_text(html)
    assert "Quán Lẩu" in text and "Ngon" in text
    assert "var a" not in text and ".x{}" not in text


# --- LLM verdict parsing -----------------------------------------------------


def test_parse_verify_json_full():
    text = (
        'noise before {"is_food_venue": true, "keep_image_indices": [0, 2], '
        '"intro": "Quán lẩu bò ngon", "info": {"cuisine": "Lẩu bò", "address": "123 Lê Văn Việt", '
        '"description": "Quán lẩu bò nổi tiếng", "opening_hours": "10:00-22:00", "phone": "0909", '
        '"rating": 4.5, "price_min": 100000, "price_max": 200000}} trailing'
    )
    keep, info, intro, is_food = _parse_verify_json(text)
    assert keep == [0, 2]
    assert is_food is True
    assert intro == "Quán lẩu bò ngon"
    assert info.cuisine == "Lẩu bò"
    assert info.rating == 4.5
    assert info.price_max == 200000


def test_parse_verify_json_rejects_non_food():
    keep, info, intro, is_food = _parse_verify_json(
        '{"is_food_venue": false, "keep_image_indices": [], "intro": "", '
        '"info": {"cuisine": "", "address": "", "description": "", "opening_hours": "", '
        '"phone": "", "rating": null, "price_min": null, "price_max": null}}'
    )
    assert keep == []
    assert is_food is False
    assert info.rating is None


def test_parse_verify_json_bad_input():
    assert _parse_verify_json("not json at all") == ([], _parse_verify_json("not json at all")[1], "", False)


def test_flatten_candidates_indexes_across_pages():
    pages = [
        PageContent(url="https://foody.vn/a", title="A", images=[("https://i/1.jpg", "m1"), ("https://i/2.jpg", "m2")]),
        PageContent(url="https://blog.vn/b", title="B", images=[("https://i/3.jpg", "m3")]),
    ]
    flat = _flatten_candidates(pages)
    assert [img.url for img, _ in flat] == ["https://i/1.jpg", "https://i/2.jpg", "https://i/3.jpg"]
    assert flat[0][0].source == "foody.vn"
    assert flat[2][1] == 1  # third image belongs to page index 1
