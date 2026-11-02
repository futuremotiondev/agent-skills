#Requires -Version 7.1
using namespace System.IO
using namespace System.Collections.Generic

<#
.SYNOPSIS
    Regenerates Context/generated/obsidian-manifest-index.md — an inventory of
    every Obsidian plugin in the repo (manifest, versions.json, package.json,
    and the surface its source registers) with a release-readiness report.

.DESCRIPTION
    Seeded by the context-engine obsidian-plugin adapter; project-owned — tune
    the exclusions, the fact tables, or the checks freely.

    A plugin root is a directory holding a manifest.json that parses, declares
    "id" and "minAppVersion", and has neither "manifest_version" (a WebExtension
    manifest) nor "editorType"/"api" (a Figma manifest). Theme manifests have no
    "id" and are skipped.

    For each plugin it reports the manifest, the versions.json floor map, the
    package.json version and build script, and a best-effort scan of the source
    for registered surface: commands, views, Bases views, the settings tab,
    ribbon icons, status-bar items, Markdown processors, editor extensions and
    suggests, CLI handlers, obsidian:// actions, and file extensions. The scan
    resolves string literals and same-repo string constants only, and does not
    skip comments.

    The validation report is the point. It flags what the Community directory
    blocks (string execution, HTML injection, <style>/<link> elements, regex
    lookbehind outside desktop-only plugins), the documented manifest and
    release requirements, APIs above the project's minAppVersion, deprecated
    APIs, and review-guideline problems.

    Contract (Context/scripts/README.md): standalone, fast, writes exactly one
    banner-prefixed artifact into Context/generated/.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR }
            else { (Get-Location).ProviderPath }
$outPath = [Path]::Combine($repoRoot, 'Context', 'generated', 'obsidian-manifest-index.md')

# Directory names never descended into (matched case-sensitively, so a
# src/context/ folder is still scanned). ".obsidian" keeps a test vault's
# installed copy of the plugin from being counted as a second plugin;
# ".obsidian-cache" is wdio-obsidian-service's download cache.
$prunedDirPattern =
    '^(\.git|\.claude|Context|node_modules|dist|build|out|coverage|' +
    '\.vite|\.parcel-cache|\.obsidian|\.obsidian-cache)$'

# Source files that are not plugin code: tests, build and tool configs.
$excludeSourcePattern =
    '([\\/](tests?|e2e|__tests__|__mocks__)[\\/])|' +
    '([\\/](esbuild|vite|rollup|eslint|vitest|jest|wdio)\.config\.[^\\/]+$)|' +
    '([\\/]version-bump\.[^\\/]+$)|(\.(test|spec)\.[^\\/]+$)|(\.d\.ts$)'

# ── Fact tables (refresh with obsidian-plugin-style.md) ────────────────────

$documentedKeys = @('id', 'name', 'version', 'minAppVersion', 'description',
                    'author', 'authorUrl', 'fundingUrl', 'isDesktopOnly')

# APIs newer than some floors. A use above the project's minAppVersion needs a
# requireApiVersion() guard or a raised floor. eslint-plugin-obsidianmd's
# no-unsupported-api pins older typings and misses the 1.13 rows.
$gatedApis = @(
    @{ Pattern = '\bregisterBasesView\s*\(';        Api = 'registerBasesView()';              Since = '1.10.0' }
    @{ Pattern = '\bnew\s+SettingGroup\s*\(';       Api = 'SettingGroup';                     Since = '1.11.0' }
    @{ Pattern = '\bsecretStorage\b';               Api = 'app.secretStorage';                Since = '1.11.4' }
    @{ Pattern = '\bregisterCliHandler\s*\(';       Api = 'registerCliHandler()';             Since = '1.12.2' }
    @{ Pattern = '\bappendBinary\s*\(';             Api = 'Vault.appendBinary()';             Since = '1.12.3' }
    @{ Pattern = '\bgetSettingDefinitions\s*\(';    Api = 'getSettingDefinitions()';          Since = '1.13.0' }
    @{ Pattern = '\bsetDestructive\s*\(';           Api = 'ButtonComponent.setDestructive()'; Since = '1.13.0' }
    @{ Pattern = '\baddDisplayValue\s*\(';          Api = 'Setting.addDisplayValue()';        Since = '1.13.1' }
    @{ Pattern = 'type\s*:\s*[''"]secret[''"]';     Api = "the 'secret' setting control";     Since = '1.13.2' }
)

$deprecatedApis = @(
    @{ Pattern = '\bworkspace\.activeLeaf\b';       Message = '`workspace.activeLeaf` is deprecated; use `getActiveViewOfType()` or `getActiveFile()`.' }
    @{ Pattern = '\.renderMarkdown\s*\(';           Message = '`MarkdownRenderer.renderMarkdown()` is deprecated; use `MarkdownRenderer.render()`.' }
    @{ Pattern = '\.setWarning\s*\(';               Message = '`ButtonComponent.setWarning()` is deprecated; use `setDestructive()`.' }
    @{ Pattern = '\.setDynamicTooltip\s*\(';        Message = '`SliderComponent.setDynamicTooltip()` is deprecated; the value is always shown.' }
    @{ Pattern = '\.noticeEl\b';                    Message = '`Notice.noticeEl` is deprecated; use `messageEl`.' }
    @{ Pattern = '\b(splitActiveLeaf|getUnpinnedLeaf)\s*\('; Message = '`splitActiveLeaf()` / `getUnpinnedLeaf()` are deprecated; use `getLeaf()`.' }
)

