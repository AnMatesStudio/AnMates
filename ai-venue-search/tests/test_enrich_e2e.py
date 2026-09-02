"""End-to-end safety tests for the agentic venue-enrichment endpoint (POST /enrich).

These drive the REAL FastAPI app and the REAL `VenueEnricher` pipeline — query
planning, the agentic crawl loop, candidate flattening, LLM-verdict parsing,
response shaping and the "honest placeholder" contract all run unmodified. Only
the two external I/O boundaries are stubbed at well-defined seams:

  * the headless web crawl  ->  `GoogleCrawler.crawl`        (no browser/network)
  * the LLM verdict call     ->  `httpx.AsyncClient.post`     (no model server)

The guarantee under test — the reason this feature exists (the "Surgeon Bbq Curry
-> operating room" bug): a photo returned to the client must genuinely belong to
THIS food venue. An unrelated / inappropriate image must never reach the client.
It is rejected by one of two layers:

  1. STRUCTURAL  — the page the image lives on isn't food-relevant, so the image
                   never becomes a candidate at all (verified for real, no LLM,
                   in `test_structural_gate_drops_non_food_page`).
  2. SEMANTIC    — among candidates from food pages, the LLM excludes anything
                   that isn't really this eatery (`keep_image_indices`).

And when nothing genuine is found, the response is an honest empty placeholder
(`is_food_venue=false`) — never a wrong photo, never a 5xx.

Run from the ai-venue-search dir:  pytest tests/test_enrich_e2e.py
"""

import asyncio
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Force fully-offline providers so importing the app touches no network and no
# code path can accidentally reach a real LLM / search server during the test.
os.environ.setdefault("SEARCH_PROVIDER", "mock")
os.environ.setdefault("STRUCTURER", "mock")
os.environ.setdefault("MCP_SERVER_CMD", "")
os.environ.setdefault("GEOCODE_ENABLED", "0")

import httpx  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from ai_venue_search.app import app  # noqa: E402
from ai_venue_search.providers.google_scrape import (  # noqa: E402
    GoogleCrawler,
    PageContent,
    SearchHit,
    _visible_text,
)
from ai_venue_search.providers.search import _food_relevant  # noqa: E402

# Distinct, recognisable URLs so assertions read clearly.
FOOD_HERO = "https://foody.vn/photos/lau-bo-1.jpg"        # a real dish photo
FOOD_SPACE = "https://foody.vn/photos/khong-gian.jpg"      # the venue's interior
BAD_IMG = "https://med.example.com/operating-room.jpg"     # the "surgeon" trap

# One food page carrying two genuine venue photos plus the inappropriate one, so
# the semantic gate has something concrete to reject.
_FOOD_PAGE = (
    "https://foody.vn/lau-bo-giao-toan",
    "Lẩu Bò Giáo Toàn | Foody",
    "Quán lẩu bò nổi tiếng khu Thủ Đức, không gian rộng, thực đơn đa dạng.",
    [
        (FOOD_HERO, "lẩu bò nghi ngút khói"),
        (FOOD_SPACE, "không gian quán ấm cúng"),
        (BAD_IMG, "phòng mổ bệnh viện"),  # must NOT survive verification
    ],
)


# --- stubs for the two external boundaries -----------------------------------


class _FakeLLMResponse:
    """Minimal stand-in for an httpx.Response from the chat-completions call."""

    def __init__(self, payload: dict):
        self._payload = payload

    def raise_for_status(self) -> None:  # noqa: D401 - mirror httpx API
        return None

    def json(self) -> dict:
        return self._payload


def _verdict_payload(*, is_food: bool, keep, intro: str = "Quán lẩu bò ngon, không gian ấm cúng.") -> dict:
    """Build a chat-completions response whose content is the LLM's strict-schema
    verdict. `keep` is the list of candidate indices the model decided are really
    this food venue."""
    content = json.dumps(
        {
            "is_food_venue": is_food,
            "keep_image_indices": list(keep),
            "intro": intro,
            "info": {
                "cuisine": "Lẩu bò",
                "address": "123 Lê Văn Việt, Thủ Đức",
                "description": "Quán lẩu bò nổi tiếng khu Thủ Đức.",
                "opening_hours": "10:00-22:00",
                "phone": "0909123456",
                "rating": 4.5,
                "price_min": 100000,
                "price_max": 250000,
            },
        },
        ensure_ascii=False,
    )
    return {"choices": [{"message": {"content": content}}], "usage": {"total_tokens": 128}}


