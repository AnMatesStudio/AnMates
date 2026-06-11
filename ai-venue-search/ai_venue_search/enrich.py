"""Agentic venue enrichment: given one venue (name + address), crawl the live web
and return LLM-verified photos of *that food venue* plus structured facts.

The loop is deliberately agentic — it searches, lets the LLM judge what it found,
and reformulates + retries when the haul is weak — so a thin or wrong first result
self-corrects instead of shipping an unrelated photo. The LLM is the semantic gate
that pure string matching (the old Bing relevance filter) could not be: it sees the
venue identity + each candidate's page/caption and decides what is really this quán.
"""

from __future__ import annotations

import json
import logging
import re
from typing import List, Tuple
from urllib.parse import urlparse

from .config import Settings
from .providers.google_scrape import GoogleCrawler, PageContent
from .schemas import EnrichedImage, EnrichedInfo, EnrichRequest, EnrichResponse

log = logging.getLogger("ai_venue_search.enrich")


class VenueEnricher:
    def __init__(self, settings: Settings):
        self._settings = settings
        self._crawler = GoogleCrawler(
            headless=settings.enrich_headless,
            nav_timeout_ms=settings.enrich_nav_timeout_ms,
            max_pages=settings.enrich_max_pages,
            bing_fallback=settings.enrich_bing_fallback,
        )

    async def enrich(self, req: EnrichRequest) -> EnrichResponse:
        queries = _plan_queries(req)
        max_iter = min(len(queries), max(1, self._settings.enrich_max_iterations))
        seen_urls: set[str] = set()
        pages: List[PageContent] = []
        used = 0

        # Agentic loop: crawl with the next query, accumulate pages, stop early once
        # we have enough distinct candidate photos to verify.
        for used in range(1, max_iter + 1):
            new = await self._crawler.crawl(queries[used - 1])
            for p in new:
                p.images = [(u, cap) for (u, cap) in p.images if u not in seen_urls]
                seen_urls.update(u for u, _ in p.images)
                if p.images:
                    pages.append(p)
            if _candidate_count(pages) >= req.max_images:
                break

        if not pages:
            log.info("enrich(%r): no food-relevant pages found", req.name)
            return EnrichResponse(is_food_venue=False, provider=self._provider(), iterations=used)

        images, info, intro, is_food, cost = await self._verify(req, pages)
        return EnrichResponse(
            images=images[: req.max_images],
            info=info,
            is_food_venue=is_food and bool(images),
            intro=intro,
            cost_tokens=cost,
            provider=self._provider(),
            iterations=used,
        )

    def _provider(self) -> str:
        return f"google-scrape+{self._settings.effective_structurer()}"

    # --- verification + extraction -------------------------------------------

    async def _verify(
        self, req: EnrichRequest, pages: List[PageContent]
    ) -> Tuple[List[EnrichedImage], EnrichedInfo, str, bool, int]:
        """Ask the LLM which crawled images are genuinely this food venue and to
        extract its facts. Falls back to a structural heuristic (keep images from
        food-relevant pages) when the LLM is unavailable — still safe, because the
        candidates were already sourced only from food pages."""
        candidates = _flatten_candidates(pages)  # [(EnrichedImage, page_idx)]
        try:
            keep, info, intro, is_food, cost = await self._llm_judge(req, pages, candidates)
            images = [candidates[i][0] for i in keep if 0 <= i < len(candidates)]
            if images or not is_food:
                return images, info, intro, is_food, cost
            log.info("llm kept 0 images but called it food — using heuristic")
        except Exception as e:  # noqa: BLE001 — LLM down/bad output → heuristic
            log.warning("llm verify failed (%s) — heuristic fallback", e)

        images = [img for img, _ in candidates]
        return images, EnrichedInfo(), "", bool(images), 0

    async def _llm_judge(
        self, req: EnrichRequest, pages: List[PageContent], candidates: List[Tuple[EnrichedImage, int]]
    ) -> Tuple[List[int], EnrichedInfo, str, bool, int]:
        import httpx

        chat_url = self._settings.llm_base_url.rstrip("/") + "/chat/completions"
        headers = {"Content-Type": "application/json"}
        if self._settings.llm_api_key:
            headers["Authorization"] = f"Bearer {self._settings.llm_api_key}"
        payload = {
            "model": self._settings.llm_model,
            "temperature": 0.2,
            "max_tokens": 1500,
            "response_format": _VERIFY_SCHEMA,
            "messages": [
                {"role": "system", "content": _SYSTEM_PROMPT},
                {"role": "user", "content": _user_prompt(req, pages, candidates)},
            ],
        }
        async with httpx.AsyncClient(timeout=self._settings.request_timeout_s) as client:
            resp = await client.post(chat_url, json=payload, headers=headers)
            resp.raise_for_status()
            data = resp.json()
        choice = (data.get("choices") or [{}])[0].get("message", {})
        text = (choice.get("content") or "").strip() or (choice.get("reasoning_content") or "")
        cost = (data.get("usage") or {}).get("total_tokens", 0)
        keep, info, intro, is_food = _parse_verify_json(text)
        return keep, info, intro, is_food, cost


