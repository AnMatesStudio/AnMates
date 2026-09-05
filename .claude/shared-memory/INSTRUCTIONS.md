# Shared Memory — Instructions & Directory Structure

This is the **single source of truth** for AnMates project memory. Every Claude session (main assistant + sub-agents) reads from here on start and writes back on finish.

If you only read one file, read **this one** — it explains the entire layout and how to use it.

---

## Access from Anywhere

**Canonical physical location:** `c:\AnM\AnMatesStudio\AnMates\.claude\shared-memory\`

**Access path that works regardless of cwd:** `.claude/shared-memory/`

```
c:\AnM\AnMatesStudio\AnMates\                          ← Project root (cwd)
├── .claude/
│   ├── agents/                          ← Real agent definitions (team-leader, coder, qa)
│   │   ├── team-leader.md
│   │   ├── coder.md
│   │   └── qa.md
│   └── shared-memory/                   ← THIS DIRECTORY — all memory (static + runtime)
│       ├── INDEX.md, INSTRUCTIONS.md, KNOWLEDGE-INDEX.md, USAGE.md, ORCHESTRATION-README.md
│       ├── product-summary.md, architecture-overview.md, design-system.md, ... (static)
│       ├── current-task.md, plan.md, decisions.md, ... (runtime)
│       ├── resolutions/, sessions/, qa-reports/, screenshots/
│       └── (no nested .claude — single source of truth)
└── plan/                                ← Handoff doc lives here
    └── lastest/handoff/anmate-design-handoff.md
```

| Entry point | Path |
|-------------|------|
| CLI from project root (`c:\AnM\AnMatesStudio\AnMates`) | `.claude/shared-memory/` |
| VS Code extension (project root) | `.claude/shared-memory/` |
| `@.claude/agents/team-leader.md` invocation | Works from project root |

---

## Directory Structure

```
.claude/shared-memory/
├── INSTRUCTIONS.md             ← THIS FILE — read first
├── INDEX.md                    ← Operational file map + read-order per role
├── KNOWLEDGE-INDEX.md          ← Navigation map for static-knowledge files
├── USAGE.md                    ← How to dispatch the agent team (team-leader/coder/qa)
├── ORCHESTRATION-README.md     ← Multi-agent system architecture + governance
│
│   # ───── Static knowledge (Phase 1, read-only for agents) ─────
├── product-summary.md          ← "Ultimate-for-all" strategy, KPIs, scope in/out
├── architecture-overview.md    ← System design, data model, module layout, jobs
├── api-contracts-summary.md    ← CANONICAL Phase 1 REST + WS endpoint catalog
├── domain-glossary.md          ← Mate, Best Mate, Kèo, Lá thư, Vibe, Trust terminology
├── design-system.md            ← FINAL color tokens, typography, conformance criteria
├── design-reference-index.md   ← Screen → reference HTML file map
├── shared-decisions.md         ← 15 LOCKED Phase 1 architecture decisions
├── task-board.md               ← W1–W8 task scaffold (~160 tasks)
│
│   # ───── Runtime (mutable) ─────
├── current-task.md             ← Active task: goal, status, owner, started_at
├── plan.md                     ← Step-by-step plan for current task
├── decisions.md                ← Runtime ADRs (new decisions during agent work)
├── blockers.md                 ← Open blockers needing user/team-leader attention
├── changelog.md                ← Append-only event log; every agent writes one row on finish
├── api-contracts.md            ← LIVE MIRROR of implemented endpoints (subset of canonical)
│
├── resolutions/                ← CONFIRMED solutions (user-verified) — Claude's primary lookup
│   ├── INDEX.md                ← Tag/error-keyword query index — read THIS to find a solution
│   ├── TEMPLATE.md             ← Frontmatter template for new resolutions
│   └── R-NNN-<slug>.md         ← One file per confirmed resolution
│
├── sessions/                   ← Chronological session logs (may include diagnostic-only work)
│   └── YYYY-MM-DD-<slug>.md
│
├── qa-reports/                 ← Per-run QA reports (test + screenshots + regressions)
│   └── YYYY-MM-DD-<feature>.md
│
└── screenshots/
    ├── baseline/               ← Approved visual-regression baselines (qa)
    └── latest/                 ← Most recent screenshots from current run (qa)
```

### Static knowledge vs Runtime — what goes where?

| Category | Purpose | Mutability | Source of truth |
|----------|---------|-----------|-----------------|
| **Static knowledge** (`KNOWLEDGE-INDEX` + product/architecture/design/decisions/glossary/task-board) | Phase 1 spec — what we're building and how | Read-only for agents; only main assistant updates when handoff doc evolves | `plan/lastest/handoff/anmate-design-handoff.md` |
| **Runtime** (`current-task`, `plan`, `decisions`, `blockers`, `changelog`, `api-contracts`) | What's happening right now in active agent work | Written every session | The agents themselves |
| **Resolutions** | Verified fixes for recurring problems | Append-only; only after user confirms | User confirmation |
| **Sessions / QA reports / Screenshots** | Historical record of what happened | Append-only journal | Each session/run |

---

## How Claude uses this directory

### ON START of every session (BEFORE responding to user)

```
1. Read INSTRUCTIONS.md (this file)
2. Read current-task.md   — what's active
3. Read blockers.md        — known open issues
4. Read tail ~20 lines of changelog.md — recent activity
5. Skim resolutions/INDEX.md tags + error-keywords
   → if user's question matches a tag/error → read the full R-NNN file
