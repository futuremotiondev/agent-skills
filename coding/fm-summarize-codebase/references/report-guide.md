# Report guide: sections 1–3

What each non-reference section of the summary needs, how deep to go, and the evidence
behind it. The scaffold has already written every fact it could measure. This guide
covers the `[[FILL]]` slots.

## Contents

- [Principles](#principles)
- [1.1 Identity and metadata](#11-identity-and-metadata)
- [1.2 Purpose](#12-purpose)
- [1.3 Languages](#13-languages)
- [1.4 Technology stack and 1.5 entry points](#14-technology-stack-and-15-entry-points)
- [2. General overview](#2-general-overview)
- [3. Detailed overview](#3-detailed-overview)
- [3.11 Observations and risks](#311-observations-and-risks)
- [Diagrams](#diagrams)
- [Style](#style)

## Principles

- **Two readers.** Section 2 is for someone who has never seen the code and wants the
  shape of it in five minutes. Section 3 is for an engineer about to change it.
- **Evidence over adjectives.** "Registers 42 CLI subcommands in `cli/main.py`" beats
  "a comprehensive, powerful toolset". Name files, functions, and counts.
- **Verified, not inferred.** When something comes from docs and you couldn't confirm
  it in code, say "the README states …".
- **Match the codebase.** A 300-line script gets a short section 3. A monorepo gets a
  subsection per package. Remove a subsection's `[[FILL]]` by writing "Not applicable"
  and the reason, rather than padding it.

## 1.1 Identity and metadata

The table is pre-filled from `metadata.json`. Your jobs:

- **Official name.** The scaffold prefers the README title, then the display name, then
  the package id. Change it if the evidence points elsewhere (for example, a README
  titled "Documentation"). The rules are in [metadata-sources.md](metadata-sources.md).
- **Conflicts.** Leave the ⚠ notes in place; they are findings. If you can tell which
  source is authoritative (the build reads `pyproject.toml`; `__init__.py` is stale),
  add that in one clause. The same goes for a stale packaged artifact: say which
  files differ and whether the package is what users actually install.
- **Working tree.** When the snapshot row says "dirty", check what the changes are
  (`git status`, `git diff --stat`). If they're only line endings or mode changes, say
  so; if they're real edits, say the summary describes uncommitted code.
- **Other important metadata.** Supported OS or platforms, published registry package
  and its name, deployment target, data stores, required external services or API keys
  (names only), licenses of bundled third-party assets, minimum hardware, and whether
  it's archived or deprecated. Write "None" if nothing applies.

## 1.2 Purpose

Two to four sentences answering: what is it, what problem does it solve, for whom,
and in what form is it used (CLI, library, service, desktop/mobile/web app, plugin,
agent skill, script collection)?

> Tidewater is a command-line tool and Python library that ships container logs to
> object storage. It tails Docker and containerd log files, batches and compresses
> records, and uploads them to S3-compatible buckets on a schedule or size threshold.
> Operators run it as a sidecar or systemd service; the library API lets other tools
> embed the same pipeline. *(Fictional example.)*

Take it from the README, manifests, and entry points, and confirm it against the code.
If the README oversells, describe what the code does.

## 1.3 Languages

Fully generated. Don't recompute or round differently. If the numbers mislead (a
vendored library committed without `.gitattributes`, or a giant generated file that
slipped through), say so in one sentence under the table and suggest re-running with
`--exclude`.

## 1.4 Technology stack and 1.5 entry points

- For each detected framework, fill **Used for** from reading the code ("HTTP API
  routes in `api/`", "validates CLI arguments"). A dependency that is declared but
  never imported is a finding: say so, and mention it in 3.11.
- Add frameworks the detector missed (it only knows common package names).
- For entry points, name the primary one and give the exact command or host that
  starts it, taken from the README, scripts, Dockerfile, or CI.

## 2. General overview

300–600 words of plain prose. Suggested flow:

1. What it does, in one paragraph a non-specialist could follow.
2. How it's used: who runs it, how, and what they get.
3. The main parts (4–8), one or two sentences each, and how they cooperate.
4. The key design decisions and trade-offs visible in the code.
5. External dependencies that shape it (runtime, services, notable libraries).

Then the **architecture at a glance** diagram (see [Diagrams](#diagrams)).

## 3. Detailed overview

| Subsection | What it must contain |
| --- | --- |
| 3.1 Directory structure | A one-phrase role for every listed module; flag leftovers (dead folders, duplicates) |
| 3.2 Architecture and design | Style (layered, hexagonal, pipeline, plugin host, MVC/MVVM, actor…), layering rules and where they are broken, core abstractions, and patterns with file references |
| 3.3 Execution flow | The primary path from entry point to result, naming functions in order; startup, configuration loading, main loop or request handling, and shutdown; a sequence diagram for the most important flow |
| 3.4 Components and modules | Per module: responsibility, key files, public API (what others call), dependencies in both directions, owned state, notable internals |
| 3.5 Data model and state | Core types and what they represent, schemas, persistence (files, DBs, caches), lifecycle, and invariants the code enforces |
| 3.6 External interfaces | CLI commands and flags, HTTP/RPC/MCP/IPC endpoints, events, public library API, config files, environment variables (names only), and file formats. Use tables; a tool or endpoint catalog belongs here |
| 3.7 Configuration, build, and run | Exact commands from the repo, required tools and versions, and configuration options with defaults |
| 3.8 Dependencies | Which ones are load-bearing and why; pinned, forked, vendored, or unusual ones |
| 3.9 Testing | What's covered and what isn't, test types, how to run them, fixtures, and CI |
| 3.10 Cross-cutting concerns | Error handling, logging, concurrency model, performance, security model, i18n, accessibility; only those that apply |

## 3.11 Observations and risks

This is an assessment, clearly separated from description. The scaffold lists starting
points (version drift, markers, uncalled private functions); verify each before keeping
it. Format:

```markdown
- **High: flush can deadlock.** `Shipper.flush` takes `self._lock` and then calls
  `Shipper.snapshot`, which takes the same non-reentrant lock (`tidewater/ship.py:212`, `:180`).
- **Medium: version drift.** `tidewater/__init__.py:3` says 0.1.0; `pyproject.toml` says 0.4.2.
- **Low: dead code.** `legacy_upload.py` duplicates `Uploader.put` and has no callers.
```

The findings above are a fictional example.

Severity: **High** means wrong results, data loss, security exposure, or a crash on a
normal path. **Medium** means a likely bug on a less common path, fragile behavior, or
significant drift. **Low** means cleanup, style, or a minor inconsistency. If you found
nothing, write that you found no significant issues, which is itself a statement.

## Diagrams

Use Mermaid in fenced ```` ```mermaid ```` blocks. They render on GitHub and in most
viewers.

- **Architecture** (section 2): `flowchart LR` or `TD` with 5–12 nodes. Use subgraphs
  for layers or processes, and label the edges with what flows ("JSON-RPC over stdio",
  "SQL", "S3 PUT").
- **Sequence** (3.3): `sequenceDiagram` for the most important flow, with 3–7
  participants.
- **Optional:** `erDiagram` for a data model with 3+ related entities, and
  `stateDiagram-v2` for an explicit state machine.

Syntax that avoids render failures: quote node labels containing spaces or punctuation
(`A["Log Tailer"]`), keep IDs alphanumeric, avoid parentheses and semicolons in
unquoted labels, and don't use `end` as a node ID.

## Style

- Present tense, active voice, and specific nouns ("`Uploader.put` retries three times",
  not "uploads are retried").
- Code identifiers go in backticks, and file references use `path:line`.
- Use tables for enumerations of four or more items, and prose for explanations.
- No marketing adjectives ("robust", "powerful", "seamless", "comprehensive"). Replace
  each with the fact it was standing in for.
