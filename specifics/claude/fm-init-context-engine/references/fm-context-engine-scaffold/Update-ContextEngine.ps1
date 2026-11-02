#Requires -Version 7.1
using namespace System.IO
using namespace System.Collections.Generic

<#
.SYNOPSIS
    Re-syncs engine-owned context-engine files in an installed project and,
    on request, refreshes its seeded files from the current templates.

.DESCRIPTION
    Always: reads the baseline hash manifest written at install time
    (.claude/context-engine-manifest.json) and reconciles every engine-owned
    template file against the target:

        UpToDate       current file already matches the template
        Upgrade        file unmodified since install (matches baseline) and
                       the template evolved -> overwritten
        Restore        file missing from the target -> reinstalled
        New            engine-owned file added in a newer engine version ->
                       installed
        ModifiedSkip   file differs from BOTH baseline and template — it was
                       hand-edited in the project -> left alone with a
                       warning (overwrite with -Force)

    Comparison uses CRLF-normalized content hashes, so git autocrlf churn in
    the target working tree never reads as a local modification. Engine-owned
    templates are token-free by design (the installer enforces this), so
    template content is copied verbatim. The manifest is then rewritten with
    fresh baselines and the current engine version, and the EngineVersion key
    in .claude/context-engine.psd1 is bumped in place.

    With -RefreshSeeds it also refreshes the seeded files: convention docs,
    rules, regenerators, CLAUDE.md, the Context/ skeleton, and the adapter
    defaults spliced into .claude/context-engine.psd1. They are project-owned
    after install, so each is re-rendered from the current templates with the
    answers the installer recorded and three-way merged against its install-
    time snapshot under .claude/context-engine/baseline/ (the Copier model):

        SeedCurrent       the engine has not changed the file
        FastForward       the project has not changed it -> new text written
        Merged            both changed, the merge is clean -> written; review it
        Conflict          both changed, the merge conflicts -> left alone;
                          <path>.merge (diff3) and <path>.new are offered
        Proposed          Propose policy (CLAUDE.md, agent-rules.md, decision
                          data) -> never written; <path>.new and <path>.diff
        New               a seed this install never had -> written
        Adopted           no usable baseline, but the file already matches the
                          engine -> baseline recorded
        Legacy            no usable baseline and the file differs -> <path>.new
                          for a two-way review
        DeletedByProject  the project deleted it -> respected (optOut)
        UpstreamRemoved   no template ships it any more -> reported only
        Excluded          matched by SeedRefreshExclude -> reported when changed
        ConfigConflict    an adapter default the project also changed

    Each path's policy (Merge, Propose, Config, or Skip) comes from the core
    table in lib/common.ps1, an adapter's SeedPolicy, and the project's
    SeedRefreshExclude. A last_verified date change alone never conflicts,
    and a merge that would bring back a skill-owned {{TOKEN}} the project had
    already filled is treated as a conflict.

    Everything the refresh will not write itself goes to the self-ignoring
    .claude/context-engine/incoming/ folder, with refresh-report.md (the
    states, the engine CHANGELOG entries since the project's last refresh with
    their Detect hits in project code, and release-channel floor advisories)
    and pending.json. Once the pending files are resolved, -CompleteRefresh
    records their new baselines.

.PARAMETER TargetPath
    Installed project to update. Default: current directory.

.PARAMETER Force
    Also overwrite engine-owned files in ModifiedSkip state (local hand-edits
    are lost). Never applies to seeded files.

.PARAMETER RefreshSeeds
    Also refresh the seeded files. Requires a clean git working tree unless
    -AllowDirty is passed, so the whole refresh is one reviewable diff.

.PARAMETER CompleteRefresh
    After resolving what a refresh left in the incoming folder, record the new
    baselines: each resolved file's baseline becomes the engine's rendering,
    so the next refresh merges three-way from there. Files that still hold
    conflict markers stay pending. Runs nothing else.

.PARAMETER Stack
    With -RefreshSeeds: the stack adapter to render from. Required for an
    install that predates manifest schema 2 (it recorded no stack); on a newer
    install, a different stack re-stacks the project (its new seeds arrive as
    New, and the rest merge as usual).

.PARAMETER AllowDirty
    With -RefreshSeeds: proceed on a working tree with uncommitted changes.

.EXAMPLE
    .\Update-ContextEngine.ps1 -TargetPath X:\my-app -WhatIf

.EXAMPLE
    .\Update-ContextEngine.ps1 -TargetPath X:\my-app -RefreshSeeds -WhatIf

.EXAMPLE
    .\Update-ContextEngine.ps1 -TargetPath X:\my-app -RefreshSeeds -Stack electron
    # ...resolve .claude/context-engine/incoming/refresh-report.md, then:
    .\Update-ContextEngine.ps1 -TargetPath X:\my-app -CompleteRefresh
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Position = 0)]
    [string] $TargetPath = (Get-Location).ProviderPath,

    [switch] $Force,

    [switch] $RefreshSeeds,

    [switch] $CompleteRefresh,

    [string] $Stack,

    [switch] $AllowDirty
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path -Path $PSScriptRoot -ChildPath 'lib/common.ps1')

$TargetPath = [Path]::GetFullPath($TargetPath)
$manifestPath = [Path]::Combine($TargetPath, '.claude', 'context-engine-manifest.json')
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "No context-engine install manifest at '$manifestPath'. Run Install-ContextEngine.ps1 first."
}
if ($RefreshSeeds -and $CompleteRefresh) {
    throw '-RefreshSeeds and -CompleteRefresh are separate steps: refresh, resolve what it reports, then complete.'
}
if ($Stack -and -not $RefreshSeeds) { throw '-Stack applies only with -RefreshSeeds.' }

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$engineVersion = Get-EngineVersion
$nowUtc = Get-Date -AsUTC -Format 'yyyy-MM-ddTHH:mm:ssZ'

function Get-ManifestValue([string] $Name) {
    $prop = $manifest.PSObject.Properties[$Name]
    if (-not $prop) { return $null }
    # Through a variable: 'return , (Command)' returns $null, and a bare
    # return would unroll an array value.
    $value = ConvertTo-PlainData $prop.Value
    return , $value
}

function Read-LfText([string] $LiteralPath) {
    return [File]::ReadAllText($LiteralPath) -replace "`r`n", "`n"
}

# The manifest's own records, case-insensitive by path like the install plan.
$seedRecords = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::OrdinalIgnoreCase)
$recordedSeeds = Get-ManifestValue 'seeds'
if ($recordedSeeds) { foreach ($k in $recordedSeeds.Keys) { $seedRecords[$k] = $recordedSeeds[$k] } }
$optOut = [List[string]]::new()
$recordedOptOut = Get-ManifestValue 'optOut'
foreach ($p in $recordedOptOut) { if ($p -and -not $optOut.Contains([string]$p)) { $optOut.Add([string]$p) } }

$incomingDir = Get-TargetFullPath -TargetPath $TargetPath -Relative $script:IncomingRoot
$pendingPath = [Path]::Combine($incomingDir, 'pending.json')
function Get-IncomingPath([string] $Relative, [string] $Suffix) {
    return Get-TargetFullPath -TargetPath $TargetPath -Relative "$script:IncomingRoot/$Relative$Suffix"
}

