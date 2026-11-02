#Requires -Version 7.4
<#
.SYNOPSIS
    Runs single-purpose ReNamer presets against throwaway files and reports (or asserts) the resulting names.

.DESCRIPTION
    Empirical probe / regression harness for den4b ReNamer presets. For every case in the .psd1 file it:
      1. creates an isolated work folder under %TEMP% with the case's input files (or folders),
      2. writes the case's preset (built from Rules, or taken verbatim from Raw) as UTF-8 without BOM, CRLF,
      3. runs  ReNamer.exe /silent /rename "<preset path>" <inputs>  and waits for it to exit,
      4. lists the resulting names and, when the case has an Expect list, prints PASS/FAIL.

    Safety: ReNamer's CLI instance rewrites Settings.ini on exit. The script snapshots Settings.ini and hashes every
    file in the Presets folder before the run, restores Settings.ini afterwards and reports any preset drift.
    It never touches files outside its own %TEMP% work folder. Safe to run while a ReNamer GUI window is open.

    Built and verified against ReNamer 7.10.0.0 (portable) on 2026-09-27 while writing the fm-renamer-preset-creator spec.

.PARAMETER CaseFile
    Path to a .psd1 file:  @{ Cases = @( @{ Name=...; Files=@(...); Rules=@(...) | Raw=@(...); Expect=@(...) } ) }
      Files   : relative paths to create under the case's 'in' folder. A trailing '\' creates a folder.
      Inputs  : optional relative paths to pass to ReNamer (default: every entry in Files). Use '.' for the 'in' folder itself.
      Rules   : @( @{ ID='Insert'; Config=@('TEXT=X ','WHERE=1',...); Marked=1; Comment='...'; Encoded=$false } )
                Config values are raw text and get ReNamer-encoded, unless Encoded=$true. Tokens: '{CRLF}' line break,
                '{ZWSP}' zero-width space, '{NBSP}' no-break space (also allowed in Files/Inputs).
      Filters : optional hashtable of [Filters] keys appended after the rules (values written verbatim).
      Raw     : optional array of preset lines written verbatim (overrides Rules/Filters).
      Expect  : optional array of expected relative paths after renaming (order-insensitive, case-sensitive).
      ExpectExit : optional expected ReNamer exit code (default 0 whenever Expect is given). Use 1 for cases where
                ReNamer must refuse (e.g. conflicting new names, invalid rule settings).

.PARAMETER ReNamerPath
    Folder that contains ReNamer.exe (portable install). Default: C:\Tools\den4b Renamer

.EXAMPLE
    ./Invoke-RnpProbe.ps1 -CaseFile ./rule-semantics.probes.psd1
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })][string] $CaseFile,
    [ValidateScript({ Test-Path -LiteralPath (Join-Path $_ 'ReNamer.exe') -PathType Leaf })][string] $ReNamerPath = 'C:\Tools\den4b Renamer',
    [ValidateRange(5, 300)][int] $TimeoutSeconds = 20
)

begin {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    # ReNamer's own value encoding: [A-Za-z0-9] literal, space -> '+', every other UTF-8 byte -> %XX (uppercase hex)
    # Test-only placeholder tokens for characters that are awkward to type in a .psd1
    function Expand-Token([string] $s) { $s.Replace('{CRLF}', "`r`n").Replace('{ZWSP}', [string][char]0x200B).Replace('{NBSP}', [string][char]0x00A0) }

    function ConvertTo-RnpValue([string] $Value) {
        $Value = Expand-Token $Value
        $sb = [Text.StringBuilder]::new()
        foreach ($b in [Text.Encoding]::UTF8.GetBytes($Value)) {
            if (($b -ge 48 -and $b -le 57) -or ($b -ge 65 -and $b -le 90) -or ($b -ge 97 -and $b -le 122)) { [void]$sb.Append([char]$b) }
            elseif ($b -eq 32) { [void]$sb.Append('+') }
            else { [void]$sb.Append(('%{0:X2}' -f $b)) }
        }
        $sb.ToString()
    }

    $exe       = Join-Path $ReNamerPath 'ReNamer.exe'
    $presetDir = Join-Path $ReNamerPath 'Presets'
    $settings  = Join-Path $ReNamerPath 'Settings.ini'
    $root      = Join-Path ([IO.Path]::GetTempPath()) 'rnp-probe'
    $backup    = Join-Path $root '_backup'
    New-Item -ItemType Directory -Force -Path $root, $backup | Out-Null

    # Snapshot user state (restored/verified in end{})
    $snapshot = @{}
    if (Test-Path -LiteralPath $presetDir) {
        Get-ChildItem -LiteralPath $presetDir -Recurse -File | ForEach-Object { $snapshot[$_.FullName] = (Get-FileHash -LiteralPath $_.FullName).Hash }
    }
    $settingsHash = (Get-FileHash -LiteralPath $settings).Hash
    Copy-Item -LiteralPath $settings -Destination (Join-Path $backup 'Settings.ini') -Force

    $cases = (Import-PowerShellDataFile -LiteralPath $CaseFile).Cases
    $pass = 0; $fail = 0; $i = 0
}

