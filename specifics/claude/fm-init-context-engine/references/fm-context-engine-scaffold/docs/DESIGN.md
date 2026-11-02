# context-engine — Founding Design

**Status:** Accepted — 2026-07-29
**Origin:** Extracted from `powershell-fmdevtoolbox` (its ADR-0004 context management system), where the system ran in production for months before extraction.

This document is intentionally self-contained. A future session should be able to read only this file (plus `templates/`) and implement Phases 1–4 without replaying the conversation that produced it.

## Top-level design principle

**Determinism for structure, intelligence for content.** Anything that must be byte-identical across projects is copied by a script; anything that requires understanding a specific project is authored by the agent. When a judgment call is close, prefer moving it to the script side as *data* (config) rather than the agent side as *generation*.

## Problem

The maintainer runs many repositories across heterogeneous stacks — PowerShell modules, C# class libraries, WinUI 3 / WPF / Avalonia desktop apps, Electron apps, Python tools, possibly C++ later. One repo (`powershell-fmdevtoolbox`) has a proven "context engine": a self-contained `Context/` knowledge tree + a `.claude/` automation layer. Every new project should get the same system with minimal effort and **zero dialect drift** between repos, while adapting to each project's language, build commands, and purpose.

## The three-layer analysis (the load-bearing finding)

Auditing the origin system file-by-file, everything cleaves into three layers:

- **Layer A — fully generic.** The `Context/` skeleton and its process contract (append-only ADRs, frozen spec archives, insights inbox + weekly triage, rolling roadmap, never-hand-edit generated), five of the six slash commands, the session-start hook, and context-keeper Operations B/C/D. Portable verbatim.
- **Layer B — generic shape, project-specific values.** The post-edit hook (watch globs → actions), `/refresh-context` (which regenerators), context-keeper Operation A (what counts as "public surface"), the CLAUDE.md section skeleton. Portable as *code + per-project config*.
- **Layer C — genuinely project-specific.** CLAUDE.md Do/Do-nots, convention docs, architecture docs, roadmap content, path-scoped rules. Cannot be templated — only interviewed/analyzed into existence, and mostly grows organically after init.

The origin system had already quarantined stack-awareness into two chokepoints (one hook, one regenerator pair). This design preserves and hardens that quarantine: **Layer B collapses into data** (`.claude/context-engine.psd1`) read by engine-owned generic scripts.

## Decision: hybrid scaffolder + skill

Three options were considered:

1. **Skill only** (Claude generates everything per project). Rejected: LLM-generated scaffolds drift — each repo gets a slightly different dialect; no way to push engine fixes to N repos; slow and token-expensive for what is 70% file copying.
2. **Script only.** Rejected: a script cannot write Do/Do-not lists, roadmaps, or decide that an Electron app's public surface is its IPC registry. Produces an empty filing cabinet; empty context systems don't get adopted.
3. **Hybrid** — **chosen.** `Install-ContextEngine.ps1` owns Layers A + B-shapes; the `/fm-init-context-engine` user-level skill owns B-values + C. The skill's first act is running the script.

## Architecture

### Repository layout

```text
context-engine/
├── Install-ContextEngine.ps1      # Phase 1
├── Update-ContextEngine.ps1       # Phase 1/4
├── templates/
│   ├── core/                      # Layer A (+ B-shapes)
│   │   ├── CLAUDE.md              #   tokenized
│   │   ├── Context/               #   full knowledge-tree skeleton
│   │   ├── claude/                #   → .claude/  (commands, hooks, skill, config, settings fragment)
│   │   └── githooks/              #   → .githooks/ (commit-msg)
│   └── stacks/<adapter>/          # Layer B values per stack (Phase 3) — contract in stacks/README.md
└── docs/DESIGN.md                 # this file
```

Install mapping: `templates/core/claude/` → `<project>/.claude/`, `templates/core/githooks/` → `<project>/.githooks/`, everything else 1:1. (Non-dotted names in the template tree keep tooling and globbing friendly.)

### File ownership model (the update contract)

