#Requires -Version 7.1
using namespace System.IO
using namespace System.Collections.Generic

<#
.SYNOPSIS
    Regenerates Context/generated/manifest-index.md — an inventory of every
    WebExtension manifest in the repo, checked against the project's target
    browsers, release channels, and minimum versions.

.DESCRIPTION
    Seeded by the context-engine browser-extension adapter and inherited by
    firefox-extension and chrome-extension; project-owned — tune the
    exclusions, the fact tables, or the checks freely.

    Targets come from Context/scripts/extension-targets.psd1, which each
    single-browser stack overrides with its own browser, channel, and floor.
    Without that file the script checks against both browsers with no floor.

    Finds every manifest*.json that parses and declares manifest_version. If
    there is none and the project uses WXT (a wxt.config.* at the repo root),
    it reads WXT's production build output (.output/<browser>-mv<N>/) instead,
    labelled as built output, because WXT projects keep no manifest in source.

    Each manifest is documented (identity, background, permissions, content
    scripts, UI surfaces, commands, web-accessible resources, network, CSP)
    and checked against the targets it applies to. A manifest named
    manifest.<browser>.json, or built into a <browser>-* output folder,
    applies to that browser only; any other manifest applies to every target.
    Findings carry a severity: Blocker (will not load or sign in a target),
    Warning (review or UX risk), Note (advisory).

    The fact tables near the top are the part that goes stale as browsers
    release: update them when a floor rises.

    Contract (Context/scripts/README.md): standalone, fast, writes exactly one
    banner-prefixed artifact into Context/generated/.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR }
            else { (Get-Location).ProviderPath }
$outPath       = [Path]::Combine($repoRoot, 'Context', 'generated', 'manifest-index.md')
$targetsPath   = [Path]::Combine($repoRoot, 'Context', 'scripts', 'extension-targets.psd1')
$targetsSource = 'Context/scripts/extension-targets.psd1'

# Build output, vendor, and engine directories are never scanned.
# .output/.wxt are WXT's; web-ext-artifacts is web-ext's packaging output.
$excludePathPattern =
    '[\\/](\.git|\.claude|Context|node_modules|dist|build|out|\.output|\.wxt|' +
    'coverage|web-ext-artifacts|\.vite|\.parcel-cache)[\\/]'

# ── Platform facts (update when a floor rises) ──────────────────────────────
# Verified 2026-09-28 against MDN browser-compat-data 8.1.3,
# developer.chrome.com, and extensionworkshop.com. Keys are manifest paths
# (dots for nesting) or permission names; each value is a severity and the
# reason the other browser rejects or ignores it.

$firefoxUnsupportedKeys = [ordered]@{
    'side_panel'             = @('Note', 'Chrome-only; Firefox uses `sidebar_action`.')
    'minimum_chrome_version' = @('Note', 'ignored by Firefox; its floor is `browser_specific_settings.gecko.strict_min_version`.')
    'key'                    = @('Note', 'ignored by Firefox; its id is `browser_specific_settings.gecko.id`.')
    'externally_connectable' = @('Note', 'not implemented in Firefox.')
    'storage.managed_schema' = @('Note', 'not implemented in Firefox.')
}
$firefoxUnsupportedPermissions = [ordered]@{
    'sidePanel'          = 'Chrome-only; Firefox uses `sidebarAction`.'
    'offscreen'          = 'not implemented in Firefox (its event page has a DOM).'
    'declarativeContent' = 'not implemented in Firefox.'
    'debugger'           = 'not implemented in Firefox.'
}
$chromeUnsupportedKeys = [ordered]@{
    'sidebar_action'            = @('Warning', 'Firefox-only; Chrome uses `side_panel`.')
    'page_action'               = @('Warning', 'MV2-only in Chrome; use `action`.')
    'browser_specific_settings' = @('Note',    'ignored by Chrome.')
    'user_scripts'              = @('Warning', 'a Firefox MV2 key; MV3 uses the `userScripts` API.')
}
$chromeUnsupportedPermissions = [ordered]@{
    'menus'                    = 'the Firefox name; Chrome uses `contextMenus`.'
    'contextualIdentities'     = 'Firefox-only.'
    'webRequestFilterResponse' = 'Firefox-only (`webRequest.filterResponseData`).'
    'theme'                    = 'Firefox-only.'
    'dns'                      = 'Firefox-only.'
    'find'                     = 'Firefox-only.'
    'browserSettings'          = 'Firefox-only.'
    'pkcs11'                   = 'Firefox-only.'
    'captivePortal'            = 'Firefox-only.'
}