# Every manifest write goes through here. Only the keys passed change; every
# other key is carried forward, and a key a newer engine added survives an
# update by an older one.
function Write-Manifest([System.Collections.IDictionary] $Updates) {
    $keyOrder = @('schema', 'engineVersion', 'installedUtc', 'updatedUtc', 'refreshedUtc', 'refreshedVersion',
                  'stack', 'chain', 'tokens', 'files', 'seeds', 'configDefaults', 'optOut')
    $existing = [ordered]@{}
    foreach ($prop in $manifest.PSObject.Properties) { $existing[$prop.Name] = $prop.Value }
    $out = [ordered]@{}
    foreach ($key in $keyOrder) {
        if ($Updates.Contains($key))      { $out[$key] = $Updates[$key] }
        elseif ($existing.Contains($key)) { $out[$key] = $existing[$key] }
    }
    foreach ($key in $existing.Keys) { if (-not $out.Contains($key)) { $out[$key] = $existing[$key] } }
    Write-Utf8NoBomFile -LiteralPath $manifestPath -Content (($out | ConvertTo-Json -Depth 10) + "`n")
}

function Get-SortedSeedRecords {
    $sorted = [ordered]@{}
    foreach ($k in (@($seedRecords.Keys) | Sort-Object)) { $sorted[$k] = $seedRecords[$k] }
    return $sorted
}

# ── What a refresh renders with (both refresh steps need it) ────────────────
if ($RefreshSeeds -or $CompleteRefresh) {
    $recordedStack = Get-ManifestValue 'stack'
    $stackName =
        if ($Stack)             { $Stack }
        elseif ($recordedStack) { [string]$recordedStack }
        else {
            throw ("This install predates seed baselines (manifest schema 1) and records no stack. " +
                   "Pass -Stack <adapter> (or None) so the refresh knows which templates seeded it.")
        }
    $chain = Resolve-AdapterChain -Stack $stackName
    # Not 'ForEach-Object Name': that form honors ShouldProcess, so under
    # -WhatIf it would skip every item and the chain would read as empty.
    $chainNames = @(foreach ($adapter in $chain) { $adapter.Name })
    $plan = Get-InstallPlan -Chain $chain

    $recordedTokens = Get-ManifestValue 'tokens'
    $tokens = [ordered]@{}
    if ($recordedTokens) {
        foreach ($k in $recordedTokens.Keys) { $tokens[$k] = [string]$recordedTokens[$k] }
    }
    else {
        # Schema 1 kept no answers. Re-derive them the way the installer does,
        # reading the project name back from CLAUDE.md's title.
        $projectName = $null
        $claudePath = [Path]::Combine($TargetPath, 'CLAUDE.md')
        if (Test-Path -LiteralPath $claudePath) {
            $title = [regex]::Match([File]::ReadAllText($claudePath), '(?m)^# (.+?)\s*$')
            if ($title.Success -and $title.Groups[1].Value -notmatch '\{\{') { $projectName = $title.Groups[1].Value }
        }
        $derived = Get-InstallerTokenValues -TargetPath $TargetPath -Chain $chain -ProjectName $projectName
        foreach ($k in (@($derived.Keys) | Where-Object { $_ -notin @('TODAY', 'ENGINE_VERSION') } | Sort-Object)) {
            $tokens[$k] = [string]$derived[$k]
        }
    }
    $renderTokens = @{}
    foreach ($k in $tokens.Keys) { $renderTokens[$k] = $tokens[$k] }
    $renderTokens['TODAY'] = Get-Date -Format 'yyyy-MM-dd'
    $renderTokens['ENGINE_VERSION'] = $engineVersion

    function Get-SeedRendering([object] $Item) {
        return Expand-InstallerTokens -Content (Read-LfText $Item.FullPath) -TokenValues $renderTokens
    }
    function Get-ConfigRendering([System.Collections.IDictionary] $Defaults) {
        # What an install of this chain writes today: the core template with
        # installer tokens, then the defaults spliced in.
        return Invoke-ConfigDefaultsSplice -ConfigText (Get-SeedRendering $plan['.claude/context-engine.psd1']) -ConfigDefaults $Defaults
    }
}

# ── -CompleteRefresh: record baselines for what was resolved ────────────────
if ($CompleteRefresh) {
    if (-not (Test-Path -LiteralPath $pendingPath)) {
        Write-Host 'Nothing to complete: the last refresh left no pending items.'
        exit 0
    }
    $pendingDoc = ConvertTo-PlainData (Get-Content -LiteralPath $pendingPath -Raw | ConvertFrom-Json)
    if ([string]$pendingDoc['engineVersion'] -ne $engineVersion) {
        throw ("The pending items came from engine $($pendingDoc['engineVersion']), and this is engine $engineVersion. " +
               'Run -RefreshSeeds with this engine first.')
    }
    $recordedDefaultsRaw = Get-ManifestValue 'configDefaults'
    $configDefaults = if ($null -ne $recordedDefaultsRaw) { ConvertTo-ConfigDefaultsRecord -ConfigDefaults $recordedDefaultsRaw } else { $null }
    $configKeyResolved = $false
    $remaining = [List[object]]::new()
    $completed = [List[object]]::new()
    $baselineWrites = [List[object]]::new()
    $cleanup = [List[string]]::new()

    foreach ($p in @($pendingDoc['items'])) {
        $rel = [string]$p['path']
        if ($p['state'] -eq 'ConfigConflict') {
            # The agent has settled the key in the project file either way; the
            # engine's value becomes the base, so the next refresh sees no change.
            if ($null -eq $configDefaults) { $configDefaults = [ordered]@{} }
            if ($null -eq $p['value']) { $configDefaults.Remove([string]$p['key']) } else { $configDefaults[[string]$p['key']] = $p['value'] }
            $configKeyResolved = $true
            $completed.Add([pscustomobject]@{ State = 'ConfigConflict'; File = "$rel ($($p['key']))"; Note = 'engine value recorded as the new base' })
            continue
        }
        $newPath = Get-IncomingPath $rel '.new'
        if (-not (Test-Path -LiteralPath $newPath)) {
            $remaining.Add($p)
            Write-Host "  still pending  $rel  (its candidate is gone; run -RefreshSeeds again)"
            continue
        }
        $full = Get-TargetFullPath -TargetPath $TargetPath -Relative $rel
        $note = 'baseline recorded'
        if (Test-Path -LiteralPath $full -PathType Leaf) {
            if (Test-ConflictMarkers (Read-LfText $full)) {
                $remaining.Add($p)
                Write-Host "  still pending  $rel  (conflict markers remain)"
                continue
            }
        }
        else {
            if (-not $optOut.Contains($rel)) { $optOut.Add($rel) }
            $note = 'left out of this project; baseline recorded so later engine changes are reported'
        }
        $theirs = Read-LfText $newPath
        $baselineWrites.Add([pscustomobject]@{ Path = Get-SeedBaselinePath -TargetPath $TargetPath -TargetRelative $rel; Content = $theirs })
        $seedRecords[$rel] = [ordered]@{ source = [string]$p['source']; engineVersion = $engineVersion; hash = Get-TextHash -Text $theirs }
        if ($p.Contains('configDefaults') -and $null -ne $p['configDefaults']) {
            $configDefaults = ConvertTo-ConfigDefaultsRecord -ConfigDefaults $p['configDefaults']
        }
        foreach ($suffix in @('.new', '.merge', '.diff')) { $cleanup.Add((Get-IncomingPath $rel $suffix)) }
        $completed.Add([pscustomobject]@{ State = [string]$p['state']; File = $rel; Note = $note })
    }

    # A settled config key changes the defaults the config baseline renders.
    $cfgRel = '.claude/context-engine.psd1'
    if ($configKeyResolved -and $plan.Contains($cfgRel) -and $seedRecords.Contains($cfgRel)) {
        $cfgText = Get-ConfigRendering $configDefaults
        $baselineWrites.Add([pscustomobject]@{ Path = Get-SeedBaselinePath -TargetPath $TargetPath -TargetRelative $cfgRel; Content = $cfgText })
        $seedRecords[$cfgRel] = [ordered]@{ source = [string]$plan[$cfgRel].Source; engineVersion = $engineVersion; hash = Get-TextHash -Text $cfgText }
    }

    if ($PSCmdlet.ShouldProcess($TargetPath, "Record $($baselineWrites.Count) baseline(s) for resolved refresh items")) {
        foreach ($w in $baselineWrites) { Write-Utf8NoBomFile -LiteralPath $w.Path -Content $w.Content }
        foreach ($c in $cleanup) { if (Test-Path -LiteralPath $c) { Remove-Item -LiteralPath $c -Force } }
        if ($remaining.Count) {
            $pendingDoc['items'] = $remaining.ToArray()
            Write-Utf8NoBomFile -LiteralPath $pendingPath -Content ((ConvertTo-Json -InputObject $pendingDoc -Depth 10) + "`n")
        }
        else { Remove-Item -LiteralPath $pendingPath -Force }
        $updates = [ordered]@{ schema = $script:ManifestSchema; seeds = Get-SortedSeedRecords; optOut = $optOut.ToArray() }
        if ($null -ne $configDefaults) { $updates['configDefaults'] = ConvertTo-ConfigDefaultsRecord -ConfigDefaults $configDefaults }
        Write-Manifest $updates
    }

    Write-Host ''
    Write-Host ("Completed {0} refresh item(s); {1} still pending." -f $completed.Count, $remaining.Count)
    if ($completed.Count) { $completed | Format-Table -AutoSize | Out-Host }
    if ($remaining.Count) {
        Write-Host 'Resolve the files above (no conflict markers left), then run -CompleteRefresh again.'
        exit 1
    }
    exit 0
}

