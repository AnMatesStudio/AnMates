"""Structurers turn raw web-search text into a list of `Venue` objects with a
short Vietnamese reason each, plus a warm intro line. They are the only place
that "understands" restaurants — search providers stay dumb."""

from __future__ import annotations

import abc
import json
import logging
import re
from typing import List, Tuple

from ..config import Settings
from ..schemas import SuggestRequest, Venue

log = logging.getLogger("ai_venue_search.structurer")

_DEFAULT_INTRO = "2 đứa hợp gu rồi nè! Đây là vài chỗ ngon, vừa túi tiền, nằm giữa 2 đứa:"


class Structurer(abc.ABC):
    name: str = "base"

    @abc.abstractmethod
    async def structure(self, req: SuggestRequest, raw: str) -> Tuple[str, List[Venue], int]:
        """Return (intro, venues, cost_tokens)."""
        raise NotImplementedError


class MockStructurer(Structurer):
    """Offline parser: pulls "<n>. Name - description ... giá Ak-Bk, rating R"
    lines out of the mock search blob with simple, forgiving sub-searches.
    Coordinates are jittered around the requested midpoint so the Flutter map
    pins land somewhere sensible in dev."""

    name = "mock"

    _NUMBERED = re.compile(r"^\s*\d+\.\s*(.+)$")
    _PRICE = re.compile(r"giá\s*(\d+)k(?:\s*-\s*(\d+)k)?", re.IGNORECASE)
    _RATING = re.compile(r"rating\s*([\d.]+)", re.IGNORECASE)

    async def structure(self, req: SuggestRequest, raw: str) -> Tuple[str, List[Venue], int]:
        venues: List[Venue] = []
        for line in raw.splitlines():
            m = self._NUMBERED.match(line)
            if not m:
                continue
            body = m.group(1)
            name, _, desc = body.partition(" - ")

            pmin = pmax = None
            if pm := self._PRICE.search(body):
                pmin = int(pm.group(1)) * 1000
                pmax = int(pm.group(2)) * 1000 if pm.group(2) else pmin
            rating = float(rm.group(1)) if (rm := self._RATING.search(body)) else None

            venues.append(
                Venue(
                    name=name.strip()[:80],
                    address=desc.strip()[:120],
                    rating=rating,
                    price_min=pmin,
                    price_max=pmax,
                    lat=req.lat + (len(venues) - 1) * 0.002,
                    lng=req.lng + (len(venues) - 1) * 0.002,
                    reason="Gần điểm giữa, hợp gu 2 đứa",
                )
            )
            if len(venues) >= req.limit:
                break
        return _DEFAULT_INTRO, venues, 0


class OpenAICompatStructurer(Structurer):
    """FREE structurer over any OpenAI chat-completions endpoint. Two presets use
    it (see build_structurer):
      - "pollinations" → https://text.pollinations.ai/openai (no key, zero setup)
      - "openai"       → local LM Studio / Ollama (no key, robust/private)
    `chat_url` is the FULL completions URL (Pollinations has no /chat/completions
    suffix; LM Studio does)."""

    def __init__(self, name: str, chat_url: str, model: str, api_key: str, timeout: float, json_mode: bool = False):
        self.name = name
        self._chat_url = chat_url
        self._model = model
        self._api_key = api_key
        self._timeout = timeout
        self._json_mode = json_mode

    async def structure(self, req: SuggestRequest, raw: str) -> Tuple[str, List[Venue], int]:
        import httpx

        headers = {"Content-Type": "application/json"}
        if self._api_key:
            headers["Authorization"] = f"Bearer {self._api_key}"
        payload = {
            "model": self._model,
            "temperature": 0.4,
            "max_tokens": 2000,
            "messages": [
                {"role": "system", "content": _SYSTEM_PROMPT},
                {"role": "user", "content": _user_prompt(req, raw)},
            ],
        }
        # Force the exact JSON shape on servers that support structured output
        # (LM Studio / Ollama). A strict json_schema is what tames small reasoning
        # models (Qwen3) — the same approach the Go backend's llm.go verified.
        # Not enabled for Pollinations (it may reject the field).
        if self._json_mode:
            payload["response_format"] = _VENUE_SCHEMA
        async with httpx.AsyncClient(timeout=self._timeout) as client:
            resp = await client.post(self._chat_url, json=payload, headers=headers)
            resp.raise_for_status()
            data = resp.json()

        choice = (data.get("choices") or [{}])[0].get("message", {})
        # Reasoning models (Qwen3 in LM Studio) route the answer into reasoning_content.
        text = (choice.get("content") or "").strip() or (choice.get("reasoning_content") or "")
        cost = (data.get("usage") or {}).get("total_tokens", 0)
        intro, venues = _parse_model_json(text, req.limit)
        return intro, venues, cost


