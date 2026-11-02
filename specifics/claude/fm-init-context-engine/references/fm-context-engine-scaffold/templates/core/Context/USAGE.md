# Using the Context Management System

A practical, scenario-focused guide for humans. This file is for **you**, not the AI agent — the agent reads `CLAUDE.md` and `Context/` content directly.

## What this is in 30 seconds

`Context/` is a single self-contained directory that holds every durable piece of knowledge about this project — architecture docs, coding conventions, decision records (ADRs), in-flight and archived specs, insights, roadmap, and machine-regenerated indexes.

The root `CLAUDE.md` is a lean pointer file that imports from `Context/` on demand via `@Context/...` links.

An automation layer in `.claude/` closes the loop:

- **`SessionStart` hook** — injects a briefing (branch, roadmap head, active specs) every time you open Claude Code in this repo.
- **`PostToolUse` hook** — watches the globs configured in `.claude/context-engine.psd1` and either runs a fast action (e.g. a manifest refresh) or marks the edit dirty so the next session nudges you to run the slow action (e.g. a full rebuild).
- **Six slash commands** — `/refresh-context`, `/new-adr`, `/new-spec`, `/archive-spec`, `/state-of-project`, `/validate-context`.
- **`context-keeper` agent skill** — watches conversations for cues (spec completion, architectural decisions, gotchas, new public surface) and proposes or performs the right bookkeeping without you asking.

This system was scaffolded by the [context-engine]({{ENGINE_REPO_URL}}) template; the design rationale lives in that repo's `docs/DESIGN.md` and in this repo's [ADR-0001](adr/0001-adopt-context-engine.md).

## Quick start

### Fresh clone on a new machine

```bash
git clone {{REPO_URL}}
cd {{REPO_DIR}}
git config core.hooksPath .githooks    # activates the commit-msg policy hook
```

Open Claude Code in the directory. Hooks, rules, slash commands, and the `context-keeper` skill all load automatically at session start.

### Every new Claude Code session

Nothing to do. The `SessionStart` hook runs and surfaces:

- Current branch + last 10 commits
- Active specs under `Context/specs/active/`
- First ~60 lines of `Context/roadmap/current.md`
- A "stale build output" warning if a prior session edited watched source without running the follow-up action

If you want a fuller picture at any time, type `/state-of-project` — the agent reads the roadmap, active-spec cursors, and recent git activity and hands back a concise status brief.

## Slash commands

| Command                | What it does                                                                |
| ---------------------- | --------------------------------------------------------------------------- |
| `/refresh-context`     | Regenerates `Context/generated/*` artifacts via the configured regenerators |
| `/new-adr "<title>"`   | Creates the next-numbered ADR in `Context/adr/` using the Nygard template   |
| `/new-spec <slug>`     | Scaffolds `Context/specs/active/<slug>/PLAN.md` from the standard template  |
| `/archive-spec <slug>` | Moves an active spec to `archive/YYYY-MM-DD-<slug>/` with a shipped summary |
| `/state-of-project`    | Produces a current status brief from roadmap + active specs + git           |
| `/validate-context`    | Sweeps `Context/**/*.md` for stale `last_verified:` stamps and spot-checks  |

All six live at `.claude/commands/<name>.md`. To see exactly what any command does, open the file — they're human-readable markdown and run as prompts the agent follows.

## Directory cheat sheet

