#Requires -Version 7.1
using namespace System.IO

<#
.SYNOPSIS
    Shared data + helpers for Install-ContextEngine.ps1 and Update-ContextEngine.ps1.

.DESCRIPTION
    Dot-sourced by both entry scripts. Defines the engine's authoritative
    single-source-of-truth lists (template exclusions, engine-owned prefixes,
    installer-owned vs skill-owned tokens) and path/hash/token helpers.
#>

Set-StrictMode -Version Latest

$script:EngineRoot   = Split-Path -Parent $PSScriptRoot
$script:TemplateCore = [Path]::Combine($script:EngineRoot, 'templates', 'core')
$script:StacksRoot   = [Path]::Combine($script:EngineRoot, 'templates', 'stacks')

# Template-relative paths (forward slashes) that are never copied verbatim.
$script:TemplateExclusions = @(
    'claude/settings.fragment.json'    # merged into .claude/settings.json, not copied
)

# Target-relative prefixes owned by the engine after install. Update-ContextEngine
# overwrites these (when locally unmodified); projects must not hand-edit them.
# Everything else installed is seeded-then-project-owned and never re-touched.
$script:EngineOwnedPrefixes = @(
    '.claude/hooks/'
    '.claude/commands/'
    '.claude/skills/context-keeper/'
    '.claude/context-engine/'
    '.githooks/'
)

# Install records. The manifest (schema 2) records what the installer wrote:
# the adapter chain, the installer's token answers, the spliced config
# defaults, and a hash per seeded file. Each seeded file is also snapshotted
# under $BaselineRoot exactly as installed, so a later refresh can three-way
# merge engine template changes into project edits (the Copier model). The
# records folder is engine-managed: never hand-edited, and skipped by token
# scans because baselines predate the authoring pass by design.
$script:ManifestSchema      = 2
$script:EngineRecordsPrefix = '.claude/context-engine/'
$script:BaselineRoot        = '.claude/context-engine/baseline'

# Where a seed refresh leaves what it will not write itself: merge candidates,
# proposals, the report, and the pending list -CompleteRefresh reads. The
# folder ignores itself (a '*' .gitignore), so none of it is committed.
$script:IncomingRoot = '.claude/context-engine/incoming'

# Seed refresh policy per seeded path; the first matching glob wins, and any
# path no glob matches is Merge. Adapters prepend their own (adapter.psd1
# SeedPolicy), and a project opts a file out with SeedRefreshExclude.
#   Merge    three-way merge; a clean result is written, a conflict is not
#   Propose  never written; the new rendering is offered for review
#   Config   per-key merge of the spliced adapter ConfigDefaults
#   Skip     never refreshed or reported: frozen history and live content
# The index READMEs come first because they are engine prose inside folders
# whose other files belong entirely to the project.
$script:SeedPolicies = @(
    @{ Glob = 'Context/*/README.md';                Policy = 'Merge' }
    @{ Glob = 'Context/adr/**';                     Policy = 'Skip' }
    @{ Glob = 'Context/roadmap/**';                 Policy = 'Skip' }
    @{ Glob = 'Context/specs/**';                   Policy = 'Skip' }
    @{ Glob = 'Context/insights/**';                Policy = 'Skip' }
    @{ Glob = 'Context/architecture/**';            Policy = 'Skip' }
    @{ Glob = 'Context/generated/**';               Policy = 'Skip' }
    @{ Glob = 'CLAUDE.md';                          Policy = 'Propose' }
    @{ Glob = 'Context/conventions/agent-rules.md'; Policy = 'Propose' }
    @{ Glob = 'Context/scripts/*.psd1';             Policy = 'Propose' }
    @{ Glob = '.claude/context-engine.psd1';        Policy = 'Config' }
)
$script:SeedPolicyNames = @('Merge', 'Propose', 'Config', 'Skip')

# Tokens the INSTALLER substitutes. Any of these left in an installed file is an error.
$script:InstallerTokens = @(
    'PROJECT_NAME', 'TODAY', 'MAIN_BRANCH', 'REPO_URL', 'REPO_DIR',
    'ENGINE_REPO_URL', 'ENGINE_VERSION', 'PRIMARY_EXT'
)

# Tokens the /fm-init-context-engine skill fills during its authoring pass.
# Allowed to remain after a bare (skill-less) install.
$script:SkillTokens = @(
    'PROJECT_DESCRIPTION', 'COMMANDS_TABLE', 'DO_LIST', 'DONT_LIST', 'DO_RULES',
    'DONT_RULES', 'DEPENDENCIES', 'STRATEGIC_DIRECTION', 'ACTIVE_WORK', 'PUBLIC_SURFACE',
    'TOOLCHAIN'
)

function Get-EngineVersion {
    (Get-Content -LiteralPath ([Path]::Combine($script:EngineRoot, 'VERSION')) -Raw).Trim()
}

