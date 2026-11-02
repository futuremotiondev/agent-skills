#Requires -Version 7.1
using namespace System.IO

<#
.SYNOPSIS
    SessionStart hook — emits a one-screen orientation briefing to stdout.

.DESCRIPTION
    Runs once per Claude Code session. Prints current branch, recent commits,
    active specs, and the roadmap head. Claude Code surfaces stdout content to
    the model, so the briefing becomes part of the session's initial context
    without bloating CLAUDE.md.

    The stale-build hint text can be customized per project via the DirtyHint
    key in .claude/context-engine.psd1.

    Never blocks session startup — any failure here is swallowed with exit 0.
    This file is engine-owned (context-engine template); project-specific
    values belong in .claude/context-engine.psd1, not here.
#>

[CmdletBinding()]
param()

try {
    $repoRoot = $env:CLAUDE_PROJECT_DIR
    if (-not $repoRoot) {
        $repoRoot = (Get-Location).ProviderPath
    }

    Push-Location $repoRoot
    try {
        # ── Branch + recent commits ──────────────────────────────
        $branch = (& git rev-parse --abbrev-ref HEAD 2>$null).Trim()
        $log    = & git log --oneline -10 2>$null

        # ── Active specs under Context/specs/active/ ─────────────
        $specsDir = [Path]::Combine($repoRoot, 'Context', 'specs', 'active')
        $activeSpecs = if (Test-Path -LiteralPath $specsDir) {
            Get-ChildItem -LiteralPath $specsDir -Directory -ErrorAction SilentlyContinue |
                Sort-Object Name |
                Select-Object -ExpandProperty Name
        } else { @() }

        # ── Roadmap head: first ~60 lines of Context/roadmap/current.md ─
        $roadmapPath = [Path]::Combine($repoRoot, 'Context', 'roadmap', 'current.md')
        $roadmapHead = if (Test-Path -LiteralPath $roadmapPath) {
            (Get-Content -LiteralPath $roadmapPath -TotalCount 60) -join "`n"
        } else {
            '_(Context/roadmap/current.md not found)_'
        }

        # ── Stale-build hint (customizable via config) ───────────
        $dirtyMarker = [Path]::Combine($repoRoot, '.claude', '.dirty-marker')
        $dirtyHint = ''
        if (Test-Path -LiteralPath $dirtyMarker) {
            $hintText = 'Watched source files were edited in a prior session without running the ' +
                        'follow-up action. See `.claude/.dirty-marker` for the file list; delete the ' +
                        'marker after handling it.'
            $configPath = [Path]::Combine($repoRoot, '.claude', 'context-engine.psd1')
            if (Test-Path -LiteralPath $configPath) {
                try {
                    $cfg = Import-PowerShellDataFile -LiteralPath $configPath
                    if ($cfg.DirtyHint) { $hintText = $cfg.DirtyHint }
                } catch { }
            }
            $dirtyHint = "`n**Stale build output.** $hintText"
        }

        # ── Emit ─────────────────────────────────────────────────
        Write-Output "# Session briefing"
        Write-Output ""
        Write-Output "**Branch:** ``$branch``"
        Write-Output ""
        Write-Output "**Recent commits:**"
        Write-Output ""
        Write-Output '```'
        Write-Output ($log -join "`n")
        Write-Output '```'
        Write-Output ""
        $specsList = if ($activeSpecs) {
            ($activeSpecs | ForEach-Object { '`' + $_ + '`' }) -join ', '
        } else { '_(none)_' }
        Write-Output "**Active specs:** $specsList"
        Write-Output ""
        Write-Output "**Roadmap cursor** (from ``Context/roadmap/current.md``):"
        Write-Output ""
        Write-Output $roadmapHead
        Write-Output $dirtyHint
    }
    finally {
        Pop-Location
    }
}
catch {
    # Never block session startup. Log to a file for diagnosis but exit 0.
    $logPath = [Path]::Combine($env:CLAUDE_PROJECT_DIR, '.claude', 'session-start.log')
    try {
        "$(Get-Date -AsUTC -Format 'yyyy-MM-ddTHH:mm:ssZ')  $_" |
            Add-Content -LiteralPath $logPath -ErrorAction SilentlyContinue
    } catch { }
}

exit 0
