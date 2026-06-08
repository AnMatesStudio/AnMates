# 2026-06-07 — Prod CD gaps: missing AI_SEARCH_URL + no sidecar CD

## TL;DR
Audited what auto-deploys to **prod** when `feat/ai-concierge-map` merges to `main`. Found two gaps that would break the AI Concierge feature on prod, and fixed both in `.github/workflows/`.

## Root cause / findings
- `cd.go-api.yml` (prod, push→main) did **not** set `AI_SEARCH_URL`, while `ci.go-api.yml` (dev) does. Cloud Run `--set-env-vars` has **replace** semantics (not merge), and Go reads it with no default (`config.go:91` `os.Getenv("AI_SEARCH_URL")`; `main.go:120-122` → AI Concierge disabled if unset). ⇒ a prod deploy would **drop** `AI_SEARCH_URL` and silently disable AI Concierge venue search.
- `ai-venue-search/` had **only** `ci.ai-venue-search.yml` (deploys to **dev** on PR). No `cd.ai-venue-search.yml` existed ⇒ sidecar would **never** deploy to prod on merge; prod keeps running the old image.
- Context: dev & prod still **share one Cloud Run service** (`anmates-api`) + one DB (transitional — see WORKFLOW-ARCHITECTURE.md "Dev environment"). So the same `ai-venue-search` service name is used for both tiers; prod CD targets the same service.
- Not a gap: DB migrations auto-apply on API startup (`db/migrate.go`), so no manual migration step.
- Still NOT auto-deployed (by design / not yet built): Flutter Android/iOS (no workflows).

## Solution (files changed)
1. `cd.go-api.yml` — added `--set-env-vars "AI_SEARCH_URL=${{ vars.AI_SEARCH_URL || 'https://ai-venue-search-492509819332.asia-southeast1.run.app' }}"` to the prod deploy step (mirrors dev).
2. `cd.ai-venue-search.yml` — NEW. push→main on `ai-venue-search/**` (+ workflow_dispatch). Pytest → build+push image (tags `:sha` + `:latest`) → capture prev revision → deploy Cloud Run (port 8090, 1Gi/1cpu/120s, `STRUCTURER=pollinations`, `GEOCODE_ENABLED=1`) → `/health` smoke → rollback-on-failure. Modeled on `cd.go-api.yml`.

## Verification (PENDING)
- No YAML linter / actionlint available on host (no Python, no powershell-yaml). New file copied structure verbatim from valid `cd.go-api.yml`; the go-api edit added one line in-style. **Not yet run in GitHub Actions.**
- ⚠️ Confirm GitHub repo **variable** `AI_SEARCH_URL` (or the hardcoded fallback URL) is correct before/at merge.

## Open follow-ups
- When prod splits off shared infra (production-mvp), give the sidecar its own prod service + move env to Secret Manager (same as go-api plan).
- Consider documenting the new `cd.ai-venue-search.yml` in `.github/WORKFLOW-ARCHITECTURE.md` Phase 1 file listing.

## Key facts
- `--set-env-vars` REPLACES the whole env set on Cloud Run; use `--update-env-vars` to merge. This is why omitting a var deletes it.
- AI Concierge enable logic: `AI_SEARCH_URL` set ⇒ web-search path; else `AI_BASE_URL` ⇒ legacy DB+LLM; neither ⇒ disabled.
