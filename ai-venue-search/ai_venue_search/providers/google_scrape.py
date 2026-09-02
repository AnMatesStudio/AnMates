"""Realtime web crawl for the venue-enrichment agent.

`GoogleCrawler` drives a headless Chromium (Playwright) over google.com to FIND
the pages about a specific venue, then fetches those pages with httpx to pull
their photos (og:image + content <img> with alt text) and body text. Sourcing
images only from food-relevant venue pages is what structurally avoids the
"unrelated photo" bug — we never crawl an operating-room page for a restaurant.

Everything degrades gracefully: if Playwright isn't installed, Chromium can't
launch, or Google serves its /sorry/ CAPTCHA, the crawler falls back to a keyless
Bing web search over httpx, and ultimately returns empty (→ honest placeholder).
"""

from __future__ import annotations

import asyncio
import logging
import re
from dataclasses import dataclass, field
from html import unescape
from typing import List, Optional, Tuple
from urllib.parse import urljoin, urlparse

import httpx

from .search import _blocked_domain, _food_relevant, _looks_like_error  # reuse filters

log = logging.getLogger("ai_venue_search.google_scrape")

# Realistic desktop UA — Google and CDNs reject obvious bots.
_UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
)


@dataclass
class SearchHit:
    title: str
    url: str


@dataclass
class PageContent:
    """One crawled venue page: its images (url + alt caption) and trimmed text."""

    url: str
    title: str = ""
    text: str = ""
    images: List[Tuple[str, str]] = field(default_factory=list)  # (img_url, alt/caption)


