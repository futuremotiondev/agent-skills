#Requires -Version 7.1
using namespace System.IO
using namespace System.Collections.Generic

<#
.SYNOPSIS
    Scaffolds the context-engine system (Context/ knowledge tree + .claude/
    automation layer + .githooks/) into a target repository.

.DESCRIPTION
    Deterministic Layer-A installer per docs/DESIGN.md: copies templates/core/
    (plus an optional stack adapter overlay), substitutes installer-owned
    {{TOKEN}}s, merges hook registrations into .claude/settings.json without
    clobbering existing content, and verifies no installer-owned tokens remain.

    It also records the install at .claude/context-engine-manifest.json
    (schema 2): baseline hashes for engine-owned files, plus the adapter
    chain, the installer's token answers, the spliced config defaults, and a
    hash per seeded file. Every seeded file is snapshotted as installed under
    .claude/context-engine/baseline/<path>.base, the common ancestor a later
    seed refresh needs for a three-way merge.

    Skill-owned tokens ({{PROJECT_DESCRIPTION}}, {{DO_LIST}}, ...) are left in
    place — the /fm-init-context-engine skill's authoring pass resolves them.

.PARAMETER TargetPath
    Repository to install into. Default: current directory.

.PARAMETER Stack
    Stack adapter name under templates/stacks/ (e.g. 'csharp',
    'winui3'), or 'None' (default) for the core-only install.

.PARAMETER ProjectName
    Display name substituted for {{PROJECT_NAME}}. Default: target leaf dir.

.PARAMETER MainBranch
    Substituted for {{MAIN_BRANCH}}. Default: the target's current branch,
    falling back to 'main'.

.PARAMETER PrimaryExtension
    Main source extension (no dot) for {{PRIMARY_EXT}}. Default: the stack
    adapter's value, falling back to the literal 'ext'.

.PARAMETER InitGit
    Run 'git init' on the target if it is not already a git repository.
    Without this switch, a non-repo target is a hard error.

.PARAMETER Force
    Proceed even when Context/, .claude/commands/, a prior install manifest,
    or any file the install would write (a hand-written CLAUDE.md, for
    example) already exist. Existing files are overwritten.

.PARAMETER Verify
    Verification-only mode: scan an already-installed target for leftover
    tokens and report; install nothing. Exit code 1 if installer-owned
    tokens remain.

.EXAMPLE
    .\Install-ContextEngine.ps1 -TargetPath X:\my-new-app -ProjectName 'MyApp' -InitGit

.EXAMPLE
    .\Install-ContextEngine.ps1 -TargetPath X:\my-new-app -Verify
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Position = 0)]
    [string] $TargetPath = (Get-Location).ProviderPath,

    [string] $Stack = 'None',

    [string] $ProjectName,

    [string] $MainBranch,

    [string] $PrimaryExtension,

    [switch] $InitGit,

    [switch] $Force,

    [switch] $Verify
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path -Path $PSScriptRoot -ChildPath 'lib/common.ps1')

$TargetPath = [Path]::GetFullPath($TargetPath)
if (-not (Test-Path -LiteralPath $TargetPath -PathType Container)) {
    throw "Target path does not exist or is not a directory: $TargetPath"
}

# ── Verify-only mode ────────────────────────────────────────────────────────
if ($Verify) {
    $installerLeft = @(Find-LeftoverTokens -TargetPath $TargetPath -TokenNames $script:InstallerTokens)
    $skillLeft     = @(Find-LeftoverTokens -TargetPath $TargetPath -TokenNames $script:SkillTokens)

    if ($installerLeft.Count) {
        Write-Host 'FAIL — installer-owned tokens remain (these must never survive an install):'
        $installerLeft | Format-Table -AutoSize | Out-Host
    }
    else {
        Write-Host 'OK — no installer-owned tokens remain.'
    }

    if ($skillLeft.Count) {
        $pendingFiles = @($skillLeft | Select-Object -ExpandProperty File -Unique)
        Write-Host ("INFO — {0} skill-owned token site(s) across {1} file(s) await the /fm-init-context-engine authoring pass:" -f $skillLeft.Count, $pendingFiles.Count)
        $skillLeft | Format-Table -AutoSize | Out-Host
    }
    else {
        Write-Host 'OK — no skill-owned tokens remain (authoring pass complete).'
    }

    exit ([int][bool]$installerLeft.Count)
}