# Manifest keys and permissions newer than the enterprise floors (Firefox ESR
# 153, Chrome Extended Stable 152). Below its version, a row needs feature
# detection or has to go. Mirrors the "Version-gated features" table in each
# browser's convention document.
$versionGated = @(
    @{ Browser = 'firefox'; Kind = 'key';        Name = 'sandbox';                         Since = 154 }
    @{ Browser = 'firefox'; Kind = 'key';        Name = 'content_security_policy.sandbox'; Since = 154 }
    @{ Browser = 'chrome';  Kind = 'permission'; Name = 'publicSuffix';                    Since = 153 }
)

$validChannels = @{ chrome = @('stable', 'extended'); firefox = @('release', 'esr') }
$channelLabels = @{
    stable = 'Stable'; extended = 'Extended Stable'; release = 'Release'; esr = 'ESR'
}

# ── Helpers ─────────────────────────────────────────────────────────────────

function Get-Val {
    # Safe nested lookup: Get-Val $manifest 'background' 'service_worker'
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
    # Normalizes a manifest value to a real array. Two PowerShell traps here:
    #   1. @($null) is a ONE-element array holding $null, so an absent key would
    #      look like a single empty entry and feed $null into loops.
    #   2. A function returning @() emits NOTHING (the pipeline unrolls it), so
    #      the caller would get $null and .Count would throw under StrictMode.
    # The unary comma wraps the result so it survives the return intact.
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
    # The outer @() is load-bearing: a Where-Object pipeline yields a scalar
    # when exactly one item matches, and .Count on a scalar throws under
    # Set-StrictMode -Version Latest.
    $arr = @(@($Items) | Where-Object { $null -ne $_ -and "$_" -ne '' })
    if (-not $arr.Count) { return '_(none)_' }
    return (($arr | ForEach-Object { '`' + $_ + '`' }) -join ', ')
}

function Get-Major {
    # '156.0', '156.0a1', '154', '154.0.8037.57' -> 156 / 154; else $null.
    param([AllowNull()] $Version)
    if ($null -eq $Version) { return $null }
    if ("$Version" -match '^\s*(\d+)') { return [int]$Matches[1] }
    return $null
}

function Get-BrowserFromName {
    # Maps a file or folder name to the browser it was built for, or $null.
    param([Parameter(Mandatory)] [string] $Name)
    if ($Name -match '(?i)(^|[.\-])(firefox|gecko)([.\-]|$)') { return 'firefox' }
    if ($Name -match '(?i)(^|[.\-])(chrome|chromium|edge)([.\-]|$)') { return 'chrome' }
    return $null
}

function Format-Target {
    param([Parameter(Mandatory)] $Target)
    $name = if ($Target.Browser -eq 'chrome') { 'Chrome' } else { 'Firefox' }
    if ($Target.Channel -and $channelLabels.ContainsKey($Target.Channel)) {
        $name += ' ' + $channelLabels[$Target.Channel]
    }
    if ($null -ne $Target.Floor) { return "$name $($Target.Floor)+" }
    return "$name (no floor recorded)"
}

function Read-Manifest {
    # Parses a manifest; $null when it is not JSON or not a WebExtension
    # manifest (Figma manifests share the file name but not manifest_version).
    param([Parameter(Mandatory)] [string] $LiteralPath)
    try {
        $json = Get-Content -LiteralPath $LiteralPath -Raw -Encoding UTF8 |
            ConvertFrom-Json -AsHashtable -Depth 32
    }
    catch { return $null }
    if ($json -isnot [System.Collections.IDictionary]) { return $null }
    if (-not $json.Contains('manifest_version')) { return $null }
    return $json
}

# ── Targets ─────────────────────────────────────────────────────────────────
$targets    = [List[object]]::new()
$setupNotes = [List[string]]::new()
$loaded     = $null

if (Test-Path -LiteralPath $targetsPath) {
    try { $loaded = Import-PowerShellDataFile -LiteralPath $targetsPath }
    catch { $setupNotes.Add("``$targetsSource`` does not parse: $($_.Exception.Message)") }
}
else {
    $setupNotes.Add("No ``$targetsSource``.")
}

