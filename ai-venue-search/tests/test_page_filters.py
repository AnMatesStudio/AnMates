"""Unit tests for the page-fetch filters: skip blocked domains, 403/error pages,
and pages that aren't about food. Run: `pytest` from the ai-venue-search dir."""

import asyncio
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

os.environ.setdefault("MCP_FETCH_TOP_N", "2")

from ai_venue_search import config  # noqa: E402
from ai_venue_search.providers.search import (  # noqa: E402
    MCPWebSearchProvider,
    _blocked_domain,
    _food_relevant,
    _looks_like_error,
)


def test_blocked_domain():
    assert _blocked_domain("https://www.facebook.com/some/page")
    assert _blocked_domain("https://shopee.vn/abc")
    assert _blocked_domain("https://www.google.com/maps/place/x")
    assert not _blocked_domain("https://mytour.vn/vi/blog/top-quan-an.html")
    assert not _blocked_domain("https://www.foody.vn/ho-chi-minh")


def test_looks_like_error():
    assert _looks_like_error("")
    assert _looks_like_error("   ")
    assert _looks_like_error("too short")
    assert _looks_like_error("403 Forbidden — Access Denied. " + "x" * 300)
    assert _looks_like_error("Just a moment... Cloudflare checking your browser. " + "y" * 300)
    # A real, long-enough restaurant page is not an error.
    ok = "Top quán ăn ngon ở Quận 3: nhà hàng ABC phục vụ lẩu và hải sản. " * 10
    assert not _looks_like_error(ok)


def test_food_relevant():
    food = (
        "Danh sách quán ăn ngon: nhà hàng A nổi tiếng món lẩu, quán B chuyên hải sản, "
        "thực đơn đa dạng, ẩm thực ba miền, có cả cà phê."
    )
    assert _food_relevant(food)
    # Off-topic page that merely mentions "quán" once → skipped.
    off = "Tin tức bất động sản: giá nhà tăng. Một quán cà phê gần đó." # only 2 hits
    assert not _food_relevant("Bản tin thời tiết hôm nay nắng nóng, không có gì để ăn ngoài trời.")
    # 'off' has 'quán' + 'cà phê' = 2 hits → below threshold (3)
    assert not _food_relevant(off)


# ── integration: _fetch_pages skips blocked / 403 / off-topic, keeps real food ──

class _Block:
    def __init__(self, text):
        self.text = text


class _Res:
    def __init__(self, text):
        self.content = [_Block(text)]


class _FakeSession:
    """Stands in for an MCP session: returns canned page bodies per URL."""
    def __init__(self, mapping):
        self.mapping = mapping
        self.fetched = []

    async def call_tool(self, tool, args):
        url = next(iter(args.values()))
        self.fetched.append(url)
        return _Res(self.mapping.get(url, ""))


def test_fetch_pages_filters():
    good = "https://mytour.vn/blog/top-quan-an-gia-dinh.html"
    blocked = "https://www.facebook.com/some-restaurant"
    forbidden = "https://www.nhatot.com/kinh-nghiem/quan-an-ngon.html"
    offtopic = "https://example.com/tin-tuc-bat-dong-san"

    snippets = f"a {good} b {blocked} c {forbidden} d {offtopic} e"
    pages = {
        good: "Top quán ăn gia đình: nhà hàng Ngon chuyên lẩu và hải sản, "
              "thực đơn phong phú, món ăn ba miền, quán ấm cúng. " * 5,
        blocked: "should never be fetched",
        forbidden: "403 Forbidden. Access denied. " + "x" * 400,
        offtopic: "Giá bất động sản quận 3 tăng mạnh trong quý này theo báo cáo. " * 5,
    }
    sess = _FakeSession(pages)
    provider = MCPWebSearchProvider(config.load())

    out = asyncio.run(provider._fetch_pages(sess, snippets))

    assert good in out  # the real food page is kept
    assert blocked not in sess.fetched  # blocked domain never even fetched
    assert forbidden not in out  # 403 page dropped
    assert offtopic not in out  # off-topic page dropped
    assert "NỘI DUNG TỪ" in out and out.count("--- NỘI DUNG TỪ") == 1
