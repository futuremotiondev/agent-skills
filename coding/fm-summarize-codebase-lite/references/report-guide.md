# Report guide: sections 1–3

What each non-reference section needs, how deep to go, and the evidence behind it. The
layout is in [report-template.md](report-template.md). This guide covers the content.

## Contents

- [Principles](#principles)
- [1.1 Identity and metadata](#11-identity-and-metadata)
- [1.2 Purpose](#12-purpose)
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
  "a comprehensive, powerful toolset". Name files, functions (with IDs), and counts.
- **Verified, not inferred.** When something comes from docs and you couldn't confirm
  it in code, say "the README states …".
- **Match the codebase.** A 300-line script gets a short section 3. A monorepo gets a
  subsection per package. Write "Not applicable" and the reason rather than padding a
  subsection.

## 1.1 Identity and metadata

- **Official name:** follow the precedence in [metadata-sources.md](metadata-sources.md).
  Give the package identifier too when it differs.
- **Conflicts are findings.** Keep every disagreeing value with its source (version in
  `pyproject.toml` versus `__init__.py`, manifest versus tag). Add which one the build
  uses when the code makes it clear.
- **Snapshot honesty.** Name the commit you read at. If the working tree has
  uncommitted changes, say so, and what kind if you can tell (line endings only, or
  real edits).
- **Other important metadata:** supported platforms, the published package and its
  registry, deployment target, data stores, required external services or API keys
  (names only), bundled third-party assets and their licenses, committed packaged
  artifacts (and whether they match the source), workspace members, and archived or
  deprecated status.

## 1.2 Purpose

Two to four sentences: what is it, what problem does it solve, for whom, and in what
form is it used?

> Tidewater is a command-line tool and Python library that ships container logs to
> object storage. It tails Docker and containerd log files, batches and compresses
> records, and uploads them to S3-compatible buckets on a schedule or size threshold.
> Operators run it as a sidecar or systemd service; the library API lets other tools
> embed the same pipeline.

The example above is fictional. Take the purpose from the README, manifests, and entry
points, then confirm it against the code. If the README oversells, describe what the
code does.

## 1.4 Technology stack and 1.5 entry points

- List every framework and runtime library the manifests declare (for large projects,
  the ones with runtime scope). Fill **Used for** from the code ("HTTP routes in
  `api/`", "validates CLI arguments"). A dependency nothing imports is a finding: write
  "Unused" and mention it in 3.11.
- For entry points, name the primary one, and the exact command or host that starts
  it, taken from the README, scripts, Dockerfile, or CI.

## 2. General overview

300–600 words of plain prose:

1. What it does, in one paragraph a non-specialist could follow.
2. How it's used: who runs it, how, and what they get.
3. The main parts (4–8), one or two sentences each, and how they cooperate.
4. The key design decisions and trade-offs visible in the code.
5. External dependencies that shape it.

Then the architecture diagram.

## 3. Detailed overview

| Subsection | What it must contain |
| --- | --- |
| 3.1 Directory structure | A role for every module, including data-only folders (`data/`, `docs/`, `assets/`); flag leftovers (dead folders, duplicates) |
| 3.2 Architecture and design | Style (layered, pipeline, plugin host, MVC/MVVM, actor…), layering rules and where they're broken, core abstractions, patterns with file references |
| 3.3 Execution flow | The primary path from entry point to result, naming functions with IDs in order; startup, configuration, main loop or request handling, shutdown; a sequence diagram |
| 3.4 Components and modules | Per module: responsibility, key files, public API, dependencies in both directions, owned state, notable internals |
| 3.5 Data model and state | Core types and what they represent, schemas, persistence, lifecycle, invariants |
| 3.6 External interfaces | CLI commands and flags, HTTP/RPC/MCP/IPC endpoints, events, public library API, config files, environment variable names, file formats. Tool and endpoint catalogs belong here, *in addition to* the per-function reference |
| 3.7 Configuration, build, and run | Exact commands from the repository, required tools and versions, configuration options with defaults |
| 3.8 Dependencies | Load-bearing dependencies and why; pinned, forked, vendored, or unusual ones |
| 3.9 Testing | What's covered and what isn't, test types, how to run them, fixtures, CI |
| 3.10 Cross-cutting concerns | Error handling, logging, concurrency, performance, security model, i18n, accessibility; only those that apply |

## 3.11 Observations and risks

This section is an assessment, clearly separated from description. Collect candidates
while reading: version drift, TODO/FIXME comments (count those in comments only, not in
strings or data), functions nothing calls or references, swallowed errors,
inconsistencies between docs and code. Then verify each one. Format:

```markdown
- **High: flush can deadlock.** `Shipper.flush` (F112) takes `self._lock` and then calls
  `Shipper.snapshot` (F109), which takes the same non-reentrant lock (`tidewater/ship.py:212`, `:180`).
- **Medium: version drift.** `tidewater/__init__.py:3` says 0.1.0; `pyproject.toml` says 0.4.2.
- **Low: dead code.** `legacy_upload.py` duplicates `Uploader.put` (F140) and has no callers.
```

The findings above are a fictional example. Severity: **High** means wrong results,
data loss, security exposure, or a crash on a normal path. **Medium** means a likely bug
on a less common path, fragile behavior, or significant drift. **Low** means cleanup or
a minor inconsistency. Before calling a function dead, check that its name isn't passed
as a callback, registered in a table, or looked up by string. If you found nothing
significant, say so explicitly.

## Diagrams

Use Mermaid in fenced `mermaid` blocks. They render on GitHub and in most viewers.

- **Architecture** (section 2): `flowchart LR` or `TD`, 5–12 nodes, subgraphs for
  layers or processes, and edges labelled with what flows ("JSON-RPC over stdio",
  "SQL", "S3 PUT").
- **Sequence** (3.3): `sequenceDiagram` with 3–7 participants.
- **Optional:** `erDiagram` for a data model with 3+ related entities, and
  `stateDiagram-v2` for an explicit state machine.

Syntax that avoids render failures: quote labels containing spaces or punctuation
(`A["Log Tailer"]`), keep node IDs alphanumeric, avoid parentheses and semicolons in
unquoted labels, and never use `end` as a node ID.

## Style

- Present tense, active voice, and specific nouns ("`Uploader.put` retries three
  times", not "uploads are retried").
- Code identifiers go in backticks, file references use `path:line`, and function
  references can carry their ID.
- Use tables for four or more parallel items, and prose for explanations.
- No marketing adjectives ("robust", "powerful", "seamless"). Replace each with the fact
  it stood in for.
