#Requires -Version 7.1
using namespace System.IO

<#
.SYNOPSIS
    Regenerates Context/generated/figma-manifest-index.md — a full inventory of
    every Figma plugin manifest in the repo, with a validation report.

.DESCRIPTION
    Seeded by the context-engine figma-plugin adapter; project-owned — tune the
    exclusions or the validation rules freely.

    Finds every manifest*.json that parses, has no "manifest_version" key (that
    would be a WebExtension manifest, not a Figma one), and declares
    "editorType" or "api". Documents the whole declared surface: identity, editor
    types, document access, network access, permissions, capabilities, the menu
    tree (walked recursively through nested submenus), parameters, relaunch
    buttons, and development flags.

    The validation report is the point. It flags manifests that will be rejected
    at publish or misbehave at runtime: a missing documentAccess, the unsupported
    dev+figjam pairing, "*" network access without reasoning, localhost in
    allowedDomains rather than devAllowedDomains, enableProposedApi left on,
    codegen/inspect without Dev Mode, and duplicate menu commands or parameter
    keys.

    Contract (Context/scripts/README.md): standalone, fast, writes exactly one
    banner-prefixed artifact into Context/generated/.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR }
            else { (Get-Location).ProviderPath }
$outPath = [Path]::Combine($repoRoot, 'Context', 'generated', 'figma-manifest-index.md')

$excludePathPattern =
    '[\\/](\.git|\.claude|Context|node_modules|dist|build|out|coverage|' +
    '\.vite|\.parcel-cache)[\\/]'

# ── Helpers ─────────────────────────────────────────────────────────────────

function Get-Val {
    # Safe nested lookup: Get-Val $manifest @('networkAccess','allowedDomains')
    param([Parameter(Mandatory)] $Table, [Parameter(Mandatory)] [string[]] $Path)
    $node = $Table
    foreach ($key in $Path) {
        if ($node -isnot [System.Collections.IDictionary]) { return $null }
        if (-not $node.Contains($key)) { return $null }
        $node = $node[$key]
    }
    return $node
}

function Get-Array {
    # Two PowerShell traps: @($null) is a one-element array holding $null, and a
    # function returning @() emits nothing (the pipeline unrolls it) so the
    # caller gets $null and .Count throws under StrictMode. The unary comma
    # makes the result survive the return intact.
    param([AllowNull()] $Value)
    if ($null -eq $Value) { return , @() }
    return , @($Value)
}

function Format-Code {
    param([AllowEmptyString()] [AllowNull()] [string] $Text)
    if ([string]::IsNullOrEmpty($Text)) { return '—' }
    return '`' + $Text + '`'
}

function Format-CodeList {
    param([AllowNull()] $Items)
    $arr = @(@($Items) | Where-Object { $null -ne $_ -and "$_" -ne '' })
    if (-not $arr.Count) { return '_(none)_' }
    return (($arr | ForEach-Object { '`' + $_ + '`' }) -join ', ')
}

function Get-MenuItem {
    # Walks the manifest menu tree. Items are one of:
    #   { name, command }        -> a clickable command
    #   { separator: true }      -> a divider (ignored here)
    #   { name, menu: [...] }    -> a nested submenu, arbitrarily deep
    # Emits one row per clickable command with its full breadcrumb path.
    param([AllowNull()] $Items, [string] $Prefix = '')
    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($item in (Get-Array $Items)) {
        if ($item -isnot [System.Collections.IDictionary]) { continue }
        if ($item.Contains('separator')) { continue }

        $name = Get-Val $item @('name')
        $path = if ($Prefix) { "$Prefix > $name" } else { "$name" }

        if ($item.Contains('menu')) {
            foreach ($child in (Get-MenuItem -Items $item['menu'] -Prefix $path)) {
                $rows.Add($child)
            }
        }
        elseif ($item.Contains('command')) {
            $rows.Add([pscustomobject]@{
                Path          = $path
                Command       = [string](Get-Val $item @('command'))
                ParameterOnly = Get-Val $item @('parameterOnly')
                Parameters    = (Get-Array (Get-Val $item @('parameters'))).Count
            })
        }
    }
    return , $rows.ToArray()
}

# ── Discover manifests ──────────────────────────────────────────────────────

$manifests = [System.Collections.Generic.List[object]]::new()

$candidates = Get-ChildItem -LiteralPath $repoRoot -Recurse -File -Filter 'manifest*.json' -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch $excludePathPattern } |
    Sort-Object FullName

