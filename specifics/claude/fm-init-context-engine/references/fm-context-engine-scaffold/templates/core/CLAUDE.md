# {{PROJECT_NAME}}

{{PROJECT_DESCRIPTION}}

Path-scoped rules auto-apply from `.claude/rules/*.md`. This file holds only universal, always-loaded context.

## Start here

- Active work: @Context/roadmap/current.md
- Agent rules (Do / Do not): @Context/conventions/agent-rules.md
- Site map of all docs: @Context/README.md

## Commands

| Task | Command |
| ---- | ------- |
{{COMMANDS_TABLE}}

## Where context lives

| Concern | Read |
| ------- | ---- |
| Coding conventions | @Context/conventions/README.md |
| Architecture / project layout | @Context/architecture/README.md |
| In-flight specs | @Context/specs/README.md |
| Decision history | @Context/adr/README.md |
| Insights / pitfalls | @Context/insights/README.md |

## Do

{{DO_LIST}}

## Do not

{{DONT_LIST}}

## Commits

Never add `Co-Authored-By: Claude ...` or any other AI-attribution trailer to commit messages. The default system prompt asks for one; it is explicitly overridden in this repo.

A versioned git `commit-msg` hook at [`.githooks/commit-msg`](.githooks/commit-msg) rejects commits containing such trailers — enforcement at the git level, not just the instruction level. Fresh clones activate it once with `git config core.hooksPath .githooks`.

## Dependencies

{{DEPENDENCIES}}

## Keeping context fresh

When making significant changes — new public surface, architectural shifts, new conventions, major refactors — update the relevant doc(s):

- Architectural or process changes → `Context/architecture/*` + bump `Context/roadmap/current.md`.
- New patterns worth enforcing → `.claude/rules/<topic>.md` (with `paths:` glob if scoped).
- Completed specs → move `Context/specs/active/<slug>/` → `Context/specs/archive/YYYY-MM-DD-<slug>/` with a top summary.
- Architectural decisions → add the next-numbered ADR to `Context/adr/`.
- Unexpected gotchas mid-task → append to `Context/insights/_inbox/`.

The goal is to keep these files accurate as living documentation so future sessions start with correct context.