# ── Refresh preflight: one reviewable diff ──────────────────────────────────
if ($RefreshSeeds -and -not $AllowDirty -and -not $WhatIfPreference) {
    $status = @(& git -C $TargetPath status --porcelain 2>$null)
    if ($LASTEXITCODE -ne 0) {
        throw "$TargetPath is not a git working tree. A seed refresh merges with git and should land as one reviewable diff."
    }
    if ($status.Count) {
        throw 'The working tree has uncommitted changes. Commit or stash them so the refresh is one reviewable diff, or pass -AllowDirty.'
    }
}

$baseline = @{}
if ($manifest.PSObject.Properties['files']) {
    foreach ($prop in $manifest.files.PSObject.Properties) { $baseline[$prop.Name] = $prop.Value }
}

Write-Host ("Updating {0}" -f $TargetPath)
Write-Host ("  Installed engine version: {0}   Current engine version: {1}" -f $manifest.engineVersion, $engineVersion)
Write-Host ''

# ── Reconcile every engine-owned template file ──────────────────────────────
$engineOwned = @(Get-TemplateFiles | Where-Object EngineOwned | Sort-Object TargetRelative)
$results   = [List[object]]::new()
$newHashes = [ordered]@{}

foreach ($item in $engineOwned) {
    $dest = [Path]::Combine($TargetPath, ($item.TargetRelative -replace '/', [Path]::DirectorySeparatorChar))
    $templateHash = Get-NormalizedContentHash -LiteralPath $item.FullPath
    $destExists   = Test-Path -LiteralPath $dest -PathType Leaf
    $currentHash  = if ($destExists) { Get-NormalizedContentHash -LiteralPath $dest } else { $null }
    $baselineHash = if ($baseline.ContainsKey($item.TargetRelative)) { $baseline[$item.TargetRelative] } else { $null }

    $state =
        if (-not $destExists)                       { if ($baselineHash) { 'Restore' } else { 'New' } }
        elseif ($currentHash -eq $templateHash)     { 'UpToDate' }
        elseif ($currentHash -eq $baselineHash)     { 'Upgrade' }
        elseif ($Force)                             { 'ForceOverwrite' }
        else                                        { 'ModifiedSkip' }

    $writeIt = $state -in @('Restore', 'New', 'Upgrade', 'ForceOverwrite')
    if ($writeIt -and $PSCmdlet.ShouldProcess($item.TargetRelative, $state)) {
        Write-Utf8NoBomFile -LiteralPath $dest -Content ([File]::ReadAllText($item.FullPath))
        $newHashes[$item.TargetRelative] = $templateHash
    }
    else {
        # Keep whatever baseline is truthful: unmodified files re-baseline to the
        # template hash they already match; skipped local edits keep the old baseline
        # so a later update still recognizes them as modified.
        $newHashes[$item.TargetRelative] =
            if ($state -eq 'UpToDate') { $templateHash }
            elseif ($baselineHash)     { $baselineHash }
            else                       { $templateHash }
    }
    $results.Add([pscustomobject]@{ State = $state; File = $item.TargetRelative })
}

# ── Report files the engine no longer owns ──────────────────────────────────
$currentTargets = @($engineOwned | Select-Object -ExpandProperty TargetRelative)
foreach ($orphan in ($baseline.Keys | Where-Object { $currentTargets -notcontains $_ } | Sort-Object)) {
    $results.Add([pscustomobject]@{ State = 'NoLongerEngineOwned'; File = $orphan })
}

