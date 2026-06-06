"""Pluggable provider layer: search (find raw results) + structurer (parse them
into venues). Each has a factory that picks the implementation from Settings, so
swapping MCP servers or LLMs is a config change, never a code change."""

from .search import SearchProvider, build_search_provider
from .structurer import Structurer, build_structurer

__all__ = ["SearchProvider", "build_search_provider", "Structurer", "build_structurer"]