foreach ($file in $candidates) {
    try {
        $json = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 |
            ConvertFrom-Json -AsHashtable -Depth 32
    }
    catch { continue }  # unparsable JSON is skipped, not fatal

    if ($json -isnot [System.Collections.IDictionary]) { continue }
    # A "manifest_version" key means this is a WebExtension manifest, not Figma.
    if ($json.Contains('manifest_version')) { continue }
    if (-not ($json.Contains('editorType') -or $json.Contains('api'))) { continue }

    $manifests.Add([pscustomobject]@{
        RelPath  = ($file.FullName.Substring($repoRoot.Length + 1) -replace '\\', '/')
        Manifest = $json
    })
}

# ── Emit ────────────────────────────────────────────────────────────────────

$sb = [System.Text.StringBuilder]::new()
$null = $sb.AppendLine('<!-- GENERATED FILE — DO NOT EDIT — regenerated by Context/scripts/regenerate-figma-manifest-index.ps1 -->')
$null = $sb.AppendLine('<!-- Source: every Figma plugin manifest*.json in the repo (build output and node_modules excluded) -->')
$null = $sb.AppendLine("<!-- Last run: $(Get-Date -AsUTC -Format 'yyyy-MM-ddTHH:mm:ssZ') -->")
$null = $sb.AppendLine('')
$null = $sb.AppendLine('# Figma Plugin Manifest Index')
$null = $sb.AppendLine('')

if (-not $manifests.Count) {
    $null = $sb.AppendLine('_No Figma plugin manifest found._ Either the plugin has not been scaffolded yet, or the manifest lives under an excluded directory (check `$excludePathPattern` in the regenerator).')
    $null = [Directory]::CreateDirectory([Path]::GetDirectoryName($outPath))
    [File]::WriteAllText($outPath, $sb.ToString().Replace("`r`n", "`n"), [System.Text.UTF8Encoding]::new($false))
    Write-Host 'figma-manifest-index: 0 manifest(s) -> Context/generated/figma-manifest-index.md'
    exit 0
}

$null = $sb.AppendLine("$($manifests.Count) manifest(s). Editor types, permissions, capabilities, allowed domains, menu commands, and parameters are **public surface** — they change what users see in the editor and what Community review examines.")
$null = $sb.AppendLine('')

