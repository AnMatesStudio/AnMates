"""Runtime config from env. Everything has a sensible default so the service
boots (in mock mode) with zero configuration."""

from __future__ import annotations

import os
import shlex
from dataclasses import dataclass, field
from typing import List


def _split(cmd: str) -> List[str]:
    return shlex.split(cmd) if cmd else []


@dataclass
class Settings:
    # --- search provider -----------------------------------------------------
    # "mcp"  → spawn an MCP web-search server over stdio and call its tool.
    # "mock" → return deterministic fake venues near the midpoint (offline/dev).
    search_provider: str = field(default_factory=lambda: os.getenv("SEARCH_PROVIDER", "mcp"))

    # Command that launches the MCP web-search server (stdio transport).
    # DEFAULT is FREE + KEYLESS: DuckDuckGo MCP server via uvx.
    #   uvx duckduckgo-mcp-server            (free, no API key)        ← default
    # Other options (need a paid key — not used here):
    #   npx -y @modelcontextprotocol/server-brave-search   (BRAVE_API_KEY)
    #   npx -y tavily-mcp                                   (TAVILY_API_KEY)
    mcp_server_cmd: List[str] = field(
        default_factory=lambda: _split(os.getenv("MCP_SERVER_CMD", "uvx duckduckgo-mcp-server"))
    )
    # The tool name to call on that server, and the name of its query argument.
    # Defaults match the DuckDuckGo MCP server (tool "search", arg "query").
    mcp_search_tool: str = field(default_factory=lambda: os.getenv("MCP_SEARCH_TOOL", "search"))
    mcp_query_arg: str = field(default_factory=lambda: os.getenv("MCP_QUERY_ARG", "query"))

    # After searching, fetch the top N result pages to ground the model on REAL venue
    # names/addresses (search snippets alone are mostly listicle titles). The DDG MCP
    # server exposes a "fetch_content" tool taking a "url" arg. Set top-N to 0 to skip.
    mcp_fetch_tool: str = field(default_factory=lambda: os.getenv("MCP_FETCH_TOOL", "fetch_content"))
    mcp_fetch_url_arg: str = field(default_factory=lambda: os.getenv("MCP_FETCH_URL_ARG", "url"))
    mcp_fetch_top_n: int = field(default_factory=lambda: int(os.getenv("MCP_FETCH_TOP_N", "2")))
    mcp_fetch_char_cap: int = field(default_factory=lambda: int(os.getenv("MCP_FETCH_CHAR_CAP", "2500")))

    # --- structurer ----------------------------------------------------------
    # Turns raw web-search text into structured venues. All free options speak the
    # OpenAI chat-completions shape (see providers/structurer.OpenAICompatStructurer).
    # "pollinations" → Pollinations free OpenAI-compatible endpoint — NO key, NO local
    #                  model, zero setup. (from github.com/zebbern/no-cost-ai)   ← default
    # "openai"       → a local OpenAI-compatible model (LM Studio / Ollama) — FREE, no
    #                  key, more robust (no public rate limit, private).
    # "anthropic"    → Claude extracts JSON (needs ANTHROPIC_API_KEY — paid).
    # "mock"         → naive offline extractor.
    structurer: str = field(default_factory=lambda: os.getenv("STRUCTURER", "pollinations"))

    # Pollinations free tier: anonymous works with no key (≈1 req/15s, basic models).
    # A token (optional) lifts the rate limit. https://text.pollinations.ai/openai
    pollinations_model: str = field(default_factory=lambda: os.getenv("POLLINATIONS_MODEL", "openai"))
    pollinations_token: str = field(default_factory=lambda: os.getenv("POLLINATIONS_TOKEN", ""))

    # Local OpenAI-compatible backend (LM Studio — the same box the project already
    # runs). No API key needed; LM Studio ignores Authorization.
    llm_base_url: str = field(default_factory=lambda: os.getenv("LLM_BASE_URL", "http://host.docker.internal:1234/v1"))
    llm_model: str = field(default_factory=lambda: os.getenv("LLM_MODEL", "qwen2.5-7b-instruct"))
    llm_api_key: str = field(default_factory=lambda: os.getenv("LLM_API_KEY", ""))

    # Optional paid backend.
    anthropic_api_key: str = field(default_factory=lambda: os.getenv("ANTHROPIC_API_KEY", ""))
    anthropic_model: str = field(default_factory=lambda: os.getenv("ANTHROPIC_MODEL", "claude-haiku-4-5-20251001"))

    # --- geocoding (free, keyless, OpenStreetMap Nominatim) ------------------
    # Reverse-geocode the midpoint → place name (better search query), and
    # forward-geocode each picked venue → real lat/lng + address (so map pins land
    # correctly instead of stacking on the midpoint). Disable for fully-offline runs.
    geocode_enabled: bool = field(default_factory=lambda: os.getenv("GEOCODE_ENABLED", "1") not in ("0", "false", ""))

    # --- misc ----------------------------------------------------------------
    request_timeout_s: float = field(default_factory=lambda: float(os.getenv("REQUEST_TIMEOUT_S", "55")))

    def effective_search_provider(self) -> str:
        """Fall back to mock when MCP can't actually run (no server command)."""
        if self.search_provider == "mcp" and not self.mcp_server_cmd:
            return "mock"
        return self.search_provider

    def effective_structurer(self) -> str:
        if self.structurer == "openai" and not self.llm_base_url:
            return "mock"
        if self.structurer == "anthropic" and not self.anthropic_api_key:
            return "mock"
        return self.structurer  # pollinations needs nothing; mock needs nothing


def load() -> "Settings":
    return Settings()