def _patch_crawl(monkeypatch, page_specs) -> None:
    """Make `GoogleCrawler.crawl` return fixture pages instead of hitting the web.
    Fresh PageContent objects are built on every call so the enrich loop's per-page
    de-dup mutation never aliases back into already-collected pages."""

    async def fake_crawl(self, query):  # noqa: ANN001 - test stub
        return [
            PageContent(url=u, title=t, text=txt, images=list(imgs))
            for (u, t, txt, imgs) in page_specs
        ]

    monkeypatch.setattr(GoogleCrawler, "crawl", fake_crawl)


def _patch_llm(monkeypatch, payload=None, *, raises: Exception | None = None) -> None:
    """Intercept the single chat-completions POST the verifier makes. Either return
    a canned verdict or raise (to exercise the LLM-down heuristic path). The crawl
    is already stubbed, so this POST is the only AsyncClient.post during /enrich."""

    async def fake_post(self, url, *args, **kwargs):  # noqa: ANN001 - test stub
        assert "chat/completions" in url, f"unexpected POST to {url}"
        if raises is not None:
            raise raises
        return _FakeLLMResponse(payload)

    monkeypatch.setattr(httpx.AsyncClient, "post", fake_post)


def _enrich(body: dict) -> dict:
    with TestClient(app) as client:
        resp = client.post("/enrich", json=body)
    assert resp.status_code == 200, resp.text
    return resp.json()


# --- SEMANTIC gate: the LLM drops the inappropriate image --------------------


def test_inappropriate_image_is_rejected_by_verification(monkeypatch):
    """A real venue whose crawl happens to include an operating-room photo: the
    verifier keeps only the genuine food images; the inappropriate one is dropped,
    and every surviving image is sourced from the venue's own page."""
    _patch_crawl(monkeypatch, [_FOOD_PAGE])
    _patch_llm(monkeypatch, _verdict_payload(is_food=True, keep=[0, 1]))

    body = _enrich({"name": "Lẩu Bò Giáo Toàn", "address": "123 Lê Văn Việt", "city": "Thủ Đức"})

    urls = [img["url"] for img in body["images"]]
    assert body["is_food_venue"] is True
    assert FOOD_HERO in urls and FOOD_SPACE in urls
    assert BAD_IMG not in urls, "inappropriate (operating-room) image must be filtered out"
    # Every returned photo belongs to the venue's own crawled page (not stock/random).
    assert all(img["source"] == "foody.vn" for img in body["images"])
    assert len(urls) <= 6
    # Proof the semantic gate actually ran (the LLM was consulted, not skipped).
    assert body["cost_tokens"] == 128
    assert body["info"]["cuisine"] == "Lẩu bò"


def test_verdict_not_food_returns_no_images(monkeypatch):
    """Crawl found candidate images, but the LLM judges this is NOT genuinely a
    food venue -> ship zero images + is_food_venue=false (honest placeholder),
    never the unverified photos."""
    _patch_crawl(monkeypatch, [_FOOD_PAGE])
    _patch_llm(monkeypatch, _verdict_payload(is_food=False, keep=[]))

    body = _enrich({"name": "Surgeon Bbq Curry", "city": "Singapore"})

    assert body["is_food_venue"] is False
    assert body["images"] == []


# --- STRUCTURAL gate: nothing genuine found -> honest placeholder ------------


def test_no_food_pages_returns_honest_placeholder(monkeypatch):
    """When the crawl surfaces no food-relevant pages at all (fake/obscure venue),
    the endpoint returns an empty, is_food_venue=false payload WITHOUT ever calling
    the LLM — the client then shows a placeholder, not a wrong photo."""
    _patch_crawl(monkeypatch, [])
    # Guard: the LLM must not be consulted when there is nothing to verify.
    _patch_llm(monkeypatch, raises=AssertionError("LLM must not run with zero pages"))

    body = _enrich({"name": "Surgeon Bbq Curry", "city": "Singapore"})

    assert body["is_food_venue"] is False
    assert body["images"] == []
    assert body["provider"].startswith("google-scrape")


