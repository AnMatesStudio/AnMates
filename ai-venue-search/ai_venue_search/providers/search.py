"""Web-search providers. A provider takes a query string and returns raw search
text (titles + snippets + urls concatenated) — it does NOT understand venues.
Turning that text into structured restaurants is the structurer's job."""

from __future__ import annotations

import abc
import logging
import re

from ..config import Settings

log = logging.getLogger("ai_venue_search.search")

_URL_RE = re.compile(r"https?://[^\s)>\]]+")


class SearchProvider(abc.ABC):
    name: str = "base"

    @abc.abstractmethod
    async def search(self, query: str) -> str:
        """Return raw web-search text for `query` (best-effort, may be empty)."""
        raise NotImplementedError


class MockSearchProvider(SearchProvider):
    """Offline/dev provider. Returns a deterministic blob so the structurer's
    mock path can produce stable venues without any network or MCP server."""

    name = "mock"

    async def search(self, query: str) -> str:
        return (
            f"[mock results for: {query}]\n"
            "1. Lẩu Nấm Gandhi - quán lẩu nấm chay, không gian ấm cúng, giá 120k-180k, rating 4.6\n"
            "2. Bún Chả Hương Liên - bún chả Hà Nội nổi tiếng, giá 60k-90k, rating 4.4\n"
            "3. The Coffee House - cafe chill làm việc, giá 45k-75k, rating 4.3\n"
        )


class MCPWebSearchProvider(SearchProvider):
    """Spawns an MCP web-search server over stdio and calls its search tool.

    Works with any MCP server exposing a text-returning search tool — Brave,
    Tavily, DuckDuckGo, etc. The tool name, query-arg name and launch command
    are all configured via env (see config.Settings)."""

    name = "mcp"

    def __init__(self, settings: Settings):
        self._cmd = settings.mcp_server_cmd
        self._tool = settings.mcp_search_tool
        self._query_arg = settings.mcp_query_arg
        self._fetch_tool = settings.mcp_fetch_tool
        self._fetch_url_arg = settings.mcp_fetch_url_arg
        self._fetch_top_n = settings.mcp_fetch_top_n
        self._fetch_char_cap = settings.mcp_fetch_char_cap

    async def search(self, query: str) -> str:
        # Imported lazily so the service still boots without the `mcp` package.
        from mcp import ClientSession, StdioServerParameters
        from mcp.client.stdio import stdio_client

        params = StdioServerParameters(command=self._cmd[0], args=self._cmd[1:])
        async with stdio_client(params) as (read, write):
            async with ClientSession(read, write) as session:
                await session.initialize()
                result = await session.call_tool(self._tool, {self._query_arg: query})
                snippets = _flatten_tool_result(result)
                if self._fetch_top_n <= 0:
                    return snippets
                pages = await self._fetch_pages(session, snippets)
                return snippets + pages

    async def _fetch_pages(self, session, snippets: str) -> str:
        """Fetch the top result pages to ground the model on real venue names. The
        search snippets are mostly listicle titles; the page bodies carry the actual
        restaurant names + addresses. Best-effort, capped, never raises.

        We pull from a larger candidate pool and SKIP pages that are (a) on an
        irrelevant domain (social/shopping/login walls), (b) failed fetches /
        403 / captcha / error pages, or (c) not actually about food — so the
        structurer only ever sees real restaurant content. Collects up to
        `_fetch_top_n` good pages."""
        urls = _top_urls(snippets, self._fetch_top_n * 3 + 3)
        out: list[str] = []
        kept = 0
        for url in urls:
            if kept >= self._fetch_top_n:
                break
            if _blocked_domain(url):
                log.info("skip (blocked domain): %s", url)
                continue
            try:
                res = await session.call_tool(self._fetch_tool, {self._fetch_url_arg: url})
                text = _flatten_tool_result(res)[: self._fetch_char_cap]
            except Exception as e:  # noqa: BLE001 — page fetch is optional enrichment
                log.warning("fetch_content failed for %s: %s", url, e)
                continue
            if _looks_like_error(text):
                log.info("skip (error/403/empty page): %s", url)
                continue
            if not _food_relevant(text):
                log.info("skip (not about food): %s", url)
                continue
            out.append(f"\n\n--- NỘI DUNG TỪ {url} ---\n{text}")
            kept += 1
        return "".join(out)


def _flatten_tool_result(result) -> str:
    """MCP tool results carry a list of content blocks; concatenate their text."""
    parts: list[str] = []
    for block in getattr(result, "content", []) or []:
        text = getattr(block, "text", None)
        if text:
            parts.append(text)
    return "\n".join(parts)


# Domains that never carry a usable restaurant listing (login walls, social,
# shopping, video) — skip before even fetching.
_BLOCKED_DOMAINS = (
    "facebook.com", "fb.com", "instagram.com", "youtube.com", "youtu.be",
    "tiktok.com", "twitter.com", "x.com", "pinterest.", "linkedin.com",
    "shopee.vn", "lazada.vn", "tiki.vn", "sendo.vn", "batdongsan.com",
    "google.com/maps", "maps.google.", "wikipedia.org",
)

# Markers of an access-denied / captcha / error page returned in the fetched body.
_ERROR_MARKERS = (
    "403 forbidden", "forbidden", "access denied", "access to this page",
    "captcha", "unusual traffic", "are you a robot", "verify you are human",
    "verify you are a human", "enable javascript", "please enable cookies",
    "just a moment", "404 not found", "page not found", "request blocked",
    "cloudflare", "attention required",
)

# Food/restaurant vocabulary (Vietnamese w/ diacritics + a few English) used to
# confirm a fetched page is actually about eating out. Generic words like "giá" or
# "địa chỉ" are intentionally excluded — they appear on every kind of page.
_FOOD_TERMS = (
    "quán ăn", "nhà hàng", "quán", "món ăn", "món ngon", "ẩm thực", "thực đơn",
    "đặc sản", "ăn uống", "lẩu", "nướng", "bún", "phở", "cơm", "hủ tiếu",
    "cà phê", "cafe", "hải sản", "buffet", "ăn vặt", "đồ ăn",
    "restaurant", "food", "cuisine", "menu", "dining", "eatery",
)


def _blocked_domain(url: str) -> bool:
    u = url.lower()
    return any(d in u for d in _BLOCKED_DOMAINS)


def _looks_like_error(text: str) -> bool:
    """True if the fetched body is empty/too short or an access-denied/error page."""
    if not text or len(text.strip()) < 200:
        return True
    head = text[:600].lower()
    return any(m in head for m in _ERROR_MARKERS)


def _food_relevant(text: str) -> bool:
    """True if the page mentions enough food/restaurant vocabulary to be worth
    feeding the structurer. Requires a few distinct hits so an off-topic page that
    merely name-drops "quán" once is still skipped."""
    low = text.lower()
    hits = sum(1 for t in _FOOD_TERMS if t in low)
    return hits >= 3


def _top_urls(text: str, n: int) -> list[str]:
    """Extract the first n distinct http(s) URLs from the search-result text."""
    seen: list[str] = []
    for m in _URL_RE.finditer(text):
        url = m.group(0).rstrip(".,);")
        if url not in seen:
            seen.append(url)
        if len(seen) >= n:
            break
    return seen


def build_search_provider(settings: Settings) -> SearchProvider:
    choice = settings.effective_search_provider()
    if choice == "mcp":
        log.info("search provider: mcp (%s via %s)", settings.mcp_search_tool, settings.mcp_server_cmd)
        return MCPWebSearchProvider(settings)
    log.info("search provider: mock")
    return MockSearchProvider()