# --- query planning -----------------------------------------------------------


def _plan_queries(req: EnrichRequest) -> List[str]:
    """Ordered search queries, most-specific first. Later queries are the agent's
    fallback reformulations when the first pass finds too little."""
    name = req.name.strip()
    addr = req.address.strip()
    city = req.city.strip()
    where = addr or city
    queries = [
        f"{name} {where} nhà hàng quán ăn".strip(),
        f"{name} {city} đánh giá thực đơn".strip() if city else f"{name} đánh giá thực đơn",
        f"{name} restaurant {city}".strip(),
    ]
    # Dedup while preserving order; drop empties.
    seen: set[str] = set()
    out: List[str] = []
    for q in queries:
        q = re.sub(r"\s+", " ", q).strip()
        if q and q.lower() not in seen:
            seen.add(q.lower())
            out.append(q)
    return out


def _candidate_count(pages: List[PageContent]) -> int:
    return sum(len(p.images) for p in pages)


def _flatten_candidates(pages: List[PageContent]) -> List[Tuple[EnrichedImage, int]]:
    """One flat, indexed list of (image, page_idx) the LLM can refer to by number."""
    out: List[Tuple[EnrichedImage, int]] = []
    for pi, p in enumerate(pages):
        for url, caption in p.images:
            src = (urlparse(p.url).hostname or p.url)
            out.append((EnrichedImage(url=url, source=src, caption=caption), pi))
    return out


# --- LLM prompt + schema ------------------------------------------------------

_SYSTEM_PROMPT = (
    'Bạn là agent xác minh ảnh & thông tin quán ăn cho app ẩm thực "ĂnMates". '
    "Bạn nhận DỮ LIỆU CRAWL THẬT (các trang web về 1 quán + danh sách ảnh ứng viên kèm caption/nguồn). "
    "Nhiệm vụ:\n"
    "1) Quyết định đây có THẬT SỰ là một quán ăn/uống (nhà hàng, quán, cà phê...) hay không "
    '("is_food_venue").\n'
    "2) Chọn các ảnh THỰC SỰ về quán này (món ăn, không gian, mặt tiền, menu). "
    "LOẠI BỎ ảnh không liên quan ẩm thực (vd phòng mổ, người ngẫu nhiên, bản đồ, logo, ảnh stock chung chung). "
    'Trả về "keep_image_indices" là mảng chỉ số (0-based) ảnh giữ lại, theo thứ tự ưu tiên.\n'
    "3) Trích thông tin có THẬT trong nội dung crawl (đừng bịa): cuisine (loại món/ẩm thực), address, "
    "description (1-2 câu), opening_hours, phone, rating (số), price_min, price_max (đồng).\n"
    "QUY TẮC: Chỉ dùng TIẾNG VIỆT cho description/intro. Field nào không có thông tin thì để rỗng/null. "
    "Nếu không có ảnh nào hợp lệ, trả keep_image_indices rỗng. "
    "Trả DUY NHẤT JSON đúng schema."
)