class GoogleCrawler:
    def __init__(
        self,
        *,
        headless: bool = True,
        nav_timeout_ms: int = 15000,
        page_char_cap: int = 3000,
        max_pages: int = 4,
        bing_fallback: bool = True,
    ):
        self._headless = headless
        self._nav_timeout = nav_timeout_ms
        self._char_cap = page_char_cap
        self._max_pages = max_pages
        self._bing_fallback = bing_fallback

    # --- public API ----------------------------------------------------------

    async def crawl(self, query: str) -> List[PageContent]:
        """Search the live web for `query`, then fetch the top food-relevant pages
        and return their images + text. Best-effort; never raises."""
        hits = await self._web_results(query, self._max_pages * 3 + 3)
        out: List[PageContent] = []
        async with httpx.AsyncClient(
            timeout=10.0, follow_redirects=True, headers={"User-Agent": _UA}
        ) as client:
            for hit in hits:
                if len(out) >= self._max_pages:
                    break
                if _blocked_domain(hit.url):
                    continue
                page = await self._fetch_page(client, hit)
                if page is not None:
                    out.append(page)
        log.info("crawl(%r): %d hits -> %d usable pages", query, len(hits), len(out))
        return out

    # --- step 1: find venue pages (Google headless, Bing fallback) ------------

    async def _web_results(self, query: str, n: int) -> List[SearchHit]:
        try:
            hits = await self._google_results(query, n)
            if hits:
                return hits
            log.info("google returned 0 hits (blocked/empty) for %r", query)
        except Exception as e:  # noqa: BLE001 — any Playwright/launch failure → fallback
            log.warning("google scrape failed (%s) — falling back to bing", e)
        if self._bing_fallback:
            try:
                return await self._bing_results(query, n)
            except Exception as e:  # noqa: BLE001
                log.warning("bing fallback failed: %s", e)
        return []

    async def _google_results(self, query: str, n: int) -> List[SearchHit]:
        """Headless Google web search. Returns [] on the CAPTCHA / consent wall so
        the caller can fall back rather than crash."""
        from playwright.async_api import async_playwright  # lazy: optional dep

        url = f"https://www.google.com/search?q={httpx.QueryParams({'q': query})['q']}&hl=vi&num={n}"
        async with async_playwright() as pw:
            browser = await pw.chromium.launch(
                headless=self._headless,
                args=["--no-sandbox", "--disable-blink-features=AutomationControlled"],
            )
            try:
                ctx = await browser.new_context(user_agent=_UA, locale="vi-VN")
                page = await ctx.new_page()
                await page.goto(url, wait_until="domcontentloaded", timeout=self._nav_timeout)
                await self._dismiss_consent(page)
                if await self._is_blocked(page):
                    log.info("google served CAPTCHA/sorry page for %r", query)
                    return []
                raw = await page.evaluate(_EXTRACT_HITS_JS)
            finally:
                await browser.close()
        return _dedup_hits(raw)

    @staticmethod
    async def _dismiss_consent(page) -> None:
        """Click through the EU consent interstitial if Google shows one."""
        if "consent.google" not in page.url and "consent." not in page.url:
            return
        for sel in (
            'button:has-text("Accept all")',
            'button:has-text("Chấp nhận tất cả")',
            'button:has-text("Reject all")',
            'button:has-text("Từ chối tất cả")',
            "#L2AGLb",
        ):
            try:
                btn = await page.query_selector(sel)
                if btn:
                    await btn.click()
                    await page.wait_for_load_state("domcontentloaded", timeout=5000)
                    return
            except Exception:  # noqa: BLE001 — best-effort consent dismissal
                continue

    @staticmethod
    async def _is_blocked(page) -> bool:
        if "/sorry/" in page.url or "sorry/index" in page.url:
            return True
        try:
            body = (await page.inner_text("body"))[:600].lower()
        except Exception:  # noqa: BLE001
            return False
        return any(m in body for m in ("unusual traffic", "are you a robot", "verify you are human"))

    async def _bing_results(self, query: str, n: int) -> List[SearchHit]:
        """Keyless Bing web search over httpx — used when Google is unavailable."""
        async with httpx.AsyncClient(
            timeout=10.0, follow_redirects=True, headers={"User-Agent": _UA, "Accept-Language": "vi,en;q=0.9"}
        ) as client:
            resp = await client.get("https://www.bing.com/search", params={"q": query, "count": n, "setlang": "vi"})
            resp.raise_for_status()
            return _dedup_hits(_parse_bing_serp(resp.text))[:n]

    # --- step 2: pull photos + text off each page ----------------------------

    async def _fetch_page(self, client: httpx.AsyncClient, hit: SearchHit) -> Optional[PageContent]:
        try:
            resp = await client.get(hit.url)
            if resp.status_code != 200 or "text/html" not in resp.headers.get("content-type", ""):
                return None
            html = resp.text
        except Exception as e:  # noqa: BLE001 — page fetch is best-effort
            log.info("fetch failed %s: %s", hit.url, e)
            return None

        text = _visible_text(html)[: self._char_cap]
        if _looks_like_error(text) or not _food_relevant(text):
            log.info("skip (error/not-food): %s", hit.url)
            return None
        images = _extract_images(html, hit.url)
        if not images:
            return None
        return PageContent(url=hit.url, title=hit.title, text=text, images=images)


# --- HTML extraction (pure, unit-tested) --------------------------------------

# Pull each Google result's title + href. Google wraps every organic hit's title
# in an <h3> inside its result <a>; this stays robust across minor layout changes.
_EXTRACT_HITS_JS = """
() => {
  const out = [];
  const seen = new Set();
  document.querySelectorAll('a h3').forEach(h3 => {
    const a = h3.closest('a');
    if (!a || !a.href) return;
    if (seen.has(a.href)) return;
    seen.add(a.href);
    out.push({title: (h3.innerText || '').trim(), url: a.href});
  });
  return out;
}
"""

_OG_IMAGE_RE = re.compile(
    r'<meta[^>]+(?:property|name)=["\'](?:og:image|twitter:image)(?::secure_url|:src)?["\'][^>]*content=["\']([^"\']+)["\']',
    re.IGNORECASE,
)
_IMG_TAG_RE = re.compile(r"<img\b[^>]*>", re.IGNORECASE)
_ATTR_RE = re.compile(r'(\w[\w:-]*)\s*=\s*"([^"]*)"', re.IGNORECASE)
_TAG_STRIP_RE = re.compile(r"(?is)<(script|style|noscript)\b.*?</\1>")
_TAGS_RE = re.compile(r"(?s)<[^>]+>")
_WS_RE = re.compile(r"\s+")