```text
Context/
├── README.md                  site map
├── USAGE.md                   this file — user-facing guide
├── architecture/              stable design docs (read first for any deep dive)
├── conventions/               coding rules (read before writing code)
├── specs/
│   ├── active/                in-flight work; each with PLAN.md
│   └── archive/               frozen, date-prefixed — audit trail
├── adr/                       numbered architectural decisions (Nygard format)
├── insights/
│   ├── <topic>.md             promoted, durable learnings
│   └── _inbox/                fresh drops awaiting weekly triage
├── roadmap/
│   ├── current.md             "you are here"
│   └── archive/               past roadmap snapshots
├── generated/                 machine-regenerated — DO NOT hand-edit
└── scripts/                   the regenerators (stack-specific)

.claude/
├── settings.json              permissions + hook registration
├── context-engine.psd1        watch globs, regenerators, public-surface definition
├── hooks/
│   ├── session-start.ps1      injects briefing at every session start
│   └── post-edit-watch.ps1    config-driven watch → action / dirty-marker
├── commands/                  the six slash commands
├── rules/                     path-scoped auto-loading rules
└── skills/context-keeper/     agent skill coordinating on conversational cues

.githooks/
└── commit-msg                 rejects AI-attribution trailers on commits
```

## Common scenarios

### I added new public surface (function / public type / exported API / IPC channel)

**What happens automatically:**

- If the file matches a watch glob in `.claude/context-engine.psd1`, the `PostToolUse` hook runs its configured action (fast refresh) or marks the edit dirty (slow rebuild deferred to you).

**What you (optionally) do:**

- Run `/refresh-context` to regenerate the indexes under `Context/generated/`, if this project has regenerators configured.
- If the addition introduces a pattern worth enforcing in similar future code, add a bullet to the relevant `.claude/rules/<topic>.md`.

**What the agent skill does:**

- If the conversation mentions the addition, `context-keeper` may offer to run `/refresh-context` and propose rule additions. You can accept or decline.

### I want to add a task to the roadmap

Just edit `Context/roadmap/current.md`. The structure is:

- **Strategic direction** — multi-month directional commitments
- **Active work** — in-flight items with spec pointers
- **Next up (unblocked)** — one-liner tasks ready to pick up
- **Parked / deferred**
- **Known but low-priority**

Dropping a one-liner into "Next up" is usually what you want. No slash command needed.

### Spec or ADR?

Two of the most useful slash commands — `/new-spec` and `/new-adr` — sound similar but capture very different things.

