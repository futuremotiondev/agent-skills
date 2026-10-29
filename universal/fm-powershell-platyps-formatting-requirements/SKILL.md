---
name: fm-powershell-platyps-formatting-requirements
description: Use when authoring or reviewing PowerShell functions in a module that will be documented with Microsoft.PowerShell.PlatyPS v1.0.1 or newer. Covers required comment-based help keywords, CBH placement above the function, parameter and OutputType alignment, placeholder avoidance in the generated Markdown, post-export validation steps, and publishing the result as an Astro Starlight documentation site. Applies to FMDevToolbox and similar Windows PowerShell 7+ modules maintained under github.com/futuremotiondev.
---

# PlatyPS Formatting Requirements (Futuremotion)

## Overview

`Microsoft.PowerShell.PlatyPS` v1.0.1+ is the modern, Microsoft-supported PowerShell help generator. It is a complete C# rewrite of the original `platyPS` module and uses a different Markdown schema. It does not parse your `.ps1` files directly. Instead, it imports your module and runs `Get-Help` against every exported function, then serialises the result to Markdown. The entire quality of the output is therefore a direct function of the quality of your comment-based help (CBH).

Incomplete CBH produces `{{ Fill in … }}` placeholders in the generated Markdown that you would otherwise have to fix by hand. The discipline this skill enforces is: write CBH so thoroughly that PlatyPS requires zero hand-editing.

This skill covers three things in order:

1. How to format PowerShell functions so PlatyPS emits clean Markdown.
2. What to do immediately after running PlatyPS (validation and commit policy).
3. How to host the generated Markdown as a beautiful documentation site with Astro Starlight.

## Target environment

- PowerShell 7.1+ (Core only)
- `Microsoft.PowerShell.PlatyPS` version 1.0.1 or later — install via `Install-PSResource -Name Microsoft.PowerShell.PlatyPS -Scope CurrentUser`
- Module under development is importable and its functions are exported via the manifest `FunctionsToExport` list
- Repository canonical URL is `https://github.com/futuremotiondev`

Legacy `platyPS` v0.14.x is explicitly out of scope. Its Markdown schema differs; do not mix versions.

## Core rules for every exported function

### 1. CBH placement

The comment-based help block goes **above** the `function` keyword, not inside the function body. PowerShell also accepts CBH placed between the opening brace and `[CmdletBinding()]`, but Futuremotion convention is above the declaration for cleaner scanning of function bodies and consistent placement across the codebase.

### 2. `[CmdletBinding()]` is required

PlatyPS documents advanced functions. A function without `[CmdletBinding()]` is treated as a plain script function and produces thin output. Every documented function must declare it.

### 3. `[OutputType()]` must match `.OUTPUTS`

Declare an `[OutputType(...)]` attribute on the function. Its type name must match the `.NET` type written on the first line of the `.OUTPUTS` CBH block. If they disagree, PlatyPS keeps the `.OUTPUTS` text but your consumers get mixed signals from `Get-Help` and tooling.

### 4. Required CBH keywords

Absent any of these, PlatyPS emits a placeholder in the generated Markdown:

- `.SYNOPSIS` — one imperative sentence ending in a period. Maximum ~120 characters.
- `.DESCRIPTION` — two to six sentences, active voice. Describe behaviour, recursion, parallelism, destructive actions, and any non-obvious preconditions.
- `.PARAMETER <Name>` — one block per declared parameter, written in the same order the parameters are declared in `param()`. Each block should cover what the parameter is plus any non-obvious constraint (ranges, defaults, mutual exclusion).
- At least one `.EXAMPLE` — a real runnable command followed by a blank line followed by a prose explanation. No `PS>` prompt prefix.

### 5. Strongly recommended CBH keywords

Include unless genuinely not applicable. Absent, PlatyPS emits placeholders that must be hand-edited.

- `.INPUTS` — fully qualified .NET type name of objects accepted from the pipeline. Write `None.` on its own line if the function does not accept pipeline input.
- `.OUTPUTS` — fully qualified .NET type name on the first line, one sentence describing the object shape on the next.
- `.NOTES` — external tool or assembly dependencies, platform caveats, configuration requirements (for example `$script:FMConfig.Tools` values).
- `.LINK` — see rule 6.

### 6. `.LINK` rules

The first `.LINK` entry is the canonical online URL and is promoted by PlatyPS into the generated Markdown's `HelpUri` frontmatter field. Subsequent `.LINK` entries may be related cmdlet names, which render as cross-references in the rendered site.

**Futuremotion canonical first `.LINK` value is:**

```
https://github.com/futuremotiondev
```

Use this verbatim for every function in every FM module unless the project has a more specific URL (for example a docs site subpath).

### 7. `HelpMessage` vs `.PARAMETER` vs inline comment

Three sources of parameter text exist in PowerShell; they are not equivalent:

