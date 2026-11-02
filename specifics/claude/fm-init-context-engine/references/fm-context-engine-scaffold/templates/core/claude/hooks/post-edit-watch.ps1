#Requires -Version 7.1
using namespace System.IO

<#
.SYNOPSIS
    PostToolUse hook — config-driven watch layer. Matches edited files against
    the Watches list in .claude/context-engine.psd1 and runs the configured
    action.

.DESCRIPTION
    Runs after any Write or Edit tool call. Parses the hook input JSON from
    stdin, determines the changed file's path, and evaluates it against each
    watch entry:

        @{
            Watches = @(
                # Fast follow-up: run a command right now (manifest refresh,
                # typecheck, lint). Non-zero exit is reported, never blocking.
                @{ Glob = 'Module/Public/**/*.ps1'
                   Action = 'Run'
                   Command = 'pwsh -NoProfile -File ./Module/Build-QuickRefresh.ps1 -SkipValidation'
                   Message = 'manifest refreshed' }

                # Slow follow-up: don't run it now — append to
                # .claude/.dirty-marker so the next SessionStart surfaces it.
                @{ Glob = 'src/**/*.cs'
                   Action = 'MarkDirty'
                   Hint = 'run dotnet build to rebuild the assembly' }
            )
        }

    Glob semantics: '/' or '\' both accepted; '**' spans directories; '*' and
    '?' stay within one path segment. Matching is case-insensitive against the
    edited file's repo-relative path, anchored at both ends — 'src/**/*.cs'
    matches only under src/, and '*.md' matches only at the repo root (use
    '**/*.md' for any depth). Edits outside the repo root never match.

    The first matching watch of each Action kind fires (multiple watches can
    fire for one edit if they differ in Action). Failures never block the
    session. Disable temporarily by creating '.claude/disable-post-edit-watch'.

    This file is engine-owned (context-engine template); project-specific
    values belong in .claude/context-engine.psd1, not here.
#>

[CmdletBinding()]
param()

function Convert-GlobToRegex {
    param([Parameter(Mandatory)] [string] $Glob)
    $g = $Glob -replace '\\', '/'
    $p = [regex]::Escape($g)
    # After [regex]::Escape: '*' => '\*', '?' => '\?', '/' stays '/'
    $p = $p -replace '\\\*\\\*/', '(?:[^/]+/)*'   # '**/' — zero or more whole segments
    $p = $p -replace '\\\*\\\*', '.*'             # bare '**'
    $p = $p -replace '\\\*', '[^/]*'              # '*' — within a segment
    $p = $p -replace '\\\?', '[^/]'               # '?' — single char within a segment
    return "(?i)^$p`$"
}

try {
    # ── Read + parse hook input ──────────────────────────────
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }

    $hookInput = $raw | ConvertFrom-Json -ErrorAction Stop
    $filePath  = $hookInput.tool_input.file_path
    if (-not $filePath) { exit 0 }

    $repoRoot = $env:CLAUDE_PROJECT_DIR
    if (-not $repoRoot) { exit 0 }

    # ── Disable-switch + config checks ───────────────────────
    $disableFlag = [Path]::Combine($repoRoot, '.claude', 'disable-post-edit-watch')
    if (Test-Path -LiteralPath $disableFlag) { exit 0 }

    $configPath = [Path]::Combine($repoRoot, '.claude', 'context-engine.psd1')
    if (-not (Test-Path -LiteralPath $configPath)) { exit 0 }

    $config = Import-PowerShellDataFile -LiteralPath $configPath
    if (-not $config.Watches) { exit 0 }

    # ── Normalize edited path to repo-relative forward slashes ─
    # Edits outside the repo root never trigger watches.
    $normalized = ($filePath -replace '\\', '/')
    $rootNorm   = (($repoRoot -replace '\\', '/').TrimEnd('/')) + '/'
    if ($normalized.StartsWith($rootNorm, [System.StringComparison]::OrdinalIgnoreCase)) {
        $normalized = $normalized.Substring($rootNorm.Length)
    }
    elseif ($normalized -match '^([A-Za-z]:/|/)') {
        exit 0
    }

    # ── Evaluate watches; first match per Action kind fires ──
    $firedActions = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($watch in $config.Watches) {
        if (-not $watch.Glob -or -not $watch.Action) { continue }
        if ($firedActions.Contains([string]$watch.Action)) { continue }
        if ($normalized -notmatch (Convert-GlobToRegex -Glob $watch.Glob)) { continue }

        $null = $firedActions.Add([string]$watch.Action)
        $leaf = [Path]::GetFileName($filePath)

        switch ([string]$watch.Action) {
            'Run' {
                if (-not $watch.Command) { continue }
                Push-Location $repoRoot
                try {
                    # $LASTEXITCODE is $null until a native command runs in this
                    # process; a pure-PowerShell Command would false-fail without this.
                    $global:LASTEXITCODE = 0
                    $output = Invoke-Expression $watch.Command 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        Write-Output "post-edit-watch: command failed (exit $LASTEXITCODE) after ``$leaf`` edit. Tail:"
                        Write-Output (($output | Select-Object -Last 8) -join "`n")
                    }
                    else {
                        $msg = if ($watch.Message) { $watch.Message } else { "ran ``$($watch.Command)``" }
                        Write-Output "post-edit-watch: $msg after ``$leaf`` edit"
                    }
                }
                finally {
                    Pop-Location
                }
            }
            'MarkDirty' {
                $marker = [Path]::Combine($repoRoot, '.claude', '.dirty-marker')
                $stamp  = Get-Date -AsUTC -Format 'yyyy-MM-ddTHH:mm:ssZ'
                Add-Content -LiteralPath $marker -Value "$stamp`t$filePath"
                $hint = if ($watch.Hint) { " — $($watch.Hint)" } else { '' }
                Write-Output "post-edit-watch: marked ``$leaf`` dirty$hint"
            }
            default {
                Write-Output "post-edit-watch: unknown Action '$($watch.Action)' in context-engine.psd1 — expected 'Run' or 'MarkDirty'"
            }
        }
    }
}
catch {
    # Don't block on hook failures. Log for diagnosis.
    $logPath = [Path]::Combine($env:CLAUDE_PROJECT_DIR, '.claude', 'post-edit-watch.log')
    try {
        "$(Get-Date -AsUTC -Format 'yyyy-MM-ddTHH:mm:ssZ')  $_" |
            Add-Content -LiteralPath $logPath -ErrorAction SilentlyContinue
    } catch { }
}

exit 0
