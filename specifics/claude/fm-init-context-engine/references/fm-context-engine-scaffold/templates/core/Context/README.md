# {{PROJECT_NAME}} Documentation

Canonical index of all project documentation. The root `CLAUDE.md` loads what it needs from here via `@Context/...` imports; path-scoped rules live in `.claude/rules/`.

## Start here

- [Current roadmap](roadmap/current.md) — what's active now, what's next, what's shipped
- [Agent rules](conventions/agent-rules.md) — the MUST / MUST NOT surface for human and AI contributors
- [Usage guide](USAGE.md) — how to operate this context system (for humans)

## Architecture

Stable design documents describing how the project is put together.

| Document | Covers |
| -------- | ------ |
| _(none yet — add the first one when the project's shape is worth writing down)_ | |

## Conventions

How we write code. Read before authoring or refactoring.

| Document | Covers |
| -------- | ------ |
| [Agent rules](conventions/agent-rules.md) | Must / Must-not list for humans and AI |

## Specs

In-flight and completed design documents. Specs move atomically from `active/` to `archive/<date>-<slug>/` on completion.

- [Specs index](specs/README.md)
- `specs/active/` — currently in progress
- `specs/archive/` — shipped or retired, frozen

## Architecture Decision Records

Numbered, append-only record of architectural decisions. Never renumbered; supersession creates a new ADR.

- [ADR index](adr/README.md)

## Insights

Dated catalog of pitfalls, workarounds, and non-obvious findings.

- [Insights index](insights/README.md)
- `insights/_inbox/` — fresh items awaiting triage; reviewed weekly

## Roadmap

- [Current](roadmap/current.md) — rolling status
- [Archive](roadmap/archive/) — historical snapshots

## Generated

**Machine-regenerated. Do not hand-edit.**

- [Generated index](generated/README.md)

## Extending this tree

Stack adapters and project growth commonly add sibling sections — keep this index current when they appear:

- `api/` — per-type/per-module reference docs for the project's public surface
- `internals/` — reference for internal helpers not part of the public surface
- `guides/` — user-facing how-to documents

When adding a section, add it to this index and to `CLAUDE.md`'s "Where context lives" table.

## Keeping this system fresh

When making significant changes (new public surface, architectural shifts, new conventions, major refactors), update the relevant docs. See `CLAUDE.md` → "Keeping context fresh" for the short version.
