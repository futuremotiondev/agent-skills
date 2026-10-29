# Report template

The exact layout of the summary. Copy the structure, replace every `{placeholder}`, and
follow the instruction in each italic note (then delete the note). Keep the headings
and numbering exactly as they are, because verification and readers rely on them. If a
subsection doesn't apply, keep the heading and write "Not applicable" and the reason.

Placeholders use `{curly braces}`. No `{` placeholder may remain in the delivered
report, except inside code blocks quoted from the codebase.

---

````markdown
# {Official name} — Codebase Summary

> Generated {YYYY-MM-DD} from {path or repository URL} at {short commit SHA or "no version control"} ·
> {N} source files · {total lines or bytes, with basis} · {N} functions & methods

**Contents:** [1. Specifications](#1-specifications) · [2. General overview](#2-general-overview) ·
[3. Detailed overview](#3-detailed-overview) · [4. Function and method reference](#4-function-and-method-reference) ·
[Appendices](#appendix-a-methodology-and-limits)

## 1. Specifications

### 1.1 Identity and metadata

| Field | Value | Source |
| --- | --- | --- |
| Official name | **{name}** | {README title / display name / manifest} |
| Package / identifier | `{package id}` | {manifest field} |
| Version | {version}{; ⚠ sources disagree: X in A, Y in B} | {source} |
| Release status | {HEAD is the tagged release / N commits past vX / no tags} | {git or API} |
| Last updated | {date of the last commit touching the target}{; uncommitted changes present} | {git / API / not available} |
| Latest snapshot | `{short SHA}` on `{branch}`: “{commit subject}” by {author name}, {date} | {git / API} |
| Repository | {URL, without credentials} | {remote / API} |
| History | First commit {date} · {N} commits · {N} contributors: {top names} | {git / API / not available} |
| License | {SPDX id or "Custom license (see LICENSE)" or "Not declared"} | {manifest / LICENSE text / API} |
| Authors | {names} | {manifest} |
| Declared description | {text} | {manifest / README} |
| Runtime / platform targets | {e.g. Python ≥3.10; .NET 8; Manifest V3} | {manifest fields} |
| Package manager · build · CI | {npm · Vite · GitHub Actions} | {lockfiles, configs} |
| Test frameworks · linters | {pytest · ruff} | {configs, dependencies} |
| Size | {N} source files · {lines/bytes with basis} · {N} functions & methods · {N} types | {measurement method} |
| Other important metadata | {platforms, published package, deployment target, data stores, stale packaged artifacts, workspace members, archived status — or "None"} | {sources} |

*Include a row for every field. Write "Not available" or "Not declared" and give the
reason in the Source column rather than removing the row. Name secret-bearing files if
present, never their contents.*

### 1.2 Purpose

{2–4 sentences: what the codebase is, the problem it solves, for whom, and in what form
(CLI, library, service, app, plugin, skill). Evidence first: README, manifests, entry
points, then code.}

### 1.3 Languages

{Method line and table from language-measurement.md, "The 1.3 table".}

### 1.4 Technology stack

| Framework / library | Declared in | Used for |
| --- | --- | --- |
| {name version} | {manifest} | {what this codebase uses it for, from reading the code; "Unused" if nothing imports it} |

{2–4 sentences on the stack as a whole.}

### 1.5 Entry points

| Kind | Name | Target | Declared in |
| --- | --- | --- | --- |
| {CLI / script / main / server / extension background} | {name} | `{file or command}` | {manifest or file} |

{How the codebase is started or consumed, and which entry point is primary.}

### 1.6 Function and method inventory

**Total functions & methods:** {N active IDs}

{N} in application code, {N} in tests; {N} abstract or interface declarations; {N}
types counted separately. Counted by {method: pattern search confirmed by reading every
file / reading every file}. Counting rule: named callables including nested functions,
named lambdas, abstract declarations, and file-level programs; anonymous callbacks
excluded.

| Kind | Count |
| --- | ---: |
| {method} | {N} |

| Language | Count |
| --- | ---: |
| {Python} | {N} |

| Module | Functions & methods |
| --- | ---: |
| `{module}` | {N} |

#### Function index

**`{path/to/file}`** ({N})

| ID | Function | Kind | Lines | Summary |
| --- | --- | --- | --- | --- |
| F001 | `{qualified name}` | {kind}{ · test / · abstract} | {12–40} | {the entry's Summary line, word for word} |

*One table per file that has callables, files in inventory order. The Summary column is
the entry's Summary line copied exactly; escape a literal `|` as `\|`. For split delivery, the index
can live in its own part or file: link it from here. Test cases registered with
callbacks (`test('…', …)`) aren't rows here; they're counted in 3.9.*

## 2. General overview

{300–600 words for a newcomer: what it is and does, who uses it and how, the main parts
and how they cooperate, key design decisions, and what it depends on.}

### Architecture at a glance

```mermaid
flowchart LR
    {5–12 components and external systems, with labelled data-flow edges}
```

{One sentence per node that isn't self-explanatory.}

## 3. Detailed overview

### 3.1 Directory structure

| Module | Files | Size | Functions | Role |
| --- | ---: | ---: | ---: | --- |
| `{module}` | {N} | {lines or bytes} | {N} | {role in one phrase} |

### 3.2 Architecture and design

{Style, layering, core abstractions, and patterns with file references.}

### 3.3 Execution flow

{The primary flow from entry point to result, naming functions (with IDs) in order.}

```mermaid
sequenceDiagram
    {3–7 participants for the most important flow}
```

### 3.4 Components and modules

#### `{module}`

{N} files · {size} · {N} functions & methods · types: {main types}

{Responsibility, key files, public API, dependencies in and out, owned state, notable
internals.}

### 3.5 Data model and state

{Core types and what they represent, schemas, persistence, lifecycle.}

### 3.6 External interfaces

{CLI commands and flags, HTTP/RPC/MCP/IPC endpoints, events, public API, config files,
environment variable names, file formats. Use tables.}

### 3.7 Configuration, build, and run

{Exact commands from the repository; required tools and versions; configuration options.}

### 3.8 Dependencies

| Dependency | Version spec | Scope | Declared in |
| --- | --- | --- | --- |
| `{name}` | {spec} | {runtime / dev / peer} | {manifest} |

{Which dependencies are load-bearing and why; anything pinned, forked, or vendored.}

### 3.9 Testing

{N} test functions in the inventory and {N} callback-registered test cases in {N} test
files; frameworks: {names}. {What's tested and what isn't, how to run the tests, CI.}

### 3.10 Cross-cutting concerns

{Error handling, logging, concurrency, performance, security model — only those that
apply.}

### 3.11 Observations and risks

Assessment, not fact: each point cites `file:line` evidence and has a severity.

- **{High/Medium/Low}: {title}.** {Finding with evidence.}

## 4. Function and method reference

### `{path/to/file}`

{The file's role in one sentence.}

#### F001 · `{qualified name}`

{kind} · {flags} · `{path/to/file}` lines {12–40}

```{language}
{signature}
```

{Optional: Doc comment: “…” · Calls: `x` (F00n) · Called by: `y` (F00n)}

**Summary:** {one line, verb first, ≤ 15 words}

{Detailed description, or one or two sentences for a compact entry.}

## Appendix A. Methodology and limits

- **Access:** {local files with/without shell · GitHub API at {SHA} · provided files}.
- **Files:** {N} listed; excluded {N} vendored, {N} generated, {N} binary (examples: …).
- **Languages:** method {A/B/C/D}, basis {bytes/lines}, precision {exact/approximate}.
- **Functions:** inventory built by {search + reading / reading}; {N} files read in full.
- **Metadata not available:** {fields and why}.
- **Scope:** {whole codebase / exclusions the user chose}.
- **Verification:** {the result line from verification.md; omit if your write tool can't
  update the file after checking, and give it in the delivery message instead}.

## Appendix B. Corrections

| ID | Correction |
| --- | --- |
| F057 | Withdrawn: {reason, e.g. a macro invocation, not a function} |
| F389 | Added after the initial inventory: {where it was found} |

{Or: "No corrections were needed."}
````
