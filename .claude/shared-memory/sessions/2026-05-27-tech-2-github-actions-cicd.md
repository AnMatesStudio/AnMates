# 2026-05-27 — TECH-2: Setup GitHub Actions CI/CD pipeline

**Jira:** [TECH-2](https://anmatesstudio.atlassian.net/browse/TECH-2) — Status: In Progress (work delivered, awaiting WIF bootstrap + first PR run for user confirmation).

## TL;DR

Implemented full CI/CD pipeline as 4 GitHub Actions workflows + 1 WIF bootstrap script + 1 docs file. Auth via Workload Identity Federation (no static service account JSON keys). Path-filtered triggers per service. Cloud Run smoke check with auto-rollback. Firebase Hosting preview channels for every PR.

## Files created

| Path | Purpose |
|---|---|
| [`.github/workflows/ci.flutter-web.yml`](../../.github/workflows/ci.flutter-web.yml) | PR → analyze + test + build web + deploy preview channel (`pr-N`, 7d expiry) + comment URL on PR |
| [`.github/workflows/ci.go-api.yml`](../../.github/workflows/ci.go-api.yml) | PR → gofmt + vet + test (excluding `smoke/`) + docker build verify |
| [`.github/workflows/cd.flutter-web.yml`](../../.github/workflows/cd.flutter-web.yml) | push `main` → build web → `firebase deploy` → curl smoke |
| [`.github/workflows/cd.go-api.yml`](../../.github/workflows/cd.go-api.yml) | push `main` → Cloud Build → Cloud Run deploy → `/health` smoke → auto-rollback on fail |
| [`scripts/setup-wif.sh`](../../scripts/setup-wif.sh) | Idempotent bash script: enable APIs, create WIF pool/provider, service account, grant roles |
| [`.github/CI-CD.md`](../../.github/CI-CD.md) | Full pipeline docs: setup steps, rollback procedures, troubleshooting |
| [`.github/WORKFLOW-ARCHITECTURE.md`](../../.github/WORKFLOW-ARCHITECTURE.md) | Architecture principles, naming convention rationale, 4-phase migration roadmap for scaling to mobile |
| [`decisions.md`](../decisions.md) ADR-001 | Captures the CI/CD organization decision (separate CI/CD + dotted naming + rule-of-three reusables) |

## Naming convention (locked-in by ADR-001)

```
<lifecycle>.<service>-<platform>.yml
```

- `ci.*` — runs on PR, never deploys
- `cd.*` — runs on push/tag, deploys
- `_*` — reusable, called via `workflow_call`
- `release.*` — release management
- `nightly.*` — scheduled

GitHub Actions does NOT support workflow subfolders (`.github/workflows/flutter/*.yml` is silently ignored). Dotted naming gives folder-like grouping when sorted alphabetically.

## Design decisions (user confirmed via AskUserQuestion)

1. **WIF setup**: script + doc combo. Script is bash, idempotent (`describe || create` pattern).
2. **CI triggers**: path-based — Flutter changes only trigger Flutter CI, Go changes only trigger Go CI.
3. **Preview deploys**: yes — every PR gets a unique Firebase Hosting channel `pr-N` with 7d expiry, URL commented on PR.
4. **Secrets**: GitHub repo Secrets (not Secret Manager) for phase 1 simplicity.

## Auth model

- GCP service account: `github-actions@anmates-studio.iam.gserviceaccount.com`
- Roles granted: `run.admin`, `artifactregistry.writer`, `cloudbuild.builds.editor`, `storage.admin`, `iam.serviceAccountUser`, `firebasehosting.admin`, `firebase.viewer`, `serviceusage.serviceUsageConsumer`
- WIF attribute condition: `assertion.repository=='AnMatesStudio/AnMates'` — restricts impersonation to this exact repo

## Pipeline behavior

```
PR opened/updated
├─ anmates_flutter/** changed → ci.flutter-web.yml → preview URL comment
└─ anmates-api/**    changed → ci.go-api.yml → status check

push to main
├─ anmates_flutter/** changed → cd.flutter-web.yml → live https://anmates-studio.web.app
└─ anmates-api/**    changed → cd.go-api.yml → Cloud Run revision sha-XXXXXXX
                                            ├─ /health smoke check (6× 10s)
                                            └─ auto-rollback traffic if smoke fails
```

## Notable choices

- **Build image on the runner (`docker build`+`docker push`), NOT `gcloud builds submit`** — First CD run failed at "Build + push image": `gcloud builds submit` streams logs to terminal, which requires the caller to be project Viewer/Owner. Our least-privilege SA only has `cloudbuild.builds.editor`, so submit succeeded but the log-stream poll exited 1 (false failure). Switched to building on the GitHub runner + `docker push` to AR via the `gcloud auth configure-docker` credential helper. Bonus: removed now-unneeded roles (`cloudbuild.builds.editor`, `storage.admin`) + `cloudbuild.googleapis.com` API from `setup-wif.sh`. Faster (no GCS tarball upload/queue) + cheaper (0 Cloud Build minutes). Error string: `This tool can only stream logs if you are Viewer/Owner of the project`.
- **Excluded `smoke/` package from CI go test** — that suite makes HTTP calls to a live server, would always fail in CI.
- **`dart format` step is `continue-on-error: true`** for now — existing codebase has 20 unformatted files. Flip to hard fail after a one-shot `dart format .` cleanup commit.
- **Revision suffix `sha-XXXXXXX`** on Cloud Run deploy — traces revision back to git commit.
- **Concurrency control**: PRs cancel in-progress runs for the same branch; CD on main does NOT cancel (don't kill mid-deploy).
- **Artifact upload between jobs**: CI Flutter uploads `build/web` as an artifact then the preview-deploy job downloads it. Avoids rebuilding for fork PRs (where secrets aren't available, preview job skips via `if:` guard).

## User action required (before pipeline activates)

1. Run `bash ./scripts/setup-wif.sh` once (need GCP Owner role on project `anmates-studio`).
2. Paste output values into GitHub repo Secrets:
   - `GCP_WIF_PROVIDER`
   - `GCP_SA_EMAIL`
3. Add 3 app secrets:
   - `DATABASE_URL` (Supabase)
   - `JWT_SECRET` (≥32 chars)
   - `FIREBASE_WEB_API_KEY`
4. Enable branch protection on `main` requiring CI status checks.
5. Open a test PR to validate.

## Verification (pending)

- [ ] User runs `setup-wif.sh` successfully
- [ ] GitHub secrets added
- [ ] First PR triggers CI workflows and they pass
- [ ] Preview channel URL appears as comment
- [ ] Merge to main triggers CD and live URLs respond 200

## Follow-ups

- One-shot `dart format .` + commit, then flip `continue-on-error: false` in ci.flutter-web.yml
- Add Slack/Discord webhook notifications
- Consider migrating secrets → Google Secret Manager once team grows
- Add visual regression (Percy or playwright screenshots) after preview deploy
- E2E test job hitting preview URL

## Key facts (for future-Claude)

- GCP project: `anmates-studio` (project number `492509819332`)
- Region: `asia-southeast1`
- Cloud Run service: `anmates-api`
- Artifact Registry: `asia-southeast1-docker.pkg.dev/anmates-studio/anmates-api/api`
- Cloud Run URL: `https://anmates-api-492509819332.asia-southeast1.run.app`
- Firebase Hosting URL: `https://anmates-studio.web.app`
- Flutter firebase.json + .firebaserc live in `anmates_flutter/` (NOT repo root — root `.firebaserc` points to wrong project `anmatesapp`)
- Root `firebase.json` is for Auth provider config only, not Hosting