| Class | Files | Update behavior |
| ----- | ----- | --------------- |
| **Engine-owned** | `.claude/hooks/session-start.ps1`, `.claude/hooks/post-edit-watch.ps1`, all six `.claude/commands/*.md`, `.claude/skills/context-keeper/SKILL.md`, `.claude/context-engine/README.md`, `.githooks/commit-msg` (11 files; derived by prefix rule in `lib/common.ps1` `$EngineOwnedPrefixes`) | `Update-ContextEngine.ps1` overwrites from template. Projects must not hand-edit (edits are lost on update). Must be **token-free** — the installer enforces this as a tripwire, because the updater compares template content verbatim. |
| **Seeded-then-project-owned** | `CLAUDE.md`, `.claude/context-engine.psd1`, everything under `Context/` (including `generated/README.md` and `scripts/README.md`, whose artifact/regenerator lists projects populate — reclassified from engine-owned in Phase 1), `.claude/rules/*`, `.claude/settings.json`, `.gitattributes` | Written once at install (tokens substituted / fragment merged); never touched by a plain update. Each file copied from a template is snapshotted as a refresh baseline, and an explicit seed refresh (`-RefreshSeeds`, below) merges later template changes in, per the file's policy, without overwriting what the project changed. |

Both hooks and the config template carry a header comment declaring their ownership class.

**Baseline hash manifest (Phase 1 refinement).** Without a baseline, an updater cannot distinguish "engine evolved" from "user hand-edited." The installer therefore writes `.claude/context-engine-manifest.json` — `{ engineVersion, installedUtc, files: { targetRelativePath: sha256 } }` — hashing each engine-owned file at install. Hashes are **CRLF-normalized** (content with `\r\n` → `\n`) so git autocrlf churn in a target working tree never reads as a local modification. `.claude/context-engine.psd1`'s `EngineVersion` key mirrors the scaffold provenance for humans; the manifest is the machine record.

