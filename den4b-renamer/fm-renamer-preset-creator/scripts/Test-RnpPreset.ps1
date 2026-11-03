#Requires -Version 7.4
<#
.SYNOPSIS
    Validates den4b ReNamer presets (.rnp) against the skill's 15 checks.

.DESCRIPTION
    Lints one or more .rnp files and emits one finding object per problem.
    The checks (references/preset-spec.md, "Validator checks") are:

       1  Structure: contiguous [Rule0..N]; ID/Config/Marked/Comment lines;
          CRLF, no BOM, trailing CRLF, the exact layout ReNamer saves
       2  Rule ID is one of the 18 IDs (case-sensitive)
       3  Config keys equal the canonical set, in canonical order, uppercase
       4  Value types and enums; legacy values rejected
       5  Every value is canonically encoded (decode/encode round-trip)
       6  Lowercase-extension guarantee (casing.md §1)
       7  [Filters] present and equal to the variant's block
       8  File name is 'FILE <Name>.rnp' or 'CONTENTS <Name>.rnp'
       9  EXTENSION without a leading dot; TARGETFORMAT filename-safe
      10  Case fragments: no empty or duplicate entries (plus size info)
      11  RegEx pitfalls: empty alternation (error), \E, case-dependent
          patterns with CASESENSITIVE=0, unescaped $ in REPLACE (warnings)
      12  Pascal Script: BOM, modal dialogs, {$INCLUDE}, short-circuit risk
      13  Order-dependent rules (warning); User Input lines not separated
          by a bare CR, Mapping row counts that differ, empty rows (error)
      14  [fm-collision] serializer present at most once, and last
      15  Every rule has a non-empty comment

    Profile Strict (default) is for every preset the skill generates.
    Profile Legacy is for decoding the user's existing presets in the explain and
    modify flows: checks 1, 3, 4, 6, 7, 8 and 14 drop to warnings, because
    older presets can lack Comment lines, use legacy values or a different
    key order. Rules the skill adds or changes must still pass Strict.

.PARAMETER LiteralPath
    Path to one or more .rnp files.

.PARAMETER ValidationProfile
    Strict (default) or Legacy. Alias: -Profile.

.PARAMETER Variant
    FILE or CONTENTS. Overrides the variant taken from the file name, e.g.
    for a harness copy saved under another name.

.PARAMETER MaskOverrides
    [Filters] keys the preset-spec declared (e.g. @{ Masks = '*.jpg' }).
    They are expected in place of the variant block's values for check 7.

.PARAMETER StrictRules
    1-based rule numbers that must meet Strict even under -Profile Legacy:
    the rules added or changed in the modify flow (Build-RnpPreset.ps1
    reports them as StrictRules). Their findings are never softened.

.INPUTS
    System.String[]
    Pipe .rnp paths or FileInfo objects.

.OUTPUTS
    System.Management.Automation.PSCustomObject
    One finding per issue: Path, Check, Level (Error, Warning, Info), Rule
    (0-based rule index or $null), Message.

.EXAMPLE
    ./Test-RnpPreset.ps1 "$env:TEMP\rnp-staging\FILE Remove Envato Timestamp.rnp"
    Validates a freshly built preset; exit code 1 when it has errors.

.EXAMPLE
    Get-ChildItem 'C:\Tools\den4b Renamer\Presets\*.rnp' |
        ./Test-RnpPreset.ps1 -Profile Legacy |
        Where-Object Level -eq 'Error'
    Lists the hard errors in every existing preset.

.EXAMPLE
    ./Test-RnpPreset.ps1 .\probe.rnp -Variant CONTENTS -MaskOverrides @{
        Masks = '*.svg' }
    Validates a renamed harness copy with a declared mask.

.EXAMPLE
    ./Test-RnpPreset.ps1 $b.Path -Profile Legacy -StrictRules $b.StrictRules
    Validates a modified existing preset: old rules leniently, the new or
    changed rules strictly.

