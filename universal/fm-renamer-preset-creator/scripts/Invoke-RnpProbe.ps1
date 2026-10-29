#Requires -Version 7.4
<#
.SYNOPSIS
    Runs ReNamer presets against throwaway files and asserts the resulting
    names and exit code.

.DESCRIPTION
    The skill's verification harness. Every case runs in its own folder
    under %TEMP%\rnp-probe:

      1. create the case's input files and folders (empty files),
      2. write or copy the preset (UTF-8 without BOM, CRLF),
      3. run  ReNamer.exe /silent /rename "<preset path>" <inputs>  and wait,
      4. list every path left in the folder and compare it with the
         expectation (order-insensitive, case-sensitive) AND compare the exit
         code. Checking the exit code matters: a preset that fails to load
         leaves every name unchanged, so an "unchanged" expectation alone
         would pass a broken preset.

    Two ways to supply cases:

      -CaseFile   A .psd1 with hand-written rules per case (the regression
                  suites in tests\). Each case builds its own preset.
      -Preset     One or more built .rnp files (FILE and/or CONTENTS), plus
                  -Tests: a preset-spec JSON whose 'tests' array holds the
                  fixtures (references/preset-spec.md). Each test runs the
                  preset of its 'variant' (default FILE when built, else
                  CONTENTS), copied into the case folder under its own name.

    Safety: ReNamer's CLI instance rewrites Settings.ini on exit, so the
    script snapshots it and restores it afterwards, and it hashes every file
    in the Presets folder before the run and reports any drift. It never
    touches files outside its own %TEMP% work folder. Safe to run while a
    ReNamer GUI window is open.

