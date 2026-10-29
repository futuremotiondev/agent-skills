---
name: fm-init-context-engine
description: Use when the user wants to set up, initialize, or scaffold the context engine in a repository — cues like "init the context engine", "set up the context system", "scaffold project memory", "give this repo the CLAUDE.md + Context/ setup", or an explicit /fm-init-context-engine invocation, optionally with arguments naming the stack, project, and a freeform brief (e.g. "/fm-init-context-engine electron" or "/fm-init-context-engine winui3 MyApp using CommunityToolkit.Mvvm, unpackaged deployment" — essential for empty repos where nothing is detectable yet; the brief pre-answers interview questions). Also use to FINISH a partial install (a repo that has .claude/context-engine-manifest.json but still shows {{TOKEN}} placeholders in CLAUDE.md or Context/), and to REFRESH an installed repo's conventions, rules, and seeded docs from a newer engine — cues like "refresh the context engine", "update the conventions from the engine", "pull the new stack templates", or "/fm-init-context-engine refresh".
---

# fm-init-context-engine

Initialize the context engine — the `Context/` knowledge tree plus the `.claude/` automation layer — into the current repository, then author the project-specific content the scaffolder cannot write.

**Engine root:** this skill bundles the engine repo at `references/fm-context-engine-scaffold` inside its own folder. Resolve that against this skill's **base directory** (announced when this skill loads) and call the absolute result `<engine>` — every path and script invocation below uses it. Always compose the absolute path before running commands; never pass the relative form to a shell, because the working directory is the target repo, not the skill folder. If the folder is missing (an unbundled copy of this skill), ask the user where the context-engine repo lives before doing anything else. Read the engine's `docs/DESIGN.md` if you need the rationale behind any rule here.