**Install records for seed refresh (manifest schema 2, 2026-09-29).** The update contract above leaves seeded files frozen at install, so corrected conventions never reach a project that already has them. The fix (a Copier-style three-way seed refresh, planned in the skills repo's `Context/CONTEXT_ENGINE_REFRESH_PLAN.md`) needs to know what the engine originally wrote, and that cannot be reconstructed later: the deployed skill copy has no version history. So the installer now records it at install time, ahead of the refresh itself (its phase 0):

- The manifest gains `schema` (2), `stack`, `chain` (the resolved adapter chain, canonical directory names), `tokens` (the installer's answers except `TODAY` and `ENGINE_VERSION`, which a refresh renders fresh), `seeds` (`{ targetRelativePath: { source, engineVersion, hash } }` for every non-engine-owned file copied from a template), `configDefaults` (the merged adapter defaults as spliced), and `optOut` (empty until refresh exists).
- Every seed is snapshotted exactly as installed (after installer tokens and the config splice, before the authoring pass) at `.claude/context-engine/baseline/<targetRelativePath>.base`. The `.base` suffix keeps Claude Code from discovering a snapshot as a rule (`.claude/rules/**/*.md` is scanned recursively) or a nested `CLAUDE.md`.
- `.claude/context-engine/` is engine-managed: its README is engine-owned, and `Find-LeftoverTokens` skips the folder, because snapshots predate the authoring pass and keep skill-owned tokens by design.
- `Update-ContextEngine.ps1` rewrites only `engineVersion`, `updatedUtc`, and `files`, carrying every other manifest key forward, so an ordinary engine update never discards the refresh baseline. Schema-1 manifests (installs before this change) stay schema 1 until a refresh migrates them.

**Seed refresh (2026-09-29).** `Update-ContextEngine.ps1 -RefreshSeeds` closes the gap. It re-renders every seed from the current templates with the recorded answers and chain, and treats each one by policy (`$SeedPolicies` in `lib/common.ps1`, extended by an adapter's `SeedPolicy` and the project's `SeedRefreshExclude`):

- **Merge** (conventions, rules, regenerators, the `Context/` index READMEs): a three-way merge with `git merge-file --diff3`, base = the baseline snapshot. A file only the engine changed is fast-forwarded; one both changed is merged, and a clean merge is written and listed for review. A conflict is not written: the diff3 result and the engine's text go to the self-ignoring `.claude/context-engine/incoming/` folder.
- **Propose** (`CLAUDE.md`, `agent-rules.md`, decision data such as `extension-targets.psd1`): never written; the engine's text and a diff against the baseline are offered instead.
- **Config** (`.claude/context-engine.psd1`): the adapter-supplied keys merge as data (base = `configDefaults`, theirs = the chain's defaults today, ours = the parsed file), `Watches` entry by entry keyed by Glob and Action; the core template's own text merges three-way.
- **Skip** (ADRs, roadmap, specs, insights, architecture docs, generated output): frozen history or live project content, never refreshed.

Two rules keep merges quiet and safe: a `last_verified` date change alone never conflicts, and a merge that would bring back a skill-owned token the project had filled is treated as a conflict. The refresh refuses a dirty working tree (so it lands as one reviewable diff), supports `-WhatIf`, reports the engine `CHANGELOG.md` entries newer than the project's last refresh with each entry's `Detect:` regex run over the project's source, and prints release-channel floor advisories without applying them. After the agent resolves the pending items, `-CompleteRefresh` sets each one's baseline to the engine's rendering, so the next refresh is three-way from there. A schema-1 install has no baselines: its first refresh (with `-Stack`) records one for every file that already matches the engine and offers the rest for a single two-way review. Copier's update model is the precedent; the rejected alternatives (reinstalling, overwriting, or a judgment-only review every time) are compared in the skills repo's `Context/CONTEXT_ENGINE_REFRESH_PLAN.md`. Keeping the templates themselves current is a maintainer task: [`REFRESHING-STACKS.md`](REFRESHING-STACKS.md).

### The config chokepoint: `.claude/context-engine.psd1`

All Layer-B values live here (schema documented inline in the template):

- `Watches` — list of `@{ Glob; Action = 'Run'|'MarkDirty'; Command/Message | Hint }` consumed by `post-edit-watch.ps1`. First match per Action kind fires; one edit may trigger both a `Run` and a `MarkDirty`.
- `Regenerators` — repo-relative `Context/scripts/*.ps1` paths consumed by `/refresh-context`.
- `PublicSurface` — one-sentence definition consumed by context-keeper Operation A.
- `DirtyHint` — optional custom session-start nudge text.
- `EngineVersion` — scaffold provenance stamp.

Rationale: one generic hook + per-project data beats N per-stack hook forks. Upgrading hook behavior = overwriting one engine-owned file in each repo, conflict-free. `Invoke-Expression` on `Watches[].Command` is an accepted trust decision — the config is repo-committed, maintainer-authored, same trust level as any build script.

### Token conventions

Tokens use `{{NAME}}` and are substituted by the installer (from CLI parameters + adapter defaults) or left for the skill to fill during authoring:

| Token | Filled by | Meaning |
| ----- | --------- | ------- |
| `{{PROJECT_NAME}}` | installer | Repo/project display name |
| `{{PROJECT_DESCRIPTION}}` | skill | One-paragraph purpose statement |
| `{{TODAY}}` | installer | ISO date at install |
| `{{MAIN_BRANCH}}` | installer | Default branch name |
| `{{REPO_URL}}` / `{{REPO_DIR}}` | installer | Clone URL / directory (blank-safe if no remote yet) |
| `{{ENGINE_REPO_URL}}` | installer | This repo's URL for back-references |
| `{{ENGINE_VERSION}}` | installer | Template version stamp |
| `{{PRIMARY_EXT}}` | installer (from adapter) | Main source extension, used in rule examples |
| `{{COMMANDS_TABLE}}` | skill (+ adapter fragment) | CLAUDE.md build/test/run table rows |
| `{{DO_LIST}}` / `{{DONT_LIST}}` / `{{DO_RULES}}` / `{{DONT_RULES}}` | skill | Project Do/Do-not bullets (CLAUDE.md + agent-rules.md) |
| `{{DEPENDENCIES}}` | skill | Toolchain/dependency summary |
| `{{STRATEGIC_DIRECTION}}` / `{{ACTIVE_WORK}}` | skill | Initial roadmap content |
| `{{PUBLIC_SURFACE}}` | skill (adapter suggests default) | Operation-A trigger definition |

Installer rule: after substitution, **no `{{...}}` may remain** in installed files; tokens the installer doesn't own are passed through to the skill's authoring pass, which must resolve the rest. `Install-ContextEngine.ps1 -Verify` (Phase 1) greps for leftovers.

### `Install-ContextEngine.ps1` behavior (shipped Phase 1)

1. Parameters: `-TargetPath` (default: cwd), `-Stack <adapter|None>`, `-ProjectName`, `-MainBranch` (default: detect or `main`), `-PrimaryExtension`, `-InitGit`, `-WhatIf`, `-Force` (allow non-empty `Context/` / reinstall), `-Verify`.
2. Preflight: git repo required — `-InitGit` runs `git init`, otherwise a non-repo target is a hard error (non-interactive by design; the Phase 2 skill asks the user and passes the switch). Refuse if `Context/`, `.claude/commands/`, or a prior install manifest exist unless `-Force`; a prior manifest without `-Force` is a friendly no-op (idempotent).
3. Copy `templates/core/` per the install mapping; apply stack adapter overlay if given (parent-first per `Inherits`; `adapter.psd1` excluded from copy). Tripwire: abort if any engine-owned template contains a token.
4. Substitute installer-owned tokens; leave skill-owned tokens intact (they're inside HTML comments or placeholder bullets, harmless if a human installs without the skill). Post-install verification fails the run if any installer-owned token survives.
5. **Merge** `settings.fragment.json` hooks into `.claude/settings.json` — create if absent; if present, append hook groups whose `command` strings aren't already registered for that event; never remove or reorder existing entries; never touch `permissions`. Re-merge is a no-op.
6. Pin `.githooks/commit-msg text eol=lf` in the target's `.gitattributes` (create or append) — CRLF checkout breaks `#!/bin/sh` hooks.
7. Write the baseline hash manifest; print next steps (activate `.githooks`, restart Claude Code, run the `/fm-init-context-engine` authoring pass or hand-fill the skill tokens, `-Verify` any time).
8. Exit-code hygiene: ends with explicit `exit 0` — internal git probes (e.g. a missing `origin` remote) must not leak a nonzero `$LASTEXITCODE` to callers.

### `Update-ContextEngine.ps1` behavior (shipped Phase 1)

Reconciles every engine-owned template file against the target using three CRLF-normalized hashes (template / baseline-from-manifest / current file):

| State | Condition | Action |
| ----- | --------- | ------ |
| `UpToDate` | current == template | none (re-baseline) |
| `Upgrade` | current == baseline, template evolved | overwrite |
| `Restore` | file missing, was in baseline | reinstall |
| `New` | engine-owned file added in a newer engine version | install |
| `ModifiedSkip` | current differs from both baseline and template | skip + warn; **keeps the old baseline** so the modification stays flagged on every future update until resolved; `-Force` overwrites |

Never touches seeded-then-project-owned files. Rewrites the manifest with fresh baselines + current engine version, bumps `EngineVersion` in `.claude/context-engine.psd1` textually, supports `-WhatIf`, reports files the engine no longer owns (`NoLongerEngineOwned`) without deleting them.

### Phase 1 implementation notes (pitfalls encoded in the scripts)

- `ForEach-Object <MemberName>` honors `ShouldProcess` — under propagated `-WhatIf` it *suppresses the member calls*. Hashing uses `[Convert]::ToHexString` instead.
- `$LASTEXITCODE` is `$null` in a fresh pwsh process until a native command runs; the watch hook seeds `$global:LASTEXITCODE = 0` before `Invoke-Expression` so pure-PowerShell `Run` commands don't false-fail.
- Shared single-sources-of-truth (engine-owned prefixes, exclusions, token sets, path mapping, hashing, settings merge) live in `lib/common.ps1`, dot-sourced by both entry scripts.

### `/fm-init-context-engine` skill (shipped Phase 2)

User-level skill at `~/.claude/skills/fm-init-context-engine/SKILL.md` (available in every repo). The skill is **portable by design** (since 2026-08-04): it references the engine as `references/fm-context-engine-scaffold` relative to the skill's own base directory (which the harness announces at skill load), and this engine folder lives at exactly that location nested inside the skill folder — so the skill folder is fully self-contained and copies across machines with no re-stamping (the earlier `{{ENGINE_ROOT}}` absolute-path stamping design is retired). **Since 2026-09-11** the skill root `SKILL.md` is the single source: the earlier `skills/fm-init-context-engine/` mirror inside this folder and the `Install-UserSkill.ps1` sync script were removed when the engine stopped being its own git repository and became a tracked subtree of the `futuremotion` skills repo. Deployment is a manual copy of the skill folder to `~/.claude/skills/`. Beyond the flow below, the shipped skill adds a **mode-selection gate** (full init / authoring-only for script-only installs with skill tokens outstanding / nothing-to-do → point at the updater / pre-existing hand-rolled context system → never overwrite, present options and stop) and a non-interactive fallback (author conservatively from observation, mark every inference `TODO: confirm with maintainer`, never block on questions). Flow:

1. **Preflight** — git repo, pwsh, existing-`Context/` detection (offer update/reconcile mode instead of overwrite).
2. **Detect stack** — `.csproj`/`.slnx` (+ WinUI/WPF/Avalonia package refs), `package.json` (+ electron dep), `pyproject.toml`, `.psd1`; propose; user confirms.
3. **Run the installer** with detected parameters.
4. **Interview** — project purpose, driving design principle, build/test/run commands, public-surface definition, known Do/Do-nots, initial roadmap items.
5. **Analyze + author** — read the codebase; fill all skill-owned tokens; write real roadmap content; seed `Context/architecture/<project>-layout.md` from observation; extend ADR-0001 if the interview surfaced project-specific consequences.
6. **Wire config** — `Watches`, `Regenerators`, `PublicSurface`, `DirtyHint`; run regenerators once if present.
7. **Handoff** — restart reminder (hooks/skills load at session start only), `git config core.hooksPath .githooks` reminder, first-week checklist.

Skill discipline (mirrors context-keeper's style): never overwrite an existing CLAUDE.md without confirmation; never invent Do/Do-nots that weren't observed in code or stated in the interview; always end with the restart reminder.

### Stack adapters (shipped Phase 3)

Contract and shipped set (all seven: `csharp`, `winui3`, `wpf`, `avalonia`, `electron`, `python`, `powershell-module`): see [`../templates/stacks/README.md`](../templates/stacks/README.md).

**Phase 3 decision — ConfigDefaults splice, not psd1 overlays.** Adapter config defaults ship as structured data in `adapter.psd1` (`ConfigDefaults = @{ PublicSurface; DirtyHint; Watches; Regenerators }`), merged per-key last-wins across the `Inherits` chain and spliced textually by the installer into the installed project config (Watches serialized via `Format-WatchEntry` in `lib/common.ps1`; result validated with `Import-PowerShellDataFile` as a tripwire). Rejected alternative: each adapter shipping a full `claude/context-engine.psd1` overlay — zero installer code but seven near-identical copies of the core config drifting independently. The commands-table idea from the original contract draft was dropped: `{{COMMANDS_TABLE}}` stays purely skill-owned (the skill verifies real commands against the repo; an adapter can't).

Two regenerators shipped as reference implementations: `csharp/regenerate-api-index.ps1` (deliberately lightweight regex scan for public type declarations — an orientation index, not a compiler; Roslyn upgrade is a per-project option) and `powershell-module/regenerate-function-index.ps1` (AST walk, top-level functions only, `Internal-/Private-/Helper-` marked internal). Electron/python ship none — no reliably derivable index without knowing the project's registry/export shape.

Implementation gotcha encoded in both regenerators: inside a **method-argument** hashtable literal (`$list.Add([pscustomobject]@{ ... })`), values parse in expression mode, so a bare `expr -replace 'a', 'b'` misparses at the comma — parenthesize the value. The same construct in a standalone hashtable statement parses fine, which is why it slips past review.

**Conventions guide rather than lock in (2026-09-29).** An agent that treats a recommended library or layout as law refuses reasonable project choices, so every statement in a convention seed is one of three kinds: a *platform fact* (what the language, framework, or platform does at the project's version), a *guardrail* (a security or correctness rule; deviating needs an ADR), or a *default* (a recommended starting choice, marked **Default:**, that the project changes whenever it has a reason). Every conventions README, core's included, carries this legend and a deviation protocol, and `CLAUDE.md` `@`-imports that README, so every session reads it. Path-scoped rules in `.claude/rules/` carry only facts and guardrails, because they load automatically and read as orders; where a rule has to mention a default, it phrases it conditionally. The browser-extension family introduced the scheme and the other adapters adopted it in the next release.

## Consequences

### Positive

- Identical process contract in every repo; engine fixes propagate via one script run per repo.
- New-project setup drops to minutes: one skill invocation, one interview, one restart.
- Stack-specific behavior is additive (adapters + config), so new stacks (C++, etc.) cost an afternoon each.

### Negative

- Two-place maintenance: improvements discovered in a project must be upstreamed here to benefit others (the origin repo's own `Context/` remains its independent, richer instance — reconciling it onto the engine is optional future work).
- Hard dependency on pwsh 7+ and Claude Code conventions (`.claude/` layout, hook JSON shape); harness changes require engine releases.
- Engine-owned files must stay hand-edit-free in projects — a discipline rule, enforced only by ownership headers and update-time diffs.

## Alternatives considered

- **Skill-only / script-only** — rejected above (drift / empty-cabinet).
- **`dotnet new` template or npm initializer** — rejected: ties a stack-agnostic system to one stack's toolchain; PS7 is the one runtime guaranteed on all maintainer machines.
- **Git submodule / subtree of a shared `Context/` process** — rejected: submodules complicate every clone and can't express per-project token substitution; copies + an updater are simpler and offline-friendly.
- **Symlinked shared `.claude/`** — rejected: breaks repo portability and versioning atomicity.

## Phase plan

| Phase | Scope | Exit criterion |
| ----- | ----- | -------------- |
| 0 | Harvest & genericize — **shipped 2026-07-29** | `templates/core/` complete, de-FM'd, tokenized; this design doc |
| 1 | Installer + updater — **shipped 2026-07-30** | Met: throwaway repo scaffolds green (14/14 content checks), `-Verify` clean, settings merge proven against a pre-existing settings.json (permissions + prior hook preserved, re-merge no-op), both hooks live-fired in an installed target, updater exercised across all five states incl. sticky ModifiedSkip and `-Force` |
| 2 | `/fm-init-context-engine` skill — **shipped 2026-07-30** | Met via full simulation on a throwaway C# repo: install → authoring pass resolved all 10 skill-token sites → `-Verify` clean on both token classes → session-start briefing renders the authored roadmap → commit-msg hook actively rejects an AI trailer. Skill installed user-level and discoverable. |
| 3 | Adapters — **shipped 2026-07-30** (all seven) | Met: every adapter installs green over core (41/42 matrix + regex-artifact re-checks; the 1 real failure was a regenerator parse bug, fixed), winui3 `Inherits` chain proven (parent files + inherited Regenerators + child Watches override), both regenerators live-fired against real source, spliced configs parse |
| 4 | Update machinery + dogfood | Engine initialized into a real project (candidate: ICOConverter at its design gate, or SvgExplorer reconciliation); one round-trip `Update-ContextEngine.ps1` proven |

## Open questions

- Should the origin repo (`powershell-fmdevtoolbox`) itself be reconciled onto engine-owned files via `Update-ContextEngine.ps1`, or left as the independent ancestor? (Leaning: reconcile hooks/commands only, after Phase 4 proves the updater.)
- Whether to seed the Claude Code auto-memory directory per project — currently out of scope: it's harness-managed and not repo-portable.
- ~~Version scheme for `EngineVersion`~~ — **decided in Phase 1:** date stamp (`YYYY.MM.DD`) read from the repo-root `VERSION` file; bumped manually when templates change in a way projects should pull. A second release on the same day appends a counter (`YYYY.MM.DD.N`), which still orders correctly as a `[version]`.