# Junk asset markers (logos, icons, ads, UI chrome) — mirrors the Go side.
_JUNK_MARKERS = (
    "logo", "icon", "favicon", "sprite", "avatar", "banner", "/ads", "advert",
    "pixel", "placeholder", "loading", "blank", "spacer", "share", "social",
    "button", "/flag", "emoji", "no-image", "noimage", "1x1", "lazy",
)
_IMG_EXT_RE = re.compile(r"\.(jpe?g|png|webp)(?:[?#].*)?$", re.IGNORECASE)


def _is_junk_image(u: str) -> bool:
    low = u.lower()
    return any(m in low for m in _JUNK_MARKERS)


def _extract_images(html: str, base_url: str) -> List[Tuple[str, str]]:
    """Return (absolute_url, alt_caption) photo candidates from one page: the
    social-preview og:image first (usually the best hero), then content <img>
    tags carrying alt text. Junk assets and duplicates are dropped."""
    out: List[Tuple[str, str]] = []
    seen: set[str] = set()

    def add(raw: str, alt: str) -> None:
        if not raw:
            return
        u = urljoin(base_url, unescape(raw.strip()))
        if not u.lower().startswith("http") or u in seen or _is_junk_image(u):
            return
        seen.add(u)
        out.append((u, _WS_RE.sub(" ", unescape(alt or "")).strip()[:140]))

    page_title = _title(html)
    for m in _OG_IMAGE_RE.finditer(html):
        add(m.group(1), page_title)

    for tag in _IMG_TAG_RE.finditer(html):
        attrs = {k.lower(): v for k, v in _ATTR_RE.findall(tag.group(0))}
        src = attrs.get("src") or attrs.get("data-src") or attrs.get("data-original") or ""
        # Keep only real photo URLs (skip data: URIs and non-image assets).
        if not src or src.startswith("data:") or not _IMG_EXT_RE.search(src):
            continue
        add(src, attrs.get("alt") or attrs.get("title") or page_title)

    return out


def _title(html: str) -> str:
    m = re.search(r"(?is)<title[^>]*>(.*?)</title>", html)
    return _WS_RE.sub(" ", unescape(m.group(1))).strip()[:140] if m else ""


def _visible_text(html: str) -> str:
    """Crude HTML→text: drop script/style, strip tags, collapse whitespace. Good
    enough to feed the LLM venue facts and to run the food-relevance check on."""
    stripped = _TAG_STRIP_RE.sub(" ", html)
    return _WS_RE.sub(" ", _TAGS_RE.sub(" ", stripped)).strip()


_HREF_RE = re.compile(r'<a\b[^>]*href="([^"]+)"[^>]*>(.*?)</a>', re.IGNORECASE | re.DOTALL)
_BING_RESULT_RE = re.compile(r'<h2><a\b[^>]*href="(http[^"]+)"[^>]*>(.*?)</a></h2>', re.IGNORECASE | re.DOTALL)


def _parse_bing_serp(html: str) -> List[SearchHit]:
    """Extract organic result (url, title) pairs from a Bing SERP HTML page."""
    hits: List[SearchHit] = []
    for m in _BING_RESULT_RE.finditer(html):
        url = unescape(m.group(1))
        title = _WS_RE.sub(" ", _TAGS_RE.sub(" ", m.group(2))).strip()
        if url.lower().startswith("http"):
            hits.append(SearchHit(title=title[:140], url=url))
    return hits


def _dedup_hits(raw) -> List[SearchHit]:
    """Normalize either dicts (from JS evaluate) or SearchHits into a deduped list,
    dropping search-engine-internal and obviously-blocked domains."""
    out: List[SearchHit] = []
    seen: set[str] = set()
    for r in raw or []:
        url = r["url"] if isinstance(r, dict) else r.url
        title = r.get("title", "") if isinstance(r, dict) else r.title
        if not url or url in seen:
            continue
        host = (urlparse(url).hostname or "").lower()
        if not host or host.endswith("google.com") or host.endswith("bing.com") or host.endswith("microsoft.com"):
            continue
        seen.add(url)
        out.append(SearchHit(title=(title or "").strip()[:140], url=url))
    return out
