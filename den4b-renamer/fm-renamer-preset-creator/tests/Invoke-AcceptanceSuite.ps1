#Requires -Version 7.4
<#
.SYNOPSIS
    Runs the skill's acceptance scenarios (tests\acceptance\*.json) end to
    end: build, validate, count rules, check determinism, run fixtures.

.DESCRIPTION
    Each acceptance file is a preset-spec with the scenario's request,
    pinned casing mode and collisions, fixtures ('tests') and a rule budget
    (acceptance.maxRules). 'rules' is empty: the skill designs them. The
    suite then proves the design:

      1. Build the full preset(s) with Build-RnpPreset.ps1, twice, and
         compare hashes (the build must be deterministic).
      2. Validate every built preset with Test-RnpPreset.ps1 (Strict):
         0 errors required.
      3. Count the rules of the full build (casing tail and collision script
         included) against acceptance.maxRules.
      4. Build the harness copy (-SkipCollisionRule drops a GUI-only
         serializer) and run the fixtures with Invoke-RnpProbe.ps1.

    A scenario with acceptance.roundTrip (T13) runs Test-RnpRoundTrip.ps1 on
    that installed preset instead.

    -UseReference copies each file's referenceRules (the probe-verified
    yardstick) into rules first, which is how the suite itself is checked.
    To grade the skill, write its designed rules into a copy of the
    scenario file and run the suite on that copy.

.PARAMETER LiteralPath
    Acceptance spec files. Defaults to every tests\acceptance\*.json.

.PARAMETER UseReference
    Use referenceRules as the rules (suite self-check).

.PARAMETER SkipHarness
    Build, validate and count only; do not run ReNamer (works anywhere
    PowerShell 7.4 runs, e.g. for a quick check away from Windows).

.PARAMETER OutputDirectory
    Work folder for builds. Default: %TEMP%\rnp-acceptance (wiped first).

.INPUTS
    System.String[]
    Pipe acceptance spec paths.

.OUTPUTS
    System.Management.Automation.PSCustomObject
    One row per scenario: Id, Name, Built, Deterministic, Errors, Rules,
    MaxRules, Tests (passed/total), Status (PASS, FAIL or SKIPPED), Detail.
    T13 is SKIPPED when its preset is not installed.

.EXAMPLE
    ./Invoke-AcceptanceSuite.ps1 -UseReference
    Self-check: every scenario with its reference rules must PASS.

.EXAMPLE
    ./Invoke-AcceptanceSuite.ps1 .\my-t06.json
    Grades a scenario file whose rules were designed by the skill.

.EXAMPLE
    ./Invoke-AcceptanceSuite.ps1 -UseReference -SkipHarness
    Builds, validates and counts without running ReNamer.

.NOTES
    Exits with the number of scenarios that did not pass.

.LINK
    https://github.com/futuremotiondev

.LINK
    Invoke-RnpProbe.ps1
#>
[CmdletBinding()]
[OutputType([pscustomobject])]
param(
    [Parameter(
        Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName,
        HelpMessage = 'Acceptance spec files (default: tests\acceptance\*.json).'
    )]
    [Alias('PSPath')]
    [String[]] $LiteralPath,

    [Switch] $UseReference,

    [Switch] $SkipHarness,

    [String] $OutputDirectory
)