# The rules the Community directory scan keeps as errors.
$blockingPatterns = @(
    @{ Pattern = '(?<![\w$.])eval\s*\(|\bnew\s+Function\s*\(|\bset(Timeout|Interval)\s*\(\s*[''"`]'
       Message = 'String execution (`eval`, `new Function`, or a string timer).' }
    @{ Pattern = '\.(innerHTML|outerHTML)\s*\+?=(?!=)|\binsertAdjacentHTML\s*\('
       Message = 'HTML string injection (`innerHTML`, `outerHTML`, `insertAdjacentHTML`); build DOM with `createEl()`.' }
    @{ Pattern = 'create(El|Element)\s*\(\s*[''"](style|link)[''"]'
       Message = 'A `<style>` or `<link>` element; put styles in `styles.css`.' }
    @{ Pattern = '\(\?<[=!]'
       Message = 'Regex lookbehind (iOS below 16.4 lacks it); allowed only when `isDesktopOnly` is true.'
       DesktopOnlyExempt = $true }
)

$guidelinePatterns = @(
    @{ Pattern = '(?<![\w$.])fetch\s*\(';                Message = '`fetch()`; use `requestUrl()`.' }
    @{ Pattern = '\bconsole\.log\s*\(';                  Message = '`console.log` in shipped code; use `console.debug` or remove it.' }
    @{ Pattern = '\.style\.[A-Za-z]+\s*=(?!=)';          Message = 'Inline style assignment; use a CSS class, or `setCssProps()` for a custom property.' }
    @{ Pattern = '[''"`/]\.obsidian[/''"`]';             Message = 'Hardcoded `.obsidian`; use `vault.configDir`.' }
    @{ Pattern = '\bvault\.(delete|trash)\s*\(';         Message = 'Deleting through the Vault; use `FileManager.trashFile()`.' }
    @{ Pattern = '\bnavigator\.(userAgent|platform)\b';  Message = 'Platform sniffing; use `Platform`.' }
    @{ Pattern = '(?<![\w$.])localStorage\.';            Message = 'Raw `localStorage` is shared by every vault; use `App.saveLocalStorage()` / `loadLocalStorage()`.' }
)

$checkPatterns = @(
    @{ Pattern = '\bdetachLeavesOfType\s*\(';            Message = '`detachLeavesOfType()`: make sure it is not called from `onunload()`.' }
)

# ── Helpers ─────────────────────────────────────────────────────────────────

function Get-ScannedFile {
    # Full paths of files under $Root whose name matches $NamePattern. Prunes
    # excluded directories and skips reparse points (a build-output symlink
    # into a test vault) instead of recursing into everything and filtering
    # afterwards: node_modules alone can hold tens of thousands of files.
    param([Parameter(Mandatory)] [string] $Root, [Parameter(Mandatory)] [string] $NamePattern)
    $found = [List[string]]::new()
    $pending = [Stack[string]]::new()
    $pending.Push($Root)
    while ($pending.Count) {
        $dir = $pending.Pop()
        try {
            foreach ($f in [Directory]::EnumerateFiles($dir)) {
                if ([Path]::GetFileName($f) -match $NamePattern) { $found.Add($f) }
            }
            foreach ($sub in [Directory]::EnumerateDirectories($dir)) {
                if ([Path]::GetFileName($sub) -cmatch $prunedDirPattern) { continue }
                if ([File]::GetAttributes($sub).HasFlag([FileAttributes]::ReparsePoint)) { continue }
                $pending.Push($sub)
            }
        }
        catch [UnauthorizedAccessException], [IOException] { continue }
    }
    $sorted = @($found | Sort-Object)
    return , $sorted
}

function Get-Val {
    # Safe nested lookup: Get-Val $manifest @('fundingUrl')
    param([Parameter(Mandatory)] $Table, [Parameter(Mandatory)] [string[]] $Path)
    $node = $Table
    foreach ($key in $Path) {
        if ($node -isnot [System.Collections.IDictionary]) { return $null }
        if (-not $node.Contains($key)) { return $null }
        $node = $node[$key]
    }
    return $node
}

function Format-Code {
    param([AllowEmptyString()] [AllowNull()] [string] $Text)
    if ([string]::IsNullOrEmpty($Text)) { return '—' }
    return '`' + $Text.Replace('|', '\|') + '`'
}

function Format-Cell {
    param([AllowEmptyString()] [AllowNull()] [string] $Text)
    if ([string]::IsNullOrEmpty($Text)) { return '—' }
    return $Text.Replace('|', '\|').Replace("`r", ' ').Replace("`n", ' ')
}

function ConvertTo-AppVersion {
    # [version] for an x.y.z string, $null for anything else (e.g. a beta tag).
    param([AllowNull()] $Value)
    if ($Value -isnot [string] -or $Value -notmatch '^\d+\.\d+\.\d+$') { return $null }
    return [version]$Value
}

