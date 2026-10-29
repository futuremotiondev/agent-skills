# Agent Rules

The canonical MUST / MUST NOT list. `CLAUDE.md` imports this file and path-scoped rules in `.claude/rules/*.md` layer additional specifics on top.

Read this first before editing anything.

## Code work

### Do

<!-- Seeded at init by /fm-init-context-engine from the interview + observed conventions.
     Keep entries short, imperative, and enforceable. One rule per bullet. -->

- {{DO_RULES}}

### Do not

- {{DONT_RULES}}

## Documentation

These rules are part of the context-engine process contract and apply to every project using it.

### Do

- Update the relevant doc when making a significant change (new public surface, architectural shift, new convention, major refactor). See "Keeping context fresh" in `CLAUDE.md`.
- Create an ADR (via `/new-adr`, or by adding the next-numbered file to `Context/adr/`) when making an architectural decision worth preserving.
- Move a completed spec from `Context/specs/active/<name>/` to `Context/specs/archive/YYYY-MM-DD-<name>/` with a top-of-file summary of what shipped (`/archive-spec` does this).
- Drop unexpected gotchas discovered mid-task into `Context/insights/_inbox/` as dated markdown files.

### Do not

- Hand-edit anything in `Context/generated/`.
- Renumber or edit past ADRs — supersede them by creating a new one.
- Delete specs in `Context/specs/archive/` — they are the audit trail.
- Promote `_inbox/` insights to durable convention docs without explicit maintainer approval.