class AnthropicStructurer(Structurer):
    """Uses Claude to extract structured venues from the raw search text. The
    model only reformats what the search returned — it must not invent venues
    that aren't in the text (instructed in the prompt)."""

    name = "anthropic"

    def __init__(self, settings: Settings):
        self._model = settings.anthropic_model
        self._api_key = settings.anthropic_api_key

    async def structure(self, req: SuggestRequest, raw: str) -> Tuple[str, List[Venue], int]:
        from anthropic import AsyncAnthropic

        client = AsyncAnthropic(api_key=self._api_key)
        resp = await client.messages.create(
            model=self._model,
            max_tokens=1500,
            system=_SYSTEM_PROMPT,
            messages=[{"role": "user", "content": _user_prompt(req, raw)}],
        )
        text = "".join(b.text for b in resp.content if getattr(b, "type", "") == "text")
        cost = resp.usage.input_tokens + resp.usage.output_tokens
        intro, venues = _parse_model_json(text, req.limit)
        return intro, venues, cost


class FallbackStructurer(Structurer):
    """Tries each structurer in order; returns the first that succeeds with at
    least one venue. Lets the free zero-setup backend (Pollinations) be primary
    while a robust local model (LM Studio) catches its frequent free-tier 429s."""

    def __init__(self, chain: List[Structurer]):
        self._chain = chain
        self.name = "+".join(s.name for s in chain) or "none"

    async def structure(self, req: SuggestRequest, raw: str) -> Tuple[str, List[Venue], int]:
        last_exc: Exception | None = None
        for s in self._chain:
            try:
                intro, venues, cost = await s.structure(req, raw)
                if venues:
                    return intro, venues, cost
                log.warning("structurer %s returned 0 venues — trying next", s.name)
            except Exception as e:  # noqa: BLE001 — any backend failure → next in chain
                last_exc = e
                log.warning("structurer %s failed (%s) — trying next", s.name, e)
        if last_exc is not None:
            raise last_exc
        return _DEFAULT_INTRO, [], 0


# Strict structured-output schema for OpenAI-compatible servers (LM Studio/Ollama).
# Mirrors the Venue fields the Flutter card consumes. strict + additionalProperties
# false forces the model to emit exactly this shape.
_VENUE_SCHEMA = {
    "type": "json_schema",
    "json_schema": {
        "name": "venue_picks",
        "strict": True,
        "schema": {
            "type": "object",
            "properties": {
                "intro": {"type": "string"},
                "picks": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "name": {"type": "string"},
                            "address": {"type": "string"},
                            "rating": {"type": ["number", "null"]},
                            "price_min": {"type": ["integer", "null"]},
                            "price_max": {"type": ["integer", "null"]},
                            "lat": {"type": "number"},
                            "lng": {"type": "number"},
                            "reason": {"type": "string"},
                        },
                        "required": ["name", "address", "rating", "price_min", "price_max", "lat", "lng", "reason"],
                        "additionalProperties": False,
                    },
                },
            },
            "required": ["intro", "picks"],
            "additionalProperties": False,
        },
    },
}


def _user_prompt(req: SuggestRequest, raw: str) -> str:
    budget = f"{req.budget_min}-{req.budget_max}đ" if req.budget_max else "không giới hạn"
    mood = ", ".join(req.mood_tags) or "không rõ"
    return (
        f"Toạ độ điểm giữa: {req.lat},{req.lng}. Gu/mood: {mood}. Ngân sách: {budget}.\n"
        f"Số quán cần chọn: tối đa {req.limit}.\n\n"
        f"KẾT QUẢ WEB SEARCH:\n{raw}\n"
    )


