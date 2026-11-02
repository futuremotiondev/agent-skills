# Refreshing the Stack Templates

Platform facts go stale. Chrome and Firefox both release every two weeks, stores change their policies, and tools change their defaults. This runbook keeps the engine's templates current, so that projects can then pull the corrections with a seed refresh (`/fm-init-context-engine refresh`, which runs `Update-ContextEngine.ps1 -RefreshSeeds`).

There are two refreshes, and this document covers the first:

1. **Template refresh (here):** update an adapter in this engine, record what changed in `CHANGELOG.md`, and release a new `VERSION`.
2. **Seed refresh (in each project):** merge the new templates into a project's seeded files. `Context/USAGE.md` in any installed project and the skill's Refresh mode describe it.

## When to refresh

| Stack | Cadence |
| ----- | ------- |
| `browser-extension`, `firefox-extension`, `chrome-extension` | Monthly: both browsers release every two weeks, and reference floors move with them |
| `obsidian-plugin` | Monthly: an Early access minor goes public within weeks (the reference floors move with it), and the Community directory's review rules and `eslint-plugin-obsidianmd` (0.x) still change often |
| Every other stack | Quarterly |
| Any stack | Straight away after a store or platform deadline, a breaking release of a tool the docs name, a floor change, or a project finding a fact wrong |

A scheduled routine can run the monthly check and report, but it must not edit anything: the report is the trigger for a refresh, not the refresh.

## The request

Ask Claude Code, in the skills repo: "Refresh the `chrome-extension` stack per `docs/REFRESHING-STACKS.md`." Claude then follows the procedure below.

## Procedure

1. **Read the sources.** Each `adapter.psd1` lists `Sources` (the authoritative pages to re-read) and `RefreshChecks` (the known time bombs to check every time). Answer every check, and note the date and source of each finding. For an overlay, also check its parent's sources for anything the overlay repeats.
2. **Change what moved.**
   - Platform facts, version tables, and version-gated rows in the convention docs and rules.
   - Reference floors in `Channels` (the extension family and `obsidian-plugin`), and the floors those documents quote. An `obsidian-plugin` floor move also needs a **Floor** changelog entry whose `Detect:` matches `minAppVersion`, because seed refreshes print floor advisories only for the extension family.
   - Regenerator fact tables (for example the unsupported-key tables in `regenerate-manifest-index.ps1`).
   - Defaults, only when the recommendation itself changed.
   Keep the three kinds of statement intact: a platform fact is plain, a guardrail is an imperative with an ADR exception path, and a default is marked **Default:**. Rules in `claude/rules/` carry no defaults. Prefer editing a file in place to renaming it: a renamed or removed seed reaches projects as `UpstreamRemoved` (left in place and no longer tracked), and a new one as `New`.
3. **Record it in `CHANGELOG.md`.** Add a `## <new version>` section with a `### <adapter>` (or `### core`) heading per scope, and one bullet per change (format below).
4. **Verify.**
   - Every stack installs and `Install-ContextEngine.ps1 -Verify` reports no installer tokens.
   - markdownlint is clean on the changed documents (MD013 excepted).
   - The regenerator fixtures still pass (extension stacks: the manifest index against a sample manifest per target; `obsidian-plugin`: a well-formed plugin reports no findings, a broken one trips every check, and WebExtension and Figma manifests are skipped).
   - A project installed from the previous engine refreshes as expected: `-RefreshSeeds -WhatIf` shows the states you intended, and each `Detect:` pattern finds its fixture code.
5. **Ship.** Bump `VERSION`, commit, redeploy the skill to `~/.claude/skills` (only `fm-init-context-engine`), then refresh the consuming projects.

## Versions

`VERSION` is a date stamp, `YYYY.MM.DD`. A second release on the same day appends a counter, `YYYY.MM.DD.N`, which still orders correctly. The refresh compares versions to pick changelog entries, so never reuse or lower one.

## Writing changelog entries

```markdown
## 2026.11.03

### chrome-extension

- **Fact:** Chrome finished rolling out Promise-returning `runtime.onMessage` listeners; the "rolling out gradually" caveat is gone.
  - Impact: optional simplification; the dispatcher may return the handler's promise instead of calling `sendResponse`.
  - Detect: `return true; // keep the channel open`
```

- **Kinds:** Fact (a correction or new platform fact), Deprecation (a platform removal; code impact likely), Guardrail (a security or correctness rule changed), Default (a recommended choice changed), Floor (a release-channel reference floor moved), Structure (a file added, renamed, or removed).
- **Impact** says what a project may need to do in its code or decisions, or "none".
- **Detect** is a .NET regular expression that the refresh runs line by line over the project's git-tracked source (never `Context/`, `.claude/`, dependencies, or build output). It should match code the change affects, not prose. Keep it narrow: every hit is a location someone reviews. Test it with `Select-String -Pattern '<regex>'` against sample code. An entry can have several Detect lines, or none.

A project sees an entry when its version is newer than the project's last refresh and its scope is `core` or an adapter in the project's chain.

## Seed policies

How a refresh treats each seeded file is set in `lib/common.ps1` (`$SeedPolicies`): Merge (three-way, the default), Propose (never written, offered as a diff: `CLAUDE.md`, `agent-rules.md`, decision data such as `Context/scripts/*.psd1`), Config (`.claude/context-engine.psd1`, merged key by key), and Skip (ADRs, the roadmap, specs, insights, architecture, generated output). An adapter adds its own with `SeedPolicy = @( @{ Glob = '<path glob>'; Policy = 'Propose' } )` in `adapter.psd1`, checked before the core table. Give a new seed a policy if Merge would be wrong for it; a file that holds a project's decisions should be Propose.

## Adding refresh metadata to a new adapter

A new adapter should ship `Sources` and `RefreshChecks` from the start. Sources are the pages that would show a fact changing (release notes, migration guides, store policies). Checks are yes-or-no questions about the dated or version-bound claims its documents make.