def test_llm_down_falls_back_to_food_page_images_only(monkeypatch):
    """Even when the semantic gate is offline, the STRUCTURAL gate still holds: the
    heuristic fallback only ever keeps images that were sourced from food-relevant
    pages, so an inappropriate image (which lives on a non-food page) can't appear.
    Here the crawl yields only genuine food photos and the LLM call raises."""
    food_only = (
        "https://foody.vn/lau-bo-giao-toan",
        "Lẩu Bò Giáo Toàn | Foody",
        "Quán lẩu bò Thủ Đức, thực đơn phong phú.",
        [(FOOD_HERO, "lẩu bò"), (FOOD_SPACE, "không gian quán")],
    )
    _patch_crawl(monkeypatch, [food_only])
    _patch_llm(monkeypatch, raises=httpx.ConnectError("llm unreachable"))

    body = _enrich({"name": "Lẩu Bò Giáo Toàn", "city": "Thủ Đức"})

    urls = [img["url"] for img in body["images"]]
    assert body["is_food_venue"] is True
    assert set(urls) == {FOOD_HERO, FOOD_SPACE}
    assert BAD_IMG not in urls
    assert all(img["source"] == "foody.vn" for img in body["images"])


# --- STRUCTURAL gate, verified for real (no LLM, no stubbed crawl loop) -------


# A genuine food page (>=3 distinct food terms, >200 chars) -> kept.
_FOOD_HTML = (
    "<html><head><title>Lẩu Bò Giáo Toàn - Quán ngon Thủ Đức</title>"
    f'<meta property="og:image" content="{FOOD_HERO}"></head><body>'
    "<h1>Quán Lẩu Bò Giáo Toàn</h1>"
    "<p>Nhà hàng lẩu bò nổi tiếng tại Thủ Đức với thực đơn đa dạng, "
    "không gian rộng rãi. Món ăn đậm đà, nước lẩu chuẩn vị, ẩm thực phong phú "
    "từ các món nướng đến hải sản tươi sống. Quán phục vụ tận tình, giá hợp lý, "
    "phù hợp cho cả gia đình và nhóm bạn đến ăn uống cuối tuần.</p>"
    f'<img src="{FOOD_SPACE}" alt="không gian quán">'
    "</body></html>"
)

# A surgery page — the exact thing the old string-match filter let through. It has
# NO food vocabulary, so the structural gate drops it before its image is ever a
# candidate. (>200 chars so it isn't dropped merely as a short/error page.)
_MED_HTML = (
    "<html><head><title>Phòng mổ ngoại khoa - Bệnh viện</title>"
    f'<meta property="og:image" content="{BAD_IMG}"></head><body>'
    "<h1>Khoa phẫu thuật</h1>"
    "<p>Đội ngũ bác sĩ phẫu thuật giàu kinh nghiệm thực hiện ca mổ trong phòng mổ "
    "vô trùng, với thiết bị y tế hiện đại. Bệnh nhân được gây mê an toàn, điều dưỡng "
    "theo dõi sát sao trước và sau ca mổ. Quy trình khử trùng nghiêm ngặt, đội ngũ "
    "chuyên môn ngoại khoa luôn sẵn sàng cấp cứu suốt ngày đêm.</p>"
    '<img src="https://med.example.com/surgery.jpg" alt="phòng mổ">'
    "</body></html>"
)


class _FakeHTTPResponse:
    def __init__(self, text: str, status_code: int = 200, content_type: str = "text/html; charset=utf-8"):
        self.text = text
        self.status_code = status_code
        self.headers = {"content-type": content_type}


class _StubHTTPClient:
    """Stands in for the httpx.AsyncClient `_fetch_page` is handed."""

    def __init__(self, response: _FakeHTTPResponse):
        self._response = response

    async def get(self, url):  # noqa: ANN001 - test stub
        return self._response


def test_structural_gate_drops_non_food_page():
    """Real `_fetch_page`, no LLM: a food page yields its photos as candidates; a
    surgery page yields NONE — its operating-room image never becomes a candidate.
    This is the deterministic core of "the photo belongs to the restaurant"."""
    crawler = GoogleCrawler(bing_fallback=False)

    food = asyncio.run(
        crawler._fetch_page(
            _StubHTTPClient(_FakeHTTPResponse(_FOOD_HTML)),
            SearchHit(title="Lẩu Bò Giáo Toàn", url="https://foody.vn/lau-bo-giao-toan"),
        )
    )
    assert food is not None
    food_urls = [u for u, _ in food.images]
    assert FOOD_HERO in food_urls and FOOD_SPACE in food_urls

    med = asyncio.run(
        crawler._fetch_page(
            _StubHTTPClient(_FakeHTTPResponse(_MED_HTML)),
            SearchHit(title="Phòng mổ", url="https://med.example.com/phong-mo"),
        )
    )
    assert med is None, "a non-food (surgery) page must be dropped, so its image is never a candidate"
    # Pin the mechanism: the page is rejected specifically because it isn't food-relevant.
    assert not _food_relevant(_visible_text(_MED_HTML))