def _user_prompt(req: EnrichRequest, pages: List[PageContent], candidates: List[Tuple[EnrichedImage, int]]) -> str:
    ident = f"QUÁN CẦN XÁC MINH: {req.name}"
    if req.address:
        ident += f" | địa chỉ gợi ý: {req.address}"
    if req.city:
        ident += f" | khu vực: {req.city}"

    page_blocks = []
    for pi, p in enumerate(pages):
        page_blocks.append(f"[TRANG {pi}] {p.url}\nTiêu đề: {p.title}\nNội dung: {p.text[:1200]}")

    img_lines = []
    for i, (img, pi) in enumerate(candidates):
        img_lines.append(f"{i}. (trang {pi}, nguồn {img.source}) caption: {img.caption or '(không có)'}")

    return (
        f"{ident}\n\n"
        f"=== NỘI DUNG CÁC TRANG CRAWL ĐƯỢC ===\n" + "\n\n".join(page_blocks) + "\n\n"
        f"=== ẢNH ỨNG VIÊN (chọn theo chỉ số) ===\n" + "\n".join(img_lines) + "\n"
    )


_VERIFY_SCHEMA = {
    "type": "json_schema",
    "json_schema": {
        "name": "venue_enrich",
        "strict": True,
        "schema": {
            "type": "object",
            "properties": {
                "is_food_venue": {"type": "boolean"},
                "keep_image_indices": {"type": "array", "items": {"type": "integer"}},
                "intro": {"type": "string"},
                "info": {
                    "type": "object",
                    "properties": {
                        "cuisine": {"type": "string"},
                        "address": {"type": "string"},
                        "description": {"type": "string"},
                        "opening_hours": {"type": "string"},
                        "phone": {"type": "string"},
                        "rating": {"type": ["number", "null"]},
                        "price_min": {"type": ["integer", "null"]},
                        "price_max": {"type": ["integer", "null"]},
                    },
                    "required": [
                        "cuisine", "address", "description", "opening_hours",
                        "phone", "rating", "price_min", "price_max",
                    ],
                    "additionalProperties": False,
                },
            },
            "required": ["is_food_venue", "keep_image_indices", "intro", "info"],
            "additionalProperties": False,
        },
    },
}


def _parse_verify_json(text: str) -> Tuple[List[int], EnrichedInfo, str, bool]:
    start, end = text.find("{"), text.rfind("}")
    if start < 0 or end < start:
        return [], EnrichedInfo(), "", False
    try:
        data = json.loads(text[start : end + 1])
    except json.JSONDecodeError:
        log.warning("enrich: bad json from model")
        return [], EnrichedInfo(), "", False

    keep = [int(i) for i in (data.get("keep_image_indices") or []) if isinstance(i, (int, float))]
    is_food = bool(data.get("is_food_venue"))
    intro = str(data.get("intro") or "").strip()[:160]
    raw = data.get("info") or {}
    info = EnrichedInfo(
        cuisine=str(raw.get("cuisine") or "")[:80],
        address=str(raw.get("address") or "")[:160],
        description=str(raw.get("description") or "")[:300],
        opening_hours=str(raw.get("opening_hours") or "")[:120],
        phone=str(raw.get("phone") or "")[:40],
        rating=_num(raw.get("rating")),
        price_min=_int(raw.get("price_min")),
        price_max=_int(raw.get("price_max")),
    )
    return keep, info, intro, is_food


def _num(v):
    try:
        return float(v) if v is not None else None
    except (TypeError, ValueError):
        return None


def _int(v):
    try:
        return int(v) if v is not None else None
    except (TypeError, ValueError):
        return None
