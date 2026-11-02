# ADR-0001: Adopt the context-engine documentation and automation system

## Status

Accepted — {{TODAY}}

## Context

{{PROJECT_NAME}} needs durable project memory that survives across AI-assisted development sessions, machines, and long gaps between work periods. Ad-hoc notes and chat history don't persist; a structured, in-repo system does.

The maintainer operates a proven system of this shape in other repositories (originating in `powershell-fmdevtoolbox`, extracted into the reusable `context-engine` template): a self-contained `Context/` tree (architecture docs, conventions, ADRs, specs, insights, roadmap, generated indexes) plus a `.claude/` automation layer (session-start briefing hook, config-driven post-edit watch hook, six slash commands, and the `context-keeper` agent skill).

## Decision

Adopt the context-engine system in this repository:

- All durable project knowledge lives under `Context/`, indexed by `Context/README.md`.
- `CLAUDE.md` stays lean and imports from `Context/` via `@Context/...` links.
- Architectural decisions are recorded as append-only, numbered ADRs in `Context/adr/`.
- Multi-phase feature work is planned in `Context/specs/active/` and frozen into `Context/specs/archive/` when shipped.
- Gotchas land in `Context/insights/_inbox/` and are triaged weekly.
- `Context/roadmap/current.md` is the rolling "you are here" document, refreshed as work completes.
- The `.claude/` automation layer (hooks, commands, `context-keeper` skill) keeps the system current with minimal manual effort. Project-specific automation values (watch globs, regenerators, public-surface definition) live in `.claude/context-engine.psd1`, not in the scripts.
- Engine-owned files (hooks, commands, the skill, this process scaffolding) may be re-synced from the context-engine template; project-authored content under `Context/` is never touched by such updates.

## Consequences

### Positive

- Every new session (human or AI) starts oriented: branch, roadmap, active specs injected automatically.
- Decisions, plans, and pitfalls are captured where future sessions will actually find them.
- Process files stay consistent with the maintainer's other repositories, and fixes to the shared engine can be pulled in.

### Negative

- Discipline cost: roadmap, specs, and insight triage require ongoing (if small) maintenance to stay truthful.
- The automation layer assumes PowerShell 7+ (`pwsh`) on PATH and Claude Code as the primary agent harness.

## Alternatives considered

### Unstructured notes / relying on chat history

Rejected: not durable, not discoverable, not versioned with the code.

### A wiki or external docs site

Rejected: context must live in-repo so agents load it automatically and it versions atomically with the code it describes.

### Hand-rolling a fresh structure per project

Rejected: per-project dialects drift; a shared template keeps the process contract identical everywhere and makes improvements portable.
