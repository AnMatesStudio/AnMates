# Workflow Architecture — GitHub Actions Strategy

**Author role:** Principal DevOps Engineer + Solutions Architect
**Last updated:** 2026-05-27
**Audience:** Anyone touching `.github/workflows/` in this repo, now or future.

This doc captures the **organizational principles** and **migration roadmap** for our GitHub Actions setup. The current state is intentionally lean — this doc explains the trajectory so future contributors don't fragment the structure.

Related:
- [CI-CD.md](CI-CD.md) — operational guide (setup, secrets, rollback)
- Jira [TECH-2](https://anmatesstudio.atlassian.net/browse/TECH-2) — original ticket
- ADR-001 in [.claude/shared-memory/decisions.md](../.claude/shared-memory/decisions.md) — captured decision

---

## Core principles

### 1. Separate CI from CD (even when they look similar)

CI and CD share surface area (checkout + setup + test) but differ in 6 fundamentals:

| Concern | CI | CD |
|---|---|---|
| Concurrency policy | `cancel-in-progress: true` (new PR pushes obsolete the old run) | `cancel-in-progress: false` (never kill a deploy mid-flight) |
| Permissions | `contents: read` enough | Needs `id-token: write` for WIF + deploy tokens |
| Secret access | Limited (fork PRs see no secrets) | Full repo secrets |
| Trigger source | `pull_request` from potentially untrusted forks | `push` to main / tag — trusted |
| Re-run semantics | Re-run = re-test (idempotent) | Re-run = re-deploy (impactful — new revision in prod) |
| Branch protection | Required status check | Never a required check |
| Failure blast radius | Blocks 1 PR | Can take down production |

**Rule:** if two pieces of pipeline differ on any of {concurrency, permissions, trigger event}, they belong in separate files.

### 2. Filename convention (we can't use folders)

**Constraint:** GitHub Actions scans only `.github/workflows/*.yml` — **one level deep, no subdirectories**. Files in `.github/workflows/flutter/ci.yml` are silently ignored. This is a hard platform limitation, not a preference.

**Workaround:** dotted prefix naming.

```
<lifecycle>.<service>-<platform>.yml
```

| Lifecycle prefix | Meaning |
|---|---|
| `ci.` | Runs on `pull_request`. Never deploys. |
| `cd.` | Runs on `push` to main, tag, or `workflow_dispatch`. Deploys. |
| `_` (underscore) | Reusable workflow called via `workflow_call` — never runs standalone. |
| `release.` | Release management (cut tags, generate notes, create GitHub releases). |
| `nightly.` | Scheduled (`schedule:` cron) — e.g., dependency audits, soak tests. |

| Service-platform suffix | Examples |
|---|---|
| `flutter-web` | Browser deploy target |
| `flutter-android` | Play Store deploy target |
| `flutter-ios` | App Store deploy target |
| `go-api` | Go Fiber backend on Cloud Run |
| `infra` | Terraform / IaC if added later |

**File listing sorts naturally:**

```
.github/workflows/
├─ _flutter-build.yml          ← reusable (underscore prefix = "internal")
├─ _gcp-auth.yml               ← reusable
├─ _go-build.yml               ← reusable
├─ cd.flutter-web.yml          ← deploy web
├─ ci.flutter-web.yml          ← test web
├─ ci.go-api.yml               ← test Go
└─ cd.go-api.yml               ← deploy Go
```

Sorted alphabetically: reusables first, then `cd.` and `ci.` grouped, then services grouped within. Easy mental scan.

### 3. Don't abstract until the third instance

Reusable workflows (`workflow_call`) are **not free** — they add indirection that hides logic. Cost > benefit until you have ≥3 callers.

**Heuristic:**

| State | Action |
|---|---|
| 1-2 workflows duplicating setup | Leave duplicated. Easier to read. |
| 3 workflows duplicating ≥10 lines | Extract reusable. |
| Duplicated logic spans different services (Flutter ↔ Go) | Don't share — they will diverge. |

We currently have 4 workflows with ~5 lines of overlap → **not yet worth abstracting**.

### 4. Trigger semantics differ per platform

Mobile is NOT just "Flutter web on a different runner." Real differences:

| Concern | Web | Android | iOS |
|---|---|---|---|
| Runner | `ubuntu-latest` | `ubuntu-latest` | `macos-latest` (**10× more expensive minutes**) |
| Code signing | None | Keystore .jks + key alias in secrets | P12 cert + provisioning profile + App Store Connect API key |
| Trigger | Every push to main | Tag `v*.*.*` or manual | Tag or manual |
| Deploy target | Firebase Hosting (1 endpoint) | Play Console: Internal → Alpha → Beta → Prod (4 tracks) | TestFlight → External Testing → App Store review (1-3 days) |
| Version policy | Immutable URL (any frequency) | Version code must increase monotonically | Build number unique per version |
| Rollback | `firebase hosting:rollback` (1 cmd) | Halt rollout + promote previous track from Play Console | **No rollback** — must submit new version |
| Local equivalent | `flutter build web` | `flutter build appbundle` + Fastlane | `flutter build ipa` + Fastlane + Xcode signing |

**Implication:** mobile CD does NOT trigger on every `main` push. It triggers on **tag**. CI on main can still happen (verify build is green) but distribution is gated on explicit release intent.

### 5. Promote artifacts, don't rebuild

Anti-pattern: CI builds → tests pass → CD builds again → deploys.

**Risk:** what CD deploys is not what CI tested. Subtle if e.g. Docker base image floats, or `flutter pub get` resolves a different version between runs.

**Pattern:** CI builds + uploads artifact. CD downloads that artifact + deploys.

We do this partially in `ci.flutter-web.yml` (uploads `build/web` artifact). The reusable refactor will formalize this.

### 6. Version build artifacts by SHA, release artifacts by semver

This is the principle that decides **how we tag a container image vs. how we version the mobile app**. They look like the same question ("what number do I put on this?") but they are not.

**The deciding question: who reads this identifier, a human or a machine?**

| | Release artifact | Build artifact |
|---|---|---|
| Examples | Mobile app on App Store / Play, a published SDK, a GitHub Release | Docker/OCI container image, `build/web` bundle, a CI cache key |
| Who consumes it | **Humans** — users, support, marketing, the reviewer at Apple | **Machines** — Cloud Run revision config, `docker-compose.yml`, deploy manifests |
| What they need from it | Reason about compatibility, read a changelog, answer "which version am I on?" | An immutable pointer that traces back to exact source |
| Best identifier | **Semver** `v1.47.2` (or a git tag) | **Git SHA** (ideally pinned by digest `@sha256:…`) |
| How often a human looks at it | Every release, in public | Almost never — it's plumbing |

**Why the backend container uses `github.sha` and NOT `v1.47.2`:**

1. **Traceability beats prettiness for plumbing.** At 3am with prod down, the only question that matters is "what commit is running?" A SHA tag answers instantly (`git show abc1234`). `v1.47` forces you to open the Actions UI and reverse-map run #47 → commit. Nobody browses Artifact Registry to admire tag names.
2. **SHA is idempotent; `run_number` is not.** The same commit always produces the same SHA. `github.run_number` drifts if the workflow is deleted/recreated, and a re-run from the UI mints a *new* number (`v1.47.2`) for *identical* code — a lie about what changed.
3. **A continuously-deployed backend has no semver.** Semver encodes a compatibility contract for consumers. A service deployed on every push to `main` has exactly one meaningful version: "whatever `main` points to right now." Forcing semver onto it is ceremony with no reader.
4. **The truly immutable form is the digest.** Tags (even SHA tags) can technically be moved; `@sha256:…` cannot. SHA tag is the pragmatic balance between human-skim-ability and immutability; pin by digest when you need hard guarantees (e.g. GitOps).

**Where semver `v1.47.2` *does* belong — and we will use it there:**

The mobile app **is** a release artifact. App Store and Play Console **require** a user-visible version that increases monotonically, and a real human (the user, the reviewer) reads it. So semver lands precisely in `cd.flutter-android.yml` / `cd.flutter-ios.yml`, which are **release-gated by a git tag** (principle 4) — not in the continuously-deployed backend.

**The clean project-wide model:**

```
Backend (Cloud Run)      → SHA tag,      continuous deploy on push to main
Flutter web (Hosting)    → SHA / none,   continuous deploy on push to main
Flutter mobile (Store)   → semver v1.47.2, release-gated by git tag v*.*.*
```

This is the same continuous-vs-release-gated split from principle 4, viewed through the versioning lens. If you ever feel the urge to make the backend image tag "prettier," re-read this section: it's intentional.

---

## End-state architecture (target ~Q4 2026)

This is what the workflow directory looks like after Android/iOS land:

```
.github/workflows/
│
├─ ci.flutter-web.yml         # PR + path anmates_flutter/lib/, web/, ...
├─ ci.flutter-mobile.yml      # PR + path mobile-touching → matrix [android, ios] subset
├─ ci.go-api.yml              # PR + path anmates-api/
│
├─ cd.flutter-web.yml         # push main + path flutter web → Firebase Hosting
├─ cd.flutter-android.yml     # tag v*.*.* OR workflow_dispatch → Play Internal Track
├─ cd.flutter-ios.yml         # tag v*.*.* OR workflow_dispatch → TestFlight
├─ cd.go-api.yml              # push main + path anmates-api/ → Cloud Run
│
├─ _flutter-build.yml         # reusable: checkout + setup + pub get + analyze + test
├─ _flutter-build-android.yml # reusable: + keystore setup + bundleRelease
├─ _flutter-build-ios.yml     # reusable: + cert import + xcodebuild archive
├─ _go-build.yml              # reusable: checkout + setup + vet + test
├─ _gcp-auth.yml              # reusable: WIF + setup-gcloud
│
├─ release.cut-version.yml    # workflow_dispatch → bump pubspec version, tag, GitHub release
└─ nightly.dep-audit.yml      # cron → flutter pub outdated + go list -u
```

**Approximate file count when complete:** 12-15 workflow files, all in one folder, all using consistent naming.

---

## Migration roadmap

### Phase 1 (NOW — Q2 2026): foundation

**Files:** 4 workflows + 1 setup script + 2 docs.

```
.github/workflows/
├─ ci.flutter-web.yml
├─ ci.go-api.yml
├─ cd.flutter-web.yml
└─ cd.go-api.yml
```

✅ Done in TECH-2.

**What we deliberately did NOT do:**
- No reusable workflows yet (rule of three).
- No mobile workflows yet (no Apple/Play accounts ready).
- No environments / approval gates (overkill for solo dev).

### Phase 2 (when adding 5th workflow): extract reusables

**Trigger event:** the moment you create `ci.flutter-android.yml` or any 5th workflow file.

**Steps:**

1. **Audit duplication** across existing 4 + planned new files. Identify blocks that appear in ≥3 files.
2. **Extract** to `_flutter-build.yml` (Flutter setup + analyze + test) and `_go-build.yml` if Go also grows.
3. **Refactor** existing `ci.flutter-web.yml` to use `workflow_call`:
   ```yaml
   jobs:
     build:
       uses: ./.github/workflows/_flutter-build.yml
       with:
         working-directory: anmates_flutter
   ```
4. **Don't refactor more than 3 files at once** — easier to bisect if something breaks.

### Phase 3 (when first mobile deploy): platform-specific reusables

**Trigger event:** ready to ship to TestFlight or Play Internal Track.

**New reusables:**
- `_flutter-build-android.yml` — keystore decode, `flutter build appbundle`, sign verification
- `_flutter-build-ios.yml` — cert import via `apple-actions/import-codesign-certs`, `xcodebuild archive`, ExportOptions.plist

**New orchestrators:**
- `cd.flutter-android.yml` — triggers on tag `v*.*.*`, uses Fastlane `supply` to upload to Play
- `cd.flutter-ios.yml` — triggers on tag, uses Fastlane `pilot` to upload to TestFlight

**New secrets needed:**
- Android: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`
- iOS: `APPLE_CERTIFICATE_P12_BASE64`, `APPLE_CERTIFICATE_PASSWORD`, `APPLE_PROVISIONING_PROFILE_BASE64`, `APPSTORE_CONNECT_API_KEY_ID`, `APPSTORE_CONNECT_API_KEY_ISSUER_ID`, `APPSTORE_CONNECT_API_KEY_CONTENT`

### Phase 4 (production maturity): governance

**Trigger event:** team grows past 1 person, or you have paying users.

- **GitHub Environments**: `production-web`, `production-api`, `production-android`, `production-ios`, plus `staging-*` mirrors
  - Each env: required reviewers (≥1 approval to deploy), wait timer (cooling-off), restrict to specific branches
  - Env-scoped secrets (DB URL prod vs staging different)
- **OIDC fine-grained**: separate GCP service account per service per env (not 1 god SA)
- **SLSA Level 2-3 provenance**: attest build artifacts (supply-chain integrity)
- **Notification routing**: Slack `#deploys-web` vs `#deploys-mobile` vs `#deploys-api`

---

## Decision tree: where does my new workflow go?

```
I want to add a workflow that...

├─ ...runs on PR to validate code
│   └─ → ci.<service>-<platform>.yml
│
├─ ...deploys something to production
│   ├─ on push to main (continuous deploy)
│   │   └─ → cd.<service>-<platform>.yml
│   └─ on tag or manual (release-gated)
│       └─ → cd.<service>-<platform>.yml + filter tag/dispatch
│
├─ ...is called by other workflows (no standalone trigger)
│   └─ → _<purpose>.yml
│
├─ ...manages versions / releases
│   └─ → release.<purpose>.yml
│
└─ ...runs on a schedule
    └─ → nightly.<purpose>.yml  (even if not literally nightly)
```

---

## Why we picked this convention over alternatives

| Alternative | Pros | Cons | Verdict |
|---|---|---|---|
| 1 monolithic `pipeline.yml` | Single source of truth | Mixed concurrency, perms, triggers — violates principle 1; God file | ❌ |
| `<service>.yml` per service (combines CI+CD) | Fewer files | Violates principle 1; Re-run = redeploy = surprise | ❌ |
| Subfolders (`workflows/flutter/ci.yml`) | Clean hierarchy | Platform doesn't support — silent ignore | ❌ technically impossible |
| Flat with `<lifecycle>-<service>.yml` (hyphens) | Simple | Sorts as `cd-flutter, cd-go, ci-flutter, ci-go` — hard to scan when many | ⚠️ what we had |
| Flat with `<lifecycle>.<service>-<platform>.yml` (dots) | Sorts well; matches Linux convention (`/etc/cron.d`, `/etc/network/if-up.d/`) | Slightly more typing | ✅ **chosen** |

---

## When to revisit this doc

- When workflow file count crosses **5** → time to extract reusables (start Phase 2)
- When first mobile platform ships → time to add platform-specific reusables (Phase 3)
- When second engineer joins or you launch publicly → time for environments + reviewers (Phase 4)
- When GitHub Actions adds nested workflow folders (don't hold your breath) → consider migrating

If you're touching workflows and this doc feels out of date, **update it in the same PR**.