# ── Preflight ───────────────────────────────────────────────────────────────
& git -C $TargetPath rev-parse --is-inside-work-tree 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    if ($InitGit) {
        if ($PSCmdlet.ShouldProcess($TargetPath, 'git init')) {
            & git init $TargetPath | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "git init failed for $TargetPath" }
        }
    }
    else {
        throw "Target is not a git repository: $TargetPath. Run 'git init' first or pass -InitGit."
    }
}

$manifestPath = [Path]::Combine($TargetPath, '.claude', 'context-engine-manifest.json')
if ((Test-Path -LiteralPath $manifestPath) -and -not $Force) {
    $existing = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    Write-Host ("Already installed (engine version {0}, installed {1}). Nothing to do." -f $existing.engineVersion, $existing.installedUtc)
    Write-Host 'Use Update-ContextEngine.ps1 to sync engine-owned files, or re-run with -Force to reinstall.'
    exit 0
}

foreach ($blocker in @('Context', [Path]::Combine('.claude', 'commands'))) {
    $blockerPath = [Path]::Combine($TargetPath, $blocker)
    if ((Test-Path -LiteralPath $blockerPath) -and -not $Force) {
        throw "'$blocker' already exists in the target. This looks like a pre-existing context system — reconcile manually or re-run with -Force to overwrite."
    }
}

# ── Stack adapter chain (parent-first per Inherits) ─────────────────────────
# Resolved to the adapter directories' real names, so the manifest records the
# canonical chain even when -Stack or an Inherits value differs in case.
$adapterChain = Resolve-AdapterChain -Stack $Stack