if ($loaded -and $loaded.ContainsKey('Targets')) {
    foreach ($t in @($loaded.Targets)) {
        if ($t -isnot [System.Collections.IDictionary]) { continue }
        $browser = ([string]$t['Browser']).Trim().ToLowerInvariant()
        if ($browser -notin @('chrome', 'firefox')) {
            $setupNotes.Add("Target browser ``$browser`` is not one this script checks (chrome, firefox); ignored.")
            continue
        }
        $channel = ([string]$t['Channel']).Trim().ToLowerInvariant()
        if ($channel -and $channel -notin $validChannels[$browser]) {
            $setupNotes.Add("Channel ``$channel`` is not valid for $browser; expected $($validChannels[$browser] -join ' or ').")
            $channel = ''
        }
        $targets.Add([pscustomobject]@{
            Browser = $browser
            Channel = $channel
            Floor   = Get-Major $t['MinVersion']
        })
    }
}
if (-not $targets.Count) {
    if ($loaded) { $setupNotes.Add("``$targetsSource`` lists no usable targets.") }
    $setupNotes.Add('Checking both browsers with no floor.')
    foreach ($b in @('chrome', 'firefox')) {
        $targets.Add([pscustomobject]@{ Browser = $b; Channel = ''; Floor = $null })
    }
}
if (@($targets | Where-Object { $null -eq $_.Floor }).Count) {
    $setupNotes.Add('A target with no floor skips the minimum-version and version-gated checks.')
}

# ── Discover manifests ──────────────────────────────────────────────────────
$manifests = [List[object]]::new()

$candidates = Get-ChildItem -LiteralPath $repoRoot -Recurse -File -Filter 'manifest*.json' -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch $excludePathPattern } |
    Sort-Object FullName

foreach ($file in $candidates) {
    $json = Read-Manifest -LiteralPath $file.FullName
    if ($null -eq $json) { continue }
    $manifests.Add([pscustomobject]@{
        RelPath     = ($file.FullName.Substring($repoRoot.Length + 1) -replace '\\', '/')
        Manifest    = $json
        Built       = $false
        OnlyBrowser = Get-BrowserFromName -Name $file.Name
    })
}

# WXT generates the manifest at build time, so a WXT project has none in
# source. Fall back to its production build output; -dev folders are skipped
# because a dev manifest carries dev-server CSP and reload hooks.
if (-not $manifests.Count) {
    $wxtConfig = Get-ChildItem -LiteralPath $repoRoot -File -Filter 'wxt.config.*' -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($wxtConfig) {
        $outputDir = [Path]::Combine($repoRoot, '.output')
        # Start from a real empty array: @($null) would iterate once over $null.
        $builds = @()
        if (Test-Path -LiteralPath $outputDir -PathType Container) {
            $builds = @(Get-ChildItem -LiteralPath $outputDir -Directory |
                Where-Object Name -notlike '*-dev' | Sort-Object Name)
        }
        foreach ($dir in $builds) {
            $browser = Get-BrowserFromName -Name $dir.Name
            $file = [Path]::Combine($dir.FullName, 'manifest.json')
            if (-not $browser -or -not (Test-Path -LiteralPath $file)) { continue }
            $json = Read-Manifest -LiteralPath $file
            if ($null -eq $json) { continue }
            $manifests.Add([pscustomobject]@{
                RelPath     = ".output/$($dir.Name)/manifest.json"
                Manifest    = $json
                Built       = $true
                OnlyBrowser = $browser
            })
        }
        if (-not $manifests.Count) {
            $setupNotes.Add("WXT project (``$($wxtConfig.Name)``) with no production build in ``.output/``: run the build, then ``/refresh-context``.")
        }
    }
}

# ── Emit ────────────────────────────────────────────────────────────────────
$body = [System.Text.StringBuilder]::new()
$totals = @{ Blocker = 0; Warning = 0; Note = 0 }

function Add-Finding([string] $Severity, [string] $Scope, [string] $Text) {
    # Appends to the current manifest's $findings list, which the loop below
    # rebinds per manifest; PowerShell resolves it from the caller's scope.
    $findings.Add([pscustomobject]@{ Severity = $Severity; Scope = $Scope; Text = $Text })
}