**Division of labor (the system's core principle):** the scaffolder (`Install-ContextEngine.ps1`) deterministically owns file structure and installer-owned tokens; **you** own the interview and the content only a project analysis can produce — the skill-owned tokens, the roadmap, the architecture seed, the watch config. Never hand-replicate what the scaffolder does.

## Arguments

The invocation may carry arguments: `/fm-init-context-engine [<stack>] [<project name>] [<freeform project brief>]`.

- **First argument `refresh`** (not a stack name) selects **Refresh mode** for an installed repo; nothing else applies. An optional second argument names the stack for an install that predates recorded stacks.
- **First argument = stack adapter name** (case-insensitive; `none` is valid). Validate it against the directories under `<engine>\templates\stacks\`; on no match, list the available adapters and ask rather than guessing. A valid stack argument is the user's declared intent:
  - **Empty repo** — this fully resolves stack selection; skip the detection probe in step 2 (there is nothing to detect) and proceed. This is the intended way to scaffold a project *before any code exists*: `/fm-init-context-engine electron` in a fresh directory.
  - **Non-empty repo** — still run the detection probe as a sanity check. If detection contradicts the argument (e.g. the argument says `electron` but the repo is full of `.csproj`), surface the conflict and let the user decide; otherwise the argument stands without re-asking.
- **Second argument (optional) = project display name**, passed through as the installer's `-ProjectName`. A quoted multi-word name is fine — it's display-only (titles, the ADR's context sentence), never a path or identifier.
- **Everything after the name (optional) = freeform project brief.** Treat it as pre-supplied interview answers, sentence by sentence. Examples: `/fm-init-context-engine winui3 "My App Name" using CommunityToolkit.Mvvm and the Windows Community Toolkit controls, unpackaged deployment, MVVM strict`. Handling rules:
  - A fact the brief states is **user-stated evidence** — it may seed `{{DEPENDENCIES}}`, Do/Do-not bullets, the roadmap, and the description without re-asking in step 4. Skip every interview question the brief already answers; ask only what's still missing.
  - Named libraries/frameworks (a UI component library, an MVVM toolkit, a test framework) go into `{{DEPENDENCIES}}` and, where they imply a working rule ("MVVM strict" → a Do bullet), into the rules — quoting the user's intent, not inventing beyond it.
  - The brief supplements the stack adapter's seeds; it never replaces them. If the brief contradicts an adapter seed (e.g. "no MVVM" vs the winui3 seed's MVVM section), flag it and edit the seeded convention doc to match the user — the seeds are project-owned starting points.
- **No arguments** — the default flow: detect in step 2, confirm with the user.

An empty repo initialized by stack argument still gets the full authoring pass — the interview (step 4) carries whatever weight the brief didn't, since there is no code to observe, and the architecture seed doc is skipped until real structure exists.

## Mode selection (do this first)

Check the target repo's state and pick exactly one mode:

| Repo state | Mode |
| ---------- | ---- |
| No `Context/`, no `CLAUDE.md`, no `.claude/context-engine-manifest.json` | **Full init** — steps 1–7 |
| Manifest exists AND `Install-ContextEngine.ps1 -Verify` reports skill-owned tokens | **Authoring-only** — steps 4–7 (a script-only install was done earlier; do not reinstall) |
| Manifest exists, `-Verify` clean, and the user asks to refresh or update the engine or its conventions (or passed `refresh`) | **Refresh** — the Refresh mode section below |
| Manifest exists, `-Verify` fully clean, no refresh asked | Nothing to init. If `<engine>\VERSION` is newer than the manifest's `engineVersion`, offer Refresh mode; otherwise stop. |
| `Context/` or `CLAUDE.md` exist **without** a manifest | A pre-existing, hand-rolled context system. **Do not overwrite.** Present the options — (a) leave it alone, (b) manual reconciliation (user-guided, file by file), (c) `-Force` reinstall (destructive, explicit confirmation required) — and stop unless the user picks one. |

## Step 1 — Preflight

1. Confirm `pwsh` 7.1+ is available (the engine scripts `#Requires` it).
2. Confirm the target is a git repository. If not, ask the user whether to initialize one — pass `-InitGit` to the installer only after they confirm.
3. Note the current branch and whether the repo has any commits (affects `MainBranch` detection).

## Step 2 — Detect the stack

Probe the repo and classify:

| Marker | Stack adapter |
| ------ | ------------- |
| `*.psd1` module manifest + a `Public/` function tree | `powershell-module` |
| `.csproj`/`.slnx`/`.sln` + `Microsoft.WindowsAppSDK` package ref | `winui3` |
| `.csproj` + `<UseWPF>true</UseWPF>` | `wpf` |
| `.csproj` + `Avalonia` package refs | `avalonia` |
| `.csproj`, none of the above | `csharp` |
| `manifest.json` declaring `manifest_version` (or a `wxt.config.*`) whose only target is **Firefox**: `browser_specific_settings.gecko` present, a `background.scripts` without `service_worker`, no `minimum_chrome_version`; or WXT with `targetBrowsers: ['firefox']` / only `-b firefox` scripts | `firefox-extension` |
| Same markers, only target **Chrome**: `background.service_worker` without `scripts`, no `browser_specific_settings`; or WXT with no Firefox target in its config or scripts | `chrome-extension` |
| Same markers, **both** targets or undecided: both background shapes, per-target manifests, WXT scripts for both browsers, or signals too thin to call | `browser-extension` (the neutral base; when unsure, ask, and in a non-interactive run choose this one) |
| `manifest.json` declaring `editorType` and `api`, with **no** `manifest_version` | `figma-plugin` (same filename as a WebExtension manifest, unrelated format — read the keys, don't guess from the name) |
| `manifest.json` declaring `id` and `minAppVersion`, with **no** `manifest_version`, `editorType`, or `api`; usually alongside `versions.json` and an `obsidian` dependency in `package.json` | `obsidian-plugin` (a theme's manifest has no `id` and is not a plugin) |
| `next.config.*` | `nextjs` |
| `astro.config.*` | `astro` |
| `nuxt.config.*` or `svelte.config.*` | `web` — no overlay ships for these yet; the base's route regenerator already understands both conventions |
| `index.html` / `*.scss` with no framework config, or `vite.config.*` with a client-only app | `web` |
| `package.json` with an `electron` dependency | `electron` |
| `package.json` + `tsconfig.json`, none of the above | `typescript` |
| `package.json` with neither TypeScript nor a framework marker | no adapter — pass `-Stack None`; detection still informs authoring |
| `pyproject.toml` / `setup.py` | `python` |
| `CMakeLists.txt` at the repo root + `.cpp`/`.h` sources | `cpp` (assumes CMake; the compiler / generator / package manager are interview facts, not adapter variants) |
| `Cargo.toml` at the repo root with `[package]` or `[workspace]` | `rust` (if a root `CMakeLists.txt` is also present, the language that owns the deliverable wins — see Secondary languages below) |
| An empty repo (project not started) | use the stack argument if one was passed (see Arguments); otherwise ask the user what it will be |

Check the `manifest.json` rows (the three extension rows, `figma-plugin`, `obsidian-plugin`) **before** the `package.json` rows, because those repos have both. A brief that names the browser ("a Firefox extension") or the host ("an Obsidian plugin") settles the choice.

State your detection and let the user confirm or override — a repo can be ambiguous (e.g. a C# solution with a JS tool subfolder). The authoritative adapter list is the directories under `<engine>\templates\stacks\`; check it rather than trusting this table blindly (new adapters may exist). If nothing fits, pass `-Stack None` — the core install is complete on its own.

**Secondary languages.** The installer takes exactly one `-Stack`; pick the adapter for the language that owns the deliverable (the app or the published library). Other languages present in the repo — a `Cargo.toml` (Rust) building a DLL the app consumes, a `package.json` for tooling, a `pyproject.toml` for scripts — are handled in the authoring pass, not by a second adapter. Record what you detect and, in steps 4–6: add `MarkDirty` watches for the secondary sources (`**/*.rs` + `Cargo.toml`, etc.), put its build command in `{{COMMANDS_TABLE}}`, note its toolchain in `{{DEPENDENCIES}}`, and — if the primary adapter's convention seed has a foreign-language boundary section (`cpp-style.md` and `rust-style.md` do) — fill it with the specifics: which side owns the boundary header, where the artifact lands, and which toolchain must match.

**What an adapter contributes** (so you don't duplicate it in later steps): convention seed docs (+ an updated `Context/conventions/README.md` index), path-scoped `.claude/rules/` seeds, optionally a `Context/scripts/` regenerator, and config defaults spliced into `.claude/context-engine.psd1` — `Watches`, `Regenerators`, `DirtyHint`, and a resolved `PublicSurface` (so that token may already be gone after install). Adapters with `Inherits` install the parent's files first, and chains can be any depth: winui3/wpf/avalonia → csharp; electron/browser-extension/figma-plugin/obsidian-plugin/web → typescript; firefox-extension/chrome-extension → browser-extension → typescript; nextjs/astro → web → typescript.

## Step 3 — Run the installer

```powershell
& "<engine>\Install-ContextEngine.ps1" -TargetPath <repo> -Stack <adapter|None> -ProjectName '<name>' [-InitGit]
```

- `ProjectName` = the display name the user actually calls the project (ask if the folder name looks like a slug).
- Expect exit 0 and a "Files written" report. A nonzero exit or a leftover-token table is a hard stop — diagnose before continuing; do not paper over it.
- Do not pass `-Force` unless the user explicitly chose the destructive reinstall path in mode selection.

## Step 4 — Interview (one batched round, not a drip)

Ask everything in a single round; skip any item the user already answered in conversation. Offer your detected/proposed values as defaults so confirming is cheap:

1. **Purpose** — what is this project, in 1–3 sentences? (seeds `{{PROJECT_DESCRIPTION}}`)
2. **Driving design principle** — the one-sentence tiebreaker for close calls (seeds the roadmap's strategic direction; the same concept the spec template calls "top-level design principle").
3. **Build / test / run commands** — propose what you detected (`package.json` scripts, `dotnet build/test` on the found solution, `Invoke-Pester`, ...); the user corrects.
4. **Public surface** — if an adapter already baked a `PublicSurface` default into `.claude/context-engine.psd1`, offer *that* for confirmation; otherwise propose a stack-informed one-sentence definition (exported functions / published API types / IPC channels + preload exports / package `__init__` exports); the user corrects. (drives context-keeper Operation A)
5. **Known Do / Do-nots** — any hard rules they already know they want enforced.
6. **Initial roadmap** — strategic direction (1–5 numbered commitments) and what they're building first.
7. **Toolchain layers** (only for adapters whose convention seed has a Toolchain section — `cpp`, `rust`, `web` and its overlays, `figma-plugin`, `obsidian-plugin`, and the extension family) — propose what you detected; the user corrects. (seeds `{{TOOLCHAIN}}`)
   - `cpp`: compiler, standard library, generator + executor, package manager, C++ standard. Detect from `CMakePresets.json` generator/toolchain entries, `vcpkg.json` / `conanfile.*`, `CMAKE_CXX_STANDARD` in `CMakeLists.txt`, an installed Visual Studio Build Tools.
   - `rust`: channel + pinned version, target triple, edition. Detect from `rust-toolchain.toml`, `.cargo/config.toml` (`[build] target`), and `Cargo.toml` (`edition`); the target triple matters most when another language consumes the crate (MSVC vs GNU on Windows).
   - `web` (and its overlays): framework + major version, UI library, styling approach, build tooling + runtime, package manager, and **hosting target** (static host / Node server / serverless / edge). Detect from the framework config, `package.json`, and any deploy config. The hosting target is load-bearing: it decides whether long-lived server state is possible and what a cold start costs.
   - `figma-plugin`: editor types, Plugin API version, `documentAccess`, typings package, build tooling, package manager. Detect from `manifest.json` (`editorType`, `api`, `documentAccess`) and `package.json` (`@figma/plugin-typings`, `@figma/widget-typings`). Flag two things at authoring time if the manifest shows them: a missing `documentAccess: "dynamic-page"` (required, and it changes which APIs are legal) and the unsupported `dev` + `figjam` editor-type pairing.
   - `obsidian-plugin`: the **release channel** and floor, platforms (desktop and mobile, or desktop only), typings (`obsidian` package version), build tooling, lint, tests, package manager, and distribution (Community directory, BRAT betas, private).
     - **Channel — public or Early access.** The adapter lists both, with reference floors, in its `adapter.psd1` under `Channels`; read the current numbers there, not from this skill. The public channel (the `Default`) reaches every user. An Early access floor installs only for Catalyst users until that minor goes public. A brief pre-answers it: "public" or "stable" means public; "Early access", "Catalyst", or "insider" means early-access. A version in the brief (for example "1.14+") picks whichever channel's floor it matches; if that is Early access, say that public users cannot install until the minor goes public, and confirm. In a non-interactive run, use `Default` and mark it `<!-- TODO: confirm with maintainer -->`.
     - **Record it** as Channel and Floor rows in the Toolchain table. The floor the code ships with is `minAppVersion` in `manifest.json`: if one exists and differs from the chosen floor, surface the difference and let the user decide. Changing it is a release decision (the style document's "Changing channel or raising the floor" checklist), not an authoring step, so do not edit the manifest during init. A floor the user states explicitly wins over the reference floor.
     - **Detect** from `manifest.json` (`minAppVersion`, `isDesktopOnly`), `versions.json`, `package.json` (`obsidian`, `eslint-plugin-obsidianmd`, `esbuild`, `vitest`, `obsidian-test-mocks`, `wdio-obsidian-service`), and the release workflow under `.github/workflows/`.
     - Flag at authoring time: an `id` that breaks the manifest naming rules (it cannot change after publishing), and Node or Electron imports in a plugin whose `isDesktopOnly` is `false`.
   - **Extension family** (`browser-extension`, `firefox-extension`, `chrome-extension`): the **release channel**, target browsers **with minimum versions**, build tooling, typings, test runners, package manager, and distribution (AMO listed / unlisted / self-hosted; Chrome Web Store public / unlisted / private).
     - **Channel — latest or enterprise.** Each single-browser adapter lists its channels and reference floors in its `adapter.psd1` under `Channels` (Firefox: `release` / `esr`; Chrome: `stable` / `extended`) — read the current numbers there, not from this skill. The latest channel excludes enterprise users on ESR / Extended Stable; the enterprise channel keeps them but gates newer features. A brief pre-answers it: "latest", "release", or "stable" means latest; "enterprise", "ESR", "Extended Stable", or "managed" means enterprise. Otherwise default to the adapter's `Default` channel (in a non-interactive run, use it and mark it `<!-- TODO: confirm with maintainer -->`).
     - **Record it as data.** Set `Channel` and `MinVersion` in `Context/scripts/extension-targets.psd1` from the adapter's `Channels` table — for `browser-extension`, one entry per target browser, read from the two single-browser adapters — and add a Channel row to the Toolchain table; keep the two identical. A floor the user states explicitly wins over the reference floor.
     - **Detect** from `manifest.json` (`minimum_chrome_version`, `browser_specific_settings.gecko.strict_min_version`), `wxt.config.*` (`targetBrowsers`, `manifestVersion`, the `manifest` config), and the `package.json` scripts. An existing manifest floor equal to an enterprise reference floor is a strong hint for that channel.
     - **Firefox also needs:** whether Android is a target (`gecko_android`), and what data leaves the browser (`data_collection_permissions`).
     - No floor at or above Chrome 148 needs `webextension-polyfill` (archived in 2026); below 148, the documented guard is `globalThis.browser ??= chrome`.

If the session is non-interactive and answers are unavailable, author conservatively from observation alone, mark every inference with `<!-- TODO: confirm with maintainer -->`, and say so in the handoff. Never block a non-interactive run on questions.

## Step 5 — Analyze + author

**Read the codebase before writing anything** — the directory layout, the build files, existing docs/README, a sample of source files. Authored content must describe what is actually there.

Then resolve every skill-owned token. `Install-ContextEngine.ps1 -Verify` lists the outstanding sites; work through them:

| Token | File | What to write |
| ----- | ---- | ------------- |
| `{{PROJECT_DESCRIPTION}}` | `CLAUDE.md` | 1–3 sentences from the interview, grounded in what you observed |
| `{{COMMANDS_TABLE}}` | `CLAUDE.md` | `\| Task \| Command \|` rows for build / test / run / lint — **verify each command exists** before writing it |
| `{{DO_LIST}}` / `{{DONT_LIST}}` | `CLAUDE.md` | Short universal rules (5–10 bullets each max) — the summary tier |
| `{{DO_RULES}}` / `{{DONT_RULES}}` | `Context/conventions/agent-rules.md` | The canonical list — a superset of (and consistent with) CLAUDE.md's; remove the seeding HTML comment |
| `{{DEPENDENCIES}}` | `CLAUDE.md` | Toolchain + minimum versions actually required (SDK, runtime, package manager) |
| `{{STRATEGIC_DIRECTION}}` | `Context/roadmap/current.md` | Numbered commitments from the interview |
| `{{ACTIVE_WORK}}` | `Context/roadmap/current.md` | The first real work item(s), or `_(nothing in flight yet)_` for a fresh project |
| `{{PUBLIC_SURFACE}}` | `.claude/context-engine.psd1` | The confirmed one-sentence definition |
| `{{TOOLCHAIN}}` | the adapter's `Context/conventions/<stack>-style.md` | (only where the seed has a Toolchain section: `cpp-style.md`, `rust-style.md`, `browser-extension-style.md` (installed by all three extension stacks), `figma-plugin-style.md`, `obsidian-plugin-style.md`, `web-style.md`) A table with one row per toolchain layer from interview item 7; remove the seeding HTML comment |

Rules while authoring:

- **Only write Do/Do-nots that were observed in the code or stated by the user.** An empty-but-honest rules list beats an invented one — rules accrete as the project lives.
- **Keep seeded defaults out of the Do lists.** Convention seeds mark recommended choices **Default:**, and each conventions README explains facts, guardrails, and defaults. The Do/Do-not lists and `.claude/rules/` load every session and read as orders, so a seeded default goes there only when the user confirms it as a binding project decision.
- Update the roadmap's `_Last refreshed:_` line to today and clear placeholder bullets you replaced.
- Seed **one architecture doc**: `Context/architecture/<slug>-layout.md` describing the observed top-level layout and each directory's role, with `last_verified: <today>` frontmatter. Add its row to `Context/architecture/README.md`'s table AND `Context/README.md`'s Architecture section — a doc nobody can find is a doc nobody reads. For an empty repo, skip this (nothing to observe).
- If the interview surfaced project-specific consequences of adopting the engine (e.g. "hooks require pwsh which this Node team doesn't otherwise use"), append them to ADR-0001's Consequences — extending the seeded ADR is allowed at init time; it is not yet frozen history.

## Step 6 — Wire the automation config

Edit `.claude/context-engine.psd1`:

- **`Watches`** — an adapter may have seeded defaults; adjust their globs to the project's real source roots (adapter globs are conservative `**` patterns) and confirm the actions fit. Where authoring fresh: a fast refresh (`Action='Run'`) only when a cheap, quiet command keeps something in sync (a manifest, a generated index); a `MarkDirty` for slow rebuilds (C# assemblies, native builds). **An empty Watches list is a valid answer** — don't invent busywork automation. Glob semantics: anchored repo-relative, `**` spans directories, `*` stays in one segment.
- **`Regenerators`** — adapters seed these where reliable (csharp's `regenerate-api-index.ps1`, powershell-module's `regenerate-function-index.ps1`); otherwise leave empty unless the project already has a script honoring `Context/scripts/README.md`'s contract.
- **`DirtyHint`** — set when `MarkDirty` watches exist, naming the exact command to run (e.g. `'Run dotnet build src/Foo.slnx to rebuild, then delete .claude/.dirty-marker.'`).
- **Extension family** — confirm `Context/scripts/extension-targets.psd1` matches the Toolchain table (browser, channel, floor) before the first `/refresh-context`; the manifest index scopes its checks by it.
- If you added any regenerator, run it once so `Context/generated/` has a first artifact, and list it in `Context/generated/README.md`.

## Step 7 — Verify + handoff

1. Run `& "<engine>\Install-ContextEngine.ps1" -TargetPath <repo> -Verify` — it must report **zero** leftover tokens of both classes. If skill tokens remain, you missed an authoring site; finish it.
2. Run `git config core.hooksPath .githooks` in the target (safe, local-only) so the commit-msg policy hook is active.
3. Hand off with, verbatim in substance:
   - **Restart Claude Code in this repo** — hooks, slash commands, and the `context-keeper` skill load at session start only; nothing is live until restart.
   - What was authored and what was inferred (flag every `TODO: confirm` you left).
   - First-week checklist: add real items to `Context/roadmap/current.md` as they emerge; capture the first gotcha in `Context/insights/_inbox/`; run `/state-of-project` at the start of a session to see the loop working; skim `Context/USAGE.md` once.

Committing the scaffold is the user's call — offer a `chore: initialize context engine` commit, don't make it unasked.

## Refresh mode

Brings an installed repo's seeded files (convention docs, rules, regenerators, `CLAUDE.md`, the `Context/` skeleton, the adapter defaults in `.claude/context-engine.psd1`) up to the engine's current templates without losing what the project changed. The updater does the deterministic part — a Copier-style three-way merge against the install-time baselines; you do the judgment.

1. **Preflight.**
   - The working tree must be clean (the updater refuses otherwise, so the refresh is one reviewable diff). Suggest a branch such as `chore/context-engine-refresh`.
   - If the manifest has no `stack` (schema 1, installed before 2026-09-29), infer it from the installed seeds (for example `electron-style.md` plus `.claude/rules/electron-boundaries.md` → `electron`; `typescript-style.md` alone → `typescript`), confirm it with the user, and pass `-Stack`. Passing a different stack to a newer install re-stacks it (for example `browser-extension` → `firefox-extension`).
2. **Plan.** Run `& "<engine>\Update-ContextEngine.ps1" -TargetPath <repo> -RefreshSeeds -WhatIf` (plus `-Stack` if needed). Show the user the seed states, the engine changelog entries since the last refresh with their Detect hits, and any advisories.
3. **Apply.** Run the same command without `-WhatIf`. Engine-owned files and seeds update together. What the updater did not write is in `.claude/context-engine/incoming/`, listed in `refresh-report.md` there; read it next.
4. **Review and resolve**, file by file:
   - **Merged** (already written): read the diff. A clean textual merge can still pair a project's changed default with an engine sentence that assumed the old one.
   - **Conflict:** resolve the project file from `<path>.merge` (diff3: project / baseline / engine) and `<path>.new`. A conflict can also mean the merge would restore a `{{TOKEN}}` the project had filled.
   - **Proposed** (`CLAUDE.md`, `agent-rules.md`, decision data such as `extension-targets.psd1`): apply what fits from `<path>.diff` by hand, or nothing.
   - **Legacy** (no baseline yet, the first refresh of an old install): compare the project file with `<path>.new` two-way, guided by the changelog entries.
   - **ConfigConflict:** settle the key in `.claude/context-engine.psd1`.
   - **UpstreamRemoved, DeletedByProject, Excluded:** informational; mention them.

   Precedence, in order: (1) the engine's platform facts win — they are corrections; (2) project decisions win — deviations from defaults, guardrail exceptions backed by an ADR, the filled Toolchain table, edited rule globs, sections the project added; (3) if the engine changed a guardrail the project had deviated from, ask the user; (4) never reintroduce content the engine removed as deprecated, and never drop a section the project added.
5. **Complete.** Run `Update-ContextEngine.ps1 -TargetPath <repo> -CompleteRefresh`. It records the new baseline for every resolved item; a file that still holds conflict markers stays pending (exit 1). Repeat until it exits 0.
6. **Code impact.** Walk the Detect hits: fix trivial ones with the user's confirmation; otherwise create a spec with `/new-spec` (`<date>-convention-refresh`) holding a checklist per changelog entry. Record a guardrail change the project adopts or rejects with `/new-adr`.
7. **Advisories.** Present release-channel floor advisories. Apply one only when the user asks, following the stack's "Changing channel or raising the floor" checklist. `obsidian-plugin` gets no advisory line: a moved reference floor arrives as a changelog **Floor** entry whose Detect hit is the project's `minAppVersion`, handled the same way.
8. **Finish.** Run `/refresh-context` (regenerators may have changed), `Install-ContextEngine.ps1 -Verify`, and `/doctor prompt-audit` where the Claude Code version has it (a new rule can contradict a project rule). Offer a `chore(context): refresh context engine to <version>` commit, and remind the user to restart Claude Code.

## Never do

- Overwrite an existing `CLAUDE.md` or `Context/` tree without explicit confirmation — a request for init is not a request to destroy a predecessor system.
- Invent Do/Do-nots, commands, or dependencies that were neither observed in the repo nor stated by the user.
- Leave any `{{TOKEN}}` unresolved at handoff (step 7's verify is the gate).
- Hand-edit engine-owned files (`.claude/hooks/`, `.claude/commands/`, `.claude/skills/context-keeper/`, `.githooks/commit-msg`) — improvements go to the engine repo, then `Update-ContextEngine.ps1`.
- Touch the install records: `.claude/context-engine-manifest.json` or anything under `.claude/context-engine/`. The `baseline/*.base` snapshots are the pre-authoring originals a later refresh merges against, so they are *supposed* to still contain `{{TOKEN}}`s — never "fix" them, and never mistake them for the files to author.
- Replicate the installer's work by hand (copying templates, substituting installer tokens) — if the installer fails, fix the cause and rerun it.
- Finish a refresh by hand-editing baselines or the manifest, or by deleting `pending.json` — `-CompleteRefresh` records baselines; an item it keeps pending is not resolved yet.
- Create the architecture doc without adding it to both parent indexes.
- End without the restart reminder.

## Red flags — STOP and reconsider

- About to run the installer with `-Force`? STOP — only the user chooses destruction.
- Writing a Do/Do-not you can't point to evidence for? STOP — leave it out.
- The commands table contains a command you didn't verify runs (or at least exists)? STOP — check it.
- Adding a `Run` watch that takes more than a few seconds? STOP — that's a `MarkDirty`.
- About to ask a fourth round of questions? STOP — batch, or proceed with marked inferences.
