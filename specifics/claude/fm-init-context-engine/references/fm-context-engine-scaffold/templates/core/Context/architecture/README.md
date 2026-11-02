# Architecture

Stable design documents describing how the project is put together — layout, subsystem boundaries, build system, configuration. Read these first for any deep dive.

## Documents

| Document | Covers |
| -------- | ------ |
| _(none yet)_ | |

## When to add a document here

- The project's directory layout and subsystem responsibilities are settled enough to describe (`<project>-layout.md` is usually the first doc).
- A build/packaging pipeline exists that a future session would otherwise have to reverse-engineer.
- A configuration system, plugin system, or cross-cutting mechanism has non-obvious rules.

Architecture docs describe **what is** (current state), not decisions (`Context/adr/`) or plans (`Context/specs/`). Add `last_verified: YYYY-MM-DD` frontmatter so `/validate-context` can flag drift.