process {
    foreach ($case in $cases) {
        $i++
        $dir = Join-Path $root ('c{0:D3}' -f $i)
        if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force }
        $in = Join-Path $dir 'in'
        New-Item -ItemType Directory -Force -Path $in | Out-Null

        # Create inputs ('\'-terminated entries are folders)
        foreach ($f in $case.Files) {
            $p = Join-Path $in (Expand-Token $f)
            if ($f.EndsWith('\')) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
            else { New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null; [IO.File]::WriteAllText($p, '') }
        }

        # Build preset text
        if ($case.ContainsKey('Raw')) { $text = ($case.Raw -join "`r`n") + "`r`n" }
        else {
            $lines = [Collections.Generic.List[string]]::new(); $n = 0
            foreach ($r in $case.Rules) {
                $enc = $r.ContainsKey('Encoded') -and $r.Encoded
                $cfg = ($r.Config | ForEach-Object { $kv = $_ -split '=', 2; '{0}:{1}' -f $kv[0], ($(if ($enc) { $kv[1] } else { ConvertTo-RnpValue $kv[1] })) }) -join ';'
                $marked  = if ($r.ContainsKey('Marked')) { $r.Marked } else { 1 }
                $comment = if ($r.ContainsKey('Comment')) { ConvertTo-RnpValue $r.Comment } else { '' }
                $lines.AddRange([string[]]@("[Rule$n]", "ID=$($r.ID)", "Config=$cfg", "Marked=$marked", "Comment=$comment", '')); $n++
            }
            if ($case.ContainsKey('Filters')) {
                $lines.Add('[Filters]')
                foreach ($k in 'AddFilesFromFolders', 'AddFoldersAsFiles', 'IncludeSubfolders', 'IncludeHidden', 'IncludeSystem', 'SkipRootFoldersAsFiles', 'MasksOnFileName', 'Masks', 'MasksExclude') {
                    if ($case.Filters.ContainsKey($k)) { $lines.Add("$k=$($case.Filters[$k])") }
                }
            }
            $text = ($lines -join "`r`n") + "`r`n"
        }
        $preset = Join-Path $dir 'probe.rnp'
        [IO.File]::WriteAllText($preset, $text, [Text.UTF8Encoding]::new($false))

        # Run ReNamer silently on the requested inputs
        $inputs = if ($case.ContainsKey('Inputs')) { $case.Inputs } else { $case.Files }
        $paths  = foreach ($x in $inputs) { if ($x -eq '.') { $in } else { (Join-Path $in (Expand-Token $x)).TrimEnd('\') } }
        $argLine = '/silent /rename "{0}" {1}' -f $preset, (($paths | ForEach-Object { '"{0}"' -f $_ }) -join ' ')
        $proc = Start-Process -FilePath $exe -ArgumentList $argLine -PassThru -WindowStyle Hidden
        $code = if ($proc.WaitForExit($TimeoutSeconds * 1000)) { $proc.ExitCode } else { $proc.Kill(); 'TIMEOUT' }

        # Collect results as relative paths ('\' suffix for folders)
        $after = @(Get-ChildItem -LiteralPath $in -Recurse | ForEach-Object {
            $rel = [IO.Path]::GetRelativePath($in, $_.FullName); if ($_.PSIsContainer) { "$rel\" } else { $rel } } | Sort-Object)

        # Assert names AND exit code: an 'unchanged' expectation must not be satisfied by a preset that failed to load/compile
        $status = ''
        if ($case.ContainsKey('Expect') -or $case.ContainsKey('ExpectExit')) {
            $namesOk = $true
            if ($case.ContainsKey('Expect')) {
                $exp = @($case.Expect | ForEach-Object { Expand-Token $_ } | Sort-Object)
                $namesOk = ($exp.Count -eq $after.Count) -and -not (Compare-Object -ReferenceObject $exp -DifferenceObject $after -CaseSensitive)
            }
            $expExit = if ($case.ContainsKey('ExpectExit')) { $case.ExpectExit } else { 0 }
            $ok = $namesOk -and ("$code" -eq "$expExit")
            if ($ok) { $pass++; $status = 'PASS' } else { $fail++; $status = 'FAIL' }
        }
        '[{0:D3}] {1,-4} exit={2,-3} {3}' -f $i, $status, $code, $case.Name
        if ($status -ne 'PASS') {
            '        in : ' + ($case.Files -join ' || ')
            '        out: ' + ($after -join ' || ')
            if ($status -eq 'FAIL') { '        exp: ' + (@($case['Expect']) -join ' || ') + "   (exit $(if ($case.ContainsKey('ExpectExit')) { $case.ExpectExit } else { 0 }))" }
        }
    }
}

end {
    # Restore Settings.ini (the CLI instance rewrites it on exit) and report any drift in the Presets folder
    if ((Get-FileHash -LiteralPath $settings).Hash -ne $settingsHash) {
        Copy-Item -LiteralPath (Join-Path $backup 'Settings.ini') -Destination $settings -Force
        'Settings.ini was rewritten by ReNamer -> restored from snapshot.'
    }
    $drift = foreach ($f in (Get-ChildItem -LiteralPath $presetDir -Recurse -File -ErrorAction SilentlyContinue)) {
        if (-not $snapshot.ContainsKey($f.FullName)) { "NEW     $($f.FullName)" }
        elseif ((Get-FileHash -LiteralPath $f.FullName).Hash -ne $snapshot[$f.FullName]) { "CHANGED $($f.FullName)" }
    }
    if ($drift) { 'WARNING: Presets folder drift detected:'; $drift } else { 'Presets folder unchanged.' }
    if ($pass + $fail) { "Result: $pass passed, $fail failed." }
    exit $fail   # non-zero when any assertion failed (CI / skill scripts can gate on it)
}