foreach ($entry in $manifests) {
    $m = $entry.Manifest
    $findings = [System.Collections.Generic.List[string]]::new()

    $null = $sb.AppendLine("## ``$($entry.RelPath)``")
    $null = $sb.AppendLine('')

    # ---- Identity ----------------------------------------------------------
    $editorTypes = Get-Array (Get-Val $m @('editorType'))
    $docAccess = Get-Val $m @('documentAccess')
    $uiVal = Get-Val $m @('ui')

    $uiText = if ($uiVal -is [System.Collections.IDictionary]) {
        (@($uiVal.Keys) | Sort-Object | ForEach-Object { "``$_`` -> ``$($uiVal[$_])``" }) -join ', '
    }
    else { Format-Code $uiVal }

    $null = $sb.AppendLine('| Field | Value |')
    $null = $sb.AppendLine('| ----- | ----- |')
    $null = $sb.AppendLine("| Name | $(Format-Code (Get-Val $m @('name'))) |")
    $null = $sb.AppendLine("| Plugin id | $(Format-Code (Get-Val $m @('id'))) |")
    $null = $sb.AppendLine("| API version | $(Format-Code (Get-Val $m @('api'))) |")
    $null = $sb.AppendLine("| Main (sandbox) | $(Format-Code (Get-Val $m @('main'))) |")
    $null = $sb.AppendLine("| UI (iframe) | $uiText |")
    $null = $sb.AppendLine("| Editor types | $(Format-CodeList $editorTypes) |")
    $null = $sb.AppendLine("| Document access | $(Format-Code $docAccess) |")
    $null = $sb.AppendLine("| Build command | $(Format-Code (Get-Val $m @('build'))) |")
    $null = $sb.AppendLine('')

    if (-not (Get-Val $m @('main'))) {
        $findings.Add('No `main` — the manifest must name the sandbox entry point.')
    }
    if (-not (Get-Val $m @('api'))) {
        $findings.Add('No `api` version. Figma never auto-upgrades this field, so set it deliberately and review it when new API features land.')
    }
    if (-not (Get-Val $m @('id'))) {
        $findings.Add('No `id`. Expected for an unpublished plugin; Figma assigns one at first publish.')
    }
    if ("$docAccess" -ne 'dynamic-page') {
        $findings.Add('`documentAccess` is not `"dynamic-page"`. It is **required for all new plugins**; without it Figma preloads the whole file on first run (a 20-30s stall in a large document).')
    }
    if (-not $editorTypes.Count) {
        $findings.Add('`editorType` is missing. It is a required field.')
    }
    if (($editorTypes -contains 'dev') -and ($editorTypes -contains 'figjam')) {
        $findings.Add('`editorType` declares both `dev` and `figjam`. That combination is **unsupported** and the manifest will be rejected.')
    }

    # ---- Network access ----------------------------------------------------
    $hasNetworkKey = ($m -is [System.Collections.IDictionary]) -and $m.Contains('networkAccess')
    $allowed = Get-Array (Get-Val $m @('networkAccess', 'allowedDomains'))
    $devAllowed = Get-Array (Get-Val $m @('networkAccess', 'devAllowedDomains'))
    $reasoning = Get-Val $m @('networkAccess', 'reasoning')

    $null = $sb.AppendLine('### Network access')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine("- Allowed domains: $(Format-CodeList $allowed)")
    $null = $sb.AppendLine("- Dev-only domains: $(Format-CodeList $devAllowed)")
    $null = $sb.AppendLine("- Reasoning: $(if ($reasoning) { $reasoning } else { '—' })")
    $null = $sb.AppendLine('')

    if (-not $hasNetworkKey) {
        $findings.Add('No `networkAccess`. The field is required; use `{"allowedDomains": ["none"]}` when the plugin makes no requests.')
    }
    elseif (-not $allowed.Count) {
        $findings.Add('`networkAccess.allowedDomains` is empty. It must list at least one pattern, or `"none"`.')
    }
    if (($allowed -contains '*') -and -not $reasoning) {
        $findings.Add('`allowedDomains` includes `"*"` without `reasoning`. Reasoning is **required** for a wildcard and review will reject it otherwise.')
    }
    $localHosts = @($allowed | Where-Object { $_ -match 'localhost|127\.0\.0\.1' })
    if ($localHosts.Count) {
        $findings.Add("Local/development server(s) in ``allowedDomains``: $(Format-CodeList $localHosts). Move them to ``devAllowedDomains`` so the published plugin does not request them; keeping them in ``allowedDomains`` also makes ``reasoning`` mandatory.")
    }

    # ---- Permissions and capabilities --------------------------------------
    $perms = Get-Array (Get-Val $m @('permissions'))
    $caps = Get-Array (Get-Val $m @('capabilities'))

    $null = $sb.AppendLine('### Permissions and capabilities')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine("- Permissions: $(Format-CodeList $perms)")
    $null = $sb.AppendLine("- Capabilities: $(Format-CodeList $caps)")
    $null = $sb.AppendLine('')

    foreach ($cap in @('codegen', 'inspect')) {
        if (($caps -contains $cap) -and -not ($editorTypes -contains 'dev')) {
            $findings.Add("Capability ``$cap`` only applies in Dev Mode, but ``editorType`` does not include ``dev``.")
        }
    }

    # ---- Menu --------------------------------------------------------------
    $menuRows = Get-MenuItem -Items (Get-Val $m @('menu'))

    $null = $sb.AppendLine('### Menu commands')
    $null = $sb.AppendLine('')
    if (-not $menuRows.Count) {
        $null = $sb.AppendLine('_No submenu declared — the plugin runs a single default command._')
    }
    else {
        $null = $sb.AppendLine('| Menu path | `figma.command` | Parameter only | Parameters |')
        $null = $sb.AppendLine('| --------- | --------------- | -------------- | ---------- |')
        foreach ($row in $menuRows) {
            $null = $sb.AppendLine("| $($row.Path) | $(Format-Code $row.Command) | $(Format-Code "$($row.ParameterOnly)") | $($row.Parameters) |")
        }

        $dupes = @($menuRows | Group-Object Command | Where-Object { $_.Count -gt 1 })
        foreach ($d in $dupes) {
            $findings.Add("Menu command ``$($d.Name)`` is declared $($d.Count) times. ``figma.command`` cannot tell them apart.")
        }
    }
    $null = $sb.AppendLine('')

    # ---- Parameters --------------------------------------------------------
    $parameters = Get-Array (Get-Val $m @('parameters'))
    $parameterOnly = Get-Val $m @('parameterOnly')

    $null = $sb.AppendLine('### Parameters')
    $null = $sb.AppendLine('')
    if (-not $parameters.Count) {
        $null = $sb.AppendLine('_None declared._')
    }
    else {
        $null = $sb.AppendLine('| Key | Name | Optional | Freeform |')
        $null = $sb.AppendLine('| --- | ---- | -------- | -------- |')
        foreach ($p in $parameters) {
            $null = $sb.AppendLine("| $(Format-Code (Get-Val $p @('key'))) | $(Get-Val $p @('name')) | $(Format-Code "$(Get-Val $p @('optional'))") | $(Format-Code "$(Get-Val $p @('allowFreeform'))") |")
        }
        $dupeKeys = @($parameters | ForEach-Object { Get-Val $_ @('key') } |
            Group-Object | Where-Object { $_.Count -gt 1 })
        foreach ($d in $dupeKeys) {
            $findings.Add("Parameter key ``$($d.Name)`` is declared $($d.Count) times; keys must be unique.")
        }
    }
    # Single-quoted prefix: inside a double-quoted string a backtick escapes the
    # next character, which would silently eat the leading letter of the label.
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('- `parameterOnly`: ' + (Format-Code "$parameterOnly"))
    $null = $sb.AppendLine('')

    if (($parameterOnly -eq $true) -and -not $parameters.Count -and -not $menuRows.Count) {
        $findings.Add('`parameterOnly` is true but no `parameters` are declared. The plugin cannot be launched.')
    }

    # ---- Relaunch buttons --------------------------------------------------
    $relaunch = Get-Array (Get-Val $m @('relaunchButtons'))
    $null = $sb.AppendLine('### Relaunch buttons')
    $null = $sb.AppendLine('')
    if (-not $relaunch.Count) {
        $null = $sb.AppendLine('_None declared._')
    }
    else {
        $null = $sb.AppendLine('| `command` | Button name | Multiple selection |')
        $null = $sb.AppendLine('| --------- | ----------- | ------------------ |')
        foreach ($r in $relaunch) {
            $null = $sb.AppendLine("| $(Format-Code (Get-Val $r @('command'))) | $(Get-Val $r @('name')) | $(Format-Code "$(Get-Val $r @('multipleSelection'))") |")
        }
        $null = $sb.AppendLine('')
        $null = $sb.AppendLine('_Each `command` must match the one passed to `setRelaunchData()`. Renaming or removing one makes every existing button disappear._')
    }
    $null = $sb.AppendLine('')

    # ---- Development flags -------------------------------------------------
    $proposed = Get-Val $m @('enableProposedApi')
    $privateApi = Get-Val $m @('enablePrivatePluginApi')
    if (($proposed -eq $true) -or ($privateApi -eq $true)) {
        $null = $sb.AppendLine('### Development flags')
        $null = $sb.AppendLine('')
        $null = $sb.AppendLine('- `enableProposedApi`: ' + (Format-Code "$proposed"))
        $null = $sb.AppendLine('- `enablePrivatePluginApi`: ' + (Format-Code "$privateApi"))
        $null = $sb.AppendLine('')
    }
    if ($proposed -eq $true) {
        $findings.Add('`enableProposedApi` is true. This flag is **inert in published plugins** — anything relying on a proposed API will break for users. Do not ship it enabled.')
    }
    if ($privateApi -eq $true) {
        $findings.Add('`enablePrivatePluginApi` is true. Only valid for private (organization) plugins.')
    }

    # ---- Validation report -------------------------------------------------
    $null = $sb.AppendLine('### Validation findings')
    $null = $sb.AppendLine('')
    if (-not $findings.Count) {
        $null = $sb.AppendLine('_No issues detected._')
    }
    else {
        foreach ($f in $findings) { $null = $sb.AppendLine("- $f") }
    }
    $null = $sb.AppendLine('')
}

$null = [Directory]::CreateDirectory([Path]::GetDirectoryName($outPath))
[File]::WriteAllText($outPath, $sb.ToString().Replace("`r`n", "`n"), [System.Text.UTF8Encoding]::new($false))
Write-Host "figma-manifest-index: $($manifests.Count) manifest(s) -> Context/generated/figma-manifest-index.md"
exit 0