.PARAMETER CaseFile
    A .psd1 file:  @{ Cases = @( @{ Name; Files; Rules | Raw; Expect } ) }
      Files      Relative paths to create; a trailing '\' makes a folder.
      Inputs     Paths to pass to ReNamer (default: every entry in Files);
                 '.' is the case folder itself.
      Rules      @( @{ ID; Config = @('KEY=value', ...); Marked; Comment;
                 Encoded } ). Values are raw text and get encoded unless
                 Encoded = $true. Tokens: {CRLF}, {CR}, {LF}, {ZWSP} (zero-width space),
                 {NBSP} (no-break space); also allowed in Files and Inputs.
      Filters    Optional [Filters] hashtable, written verbatim.
      Raw        Optional preset lines written verbatim (overrides Rules).
      Expect     Expected relative paths after the run (folders end in '\').
      ExpectExit Expected exit code (default 0 whenever Expect is given).

.PARAMETER Preset
    Path to one or more built .rnp files whose names start with 'FILE ' or
    'CONTENTS '.

.PARAMETER Tests
    Preset-spec JSON file with a 'tests' array. Fields per test: name,
    variant, files, inputs, expect, expectExit, or the shorthand
    { "in": x, "out": y }, which expects y plus each parent folder of y.

.PARAMETER ReNamerPath
    Folder that contains ReNamer.exe. Default: ReNamerPath from the skill's
    config.json (C:\Tools\den4b Renamer).

.PARAMETER TimeoutSeconds
    How long to wait for each ReNamer run before killing it.

.INPUTS
    None.

.OUTPUTS
    System.Management.Automation.PSCustomObject
    One result per case: Index, Name, Status (PASS, FAIL or INFO),
    ExitCode, ExpectedExit, Actual, Expected, Inputs, Preset.

.EXAMPLE
    ./Invoke-RnpProbe.ps1 -CaseFile ..\tests\rule-semantics.probes.psd1
    Runs the rule-semantics regression suite.

.EXAMPLE
    ./Invoke-RnpProbe.ps1 -Preset "$h\FILE X.rnp", "$h\CONTENTS X.rnp" `
        -Tests .\x.json
    Runs the preset-spec fixtures against both built variants.

.EXAMPLE
    ./Invoke-RnpProbe.ps1 -CaseFile .\cases.psd1 |
        Where-Object Status -eq 'FAIL' | Format-List
    Shows full details of failing cases only.

.NOTES
    Windows only (runs ReNamer.exe). Built and verified against ReNamer
    7.10.0.0 portable. The exit code equals the number of failed cases, so
    scripts can gate on it. Informational cases (no Expect/ExpectExit) never
    fail.

.LINK
    https://github.com/futuremotiondev

.LINK
    Build-RnpPreset.ps1

.LINK
    Test-RnpPreset.ps1
#>
[CmdletBinding(DefaultParameterSetName = 'CaseFile')]
[OutputType([pscustomobject])]
param(
    [Parameter(Mandatory, ParameterSetName = 'CaseFile')]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [String] $CaseFile,

    [Parameter(Mandatory, ParameterSetName = 'Preset')]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [String[]] $Preset,

    [Parameter(Mandatory, ParameterSetName = 'Preset')]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [String] $Tests,

    [String] $ReNamerPath,

    [ValidateRange(5, 300)]
    [Int] $TimeoutSeconds = 20
)

begin {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    Import-Module (Join-Path $PSScriptRoot 'RnpCommon.psm1') -Force

    # TEST-ONLY TOKENS ─────────────────────────────────────────────────────────
    # Characters that are awkward to type in a .psd1 or JSON file.
    function Expand-Token([string] $Text) {
        $Text.Replace('{CRLF}', "`r`n").
              Replace('{CR}', "`r").
              Replace('{LF}', "`n").
              Replace('{ZWSP}', [string][char]0x200B).
              Replace('{NBSP}', [string][char]0x00A0)
    }

    if (-not $ReNamerPath) { $ReNamerPath = (Get-RnpConfig).ReNamerPath }
    $exe = Join-Path $ReNamerPath 'ReNamer.exe'
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
        throw "ReNamer.exe not found in '$ReNamerPath' (see config.json)."
    }
    $presetDir = Join-Path $ReNamerPath 'Presets'
    $settings = Join-Path $ReNamerPath 'Settings.ini'
    $root = Join-Path ([IO.Path]::GetTempPath()) 'rnp-probe'
    $backup = Join-Path $root '_backup'
    New-Item -ItemType Directory -Force -Path $root, $backup | Out-Null

    # SNAPSHOT USER STATE (restored and verified in end) ───────────────────────
    $snapshot = @{}
    if (Test-Path -LiteralPath $presetDir) {
        Get-ChildItem -LiteralPath $presetDir -Recurse -File | ForEach-Object {
            $snapshot[$_.FullName] = (Get-FileHash -LiteralPath $_.FullName).Hash
        }
    }
    $settingsHash = $null
    if (Test-Path -LiteralPath $settings) {
        $settingsHash = (Get-FileHash -LiteralPath $settings).Hash
        Copy-Item -LiteralPath $settings -Force `
            -Destination (Join-Path $backup 'Settings.ini')
    }

    # NORMALIZE CASES ──────────────────────────────────────────────────────────
    # Both input styles become the same shape: Name, Files, Inputs, Expect
    # (or $null), ExpectExit (or $null), and either PresetText or
    # PresetSource (a built .rnp to copy).
    $cases = [Collections.Generic.List[object]]::new()
    if ($PSCmdlet.ParameterSetName -eq 'CaseFile') {
        foreach ($c in (Import-PowerShellDataFile -LiteralPath $CaseFile).Cases) {
            if ($c.ContainsKey('Raw')) {
                $text = ($c.Raw -join "`r`n") + "`r`n"
            }
            else {
                # Build the preset text from the case's rule list.
                $lines = [Collections.Generic.List[string]]::new()
                $n = 0
                foreach ($r in $c.Rules) {
                    $encoded = $r.ContainsKey('Encoded') -and $r.Encoded
                    $cfg = ($r.Config | ForEach-Object {
                        $kv = $_ -split '=', 2
                        $val = $encoded ? $kv[1] :
                            (ConvertTo-RnpValue (Expand-Token $kv[1]))
                        '{0}:{1}' -f $kv[0], $val
                    }) -join ';'
                    $marked = $r.ContainsKey('Marked') ? $r.Marked : 1
                    $comment = $r.ContainsKey('Comment') ?
                        (ConvertTo-RnpValue $r.Comment) : ''
                    $lines.AddRange([string[]]@(
                        "[Rule$n]", "ID=$($r.ID)", "Config=$cfg",
                        "Marked=$marked", "Comment=$comment", ''))
                    $n++
                }
                if ($c.ContainsKey('Filters')) {
                    $lines.Add('[Filters]')
                    $order = 'AddFilesFromFolders', 'AddFoldersAsFiles',
                             'IncludeSubfolders', 'IncludeHidden',
                             'IncludeSystem', 'SkipRootFoldersAsFiles',
                             'MasksOnFileName', 'Masks', 'MasksExclude'
                    foreach ($k in $order) {
                        if ($c.Filters.ContainsKey($k)) {
                            $lines.Add("$k=$($c.Filters[$k])")
                        }
                    }
                }
                $text = ($lines -join "`r`n") + "`r`n"
            }
            $cases.Add([pscustomobject]@{
                NoAssertion  = $false
                Name         = $c.Name
                Files        = @($c.Files)
                Inputs       = $c.ContainsKey('Inputs') ? @($c.Inputs) :
                                                         @($c.Files)
                Expect       = $c.ContainsKey('Expect') ? @($c.Expect) : $null
                ExpectExit   = $c.ContainsKey('ExpectExit') ? $c.ExpectExit :
                               ($c.ContainsKey('Expect') ? 0 : $null)
                PresetText   = $text
                PresetSource = $null
            })
        }
    }
    else {
        # Map each built preset to its variant by file-name prefix.
        $byVariant = @{}
        foreach ($p in $Preset) {
            $full = Convert-Path -LiteralPath $p
            $leaf = Split-Path -Leaf $full
            if ($leaf -cmatch '^(FILE|CONTENTS) ') {
                $byVariant[$Matches[1]] = $full
            }
            else {
                throw "Preset '$leaf' must start with 'FILE ' or 'CONTENTS '."
            }
        }
        $defaultVariant = $byVariant.ContainsKey('FILE') ? 'FILE' : 'CONTENTS'
        $spec = ConvertFrom-RnpJson (
            Get-Content -LiteralPath $Tests -Raw -Encoding utf8)
        $n = 0
        foreach ($t in @($spec['tests'] ?? @())) {
            $n++
            $variant = $t['variant'] ?? $defaultVariant
            if ($t.Contains('in')) {
                # Shorthand: one file, expect its new name plus every parent
                # folder, because the harness lists folders too.
                $files = @($t['in'])
                $expect = [Collections.Generic.List[string]]::new()
                # A folder rename ends in '\'; its parents are the segments
                # before the last one.
                $parts = $t['out'].TrimEnd('\') -split '\\'
                for ($i = 1; $i -lt $parts.Count; $i++) {
                    $expect.Add((($parts[0..($i - 1)]) -join '\') + '\')
                }
                $expect.Add($t['out'])
                $label = "$($t['in']) -> $($t['out'])"
            }
            else {
                $files = @($t['files'])
                $expect = $t.Contains('expect') ? @($t['expect']) : $null
                $label = $t['name'] ?? "test $n"
            }
            $cases.Add([pscustomobject]@{
                Name         = "[$variant] $label"
                Files        = $files
                Inputs       = $t.Contains('inputs') ? @($t['inputs']) : $files
                Expect       = $expect
                ExpectExit   = $t['expectExit'] ??
                               ($null -ne $expect ? 0 : $null)
                PresetText   = $null
                PresetSource = $byVariant[$variant]
                NoAssertion  = $null -eq $expect -and
                               -not $t.Contains('expectExit')
            })
        }
        # A built variant without fixtures would be delivered unverified.
        foreach ($v in $byVariant.Keys) {
            if (-not @($cases | Where-Object {
                    $_.PresetSource -eq $byVariant[$v] })) {
                Write-Warning ("No test runs the $v preset; add a test with " +
                    "`"variant`": `"$v`" or it stays unverified.")
            }
        }
    }
    $pass = 0
    $fail = 0
}