# ── Seed refresh (-RefreshSeeds) ────────────────────────────────────────────
$manifestUpdates = [ordered]@{}
if ($RefreshSeeds) {
    $seedResults    = [List[object]]::new()
    $projectWrites  = [List[object]]::new()
    $baselineWrites = [List[object]]::new()
    $incomingWrites = [List[object]]::new()
    $baselineDeletes = [List[string]]::new()
    $pending        = [List[object]]::new()
    $legacyInstall  = $seedRecords.Count -eq 0

    function Add-SeedResult([string] $State, [string] $File, [string] $Note = '') {
        $seedResults.Add([pscustomobject]@{ State = $State; File = $File; Note = $Note })
    }
    function Add-Incoming([string] $Relative, [string] $Suffix, [string] $Content) {
        $incomingWrites.Add([pscustomobject]@{ Path = Get-IncomingPath $Relative $Suffix; Content = $Content })
    }
    function Set-SeedBaseline([string] $Relative, [string] $Content, [string] $Source) {
        $baselineWrites.Add([pscustomobject]@{ Path = Get-SeedBaselinePath -TargetPath $TargetPath -TargetRelative $Relative; Content = $Content })
        $seedRecords[$Relative] = [ordered]@{ source = $Source; engineVersion = $engineVersion; hash = Get-TextHash -Text $Content }
    }
    function Get-ValidBaseline([string] $Relative) {
        # The snapshot, unless it is missing or no longer matches the hash the
        # manifest recorded (a hand edit corrupts the merge base; fall back to
        # a two-way review rather than merging against it).
        if (-not $seedRecords.Contains($Relative)) { return $null }
        $path = Get-SeedBaselinePath -TargetPath $TargetPath -TargetRelative $Relative
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
        $text = Read-LfText $path
        if ((Get-TextHash -Text $text) -ne [string]$seedRecords[$Relative]['hash']) { return $null }
        return $text
    }
    function Set-DateIfAny([string] $Text, [AllowNull()] [string] $Date) {
        if ($Date) { return Set-FrontMatterDate -Text $Text -Date $Date }
        return $Text
    }

    # Adapter SeedPolicy entries, child-most adapter first.
    $adapterPolicies = [List[object]]::new()
    for ($i = $chain.Count - 1; $i -ge 0; $i--) {
        if (-not $chain[$i].Config.ContainsKey('SeedPolicy')) { continue }
        foreach ($rule in @($chain[$i].Config.SeedPolicy)) {
            if ($rule.Policy -notin $script:SeedPolicyNames) {
                throw "Adapter '$($chain[$i].Name)' declares an unknown SeedPolicy '$($rule.Policy)' for '$($rule.Glob)'."
            }
            $adapterPolicies.Add(@{ Glob = [string]$rule.Glob; Policy = [string]$rule.Policy })
        }
    }

    # The project's opt-outs: SeedRefreshExclude in its (parsed) config.
    $cfgRel  = '.claude/context-engine.psd1'
    $cfgFull = Get-TargetFullPath -TargetPath $TargetPath -Relative $cfgRel
    $excludeGlobs = @()
    if (Test-Path -LiteralPath $cfgFull) {
        $parsedCfg = ConvertFrom-Psd1Text -Text (Read-LfText $cfgFull)
        if ($parsedCfg -and $parsedCfg.ContainsKey('SeedRefreshExclude')) { $excludeGlobs = @($parsedCfg.SeedRefreshExclude | Where-Object { $_ }) }
    }
    function Test-Excluded([string] $Relative) {
        foreach ($g in $excludeGlobs) { if ($Relative -match (Convert-GlobToRegex -Glob ([string]$g))) { return $true } }
        return $false
    }

    # Every path the refresh has an opinion about: this chain's seeds, plus
    # anything the manifest recorded or the project opted out of.
    $paths = [SortedSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($item in $plan.Values) { if (-not $item.EngineOwned) { $null = $paths.Add($item.TargetRelative) } }
    foreach ($k in $seedRecords.Keys) { $null = $paths.Add([string]$k) }
    foreach ($k in $optOut) { $null = $paths.Add($k) }

    # ── Text seeds ──────────────────────────────────────────────────────────
    foreach ($rel in $paths) {
        $policy = Get-SeedPolicy -TargetRelative $rel -AdapterPolicies $adapterPolicies.ToArray()
        if ($policy -in @('Skip', 'Config')) { continue }
        $item = if ($plan.Contains($rel)) { $plan[$rel] } else { $null }
        if ($item -and $item.EngineOwned) { continue }
        $full = Get-TargetFullPath -TargetPath $TargetPath -Relative $rel
        $oursExists = Test-Path -LiteralPath $full -PathType Leaf
        $recorded = $seedRecords.Contains($rel)

        if (-not $item) {
            # Reported once, then no longer tracked: the file stays, as plain
            # project content, and later refreshes stop mentioning it.
            if ($recorded) {
                if ($oursExists) { Add-SeedResult 'UpstreamRemoved' $rel 'no template ships this file any more; left in place and no longer tracked' }
                $seedRecords.Remove($rel)
                $baselineDeletes.Add((Get-SeedBaselinePath -TargetPath $TargetPath -TargetRelative $rel))
            }
            if ($optOut.Contains($rel)) { $null = $optOut.Remove($rel) }
            continue
        }
        $theirs = Get-SeedRendering $item
        $base = Get-ValidBaseline $rel
        $baseDate = if ($base) { Get-FrontMatterDate -Text $base } else { $null }
        # The engine changed the file only if more than the date differs.
        $changed = (-not $base) -or ((Set-DateIfAny $theirs $baseDate) -cne $base)

        if (Test-Excluded $rel) {
            if ($base -and $changed) {
                Add-SeedResult 'Excluded' $rel 'the engine changed this file; SeedRefreshExclude keeps it project-owned'
                Set-SeedBaseline $rel $theirs $item.Source
            }
            continue
        }

        if (-not $oursExists) {
            if ($recorded -or $optOut.Contains($rel)) {
                if (-not $optOut.Contains($rel)) { $optOut.Add($rel) }
                if ($base -and $changed) {
                    Add-SeedResult 'DeletedByProject' $rel 'deleted in this project; the engine has changed it since (not restored)'
                    Set-SeedBaseline $rel $theirs $item.Source
                }
            }
            elseif ($legacyInstall) {
                Add-Incoming $rel '.new' $theirs
                $pending.Add([ordered]@{ path = $rel; state = 'Legacy'; source = $item.Source })
                Add-SeedResult 'Legacy' $rel 'not in this project, and the engine seeds it: add it or leave it out'
            }
            else {
                $projectWrites.Add([pscustomobject]@{ Path = $full; Content = $theirs })
                Set-SeedBaseline $rel $theirs $item.Source
                Add-SeedResult 'New' $rel 'the engine added this file'
            }
            continue
        }

        $ours = Read-LfText $full
        if (-not $base) {
            # No usable baseline: legacy install, a file the engine never
            # recorded, or a hand-edited snapshot. Compare two-way.
            $oursDate = Get-FrontMatterDate -Text $ours
            $comparable = Set-DateIfAny $theirs $oursDate
            if ($comparable -ceq $ours) {
                Set-SeedBaseline $rel $comparable $item.Source
                Add-SeedResult 'Adopted' $rel 'already matches the engine; baseline recorded'
            }
            else {
                Add-Incoming $rel '.new' $theirs
                $pending.Add([ordered]@{ path = $rel; state = 'Legacy'; source = $item.Source })
                $why = if ($recorded) { 'its baseline is missing or was edited' } else { 'no baseline' }
                Add-SeedResult 'Legacy' $rel "$why; review two-way against .new"
            }
            continue
        }

        if (-not $changed) { Add-SeedResult 'SeedCurrent' $rel; continue }

        if ($policy -eq 'Propose') {
            Add-Incoming $rel '.new' $theirs
            Add-Incoming $rel '.diff' (Get-TextDiff -Old $base -New $theirs -OldLabel "baseline/$rel" -NewLabel "engine/$rel")
            $pending.Add([ordered]@{ path = $rel; state = 'Proposed'; source = $item.Source })
            Add-SeedResult 'Proposed' $rel 'never written; apply what fits from .diff by hand'
            continue
        }

        if ($ours -ceq $base) {
            $projectWrites.Add([pscustomobject]@{ Path = $full; Content = $theirs })
            Set-SeedBaseline $rel $theirs $item.Source
            Add-SeedResult 'FastForward' $rel
            continue
        }

        # Both sides changed. Neutralize the date line first: base takes the
        # project's date, and the engine's text takes the later of the two,
        # so re-verifying a document is never a conflict.
        $oursDate = Get-FrontMatterDate -Text $ours
        $theirsDate = Get-FrontMatterDate -Text $theirs
        $mergeBase = Set-DateIfAny $base $oursDate
        $mergeTheirs =
            if (-not $theirsDate) { $theirs }
            elseif (-not $oursDate) { Set-DateIfAny $theirs $baseDate }
            else { Set-FrontMatterDate -Text $theirs -Date (@($oursDate, $theirsDate) | Sort-Object | Select-Object -Last 1) }
        $merge = Invoke-ThreeWayMerge -Ours $ours -Base $mergeBase -Theirs $mergeTheirs
        $oursTokens = Get-SkillTokenNames -Text $ours
        $reentered = @(Get-SkillTokenNames -Text $merge.Text | Where-Object { $_ -notin $oursTokens })
        if ($merge.Conflicts -eq 0 -and $reentered.Count -eq 0) {
            $projectWrites.Add([pscustomobject]@{ Path = $full; Content = $merge.Text })
            Set-SeedBaseline $rel $theirs $item.Source
            Add-SeedResult 'Merged' $rel 'clean merge written; review it'
        }
        else {
            Add-Incoming $rel '.merge' $merge.Text
            Add-Incoming $rel '.new' $theirs
            $pending.Add([ordered]@{ path = $rel; state = 'Conflict'; source = $item.Source })
            $why = if ($merge.Conflicts) { "$($merge.Conflicts) conflicting hunk(s)" } else { "the merge would restore {{$($reentered -join '}}, {{')}}" }
            Add-SeedResult 'Conflict' $rel "$why; resolve from .merge, then -CompleteRefresh"
        }
    }

    # ── The project config (Config policy) ─────────────────────────────────
    # Its adapter-supplied keys merge as data: base = the defaults recorded at
    # install, theirs = the chain's defaults today, ours = the parsed file.
    $newConfigDefaults = $null
    if ($plan.Contains($cfgRel) -and (Get-SeedPolicy -TargetRelative $cfgRel -AdapterPolicies $adapterPolicies.ToArray()) -eq 'Config') {
        $cfgItem = $plan[$cfgRel]
        $theirsDefaults = ConvertTo-ConfigDefaultsRecord -ConfigDefaults (Get-MergedConfigDefaults -Chain $chain)
        $recordedDefaultsRaw = Get-ManifestValue 'configDefaults'
        $baseDefaults = if ($null -ne $recordedDefaultsRaw) { ConvertTo-ConfigDefaultsRecord -ConfigDefaults $recordedDefaultsRaw } else { $null }
        $cfgBase = Get-ValidBaseline $cfgRel
        $theirsCfg = Get-ConfigRendering $theirsDefaults
        # The unspliced template's values stand in for a key no adapter set.
        $templateValues = ConvertTo-ConfigDefaultsRecord -ConfigDefaults (ConvertFrom-Psd1Text -Text (Get-SeedRendering $cfgItem))

        if (Test-Excluded $cfgRel) {
            if ($null -ne $baseDefaults -and (ConvertTo-CanonicalJson $theirsDefaults) -ne (ConvertTo-CanonicalJson $baseDefaults)) {
                Add-SeedResult 'Excluded' $cfgRel 'the adapter defaults changed; SeedRefreshExclude keeps the config project-owned'
            }
        }
        elseif (-not (Test-Path -LiteralPath $cfgFull)) {
            Add-SeedResult 'DeletedByProject' $cfgRel 'the project config is missing; the hooks run on defaults'
        }
        elseif (-not $cfgBase -or $null -eq $baseDefaults) {
            $oursCfg = Read-LfText $cfgFull
            $oursVersion = [regex]::Match($oursCfg, "(?m)^\s*EngineVersion\s*=\s*'([^']*)'").Groups[1].Value
            $comparable = Set-ConfigScalar -ConfigText $theirsCfg -Key 'EngineVersion' -Value $oursVersion
            if ($comparable -and $comparable -ceq $oursCfg) {
                Set-SeedBaseline $cfgRel $theirsCfg $cfgItem.Source
                $newConfigDefaults = $theirsDefaults
                Add-SeedResult 'Adopted' $cfgRel 'already matches the engine; baseline recorded'
            }
            else {
                Add-Incoming $cfgRel '.new' $theirsCfg
                $pending.Add([ordered]@{ path = $cfgRel; state = 'Legacy'; source = $cfgItem.Source; configDefaults = $theirsDefaults })
                Add-SeedResult 'Legacy' $cfgRel 'no baseline; compare the Watches, Regenerators, DirtyHint, and PublicSurface with .new'
            }
        }
        else {
            $oursCfg = Read-LfText $cfgFull
            $working = $oursCfg
            $notes = [List[string]]::new()
            $structConflict = $false

            # 1. The core template's own text (comments, new keys such as
            #    SeedRefreshExclude): three-way against the same defaults, so
            #    only template changes are in play.
            $structTheirs = Get-ConfigRendering $baseDefaults
            if ($structTheirs -cne $cfgBase) {
                $merge = Invoke-ThreeWayMerge -Ours $oursCfg -Base $cfgBase -Theirs $structTheirs
                if ($merge.Conflicts) {
                    $structConflict = $true
                    Add-Incoming $cfgRel '.merge' $merge.Text
                    Add-Incoming $cfgRel '.new' $theirsCfg
                    $pending.Add([ordered]@{ path = $cfgRel; state = 'Conflict'; source = $cfgItem.Source; configDefaults = $theirsDefaults })
                    Add-SeedResult 'Conflict' $cfgRel 'the config template changed where this project edited it; resolve from .merge'
                }
                else {
                    $working = $merge.Text
                    $a = Set-ConfigScalar -ConfigText $structTheirs -Key 'EngineVersion' -Value 'x'
                    $b = Set-ConfigScalar -ConfigText $cfgBase -Key 'EngineVersion' -Value 'x'
                    if ($a -cne $b) { $notes.Add('template text merged') }
                }
            }

            if (-not $structConflict) {
                $parsed = ConvertFrom-Psd1Text -Text $working
                if (-not $parsed) {
                    Add-Incoming $cfgRel '.new' $theirsCfg
                    $pending.Add([ordered]@{ path = $cfgRel; state = 'Conflict'; source = $cfgItem.Source; configDefaults = $theirsDefaults })
                    Add-SeedResult 'Conflict' $cfgRel 'the project config does not parse; fix it, then compare with .new'
                }
                else {
                    $oursDefaults = ConvertTo-ConfigDefaultsRecord -ConfigDefaults $parsed
                    $recordedNext = [ordered]@{}
                    $configConflicts = [List[object]]::new()
                    function Get-EffectiveValue([System.Collections.IDictionary] $Record, [string] $Key) {
                        if ($null -ne $Record -and $Record.Contains($Key)) { return , $Record[$Key] }
                        if ($templateValues.Contains($Key)) { return , $templateValues[$Key] }
                        return $null
                    }

                    foreach ($key in @('PublicSurface', 'DirtyHint', 'Regenerators')) {
                        $b = Get-EffectiveValue $baseDefaults $key
                        $t = Get-EffectiveValue $theirsDefaults $key
                        $o = Get-EffectiveValue $oursDefaults $key
                        $cb = ConvertTo-CanonicalJson $b; $ct = ConvertTo-CanonicalJson $t; $co = ConvertTo-CanonicalJson $o
                        $keepBase = { if ($baseDefaults.Contains($key)) { $recordedNext[$key] = $baseDefaults[$key] } }
                        $takeTheirs = { if ($theirsDefaults.Contains($key)) { $recordedNext[$key] = $theirsDefaults[$key] } }
                        if ($ct -eq $cb) { & $keepBase; continue }
                        if ($co -eq $ct) { & $takeTheirs; continue }
                        if ($co -eq $cb) {
                            $next = if ($key -eq 'Regenerators') {
                                Set-ConfigList -ConfigText $working -Key $key -ItemLines @(foreach ($r in @($t | Where-Object { $_ })) { "'" + ([string]$r -replace "'", "''") + "'" })
                            }
                            else { Set-ConfigScalar -ConfigText $working -Key $key -Value ([string]$t) }
                            if ($null -ne $next) {
                                $working = $next
                                & $takeTheirs
                                $notes.Add("$key updated")
                                continue
                            }
                        }
                        $configConflicts.Add([pscustomobject]@{ Key = $key; Base = $b; Theirs = $t; Ours = $o; Detail = '' })
                        & $keepBase
                    }

                    # Watches reconcile entry by entry, keyed by Glob + Action, so
                    # a project that added its own watch still receives the
                    # engine's fix to another.
                    $bwRaw = Get-EffectiveValue $baseDefaults 'Watches'
                    $twRaw = Get-EffectiveValue $theirsDefaults 'Watches'
                    $owRaw = Get-EffectiveValue $oursDefaults 'Watches'
                    $bw = @(foreach ($w in $bwRaw) { if ($w) { $w } })
                    $tw = @(foreach ($w in $twRaw) { if ($w) { $w } })
                    $ow = @(foreach ($w in $owRaw) { if ($w) { $w } })
                    $wm = Merge-WatchList -Base $bw -Theirs $tw -Ours $ow
                    if ($wm.Conflicts.Count) {
                        $configConflicts.Add([pscustomobject]@{ Key = 'Watches'; Base = $bw; Theirs = $tw; Ours = $ow; Detail = ($wm.Conflicts -join '; ') })
                        if ($baseDefaults.Contains('Watches')) { $recordedNext['Watches'] = $baseDefaults['Watches'] }
                    }
                    else {
                        $changedWatches = (ConvertTo-CanonicalJson $wm.Result) -ne (ConvertTo-CanonicalJson $ow)
                        $next = if ($changedWatches) { Set-ConfigList -ConfigText $working -Key 'Watches' -ItemLines @($wm.Result | ForEach-Object { Format-WatchEntry -Watch $_ }) } else { $working }
                        if ($null -eq $next) {
                            $configConflicts.Add([pscustomobject]@{ Key = 'Watches'; Base = $bw; Theirs = $tw; Ours = $ow; Detail = 'the Watches block is not in the installer''s shape' })
                            if ($baseDefaults.Contains('Watches')) { $recordedNext['Watches'] = $baseDefaults['Watches'] }
                        }
                        else {
                            if ($changedWatches) { $working = $next; $notes.Add('Watches updated') }
                            if ($theirsDefaults.Contains('Watches')) { $recordedNext['Watches'] = $theirsDefaults['Watches'] }
                        }
                    }

                    $newConfigDefaults = ConvertTo-ConfigDefaultsRecord -ConfigDefaults $recordedNext
                    if ($working -cne $oursCfg) {
                        if (ConvertFrom-Psd1Text -Text $working) {
                            $projectWrites.Add([pscustomobject]@{ Path = $cfgFull; Content = $working })
                            Add-SeedResult 'Merged' $cfgRel (($notes -join '; ') + '; review it')
                        }
                        else { throw 'Internal error: the merged project config does not parse. Nothing was written.' }
                    }
                    elseif (-not $configConflicts.Count) { Add-SeedResult 'SeedCurrent' $cfgRel }
                    $newCfgBase = Get-ConfigRendering $newConfigDefaults
                    if ($newCfgBase -cne $cfgBase) { Set-SeedBaseline $cfgRel $newCfgBase $cfgItem.Source }
                    foreach ($c in $configConflicts) {
                        $detail = if ($c.Detail) { $c.Detail } else { "engine: $(ConvertTo-CanonicalJson $c.Theirs)  project: $(ConvertTo-CanonicalJson $c.Ours)" }
                        Add-SeedResult 'ConfigConflict' "$cfgRel ($($c.Key))" $detail
                        $value = if ($theirsDefaults.Contains($c.Key)) { $theirsDefaults[$c.Key] } else { $null }
                        $pending.Add([ordered]@{ path = $cfgRel; state = 'ConfigConflict'; key = $c.Key; value = $value })
                    }
                }
            }
        }
    }

    # ── Changelog entries since this project's last refresh ────────────────
    $fromText = Get-ManifestValue 'refreshedVersion'
    if (-not $fromText) {
        # The oldest version any recorded baseline was rendered from, as the
        # stamp it was written with ([version] would drop the zero padding).
        $oldest = @(if ($recordedSeeds) {
            $recordedSeeds.Values | Where-Object { ConvertTo-EngineVersion ([string]$_['engineVersion']) } |
                Sort-Object { ConvertTo-EngineVersion ([string]$_['engineVersion']) } | Select-Object -First 1
        })
        if ($oldest.Count) { $fromText = [string]$oldest[0]['engineVersion'] }
        elseif ($manifest.PSObject.Properties['installedUtc']) {
            # Versions are date stamps, so a legacy install's date bounds the
            # changelog. ConvertFrom-Json has already made it a [datetime].
            $installed = $manifest.installedUtc
            $fromText = if ($installed -is [datetime]) {
                $installed.ToUniversalTime().ToString('yyyy.MM.dd', [cultureinfo]::InvariantCulture)
            }
            else { ([string]$installed).Substring(0, 10).Replace('-', '.') }
        }
    }
    $fromVersion = ConvertTo-EngineVersion $fromText
    $toVersion = ConvertTo-EngineVersion $engineVersion
    $scopes = @('core') + $chainNames
    # Assigned first: the parser returns its array whole, and piping the call
    # directly would hand Where-Object one array instead of each entry.
    $allEntries = Read-EngineChangelog -LiteralPath ([Path]::Combine($script:EngineRoot, 'CHANGELOG.md'))
    $changelog = @($allEntries | Where-Object {
        $v = ConvertTo-EngineVersion $_.Version
        $v -and $_.Scope -in $scopes -and ($null -eq $fromVersion -or $v -gt $fromVersion) -and ($null -eq $toVersion -or $v -le $toVersion)
    })

    # Detect patterns run over git-tracked source, never the docs or records.
    $detectHits = @{}
    $invalidPatterns = [List[string]]::new()
    $patterns = @($changelog | ForEach-Object { $_.Detect } | Sort-Object -Unique)
    if ($patterns.Count) {
        $regexes = [ordered]@{}
        foreach ($p in $patterns) {
            try { $regexes[$p] = [regex]::new($p); $detectHits[$p] = [List[string]]::new() }
            catch { $invalidPatterns.Add($p) }
        }
        $tracked = @(& git -C $TargetPath -c core.quotepath=off ls-files 2>$null)
        foreach ($rel in $tracked) {
            if ($rel -match '^(Context|\.claude|\.githooks)/' -or $rel -match '(^|/)(node_modules|dist|build|out|\.output|bin|obj|target|coverage)/') { continue }
            $full = Get-TargetFullPath -TargetPath $TargetPath -Relative $rel
            $info = [FileInfo]::new($full)
            if (-not $info.Exists -or $info.Length -gt 2MB) { continue }
            $bytes = [File]::ReadAllBytes($full)
            if ([Array]::IndexOf($bytes, [byte]0) -ge 0) { continue }
            $lines = [System.Text.Encoding]::UTF8.GetString($bytes) -split "`r?`n"
            for ($n = 0; $n -lt $lines.Count; $n++) {
                foreach ($p in $regexes.Keys) {
                    if ($regexes[$p].IsMatch($lines[$n])) { $detectHits[$p].Add("${rel}:$($n + 1)") }
                }
            }
        }
    }

    # ── Release-channel floor advisories (never applied) ───────────────────
    $advisories = [List[string]]::new()
    $targetsRel = 'Context/scripts/extension-targets.psd1'
    $targetsFull = Get-TargetFullPath -TargetPath $TargetPath -Relative $targetsRel
    if (Test-Path -LiteralPath $targetsFull) {
        $targetsData = ConvertFrom-Psd1Text -Text (Read-LfText $targetsFull)
        foreach ($t in @(if ($targetsData -and $targetsData.ContainsKey('Targets')) { $targetsData.Targets })) {
            if (-not $t) { continue }
            $browser = [string]$t.Browser
            $adapterPath = [Path]::Combine($script:StacksRoot, "$browser-extension", 'adapter.psd1')
            if (-not $browser -or -not (Test-Path -LiteralPath $adapterPath)) { continue }
            $channels = (Import-PowerShellDataFile -LiteralPath $adapterPath)['Channels']
            if (-not $channels) { continue }
            $known = (@($channels.Keys | Where-Object { $_ -ne 'Default' } | Sort-Object) | ForEach-Object { "$_ ($($channels[$_].Floor)+)" }) -join ', '
            $channel = [string]$t.Channel
            $min = [string]$t.MinVersion
            if (-not $channel) { $advisories.Add("${browser}: no release channel is recorded in $targetsRel. Reference channels: $known."); continue }
            if (-not $channels.ContainsKey($channel)) { $advisories.Add("${browser}: channel '$channel' is not one the engine knows. Reference channels: $known."); continue }
            $floor = [string]$channels[$channel].Floor
            $label = [string]$channels[$channel].Label
            if (-not $min) { $advisories.Add("${browser}: no minimum version is recorded for $label. The reference floor is $floor."); continue }
            $minMajor = 0; $floorMajor = 0
            if ([int]::TryParse(($min -split '\.')[0], [ref] $minMajor) -and [int]::TryParse(($floor -split '\.')[0], [ref] $floorMajor) -and $minMajor -lt $floorMajor) {
                $advisories.Add("The $label reference floor is now $floor (engine $engineVersion); this project's floor is $min. Raising it is a release decision: see 'Changing channel or raising the floor' in the $browser extension style document.")
            }
        }
    }

    # ── Apply ───────────────────────────────────────────────────────────────
    $writeCount = $projectWrites.Count + $baselineWrites.Count + $incomingWrites.Count
    if ($PSCmdlet.ShouldProcess($TargetPath, "Apply the seed refresh ($writeCount file write(s))")) {
        # The incoming folder holds only this run's candidates.
        if (Test-Path -LiteralPath $incomingDir) { Remove-Item -LiteralPath $incomingDir -Recurse -Force }
        $null = [Directory]::CreateDirectory($incomingDir)
        Write-Utf8NoBomFile -LiteralPath ([Path]::Combine($incomingDir, '.gitignore')) -Content "*`n"
        foreach ($w in @($projectWrites) + @($baselineWrites) + @($incomingWrites)) { Write-Utf8NoBomFile -LiteralPath $w.Path -Content $w.Content }
        foreach ($d in $baselineDeletes) { if (Test-Path -LiteralPath $d) { Remove-Item -LiteralPath $d -Force } }
        if ($pending.Count) {
            $pendingDoc = [ordered]@{
                engineVersion = $engineVersion; createdUtc = $nowUtc; stack = $stackName; chain = $chainNames
                items = $pending.ToArray()
            }
            Write-Utf8NoBomFile -LiteralPath $pendingPath -Content ((ConvertTo-Json -InputObject $pendingDoc -Depth 10) + "`n")
        }
    }

    $manifestUpdates['schema']           = $script:ManifestSchema
    $manifestUpdates['refreshedUtc']     = $nowUtc
    $manifestUpdates['refreshedVersion'] = $engineVersion
    $manifestUpdates['stack']            = if ($chainNames.Count) { $chainNames[-1] } else { 'None' }
    $manifestUpdates['chain']            = $chainNames
    $manifestUpdates['tokens']           = $tokens
    $manifestUpdates['seeds']            = Get-SortedSeedRecords
    $manifestUpdates['optOut']           = @($optOut | Sort-Object)
    if ($null -ne $newConfigDefaults) { $manifestUpdates['configDefaults'] = $newConfigDefaults }
}

# ── Rewrite manifest + bump EngineVersion in the project config ─────────────
# The engine-owned reconciliation fields always change; a refresh adds its
# own. Every other key the installer recorded (schema 2: stack, chain, tokens,
# seeds, configDefaults, optOut) is carried forward untouched: the seed
# baselines it indexes are the merge base for a later refresh, and dropping
# them would silently turn this project back into a legacy install.
if ($PSCmdlet.ShouldProcess('.claude/context-engine-manifest.json', 'Rewrite baseline manifest')) {
    $updates = [ordered]@{
        engineVersion = $engineVersion
        updatedUtc    = $nowUtc
        files         = $newHashes
    }
    foreach ($k in $manifestUpdates.Keys) { $updates[$k] = $manifestUpdates[$k] }
    Write-Manifest $updates
}

# The pin set grows as the engine's footprint does, so re-sync it here too —
# an install predating a new pin would otherwise keep churning line endings.
$gaResult = $null
if ($PSCmdlet.ShouldProcess('.gitattributes', 'Sync engine LF pins')) {
    $gaResult = Sync-GitAttributesPin -TargetPath $TargetPath
}

$configPath = [Path]::Combine($TargetPath, '.claude', 'context-engine.psd1')
if (Test-Path -LiteralPath $configPath) {
    $configText = [File]::ReadAllText($configPath)
    $bumped = $configText -replace "(?m)^(\s*EngineVersion\s*=\s*')[^']*(')", "`${1}$engineVersion`${2}"
    if ($bumped -cne $configText -and $PSCmdlet.ShouldProcess('.claude/context-engine.psd1', 'Bump EngineVersion')) {
        Write-Utf8NoBomFile -LiteralPath $configPath -Content $bumped
    }
}

# ── Report ──────────────────────────────────────────────────────────────────
$results | Group-Object State | Sort-Object Name | ForEach-Object {
    Write-Host ("  {0,-20} {1}" -f "$($_.Name):", $_.Count)
}
if ($gaResult -and $gaResult -ne 'already pinned') {
    Write-Host ("  {0,-20} {1}" -f '.gitattributes:', $gaResult)
}
$interesting = @($results | Where-Object State -ne 'UpToDate')
if ($interesting.Count) {
    Write-Host ''
    $interesting | Format-Table -AutoSize | Out-Host
}
$skipped = @($results | Where-Object State -eq 'ModifiedSkip')
if ($skipped.Count) {
    Write-Host 'WARNING: the ModifiedSkip file(s) above were hand-edited in this project and were left alone.'
    Write-Host '         Engine-owned files should not be hand-edited — upstream the change into the'
    Write-Host '         context-engine template instead, or re-run with -Force to discard the local edit.'
}

if ($RefreshSeeds) {
    Write-Host ''
    Write-Host ("Seed refresh: engine {0} -> {1}, stack {2} ({3})" -f $(if ($fromText) { $fromText } else { 'unknown' }), $engineVersion,
        $manifestUpdates['stack'], $(if ($chainNames.Count) { $chainNames -join ' -> ' } else { 'core only' }))
    $seedResults | Group-Object State | Sort-Object Name | ForEach-Object {
        Write-Host ("  {0,-20} {1}" -f "$($_.Name):", $_.Count)
    }
    $seedInteresting = @($seedResults | Where-Object State -notin @('SeedCurrent', 'Adopted'))
    if ($seedInteresting.Count) {
        Write-Host ''
        $seedInteresting | Sort-Object State, File | Format-Table -AutoSize -Wrap | Out-Host
    }
    if ($changelog.Count) {
        Write-Host ("Engine changelog: {0} entr(ies) since {1}" -f $changelog.Count, $(if ($fromText) { $fromText } else { 'install' }))
        foreach ($e in $changelog) {
            $hitCount = (@($e.Detect | ForEach-Object { if ($detectHits.ContainsKey($_)) { $detectHits[$_].Count } else { 0 } }) | Measure-Object -Sum).Sum
            $suffix = if ($e.Detect.Count) { "  [Detect: $hitCount hit(s)]" } else { '' }
            Write-Host ("  {0} {1} {2}: {3}{4}" -f $e.Version, $e.Scope, $e.Kind, $e.Text, $suffix)
        }
    }
    foreach ($a in $advisories) { Write-Host "ADVISORY: $a" }
    foreach ($p in $invalidPatterns) { Write-Host "WARNING: the changelog Detect pattern '$p' is not a valid regular expression." }

    # The same, as a file the skill (and a person) can work through.
    $md = [System.Text.StringBuilder]::new()
    $null = $md.AppendLine('# Context Engine Refresh Report').AppendLine()
    $null = $md.AppendLine(("Engine {0} to {1}, stack ``{2}`` ({3}). Generated {4}." -f $(if ($fromText) { $fromText } else { '(unknown)' }), $engineVersion,
        $manifestUpdates['stack'], $(if ($chainNames.Count) { $chainNames -join ' -> ' } else { 'core only' }), $nowUtc)).AppendLine()
    $null = $md.AppendLine('## States').AppendLine()
    $null = $md.AppendLine('| State | Files |').AppendLine('| ----- | ----- |')
    foreach ($g in ($seedResults | Group-Object State | Sort-Object Name)) { $null = $md.AppendLine("| $($g.Name) | $($g.Count) |") }
    $null = $md.AppendLine()
    $order = @('Conflict', 'ConfigConflict', 'Legacy', 'Proposed', 'Merged', 'FastForward', 'New', 'DeletedByProject', 'UpstreamRemoved', 'Excluded')
    $headings = @{
        Conflict = 'Conflicts (not written)'; ConfigConflict = 'Config conflicts (not written)'; Legacy = 'Two-way reviews (no baseline)'
        Proposed = 'Proposals (never written)'; Merged = 'Merged (written; review)'; FastForward = 'Fast-forwarded (written)'
        New = 'New files (written)'; DeletedByProject = 'Deleted by this project'; UpstreamRemoved = 'No longer shipped by the engine'
        Excluded = 'Excluded by SeedRefreshExclude'
    }
    foreach ($state in $order) {
        $rows = @($seedResults | Where-Object State -eq $state | Sort-Object File)
        if (-not $rows.Count) { continue }
        $null = $md.AppendLine("## $($headings[$state])").AppendLine()
        foreach ($r in $rows) {
            $line = "- ``$($r.File)``"
            if ($r.Note) { $line += ": $($r.Note)" }
            $null = $md.AppendLine($line)
        }
        $null = $md.AppendLine()
    }
    if ($changelog.Count) {
        $null = $md.AppendLine('## Engine changelog since this project''s last refresh').AppendLine()
        foreach ($e in $changelog) {
            $null = $md.AppendLine("- **$($e.Kind):** ($($e.Version), ``$($e.Scope)``) $($e.Text)")
            if ($e.Impact) { $null = $md.AppendLine("  - Impact: $($e.Impact)") }
            foreach ($p in $e.Detect) {
                $hits = @(if ($detectHits.ContainsKey($p)) { $detectHits[$p] })
                $shown = @($hits | Select-Object -First 20)
                $more = if ($hits.Count -gt $shown.Count) { " (and $($hits.Count - $shown.Count) more)" } else { '' }
                $where = if ($hits.Count) { ($shown | ForEach-Object { "``$_``" }) -join ', ' } else { 'no hits' }
                $null = $md.AppendLine("  - Detect ``$p``: $($hits.Count) hit(s): $where$more")
            }
        }
        $null = $md.AppendLine()
    }
    if ($advisories.Count) {
        $null = $md.AppendLine('## Advisories (never applied)').AppendLine()
        foreach ($a in $advisories) { $null = $md.AppendLine("- $a") }
        $null = $md.AppendLine()
    }
    $null = $md.AppendLine('## Next steps').AppendLine()
    $null = $md.AppendLine('1. Review every Merged file, and resolve each Conflict, Legacy, Proposed, and ConfigConflict item (candidates are next to this report as `<path>.new`, `.merge`, and `.diff`).')
    $null = $md.AppendLine('2. Run `Update-ContextEngine.ps1 -CompleteRefresh` to record the new baselines.')
    $null = $md.AppendLine('3. Turn Detect hits into fixes or a spec, run `/refresh-context`, and commit the refresh as one change.')
    if (-not $WhatIfPreference) {
        Write-Utf8NoBomFile -LiteralPath ([Path]::Combine($incomingDir, 'refresh-report.md')) -Content $md.ToString()
        Write-Host ''
        Write-Host "Report: $script:IncomingRoot/refresh-report.md"
        if ($pending.Count) {
            Write-Host "$($pending.Count) item(s) need a decision. Resolve them, then run -CompleteRefresh."
        }
    }
}

Write-Host ''
Write-Host 'Reminder: hooks/commands/skills reload at Claude Code session start — restart to pick up changes.'

exit 0
