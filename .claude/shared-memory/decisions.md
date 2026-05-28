# Decisions Log (Runtime ADRs)

> **Locked Phase 1 decisions:** see [shared-decisions.md](shared-decisions.md) — 15 architecture-wide decisions per handoff v1.0. Those are **read-only**; do not edit them here.
>
> This file is for **new** ADR-style entries that arise during agent work (e.g. an edge case the locked decisions don't cover, an implementation choice with trade-offs worth recording).

## Template

```
## ADR-NNN: <title>
**Date:** YYYY-MM-DD
**Status:** proposed | accepted | superseded
**Related:** shared-decisions.md §Decision X (if extends a locked decision)

### Context
<why we needed to decide>

### Decision
<what was decided>

### Consequences
<what changes / trade-offs>
```

---

## ADR-001: GitHub Actions workflow organization — separate CI/CD, dotted naming convention, reusable workflows on rule-of-three

**Date:** 2026-05-27
**Status:** accepted
**Related:** Jira [TECH-2](https://anmatesstudio.atlassian.net/browse/TECH-2); full architecture doc in [`.github/WORKFLOW-ARCHITECTURE.md`](../../.github/WORKFLOW-ARCHITECTURE.md)
**Decided by:** main-assistant + user (2026-05-27 conversation)

### Context

TECH-2 delivered 4 GitHub Actions workflows (`ci-flutter.yml`, `ci-go.yml`, `cd-flutter.yml`, `cd-go.yml`). User asked: (a) should we merge CI + CD into single files? (b) when we add Flutter iOS/Android later (→ 4-6 more workflows), should we organize them into subfolders like `workflows/flutter/`, `workflows/go/`?

These are forward-looking architectural choices: choosing wrong locks in fragmentation when 8-12 workflow files exist.

### Decision

**Four principles, encoded:**

1. **Never merge CI and CD into the same workflow file.**
   They differ on ≥3 of {concurrency policy, permissions, secret access, trigger event, re-run semantics, branch-protection role, failure blast radius}. Mixing them produces god files that are hard to reason about, hard to permission correctly, and dangerous to re-run.

2. **Use filename convention, never subfolders.**
   GitHub Actions scans only `.github/workflows/*.yml` (one level — subdirs silently ignored). This is a platform constraint, not a preference.
   Convention adopted: `<lifecycle>.<service>-<platform>.yml`
   - Lifecycle prefixes: `ci.`, `cd.`, `_` (reusable), `release.`, `nightly.`
   - Examples: `ci.flutter-web.yml`, `cd.go-api.yml`, `_flutter-build.yml`
   - Dots beat hyphens for sort grouping (`cd.*` cluster, `ci.*` cluster, `_*` cluster).

3. **Reusable workflows only at rule-of-three.**
   1-2 duplications → leave duplicated. 3+ duplications → extract `_*.yml` reusable invoked via `workflow_call`. Mobile (iOS+Android) is when we cross that threshold.

4. **Version build artifacts by SHA, release artifacts by semver.** (added 2026-05-27, user-driven)
   Decided to keep `github.sha` as the Cloud Run container image tag, NOT a pretty `v1.<run_number>.<attempt>`. Deciding question = *who reads this identifier?* Machine-facing plumbing (container images, build bundles, deploy manifests) → SHA, because the only useful question at incident time is "which commit is running?" and `run_number` is not idempotent (re-runs mint new numbers for identical code). Human-facing release artifacts (mobile app on App Store/Play) → semver `v1.47.2`, because users/reviewers read it and stores require monotonic increase. Semver therefore belongs in `cd.flutter-{android,ios}.yml` (release-gated), never in the continuously-deployed backend. Full reasoning: WORKFLOW-ARCHITECTURE.md principle #6.

### Consequences

**Immediate (TECH-2):**
- 4 workflow files renamed: `ci-flutter.yml` → `ci.flutter-web.yml`, etc. Internal `concurrency.group` strings + `paths:` self-references also updated.
- `.github/WORKFLOW-ARCHITECTURE.md` written: principles, end-state target, 4-phase migration roadmap, decision tree for new contributors.
- `.github/CI-CD.md` updated to reference new filenames + link to architecture doc.

**Phase 2 (when 5th workflow lands — likely first mobile CI):**
- Extract `_flutter-build.yml` reusable (setup + analyze + test, currently duplicated in `ci.flutter-web.yml` + `cd.flutter-web.yml`).
- Refactor existing 2 callers to use `workflow_call`.
- New mobile workflows use the reusable from day 1.

**Phase 3 (first mobile deploy — TestFlight/Play Internal):**
- Add `_flutter-build-android.yml`, `_flutter-build-ios.yml` for platform-specific signing/packaging.
- Mobile CD triggers on tag `v*.*.*` (NOT push to main — release-gated unlike web).
- macOS runner cost (~10× ubuntu) is the main cost driver — only run iOS jobs when truly needed.

**Phase 4 (multi-engineer / paid users):**
- GitHub Environments for prod/staging with required reviewers + wait timers.
- Per-service-per-env service accounts (currently 1 god SA for all deploys).
- SLSA provenance + supply-chain attestation.

### Trade-offs accepted

- **More files** (vs. monolithic pipeline.yml): improves separation of concerns at cost of more files to scan. Mitigated by sort-friendly naming.
- **Filename convention is enforced socially**, not by tooling: future contributors must read `WORKFLOW-ARCHITECTURE.md`. Mitigated by linking the doc from `CI-CD.md` and from every workflow file's PR template (TODO).
- **Renaming the initial 4 files is risky** (broken refs in docs, branch-protection rules): we paid that cost once now while only 4 files exist, instead of renaming 12 later.
- **No reusable workflows yet** (despite some duplication between `ci.flutter-web.yml` + `cd.flutter-web.yml`): deliberate — adding indirection prematurely hurts readability more than it helps DRY.

### Reference

- Full architecture doc: [`.github/WORKFLOW-ARCHITECTURE.md`](../../.github/WORKFLOW-ARCHITECTURE.md)
- Operational guide: [`.github/CI-CD.md`](../../.github/CI-CD.md)
- Session log: [`sessions/2026-05-27-tech-2-github-actions-cicd.md`](sessions/2026-05-27-tech-2-github-actions-cicd.md)
