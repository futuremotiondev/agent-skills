# context-engine

A portable, stack-agnostic scaffold for the Futuremotion context management system — durable project memory (`Context/` tree) plus a Claude Code automation layer (`.claude/` hooks, slash commands, and the `context-keeper` agent skill), initializable into any new repository regardless of language or stack.

Extracted 2026-07-29 from the system proven in `powershell-fmdevtoolbox` (its ADR-0004). Full design rationale: [`docs/DESIGN.md`](docs/DESIGN.md).

## Status

| Phase | Deliverable | Status |
| ----- | ----------- | ------ |
| 0 | Harvest & genericize — `templates/core/` extracted, de-FM'd, tokenized | **Done** (2026-07-29) |
| 1 | `Install-ContextEngine.ps1` scaffolder + `Update-ContextEngine.ps1` | **Done** (2026-07-30) |
| 2 | `/fm-init-context-engine` user-level skill (interview + intelligence layer) | **Done** (2026-07-30) |
| 3 | Stack adapters — all seven (`csharp`, `winui3`, `wpf`, `avalonia`, `electron`, `python`, `powershell-module`) | **Done** (2026-07-30); `cpp` + `rust` + `typescript` bases plus `browser-extension`, `figma-plugin`, `web`, `nextjs`, `astro` added 2026-09-11; `firefox-extension` + `chrome-extension` added 2026-09-29 (`browser-extension` refactored into their browser-neutral base); `obsidian-plugin` added 2026-09-30 |
| 4 | Update machinery hardening + dogfood into a real project | **Verified** (2026-09-11): all five reconciliation states exercised against a copy of a real install (`electron-icon-explorer`, installed 2026-08-04). Fixed in the same pass: engine writes normalized to LF, `.gitattributes` pins shared by installer and updater. Idempotent across repeat runs. |
| 5 | Seed refresh: installed projects take template improvements | **Done** (2026-09-29): install-time baselines (manifest schema 2), `Update-ContextEngine.ps1 -RefreshSeeds` / `-CompleteRefresh`, `CHANGELOG.md` with Detect patterns, the skill's Refresh mode, and the [template refresh runbook](docs/REFRESHING-STACKS.md) |

## Layout

```text
context-engine/
├── README.md                    this file
├── VERSION                      engine version (date stamp) — stamped into installs
├── CHANGELOG.md                 what changed in the seeded templates, per version and stack (read by refreshes)
├── docs/DESIGN.md               founding design document — read this first
├── docs/REFRESHING-STACKS.md    maintainer runbook for keeping the stack templates current
├── Install-ContextEngine.ps1    deterministic scaffolder (copy + tokens + settings merge + manifest + baselines)
├── Update-ContextEngine.ps1     re-syncs engine-owned files; -RefreshSeeds merges template changes into seeds
├── lib/common.ps1               shared single-sources-of-truth for the entry scripts
├── templates/
│   ├── core/                    Layer A: stack-agnostic, copied into every project
│   │   ├── CLAUDE.md            tokenized CLAUDE.md skeleton
│   │   ├── Context/             the full Context/ tree (adr, specs, insights,
│   │   │                        roadmap, generated, scripts, conventions, architecture)
│   │   ├── claude/              → installs as .claude/ (commands, hooks, skill,
│   │   │                        context-engine.psd1 config, settings fragment)
│   │   └── githooks/            → installs as .githooks/ (commit-msg AI-trailer rejector)
│   └── stacks/                  Layer B: seventeen per-stack adapters (language bases + framework overlays) — see stacks/README.md
```

## How it is used

**Where the engine lives:** this folder is bundled inside the `fm-init-context-engine` skill at `references/fm-context-engine-scaffold`, and the skill folder is the unit that gets copied around. The canonical, version-controlled copy is the skill folder in the `futuremotion` skills repo; the working copy Claude Code loads is `~/.claude/skills/fm-init-context-engine/` (copied there by hand after edits). The skill's `SKILL.md` at the skill root is its only source — there is no second copy inside this folder. `<engine-root>` below means whichever copy you are invoking.

**Script-only:**

```powershell
<engine-root>\Install-ContextEngine.ps1 -TargetPath X:\my-new-app -Stack winui3 -ProjectName 'MyApp' -InitGit
# -Stack: csharp | winui3 | wpf | avalonia | typescript | electron | browser-extension | firefox-extension | chrome-extension | figma-plugin | obsidian-plugin | python | powershell-module | cpp | rust | web | nextjs | astro | None
# then: git config core.hooksPath .githooks; restart Claude Code;
# hand-fill the {{SKILL_TOKEN}} sites (Install-ContextEngine.ps1 -Verify lists them)
```

**With the `/fm-init-context-engine` user-level skill (copy the whole skill folder to `~/.claude/skills/`; re-copy after engine edits):**

1. In a new repo, run `/fm-init-context-engine`.
2. The skill detects the stack, runs `Install-ContextEngine.ps1 -Stack <profile>`, then interviews the maintainer and authors the project-specific content: `CLAUDE.md` values, `Context/roadmap/current.md`, `.claude/context-engine.psd1` watches/regenerators, and ADR-0001 extensions.
3. Restart Claude Code — hooks, commands, and the `context-keeper` skill are live.

**Later engine releases:** `Update-ContextEngine.ps1 -TargetPath <repo>` re-syncs **engine-owned** files only (hooks, commands, skill) via baseline-hash reconciliation; project-authored content is never touched, and hand-edited engine files are skipped with a warning (`-Force` to overwrite).

**Newer conventions for an existing project:** `/fm-init-context-engine refresh` (or `Update-ContextEngine.ps1 -RefreshSeeds`, then `-CompleteRefresh`) three-way merges the current templates into the project's seeded files against their install-time baselines: untouched files update, edited ones merge, conflicts and proposals wait in `.claude/context-engine/incoming/` for review, and the report lists the `CHANGELOG.md` entries since the last refresh with where the project's code matches them. See `docs/DESIGN.md`, "Seed refresh".

## Design invariants

- **Engine-owned vs project-owned is a hard boundary.** Scripts and commands carry no project values; all project values live in `.claude/context-engine.psd1` and the `Context/` content. That's what makes updates conflict-free.
- **PowerShell 7 everywhere.** One hook language across all stacks (C#, Electron, Python, ...); Node/Python projects are driven via `Run` commands in config, not per-stack hook forks.
- **Conventions guide; they don't lock in.** Seeded convention docs separate platform facts, guardrails, and marked defaults, and say how to deviate; path-scoped rules carry no defaults.
- **Determinism for structure, intelligence for content.** The scaffolder owns the ~40 process files; Claude owns the interview and the documents only a project analysis can write.