foreach ($entry in $manifests) {
    $m = $entry.Manifest
    $findings = [List[object]]::new()
    $applicable = @($targets | Where-Object { -not $entry.OnlyBrowser -or $_.Browser -eq $entry.OnlyBrowser })
    $fx = $applicable | Where-Object Browser -eq 'firefox' | Select-Object -First 1
    $cr = $applicable | Where-Object Browser -eq 'chrome' | Select-Object -First 1

    $heading = "## ``$($entry.RelPath)``"
    if ($entry.Built) { $heading += ' (built output; regenerate after the build)' }
    $null = $body.AppendLine($heading)
    $null = $body.AppendLine('')
    if ($applicable.Count) {
        $null = $body.AppendLine("Checked against: $((@($applicable | ForEach-Object { Format-Target $_ })) -join ', ').")
    }
    else {
        $null = $body.AppendLine("Built for $($entry.OnlyBrowser), which is not a target in ``$targetsSource``; browser checks skipped.")
    }
    $null = $body.AppendLine('')

    # ---- Identity ----------------------------------------------------------
    $mv = Get-Val $m @('manifest_version')
    $isMv3 = "$mv" -eq '3'
    $geckoId = Get-Val $m @('browser_specific_settings', 'gecko', 'id')
    $geckoMin = Get-Val $m @('browser_specific_settings', 'gecko', 'strict_min_version')
    $chromeMin = Get-Val $m @('minimum_chrome_version')
    $dcp = Get-Val $m @('browser_specific_settings', 'gecko', 'data_collection_permissions')
    $dcpText = if ($dcp -is [System.Collections.IDictionary]) {
        "required: $(Format-CodeList (Get-Val $dcp @('required'))); optional: $(Format-CodeList (Get-Val $dcp @('optional')))"
    } else { '—' }

    $null = $body.AppendLine('| Field | Value |')
    $null = $body.AppendLine('| ----- | ----- |')
    $null = $body.AppendLine("| Name | $(Format-Code (Get-Val $m @('name'))) |")
    $null = $body.AppendLine("| Version | $(Format-Code (Get-Val $m @('version'))) |")
    $null = $body.AppendLine("| Manifest version | $(Format-Code "$mv") |")
    $null = $body.AppendLine("| Default locale | $(Format-Code (Get-Val $m @('default_locale'))) |")
    $null = $body.AppendLine("| Firefox id (gecko) | $(Format-Code $geckoId) |")
    $null = $body.AppendLine("| Firefox min version | $(Format-Code $geckoMin) |")
    $null = $body.AppendLine("| Firefox data collection | $dcpText |")
    $null = $body.AppendLine("| Chrome min version | $(Format-Code $chromeMin) |")
    $null = $body.AppendLine('')

    # ---- Background --------------------------------------------------------
    $background = Get-Val $m @('background')
    $swPath = Get-Val $m @('background', 'service_worker')
    $bgScripts = Get-Array (Get-Val $m @('background', 'scripts'))
    $bgType = Get-Val $m @('background', 'type')

    $null = $body.AppendLine('### Background')
    $null = $body.AppendLine('')
    if (-not $background) {
        $null = $body.AppendLine('_No background declared._')
    }
    else {
        $null = $body.AppendLine("- Service worker (Chrome): $(Format-Code $swPath)")
        $null = $body.AppendLine("- Scripts (Firefox event page): $(Format-CodeList $bgScripts)")
        $null = $body.AppendLine("- Module type: $(Format-Code $bgType)")
    }
    $null = $body.AppendLine('')

    # ---- Permissions -------------------------------------------------------
    $perms = Get-Array (Get-Val $m @('permissions'))
    $optPerms = Get-Array (Get-Val $m @('optional_permissions'))
    $hostPerms = Get-Array (Get-Val $m @('host_permissions'))
    $optHostPerms = Get-Array (Get-Val $m @('optional_host_permissions'))
    $allPerms = @($perms) + @($optPerms)

    $null = $body.AppendLine('### Permissions')
    $null = $body.AppendLine('')
    $null = $body.AppendLine("- Required: $(Format-CodeList $perms)")
    $null = $body.AppendLine("- Optional: $(Format-CodeList $optPerms)")
    $null = $body.AppendLine("- Host (required): $(Format-CodeList $hostPerms)")
    $null = $body.AppendLine("- Host (optional): $(Format-CodeList $optHostPerms)")
    $null = $body.AppendLine('')

    # ---- Content scripts ---------------------------------------------------
    $contentScripts = Get-Array (Get-Val $m @('content_scripts'))
    $null = $body.AppendLine('### Content scripts')
    $null = $body.AppendLine('')
    if (-not $contentScripts.Count) {
        $null = $body.AppendLine('_None declared._')
    }
    else {
        $null = $body.AppendLine('| Matches | Run at | All frames | World | JS | CSS |')
        $null = $body.AppendLine('| ------- | ------ | ---------- | ----- | -- | --- |')
        foreach ($cs in $contentScripts) {
            $row = @(
                (Format-CodeList (Get-Val $cs @('matches')))
                (Format-Code (Get-Val $cs @('run_at')))
                (Format-Code "$(Get-Val $cs @('all_frames'))")
                (Format-Code (Get-Val $cs @('world')))
                (Format-CodeList (Get-Val $cs @('js')))
                (Format-CodeList (Get-Val $cs @('css')))
            ) -join ' | '
            $null = $body.AppendLine("| $row |")
        }
    }
    $null = $body.AppendLine('')

    # ---- UI surfaces -------------------------------------------------------
    $null = $body.AppendLine('### UI surfaces')
    $null = $body.AppendLine('')
    $null = $body.AppendLine('| Surface | Value |')
    $null = $body.AppendLine('| ------- | ----- |')
    $null = $body.AppendLine("| Action popup | $(Format-Code (Get-Val $m @('action', 'default_popup'))) |")
    $null = $body.AppendLine("| Options page | $(Format-Code ((Get-Val $m @('options_ui', 'page')) ?? (Get-Val $m @('options_page')))) |")
    $null = $body.AppendLine("| Sidebar (Firefox) | $(Format-Code (Get-Val $m @('sidebar_action', 'default_panel'))) |")
    $null = $body.AppendLine("| Side panel (Chrome) | $(Format-Code (Get-Val $m @('side_panel', 'default_path'))) |")
    $null = $body.AppendLine("| Page action (Firefox) | $(Format-Code "$(if (Get-Val $m @('page_action')) { 'declared' } else { $null })") |")
    $null = $body.AppendLine("| DevTools page | $(Format-Code (Get-Val $m @('devtools_page'))) |")
    $null = $body.AppendLine("| Omnibox keyword | $(Format-Code (Get-Val $m @('omnibox', 'keyword'))) |")
    $null = $body.AppendLine('')

    # ---- Commands ----------------------------------------------------------
    $commands = Get-Val $m @('commands')
    $null = $body.AppendLine('### Commands')
    $null = $body.AppendLine('')
    if (-not $commands -or -not @($commands.Keys).Count) {
        $null = $body.AppendLine('_None declared._')
    }
    else {
        $null = $body.AppendLine('| Command | Default shortcut | Description |')
        $null = $body.AppendLine('| ------- | ---------------- | ----------- |')
        foreach ($name in (@($commands.Keys) | Sort-Object)) {
            $cmd = $commands[$name]
            $key = Get-Val $cmd @('suggested_key', 'default')
            $desc = Get-Val $cmd @('description')
            $null = $body.AppendLine("| $(Format-Code $name) | $(Format-Code $key) | $(if ($desc) { $desc } else { '—' }) |")
        }
    }
    $null = $body.AppendLine('')

    # ---- Web-accessible resources, network, CSP, connectivity --------------
    $war = Get-Array (Get-Val $m @('web_accessible_resources'))
    $null = $body.AppendLine('### Web-accessible resources')
    $null = $body.AppendLine('')
    if (-not $war.Count) {
        $null = $body.AppendLine('_None declared._')
    }
    else {
        $null = $body.AppendLine('| Resources | Exposed to |')
        $null = $body.AppendLine('| --------- | ---------- |')
        foreach ($w in $war) {
            if ($w -is [System.Collections.IDictionary]) {
                $res = Format-CodeList (Get-Val $w @('resources'))
                $to = Format-CodeList (Get-Val $w @('matches'))
            }
            else { $res = Format-Code "$w"; $to = '_(MV2 shape — all pages)_' }
            $null = $body.AppendLine("| $res | $to |")
        }
    }
    $null = $body.AppendLine('')

    $dnr = Get-Array (Get-Val $m @('declarative_net_request', 'rule_resources'))
    $csp = Get-Val $m @('content_security_policy', 'extension_pages')
    $extConn = Get-Val $m @('externally_connectable', 'matches')

    $null = $body.AppendLine('### Network, CSP, and connectivity')
    $null = $body.AppendLine('')
    if ($dnr.Count) {
        $null = $body.AppendLine('| Rule set | Enabled | Path |')
        $null = $body.AppendLine('| -------- | ------- | ---- |')
        foreach ($r in $dnr) {
            $null = $body.AppendLine("| $(Format-Code (Get-Val $r @('id'))) | $(Format-Code "$(Get-Val $r @('enabled'))") | $(Format-Code (Get-Val $r @('path'))) |")
        }
        $null = $body.AppendLine('')  # a table must not butt against the bullets
    }
    else {
        $null = $body.AppendLine('- Declarative net request rule sets: _(none)_')
    }
    $null = $body.AppendLine("- Extension-pages CSP: $(Format-Code $csp)")
    $null = $body.AppendLine("- Externally connectable: $(Format-CodeList $extConn)")
    $null = $body.AppendLine('')

    # ---- Checks: every target ----------------------------------------------
    if (-not $isMv3) {
        if ($cr) { Add-Finding 'Blocker' 'Chrome' "Manifest V$mv. Chrome stopped running MV2 extensions after version 138." }
        if ($fx) { Add-Finding 'Note' 'Firefox' "Manifest V$mv. Firefox still supports MV2, but these conventions assume MV3; record the choice in an ADR." }
    }
    if ($isMv3 -and (Get-Val $m @('background', 'persistent')) -eq $true) {
        Add-Finding 'Blocker' '' '`background.persistent: true` is invalid in MV3; every MV3 background is non-persistent.'
    }
    # Match patterns sitting in `permissions` are the MV2 shape.
    $strayHosts = @($perms | Where-Object { $_ -match '^(<all_urls>|\*://|https?://|file://|ftp://)' })
    if ($strayHosts.Count) {
        Add-Finding 'Warning' '' "Match pattern(s) in ``permissions``: $(Format-CodeList $strayHosts). In MV3 these belong in ``host_permissions``."
    }
    if ($hostPerms -contains '<all_urls>') {
        Add-Finding 'Warning' '' '`<all_urls>` host permission triggers the strictest review in both stores. Narrow it, or move it to `optional_host_permissions` and request it at runtime.'
    }
    foreach ($w in $war) {
        if ($w -is [System.Collections.IDictionary] -and (Get-Array (Get-Val $w @('matches'))) -contains '<all_urls>') {
            Add-Finding 'Warning' '' 'A `web_accessible_resources` entry is exposed to `<all_urls>`, so any page can probe for the extension. Narrow `matches`.'
            break
        }
    }
    # 'wasm-unsafe-eval' is the one relaxation MV3 allows, and its name
    # contains 'unsafe-eval', so strip it before looking for real relaxations.
    if ($csp -and (($csp -replace "'wasm-unsafe-eval'", '') -match "'unsafe-eval'|'unsafe-inline'|https?:")) {
        Add-Finding 'Warning' '' 'The extension-pages CSP is relaxed beyond `''self''` and `''wasm-unsafe-eval''`. MV3 forbids remote code; record the threat model in an ADR.'
    }
    if (Get-Val $m @('browser_action')) {
        Add-Finding 'Warning' '' '`browser_action` is the MV2 key. MV3 uses `action`.'
    }

    # ---- Checks: Firefox ---------------------------------------------------
    if ($fx) {
        if (-not $geckoId) {
            if ($isMv3) { Add-Finding 'Blocker' 'Firefox' 'No `browser_specific_settings.gecko.id`. AMO requires an explicit id to sign an MV3 extension.' }
            else { Add-Finding 'Note' 'Firefox' 'No `browser_specific_settings.gecko.id`. AMO assigns one to an MV2 extension, but an explicit id keeps updates and storage stable.' }
        }
        if (-not ($dcp -is [System.Collections.IDictionary])) {
            Add-Finding 'Blocker' 'Firefox' 'No `browser_specific_settings.gecko.data_collection_permissions`. It is required for every extension first submitted after 2025-11-03; declare `{ "required": ["none"] }` when no data leaves the browser.'
        }
        else {
            $required = Get-Array (Get-Val $dcp @('required'))
            if (-not $required.Count) {
                Add-Finding 'Warning' 'Firefox' '`data_collection_permissions` has no `required` list. Declare `["none"]` when no data leaves the browser.'
            }
            if ($required -contains 'none' -and $required.Count -gt 1) {
                Add-Finding 'Blocker' 'Firefox' '`"none"` must be the only `required` data-collection entry.'
            }
            if ($required -contains 'technicalAndInteraction') {
                Add-Finding 'Blocker' 'Firefox' '`technicalAndInteraction` may only be listed under `optional`.'
            }
        }
        if ($null -ne $fx.Floor) {
            $minFx = Get-Major $geckoMin
            if ($null -eq $minFx) {
                Add-Finding 'Warning' 'Firefox' "No ``strict_min_version``. Set it to ``""$($fx.Floor).0""`` so Firefox refuses older versions and ``web-ext lint`` checks APIs against the floor."
            }
            elseif ($minFx -lt $fx.Floor) {
                Add-Finding 'Warning' 'Firefox' "``strict_min_version`` $geckoMin is below the target floor ($($fx.Floor)); the manifest admits Firefox versions the code is not written for."
            }
            elseif ($minFx -gt $fx.Floor) {
                Add-Finding 'Note' 'Firefox' "``strict_min_version`` $geckoMin is above the target floor ($($fx.Floor)). Raise the floor in ``$targetsSource`` or lower the manifest."
            }
        }
        if ($swPath -and -not $bgScripts.Count) {
            Add-Finding 'Blocker' 'Firefox' 'The background declares `service_worker` without `scripts`. Firefox does not run background service workers, so it would load no background at all.'
        }
        elseif ($swPath -and $applicable.Count -eq 1) {
            Add-Finding 'Note' 'Firefox' 'The background declares both `service_worker` and `scripts`; Firefox uses `scripts` and ignores `service_worker`, so a Firefox-only manifest can drop it.'
        }
        if ($perms -contains 'userScripts') {
            Add-Finding 'Blocker' 'Firefox' '`userScripts` is optional-only in Firefox. Move it to `optional_permissions` and request it, alone, from a user action.'
        }
        if ((Get-Val $m @('incognito')) -eq 'split') {
            Add-Finding 'Warning' 'Firefox' '`incognito: "split"` is not supported; Firefox treats it as `not_allowed`.'
        }
        foreach ($k in $firefoxUnsupportedKeys.Keys) {
            if ($null -ne (Get-Val $m ($k -split '\.'))) {
                Add-Finding $firefoxUnsupportedKeys[$k][0] 'Firefox' "``$k`` is $($firefoxUnsupportedKeys[$k][1])"
            }
        }
        foreach ($w in $war) {
            if ($w -is [System.Collections.IDictionary] -and $w.Contains('use_dynamic_url')) {
                Add-Finding 'Note' 'Firefox' '`web_accessible_resources[].use_dynamic_url` is Chrome-only; Firefox ignores it.'
                break
            }
        }
        foreach ($p in $firefoxUnsupportedPermissions.Keys) {
            if ($allPerms -contains $p) { Add-Finding 'Warning' 'Firefox' "Permission ``$p`` is $($firefoxUnsupportedPermissions[$p])" }
        }
        if ($null -ne (Get-Val $m @('browser_specific_settings', 'gecko_android'))) {
            Add-Finding 'Note' 'Firefox' 'Listed for Firefox for Android (`gecko_android`). `menus`, `commands`, `sidebarAction`, and several other desktop APIs are missing there.'
        }
    }

    # ---- Checks: Chrome ----------------------------------------------------
    if ($cr) {
        if ($isMv3 -and $background -and -not $swPath) {
            Add-Finding 'Blocker' 'Chrome' 'The background declares no `service_worker`. Chrome MV3 runs only a service worker; `background.scripts` is MV2-only there.'
        }
        elseif ($swPath -and $bgScripts.Count -and $applicable.Count -eq 1) {
            Add-Finding 'Note' 'Chrome' 'The background declares both `service_worker` and `scripts`; Chrome ignores `scripts`, so a Chrome-only manifest can drop it.'
        }
        if ($null -ne $cr.Floor) {
            $minCr = Get-Major $chromeMin
            if ($null -eq $minCr) {
                Add-Finding 'Warning' 'Chrome' "No ``minimum_chrome_version``. Set it to ``""$($cr.Floor)""``: users below it cannot install, and the ``browser`` namespace needs 148 or later."
            }
            elseif ($minCr -lt $cr.Floor) {
                Add-Finding 'Warning' 'Chrome' "``minimum_chrome_version`` $chromeMin is below the target floor ($($cr.Floor)); the manifest admits Chrome versions the code is not written for."
            }
            elseif ($minCr -gt $cr.Floor) {
                Add-Finding 'Note' 'Chrome' "``minimum_chrome_version`` $chromeMin is above the target floor ($($cr.Floor)). Raise the floor in ``$targetsSource`` or lower the manifest; users below it silently stop receiving updates."
            }
        }
        foreach ($k in $chromeUnsupportedKeys.Keys) {
            if ($null -ne (Get-Val $m ($k -split '\.'))) {
                Add-Finding $chromeUnsupportedKeys[$k][0] 'Chrome' "``$k`` is $($chromeUnsupportedKeys[$k][1])"
            }
        }
        foreach ($p in $chromeUnsupportedPermissions.Keys) {
            if ($allPerms -contains $p) { Add-Finding 'Warning' 'Chrome' "Permission ``$p`` is $($chromeUnsupportedPermissions[$p])" }
        }
        if ($allPerms -contains 'webRequestBlocking') {
            Add-Finding 'Warning' 'Chrome' '`webRequestBlocking` works in Chrome MV3 only for policy-installed extensions. Move blocking behavior to `declarativeNetRequest`.'
        }
    }

    # ---- Checks: version-gated features ------------------------------------
    foreach ($g in $versionGated) {
        $t = if ($g.Browser -eq 'firefox') { $fx } else { $cr }
        if (-not $t -or $null -eq $t.Floor -or $t.Floor -ge $g.Since) { continue }
        $present = if ($g.Kind -eq 'key') { $null -ne (Get-Val $m ($g.Name -split '\.')) }
                   else { $allPerms -contains $g.Name }
        if ($present) {
            $browserName = if ($g.Browser -eq 'firefox') { 'Firefox' } else { 'Chrome' }
            $scope = if ($g.Browser -eq 'firefox') { 'Firefox' } else { 'Chrome' }
            Add-Finding 'Warning' $scope "``$($g.Name)`` needs $browserName $($g.Since); this project's floor is $($t.Floor). Feature-detect it or raise the floor."
        }
    }

    # ---- Findings ----------------------------------------------------------
    $null = $body.AppendLine('### Findings')
    $null = $body.AppendLine('')
    if (-not $findings.Count) {
        $null = $body.AppendLine('_No findings._')
    }
    else {
        foreach ($severity in @('Blocker', 'Warning', 'Note')) {
            foreach ($f in @($findings | Where-Object Severity -eq $severity)) {
                $label = if ($f.Scope) { "$($f.Severity) ($($f.Scope))" } else { $f.Severity }
                $null = $body.AppendLine("- **${label}:** $($f.Text)")
                $totals[$severity]++
            }
        }
        if ($fx -and $cr) {
            $null = $body.AppendLine('')
            $null = $body.AppendLine('_This manifest serves both targets. Generating one manifest per browser (see "Adding or changing a target browser" in `browser-extension-style.md`) removes most cross-browser findings._')
        }
    }
    $null = $body.AppendLine('')
}