function Read-JsonFile {
    # Parsed hashtable, $null when absent, or the string 'unparsable'.
    param([Parameter(Mandatory)] [string] $Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    try {
        return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 |
            ConvertFrom-Json -AsHashtable -Depth 32
    }
    catch { return 'unparsable' }
}

function Get-LineNumber {
    param([Parameter(Mandatory)] [string] $Text, [Parameter(Mandatory)] [int] $Index)
    $line = 1
    for ($i = 0; $i -lt $Index; $i++) { if ($Text[$i] -eq "`n") { $line++ } }
    return $line
}

function Find-CallEnd {
    # Index of the ')' closing the '(' at $Open. Skips string literals and
    # comments. Regex literals and ${...} inside template literals are not
    # parsed, so a stray paren there can end the span early or late; good
    # enough for an inventory.
    param([Parameter(Mandatory)] [string] $Text, [Parameter(Mandatory)] [int] $Open)
    $depth = 0
    $n = $Text.Length
    $i = $Open
    while ($i -lt $n) {
        $c = $Text[$i]
        if ($c -eq '/' -and $i + 1 -lt $n) {
            $next = $Text[$i + 1]
            if ($next -eq '/') {
                $j = $Text.IndexOf("`n", $i)
                if ($j -lt 0) { return $n - 1 }
                $i = $j + 1; continue
            }
            if ($next -eq '*') {
                $j = $Text.IndexOf('*/', $i + 2)
                if ($j -lt 0) { return $n - 1 }
                $i = $j + 2; continue
            }
        }
        if ($c -eq "'" -or $c -eq '"' -or $c -eq '`') {
            $i++
            while ($i -lt $n -and $Text[$i] -ne $c) {
                if ($Text[$i] -eq '\') { $i++ }
                $i++
            }
            $i++; continue
        }
        if ($c -eq '(') { $depth++ }
        elseif ($c -eq ')') {
            $depth--
            if ($depth -eq 0) { return $i }
        }
        $i++
    }
    return $n - 1
}

function Split-CallArgs {
    # Splits a call's argument text on top-level commas.
    param([AllowEmptyString()] [string] $ArgText)
    $parts = [List[string]]::new()
    $depth = 0
    $start = 0
    $n = $ArgText.Length
    $i = 0
    while ($i -lt $n) {
        $c = $ArgText[$i]
        if ($c -eq "'" -or $c -eq '"' -or $c -eq '`') {
            $i++
            while ($i -lt $n -and $ArgText[$i] -ne $c) {
                if ($ArgText[$i] -eq '\') { $i++ }
                $i++
            }
            $i++; continue
        }
        if ('([{'.Contains($c)) { $depth++ }
        elseif (')]}'.Contains($c)) { $depth-- }
        elseif ($c -eq ',' -and $depth -eq 0) {
            $parts.Add($ArgText.Substring($start, $i - $start).Trim())
            $start = $i + 1
        }
        $i++
    }
    $tail = $ArgText.Substring([Math]::Min($start, $n)).Trim()
    if ($tail) { $parts.Add($tail) }
    $result = $parts.ToArray()
    return , $result
}

function Resolve-Arg {
    # A string literal's value, a same-repo string constant's value, or the
    # expression in parentheses.
    param([AllowEmptyString()] [AllowNull()] [string] $Arg, [hashtable] $Constants = @{})
    if ([string]::IsNullOrWhiteSpace($Arg)) { return $null }
    $t = $Arg.Trim()
    if ($t -match '^([''"`])((?:\\.|(?!\1).)*)\1$') { return $Matches[2] }
    if ($t -match '^[A-Za-z_$][\w$]*(\.[A-Za-z_$][\w$]*)*$') {
        $last = ($t -split '\.')[-1]
        if ($Constants.ContainsKey($last)) { return $Constants[$last] }
    }
    if ($t.Length -gt 40) { $t = $t.Substring(0, 37) + '...' }
    return "($t)"
}

function Get-PropertyArg {
    # The value text of the first "<name>:" property in an object literal.
    param([AllowEmptyString()] [string] $ObjectText, [Parameter(Mandatory)] [string] $Name)
    $m = [regex]::Match($ObjectText, '(?<![\w$])' + $Name + '\s*:\s*')
    if (-not $m.Success) { return $null }
    $rest = $ObjectText.Substring($m.Index + $m.Length)
    $parts = Split-CallArgs -ArgText $rest
    if (-not $parts.Count) { return $null }
    return $parts[0]
}

function Test-TitleCase {
    # True for "Open Daily Note" (every later word capitalized), false for
    # sentence case with proper nouns such as "Open in GitHub".
    param([AllowNull()] [string] $Text)
    if ([string]::IsNullOrWhiteSpace($Text) -or $Text.StartsWith('(')) { return $false }
    $words = @($Text -split '\s+' | Where-Object { $_ -match '^[A-Za-z]' })
    if ($words.Count -lt 3) { return $false }
    $later = @($words | Select-Object -Skip 1)
    $capitalized = @($later | Where-Object { $_ -cmatch '^[A-Z][a-z]' })
    return $capitalized.Count -eq $later.Count
}

function Format-Locations {
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [List[string]] $Locations)
    $shown = @($Locations | Select-Object -First 5 | ForEach-Object { '`' + $_ + '`' })
    $text = $shown -join ', '
    if ($Locations.Count -gt 5) { $text += " (and $($Locations.Count - 5) more)" }
    return $text
}

# ── Discover plugins ────────────────────────────────────────────────────────

$plugins = [List[object]]::new()

$candidates = Get-ScannedFile -Root $repoRoot -NamePattern '^manifest\.json$'

foreach ($path in $candidates) {
    $json = Read-JsonFile -Path $path
    if ($json -isnot [System.Collections.IDictionary]) { continue }
    if ($json.Contains('manifest_version')) { continue }                  # WebExtension
    if ($json.Contains('editorType') -or $json.Contains('api')) { continue }  # Figma
    if (-not ($json.Contains('id') -and $json.Contains('minAppVersion'))) { continue }  # theme or other

    $plugins.Add([pscustomobject]@{
        Root     = [Path]::GetDirectoryName($path)
        RelPath  = ($path.Substring($repoRoot.Length).TrimStart('\', '/') -replace '\\', '/')
        Manifest = $json
    })
}

# ── Emit ────────────────────────────────────────────────────────────────────

$sb = [System.Text.StringBuilder]::new()
$null = $sb.AppendLine('<!-- GENERATED FILE — DO NOT EDIT — regenerated by Context/scripts/regenerate-obsidian-manifest-index.ps1 -->')
$null = $sb.AppendLine('<!-- Source: every Obsidian plugin manifest.json in the repo, its versions.json and package.json, and its source (build output, tests, and node_modules excluded) -->')
$null = $sb.AppendLine("<!-- Last run: $(Get-Date -AsUTC -Format 'yyyy-MM-ddTHH:mm:ssZ') -->")
$null = $sb.AppendLine('')
$null = $sb.AppendLine('# Obsidian Plugin Manifest Index')
$null = $sb.AppendLine('')

if (-not $plugins.Count) {
    $null = $sb.AppendLine('_No Obsidian plugin manifest found._ Either the plugin has not been scaffolded yet, or its manifest lives under an excluded directory (check `$prunedDirPattern` in the regenerator).')
    $null = [Directory]::CreateDirectory([Path]::GetDirectoryName($outPath))
    [File]::WriteAllText($outPath, $sb.ToString().Replace("`r`n", "`n"), [System.Text.UTF8Encoding]::new($false))
    Write-Host 'obsidian-manifest-index: 0 plugin(s) -> Context/generated/obsidian-manifest-index.md'
    exit 0
}

$null = $sb.AppendLine("$($plugins.Count) plugin(s). Command ids, view types, CLI handler ids, settings keys, and the manifest's ``minAppVersion`` and ``isDesktopOnly`` are **public surface**: users' hotkeys, workspaces, scripts, and saved data depend on them, and the Community directory lists the manifest on the default branch. The source scan is best effort: string literals and same-repo string constants only, and matches inside comments are not excluded.")
$null = $sb.AppendLine('')

$gitAvailable = [bool](Get-Command git -ErrorAction SilentlyContinue)

foreach ($plugin in $plugins) {
    $m = $plugin.Manifest
    $root = $plugin.Root
    $findings = [List[object]]::new()
    function Add-Finding([string] $Level, [string] $Text) {
        $findings.Add([pscustomobject]@{ Level = $Level; Text = $Text })
    }

    $id = [string](Get-Val $m @('id'))
    $name = [string](Get-Val $m @('name'))
    $version = Get-Val $m @('version')
    $minApp = Get-Val $m @('minAppVersion')
    $minAppVersion = ConvertTo-AppVersion $minApp
    $description = [string](Get-Val $m @('description'))
    $desktopOnly = Get-Val $m @('isDesktopOnly')
    $funding = Get-Val $m @('fundingUrl')

    $null = $sb.AppendLine("## ``$($plugin.RelPath)``")
    $null = $sb.AppendLine('')

    # ---- Manifest ------------------------------------------------------------
    $fundingText = if ($funding -is [System.Collections.IDictionary]) {
        (@($funding.Keys) | Sort-Object | ForEach-Object { "$_ -> $($funding[$_])" }) -join ', '
    }
    else { [string]$funding }

    $null = $sb.AppendLine('| Field | Value |')
    $null = $sb.AppendLine('| ----- | ----- |')
    $null = $sb.AppendLine("| Id | $(Format-Code $id) |")
    $null = $sb.AppendLine("| Name | $(Format-Cell $name) |")
    $null = $sb.AppendLine("| Version | $(Format-Code ([string]$version)) |")
    $null = $sb.AppendLine("| minAppVersion (the floor) | $(Format-Code ([string]$minApp)) |")
    # JSON spelling for booleans: [string]$true is 'True'.
    $desktopOnlyText = if ($desktopOnly -is [bool]) { $desktopOnly.ToString().ToLowerInvariant() } else { [string]$desktopOnly }
    $null = $sb.AppendLine("| isDesktopOnly | $(Format-Code $desktopOnlyText) |")
    $null = $sb.AppendLine("| Author | $(Format-Cell ([string](Get-Val $m @('author')))) |")
    $null = $sb.AppendLine("| Author URL | $(Format-Cell ([string](Get-Val $m @('authorUrl')))) |")
    $null = $sb.AppendLine("| Funding URL | $(Format-Cell $fundingText) |")
    $null = $sb.AppendLine("| Description ($($description.Length) chars) | $(Format-Cell $description) |")
    $null = $sb.AppendLine('')

    foreach ($key in @('id', 'name', 'version', 'minAppVersion', 'description', 'author', 'isDesktopOnly')) {
        if (-not $m.Contains($key)) { Add-Finding 'Required' "``$key`` is missing from the manifest." }
    }
    $unknown = @($m.Keys | Where-Object { $documentedKeys -notcontains $_ })
    if ($unknown.Count) {
        Add-Finding 'Required' "Undocumented manifest key(s): $(($unknown | ForEach-Object { '`' + $_ + '`' }) -join ', '). Only $(($documentedKeys | ForEach-Object { '`' + $_ + '`' }) -join ', ') are allowed."
    }

    if ($id) {
        if ($id -cnotmatch '^[a-z0-9-]+$') { Add-Finding 'Required' '`id` must be lowercase letters and hyphens.' }
        elseif ($id -match '\d') { Add-Finding 'Check' '`id` contains digits; the manifest reference documents lowercase letters and hyphens only.' }
        if ($id -match 'obsidian') { Add-Finding 'Required' '`id` must not contain "obsidian".' }
        if ($id -match 'plugin$') { Add-Finding 'Required' '`id` must not end with "plugin".' }
        if ((Split-Path -Leaf $root) -ne $id -and (Split-Path -Leaf $root) -ne (Split-Path -Leaf $repoRoot)) {
            Add-Finding 'Check' "The plugin folder is ``$(Split-Path -Leaf $root)``; Obsidian expects the installed folder name to match the ``id``."
        }
    }
    if ($name) {
        if ($name -match 'obsidian') { Add-Finding 'Required' '`name` must not contain "Obsidian".' }
        elseif ($name -match 'obsi|sidian') { Add-Finding 'Check' '`name` resembles "Obsidian" ("Obsi-" and "-sidian" are not allowed).' }
        if ($name -match '\bplugin\b') { Add-Finding 'Required' '`name` must not contain the word "Plugin".' }
        if ($name -match '[^\x20-\x7E]') { Add-Finding 'Required' '`name` must be Basic Latin: no emoji or accented characters.' }
        elseif ($name -match '[^A-Za-z0-9 +()\-]') { Add-Finding 'Check' '`name` has punctuation other than hyphens, `+`, and parentheses.' }
    }
    if ($m.Contains('description')) {
        if ($description.Length -gt 250) { Add-Finding 'Required' "``description`` is $($description.Length) characters; the limit is 250." }
        if (-not $description.TrimEnd().EndsWith('.')) { Add-Finding 'Required' '`description` must end with a period.' }
        if ($description -match '^\s*This (is a )?plugin') { Add-Finding 'Guideline' '`description` should start with what the plugin does, not "This plugin".' }
        if ($description -match '[^\x20-\x7E]') { Add-Finding 'Guideline' '`description` should have no emoji or special characters.' }
    }
    if ($m.Contains('version') -and -not (ConvertTo-AppVersion $version)) {
        Add-Finding 'Required' '`version` must be `x.y.z`; the release tag must equal it exactly.'
    }
    if ($m.Contains('minAppVersion') -and -not $minAppVersion) {
        Add-Finding 'Required' '`minAppVersion` must be `x.y.z`.'
    }
    if ($m.Contains('isDesktopOnly') -and $desktopOnly -isnot [bool]) {
        Add-Finding 'Required' '`isDesktopOnly` must be `true` or `false`.'
    }
    if ($null -ne $funding -and $funding -isnot [string] -and $funding -isnot [System.Collections.IDictionary]) {
        Add-Finding 'Required' '`fundingUrl` must be a URL string or an object of name -> URL.'
    }

    # ---- versions.json and package.json --------------------------------------
    $versionsPath = [Path]::Combine($root, 'versions.json')
    $versionsJson = Read-JsonFile -Path $versionsPath
    $pkg = Read-JsonFile -Path ([Path]::Combine($root, 'package.json'))

    $null = $sb.AppendLine('### Versions and build')
    $null = $sb.AppendLine('')

    if ($null -eq $versionsJson) {
        $null = $sb.AppendLine('- `versions.json`: _absent_')
        Add-Finding 'Guideline' 'No `versions.json`. Older apps read it to find the newest release they support; record `"<version>": "<minAppVersion>"` at least whenever the floor changes.'
    }
    elseif ($versionsJson -isnot [System.Collections.IDictionary]) {
        $null = $sb.AppendLine('- `versions.json`: _unparsable_')
        Add-Finding 'Required' '`versions.json` does not parse as a JSON object.'
    }
    else {
        $entries = @($versionsJson.Keys | ForEach-Object {
            [pscustomobject]@{ Plugin = [string]$_; App = [string]$versionsJson[$_]; Sort = (ConvertTo-AppVersion ([string]$_)) }
        } | Sort-Object { if ($_.Sort) { $_.Sort } else { [version]'0.0.0' } })
        $null = $sb.AppendLine("- ``versions.json``: $($entries.Count) entr$(if ($entries.Count -eq 1) { 'y' } else { 'ies' }); the floor map (plugin version -> minAppVersion):")
        $null = $sb.AppendLine('')
        $floors = @($entries | Group-Object App | ForEach-Object {
            $first = $_.Group[0].Plugin
            "``$first``+ -> ``$($_.Name)``"
        })
        foreach ($f in $floors) { $null = $sb.AppendLine("  - $f") }
        $null = $sb.AppendLine('')

        if ($minApp -and -not @($entries | Where-Object { $_.App -eq [string]$minApp }).Count) {
            Add-Finding 'Guideline' "No ``versions.json`` entry records the current floor ``$minApp``. Add ``""$version"": ""$minApp""``, or older apps may be offered this release."
        }
        $current = @($entries | Where-Object { $_.Plugin -eq [string]$version })
        if ($current.Count -and $current[0].App -ne [string]$minApp) {
            Add-Finding 'Check' "``versions.json`` maps ``$version`` to ``$($current[0].App)``, but the manifest says ``$minApp``."
        }
        $badValues = @($entries | Where-Object { -not (ConvertTo-AppVersion $_.App) })
        if ($badValues.Count) {
            Add-Finding 'Required' "``versions.json`` value(s) that are not ``x.y.z``: $(($badValues | ForEach-Object { '`' + $_.Plugin + '`' }) -join ', ')."
        }
    }

    if ($pkg -is [System.Collections.IDictionary]) {
        $pkgVersion = [string](Get-Val $pkg @('version'))
        $scripts = Get-Val $pkg @('scripts')
        $buildScript = $null
        foreach ($s in @('build', 'build:plugin', 'compile')) {
            if ($scripts -is [System.Collections.IDictionary] -and $scripts.Contains($s)) { $buildScript = $s; break }
        }
        $typings = [string](Get-Val $pkg @('devDependencies', 'obsidian'))
        if (-not $typings) { $typings = [string](Get-Val $pkg @('dependencies', 'obsidian')) }

        $null = $sb.AppendLine("- ``package.json`` version: $(Format-Code $pkgVersion)")
        $null = $sb.AppendLine("- ``obsidian`` typings: $(Format-Code $typings)")
        $null = $sb.AppendLine("- Build verification runs: $(if ($buildScript) { Format-Code "npm run $buildScript" } else { '_no build script_' })")

        if ($pkgVersion -and $version -and $pkgVersion -ne [string]$version) {
            Add-Finding 'Guideline' "``package.json`` version ``$pkgVersion`` differs from the manifest's ``$version``; ``npm version`` keeps them in step."
        }
        if (-not $buildScript) {
            Add-Finding 'Required' 'No `build`, `build:plugin`, or `compile` npm script. The Community directory rebuilds the release with the first of these.'
        }
        if (-not $typings) { Add-Finding 'Check' 'No `obsidian` dependency in `package.json`.' }
        foreach ($section in @('dependencies', 'devDependencies')) {
            if (Get-Val $pkg @($section, 'builtin-modules')) {
                Add-Finding 'Guideline' '`builtin-modules` is deprecated; use `builtinModules` from `node:module`.'
            }
        }
        if ($scripts -is [System.Collections.IDictionary] -and $scripts.Contains('version')) {
            $npmrc = [Path]::Combine($root, '.npmrc')
            $npmrcText = if (Test-Path -LiteralPath $npmrc) { Get-Content -LiteralPath $npmrc -Raw } else { '' }
            if ($npmrcText -notmatch 'tag-version-prefix\s*=\s*""') {
                Add-Finding 'Guideline' '`.npmrc` lacks `tag-version-prefix=""`, so `npm version` tags `v1.2.3`; the release tag must equal the version exactly.'
            }
        }
        $lockfiles = @('package-lock.json', 'pnpm-lock.yaml', 'yarn.lock', 'bun.lock', 'bun.lockb') |
            Where-Object { Test-Path -LiteralPath ([Path]::Combine($root, $_)) }
        if (-not @($lockfiles).Count) {
            Add-Finding 'Guideline' 'No lockfile. Build verification installs from it; commit one.'
        }
    }
    elseif ($pkg -eq 'unparsable') {
        $null = $sb.AppendLine('- `package.json`: _unparsable_')
        Add-Finding 'Required' '`package.json` does not parse.'
    }
    else {
        $null = $sb.AppendLine('- `package.json`: _absent_')
        Add-Finding 'Required' 'No `package.json`; the Community directory needs a build script to verify the release.'
    }

    # ---- Release files -------------------------------------------------------
    $hasStyles = Test-Path -LiteralPath ([Path]::Combine($root, 'styles.css'))
    $licenses = @(Get-ChildItem -LiteralPath $root -File -Filter 'LICENSE*' -ErrorAction SilentlyContinue)
    $readmes = @(Get-ChildItem -LiteralPath $root -File -Filter 'README*' -ErrorAction SilentlyContinue)
    $null = $sb.AppendLine("- Release assets: ``main.js``, ``manifest.json``$(if ($hasStyles) { ', `styles.css`' } else { ' (no `styles.css`)' })")
    $null = $sb.AppendLine('')

    if (-not $licenses.Count) { Add-Finding 'Required' 'No LICENSE file.' }
    if (-not $readmes.Count) { Add-Finding 'Guideline' 'No README; it must disclose network use, accounts, payments, and access outside the vault.' }
    if (Test-Path -LiteralPath ([Path]::Combine($root, 'manifest-beta.json'))) {
        Add-Finding 'Check' '`manifest-beta.json` exists. BRAT 1.1+ ignores it and installs betas from GitHub pre-releases.'
    }
    if ($gitAvailable) {
        $null = & git -C $root ls-files --error-unmatch -- main.js 2>$null
        if ($LASTEXITCODE -eq 0) {
            Add-Finding 'Guideline' '`main.js` is committed. It is build output: attach it to the release and ignore it in git.'
        }
    }

    # ---- Source scan ---------------------------------------------------------
    $allSource = Get-ScannedFile -Root $root -NamePattern '\.(ts|tsx|js|jsx|mjs)$'
    $builtMain = [Path]::Combine($root, 'main.js')
    $sourceFiles = @($allSource | Where-Object { $_ -notmatch $excludeSourcePattern -and $_ -ne $builtMain })

    $sources = [List[object]]::new()
    $constants = @{}
    foreach ($path in $sourceFiles) {
        $text = Get-Content -LiteralPath $path -Raw -Encoding UTF8
        if ($null -eq $text) { $text = '' }
        $rel = ($path.Substring($repoRoot.Length).TrimStart('\', '/') -replace '\\', '/')
        $sources.Add([pscustomobject]@{ Rel = $rel; Text = $text })
        foreach ($c in [regex]::Matches($text, '(?m)^\s*(?:export\s+)?const\s+([A-Za-z_$][\w$]*)\s*(?::\s*[^=\r\n]+)?=\s*([''"`])((?:\\.|(?!\2).)*)\2')) {
            $key = $c.Groups[1].Value
            if (-not $constants.ContainsKey($key)) { $constants[$key] = $c.Groups[3].Value }
        }
    }

    $calls = 'addCommand|registerView|registerBasesView|addSettingTab|addRibbonIcon|addStatusBarItem|' +
             'registerMarkdownCodeBlockProcessor|registerMarkdownPostProcessor|registerEditorExtension|' +
             'registerEditorSuggest|registerCliHandler|registerObsidianProtocolHandler|registerExtensions'
    $surface = [List[object]]::new()
    foreach ($src in $sources) {
        foreach ($match in [regex]::Matches($src.Text, "\.($calls)\s*\(")) {
            $open = $match.Index + $match.Length - 1
            $close = Find-CallEnd -Text $src.Text -Open $open
            $argText = $src.Text.Substring($open + 1, [Math]::Max(0, $close - $open - 1))
            $callArgs = Split-CallArgs -ArgText $argText
            $surface.Add([pscustomobject]@{
                Call  = $match.Groups[1].Value
                Args  = $callArgs
                Where = "$($src.Rel):$(Get-LineNumber -Text $src.Text -Index $match.Index)"
            })
        }
    }

    function Get-Surface([string] $Call) {
        $items = @($surface | Where-Object { $_.Call -eq $Call })
        return , $items
    }

    $null = $sb.AppendLine('### Registered surface')
    $null = $sb.AppendLine('')

    # Commands
    $commandCalls = Get-Surface 'addCommand'
    $null = $sb.AppendLine("#### Commands ($($commandCalls.Count))")
    $null = $sb.AppendLine('')
    if ($commandCalls.Count) {
        $null = $sb.AppendLine('| Id | Name | Callback | Default hotkeys | Where |')
        $null = $sb.AppendLine('| -- | ---- | -------- | --------------- | ----- |')
        $commandIds = [List[string]]::new()
        foreach ($cmd in $commandCalls) {
            $obj = if ($cmd.Args.Count) { $cmd.Args[0] } else { '' }
            $cmdId = Resolve-Arg -Arg (Get-PropertyArg -ObjectText $obj -Name 'id') -Constants $constants
            $cmdName = Resolve-Arg -Arg (Get-PropertyArg -ObjectText $obj -Name 'name') -Constants $constants
            $kind = [regex]::Match($obj, '(?<![\w$])(editorCheckCallback|editorCallback|checkCallback|callback)\s*[:(]')
            $hotkeys = $obj -match '(?<![\w$])hotkeys\s*:'
            $null = $sb.AppendLine("| $(Format-Code $cmdId) | $(Format-Cell $cmdName) | $(if ($kind.Success) { Format-Code $kind.Groups[1].Value } else { '—' }) | $(if ($hotkeys) { 'yes' } else { 'no' }) | ``$($cmd.Where)`` |")

            if ($cmdId -and -not $cmdId.StartsWith('(')) {
                $commandIds.Add($cmdId)
                if ($id -and $cmdId -match [regex]::Escape($id)) { Add-Finding 'Guideline' "Command id ``$cmdId`` repeats the plugin id; Obsidian prefixes it already." }
                if ($cmdId -match '\bcommand\b') { Add-Finding 'Guideline' "Command id ``$cmdId`` contains the word ""command""." }
            }
            if ($cmdName -and -not $cmdName.StartsWith('(')) {
                if ($name -and $cmdName -match [regex]::Escape($name)) { Add-Finding 'Guideline' "Command name ""$cmdName"" repeats the plugin name; Obsidian shows it already." }
                if ($cmdName -match '\bcommand\b') { Add-Finding 'Guideline' "Command name ""$cmdName"" contains the word ""command""." }
                if (Test-TitleCase $cmdName) { Add-Finding 'Check' "Command name ""$cmdName"" looks like Title Case; UI text is sentence case." }
            }
            if ($hotkeys) { Add-Finding 'Guideline' "A command at ``$($cmd.Where)`` sets default ``hotkeys``; leave hotkeys to the user." }
        }
        foreach ($dupe in @($commandIds | Group-Object | Where-Object { $_.Count -gt 1 })) {
            Add-Finding 'Required' "Command id ``$($dupe.Name)`` is registered $($dupe.Count) times."
        }
    }
    else { $null = $sb.AppendLine('_None found._') }
    $null = $sb.AppendLine('')

    # Everything else, one row per registration
    $otherRows = [List[string]]::new()
    foreach ($call in $surface) {
        $first = if ($call.Args.Count) { $call.Args[0] } else { $null }
        $second = if ($call.Args.Count -gt 1) { $call.Args[1] } else { $null }
        $detail = switch ($call.Call) {
            'addCommand'                          { $null }
            'registerView'                        { 'View type ' + (Format-Code (Resolve-Arg -Arg $first -Constants $constants)) }
            'registerBasesView'                   { 'Bases view ' + (Format-Code (Resolve-Arg -Arg $first -Constants $constants)) }
            'addSettingTab'                       { 'Settings tab' }
            'addRibbonIcon'                       { 'Ribbon icon ' + (Format-Code (Resolve-Arg -Arg $first -Constants $constants)) + ', title "' + (Resolve-Arg -Arg $second -Constants $constants) + '"' }
            'addStatusBarItem'                    { 'Status-bar item (desktop only)' }
            'registerMarkdownCodeBlockProcessor'  { 'Code-block language ' + (Format-Code (Resolve-Arg -Arg $first -Constants $constants)) }
            'registerMarkdownPostProcessor'       { 'Markdown post-processor' }
            'registerEditorExtension'             { 'Editor extension' }
            'registerEditorSuggest'               { 'Editor suggest' }
            'registerCliHandler'                  { 'CLI handler ' + (Format-Code (Resolve-Arg -Arg $first -Constants $constants)) }
            'registerObsidianProtocolHandler'     { 'Protocol action ' + (Format-Code ('obsidian://' + (Resolve-Arg -Arg $first -Constants $constants))) }
            'registerExtensions'                  {
                $exts = @([regex]::Matches([string]$first, '([''"`])([^''"`]+)\1') | ForEach-Object { $_.Groups[2].Value })
                'File extension(s) ' + $(if ($exts.Count) { ($exts | ForEach-Object { '`.' + $_ + '`' }) -join ', ' } else { Format-Code (Resolve-Arg -Arg $first -Constants $constants) }) +
                    ' -> view ' + (Format-Code (Resolve-Arg -Arg $second -Constants $constants))
            }
        }
        if ($detail) { $otherRows.Add("| $detail | ``$($call.Where)`` |") }

        if ($call.Call -eq 'addRibbonIcon') {
            $title = Resolve-Arg -Arg $second -Constants $constants
            if (Test-TitleCase $title) { Add-Finding 'Check' "Ribbon title ""$title"" looks like Title Case; UI text is sentence case." }
        }
        if ($call.Call -eq 'registerCliHandler') {
            $cliId = Resolve-Arg -Arg $first -Constants $constants
            if ($id -and $cliId -and -not $cliId.StartsWith('(') -and $cliId -notmatch ('^' + [regex]::Escape($id) + '(:|$)')) {
                Add-Finding 'Guideline' "CLI handler ``$cliId`` should be ``$id`` or ``$($id):<action>``; CLI ids are global and a duplicate throws."
            }
        }
    }
    $null = $sb.AppendLine("#### Other registrations ($($otherRows.Count))")
    $null = $sb.AppendLine('')
    if ($otherRows.Count) {
        $null = $sb.AppendLine('| Registration | Where |')
        $null = $sb.AppendLine('| ------------ | ----- |')
        foreach ($row in $otherRows) { $null = $sb.AppendLine($row) }
    }
    else { $null = $sb.AppendLine('_None found._') }
    $null = $sb.AppendLine('')

    # Settings tab shape
    $allText = ($sources | ForEach-Object { $_.Text }) -join "`n"
    if ($allText -match 'extends\s+PluginSettingTab' -and $allText -notmatch '\bgetSettingDefinitions\s*\(' -and
        $minAppVersion -and $minAppVersion -ge [version]'1.13.0') {
        Add-Finding 'Guideline' 'The settings tab has no `getSettingDefinitions()`. At a 1.13+ floor, `display()` is deprecated and only definitions appear in the settings search.'
    }

    # ---- Pattern checks ------------------------------------------------------
    function Find-Pattern([string] $Pattern) {
        $locations = [List[string]]::new()
        foreach ($src in $sources) {
            foreach ($hit in [regex]::Matches($src.Text, $Pattern)) {
                $locations.Add("$($src.Rel):$(Get-LineNumber -Text $src.Text -Index $hit.Index)")
            }
        }
        return , $locations
    }

    foreach ($p in $blockingPatterns) {
        if ($p.ContainsKey('DesktopOnlyExempt') -and $desktopOnly -eq $true) { continue }
        $locations = Find-Pattern $p.Pattern
        if ($locations.Count) { Add-Finding 'Blocks release' "$($p.Message) At $(Format-Locations $locations)." }
    }
    if ($minAppVersion) {
        foreach ($g in $gatedApis) {
            $since = [version]$g.Since
            if ($minAppVersion -ge $since) { continue }
            $locations = Find-Pattern $g.Pattern
            if ($locations.Count) {
                Add-Finding 'Required' "$($g.Api) needs $($g.Since), above this floor ($minApp). Guard it with ``requireApiVersion('$($g.Since)')`` or raise the floor. At $(Format-Locations $locations)."
            }
        }
    }
    foreach ($d in $deprecatedApis) {
        $locations = Find-Pattern $d.Pattern
        if ($locations.Count) { Add-Finding 'Guideline' "$($d.Message) At $(Format-Locations $locations)." }
    }
    foreach ($p in $guidelinePatterns) {
        $locations = Find-Pattern $p.Pattern
        if ($locations.Count) { Add-Finding 'Guideline' "$($p.Message) At $(Format-Locations $locations)." }
    }
    foreach ($p in $checkPatterns) {
        $locations = Find-Pattern $p.Pattern
        if ($locations.Count) { Add-Finding 'Check' "$($p.Message) At $(Format-Locations $locations)." }
    }

    # ---- Validation report ---------------------------------------------------
    $null = $sb.AppendLine('### Validation findings')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('_Levels: **Blocks release** (the Community directory scan fails the version), **Required** (a documented manifest, release, or API-floor requirement), **Guideline** (review guidelines and lint warnings), **Check** (heuristics worth a look)._')
    $null = $sb.AppendLine('')
    if (-not $findings.Count) {
        $null = $sb.AppendLine('_No issues detected._')
    }
    else {
        foreach ($level in @('Blocks release', 'Required', 'Guideline', 'Check')) {
            foreach ($f in @($findings | Where-Object { $_.Level -eq $level })) {
                $null = $sb.AppendLine("- **$($f.Level):** $($f.Text)")
            }
        }
    }
    $null = $sb.AppendLine('')
}

$null = [Directory]::CreateDirectory([Path]::GetDirectoryName($outPath))
[File]::WriteAllText($outPath, $sb.ToString().TrimEnd() + "`n", [System.Text.UTF8Encoding]::new($false))
Write-Host "obsidian-manifest-index: $($plugins.Count) plugin(s) -> Context/generated/obsidian-manifest-index.md"
exit 0