begin {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    $scripts = Join-Path $PSScriptRoot '..' 'scripts'
    $builder = Join-Path $scripts 'Build-RnpPreset.ps1'
    $validator = Join-Path $scripts 'Test-RnpPreset.ps1'
    $harness = Join-Path $scripts 'Invoke-RnpProbe.ps1'
    $roundTrip = Join-Path $PSScriptRoot 'Test-RnpRoundTrip.ps1'
    Import-Module (Join-Path $scripts 'RnpCommon.psm1') -Force

    $work = $PSCmdlet.GetUnresolvedProviderPathFromPSPath(
        ($OutputDirectory ? $OutputDirectory :
            (Join-Path ([IO.Path]::GetTempPath()) 'rnp-acceptance')))
    if (Test-Path -LiteralPath $work) {
        Remove-Item -LiteralPath $work -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $work | Out-Null
    $specFiles = [Collections.Generic.List[string]]::new()
    $failed = 0
}

process {
    foreach ($p in @($LiteralPath)) {
        if ($p) { $specFiles.Add((Convert-Path -LiteralPath $p)) }
    }
}

end {
    if (-not $specFiles.Count) {
        Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'acceptance') `
            -Filter *.json | Sort-Object Name |
            ForEach-Object { $specFiles.Add($_.FullName) }
    }

    foreach ($file in $specFiles) {
        $spec = ConvertFrom-RnpJson (
            Get-Content -LiteralPath $file -Raw -Encoding utf8)
        $acc = $spec['acceptance'] ?? @{}
        $id = $acc['id'] ?? [IO.Path]::GetFileNameWithoutExtension($file)
        $row = [ordered]@{
            Id = $id; Name = $spec['name']; Built = $false
            Deterministic = $null; Errors = $null; Rules = $null
            MaxRules = $acc['maxRules']; Tests = $null; Status = 'FAIL'
            Detail = ''
        }

        # ROUND-TRIP SCENARIO (T13) ────────────────────────────────────────────
        if ($acc['roundTrip']) {
            $target = [IO.Path]::Combine((Get-RnpConfig).ReNamerPath,
                'Presets', $acc['roundTrip'])
            if (-not (Test-Path -LiteralPath $target)) {
                # Not a failure: the scenario needs the user's installed preset.
                $row.Name = $acc['roundTrip']
                $row.Status = 'SKIPPED'
                $row.Detail = "Preset not installed: $target"
            }
            else {
                $rt = & $roundTrip -LiteralPath $target
                $row.Name = $acc['roundTrip']
                $row.Built = $true
                $row.Deterministic = $rt.Identical
                $row.Rules = $rt.Rules
                $row.Tests = "$($rt.Explained)/$($rt.Rules) rules explained"
                $row.Status = $rt.Status
                $row.Detail = $rt.Reason ?? 'byte-identical rebuild'
            }
            if ($row.Status -notin 'PASS', 'SKIPPED') { $failed++ }
            [pscustomobject]$row
            continue
        }

        # MATERIALIZE THE SPEC ─────────────────────────────────────────────────
        $caseDir = Join-Path $work $id
        $full = Join-Path $caseDir 'full'
        $again = Join-Path $caseDir 'again'
        $probe = Join-Path $caseDir 'harness'
        New-Item -ItemType Directory -Force -Path $caseDir | Out-Null
        if ($UseReference -and $spec.Contains('referenceRules')) {
            $spec['rules'] = $spec['referenceRules']
        }
        # The copy lives elsewhere, so pin relative Pascal source files to
        # the original spec's folder.
        foreach ($r in @($spec['rules'] ?? @())) {
            if ($r['sourceFile'] -and
                -not [IO.Path]::IsPathRooted($r['sourceFile'])) {
                $r['sourceFile'] = [IO.Path]::GetFullPath(
                    [IO.Path]::Combine((Split-Path -Parent $file),
                                       $r['sourceFile']))
            }
        }
        $specPath = Join-Path $caseDir "$id.json"
        [IO.File]::WriteAllText($specPath, ($spec | ConvertTo-Json -Depth 20),
            [Text.UTF8Encoding]::new($false))

        try {
            # 1. BUILD TWICE (DETERMINISM) ─────────────────────────────────────
            $built = @(& $builder -LiteralPath $specPath -OutputDirectory $full)
            if ($LASTEXITCODE -or -not $built) { throw 'build failed' }
            $null = & $builder -LiteralPath $specPath -OutputDirectory $again
            $row.Built = $true
            $row.Deterministic = -not @($built | Where-Object {
                $twin = Join-Path $again (Split-Path -Leaf $_.Path)
                (Get-FileHash -LiteralPath $_.Path).Hash -ne
                    (Get-FileHash -LiteralPath $twin).Hash
            })

            # 2. VALIDATE (STRICT) ─────────────────────────────────────────────
            $masks = @{}
            foreach ($k in @(($spec['filters'] ?? @{}).Keys)) {
                $masks[$k] = [string]$spec['filters'][$k]
            }
            $findings = @($built | ForEach-Object {
                & $validator -LiteralPath $_.Path -MaskOverrides $masks
            })
            $errors = @($findings | Where-Object Level -eq 'Error')
            $row.Errors = $errors.Count

            # 3. RULE BUDGET (full build) ──────────────────────────────────────
            $row.Rules = [int]($built | Measure-Object RuleCount -Maximum).Maximum
            $overBudget = $null -ne $row.MaxRules -and
                $row.Rules -gt $row.MaxRules

            # 4. FIXTURES IN THE HARNESS ───────────────────────────────────────
            $testsOk = $true
            if (-not $SkipHarness) {
                $harnessBuild = @(& $builder -LiteralPath $specPath `
                    -OutputDirectory $probe -SkipCollisionRule)
                $results = @(& $harness -Preset @($harnessBuild.Path) `
                    -Tests $specPath 6>$null)
                $passed = @($results | Where-Object Status -eq 'PASS').Count
                $row.Tests = "$passed/$($results.Count)"
                $bad = @($results | Where-Object Status -eq 'FAIL')
                $testsOk = -not $bad -and $results.Count
                foreach ($b in $bad) {
                    $row.Detail += "FAIL $($b.Name): got " +
                        "[$($b.Actual -join ' | ')] exit $($b.ExitCode); " +
                        "expected [$($b.Expected -join ' | ')] exit " +
                        "$($b.ExpectedExit). "
                }
            }
            else { $row.Tests = 'skipped' }

            $problems = @(
                $row.Deterministic ? $null : 'not deterministic'
                $errors ? ("validator: " +
                    (($errors | ForEach-Object {
                        "check $($_.Check): $($_.Message)" }) -join '; ')) :
                    $null
                $overBudget ? "$($row.Rules) rules > budget $($row.MaxRules)" :
                    $null
            ) | Where-Object { $_ }
            if ($problems) { $row.Detail = ($problems -join '; ') + $row.Detail }
            $row.Status = (-not $problems -and $testsOk) ? 'PASS' : 'FAIL'
        }
        catch {
            $row.Detail = "$($_.Exception.Message) $($row.Detail)".Trim()
        }
        if ($row.Status -ne 'PASS') { $failed++ }
        [pscustomobject]$row
    }
    exit $failed
}
