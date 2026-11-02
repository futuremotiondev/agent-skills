#Requires -Version 7.4
<#
.SYNOPSIS
    Delivers validated presets from staging into ReNamer's Presets folder,
    never overwriting silently.

.DESCRIPTION
    Copies each staged .rnp into <ReNamerPath>\Presets (or a subfolder).

      * New preset: copied, reported as Installed.
      * Existing preset with identical bytes: reported as Unchanged.
      * Existing preset that differs: NOT touched unless -Force. The result
        carries a rule-level diff (rules added or removed, IDs, Config keys,
        Marked, Comment, [Filters]) so the change can be shown to Jay and
        confirmed first. With -Force the old file is backed up to BackupDir
        (config.json, %TEMP%\rnp-backups) with a timestamp, then replaced.

    Backups never go inside Presets: every .rnp there appears in ReNamer's
    preset menu. Supports -WhatIf.

.PARAMETER LiteralPath
    Path to one or more staged .rnp files.

.PARAMETER Subfolder
    Optional subfolder of Presets, e.g. 'Icons'. Defaults to
    PresetsSubfolder from config.json.

.PARAMETER Force
    Replace a differing existing preset (after backing it up), or install
    even though a preset with the same name lives in another Presets
    subfolder. Only use it after Jay confirmed.

.INPUTS
    System.String[]
    Pipe staged .rnp paths or FileInfo objects.

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Source, Target, Action (Installed, Unchanged, NeedsConfirmation,
    Replaced), Backup, Diff (string[]).

.EXAMPLE
    ./Install-RnpPreset.ps1 "$env:TEMP\rnp-staging\FILE Remove Envato Timestamp.rnp"
    Installs a new preset, or reports the diff when one already exists.

.EXAMPLE
    Get-ChildItem "$env:TEMP\rnp-staging\*Envato*.rnp" |
        ./Install-RnpPreset.ps1 -Force
    Replaces both variants after confirmation, backing up the old files.

.EXAMPLE
    ./Install-RnpPreset.ps1 .\staged.rnp -Subfolder Icons -WhatIf
    Shows what would happen without writing anything.

.NOTES
    Run Test-RnpPreset.ps1 first; this script only moves files. Exit code 1
    when any preset still needs confirmation.

.LINK
    https://github.com/futuremotiondev

.LINK
    ConvertFrom-Rnp.ps1
#>
[CmdletBinding(SupportsShouldProcess)]
[OutputType([pscustomobject])]
param(
    [Parameter(
        Mandatory, Position = 0, ValueFromPipeline,
        ValueFromPipelineByPropertyName,
        HelpMessage = 'Literal path to one or more staged .rnp presets.'
    )]
    [Alias('PSPath')]
    [ValidateNotNullOrEmpty()]
    [String[]] $LiteralPath,

    [String] $Subfolder,

    [Switch] $Force
)

