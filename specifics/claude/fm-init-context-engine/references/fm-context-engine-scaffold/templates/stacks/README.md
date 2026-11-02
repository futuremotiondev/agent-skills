# Stack Adapters

Per-stack overlays applied on top of `templates/core/` by the installer (`-Stack <name>`). An adapter supplies the Layer-B values the core deliberately leaves abstract: what to watch, what to regenerate, which conventions to seed.

## Shipped adapters

Adapters form two tiers. A **language base** is a complete adapter for a plain library or package in that language and also the parent that framework overlays inherit from. A **framework overlay** inherits its language base (parent files first, child overrides same-path; config merged per key) and adds what the UI or runtime layer changes: extra watches, a narrower public surface, framework conventions. The directory listing is flat because `-Stack <name>` takes one bare name; the tiering lives in each overlay's `Inherits`.

### Language bases

| Adapter | For | Regenerator |
| ------- | --- | ----------- |
| `csharp/` | C# class libraries | `regenerate-api-index.ps1` (public-type scan) |
| `typescript/` | TypeScript libraries, tools, and Node packages; base for every TypeScript app adapter | — |
| `cpp/` | C++ projects built with CMake (any compiler / generator / package manager — recorded in the seeded Toolchain table) | — |
| `rust/` | Rust crates and workspaces built with cargo (channel / target triple / edition recorded in the seeded Toolchain table) | — |
| `python/` | Python packages and tools | — |
| `powershell-module/` | PowerShell 7 modules (the engine's origin stack) | `regenerate-function-index.ps1` (AST walk) |

### Framework overlays

| Adapter | For | Inherits | Regenerator |
| ------- | --- | -------- | ----------- |
| `winui3/` | WinUI 3 / Windows App SDK desktop apps (C#) | `csharp` | inherited |
| `wpf/` | WPF desktop apps | `csharp` | inherited |
| `avalonia/` | Avalonia cross-platform desktop apps | `csharp` | inherited |
| `electron/` | Electron desktop apps | `typescript` | inherited |
| `browser-extension/` | Manifest V3 browser extensions, browser-neutral. Install directly when an extension targets more than one browser (or the target is undecided); it is also the base for the single-browser overlays below | `typescript` | `regenerate-manifest-index.ps1` (manifest parse, checked against the targets in `Context/scripts/extension-targets.psd1`) |
| `firefox-extension/` | Firefox-only MV3 extensions on the Release (156+) or ESR (153+) channel: event page, data-collection consent, AMO | `browser-extension` | inherited (narrowed to Firefox checks by its `extension-targets.psd1`) |
| `chrome-extension/` | Chrome-only MV3 extensions on the Stable (154+) or Extended Stable (152+) channel: service worker, offscreen documents, side panel, Chrome Web Store | `browser-extension` | inherited (narrowed to Chrome checks by its `extension-targets.psd1`) |
| `figma-plugin/` | Figma plugins and widgets (Figma design, FigJam, Dev Mode, Slides, Buzz) | `typescript` | `regenerate-figma-manifest-index.ps1` (manifest parse + publish-readiness validation) |
| `obsidian-plugin/` | Obsidian community plugins on the public (1.13.0+) or Early access (1.14.0+) channel: declarative settings, the Vault API, deferred views, mobile, the Community directory | `typescript` | `regenerate-obsidian-manifest-index.ps1` (manifest, `versions.json`, and registered-surface inventory + release-readiness validation) |
| `web/` | Websites and web apps, framework-independent. Install directly for a plain HTML/Sass site or a client-only SPA; it is also the base for the meta-framework overlays below | `typescript` | `regenerate-route-map.ps1` (walks the route directory for Next.js, Astro, Nuxt, or SvelteKit) |
| `nextjs/` | Next.js App Router applications | `web` | inherited |
| `astro/` | Astro sites | `web` | inherited |

Chains can be any depth: `nextjs` resolves to `typescript -> web -> nextjs` and `firefox-extension` to `typescript -> browser-extension -> firefox-extension`, and every level's conventions install parent-first while `ConfigDefaults` merge per-key last-wins.

The browser-extension family, `figma-plugin`, and `obsidian-plugin` all key off a `manifest.json`, but the three formats are unrelated: a WebExtension manifest declares `manifest_version`, a Figma manifest declares `editorType` and `api`, and an Obsidian plugin manifest declares `id` and `minAppVersion` with none of those. Each regenerator skips the others' manifests.

The single-browser extension overlays and `obsidian-plugin` record their release channels and reference floors in `adapter.psd1` under `Channels`: latest and enterprise for the browsers, public and Early access for Obsidian. The `/fm-init-context-engine` skill reads them to seed a project's floor (`extension-targets.psd1` for an extension, the Toolchain table for an Obsidian plugin, whose shipped floor is `minAppVersion`); the project's own channel and floor are data it owns from then on. A seed refresh prints floor advisories only for the extension family; an Obsidian floor move ships as a changelog **Floor** entry whose `Detect:` pattern matches `minAppVersion`.

## Adapter contract

An adapter is a directory mirroring the install layout, applied after core (and after its parent, for `Inherits` chains — parent files first, child files override same-path). It may contribute:

| Slot | Path in adapter | Purpose |
| ---- | --------------- | ------- |
| Adapter metadata | `adapter.psd1` | `Inherits` (optional parent name), `PrimaryExtension` (no dot; feeds `{{PRIMARY_EXT}}`), `ConfigDefaults` (below), and optional engine-side data the installer ignores: reference data the skill reads (e.g. `Channels`) and refresh metadata (`Sources`, `RefreshChecks`, `SeedPolicy`; below). **Never copied to the target.** |
| Convention seeds | `Context/conventions/*.md` | Language/framework style guide. May use installer tokens (e.g. `last_verified: {{TODAY}}`). |
| Conventions index | `Context/conventions/README.md` | **Whole-file override** listing agent-rules + every style doc the full chain installs — a child adapter's README must include its parent's docs. |
| Rule seeds | `claude/rules/*.md` | Path-scoped rules with `paths:` frontmatter → install to `.claude/rules/`. |
| Regenerators | `Context/scripts/*.ps1` | Public-surface index generators honoring the contract in core's `Context/scripts/README.md`. |
| Regenerator data | `Context/scripts/*.psd1` | Data a regenerator reads, such as `extension-targets.psd1`. A child overrides it at the same path to specialize an inherited regenerator without copying the script. Project-owned after install. |
| Architecture seeds | `Context/architecture/*.md` | Optional stack-specific skeleton docs. |

### `ConfigDefaults` (in `adapter.psd1`)

Structured defaults the installer splices into the installed (project-owned) `.claude/context-engine.psd1` — the core template stays the single structural source; no adapter ships its own copy of that file:

```powershell
ConfigDefaults = @{
    PublicSurface = 'One sentence — resolves the {{PUBLIC_SURFACE}} token'
    DirtyHint     = 'Replaces the empty DirtyHint value'
    Watches       = @(  # flat hashtables; keys Glob/Action/Command/Message/Hint
        @{ Glob = '**/*.cs'; Action = 'MarkDirty'; Hint = 'run dotnet build to verify' }
    )
    Regenerators  = @('Context/scripts/regenerate-api-index.ps1')
}
```

Merging across an `Inherits` chain is **per-key last-wins**: a child that omits `Regenerators` inherits the parent's; a child that provides `Watches` replaces the parent's wholesale. The installer validates the spliced result with `Import-PowerShellDataFile` — a malformed splice fails the install loudly.

### Refresh metadata (in `adapter.psd1`)

Installed projects pull template improvements with a seed refresh (`Update-ContextEngine.ps1 -RefreshSeeds`), and the maintainer keeps the templates current with [`docs/REFRESHING-STACKS.md`](../../docs/REFRESHING-STACKS.md). Three optional keys serve those two jobs:

```powershell
Sources       = @('https://…')    # authoritative pages to re-read when refreshing this stack
RefreshChecks = @('Question?')    # known time bombs to check on every template refresh
SeedPolicy    = @(                # how a seed refresh treats a path; checked before the core table
    @{ Glob = 'Context/scripts/*.psd1'; Policy = 'Propose' }
)
```

`SeedPolicy` entries use the watch glob semantics, and the policy is `Merge`, `Propose`, `Config`, or `Skip` (the core table and what each does are in `lib/common.ps1`). A child adapter's entries win over its parent's. Record every change to what an adapter seeds in the engine's `CHANGELOG.md`, scoped to the adapter.

## Rules for adapters

- Adapters **seed**, they don't finish. Everything they install is project-owned after install — the maintainer edits freely. A plain `Update-ContextEngine.ps1` never re-touches adapter-seeded files; an explicit seed refresh merges later template changes in without overwriting the project's edits.
- Adapters never modify core process files (commands, hooks, the context-keeper skill) and never install into engine-owned paths (`.claude/hooks/`, `.claude/commands/`, `.claude/skills/context-keeper/`, `.claude/context-engine/`, `.githooks/`).
- Inheritance is additive: every parent file installs under every child, and a child cannot remove one. Keep a base adapter's content true for every child, and put child-specific content in the child. When a child needs different behavior from inherited *code*, override a small data file rather than the script.
- Keep convention seeds honest and short — starting points, not bibles. Field-tested gotchas are the highest-value content.
- Write every convention statement as a platform fact, a guardrail, or a default, and mark defaults **Default:**. Rule seeds (`claude/rules/*.md`) carry only facts and guardrails, because they load automatically and read as orders; where one has to mention a default, phrase it conditionally ("if the project uses the shared message registry (the default), …"). Every conventions README override keeps core's "Facts, guardrails, and defaults" section.

Adding a new adapter (a future C++ stack, say) is: create the directory, fill the slots that apply, done — the installer discovers adapters by directory name; nothing in core or the scripts changes.
