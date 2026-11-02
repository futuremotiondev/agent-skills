# Conventions

How we write code in this project. Read before authoring or refactoring.

## Documents

| Document | Covers |
| -------- | ------ |
| [Agent rules](agent-rules.md) | Must / Must-not list for humans and AI |
| [Rust style](rust-style.md) | Toolchain table, error strategy, `unsafe` policy, clippy/fmt gates, crate layout, foreign-language (C ABI) boundaries |

## Facts, guardrails, and defaults

These documents are defaults, not a cage. They contain three kinds of statement:

- **Platform facts** describe what the language, framework, or platform does at the version this project uses. If one is wrong for that version, fix the document.
- **Guardrails** are security and correctness rules held on purpose. Deviating needs an ADR that names the risk and how it is contained.
- **Defaults**, marked **Default:**, are recommended starting choices for tooling, layout, and code shape. Deviate whenever the project has a reason.

When a task conflicts with a convention, say which kind it is, propose the deviation, and proceed once it is agreed. Do not refuse work only because a default says otherwise, and do not silently break a guardrail. Record structural deviations (an ADR, or an edit to the relevant document; these seeds are project-owned) so a later session does not "fix" them back.

The path-scoped rules in `.claude/rules/` carry only platform facts and guardrails, because they load automatically and read as instructions. The Do and Do-not lists in [Agent rules](agent-rules.md) hold guardrails and the decisions this project has made binding. Defaults live only in the style documents.

## When to add a document here

- A recurring code shape worth templating (e.g. "the canonical opaque-handle export + `*_free` pair").
- A cross-cutting contract every unit of code must honor.

Conventions describe **how we write** (enforceable rules), not why (`Context/adr/`) or what exists (`Context/architecture/`). Keep rules short and checkable; move rationale into an ADR and link it.