_SYSTEM_PROMPT = (
    'Bạn là "Trợ lý ĂnMates", gợi ý quán ăn cho 2 người vừa hợp gu trên app hẹn hò ẩm thực. '
    "Từ KẾT QUẢ WEB SEARCH cho sẵn, chọn các quán hợp nhất (gần khu vực điểm giữa, hợp mood, vừa ngân sách).\n"
    "QUY TẮC QUAN TRỌNG:\n"
    '- "name" PHẢI là tên MỘT quán ăn cụ thể (vd "Lẩu Dê 6 Tửng", "Ashima"), '
    'TUYỆT ĐỐI KHÔNG dùng tiêu đề bài viết / danh sách (vd "Top 20 quán lẩu...", "Top 12...") làm tên quán. '
    "Hãy bóc tên quán cụ thể nằm BÊN TRONG tiêu đề/đoạn mô tả kết quả search.\n"
    "- Nếu không tìm được tên quán cụ thể nào, trả picks rỗng — KHÔNG bịa, KHÔNG dùng tên bài viết.\n"
    '- "address": ghi địa chỉ/khu vực cụ thể nếu kết quả có nêu, không thì để "".\n'
    '- lat và lng LUÔN để 0 — hệ thống tự định vị theo tên quán, đừng đoán toạ độ.\n'
    "- CHỈ DÙNG TIẾNG VIỆT, không dùng chữ Hán/tiếng Trung trong intro và reason. "
    '"intro" ấm áp, ngắn (<140 ký tự). "reason" mỗi quán <60 ký tự.\n'
    "Trả DUY NHẤT JSON đúng schema: "
    '{"intro": string, "picks": [{"name": string, "address": string, "rating": number|null, '
    '"price_min": number|null, "price_max": number|null, "lat": number, "lng": number, "reason": string}]}'
)


def _parse_model_json(text: str, limit: int) -> Tuple[str, List[Venue]]:
    start, end = text.find("{"), text.rfind("}")
    if start < 0 or end < start:
        return _DEFAULT_INTRO, []
    try:
        data = json.loads(text[start : end + 1])
    except json.JSONDecodeError:
        log.warning("structurer: bad json from model")
        return _DEFAULT_INTRO, []
    intro = (data.get("intro") or _DEFAULT_INTRO).strip()[:160]
    venues: List[Venue] = []
    for p in (data.get("picks") or [])[:limit]:
        if not p.get("name"):
            continue
        venues.append(
            Venue(
                name=str(p["name"])[:80],
                address=str(p.get("address") or "")[:160],
                rating=_num(p.get("rating")),
                price_min=_int(p.get("price_min")),
                price_max=_int(p.get("price_max")),
                lat=float(p.get("lat") or 0),
                lng=float(p.get("lng") or 0),
                reason=str(p.get("reason") or "")[:80],
            )
        )
    return intro, venues


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


POLLINATIONS_URL = "https://text.pollinations.ai/openai"


def _pollinations(settings: Settings) -> OpenAICompatStructurer:
    return OpenAICompatStructurer(
        name="pollinations", chat_url=POLLINATIONS_URL,
        model=settings.pollinations_model, api_key=settings.pollinations_token,
        timeout=settings.request_timeout_s,
    )


def _lm_studio(settings: Settings) -> OpenAICompatStructurer:
    return OpenAICompatStructurer(
        name="openai", chat_url=settings.llm_base_url.rstrip("/") + "/chat/completions",
        model=settings.llm_model, api_key=settings.llm_api_key,
        timeout=settings.request_timeout_s, json_mode=True,
    )


def build_structurer(settings: Settings) -> Structurer:
    choice = settings.effective_structurer()
    if choice == "pollinations":
        # Free zero-setup primary, with the local model as a robust fallback for
        # Pollinations' frequent anonymous-tier 429s.
        chain: List[Structurer] = [_pollinations(settings)]
        if settings.llm_base_url:
            chain.append(_lm_studio(settings))
        log.info("structurer: %s", "+".join(s.name for s in chain))
        return FallbackStructurer(chain) if len(chain) > 1 else chain[0]
    if choice == "openai":
        log.info("structurer: openai-compat (%s @ %s)", settings.llm_model, settings.llm_base_url)
        return _lm_studio(settings)
    if choice == "anthropic":
        log.info("structurer: anthropic (%s)", settings.anthropic_model)
        return AnthropicStructurer(settings)
    log.info("structurer: mock")
    return MockStructurer()
