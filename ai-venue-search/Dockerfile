FROM python:3.12-slim

WORKDIR /app
COPY requirements.txt .
# `uv` (in requirements) provides `uvx`. No Node / API keys needed for the default
# free setup (Pollinations structurer + DuckDuckGo MCP search).
RUN pip install --no-cache-dir -r requirements.txt
# Pre-install the free DuckDuckGo MCP server so the first /suggest doesn't pay the
# download cost at request time (would otherwise risk the caller's timeout).
RUN uv tool install duckduckgo-mcp-server || true
# Chromium + its OS libs for the agentic venue-enrichment crawl (Playwright). The
# `--with-deps` apt step is what makes headless Chromium run in the slim image.
# Best-effort: if it fails the service still boots and enrich falls back to Bing.
RUN playwright install --with-deps chromium || true

COPY ai_venue_search ./ai_venue_search

ENV PORT=8090
EXPOSE 8090
CMD ["sh", "-c", "uvicorn ai_venue_search.app:app --host 0.0.0.0 --port ${PORT}"]