# ── Resolve installer-owned token values ────────────────────────────────────
$engineVersion = Get-EngineVersion
$tokens = Get-InstallerTokenValues -TargetPath $TargetPath -Chain $adapterChain -ProjectName $ProjectName `
    -MainBranch $MainBranch -PrimaryExtension $PrimaryExtension

# ── Build the install plan (core first, adapter overlays override) ──────────
$planned = Get-InstallPlan -Chain $adapterChain

# ── Refuse to overwrite files the target already has ────────────────────────
# The blockers above catch an earlier install. This catches the rest: a
# hand-written CLAUDE.md, a .githooks/commit-msg, or a rule file of the same
# name, which the copy loop below would otherwise replace without a word.
if (-not $Force) {
    $collisions = @($planned.Values | Where-Object {
            $existingPath = [Path]::Combine($TargetPath, ($_.TargetRelative -replace '/', [Path]::DirectorySeparatorChar))
            Test-Path -LiteralPath $existingPath -PathType Leaf
        } | ForEach-Object { $_.TargetRelative } | Sort-Object)
    # A script block, not ForEach-Object -MemberName: the member form honours
    # ShouldProcess, so under -WhatIf it returns nothing and the guard is skipped.
    if ($collisions.Count) {
        throw ("The target already has {0} file(s) this install would overwrite: {1}. This looks like a pre-existing context system — reconcile manually or re-run with -Force to overwrite." -f $collisions.Count, ($collisions -join ', '))
    }
}

# Design tripwire: engine-owned templates must be token-free, or the updater's
# byte-level template comparison breaks.
$allTokenPattern = '\{\{(' + (($script:InstallerTokens + $script:SkillTokens) -join '|') + ')\}\}'
foreach ($item in $planned.Values) {
    if ($item.EngineOwned -and (([File]::ReadAllText($item.FullPath)) -match $allTokenPattern)) {
        throw "Design violation: engine-owned template '$($item.TemplateRelative)' contains tokens. Engine-owned files must be token-free."
    }
}

# ── Copy + substitute ───────────────────────────────────────────────────────
$written = [List[object]]::new()
foreach ($item in $planned.Values) {
    $dest = [Path]::Combine($TargetPath, ($item.TargetRelative -replace '/', [Path]::DirectorySeparatorChar))
    if ($PSCmdlet.ShouldProcess($item.TargetRelative, 'Install file')) {
        $content = [File]::ReadAllText($item.FullPath)
        $content = Expand-InstallerTokens -Content $content -TokenValues $tokens
        Write-Utf8NoBomFile -LiteralPath $dest -Content $content
        $written.Add($item)
    }
}

# ── Apply stack ConfigDefaults to the installed context-engine.psd1 ─────────
# Adapters may carry ConfigDefaults = @{ Watches; Regenerators; PublicSurface;
# DirtyHint } in adapter.psd1. Per-key last-wins across the Inherits chain;
# values are spliced textually into the installed (project-owned) config so
# the core template stays the single structural source.
$configDefaults = Get-MergedConfigDefaults -Chain $adapterChain
$projectConfigPath = [Path]::Combine($TargetPath, '.claude', 'context-engine.psd1')
if ($configDefaults.Count -gt 0 -and (Test-Path -LiteralPath $projectConfigPath) -and
    $PSCmdlet.ShouldProcess('.claude/context-engine.psd1', 'Apply stack config defaults')) {

    $configText = Invoke-ConfigDefaultsSplice -ConfigText ([File]::ReadAllText($projectConfigPath)) -ConfigDefaults $configDefaults
    Write-Utf8NoBomFile -LiteralPath $projectConfigPath -Content $configText
    # Tripwire: the spliced config must still be valid psd1.
    $null = Import-PowerShellDataFile -LiteralPath $projectConfigPath
}

# ── Merge settings fragment into .claude/settings.json ──────────────────────
$fragmentPath = [Path]::Combine($script:TemplateCore, 'claude', 'settings.fragment.json')
$settingsPath = [Path]::Combine($TargetPath, '.claude', 'settings.json')
$settingsResult = '(skipped — WhatIf)'
if ($PSCmdlet.ShouldProcess('.claude/settings.json', 'Merge hook registrations')) {
    $settingsResult = Merge-SettingsFragment -FragmentPath $fragmentPath -SettingsPath $settingsPath
}

# ── Pin LF for engine-written paths in the target's .gitattributes ──────────
$gaResult = 'skipped (WhatIf)'
if ($PSCmdlet.ShouldProcess('.gitattributes', 'Sync engine LF pins')) {
    $gaResult = Sync-GitAttributesPin -TargetPath $TargetPath
}

# ── Snapshot every seeded file (the refresh baseline) ───────────────────────
# Seeded files are project-owned from here on: the authoring pass and the
# maintainer edit them freely. A future refresh can only tell those edits
# apart from engine template changes if it knows what the engine originally
# wrote, so each one is copied as installed (after installer tokens and the
# ConfigDefaults splice, before any authoring) and hashed into the manifest.
$seedRecords = [ordered]@{}
$seeds = @($written | Where-Object { -not $_.EngineOwned } | Sort-Object TargetRelative)
if ($seeds.Count -and $PSCmdlet.ShouldProcess($script:BaselineRoot, 'Record seed baselines')) {
    # -Force reinstalls from scratch; snapshots left from the previous install
    # would otherwise linger for seeds this install no longer writes.
    $baselineDir = [Path]::Combine($TargetPath, ($script:BaselineRoot -replace '/', [Path]::DirectorySeparatorChar))
    if (Test-Path -LiteralPath $baselineDir) {
        Remove-Item -LiteralPath $baselineDir -Recurse -Force
    }
    foreach ($item in $seeds) {
        $installedPath = [Path]::Combine($TargetPath, ($item.TargetRelative -replace '/', [Path]::DirectorySeparatorChar))
        $snapshotPath  = Get-SeedBaselinePath -TargetPath $TargetPath -TargetRelative $item.TargetRelative
        Write-Utf8NoBomFile -LiteralPath $snapshotPath -Content ([File]::ReadAllText($installedPath))
        $seedRecords[$item.TargetRelative] = [ordered]@{
            source        = $item.Source
            engineVersion = $engineVersion
            hash          = Get-NormalizedContentHash -LiteralPath $installedPath
        }
    }
}

# ── Write the install manifest (schema 2) ───────────────────────────────────
# Records everything a refresh needs to re-render the templates the way this
# install did: the chain, the installer's token answers, and the spliced
# config defaults. TODAY and ENGINE_VERSION are left out on purpose: they
# describe the moment of rendering, so a refresh renders both fresh (the
# install-time version is kept once, as engineVersion).
if ($written.Count -gt 0 -and $PSCmdlet.ShouldProcess('.claude/context-engine-manifest.json', 'Write install manifest')) {
    $fileHashes = [ordered]@{}
    foreach ($item in ($written | Where-Object EngineOwned | Sort-Object TargetRelative)) {
        $installedPath = [Path]::Combine($TargetPath, ($item.TargetRelative -replace '/', [Path]::DirectorySeparatorChar))
        $fileHashes[$item.TargetRelative] = Get-NormalizedContentHash -LiteralPath $installedPath
    }
    $answers = [ordered]@{}
    foreach ($key in (@($tokens.Keys) | Where-Object { $_ -notin @('TODAY', 'ENGINE_VERSION') } | Sort-Object)) {
        $answers[$key] = [string]$tokens[$key]
    }
    $chainNames = @($adapterChain | Select-Object -ExpandProperty Name)
    $manifest = [ordered]@{
        schema         = $script:ManifestSchema
        engineVersion  = $engineVersion
        installedUtc   = (Get-Date -AsUTC -Format 'yyyy-MM-ddTHH:mm:ssZ')
        stack          = if ($chainNames.Count) { $chainNames[-1] } else { 'None' }
        chain          = $chainNames
        tokens         = $answers
        files          = $fileHashes
        seeds          = $seedRecords
        configDefaults = ConvertTo-ConfigDefaultsRecord -ConfigDefaults $configDefaults
        optOut         = @()
    }
    Write-Utf8NoBomFile -LiteralPath $manifestPath -Content (($manifest | ConvertTo-Json -Depth 8) + "`n")
}

