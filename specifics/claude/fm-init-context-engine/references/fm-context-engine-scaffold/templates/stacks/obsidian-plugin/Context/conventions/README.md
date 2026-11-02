# Conventions

How we write code in this project. Read before authoring or refactoring.

## Documents

| Document | Covers |
| -------- | ------ |
| [Agent rules](agent-rules.md) | Must / Must-not list for humans and AI |
| [TypeScript style](typescript-style.md) | Compiler settings, types at boundaries, module structure, errors and async, tooling |
| [Obsidian plugin style](obsidian-plugin-style.md) | Toolchain, release channels (public 1.13.0+, Early access 1.14.0+) and the floor, version-gated APIs and deprecations, lifecycle and load time, settings and secrets, vault and files, views, editor and rendering, DOM and styling, pop-out windows, mobile, network and security, commands, release and the Community directory, the development loop and testing, tooling defaults |

## Facts, guardrails, and defaults

These documents are defaults, not a cage. They contain three kinds of statement:

- **Platform facts** describe what Obsidian and its Community directory do at the recorded floor (`minAppVersion`). If one is wrong for that version, fix the document.
- **Guardrails** are security and correctness rules held on purpose. Deviating needs an ADR that names the risk and how it is contained.
- **Defaults**, marked **Default:**, are recommended starting choices for tooling, layout, and code shape. Deviate whenever the project has a reason.

When a task conflicts with a convention, say which kind it is, propose the deviation, and proceed once it is agreed. Do not refuse work only because a default says otherwise, and do not silently break a guardrail. Record structural deviations (an ADR, or an edit to the relevant document; these seeds are project-owned) so a later session does not "fix" them back.

The path-scoped rules in `.claude/rules/` carry only platform facts and guardrails, because they load automatically and read as instructions. The Do and Do-not lists in [Agent rules](agent-rules.md) hold guardrails and the decisions this project has made binding. Defaults live only in the style documents.

## When to add a document here

- A recurring code shape worth templating (e.g. "a view: the `ItemView` subclass, its `registerView` call, and the command that reveals it").
- A cross-cutting contract every unit of code must honor.

Conventions describe **how we write** (enforceable rules), not why (`Context/adr/`) or what exists (`Context/architecture/`). Keep rules short and checkable; move rationale into an ADR and link it.