begin {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    Import-Module (Join-Path $PSScriptRoot 'RnpCommon.psm1') -Force

    $config = Get-RnpConfig
    $sub = $PSBoundParameters.ContainsKey('Subfolder') ? $Subfolder :
        $config.PresetsSubfolder
    $presetRoot = [IO.Path]::Combine($config.ReNamerPath, 'Presets')
    $presetDir = $presetRoot

    # GUARD RAILS ──────────────────────────────────────────────────────────────
    # The subfolder must stay inside Presets, and backups must stay outside
    # it: every .rnp under Presets shows up in ReNamer's preset menu.
    if ($sub) {
        $climbs = $sub -match '(^|[\\/])\.\.([\\/]|$)'
        if ([IO.Path]::IsPathRooted($sub) -or $climbs) {
            throw "Subfolder '$sub' must be a relative path inside Presets."
        }
        $presetDir = [IO.Path]::Combine($presetRoot, $sub)
    }
    $inside = { param($Path, $Root)
        $p = [IO.Path]::GetFullPath($Path).TrimEnd('\', '/') + '\'
        $r = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/') + '\'
        $p.StartsWith($r, [StringComparison]::OrdinalIgnoreCase)
    }
    if (& $inside $config.BackupDir $presetRoot) {
        throw "BackupDir '$($config.BackupDir)' is inside the Presets " +
              'folder; point it elsewhere in config.json.'
    }
    $pending = 0

    # RULE-LEVEL DIFF ──────────────────────────────────────────────────────────
    # Describes how the new preset differs from the installed one, in terms
    # Jay can check at a glance. Long values are shortened.
    $short = {
        param([string] $Value)
        $v = $Value -replace "`r`n", '⏎'
        ($v.Length -gt 60) ? ($v.Substring(0, 60) + '…') : $v
    }
    $diff = {
        param($Old, $New)
        $lines = [Collections.Generic.List[string]]::new()
        $max = [Math]::Max($Old.Rules.Count, $New.Rules.Count)
        for ($i = 0; $i -lt $max; $i++) {
            $o = ($i -lt $Old.Rules.Count) ? $Old.Rules[$i] : $null
            $n = ($i -lt $New.Rules.Count) ? $New.Rules[$i] : $null
            $label = "Rule $($i + 1)"
            if (-not $o) {
                $lines.Add("$label added: $($n.ID) '$($n.Comment)'")
                continue
            }
            if (-not $n) {
                $lines.Add("$label removed: $($o.ID) '$($o.Comment)'")
                continue
            }
            if ($o.ID -cne $n.ID) {
                $lines.Add("${label}: $($o.ID) -> $($n.ID)")
                continue
            }
            $keys = @($o.Config.Keys) + @($n.Config.Keys) |
                Select-Object -Unique
            foreach ($k in $keys) {
                $ov = $o.Config.Contains($k) ? [string]$o.Config[$k] : '<absent>'
                $nv = $n.Config.Contains($k) ? [string]$n.Config[$k] : '<absent>'
                if ($ov -cne $nv) {
                    $lines.Add("$label ($($n.ID)) ${k}: '$(& $short $ov)' -> " +
                               "'$(& $short $nv)'")
                }
            }
            if ("$($o.Marked)" -ne "$($n.Marked)") {
                $lines.Add(
                    "$label ($($n.ID)) Marked: $($o.Marked) -> $($n.Marked)")
            }
            if ("$($o.Comment)" -cne "$($n.Comment)") {
                $lines.Add("$label ($($n.ID)) Comment: '$($o.Comment)' -> " +
                           "'$($n.Comment)'")
            }
        }
        $of = $Old.Filters ?? @{}
        $nf = $New.Filters ?? @{}
        foreach ($k in (@($of.Keys) + @($nf.Keys) | Select-Object -Unique)) {
            if ("$($of[$k])" -cne "$($nf[$k])") {
                $lines.Add("[Filters] ${k}: '$($of[$k])' -> '$($nf[$k])'")
            }
        }
        if (-not $lines.Count) {
            $lines.Add('Same rules and filters; the files differ only in ' +
                       'layout or encoding.')
        }
        $lines.ToArray()
    }
}

process {
    foreach ($item in $LiteralPath) {
        $source = Convert-Path -LiteralPath $item
        $target = [IO.Path]::Combine($presetDir, (Split-Path -Leaf $source))
        $result = [ordered]@{
            Source = $source; Target = $target; Action = $null
            Backup = $null; Diff = @()
        }

        if (-not (Test-Path -LiteralPath $target)) {
            # Same file name elsewhere under Presets: probably an update of a
            # preset that lives in a subfolder, not a new preset.
            $twins = @(Get-ChildItem -LiteralPath $presetRoot -Recurse `
                -File -Filter (Split-Path -Leaf $source) `
                -ErrorAction SilentlyContinue)
            if ($twins -and -not $Force) {
                $result.Action = 'NeedsConfirmation'
                $result.Diff = @($twins | ForEach-Object {
                    "A preset with this name already exists at " +
                    "$($_.FullName). To update it, pass -Subfolder with " +
                    'its folder; -Force installs a second copy here.' })
                $pending++
                [pscustomobject]$result
                continue
            }
            if ($PSCmdlet.ShouldProcess($target, 'Install new preset')) {
                New-Item -ItemType Directory -Force -Path $presetDir | Out-Null
                Copy-Item -LiteralPath $source -Destination $target
                $result.Action = 'Installed'
            }
            else { $result.Action = 'WhatIf: Install' }
            [pscustomobject]$result
            continue
        }

        # IDENTICAL? ───────────────────────────────────────────────────────────
        $same = (Get-FileHash -LiteralPath $source).Hash -eq
                (Get-FileHash -LiteralPath $target).Hash
        if ($same) {
            $result.Action = 'Unchanged'
            [pscustomobject]$result
            continue
        }

        # DIFFERS: DIFF, THEN REPLACE ONLY WITH -FORCE (AFTER A BACKUP) ────────
        $result.Diff = & $diff (Read-RnpPreset -LiteralPath $target) `
                               (Read-RnpPreset -LiteralPath $source)
        if (-not $Force) {
            $result.Action = 'NeedsConfirmation'
            $pending++
            [pscustomobject]$result
            continue
        }
        if ($PSCmdlet.ShouldProcess($target, 'Back up and replace preset')) {
            New-Item -ItemType Directory -Force -Path $config.BackupDir |
                Out-Null
            $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            $name = [IO.Path]::GetFileNameWithoutExtension($target)
            $backup = [IO.Path]::Combine($config.BackupDir,
                "$name.$stamp.rnp")
            Copy-Item -LiteralPath $target -Destination $backup
            Copy-Item -LiteralPath $source -Destination $target -Force
            $result.Backup = $backup
            $result.Action = 'Replaced'
        }
        else { $result.Action = 'WhatIf: Replace' }
        [pscustomobject]$result
    }
}

end {
    exit ($pending ? 1 : 0)
}