function ConvertTo-EngineVersion {
    <# Parses an engine version stamp (YYYY.MM.DD, or YYYY.MM.DD.N for a
       second release the same day) into a [version] for ordering. Returns
       $null for anything unparsable rather than throwing. #>
    param([AllowEmptyString()] [AllowNull()] [string] $Text)
    $parsed = $null
    if ($Text -and [version]::TryParse($Text.Trim(), [ref] $parsed)) { return $parsed }
    return $null
}

function Get-TargetFullPath {
    <# Absolute path of a target-relative (forward-slash) path. #>
    param(
        [Parameter(Mandatory)] [string] $TargetPath,
        [Parameter(Mandatory)] [string] $Relative
    )
    return [Path]::Combine($TargetPath, ($Relative -replace '/', [Path]::DirectorySeparatorChar))
}

function Convert-GlobToRegex {
    <# The watch hook's glob semantics, shared so policy globs read the same
       way: '**' spans directories, '*' and '?' stay within one segment, and
       the match is case-insensitive and anchored at both ends. The engine-
       owned hook keeps its own copy because hooks run standalone. #>
    param([Parameter(Mandatory)] [string] $Glob)
    $p = [regex]::Escape(($Glob -replace '\\', '/'))
    $p = $p -replace '\\\*\\\*/', '(?:[^/]+/)*'
    $p = $p -replace '\\\*\\\*', '.*'
    $p = $p -replace '\\\*', '[^/]*'
    $p = $p -replace '\\\?', '[^/]'
    return "(?i)^$p`$"
}

function Resolve-AdapterChain {
    <# Resolves a stack adapter and its Inherits ancestors, parent first, as
       objects with Name (the directory's real name, so a differently cased
       -Stack still records the canonical chain), Dir, and Config (the parsed
       adapter.psd1). 'None' or an empty name resolves to an empty chain. #>
    param([AllowEmptyString()] [AllowNull()] [string] $Stack)
    $chain = [System.Collections.Generic.List[object]]::new()
    if (-not $Stack -or $Stack -eq 'None') { return , $chain }
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $reversed = [System.Collections.Generic.List[object]]::new()
    $name = $Stack
    while ($name) {
        if (-not $seen.Add($name)) { throw "Stack adapter inheritance cycle detected at '$name'." }
        $match = Get-ChildItem -LiteralPath $script:StacksRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object Name -eq $name | Select-Object -First 1
        if (-not $match) {
            $available = (Get-ChildItem -LiteralPath $script:StacksRoot -Directory -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty Name) -join ', '
            throw "Unknown stack adapter '$name'. Available: $(if ($available) { $available } else { '(none yet — Phase 3)' })"
        }
        $configPath = [Path]::Combine($match.FullName, 'adapter.psd1')
        $config = if (Test-Path -LiteralPath $configPath) { Import-PowerShellDataFile -LiteralPath $configPath } else { @{} }
        $reversed.Add([pscustomobject]@{ Name = $match.Name; Dir = $match.FullName; Config = $config })
        $name = if ($config.ContainsKey('Inherits')) { [string]$config.Inherits } else { $null }
    }
    for ($i = $reversed.Count - 1; $i -ge 0; $i--) { $chain.Add($reversed[$i]) }
    return , $chain
}

function Get-MergedConfigDefaults {
    <# The chain's ConfigDefaults merged per key, last wins: a child that
       omits a key inherits its parent's, and one that sets it replaces the
       parent's value wholesale. #>
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Chain)
    $merged = @{}
    foreach ($adapter in $Chain) {
        if ($adapter.Config.ContainsKey('ConfigDefaults')) {
            foreach ($key in $adapter.Config.ConfigDefaults.Keys) {
                $merged[$key] = $adapter.Config.ConfigDefaults[$key]
            }
        }
    }
    return $merged
}

function Get-InstallPlan {
    <# Every file an install of this chain writes, keyed by target-relative
       path: core first, then each adapter, a later file overriding an
       earlier one at the same path. #>
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Chain)
    $planned = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($item in @(Get-TemplateFiles)) { $planned[$item.TargetRelative] = $item }
    foreach ($adapter in $Chain) {
        foreach ($item in @(Get-TemplateFiles -Root $adapter.Dir -ExcludeRelative @('adapter.psd1') -Source $adapter.Name)) {
            $planned[$item.TargetRelative] = $item
        }
    }
    return , $planned
}