process {
    $i = 0
    foreach ($case in $cases) {
        $i++
        $status = ''
        $code = $null
        $after = @()
        # One broken fixture (bad path, locked folder) must not abort the
        # run: record it as a failure and carry on.
        try {
            $dir = Join-Path $root ('c{0:D3}' -f $i)
            if (Test-Path -LiteralPath $dir) {
                Remove-Item -LiteralPath $dir -Recurse -Force
            }
            $in = Join-Path $dir 'in'
            New-Item -ItemType Directory -Force -Path $in | Out-Null

            # CREATE INPUTS ('\'-terminated entries are folders) ───────────────
            foreach ($f in $case.Files) {
                $p = Join-Path $in (Expand-Token $f)
                if ($f.EndsWith('\')) {
                    New-Item -ItemType Directory -Force -Path $p | Out-Null
                }
                else {
                    New-Item -ItemType Directory -Force `
                        -Path (Split-Path -Parent $p) | Out-Null
                    [IO.File]::WriteAllText($p, '')
                }
            }

            # PLACE THE PRESET ─────────────────────────────────────────────────
            if ($null -eq $case.PresetText -and -not $case.PresetSource) {
                $status = 'FAIL'
                $code = 'NO PRESET'
            }
            elseif ($case.NoAssertion) {
                $status = 'FAIL'
                $code = 'NO ASSERTION (add expect or expectExit)'
            }
            else {
                if ($case.PresetSource) {
                    $presetPath = Join-Path $dir (Split-Path -Leaf $case.PresetSource)
                    Copy-Item -LiteralPath $case.PresetSource -Destination $presetPath
                }
                else {
                    $presetPath = Join-Path $dir 'probe.rnp'
                    [IO.File]::WriteAllText($presetPath, $case.PresetText,
                        [Text.UTF8Encoding]::new($false))
                }

                # RUN RENAMER SILENTLY ─────────────────────────────────────────
                $paths = foreach ($x in $case.Inputs) {
                    if ($x -eq '.') { $in }
                    else { (Join-Path $in (Expand-Token $x)).TrimEnd('\') }
                }
                $argLine = '/silent /rename "{0}" {1}' -f $presetPath,
                    (($paths | ForEach-Object { '"{0}"' -f $_ }) -join ' ')
                $proc = Start-Process -FilePath $exe -ArgumentList $argLine `
                    -PassThru -WindowStyle Hidden
                $code = if ($proc.WaitForExit($TimeoutSeconds * 1000)) {
                    $proc.ExitCode
                }
                else { $proc.Kill(); 'TIMEOUT' }
            }

            # COLLECT RESULTS (relative paths, '\' suffix for folders) ─────────
            $after = @(Get-ChildItem -LiteralPath $in -Recurse | ForEach-Object {
                $rel = [IO.Path]::GetRelativePath($in, $_.FullName)
                $_.PSIsContainer ? "$rel\" : $rel
            } | Sort-Object)
        }
        catch {
            $status = 'FAIL'
            $code = "ERROR: $($_.Exception.Message)"
        }

        # ASSERT NAMES AND EXIT CODE ───────────────────────────────────────────
        $expected = $null
        if (-not $status) {
            if ($null -ne $case.Expect -or $null -ne $case.ExpectExit) {
                $namesOk = $true
                if ($null -ne $case.Expect) {
                    $expected = @($case.Expect |
                        ForEach-Object { Expand-Token $_ } | Sort-Object)
                    $namesOk = ($expected.Count -eq $after.Count) -and
                        -not (Compare-Object -ReferenceObject $expected `
                            -DifferenceObject $after -CaseSensitive)
                }
                $expExit = $case.ExpectExit ?? 0
                $status = ($namesOk -and "$code" -eq "$expExit") ?
                    'PASS' : 'FAIL'
            }
            else { $status = 'INFO' }
        }
        if ($status -eq 'PASS') { $pass++ }
        elseif ($status -eq 'FAIL') { $fail++ }

        [pscustomobject]@{
            Index        = $i
            Name         = $case.Name
            Status       = $status
            ExitCode     = $code
            ExpectedExit = $case.ExpectExit
            Actual       = $after
            Expected     = $expected
            Inputs       = $case.Files
            Preset       = $case.PresetSource ?? 'probe.rnp'
        }
    }
}

end {
    # RESTORE SETTINGS.INI AND REPORT PRESET DRIFT ─────────────────────────────
    $restored = $true
    if ($settingsHash -and
        (Get-FileHash -LiteralPath $settings).Hash -ne $settingsHash) {
        Copy-Item -LiteralPath (Join-Path $backup 'Settings.ini') `
            -Destination $settings -Force
        Write-Host 'Settings.ini was rewritten by ReNamer; restored from snapshot.'
    }
    $drift = foreach ($f in (Get-ChildItem -LiteralPath $presetDir -Recurse `
                                -File -ErrorAction SilentlyContinue)) {
        if (-not $snapshot.ContainsKey($f.FullName)) { "NEW     $($f.FullName)" }
        elseif ((Get-FileHash -LiteralPath $f.FullName).Hash -ne
                $snapshot[$f.FullName]) { "CHANGED $($f.FullName)" }
    }
    if ($drift) {
        Write-Warning ("Presets folder drift detected:`n" + ($drift -join "`n"))
    }
    else { Write-Host 'Presets folder unchanged.' }
    Write-Host "Result: $pass passed, $fail failed."

    # Non-zero when any assertion failed, so callers can gate on it.
    exit $fail
}

clean {
    # Runs even when the script is stopped by an error or Ctrl+C: ReNamer may
    # already have rewritten Settings.ini, so put the snapshot back.
    if (-not (Get-Variable -Name restored -ValueOnly -ErrorAction Ignore) -and
        (Get-Variable -Name settingsHash -ValueOnly -ErrorAction Ignore) -and
        (Get-FileHash -LiteralPath $settings).Hash -ne $settingsHash) {
        Copy-Item -LiteralPath (Join-Path $backup 'Settings.ini') `
            -Destination $settings -Force
    }
}
