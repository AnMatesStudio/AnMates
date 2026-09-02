# Session: Containerize the LLM — run all services in Docker (Ollama)

**Date:** 2026-06-10
**Owner:** main-assistant
**Status:** Completed (config-only, **pending live `./start.sh` verification**)

## TL;DR
User asked to "modify start.sh to run all services in docker". Finding: the app
services (`db`, `api`, `ai_venue_search`, `flutter_web`) were **already** fully in
Docker via `docker compose`. The **only** host dependency left was the LLM the
venue-search sidecar uses as its structurer — `LLM_BASE_URL=http://host.docker.internal:1234/v1`
(LM Studio on the host). User chose **"Containerize the LLM"**. So I added a bundled
**Ollama** container and repointed the sidecar at it → the whole stack is now
self-contained (no host model, no cloud).

## What changed

### `docker-compose.yml`
- **New `ollama` service** (`ollama/ollama:latest`) — OpenAI-compatible API at
  `:11434/v1`, models persisted in a named `ollama` volume, healthcheck `ollama list`,
  published on `127.0.0.1:11434`.
- **New `ollama_pull` one-shot** — `entrypoint: ollama pull ${OLLAMA_MODEL}` with
  `OLLAMA_HOST=http://ollama:11434` so the CLI drives the server container; `restart:"no"`;
  idempotent (no-op once the model is cached). First run downloads ~2GB into the volume.
- **`ai_venue_search` repointed**: `STRUCTURER` default `pollinations` → **`openai`**;
  `LLM_BASE_URL` default `host.docker.internal:1234` → **`http://ollama:11434/v1`**;
  `LLM_MODEL` now `${OLLAMA_MODEL:-qwen2.5:3b}` (single source of truth, shared with the
  puller). Added `depends_on: ollama (service_healthy)`. Kept `extra_hosts` so a user can
  still override `LLM_BASE_URL` back to a host model.
- Added `ollama` to the `volumes:` block.

### `docker-compose.gpu.yml` (NEW)
- Opt-in NVIDIA override (`deploy.resources.reservations.devices` → nvidia/all/gpu).
- Kept OUT of base on purpose: requesting an NVIDIA device makes `up` fail on boxes
  without the NVIDIA Container Toolkit. Merged only when asked.

### `start.sh`
- **5b. Compose-file + LLM mode select**: exports `COMPOSE_FILE` (read by every
  `docker compose` call). `OLLAMA_GPU=1` merges `docker-compose.gpu.yml`; default is CPU.
  If `nvidia-smi` is present but GPU not requested, prints a hint to re-run with
  `OLLAMA_GPU=1`. Exports `OLLAMA_MODEL` (default `qwen2.5:3b`) so compose + the puller agree.
- **8b. LLM model wait**: after web is up, polls `docker compose exec -T ollama ollama list`
  for the model (≤10 min) so the model is ready before the user gets deep into chat.
  Soft wait — only warns on timeout (download keeps going in the background).
- Banner now lists the Ollama LLM URL + model; startup log mentions AI search · Ollama.

### `.env` / `.env.example`
- AI Concierge section now documents the in-Docker Ollama structurer. `.env`: removed
  stale `LLM_MODEL=qwen/qwen3.5-9b`, set `STRUCTURER=openai` + `OLLAMA_MODEL=qwen2.5:3b`.
  Documented `STRUCTURER=pollinations` (cloud) and `OLLAMA_MODEL=qwen2.5:7b` + `OLLAMA_GPU=1`
  (bigger model on GPU) as the two escape hatches.

## How it fits together
```
ai_venue_search (STRUCTURER=openai)
   └─ POST http://ollama:11434/v1/chat/completions  (strict json_schema, json_mode=True)
        └─ ollama serve  ← model pulled by ollama_pull into the `ollama` volume
```
The sidecar's existing `_lm_studio` builder (providers/structurer.py) already speaks this
exact OpenAI shape with `response_format: json_schema` — only the URL/model/structurer
defaults changed, no Python code edits needed.

## Verification done (static)
- `docker compose -f docker-compose.yml config -q` → OK
- `docker compose -f docker-compose.yml -f docker-compose.gpu.yml config -q` → OK (merge)
- `docker compose config` resolves: sidecar `LLM_BASE_URL=http://ollama:11434/v1`,
  `LLM_MODEL=qwen2.5:3b`, `STRUCTURER=openai`; puller `ollama pull qwen2.5:3b`,
  `OLLAMA_HOST=http://ollama:11434`.
- `bash -n start.sh` → OK

## Verification PENDING (user — run `./start.sh`)
1. First run pulls the `ollama/ollama` image + the `qwen2.5:3b` model (~2GB) — confirm the
   8b wait passes and the banner shows the Ollama URL.
2. **Key risk to confirm:** Ollama's `/v1/chat/completions` honoring the sidecar's strict
   `response_format: json_schema` (the `_VENUE_SCHEMA`, incl. `["number","null"]` unions).
   LM Studio handled it; verify Ollama latest does too. If venues come back empty / malformed:
   - try a larger model: `OLLAMA_MODEL=qwen2.5:7b ./start.sh` (GPU: add `OLLAMA_GPU=1`), or
   - fall back to cloud: `STRUCTURER=pollinations` in `.env`.
3. Drive an AI Concierge card end-to-end (chat → Vibe ≥ 70 → `ai_venue_card`) and confirm
   real VN venue names, now sourced from the in-Docker LLM.
4. On a GPU box (RTX 5080), confirm `OLLAMA_GPU=1 ./start.sh` works (needs NVIDIA Container
   Toolkit / Docker Desktop WSL2 GPU). Without it, CPU `qwen2.5:3b` should still respond
   within the sidecar's 55s timeout.

## Open follow-ups
- If `qwen2.5:3b` quality is weak for venue extraction, make `qwen2.5:7b` the default once
  GPU is confirmed working on the dev box.
- When user confirms → migrate to a resolution (R-007) with tags
  `docker`, `ai-venue-search`, `ai-concierge`, `ollama`, `llm`.

## Key facts
- All app services were already in Docker; this change removes the last host/cloud LLM dep.
- GPU is **opt-in** (`OLLAMA_GPU=1`) by design — keeps the default `up` working on any box.
- `OLLAMA_MODEL` is the single knob for model choice (used by both the sidecar and the puller).