function Get-InstallerTokenValues {
    <# The installer-owned token values for a target, from explicit answers
       where given and the repository otherwise. TODAY and ENGINE_VERSION are
       included; the manifest leaves both out because they describe the
       moment of rendering. #>
    param(
        [Parameter(Mandatory)] [string] $TargetPath,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Chain,
        [string] $ProjectName,
        [string] $MainBranch,
        [string] $PrimaryExtension
    )
    if (-not $ProjectName) { $ProjectName = [Path]::GetFileName($TargetPath.TrimEnd('\', '/')) }
    if (-not $MainBranch) {
        $branch = (& git -C $TargetPath symbolic-ref --short HEAD 2>$null)
        $MainBranch = if ($LASTEXITCODE -eq 0 -and $branch) { ([string]$branch).Trim() } else { 'main' }
    }
    $repoUrl = (& git -C $TargetPath remote get-url origin 2>$null)
    $repoUrl = if ($LASTEXITCODE -eq 0 -and $repoUrl) { ([string]$repoUrl).Trim() } else { '<repo-url — no origin remote yet>' }
    $engineRepoUrl = (& git -C $script:EngineRoot remote get-url origin 2>$null)
    $engineRepoUrl = if ($LASTEXITCODE -eq 0 -and $engineRepoUrl) { ([string]$engineRepoUrl).Trim() } else { $script:EngineRoot }
    if (-not $PrimaryExtension) {
        foreach ($adapter in $Chain) {
            if ($adapter.Config.ContainsKey('PrimaryExtension') -and $adapter.Config.PrimaryExtension) {
                $PrimaryExtension = [string]$adapter.Config.PrimaryExtension
            }
        }
        if (-not $PrimaryExtension) { $PrimaryExtension = 'ext' }
    }
    return @{
        PROJECT_NAME    = $ProjectName
        TODAY           = Get-Date -Format 'yyyy-MM-dd'
        MAIN_BRANCH     = $MainBranch
        REPO_URL        = $repoUrl
        REPO_DIR        = [Path]::GetFileName($TargetPath.TrimEnd('\', '/'))
        ENGINE_REPO_URL = $engineRepoUrl
        ENGINE_VERSION  = Get-EngineVersion
        PRIMARY_EXT     = $PrimaryExtension.TrimStart('.')
    }
}

function Convert-TemplatePathToTargetPath {
    <# Maps a template-relative path to its target-relative install path:
       claude/... -> .claude/...   githooks/... -> .githooks/...   rest 1:1 #>
    param([Parameter(Mandatory)] [string] $TemplateRelative)
    $p = $TemplateRelative -replace '\\', '/'
    if ($p.StartsWith('claude/',   [System.StringComparison]::Ordinal)) { return '.claude/'   + $p.Substring(7) }
    if ($p.StartsWith('githooks/', [System.StringComparison]::Ordinal)) { return '.githooks/' + $p.Substring(9) }
    return $p
}

function Get-TemplateFiles {
    <# Enumerates a template root's files as objects:
       TemplateRelative / TargetRelative (forward slashes), FullPath,
       EngineOwned, and Source (the adapter name, or 'core'). #>
    param(
        [string]   $Root = $script:TemplateCore,
        [string[]] $ExcludeRelative = $script:TemplateExclusions,
        [string]   $Source = 'core'
    )
    Get-ChildItem -LiteralPath $Root -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring($Root.Length + 1) -replace '\\', '/'
        if ($ExcludeRelative -contains $rel) { return }
        $target = Convert-TemplatePathToTargetPath -TemplateRelative $rel
        $owned  = $false
        foreach ($prefix in $script:EngineOwnedPrefixes) {
            if ($target.StartsWith($prefix, [System.StringComparison]::Ordinal)) { $owned = $true; break }
        }
        [pscustomobject]@{
            TemplateRelative = $rel
            TargetRelative   = $target
            FullPath         = $_.FullName
            EngineOwned      = $owned
            Source           = $Source
        }
    }
}

function Get-SeedBaselinePath {
    <# Absolute path of a seeded file's install-time snapshot. The .base
       suffix is load-bearing: Claude Code discovers .claude/rules/*.md
       recursively (nested .claude/rules/ folders included) and loads any
       CLAUDE.md it finds, so a snapshot keeping its real name could be read
       as live instructions. #>
    param(
        [Parameter(Mandatory)] [string] $TargetPath,
        [Parameter(Mandatory)] [string] $TargetRelative
    )
    $rel = "$script:BaselineRoot/$TargetRelative.base"
    return [Path]::Combine($TargetPath, ($rel -replace '/', [Path]::DirectorySeparatorChar))
}

function ConvertTo-ConfigDefaultsRecord {
    <# Normalizes merged adapter ConfigDefaults into an ordered structure for
       the manifest. Hashtable key order is not stable, so without this the
       same install could serialize differently run to run; watch entries use
       the same known-key order as Format-WatchEntry. #>
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [System.Collections.IDictionary] $ConfigDefaults)
    $record = [ordered]@{}
    foreach ($key in @('PublicSurface', 'DirtyHint')) {
        if ($ConfigDefaults.Contains($key)) { $record[$key] = [string]$ConfigDefaults[$key] }
    }
    if ($ConfigDefaults.Contains('Watches')) {
        $record['Watches'] = @(
            foreach ($w in @($ConfigDefaults['Watches'])) {
                if ($null -eq $w) { continue }
                $entry = [ordered]@{}
                foreach ($k in @('Glob', 'Action', 'Command', 'Message', 'Hint')) {
                    if ($w.Contains($k) -and $w[$k]) { $entry[$k] = [string]$w[$k] }
                }
                $entry
            }
        )
    }
    if ($ConfigDefaults.Contains('Regenerators')) {
        $record['Regenerators'] = @(foreach ($r in @($ConfigDefaults['Regenerators'])) { if ($null -ne $r) { [string]$r } })
    }
    return $record
}

function ConvertTo-PlainData {
    <# Deep-converts parsed JSON (PSCustomObject trees) into ordered
       dictionaries and object arrays, so manifest records and freshly built
       ones compare and serialize the same way. #>
    param([AllowNull()] $InputObject)
    if ($null -eq $InputObject) { return $null }
    if ($InputObject -is [System.Management.Automation.PSCustomObject]) {
        $d = [ordered]@{}
        foreach ($p in $InputObject.PSObject.Properties) { $d[$p.Name] = ConvertTo-PlainData $p.Value }
        return $d
    }
    if ($InputObject -is [System.Collections.IDictionary]) {
        $d = [ordered]@{}
        foreach ($k in $InputObject.Keys) { $d[[string]$k] = ConvertTo-PlainData $InputObject[$k] }
        return $d
    }
    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        return , @(foreach ($x in $InputObject) { ConvertTo-PlainData $x })
    }
    return $InputObject
}

function ConvertTo-CanonicalJson {
    <# A stable string form for comparing records (null-safe). #>
    param([AllowNull()] $InputObject)
    if ($null -eq $InputObject) { return 'null' }
    return (ConvertTo-Json -InputObject $InputObject -Depth 8 -Compress)
}

function Invoke-ConfigDefaultsSplice {
    <# Splices ConfigDefaults into the text of a context-engine.psd1 that
       still has the core template's shape. The installer uses it on the
       freshly copied config, and a seed refresh uses it to re-render what an
       install would write today. Values are spliced textually so the core
       template stays the single structural source. #>
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $ConfigText,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [System.Collections.IDictionary] $ConfigDefaults
    )
    if ($ConfigDefaults.Contains('PublicSurface') -and $ConfigDefaults['PublicSurface']) {
        $ConfigText = $ConfigText.Replace('{{PUBLIC_SURFACE}}', ([string]$ConfigDefaults['PublicSurface'] -replace "'", "''"))
    }
    if ($ConfigDefaults.Contains('DirtyHint') -and $ConfigDefaults['DirtyHint']) {
        $ConfigText = $ConfigText.Replace("DirtyHint = ''", "DirtyHint = '$([string]$ConfigDefaults['DirtyHint'] -replace "'", "''")'")
    }
    if ($ConfigDefaults.Contains('Watches') -and @($ConfigDefaults['Watches']).Count -gt 0) {
        $lines = foreach ($w in @($ConfigDefaults['Watches'])) { '        ' + (Format-WatchEntry -Watch $w) }
        $newBlock = "Watches = @(`n" + ($lines -join "`n") + "`n    )"
        $ConfigText = [regex]::Replace($ConfigText, '(?s)Watches = @\(.*?\n    \)', $newBlock.Replace('$', '$$'))
    }
    if ($ConfigDefaults.Contains('Regenerators') -and @($ConfigDefaults['Regenerators']).Count -gt 0) {
        $lines = foreach ($r in @($ConfigDefaults['Regenerators'])) { "        '" + ([string]$r -replace "'", "''") + "'" }
        $newBlock = "Regenerators = @(`n" + ($lines -join "`n") + "`n    )"
        $ConfigText = [regex]::Replace($ConfigText, '(?s)Regenerators = @\(.*?\n    \)', $newBlock.Replace('$', '$$'))
    }
    return $ConfigText
}

function Set-ConfigScalar {
    <# Sets a single-quoted scalar key (PublicSurface, DirtyHint) in config
       text. Returns $null when the key line is not there to change. #>
    param(
        [Parameter(Mandatory)] [string] $ConfigText,
        [Parameter(Mandatory)] [string] $Key,
        [AllowEmptyString()] [AllowNull()] [string] $Value
    )
    $pattern = "(?m)^(\s*$Key\s*=\s*)'(?:[^']|'')*'"
    if ($ConfigText -notmatch $pattern) { return $null }
    $escaped = ([string]$Value -replace "'", "''").Replace('$', '$$')
    return [regex]::Replace($ConfigText, $pattern, "`${1}'$escaped'", 'None', [timespan]::FromSeconds(2))
}

function Set-ConfigList {
    <# Rewrites a list key (Watches, Regenerators) in config text from
       already-formatted item lines. Returns $null when the block is not in
       the shape the installer writes. #>
    param(
        [Parameter(Mandatory)] [string] $ConfigText,
        [Parameter(Mandatory)] [string] $Key,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [string[]] $ItemLines
    )
    $pattern = "(?s)$Key = @\(.*?\n    \)"
    if ($ConfigText -notmatch $pattern) { return $null }
    $body = if ($ItemLines.Count) { ($ItemLines | ForEach-Object { '        ' + $_ }) -join "`n" } else { $null }
    $block = if ($body) { "$Key = @(`n$body`n    )" } else { "$Key = @(`n    )" }
    return [regex]::Replace($ConfigText, $pattern, $block.Replace('$', '$$'))
}

function ConvertFrom-Psd1Text {
    <# Parses psd1 text with Import-PowerShellDataFile (which only reads
       files) via a temporary file. Returns $null when the text is invalid. #>
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Text)
    $tmp = [Path]::Combine([Path]::GetTempPath(), "ce-$([guid]::NewGuid().ToString('N')).psd1")
    try {
        [File]::WriteAllText($tmp, $Text, [System.Text.UTF8Encoding]::new($false))
        return Import-PowerShellDataFile -LiteralPath $tmp
    }
    catch { return $null }
    finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
}

function Get-SeedPolicy {
    <# The refresh policy for a seeded path: the adapter chain's SeedPolicy
       entries first (child before parent), then the core table, then Merge. #>
    param(
        [Parameter(Mandatory)] [string] $TargetRelative,
        [AllowEmptyCollection()] [object[]] $AdapterPolicies = @()
    )
    foreach ($rule in @($AdapterPolicies) + @($script:SeedPolicies)) {
        if ($TargetRelative -match (Convert-GlobToRegex -Glob $rule.Glob)) { return $rule.Policy }
    }
    return 'Merge'
}

function Get-FrontMatterDate {
    <# The last_verified date in a document's front matter, or $null. #>
    param([AllowEmptyString()] [string] $Text)
    $m = [regex]::Match($Text, '\A---\n(?:.*\n)*?last_verified:[ \t]*(\S+)[ \t]*\n(?:.*\n)*?---\n')
    if ($m.Success) { return $m.Groups[1].Value }
    return $null
}

function Set-FrontMatterDate {
    <# Replaces the front-matter last_verified value; text without one is
       returned unchanged. #>
    param(
        [AllowEmptyString()] [string] $Text,
        [Parameter(Mandatory)] [string] $Date
    )
    $m = [regex]::Match($Text, '\A---\n(?:.*\n)*?---\n')
    if (-not $m.Success) { return $Text }
    $front = [regex]::Replace($m.Value, '(?m)^(last_verified:[ \t]*)\S+', "`${1}$Date")
    return $front + $Text.Substring($m.Length)
}

function Get-SkillTokenNames {
    <# The skill-owned token names present in a text. #>
    param([AllowEmptyString()] [string] $Text)
    $pattern = '\{\{(' + ($script:SkillTokens -join '|') + ')\}\}'
    return @([regex]::Matches($Text, $pattern) | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
}

function Test-ConflictMarkers {
    <# True when a text still holds merge conflict markers. #>
    param([AllowEmptyString()] [string] $Text)
    return [regex]::IsMatch($Text, '(?m)^(<{7}|>{7}|\|{7})( |$)')
}

function Invoke-ThreeWayMerge {
    <# Three-way merges texts with git merge-file (--diff3, labelled), and
       returns the merged text and its conflict count. git writes the result
       into the "ours" temp file rather than stdout: native output decoding
       would mangle non-ASCII text on a Windows console code page. #>
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Ours,
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Base,
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Theirs
    )
    $dir = [Path]::Combine([Path]::GetTempPath(), "ce-merge-$([guid]::NewGuid().ToString('N'))")
    $null = [Directory]::CreateDirectory($dir)
    try {
        $utf8 = [System.Text.UTF8Encoding]::new($false)
        $o = [Path]::Combine($dir, 'ours'); $b = [Path]::Combine($dir, 'base'); $t = [Path]::Combine($dir, 'theirs')
        [File]::WriteAllText($o, $Ours, $utf8)
        [File]::WriteAllText($b, $Base, $utf8)
        [File]::WriteAllText($t, $Theirs, $utf8)
        & git merge-file --diff3 -L project -L baseline -L engine $o $b $t 2>$null
        $code = $LASTEXITCODE
        # 0 is clean and 1-127 counts conflicts; anything else is a failure.
        if ($code -lt 0 -or $code -gt 127) { throw "git merge-file failed (exit $code)." }
        return [pscustomobject]@{ Text = [File]::ReadAllText($o); Conflicts = $code }
    }
    finally { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
}

function Merge-WatchList {
    <# Three-way merges watch lists entry by entry, keyed by Glob + Action.
       An entry only one side changed takes that side; one both changed
       differently is a conflict (the project's entry stays). The project's
       own entries and order are kept, and an entry the engine added lands at
       the engine's position: only the first matching watch per Action
       fires, so order is behavior. Returns Result and Conflicts. #>
    param(
        [AllowEmptyCollection()] [object[]] $Base = @(),
        [AllowEmptyCollection()] [object[]] $Theirs = @(),
        [AllowEmptyCollection()] [object[]] $Ours = @()
    )
    $keyOf = { param($w) '{0}|{1}' -f $w['Glob'], $w['Action'] }
    $b = @{}; foreach ($w in $Base) { $b[(& $keyOf $w)] = ConvertTo-CanonicalJson $w }
    $t = @{}; $tEntry = @{}
    foreach ($w in $Theirs) { $k = & $keyOf $w; $t[$k] = ConvertTo-CanonicalJson $w; $tEntry[$k] = $w }
    $seen = [System.Collections.Generic.HashSet[string]]::new()
    $result = [System.Collections.Generic.List[object]]::new()
    $conflicts = [System.Collections.Generic.List[string]]::new()
    foreach ($o in $Ours) {
        $k = & $keyOf $o
        $null = $seen.Add($k)
        $oj = ConvertTo-CanonicalJson $o
        if ($b.ContainsKey($k) -and $t.ContainsKey($k)) {
            if ($t[$k] -eq $b[$k] -or $oj -eq $t[$k]) { $result.Add($o) }
            elseif ($oj -eq $b[$k]) { $result.Add($tEntry[$k]) }
            else { $conflicts.Add("$k (both changed it)"); $result.Add($o) }
        }
        elseif ($b.ContainsKey($k)) {
            # The engine dropped it: follow, unless the project changed it.
            if ($oj -ne $b[$k]) { $conflicts.Add("$k (the engine removed it; the project changed it)"); $result.Add($o) }
        }
        elseif ($t.ContainsKey($k)) {
            if ($oj -ne $t[$k]) { $conflicts.Add("$k (both added it, differently)") }
            $result.Add($o)
        }
        else { $result.Add($o) }
    }
    for ($i = 0; $i -lt $Theirs.Count; $i++) {
        $k = & $keyOf $Theirs[$i]
        # Skip what the project has, and what it deleted from the base.
        if ($seen.Contains($k) -or $b.ContainsKey($k)) { continue }
        $at = $result.Count
        for ($j = $i + 1; $j -lt $Theirs.Count -and $at -eq $result.Count; $j++) {
            $nextKey = & $keyOf $Theirs[$j]
            for ($r = 0; $r -lt $result.Count; $r++) {
                if ((& $keyOf $result[$r]) -eq $nextKey) { $at = $r; break }
            }
        }
        $result.Insert($at, $Theirs[$i])
    }
    return [pscustomobject]@{ Result = $result.ToArray(); Conflicts = $conflicts.ToArray() }
}

function Read-EngineChangelog {
    <# Parses the engine's CHANGELOG.md into entries: Version, Scope (an
       adapter name or 'core'), Kind, Text, Impact, and Detect (regex
       patterns). The format is "## <version>", "### <scope>", then
       "- **Kind:** text" bullets with optional "  - Impact:" and
       "  - Detect: `pattern`" sub-bullets. #>
    param([Parameter(Mandatory)] [string] $LiteralPath)
    if (-not (Test-Path -LiteralPath $LiteralPath)) { return @() }
    $entries = [System.Collections.Generic.List[object]]::new()
    $version = $null; $scope = $null; $current = $null
    foreach ($line in ([File]::ReadAllText($LiteralPath) -replace "`r`n", "`n") -split "`n") {
        if ($line -match '^## (\S+)\s*$') { $version = $Matches[1]; $scope = $null; $current = $null; continue }
        if ($line -match '^### (\S+)\s*$') { $scope = $Matches[1]; $current = $null; continue }
        if ($version -and $scope -and $line -match '^- \*\*(\w+):\*\*\s*(.+)$') {
            $current = [pscustomobject]@{
                Version = $version; Scope = $scope; Kind = $Matches[1]; Text = $Matches[2].Trim()
                Impact = $null; Detect = [System.Collections.Generic.List[string]]::new()
            }
            $entries.Add($current)
            continue
        }
        if ($current -and $line -match '^\s+- Impact:\s*(.+)$') { $current.Impact = $Matches[1].Trim(); continue }
        if ($current -and $line -match '^\s+- Detect:\s*`(.+)`\s*$') { $current.Detect.Add($Matches[1]); continue }
    }
    return , $entries.ToArray()
}

function Get-NormalizedContentHash {
    <# SHA256 of the file's text with CRLF normalized to LF, so git autocrlf
       churn in a target working tree never reads as a local modification. #>
    param([Parameter(Mandatory)] [string] $LiteralPath)
    return Get-TextHash -Text ([File]::ReadAllText($LiteralPath))
}

function Get-TextHash {
    <# The same hash as Get-NormalizedContentHash, for text in memory. #>
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Text)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(($Text -replace "`r`n", "`n"))
    $sha = [System.Security.Cryptography.SHA256]::Create()
    # Convert.ToHexString, not ForEach-Object ToString: the latter honors
    # ShouldProcess, so -WhatIf propagation would suppress the hashing itself.
    try   { return [System.Convert]::ToHexString($sha.ComputeHash($bytes)) }
    finally { $sha.Dispose() }
}

function Get-TextDiff {
    <# A unified diff between two texts, labelled for the reader. git writes
       it to a file (--output) so non-ASCII text survives decoding. #>
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Old,
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $New,
        [Parameter(Mandatory)] [string] $OldLabel,
        [Parameter(Mandatory)] [string] $NewLabel
    )
    $dir = [Path]::Combine([Path]::GetTempPath(), "ce-diff-$([guid]::NewGuid().ToString('N'))")
    $null = [Directory]::CreateDirectory($dir)
    try {
        $utf8 = [System.Text.UTF8Encoding]::new($false)
        $a = [Path]::Combine($dir, 'old'); $b = [Path]::Combine($dir, 'new'); $out = [Path]::Combine($dir, 'diff')
        [File]::WriteAllText($a, $Old, $utf8)
        [File]::WriteAllText($b, $New, $utf8)
        & git diff --no-index --no-color --no-prefix "--output=$out" -- $a $b 2>$null
        $text = if (Test-Path -LiteralPath $out) { [File]::ReadAllText($out) } else { '' }
        # git's header names the temp files (quoted and escaped); replace it
        # with one naming what the reader is comparing.
        $hunk = $text.IndexOf("`n@@")
        if ($hunk -lt 0) { return '' }
        return "--- $OldLabel`n+++ $NewLabel`n" + $text.Substring($hunk + 1)
    }
    finally { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
}

function Expand-InstallerTokens {
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Content,
        [Parameter(Mandatory)] [hashtable] $TokenValues
    )
    foreach ($key in $TokenValues.Keys) {
        $Content = $Content.Replace('{{' + $key + '}}', [string]$TokenValues[$key])
    }
    return $Content
}

function Write-Utf8NoBomFile {
    param(
        [Parameter(Mandatory)] [string] $LiteralPath,
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Content
    )
    $dir = [Path]::GetDirectoryName($LiteralPath)
    if ($dir) { $null = [Directory]::CreateDirectory($dir) }
    # Normalize to LF. This is the single choke point for every file the
    # installer and updater write, and three separate sources would otherwise
    # emit CRLF on Windows: ConvertTo-Json (the manifest and the merged
    # settings.json), a template read from a clone with core.autocrlf=true, and
    # any here-string built in this script. Writing LF unconditionally makes an
    # install byte-identical across machines, keeps the sh commit-msg hook
    # working (CRLF breaks "#!/bin/sh"), and stops every engine update from
    # showing spurious line-ending diffs in the target's git history.
    $normalized = $Content.Replace("`r`n", "`n")
    [File]::WriteAllText($LiteralPath, $normalized, [System.Text.UTF8Encoding]::new($false))
}

function Find-LeftoverTokens {
    <# Scans the installed surface of a target project for {{TOKEN}} leftovers
       from the given token-name set. Returns one object per hit. The
       engine-records folder is skipped: its baselines are snapshots taken
       before the authoring pass, so they keep skill-owned tokens on purpose,
       and counting them would stop -Verify from ever reporting clean. #>
    param(
        [Parameter(Mandatory)] [string]   $TargetPath,
        [Parameter(Mandatory)] [string[]] $TokenNames
    )
    $pattern = '\{\{(' + ($TokenNames -join '|') + ')\}\}'
    $roots = @('CLAUDE.md', 'Context', '.claude', '.githooks')
    $files = foreach ($r in $roots) {
        $p = [Path]::Combine($TargetPath, $r)
        if (Test-Path -LiteralPath $p -PathType Container) {
            Get-ChildItem -LiteralPath $p -Recurse -File | Where-Object {
                $rel = $_.FullName.Substring($TargetPath.Length + 1) -replace '\\', '/'
                -not $rel.StartsWith($script:EngineRecordsPrefix, [System.StringComparison]::OrdinalIgnoreCase)
            }
        }
        elseif (Test-Path -LiteralPath $p -PathType Leaf) {
            Get-Item -LiteralPath $p
        }
    }
    $files | Select-String -Pattern $pattern | ForEach-Object {
        [pscustomobject]@{
            File   = $_.Path.Substring($TargetPath.Length + 1) -replace '\\', '/'
            Line   = $_.LineNumber
            Tokens = ($_.Matches.Value | Sort-Object -Unique) -join ', '
        }
    }
}

function Format-WatchEntry {
    <# Serializes one flat watch hashtable to a single psd1 line. Known keys
       only, stable order, single-quote escaping. Used when splicing adapter
       ConfigDefaults.Watches into the installed context-engine.psd1. #>
    param([Parameter(Mandatory)] [System.Collections.IDictionary] $Watch)
    $parts = foreach ($key in @('Glob', 'Action', 'Command', 'Message', 'Hint')) {
        if ($Watch.Contains($key) -and $Watch[$key]) {
            "{0} = '{1}'" -f $key, ([string]$Watch[$key] -replace "'", "''")
        }
    }
    return '@{ ' + ($parts -join '; ') + ' }'
}

function Merge-SettingsFragment {
    <# Merges the hook registrations from settings.fragment.json into the
       target's .claude/settings.json. Creates the file if absent. Appends
       only hook groups whose command strings are not already registered for
       that event; never removes, reorders, or touches other keys
       (permissions etc.). Returns a one-line description of what happened. #>
    param(
        [Parameter(Mandatory)] [string] $FragmentPath,
        [Parameter(Mandatory)] [string] $SettingsPath
    )
    $fragment = Get-Content -LiteralPath $FragmentPath -Raw | ConvertFrom-Json

    $settings = if (Test-Path -LiteralPath $SettingsPath) {
        Get-Content -LiteralPath $SettingsPath -Raw | ConvertFrom-Json
    } else {
        [pscustomobject]@{}
    }

    if (-not $settings.PSObject.Properties['hooks']) {
        $settings | Add-Member -NotePropertyName 'hooks' -NotePropertyValue ([pscustomobject]@{})
    }

    $added = 0
    foreach ($eventProp in $fragment.hooks.PSObject.Properties) {
        $eventName = $eventProp.Name
        if (-not $settings.hooks.PSObject.Properties[$eventName]) {
            $settings.hooks | Add-Member -NotePropertyName $eventName -NotePropertyValue @()
        }
        $existingCommands = @(
            foreach ($group in @($settings.hooks.$eventName)) {
                foreach ($h in @($group.hooks)) { $h.command }
            }
        )
        foreach ($group in @($eventProp.Value)) {
            $newCommands = @(foreach ($h in @($group.hooks)) { $h.command })
            $alreadyThere = @($newCommands | Where-Object { $existingCommands -contains $_ })
            if ($alreadyThere.Count -eq 0) {
                $settings.hooks.$eventName = @($settings.hooks.$eventName) + $group
                $added++
            }
        }
    }

    if ($added -eq 0 -and (Test-Path -LiteralPath $SettingsPath)) {
        return 'unchanged (hooks already registered)'
    }

    $existed = Test-Path -LiteralPath $SettingsPath
    Write-Utf8NoBomFile -LiteralPath $SettingsPath -Content (($settings | ConvertTo-Json -Depth 16) + "`n")
    if ($existed) { return "merged ($added hook group(s) added)" }
    return "created ($added hook group(s))"
}

function Sync-GitAttributesPin {
<#
    Ensures the target's .gitattributes pins every path the engine writes to
    LF, creating or appending as needed. Returns a short status string.

    Everything the engine writes is LF (see Write-Utf8NoBomFile). Without these
    pins a checkout on a machine with core.autocrlf=true rewrites them as CRLF,
    and the next update then shows spurious line-ending diffs across every
    engine-owned file. The sh commit-msg hook is the load-bearing case: CRLF in
    a "#!/bin/sh" script breaks execution outright.

    Shared by the installer and the updater so an existing install picks the
    pins up on its next update rather than only at install time.
#>
    param([Parameter(Mandatory)] [string] $TargetPath)

    $gaPath   = [Path]::Combine($TargetPath, '.gitattributes')
    $header   = '# Written by the context-engine: these paths are generated as LF, so pin them'
    $pinLines = @(
        '.githooks/commit-msg text eol=lf'
        '.claude/** text eol=lf'
        'Context/** text eol=lf'
        # Self-pin: this file is written LF too, and without a rule covering it
        # an autocrlf checkout flips it to CRLF and the next update rewrites it
        # back — churning the very file that exists to stop churn.
        '.gitattributes text eol=lf'
    )

    if (-not (Test-Path -LiteralPath $gaPath)) {
        # Parens are load-bearing: -join binds tighter than +, so without them
        # the header and the pin lines never concatenate into one string.
        Write-Utf8NoBomFile -LiteralPath $gaPath -Content (
            ((@($header) + $pinLines) -join "`n") + "`n")
        return 'created'
    }

    $existing = Get-Content -LiteralPath $gaPath -Raw
    $missing  = @($pinLines | Where-Object { $existing -notmatch [regex]::Escape($_) })
    if (-not $missing.Count) { return 'already pinned' }

    # Rewritten rather than Add-Content so the appended lines are LF too.
    Write-Utf8NoBomFile -LiteralPath $gaPath -Content (
        ($existing.TrimEnd("`r", "`n") + "`n" + $header + "`n" + ($missing -join "`n")) + "`n")
    return "appended $($missing.Count) pin line(s)"
}
