#Requires -Version 7.4
<#
.SYNOPSIS
    Proves the skill's value encoder reproduces ReNamer's own output.

.DESCRIPTION
    Decodes every Config value and Comment in every .rnp under the given
    folders, re-encodes it with ConvertTo-RnpConfigValue from RnpCommon.psm1
    (the Mapping row exception included) and
    compares the result byte for byte with what ReNamer saved. On Jay's
    158 presets (ReNamer 7.10) all 6,860 values round-trip. Any mismatch
    means the encoder, or ReNamer's format, has changed.

.PARAMETER LiteralPath
    Folders (or .rnp files) to scan recursively. Defaults to the Presets
    and Presets Disabled folders of ReNamerPath in config.json.

.INPUTS
    System.String[]
    Pipe folder or file paths.

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Presets, Values, Mismatches (count) and Samples (up to 25 examples).

.EXAMPLE
    ./Test-RnpEncoderRoundTrip.ps1
    Checks every preset of the configured ReNamer install.

.EXAMPLE
    ./Test-RnpEncoderRoundTrip.ps1 -LiteralPath 'D:\Backup\Presets'
    Checks a backup folder instead.

.EXAMPLE
    Get-Item .\*.rnp | ./Test-RnpEncoderRoundTrip.ps1
    Checks a few individual presets.

.NOTES
    Exits with code 1 when any value does not round-trip.

.LINK
    https://github.com/futuremotiondev

.LINK
    Test-RnpRoundTrip.ps1
#>
[CmdletBinding()]
[OutputType([pscustomobject])]
param(
    [Parameter(
        Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName,
        HelpMessage = 'Folders or .rnp files to scan (default: the configured Presets folders).'
    )]
    [Alias('PSPath', 'Path')]
    [String[]] $LiteralPath
)

begin {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    Import-Module (Join-Path $PSScriptRoot '..' 'scripts' 'RnpCommon.psm1') -Force
    $targets = [Collections.Generic.List[string]]::new()
}

process {
    foreach ($p in @($LiteralPath)) {
        if ($p) { $targets.Add((Convert-Path -LiteralPath $p)) }
    }
}

end {
    if (-not $targets.Count) {
        $base = (Get-RnpConfig).ReNamerPath
        foreach ($sub in 'Presets', 'Presets Disabled') {
            $dir = [IO.Path]::Combine($base, $sub)
            if (Test-Path -LiteralPath $dir) { $targets.Add($dir) }
        }
    }
    $files = @(Get-ChildItem -LiteralPath $targets -Recurse -Filter *.rnp -File)
    $values = 0
    $mismatch = [Collections.Generic.List[string]]::new()

    # Every Config value and every non-empty Comment, exactly as saved.
    foreach ($f in $files) {
        $id = ''
        foreach ($line in [IO.File]::ReadAllLines($f.FullName)) {
            # Pairs of (key, raw value); the key matters for Mapping rows,
            # which ReNamer joins with a raw '|'.
            $raw = @()
            if ($line -match '^ID=(.*)$') { $id = $Matches[1]; continue }
            if ($line -match '^Config=(.*)$') {
                $raw = @($Matches[1] -split ';' | ForEach-Object {
                    $kv = $_ -split ':', 2
                    if ($kv.Count -eq 2) { , @($kv[0], $kv[1]) }
                })
            }
            elseif ($line -match '^Comment=(.+)$') {
                $raw = @(, @('Comment', $Matches[1]))
            }
            foreach ($pair in $raw) {
                $v = $pair[1]
                $values++
                $re = ConvertTo-RnpConfigValue $id $pair[0] (
                    ConvertFrom-RnpValue $v)
                if ($re -cne $v) {
                    $cut = { param($s) $s.Substring(0, [Math]::Min(80, $s.Length)) }
                    $mismatch.Add("$($f.Name): '$(& $cut $v)' -> '$(& $cut $re)'")
                }
            }
        }
    }

    [pscustomobject]@{
        Presets    = $files.Count
        Values     = $values
        Mismatches = $mismatch.Count
        Samples    = @($mismatch | Select-Object -First 25)
    }
    exit ($mismatch.Count ? 1 : 0)
}