# ── Assemble ────────────────────────────────────────────────────────────────
$sb = [System.Text.StringBuilder]::new()
$null = $sb.AppendLine('<!-- GENERATED FILE — DO NOT EDIT — regenerated by Context/scripts/regenerate-manifest-index.ps1 -->')
$null = $sb.AppendLine('<!-- Source: every manifest*.json in the repo declaring manifest_version (build output and node_modules excluded), or WXT''s .output/ build when there is none -->')
$null = $sb.AppendLine("<!-- Last run: $(Get-Date -AsUTC -Format 'yyyy-MM-ddTHH:mm:ssZ') -->")
$null = $sb.AppendLine('')
$null = $sb.AppendLine('# Extension Manifest Index')
$null = $sb.AppendLine('')
$null = $sb.AppendLine("Targets (from ``$targetsSource``): $((@($targets | ForEach-Object { Format-Target $_ })) -join ', ').")
$null = $sb.AppendLine('')
if ($setupNotes.Count) {
    foreach ($n in $setupNotes) { $null = $sb.AppendLine("- $n") }
    $null = $sb.AppendLine('')
}

if (-not $manifests.Count) {
    $null = $sb.AppendLine('_No WebExtension manifest found._ Either the extension has not been scaffolded yet, or the manifest lives under an excluded directory (check `$excludePathPattern` in the regenerator).')
}
else {
    $null = $sb.AppendLine("$($manifests.Count) manifest(s): $($totals.Blocker) blocker(s), $($totals.Warning) warning(s), $($totals.Note) note(s). Permissions, host permissions, content-script matches, and web-accessible resources are **public surface**: a change to any of them alters the install prompt and the store review.")
    $null = $sb.AppendLine('')
    $null = $sb.Append($body.ToString())
}

$null = [Directory]::CreateDirectory([Path]::GetDirectoryName($outPath))
[File]::WriteAllText($outPath, $sb.ToString().TrimEnd("`r", "`n").Replace("`r`n", "`n") + "`n", [System.Text.UTF8Encoding]::new($false))
Write-Host "manifest-index: $($manifests.Count) manifest(s), $($totals.Blocker) blocker(s), $($totals.Warning) warning(s) -> Context/generated/manifest-index.md"
exit 0
