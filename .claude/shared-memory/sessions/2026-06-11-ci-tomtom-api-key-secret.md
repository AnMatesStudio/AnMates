# 2026-06-11 — CI: TOMTOM_API_KEY from GitHub secret

## TL;DR
Wired `TOMTOM_API_KEY` into the Cloud Run deploys so the Discovery `/venues/nearby`
TomTom proxy turns on in dev + prod. Pulled from a GitHub **secret** (private API key).

## Why
The key was added to `.env`/`.env.example` and consumed by the backend
(`config.go` → `cfg.TomTomAPIKey` → `services.NewTomTomClient`) in the
2026-06-11 Discovery TomTom session, but the CI/CD deploy workflows never passed
it to Cloud Run — so on the deployed API the proxy stayed disabled and the client
silently fell back to Overpass.

## Change
Added one line to the `gcloud run deploy ... --set-env-vars` block in **both**:
- `.github/workflows/cd.go-api.yml` (production, push to main)
- `.github/workflows/ci.go-api.yml` (`deploy-dev` job, same-repo PRs)

```
--set-env-vars "TOMTOM_API_KEY=${{ secrets.TOMTOM_API_KEY }}" \
```

Placed right after the `AI_SEARCH_URL` line, before the SMTP block. Used
**secret** not **var** because it's a private key (same treatment as
`SMTP_PASSWORD`, `JWT_SECRET`, `DATABASE_URL`).

Key facts that make this safe:
- gcloud `--set-env-vars` **replaces the whole env set** → the var must be listed
  in the same command as the others, which it now is.
- Backend degrades gracefully: empty/unset key → `TomTomClient.Enabled()==false` →
  `/venues/nearby` route not registered → Flutter falls back to Overpass. So the
  workflow is valid even before the secret is created (it just sets it to "").

Also updated `.github/CI-CD.md` secrets table: added `TOMTOM_API_KEY` (optional)
and the previously-undocumented `SMTP_PASSWORD` (optional), both noting the
graceful-degradation behavior when blank.

## Verification (pending)
- YAML is a 1-line addition mirroring existing working lines — no structural risk.
- Live confirm needs: create GH repo secret `TOMTOM_API_KEY`
  (Settings → Secrets and variables → Actions → New repository secret), then a
  deploy → check API logs print `TomTom nearby enabled` and `/venues/nearby`
  returns results.

## Open follow-ups
- User: create the `TOMTOM_API_KEY` repo secret.
- When live-confirmed working on the deployed API → migrate to a resolution.