.NOTES
    Requires scripts\RnpCommon.psm1. Exits with code 1 when any Error
    finding is emitted, 0 otherwise.

.LINK
    https://github.com/futuremotiondev

.LINK
    Build-RnpPreset.ps1

.LINK
    ConvertFrom-Rnp.ps1
#>
[CmdletBinding()]
[OutputType([pscustomobject])]
param(
    [Parameter(
        Mandatory, Position = 0, ValueFromPipeline,
        ValueFromPipelineByPropertyName,
        HelpMessage = 'Literal path to one or more .rnp presets to validate.'
    )]
    [Alias('PSPath')]
    [ValidateNotNullOrEmpty()]
    [String[]] $LiteralPath,

    [Alias('Profile')]
    [ValidateSet('Strict', 'Legacy')]
    [String] $ValidationProfile = 'Strict',

    [ValidateSet('FILE', 'CONTENTS')]
    [String] $Variant,

    [Collections.IDictionary] $MaskOverrides = @{},

    [Int[]] $StrictRules = @()
)

begin {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    Import-Module (Join-Path $PSScriptRoot 'RnpCommon.psm1') -Force

    $catalog = Get-RnpRuleCatalog
    $minorWords = Get-RnpMinorWords
    $errorCount = 0

    # Checks that only warn under the Legacy profile.
    $legacySoft = 1, 3, 4, 6, 7, 8, 14

    # [Filters] keys that decide what a variant renames. A mismatch here
    # means the preset renames the wrong things, so it is always an error.
    $variantKeys = 'AddFilesFromFolders', 'AddFoldersAsFiles',
                   'IncludeSubfolders'

    # Pascal calls that open a modal dialog (GUI-only presets).
    $dialogPattern = '\b(ShowMessage|WideShowMessage|DialogYesNo|' +
                     'WideDialogYesNo|InputBox|InputQuery|InputBoxW|' +
                     'MessageBox)\s*\('

    $reservedNames = 'CON', 'PRN', 'AUX', 'NUL', 'COM1', 'COM2', 'COM3',
                     'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9', 'LPT1',
                     'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8',
                     'LPT9'
}