| Source | Where it is consumed | Read by PlatyPS |
|--------|---------------------|-----------------|
| `HelpMessage="..."` in `[Parameter()]` | Interactive prompt when a mandatory parameter is missing | No |
| `# inline comment` above a parameter declaration | `Get-Help -Parameter` when no `.PARAMETER` block exists | Only as a fallback |
| `.PARAMETER <Name>` block in CBH | `Get-Help -Full`, PlatyPS | Authoritative |

Keep existing `HelpMessage` attributes. Add `.PARAMETER` blocks. Never rely on inline parameter comments when `.PARAMETER` blocks are present; PowerShell ignores them.

### 8. Formatting conventions

- Four-space indentation inside the `<# #>` block.
- Section bodies indented one additional level.
- Blank line between CBH sections.
- Line width target 100 columns, hard wrap at 110.
- No emoji, no marketing phrasing. Active voice. Second person only when strictly necessary.
- Code inside `.EXAMPLE` blocks is bare — no `PS>` or `PS C:\>` prefix.
- Prose follows Strunk: active voice, positive form, omit needless words, keep related words together.

### 9. Keywords to avoid

- `.FORWARDHELPTARGETNAME` / `.FORWARDHELPCATEGORY` — these redirect help and confuse PlatyPS.
- `.COMPONENT` / `.ROLE` / `.FUNCTIONALITY` — valid PowerShell keywords but not rendered meaningfully by typical Markdown sites. Skip unless you are publishing structured metadata.
- `.EXTERNALHELP` — opts out of CBH entirely. Do not use in a module that is being documented by PlatyPS.

## Canonical template

```powershell
<#
.SYNOPSIS
    Converts one or more SVG files to Windows ICO format with standard icon sizes.

.DESCRIPTION
    Renders each input SVG at the nine standard Windows icon sizes
    (16, 20, 24, 32, 48, 64, 96, 128, 256) using rsvg-convert, normalises each
    PNG canvas with ImageMagick, and assembles the result into a
    multi-resolution .ico file. Files are processed in parallel.

.PARAMETER LiteralPath
    One or more SVG file paths. Directories are skipped with a warning.
    Accepts pipeline input and the PSPath alias.

.PARAMETER OutputInSubfolder
    Place the produced .ico in a subfolder of each SVG's directory instead of
    alongside the source. Subfolder name is controlled by -SubfolderName.

.PARAMETER SubfolderName
    Subfolder name when -OutputInSubfolder is used. Must not contain invalid
    filename characters. Defaults to 'ICO Conversion'.

.PARAMETER MaxThreads
    Maximum parallel threads. Defaults to 75% of available processors.

.INPUTS
    System.String[]
    Pipe file paths to this function.

.OUTPUTS
    System.Management.Automation.PSCustomObject
    One result per file with SourcePath, OutputPath, Successful, ErrorMessage.

.EXAMPLE
    Convert-SVGToICO -LiteralPath 'C:\Icons\logo.svg'

    Converts logo.svg to logo.ico in the same directory.

.EXAMPLE
    Get-ChildItem 'C:\Icons' -Filter *.svg | Convert-SVGToICO -OutputInSubfolder

    Pipes all SVGs in a directory and writes each .ico into an
    'ICO Conversion' subfolder beside its source.

.NOTES
    Requires rsvg-convert and ImageMagick on PATH, configured through
    $script:FMConfig.Tools.

.LINK
    https://github.com/futuremotiondev

.LINK
    Convert-SVGToPNGBySize
#>
function Convert-SVGToICO {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        # ... existing param block unchanged ...
    )
    # ... existing body unchanged ...
}
```

## Running PlatyPS

From a clean PowerShell 7 session with the target module built and importable:

```powershell
Install-PSResource -Name Microsoft.PowerShell.PlatyPS -Scope CurrentUser -TrustRepository
Import-Module ./FMDevToolbox -Force
$module = Get-Module FMDevToolbox

$help = New-MarkdownCommandHelp -ModuleInfo $module
Export-MarkdownCommandHelp `
    -CommandHelp    $help `
    -OutputFolder   ./docs-src `
    -Force
```

The call produces one Markdown file per exported function plus a module landing page. Generated files carry YAML frontmatter with `title`, `HelpUri`, `Module Name`, `external help file`, `Locale`, and `ms.date` fields.

## After-steps: validate and commit

### 1. Scan for placeholders

Any `{{ Fill in X }}` string in the output means the corresponding CBH section is missing in the source `.ps1`. Fix the source, never hand-edit the generated Markdown.

```powershell
Get-ChildItem ./docs-src -Filter *.md -Recurse |
    Select-String -Pattern '\{\{ Fill in'
