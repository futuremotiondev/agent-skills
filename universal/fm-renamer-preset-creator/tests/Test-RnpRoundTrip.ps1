#Requires -Version 7.4
<#
.SYNOPSIS
    Acceptance test T13: decode a preset, rebuild it, and compare bytes.

.DESCRIPTION
    For every .rnp given, this test:

      1. runs ConvertFrom-Rnp.ps1 (spec + explanation) into a temp folder,
      2. rebuilds the preset from that spec with Build-RnpPreset.ps1, on its
         own, without trusting ConvertFrom-Rnp's internal check,
      3. compares the rebuilt file with the original byte for byte, and
      4. checks that the explanation has one numbered entry per rule.

    Round-tripping must be lossless for every canonical preset (anything
    ReNamer saved). Presets that ConvertFrom-Rnp refuses are reported as
    NOT LOSSLESS with its reason; that is a failure only with -Strict.

.PARAMETER LiteralPath
    One or more .rnp files. Defaults to 'CONTENTS 00 Clean Up Filename.rnp'
    in the configured Presets folder (the T13 scenario).

.PARAMETER All
    Round-trip every .rnp in the configured Presets and Presets Disabled
    folders (the stretch run).

.PARAMETER Strict
    Treat presets that cannot be decoded losslessly as failures.

.INPUTS
    System.String[]
    Pipe .rnp paths or FileInfo objects.

.OUTPUTS
    System.Management.Automation.PSCustomObject
    File, Rules, Explained, Lossless, Identical, Status, Reason.

.EXAMPLE
    ./Test-RnpRoundTrip.ps1
    Runs T13 on CONTENTS 00 Clean Up Filename.rnp.

.EXAMPLE
    ./Test-RnpRoundTrip.ps1 -All | Where-Object Status -ne 'PASS'
    Round-trips every installed preset and lists the ones that did not pass.

.EXAMPLE
    Get-ChildItem .\*.rnp | ./Test-RnpRoundTrip.ps1 -Strict
    Round-trips a folder of presets; any refusal fails the run.

.NOTES
    Never writes into the Presets folder. Exits with the number of failures.

.LINK
    https://github.com/futuremotiondev

.LINK
    ConvertFrom-Rnp.ps1
#>
[CmdletBinding()]
[OutputType([pscustomobject])]
param(
    [Parameter(
        Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName,
        HelpMessage = 'Literal path to one or more .rnp presets to round-trip.'
    )]
    [Alias('PSPath')]
    [String[]] $LiteralPath,

    [Switch] $All,

    [Switch] $Strict
)

begin {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    $scripts = Join-Path $PSScriptRoot '..' 'scripts'
    Import-Module (Join-Path $scripts 'RnpCommon.psm1') -Force
    $decoder = Join-Path $scripts 'ConvertFrom-Rnp.ps1'
    $builder = Join-Path $scripts 'Build-RnpPreset.ps1'
    $renamer = (Get-RnpConfig).ReNamerPath
    $files = [Collections.Generic.List[string]]::new()
    $work = Join-Path ([IO.Path]::GetTempPath()) 'rnp-roundtrip'
    if (Test-Path -LiteralPath $work) {
        Remove-Item -LiteralPath $work -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $work | Out-Null
    $failures = 0
}

process {
    foreach ($p in @($LiteralPath)) {
        if ($p) { $files.Add((Convert-Path -LiteralPath $p)) }
    }
}

end {
    # DEFAULT TARGETS ──────────────────────────────────────────────────────────
    if ($All) {
        foreach ($sub in 'Presets', 'Presets Disabled') {
            $dir = [IO.Path]::Combine($renamer, $sub)
            if (Test-Path -LiteralPath $dir) {
                Get-ChildItem -LiteralPath $dir -Recurse -Filter *.rnp -File |
                    ForEach-Object { $files.Add($_.FullName) }
            }
        }
    }
    elseif (-not $files.Count) {
        $files.Add([IO.Path]::Combine($renamer, 'Presets',
            'CONTENTS 00 Clean Up Filename.rnp'))
    }

    $n = 0
    foreach ($file in $files) {
        $n++
        $caseDir = Join-Path $work ('p{0:D3}' -f $n)
        $decoded = Join-Path $caseDir 'decoded'
        $rebuiltDir = Join-Path $caseDir 'rebuilt'

        # DECODE ───────────────────────────────────────────────────────────────
        $result = & $decoder -LiteralPath $file -OutputDirectory $decoded `
            -ErrorAction SilentlyContinue 2>$null
        $rules = @((Read-RnpPreset -LiteralPath $file).Rules).Count
        $explained = $result ?
            ([regex]::Matches($result.Explanation, '(?m)^\d+\. \*\*')).Count : 0

        # REBUILD INDEPENDENTLY AND COMPARE ────────────────────────────────────
        $identical = $false
        if ($result -and $result.SpecPath) {
            $null = & $builder -LiteralPath $result.SpecPath `
                -OutputDirectory $rebuiltDir 2>$null
            $rebuilt = Join-Path $rebuiltDir (Split-Path -Leaf $file)
            $identical = (Test-Path -LiteralPath $rebuilt) -and
                ((Get-FileHash -LiteralPath $rebuilt).Hash -eq
                 (Get-FileHash -LiteralPath $file).Hash)
        }

        $lossless = [bool]($result -and $result.Lossless)
        $status = if ($lossless -and $identical -and $explained -eq $rules) {
            'PASS'
        }
        elseif (-not $lossless -and -not $Strict -and $explained -eq $rules) {
            'NOT LOSSLESS'
        }
        else { 'FAIL' }
        if ($status -eq 'FAIL') { $failures++ }

        [pscustomobject]@{
            File      = Split-Path -Leaf $file
            Rules     = $rules
            Explained = $explained
            Lossless  = $lossless
            Identical = $identical
            Status    = $status
            Reason    = $result ? $result.Reason : 'decoder failed'
        }
    }
    exit $failures
}