process {
    foreach ($item in $LiteralPath) {
        $findings = [Collections.Generic.List[object]]::new()
        # Pipeline input arrives as provider paths (PSPath); .NET file APIs
        # need a plain file-system path.
        $path = (Test-Path -LiteralPath $item -PathType Leaf) ?
            (Convert-Path -LiteralPath $item) : $item

        # FINDING FACTORY ──────────────────────────────────────────────────────
        # Level is the Strict level; Legacy softens the listed checks.
        $add = {
            param([int] $Check, [string] $Level, $Rule, [string] $Message)
            $keepStrict = $null -ne $Rule -and ($Rule + 1) -in $StrictRules
            if ($Level -eq 'Error' -and $ValidationProfile -eq 'Legacy' -and
                $Check -in $legacySoft -and -not $keepStrict) {
                $Level = 'Warning'
            }
            $findings.Add([pscustomobject]@{
                Path    = $path
                Check   = $Check
                Level   = $Level
                Rule    = $Rule
                Message = $Message
            })
        }

        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            & $add 1 'Error' $null 'File not found.'
            $errorCount++
            $findings
            continue
        }
        $preset = Read-RnpPreset -LiteralPath $path
        $rules = @($preset.Rules)
        $text = [IO.File]::ReadAllText($path, [Text.UTF8Encoding]::new($false))

        # CHECK 1 - STRUCTURE AND LAYOUT ───────────────────────────────────────
        if ($preset.HasBom) { & $add 1 'Error' $null 'File starts with a BOM.' }
        if ($preset.HasBareLf) {
            & $add 1 'Error' $null 'Line endings must be CRLF (bare LF found).'
        }
        if (-not $preset.EndsWithCrLf) {
            & $add 1 'Error' $null 'The last line must end with CRLF.'
        }
        elseif ($text.EndsWith("`r`n`r`n")) {
            & $add 1 'Error' $null 'Blank line at the end of the file.'
        }
        foreach ($issue in $preset.Issues) { & $add 1 'Error' $null $issue }
        if (-not $rules.Count) { & $add 1 'Error' $null 'Preset has no rules.' }
        foreach ($r in $rules) {
            if (-not $r.ID) { & $add 1 'Error' $r.Index 'Missing ID= line.' }
            if (-not $r.HasConfig) {
                & $add 1 'Error' $r.Index 'Missing Config= line.'
            }
            if ($null -eq $r.Marked) {
                & $add 1 'Error' $r.Index 'Missing Marked= line.'
            }
            elseif ($r.Marked -notin '0', '1') {
                & $add 1 'Error' $r.Index "Marked=$($r.Marked) must be 0 or 1."
            }
            if ($null -eq $r.Comment) {
                & $add 1 'Error' $r.Index (
                    'Missing Comment= line (ReNamer 7.6.0.1+ always writes it).')
            }
        }
        # Re-serializing the parsed preset must give the file back. When the
        # simpler checks pass and it still differs, the layout (key order in
        # a block, blank lines) is not what ReNamer saves.
        $structOk = -not $preset.HasBom -and -not $preset.HasBareLf -and
                    $preset.EndsWithCrLf -and -not $preset.Issues.Count
        if ($structOk -and -not $preset.IsCanonical -and
            -not @($rules | Where-Object { -not $_.ID -or -not $_.HasConfig })) {
            $rebuilt = Write-RnpPresetText -Rules $rules -Filters $preset.Filters
            if ($rebuilt -cne $text) {
                & $add 1 'Error' $null (
                    'Layout or value encoding differs from what ReNamer ' +
                    'saves (block order ID, Config, Marked, Comment; one ' +
                    'blank line between blocks; see check 5 for values).')
            }
        }

        # CHECKS 2-5 - PER-RULE CATALOG CHECKS ─────────────────────────────────
        foreach ($r in $rules) {
            $idx = $r.Index
            if (-not $r.ID) { continue }
            if ($r.ID -cnotin @($catalog.Keys)) {
                & $add 2 'Error' $idx (
                    "Unknown rule ID '$($r.ID)' (ReNamer silently skips it). " +
                    "Valid, case-sensitive: $($catalog.Keys -join ', ').")
                continue
            }
            $entry = $catalog[$r.ID]
            $canon = @($entry.Defaults.Keys)
            $keys = @($r.Config.Keys)

            # Check 3: exact key set, canonical order, uppercase.
            $missing = @($canon | Where-Object { $_ -cnotin $keys })
            $unknown = @($keys | Where-Object { $_ -cnotin $canon })
            if ($missing) {
                & $add 3 'Error' $idx (
                    "$($r.ID): missing keys $($missing -join ', ').")
            }
            if ($unknown) {
                & $add 3 'Error' $idx (
                    "$($r.ID): unknown keys $($unknown -join ', ') " +
                    '(keys are uppercase; see rnp-format.md section 4).')
            }
            if (-not $missing -and -not $unknown -and
                ($keys -join ';') -cne ($canon -join ';')) {
                & $add 3 'Error' $idx "$($r.ID): keys are not in canonical order."
            }

            # Check 4: types, enums, legacy values.
            foreach ($k in $entry.Bool) {
                if ($r.Config.Contains($k) -and $r.Config[$k] -notin '0', '1') {
                    & $add 4 'Error' $idx "$($r.ID): $k must be 0 or 1."
                }
            }
            foreach ($k in $entry.Int) {
                if ($r.Config.Contains($k) -and
                    $r.Config[$k] -notmatch '^-?\d+$') {
                    & $add 4 'Error' $idx "$($r.ID): $k must be an integer."
                }
            }
            foreach ($k in $entry.Enum.Keys) {
                if (-not $r.Config.Contains($k)) { continue }
                $e = $entry.Enum[$k]
                $v = $r.Config[$k]
                if ($e.Contains('Legacy') -and
                    $v -in @($e.Legacy | ForEach-Object { "$_" })) {
                    & $add 4 'Error' $idx (
                        "$($r.ID): $k=$v is a legacy value; use one of " +
                        "$($e.Allowed -join ', ').")
                }
                elseif ($v -notin @($e.Allowed | ForEach-Object { "$_" })) {
                    & $add 4 'Error' $idx (
                        "$($r.ID): $k=$v is not valid (allowed: " +
                        "$($e.Allowed -join ', ')).")
                }
            }
            foreach ($k in $entry.Required) {
                if ($r.Config.Contains($k) -and $k -ne 'REPLACE' -and
                    $k -ne 'TEXTWITH' -and $r.Config[$k] -eq '') {
                    & $add 4 'Warning' $idx "$($r.ID): required key $k is empty."
                }
            }

            # Check 5: canonical value encoding (Mapping rows use a raw |).
            foreach ($k in $r.ConfigRaw.Keys) {
                $raw = $r.ConfigRaw[$k]
                $canon = ConvertTo-RnpConfigValue $r.ID $k (
                    ConvertFrom-RnpValue $raw)
                if ($canon -cne $raw) {
                    $hint = ($r.ID -ceq 'Mapping' -and
                             $k -cin 'SOURCE', 'TARGET') ?
                        ' Mapping rows are encoded one by one and joined ' +
                        'with a raw | (an encoded %7C is not a separator).' :
                        ' (raw punctuation, lowercase hex or %20 for a space)'
                    & $add 5 'Error' $idx (
                        "$($r.ID): $k is not canonically encoded.$hint")
                }
            }
        }

        # CHECK 6 - LOWERCASE-EXTENSION GUARANTEE ──────────────────────────────
        $active = @($rules | Where-Object {
            $_.Marked -ne '0' -and $_.ID -cin @($catalog.Keys) })
        $isCollision = {
            param($Rule)
            $Rule.ID -eq 'PascalScript' -and $Rule.Comment -and
                $Rule.Comment.Contains('[fm-collision]')
        }
        foreach ($r in $active) {
            if ($r.ID -eq 'Case' -and
                $r.Config['EXTENSIONALWAYSUPPERCASE'] -eq '1') {
                & $add 6 'Error' $r.Index (
                    'EXTENSIONALWAYSUPPERCASE=1: extensions must end lowercase.')
            }
        }
        $lastCase = @($active | Where-Object ID -eq 'Case') |
            Select-Object -Last 1
        if (-not $lastCase) {
            & $add 6 'Error' $null (
                'No active Case rule lowercases the extension; append the ' +
                "standard 'Extension always lower case' rule.")
        }
        elseif ($lastCase.Config['EXTENSIONALWAYSLOWERCASE'] -ne '1') {
            & $add 6 'Error' $lastCase.Index (
                'The last Case rule must set EXTENSIONALWAYSLOWERCASE=1.')
        }
        else {
            foreach ($r in $active) {
                if ($r.Index -le $lastCase.Index) { continue }
                $safe = ($r.Config.Contains('SKIPEXTENSION') -and
                         $r.Config['SKIPEXTENSION'] -eq '1') -or
                        (& $isCollision $r)
                if (-not $safe) {
                    & $add 6 'Error' $r.Index (
                        "$($r.ID) follows the last Case rule but can change " +
                        'the extension (needs SKIPEXTENSION=1, or move it ' +
                        'before the casing tail).')
                }
            }
        }

        # CHECK 8 - FILE NAME (also yields the variant for check 7) ────────────
        $fileName = $preset.FileName
        $nameVariant = $null
        if ($fileName -cmatch '^(FILE|CONTENTS) (.+)\.rnp$') {
            $nameVariant = $Matches[1]
            $base = $Matches[2]
            if ($base -match '[\\/:*?"<>|]' -or $base -match '[. ]$' -or
                $base -ne $base.Trim() -or
                ($base -split '\.')[0] -in $reservedNames) {
                & $add 8 'Error' $null (
                    "Preset name '$base' is not a valid Windows file name.")
            }
        }
        else {
            & $add 8 'Error' $null (
                "File name '$fileName' must be 'FILE <Name>.rnp' or " +
                "'CONTENTS <Name>.rnp'.")
        }

        # CHECK 7 - [FILTERS] ──────────────────────────────────────────────────
        $filters = $preset.Filters
        $v = $Variant ? $Variant : $nameVariant
        if ($null -eq $filters) {
            & $add 7 'Error' $null (
                '[Filters] section is missing; ReNamer would use whatever ' +
                'filters the GUI last had.')
        }
        else {
            if (-not $v) {
                # No variant from the name: infer it from the filters.
                $v = ($filters['AddFilesFromFolders'] -eq '1') ?
                    'CONTENTS' : 'FILE'
                & $add 7 'Info' $null "Variant inferred from [Filters]: $v."
            }
            $expected = Get-RnpFiltersBlock $v
            foreach ($k in $MaskOverrides.Keys) {
                $expected[$k] = [string]$MaskOverrides[$k]
            }
            $keysSeen = @($filters.Keys)
            $keysWant = @($expected.Keys)
            if (($keysSeen -join ';') -cne ($keysWant -join ';')) {
                & $add 7 'Error' $null (
                    "[Filters] keys differ from the $v block: expected " +
                    "$($keysWant -join ', ').")
            }
            foreach ($k in $keysWant) {
                if (-not $filters.Contains($k)) { continue }
                if ($filters[$k] -ceq $expected[$k]) { continue }
                if ($k -in $variantKeys) {
                    & $add 7 'Error' $null (
                        "[Filters] $k=$($filters[$k]) does not match the $v " +
                        "variant ($k=$($expected[$k])).")
                }
                else {
                    & $add 7 'Warning' $null (
                        "[Filters] $k='$($filters[$k])' differs from the $v " +
                        "default '$($expected[$k])' (fine if requested).")
                }
            }
            foreach ($k in 'Masks', 'MasksExclude') {
                if ($filters.Contains($k) -and
                    $filters[$k] -match '%[0-9A-Fa-f]{2}') {
                    & $add 7 'Error' $null (
                        "[Filters] $k looks percent-encoded; filter values " +
                        'are raw text (encoded masks match nothing).')
                }
            }
        }

        # CHECKS 9-15 - RULE CONTENT ───────────────────────────────────────────
        $collisions = @($rules | Where-Object { & $isCollision $_ })
        foreach ($r in $rules) {
            $idx = $r.Index
            $c = $r.Config

            # Check 9: extension and date target format.
            if ($r.ID -eq 'Extension' -and $c.Contains('EXTENSION') -and
                $c['EXTENSION'].StartsWith('.')) {
                & $add 9 'Error' $idx (
                    'EXTENSION must not start with a dot (.md gives x..md).')
            }
            if ($r.ID -eq 'ReformatDate' -and $c.Contains('TARGETFORMAT') -and
                $c['TARGETFORMAT'] -match '[\\/:*?"<>|]') {
                & $add 9 'Error' $idx (
                    'TARGETFORMAT contains characters that are illegal in ' +
                    'file names.')
            }

            # Check 10: Case fragments.
            if ($r.ID -eq 'Case' -and $c.Contains('FRAGMENTSTEXT') -and
                $c['FRAGMENTSTEXT'] -ne '') {
                $frags = $c['FRAGMENTSTEXT'] -split ','
                # A single trailing comma is fine (verified); other empty
                # entries are sloppy. .Count, because @('') is falsy.
                $inner = ($frags.Count -gt 1 -and $frags[-1] -eq '') ?
                    $frags[0..($frags.Count - 2)] : $frags
                if (@($inner | Where-Object { $_.Trim() -eq '' }).Count) {
                    & $add 10 'Warning' $idx 'FRAGMENTSTEXT has empty entries.'
                }
                $seen = [Collections.Generic.HashSet[string]]::new(
                    [StringComparer]::OrdinalIgnoreCase)
                $dupes = @($frags | Where-Object { $_ -and -not $seen.Add($_) })
                if ($dupes) {
                    $clash = @($dupes | Where-Object {
                        $_.ToLowerInvariant() -in $minorWords })
                    $shown = ($dupes | Sort-Object -Unique |
                        Select-Object -First 10) -join ', '
                    & $add 10 'Warning' $idx (
                        "FRAGMENTSTEXT has $($dupes.Count) case-insensitive " +
                        "duplicates ($shown); the later spelling wins." +
                        ($clash ? ' Some clash with APA minor words.' : ''))
                }
                if ($c['FORCECASE'] -ne '1') {
                    & $add 10 'Warning' $idx (
                        'FRAGMENTSTEXT is set but FORCECASE=0, so it is ignored.')
                }
                $bytes = (ConvertTo-RnpValue $c['FRAGMENTSTEXT']).Length
                & $add 10 'Info' $idx (
                    "$($frags.Count) fragments, $bytes bytes encoded.")
            }

            # Check 11: RegEx pitfalls.
            if ($r.ID -eq 'RegEx' -and $c.Contains('EXPRESSION')) {
                $expr = $c['EXPRESSION']
                # Blank out escapes and character classes, then look for an
                # empty group or alternative: it matches everywhere.
                $bare = $expr -replace '\\.', 'x' -replace '\[[^\]]*\]', 'x'
                if ($bare -match '\((\?(:|=|!|<=|<!))?\)|\(\?:\||\(\||\|\||\|\)') {
                    & $add 11 'Error' $idx (
                        'EXPRESSION has an empty group or alternative (e.g. ' +
                        'an empty <LC> list); it matches everywhere.')
                }
                if ($expr -eq '') {
                    # UI presets are templates the user fills in before running.
                    $isTemplate = $fileName -cmatch '^(FILE|CONTENTS) UI '
                    & $add 11 ($isTemplate ? 'Warning' : 'Error') $idx (
                        'EXPRESSION is empty' +
                        ($isTemplate ? ' (UI template placeholder).' : '.'))
                }
                $replace = [string]$c['REPLACE']
                if ($replace -cmatch '\\E') {
                    & $add 11 'Warning' $idx (
                        'REPLACE uses \E, which ReNamer prints as a literal E.')
                }
                $caseDependent = $expr -cmatch ('\\p\{(Lu|Ll|Lt)\}|' +
                    '\[[^\]]*(A-Z|a-z)[^\]]*\]')
                if ($caseDependent -and $c['CASESENSITIVE'] -ne '1') {
                    & $add 11 'Warning' $idx (
                        'EXPRESSION depends on letter case but ' +
                        'CASESENSITIVE=0 makes letter classes match both cases.')
                }
                $noEsc = $replace -replace '\\.', 'x'
                if ($noEsc -match '\$(?![\d{])') {
                    & $add 11 'Warning' $idx (
                        'REPLACE has a $ not followed by a digit or {; write a ' +
                        'literal dollar sign as \$.')
                }
            }

            # Check 12: Pascal Script.
            if ($r.ID -eq 'PascalScript' -and $c.Contains('SOURCEUTF8')) {
                $src = $c['SOURCEUTF8']
                if ($src.Length -and $src[0] -eq [char]0xFEFF) {
                    & $add 12 'Warning' $idx (
                        'Script starts with a BOM; strip it before embedding.')
                }
                if ($src -match $dialogPattern) {
                    & $add 12 'Warning' $idx (
                        "Script calls $($Matches[1]): the preset is GUI-only " +
                        '(never /silent or context-menu rename).')
                }
                if ($src -match '\{\$I(NCLUDE)?\s') {
                    & $add 12 'Warning' $idx (
                        '{$INCLUDE} makes the preset depend on an external file.')
                }
                # Pascal Script does not short-circuit, so a bounds check
                # joined by and/or to an index access can still read out of
                # range. Futuremotion's serializers are field-tested, so skip them.
                if (-not (& $isCollision $r)) {
                    $n = 0
                    foreach ($line in ($src -split '\r?\n')) {
                        $n++
                        $code = ($line -replace '//.*$', '')
                        if ($code -match '\b(and|or)\b' -and
                            $code -match '\w\[[^\]]*[+-][^\]]*\]' -and
                            $code -match '\b(Length|WideLength|High)\b') {
                            & $add 12 'Warning' $idx (
                                "Script line ${n}: bounds check and index " +
                                'access in one and/or expression; Pascal ' +
                                'Script evaluates both (use nested ifs).')
                        }
                    }
                }
            }

            # Check 13: order-dependent rules, User Input and Mapping lists.
            if ($r.Marked -ne '0' -and $r.ID -in 'Serialize', 'UserInput') {
                & $add 13 'Warning' $idx (
                    "$($r.ID) depends on the file-table order (sorting).")
            }
            # User Input lines are separated by a bare CR (%0D). CRLF or LF
            # makes ReNamer refuse the whole batch (verified, C1).
            if ($r.ID -eq 'UserInput' -and $c.Contains('INPUT') -and
                $c['INPUT'].Contains("`n")) {
                & $add 13 'Error' $idx (
                    'User Input lines must be separated by CR only; CRLF ' +
                    'or LF makes ReNamer refuse the whole batch.')
            }
            # Mapping: one row per '|' in SOURCE and TARGET. Fewer TARGET
            # rows rename the unmatched files to an EMPTY name (verified).
            if ($r.ID -eq 'Mapping') {
                $src = @(([string]$c['SOURCE']) -split '\|')
                $dst = @(([string]$c['TARGET']) -split '\|')
                if ($src.Count -ne $dst.Count) {
                    & $add 13 'Error' $idx (
                        "Mapping has $($src.Count) SOURCE rows but " +
                        "$($dst.Count) TARGET rows; unmatched rows rename " +
                        'files to an empty name.')
                }
                elseif (@($src + $dst | Where-Object { $_ -eq '' }).Count -and
                        "$($c['SOURCE'])$($c['TARGET'])" -ne '') {
                    & $add 13 'Error' $idx (
                        'Mapping has an empty row (a doubled or trailing |).')
                }
                if ("$($c['SOURCE'])$($c['TARGET'])" -match '[\r\n]') {
                    & $add 13 'Error' $idx (
                        'Mapping rows are separated by |, never by line breaks.')
                }
            }

            # Check 15: comments.
            if ($null -ne $r.Comment -and
                [string]::IsNullOrWhiteSpace($r.Comment)) {
                & $add 15 'Warning' $idx 'Rule has an empty comment.'
            }
        }

        # CHECK 14 - COLLISION SERIALIZER PLACEMENT ────────────────────────────
        if ($collisions.Count -gt 1) {
            & $add 14 'Error' $collisions[1].Index (
                'More than one [fm-collision] serializer.')
        }
        if ($collisions.Count -and
            $collisions[-1].Index -ne $rules[-1].Index) {
            & $add 14 'Error' $collisions[-1].Index (
                'The [fm-collision] serializer must be the last rule.')
        }
        foreach ($r in $rules) {
            if ($r.Comment -and $r.Comment.Contains('[fm-collision]') -and
                $r.ID -ne 'PascalScript') {
                & $add 14 'Error' $r.Index (
                    '[fm-collision] marks a rule that is not a Pascal script.')
            }
        }

        $errorCount += @($findings | Where-Object Level -eq 'Error').Count
        $findings
    }
}

end {
    exit ($errorCount ? 1 : 0)
}