6. Announce: "📥 Loaded shared-memory: <files-read>, resolutions matched: <R-NNN or none>"
```

**Why this order:** resolutions are the highest-signal context — solved problems with verified fixes. Always check them before re-investigating.

### ON FINISH of a session that resolves an issue

Two write paths depending on confidence:

| Confidence | Write to |
|------------|----------|
| User explicitly confirmed "it works" / "done" / "ok ngon" | **`resolutions/R-NNN-<slug>.md`** + session log + index |
| Work done but not yet user-verified | `sessions/YYYY-MM-DD-<slug>.md` only (move to `resolutions/` later when confirmed) |

**Resolution write protocol:**
1. Pick next free `R-NNN` (zero-padded 3 digits) from `resolutions/INDEX.md`.
2. Copy `resolutions/TEMPLATE.md` → `resolutions/R-NNN-<short-kebab-slug>.md`.
3. Fill in frontmatter (tags, platforms, severity, date, confirmed_by) and all template sections.
4. Append new row to `resolutions/INDEX.md` **Resolutions Table**.
5. Add Error-keyword mapping if user's error string is grep-able.
6. Re-use existing tags from `resolutions/INDEX.md` Tag glossary; only add new tags if essential.
7. Append row to `changelog.md` mentioning the new resolution ID.
8. If a blocker was resolved → update `blockers.md` (Status → resolved, link R-NNN).
9. If `current-task.md` was the issue → update Status to `done`, link R-NNN.

### ON FINISH of any other session producing deliverables

Just write a `sessions/YYYY-MM-DD-<slug>.md` log + append `changelog.md` row. No resolution entry until confirmed.

---

## File ownership

| File / Dir | Primary writers | Readers |
|------------|----------------|---------|
| `INSTRUCTIONS.md` (this) | main assistant (when conventions evolve) | all |
| `INDEX.md`, `KNOWLEDGE-INDEX.md` | main assistant; rarely changed | all (on start) |
| `USAGE.md`, `ORCHESTRATION-README.md` | main assistant | all |
| **Static-knowledge files** (`product-summary`, `architecture-overview`, `api-contracts-summary`, `domain-glossary`, `design-system`, `design-reference-index`, `shared-decisions`, `task-board`) | main assistant (re-derived from `plan/lastest/handoff/`) | all agents (read-only) |
| `current-task.md` | team-leader, main assistant | all |
| `plan.md` | team-leader | coder, qa |
| `decisions.md` | team-leader, main assistant | all |
| `blockers.md` | coder, qa raise; team-leader resolves | all |
| `changelog.md` | **all agents** (append-only on finish) | all |
| `api-contracts.md` | coder (when endpoints ship) | qa |
| `resolutions/` | main assistant (only after user confirmation) | all (lookup on start) |
| `sessions/` | main assistant (chronological log) | human review; rarely read by agents |
| `qa-reports/` | qa | team-leader, human review |
| `screenshots/` | qa | qa (compares latest vs baseline) |

---

## Resolutions vs Sessions — what goes where?

| Aspect | `resolutions/` | `sessions/` |
|--------|---------------|-------------|
| Trigger | User explicitly confirmed fix works | Any session producing deliverables |
| Lifecycle | Permanent reference | Time-stamped journal |
| Naming | `R-NNN-<slug>.md` (sequential ID) | `YYYY-MM-DD-<slug>.md` (date) |
| Structure | Strict template (frontmatter + standard sections) | Free-form session log |
| Indexed | Yes — by tag, error keyword, platform | No — browse by date |
| Read on start | **Yes — primary lookup** | Only if topic matches by filename |
| Purpose | "If this problem recurs, here is the verified fix" | "What happened on this day" |

**Rule of thumb:** if Claude future-self might be asked the same question again, the answer belongs in `resolutions/`. Diagnostic notes, planning, exploration → `sessions/`.

---

## Query patterns Claude should use

When user describes a problem, scan in this order:

1. **Exact error string** — search `resolutions/INDEX.md` "Error keywords" section
2. **Tag match** — match keywords in user's question against Tag column
3. **Platform filter** — narrow to relevant platform if mentioned (web / android / ios / backend)
4. **Severity sort** — blockers first; address them before nice-to-haves
5. **Read full R-NNN file** — DON'T propose a new fix without reading the existing one first
6. **Adapt if needed** — if symptoms match 90% but not exactly, reference the existing resolution and explain the variant

If no resolution matches, fall back to:
- `decisions.md` (architectural constraints in effect)
- `sessions/` (browse recent dates for similar topics)
- General investigation (then write a new resolution after user confirms)

---

## Quick reference card

```
NEED CONTEXT?         → resolutions/INDEX.md (tags + error keywords)
WHAT'S ACTIVE?        → current-task.md
WHAT'S STUCK?         → blockers.md
WHAT JUST HAPPENED?   → changelog.md (tail)
WHAT'S DECIDED?       → decisions.md (runtime) + shared-decisions.md (15 locked Phase 1)
WHAT ARE WE BUILDING? → KNOWLEDGE-INDEX.md → product-summary.md
WHAT'S THE API?       → api-contracts-summary.md (canonical) + api-contracts.md (live mirror)
WHAT'S THE DESIGN?    → design-system.md + design-reference-index.md
WHAT TASKS REMAIN?    → task-board.md
HOW DO I DISPATCH?    → USAGE.md (agent team docs)

DONE A FIX?
  USER CONFIRMED?     → write resolutions/R-NNN + update INDEX + changelog
  NOT YET CONFIRMED?  → write sessions/YYYY-MM-DD + update changelog
  RESOLVED BLOCKER?   → update blockers.md status → resolved
```