| If you want to capture...                                              | Use                        |
| ---------------------------------------------------------------------- | -------------------------- |
| A multi-phase implementation plan (what we're building, how)           | `/new-spec`                |
| A single architectural choice (technology, pattern, deprecation, rule) | `/new-adr`                 |
| The reasoning behind a non-obvious convention                          | `/new-adr`                 |
| A handoff document that another developer can resume from cold         | `/new-spec`                |
| A decision being reversed — supersedes an earlier ADR                  | `/new-adr`                 |
| A bug-fix or one-off task                                              | Neither — just do the work |

The two often interact:

- **Specs can produce ADRs.** A spec phase that forces an architectural commitment deserves its own ADR alongside the spec.
- **ADRs can spawn specs.** A decision that requires multi-phase rollout work gets a spec to plan the migration.

### I want to start a new spec for a bigger feature

A **spec** is a plan-of-record for a feature you are about to build or are currently building. It captures *what we're going to do and how* — goal, non-goals, scope, phases, open questions, references.

```text
/new-spec my-feature-slug
```

The agent scaffolds `Context/specs/active/my-feature-slug/PLAN.md` with the standard template. Fill in the sections as the work progresses. Once started, the `SessionStart` hook lists it under "Active specs" on every new session.

### I finished / shipped a spec

```text
/archive-spec my-feature-slug
```

The agent will:

1. `git mv Context/specs/active/my-feature-slug Context/specs/archive/YYYY-MM-DD-my-feature-slug`
2. Prepend a "Shipped summary" block to the primary spec file (what shipped, what was deferred, commit range from `git log`).
3. Remove the entry from `Context/roadmap/current.md`'s "Active work" and add a "Recently shipped" note.
4. Update `Context/specs/README.md`'s index tables.

**Archived specs are frozen.** Do not edit them afterward — follow-on work goes into a new active spec.

### I made an architectural decision I want to remember

An **ADR** (Architecture Decision Record) captures *why we made a particular choice* — alternatives considered, tradeoffs, the resulting rule. ADRs are append-only, never renumbered, never substantively edited — supersession creates a new ADR.

```text
/new-adr "Use X instead of Y for Z"
```

The agent finds the next-numbered ADR slot, slugifies the title, and creates `Context/adr/NNNN-<slug>.md` in Nygard format. If the conversation contains enough material, it pre-fills the sections instead of leaving placeholders.

**If the new ADR supersedes an older one**, also update the older ADR's `## Status` line to read `Superseded by ADR-NNNN` (don't delete or edit the older ADR otherwise — it's frozen history).

### I discovered a gotcha / workaround while debugging

Drop it in `Context/insights/_inbox/` as `YYYY-MM-DD-<slug>.md`. Recommended structure:

```markdown
# <one-line description>

**Date:** YYYY-MM-DD
**Context:** <what task surfaced this?>

## Problem

<observable symptom>

## Root cause

<what's actually going on>

## Fix / Workaround

<the code or pattern that works>

## Rule

<one-sentence prevention heuristic>
```

**Weekly-ish, triage `_inbox/`:**

- Durable, widely-applicable → promote into a topic file at `Context/insights/<topic>.md`.
- Area-specific → promote into the relevant reference doc (`Context/api/`, `Context/architecture/`, ...).
- One-off noise → delete.

Never leave items in `_inbox/` indefinitely — they lose value if not reviewed.

### I want to supply context to Claude.ai (web), a fresh Agent SDK app, or a different AI tool

Those environments **don't** auto-load `CLAUDE.md` or the `Context/` tree. Options:

- **Paste the pointers.** Copy `Context/roadmap/current.md` + the Do/Do-not sections of `CLAUDE.md` into the chat.
- **Paste relevant ADRs.** For architectural questions, the `Context/adr/` files give full decision history.
- **Upload the doc.** Most AI tools accept markdown file uploads.

Copy-paste-ready prompt template:

> Before answering, read the attached files in order:
> (1) CLAUDE.md — project overview, rules, dependencies
> (2) Context/roadmap/current.md — what's active now
> (3) Context/conventions/agent-rules.md — MUST / MUST NOT list
> Then answer: \<your question\>

### The generated artifacts look out of date

```text
/refresh-context
```

Runs every regenerator listed under `Regenerators` in `.claude/context-engine.psd1` and reports diffs. Direct invocation without the slash command:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File Context/scripts/<regenerator>.ps1
```

### I want to audit docs for staleness

```text
/validate-context
```

Sweeps every `Context/**/*.md` for `last_verified:` frontmatter stamps older than 90 days, spot-checks a claim or two from each flagged doc against the current codebase, and reports a table of findings. It **does not auto-update anything** — you decide what to fix and when.

### The context engine has newer conventions

Seeded files (convention docs, rules, `CLAUDE.md`, this file) belong to this project, so a plain engine update never changes them. To pull the engine's corrections into them, run `/fm-init-context-engine refresh`, or run the engine's `Update-ContextEngine.ps1 -RefreshSeeds` on a clean working tree:

- A file you never edited updates in place. A file you edited gets a three-way merge that keeps your changes: a clean merge is written for you to review, and a conflict is left alone, with candidates and a report in `.claude/context-engine/incoming/`.
- `CLAUDE.md`, `Context/conventions/agent-rules.md`, and decision data are never rewritten; the engine's changes are offered as a diff.
- ADRs, the roadmap, specs, insights, and architecture docs are never touched.
- The report lists the engine's changelog entries since your last refresh, and where your code matches them.

Resolve what the report lists, then run `Update-ContextEngine.ps1 -CompleteRefresh`. To keep a seeded file entirely your own, add its path to `SeedRefreshExclude` in `.claude/context-engine.psd1`. Never edit `.claude/context-engine/baseline/` or the install manifest by hand: they are the merge base.

### I edited a hook / command / rule / skill — why isn't it working?

Hooks, slash commands, path-scoped rules, and agent skills all load at **Claude Code session start**. Changes to any of them require exiting Claude Code and restarting. The `.claude/` tree is not hot-reloadable.

To verify loaded hooks in a running session: `/hooks`.

## Path-scoped rules explained

`.claude/rules/*.md` files have YAML frontmatter like:

```yaml
---
paths:
  - "src/SomeArea/**/*.{{PRIMARY_EXT}}"
---
```

Rules with a `paths:` glob only activate when the agent touches files matching the glob. Rules without a `paths:` key are always loaded. This is how area-specific guidance reaches the agent without bloating `CLAUDE.md`.

To add a new scoped rule, create `.claude/rules/<topic>.md` with appropriate `paths:` frontmatter. Restart Claude Code for it to load.

## Don'ts

- **Don't hand-edit `Context/generated/`.** Files there are regenerated from source; your edits will be silently overwritten. Run `/refresh-context` instead.
- **Don't edit archived specs** under `Context/specs/archive/**` or `Context/roadmap/archive/**`. They're frozen historical snapshots.
- **Don't renumber or substantively edit past ADRs.** Supersede by creating a new one.
- **Don't add AI-attribution trailers to commit messages.** The `commit-msg` hook at `.githooks/commit-msg` rejects them at the git level, and `CLAUDE.md` documents the rule for the agent.
- **Don't blanket-delete old files in `Context/`.** Specs, ADRs, and insights are the audit trail.

## The `context-keeper` skill (how it behaves)

Runs transparently — you don't invoke it. It watches for cues like:

- "I added \<new public surface\>" → propose `/refresh-context` + possible rule addition
- "\<feature\> is done" / "let's archive this" → propose `/archive-spec`
- "from now on all X should Y" / "let's record this decision" → propose `/new-adr`
- "worth remembering" / "I kept hitting this" → drop into `Context/insights/_inbox/`

If it gets over-eager (proposes an operation you don't want), just say "don't run the skill for this" — the agent will back off. The full operation set is at `.claude/skills/context-keeper/SKILL.md`.

## Troubleshooting

### The session-start briefing didn't appear

- Did you fully restart Claude Code after any `.claude/` change? Hot-reload isn't supported.
- The hook runs as `pwsh -NoProfile -ExecutionPolicy Bypass -File ${CLAUDE_PROJECT_DIR}/.claude/hooks/session-start.ps1`. Verify `pwsh` (PowerShell 7+) is on PATH.
- Check `.claude/session-start.log` for silent failures (the hook logs errors there rather than blocking the session).

### `PostToolUse` watch feels too frequent / noisy

Create an empty file at `.claude/disable-post-edit-watch`. The hook exits silently when this file exists. Delete the file to re-enable. To tune *which* edits trigger it, edit the `Watches` list in `.claude/context-engine.psd1`.

### A slash command doesn't appear in `/help`

- Confirm it's in `.claude/commands/` (not a subdirectory).
- File name must end in `.md`.
- Restart Claude Code.

### The commit-msg hook is too strict or not strict enough

Edit `.githooks/commit-msg` and adjust the `grep -qiE` pattern. It is line-anchored so prose doesn't trigger; only real trailer lines do.

### I want to bypass the commit-msg hook for one commit

`git commit --no-verify` skips **all** local hooks for that commit. Use sparingly — the hook exists for a reason.

## Weekly housekeeping (optional but useful)

Every week or so:

1. `/state-of-project` — fresh status snapshot.
2. Review `Context/insights/_inbox/` — promote durable entries into topic files, delete noise.
3. `/validate-context` — surface stale `last_verified:` stamps.
4. Glance at `Context/roadmap/current.md` — anything shipped or parked? Move accordingly.

## Where to ask "why?"

For any design question about how this system works:

1. Start with the ADRs under `Context/adr/`. Numbered, append-only, cover the big decisions.
2. If the ADRs don't answer it, check the relevant doc under `architecture/` or `conventions/`.
3. If neither, it's probably not documented yet — capture it in `Context/insights/_inbox/` as you figure it out.