```

If this command finds matches, stop, fix each referenced function's CBH, and re-run the export.

### 2. Count parity

Make sure every exported function produced a file:

```powershell
$exported  = (Get-Module FMDevToolbox).ExportedFunctions.Count
$generated = (Get-ChildItem ./docs-src -Filter *.md | Where-Object Name -ne 'FMDevToolbox.md').Count
if ($exported -ne $generated) { throw "Mismatch: $exported exported vs $generated generated." }
```

### 3. Decide commit policy

- **Gitignore `docs-src/`** (recommended default) — it is a pure build artifact regenerated on every run.
- **Commit `docs-src/`** only if you want GitHub's native Markdown preview to work without a built site.

Pick one and document it in the repo's `.gitignore`.

### 4. Optional Pester lint

A small `Tests/Help.Tests.ps1` that iterates `(Get-Module FMDevToolbox).ExportedFunctions.Values` and asserts each function has a non-empty synopsis, description, at least one example, and `.PARAMETER` coverage for every declared parameter. Wire it into CI so help regressions break the build.

## Publishing: Astro Starlight

Starlight is the recommended static-site generator for PlatyPS output. It consumes plain Markdown, auto-generates a category sidebar from directory structure, and ships with full-text search (Pagefind), dark mode, and theming out of the box. It is the same stack `PwshSpectreConsole` uses.

### Pipeline

```
docs-src/*.md  ─→  Build-DocsSite.ps1  ─→  docs-site/src/content/docs/reference/<Category>/*.md
                                                                                                ↓
                                                                                     npm run build  ─→  docs-site/dist/
```

### The glue script

A ~60-line `Build-DocsSite.ps1` in the repo root or `FMDevToolbox/` that:

1. Reads every `.md` under `docs-src/`.
2. Parses the YAML frontmatter with `ConvertFrom-Yaml` (PowerShell 7.4+ built-in) or equivalent.
3. Looks up the source `.ps1` under `FMDevToolbox/Public/<Category>/<Name>.ps1` to determine the category.
4. Rewrites the frontmatter into Starlight's shape (`title`, `description`, and any `sidebar` fields).
5. Writes the rewritten Markdown to `docs-site/src/content/docs/reference/<Category>/<Name>.md`.
6. Wipes and recreates the `reference/` directory on each run so the site stays in sync with the source.

### Initialising the Astro site

```bash
npm create astro@latest docs-site -- --template starlight --install --yes
cd docs-site
```

### Minimal `astro.config.mjs`

```javascript
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
  integrations: [
    starlight({
      title: 'FMDevToolbox',
      social: { github: 'https://github.com/futuremotiondev' },
      sidebar: [
        { label: 'Getting Started', autogenerate: { directory: 'guides' } },
        { label: 'Reference',       autogenerate: { directory: 'reference' } },
      ],
    }),
  ],
});
```

The `autogenerate: { directory: 'reference' }` entry makes the sidebar mirror your `FMDevToolbox/Public/<Category>/` structure with zero hand-written navigation.

### Deployment

Static output lands in `docs-site/dist/`. Any static host works:

- **Cloudflare Pages** — connect the repo, build command `npm run build --prefix docs-site`, output directory `docs-site/dist`.
- **GitHub Pages** — use `actions/deploy-pages` with the same build command and output directory.

### Optional enhancements

- `@astrojs/starlight-tailwind` plus `@astrojs/tailwind` for custom styling beyond the default theme.
- `asciinema-player` embedded in function pages for live terminal recordings of examples (`PwshSpectreConsole` does this for visual cmdlets).
- Versioning via Starlight's content collections if you ship multiple major versions of the module.

## Common gotchas

| Symptom | Cause | Fix |
|--------|-------|-----|
| `{{ Fill in X }}` placeholders in output | CBH section missing or empty in source | Fix the `.ps1`, re-run export. Never hand-edit generated Markdown. |
| Parameter appears out of order | PlatyPS follows `param()` declaration order, not `.PARAMETER` order | Reorder the `param()` block. |
| `.OUTPUTS` section missing | Neither `.OUTPUTS` CBH nor `[OutputType()]` declared | Add both; they should agree. |
| No docs for a function | Function not in `FunctionsToExport` or module not imported | Fix module manifest; re-import; re-run. |
| `HelpUri` frontmatter is empty | No `.LINK` with a URL as the first `.LINK` entry | Add `https://github.com/futuremotiondev` as the first `.LINK`. |
| Function documented but marked "not an advanced function" | `[CmdletBinding()]` missing | Add it. |

## When NOT to use this skill

- Authoring a standalone `.ps1` script that is not part of a module — use standard CBH without the PlatyPS-specific discipline.
- A function is `Internal-*` prefixed and excluded from the manifest in production builds — no docs are produced, so no PlatyPS formatting is needed.
- The project is on legacy `platyPS` v0.14.x — the Markdown schema is different; do not use this skill's guidance verbatim.

## Related skills

- `fm-powershell-coding-style` — region headers, naming, visual formatting for all PS code.
- `martix-powershell` — broader compiled-cmdlet and advanced-function authoring.
- `elements-of-style:writing-clearly-and-concisely` — writing clean prose for synopsis, description, and examples.