# ── Post-install verification (installer tokens must be gone) ───────────────
if ($written.Count -gt 0) {
    $leftovers = @(Find-LeftoverTokens -TargetPath $TargetPath -TokenNames $script:InstallerTokens)
    if ($leftovers.Count) {
        $leftovers | Format-Table -AutoSize | Out-Host
        throw 'Install verification failed: installer-owned tokens remain (see table above).'
    }
}

# ── Report + next steps ─────────────────────────────────────────────────────
$stackLabel = if ($adapterChain.Count) { ($adapterChain | Select-Object -ExpandProperty Name) -join ' -> ' } else { 'core only' }
Write-Host ''
Write-Host ("context-engine {0} installed into {1}" -f $engineVersion, $TargetPath)
Write-Host ("  Files written : {0} ({1})" -f $written.Count, $stackLabel)
Write-Host ("  settings.json : {0}" -f $settingsResult)
Write-Host ("  .gitattributes: {0}" -f $gaResult)
Write-Host ''
Write-Host 'Next steps:'
Write-Host '  1. git config core.hooksPath .githooks        (activates the commit-msg policy hook)'
Write-Host '  2. Restart Claude Code in this directory      (hooks/commands/skills load at session start)'
Write-Host '  3. Run the /fm-init-context-engine authoring pass (fills project-specific content), or'
Write-Host '     hand-edit CLAUDE.md, Context/roadmap/current.md, Context/conventions/agent-rules.md,'
Write-Host '     and .claude/context-engine.psd1 (Watches / Regenerators / PublicSurface).'
Write-Host '  4. Verify any time with: Install-ContextEngine.ps1 -TargetPath <path> -Verify'

# Git probes above may have left a nonzero $LASTEXITCODE (e.g. no origin remote);
# exit explicitly so callers see success.
exit 0
