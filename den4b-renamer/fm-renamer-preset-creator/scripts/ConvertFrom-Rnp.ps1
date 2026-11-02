#Requires -Version 7.4
<#
.SYNOPSIS
    Decodes a ReNamer preset (.rnp) into a preset-spec and a plain-English
    explanation.

.DESCRIPTION
    The explain and modify flows start here. For every .rnp file it writes:

      <name>.spec.json  A preset-spec with casing.mode 'verbatim' and
                        collisions 'none': every rule's id, marked, comment
                        and config (keys in file order, values decoded), the
                        [Filters] block as-is (or null when absent) and
                        outputFileName. Build-RnpPreset.ps1 turns it back
                        into a byte-identical .rnp.
      <name>.md         A Markdown explanation: what the variant renames, the
                        filters, one sentence per rule, and the validator's
                        findings (Legacy profile).

    The decode is only trusted when it is lossless. The script checks that
    the parsed preset re-serializes to the exact same bytes, then rebuilds
    the written spec with Build-RnpPreset.ps1 and compares again. If either
    step differs (BOM, bare LF, non-canonical encoding, stray lines), it
    refuses to write the spec and says why. The explanation is still
    written, because explaining a messy preset is still useful.

.PARAMETER LiteralPath
    Path to one or more .rnp files.

.PARAMETER OutputDirectory
    Folder for the .spec.json and .md files. Defaults to the 'decoded'
    subfolder of StagingDir from config.json (%TEMP%\rnp-staging\decoded).

.INPUTS
    System.String[]
    Pipe .rnp paths or FileInfo objects.

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Path, SpecPath ($null when not lossless), MarkdownPath, RuleCount,
    Lossless, Reason, Explanation (the Markdown text).

.EXAMPLE
    ./ConvertFrom-Rnp.ps1 'C:\Tools\den4b Renamer\Presets\FILE CASE Kebab.rnp'
    Writes the spec and explanation to %TEMP%\rnp-staging\decoded.

.EXAMPLE
    (./ConvertFrom-Rnp.ps1 .\x.rnp).Explanation
    Prints the explanation for use in chat.

.EXAMPLE
    Get-ChildItem 'C:\Tools\den4b Renamer\Presets\*.rnp' |
        ./ConvertFrom-Rnp.ps1 -OutputDirectory .\decoded |
        Where-Object -Not Lossless
    Lists presets that cannot be round-tripped, with the reason.

.NOTES
    Requires scripts\RnpCommon.psm1, Build-RnpPreset.ps1 and
    Test-RnpPreset.ps1 next to this script. Exits with code 1 when any
    preset could not be decoded losslessly.

.LINK
    https://github.com/futuremotiondev

.LINK
    Build-RnpPreset.ps1

.LINK
    Test-RnpPreset.ps1
#>
[CmdletBinding()]
[OutputType([pscustomobject])]
param(
    [Parameter(
        Mandatory, Position = 0, ValueFromPipeline,
        ValueFromPipelineByPropertyName,
        HelpMessage = 'Literal path to one or more .rnp presets to decode.'
    )]
    [Alias('PSPath')]
    [ValidateNotNullOrEmpty()]
    [String[]] $LiteralPath,

    [String] $OutputDirectory
)

begin {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    Import-Module (Join-Path $PSScriptRoot 'RnpCommon.psm1') -Force

    $builder = Join-Path $PSScriptRoot 'Build-RnpPreset.ps1'
    $validator = Join-Path $PSScriptRoot 'Test-RnpPreset.ps1'
    $config = Get-RnpConfig
    # Resolve against the PowerShell location (relative paths after
    # Set-Location), because .NET file APIs use the process directory.
    $outDir = $PSCmdlet.GetUnresolvedProviderPathFromPSPath(
        ($OutputDirectory ? $OutputDirectory :
            [IO.Path]::Combine($config.StagingDir, 'decoded')))
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    $notLossless = 0

    # FORMATTING HELPERS ───────────────────────────────────────────────────────
    # Show a value as inline code; long values are shortened and leading or
    # trailing spaces are called out because they are invisible otherwise.
    $fmt = {
        param([string] $Value, [int] $Max = 60)
        if ($Value -eq '') { return 'nothing' }
        if ($Value -eq ' ') { return 'a space' }
        if ($Value.Trim() -eq '' -and $Value -notmatch '[\r\n]') {
            return "$($Value.Length) spaces"
        }
        $shown = $Value -replace "`r`n", '⏎'
        if ($shown.Length -gt $Max) { $shown = $shown.Substring(0, $Max) + '…' }
        $tick = $shown.Contains('`') ? '``' : '`'
        $pad = $shown.Contains('`') ? ' ' : ''
        $lead = $Value -match '^\s'
        $trail = $Value -match '\s$'
        $note = ($lead -and $trail) ? ' (with spaces around it)' :
            $lead ? ' (with a leading space)' :
            $trail ? ' (with a trailing space)' : ''
        "$tick$pad$shown$pad$tick$note"
    }
    # Join a list as "`a`, `b` and 3 more".
    $fmtList = {
        param([string[]] $Items, [int] $Show = 4)
        $parts = @($Items | Select-Object -First $Show |
            ForEach-Object { & $fmt $_ 30 })
        $more = $Items.Count - $parts.Count
        $text = $parts -join ', '
        if ($more -gt 0) { $text += " and $more more" }
        $text
    }
    $on = { param($Rule, [string] $Key) $Rule.Config[$Key] -eq '1' }
    $extNote = {
        param($Rule)
        ($Rule.Config.Contains('SKIPEXTENSION') -and
         $Rule.Config['SKIPEXTENSION'] -eq '0') ?
            ' The extension is included.' : ''
    }

    # ONE SENTENCE PER RULE ────────────────────────────────────────────────────
    # Covers all 18 rule IDs. Unknown IDs are reported, never guessed at.
    $describe = {
        param($Rule)
        $c = $Rule.Config
        $g = { param([string] $k) $c.Contains($k) ? [string]$c[$k] : '' }
        switch -CaseSensitive ($Rule.ID) {
            'Insert' {
                $text = & $fmt (& $g 'TEXT')
                $tag = ((& $g 'TEXT') -match ':(\w+):') ?
                    " (``:$($Matches[1]):`` is filled in per file)" : ''
                $s = switch (& $g 'WHERE') {
                    '1' { "Adds $text at the start of the name" }
                    '2' {
                        "Adds $text at the end of the name" +
                        (((& $g 'SKIPEXTENSION') -eq '0') ?
                            ' (after the extension)' : '')
                    }
                    '3' { "Adds $text before the extension (legacy WHERE=3)" }
                    '4' {
                        "Inserts $text at position $(& $g 'POSITION')" +
                        ((& $on $Rule 'RIGHTTOLEFT') ?
                            ', counted from the right' : '')
                    }
                    '5' {
                        "Inserts $text after every " +
                        (& $fmt (& $g 'INSERTAFTERTEXT'))
                    }
                    '6' {
                        "Inserts $text before every " +
                        (& $fmt (& $g 'INSERTBEFORETEXT'))
                    }
                    '7' { "Replaces the whole name with $text" }
                    default { "Does nothing (WHERE=$(& $g 'WHERE'))" }
                }
                return "$s$tag."
            }
            'Delete' {
                if (& $on $Rule 'DELETECURRENTNAME') {
                    return 'Deletes the whole current name, so the ' +
                           'following rules can rebuild it.'
                }
                $from = ((& $g 'FROM') -eq '2') ?
                    "from $(& $fmt (& $g 'FROMDELIMITER'))" :
                    "from position $(& $g 'FROMPOSITION')"
                $until = switch (& $g 'UNTIL') {
                    '1' { "for $(& $g 'UNTILCOUNT') character(s)" }
                    '2' { 'to the end' }
                    '3' { "up to $(& $fmt (& $g 'UNTILDELIMITER'))" }
                    default { "until mode $(& $g 'UNTIL')" }
                }
                $delims = ''
                if ((& $g 'FROM') -eq '2' -or (& $g 'UNTIL') -eq '3') {
                    $delims = (& $on $Rule 'LEAVEDELIMITER') ?
                        ', keeping the delimiters' :
                        ', deleting the delimiters too'
                }
                $rtl = (& $on $Rule 'RIGHTTOLEFT') ?
                    'Working from the right, deletes' : 'Deletes'
                return "$rtl $from $until$delims.$(& $extNote $Rule)"
            }
            'Remove' {
                $which = @{ '1' = 'the first'; '2' = 'the last'; '3' = 'every' }
                $targets = (& $g 'TEXT') -split '\*\|\*'
                $flags = @(
                    (& $on $Rule 'CASESENSITIVE') ? 'case-sensitive' : $null
                    (& $on $Rule 'USEWILDCARDS') ? 'wildcards' : $null
                    (& $on $Rule 'WHOLEWORDSONLY') ? 'whole words only' : $null
                ) | Where-Object { $_ }
                $f = $flags ? " ($($flags -join ', '))" : ''
                return "Removes $($which[(& $g 'WHICH')] ?? 'no') occurrence " +
                       "of $(& $fmtList $targets)$f.$(& $extNote $Rule)"
            }
            'Replace' {
                $which = @{ '1' = 'the first'; '2' = 'the last'; '3' = 'every' }
                $finds = @((& $g 'TEXTWHAT') -split '\*\|\*')
                $withs = @((& $g 'TEXTWITH') -split '\*\|\*')
                # A trailing *|* leaves an empty find, which matches nothing;
                # drop those pairs so the sentence describes what runs.
                if ($withs.Count -eq $finds.Count) {
                    $keep = @(0..($finds.Count - 1) |
                        Where-Object { $finds[$_] -ne '' })
                    if ($keep.Count -and $keep.Count -lt $finds.Count) {
                        $finds = @($keep | ForEach-Object { $finds[$_] })
                        $withs = @($keep | ForEach-Object { $withs[$_] })
                    }
                }
                $flags = @(
                    (& $on $Rule 'CASESENSITIVE') ? 'case-sensitive' : $null
                    (& $on $Rule 'USEWILDCARDS') ? 'wildcards' : $null
                    (& $on $Rule 'WHOLEWORDSONLY') ? 'whole words only' : $null
                ) | Where-Object { $_ }
                $f = $flags ? " ($($flags -join ', '))" : ''
                $w = $which[(& $g 'WHICH')] ?? 'no'
                if ($finds.Count -gt 1 -and $withs.Count -eq $finds.Count) {
                    $top = [Math]::Min(3, $finds.Count)
                    $pairs = for ($i = 0; $i -lt $top; $i++) {
                        "$(& $fmt $finds[$i] 25) → $(& $fmt $withs[$i] 25)"
                    }
                    $more = $finds.Count - 3
                    return "Replaces $w occurrence of $($finds.Count) " +
                           "find/replace pairs, e.g. $($pairs -join ', ')" +
                           (($more -gt 0) ? " and $more more" : '') +
                           "$f.$(& $extNote $Rule)"
                }
                $with = ($finds.Count -eq 1 -and $withs.Count -eq 1) ?
                    $withs[0] : (& $g 'TEXTWITH')
                return "Replaces $w occurrence of $(& $fmtList $finds) with " +
                       "$(& $fmt $with)$f.$(& $extNote $Rule)"
            }
            'Rearrange' {
                $parts = (& $g 'DELIMETERS') -split '\|'
                $how = switch (& $g 'DELIMITERTYPE') {
                    '1' { "at positions $((& $g 'DELIMETERS') -replace '\|', ', ')" }
                    '2' {
                        'at exactly these delimiters, in order: ' +
                        (& $fmtList $parts 6)
                    }
                    default { "at any of $(& $fmtList $parts 6)" }
                }
                $rtl = (& $on $Rule 'RIGHTTOLEFT') ? ' (from the right)' : ''
                return "Splits the name $how$rtl and rebuilds it as " +
                       "$(& $fmt (& $g 'NEWPATTERN')) (`$1 = first part, " +
                       "`$-1 = last part).$(& $extNote $Rule)"
            }
            'Extension' {
                $bits = [Collections.Generic.List[string]]::new()
                if (& $on $Rule 'NEWEXTENSION') {
                    $e = & $fmt ('.' + (& $g 'EXTENSION'))
                    $bits.Add((& $on $Rule 'APPEND') ?
                        "appends the extension $e" :
                        "changes the extension to $e")
                }
                if (& $on $Rule 'USEBINSIGN') {
                    $bits.Add("detects the real extension from the file's " +
                              'content')
                }
                if (& $on $Rule 'REMOVEDUPLICATES') {
                    $bits.Add('removes duplicate extensions (y.jpg.JPG → y.jpg)')
                }
                if (-not $bits.Count) { return 'Does nothing (all options off).' }
                $s = $bits -join ' and '
                return $s.Substring(0, 1).ToUpper() + $s.Substring(1) + '.'
            }
            'Strip' {
                $sets = @(
                    (& $on $Rule 'CHECKENGLISHLETTERS') ? 'English letters' : $null
                    (& $on $Rule 'CHECKDIGITS') ? 'digits' : $null
                    (& $on $Rule 'CHECKSYMBOLS') ? 'symbols' : $null
                    (& $on $Rule 'CHECKBRACKETS') ? 'bracket characters' : $null
                    (& $on $Rule 'CHECKUSERDEFINED') ?
                        "the characters $(& $fmt (& $g 'TEXTUSERDEFINED'))" : $null
                    (& $on $Rule 'CHECKUNICODERANGE') ?
                        "Unicode $(& $fmt (& $g 'TEXTUNICODERANGE'))" : $null
                ) | Where-Object { $_ }
                if (-not $sets) { return 'Does nothing (no character set ticked).' }
                $where = @{ '0' = 'everywhere'; '1' = 'at the start';
                            '2' = 'at the end' }[(& $g 'WHERE')]
                $verb = (& $on $Rule 'STRIPALLEXCEPTSELECTED') ?
                    'Strips every character except' : 'Strips'
                return "$verb $($sets -join ', ') $where.$(& $extNote $Rule)"
            }
            'Case' {
                $what = switch (& $g 'WHAT') {
                    '0' { 'Leaves letter case as it is' }
                    '1' { 'Lowercases everything' }
                    '2' { 'UPPERCASES everything' }
                    '3' { 'Capitalizes Every Word' }
                    '4' { 'Inverts the case of every letter' }
                    '5' { 'Capitalizes the first letter' }
                    '6' {
                        'Capitalizes every word, keeping other capitals ' +
                        '(legacy WHAT=6)'
                    }
                    '7' { 'Applies sentence case' }
                    default { "Uses case mode $(& $g 'WHAT')" }
                }
                if ((& $g 'WHAT') -in '3', '5', '7') {
                    $what += (& $on $Rule 'PRESERVECASE') ?
                        ', keeping existing capitals' :
                        ' (everything else lowercased first)'
                }
                $frag = & $g 'FRAGMENTSTEXT'
                if ((& $on $Rule 'FORCECASE') -and $frag) {
                    $list = @($frag -split ',' | Where-Object { $_ })
                    $what += ", then forces the exact spelling of " +
                             "$($list.Count) words/phrases (e.g. " +
                             "$(& $fmtList $list 5))"
                }
                if (& $on $Rule 'EXTENSIONALWAYSLOWERCASE') {
                    $what += '; the extension is always lowercased'
                }
                elseif (& $on $Rule 'EXTENSIONALWAYSUPPERCASE') {
                    $what += '; the extension is always UPPERCASED'
                }
                return "$what.$(& $extNote $Rule)"
            }
            'Serialize' {
                $where = switch (& $g 'WHERE') {
                    '1' { 'as a prefix' }
                    '2' { 'as a suffix' }
                    '3' { 'as a suffix before the extension (legacy WHERE=3)' }
                    '4' { "at position $(& $g 'POSITION')" }
                    '7' { 'replacing the whole name' }
                    default { "(WHERE=$(& $g 'WHERE'), no effect)" }
                }
                $sys = @{ '2' = 'English letters'; '3' = 'Roman numerals';
                          '4' = 'Chinese numerals'; '5' = 'custom letters';
                          '6' = 'custom digits'; '7' = 'music notes'
                        }[(& $g 'NUMERALSYSTEM')]
                $bits = @(
                    "starting at $(& $g 'INDEX')"
                    ((& $g 'STEP') -ne '1') ? "step $(& $g 'STEP')" : $null
                    ((& $g 'REPEAT') -ne '1') ?
                        "each number used $(& $g 'REPEAT') times" : $null
                    (& $on $Rule 'PADTOLENGTH') ?
                        "zero-padded to $(& $g 'PADTOLENGTHVALUE') digits" : $null
                    (& $on $Rule 'RESETIFFOLDERCHANGES') ?
                        'restarting in each folder' : $null
                    (& $on $Rule 'RESETIFFILENAMECHANGES') ?
                        'restarting whenever the name changes' : $null
                    (& $on $Rule 'RESETEVERY') ?
                        "restarting every $(& $g 'RESETEVERYCOUNT') files" : $null
                    $sys ? "written as $sys" : $null
                    ((& $g 'TYPE') -eq '2') ? 'legacy random mode (TYPE=2)' : $null
                ) | Where-Object { $_ }
                return "Numbers the files $where, $($bits -join ', '). " +
                       'The order follows the file table (sort order).' +
                       (& $extNote $Rule)
            }
            'Randomize' {
                $pools = @(
                    (& $on $Rule 'USEDIGITS') ? 'digits' : $null
                    (& $on $Rule 'USEENGLISHLETTERS') ? 'letters' : $null
                    (& $on $Rule 'USEUSERDEFINED') ?
                        (& $fmt (& $g 'USERDEFINEDCHARS')) : $null
                ) | Where-Object { $_ }
                $where = @{ '1' = 'as a prefix'; '2' = 'as a suffix';
                            '4' = "at position $(& $g 'POSITION')";
                            '7' = 'replacing the whole name' }[(& $g 'WHERE')]
                return "Adds a random $(& $g 'LENGTH')-character string of " +
                       "$($pools -join ' and ') $($where ?? '(no effect)')" +
                       ((& $on $Rule 'UNIQUE') ? ', unique per file' : '') +
                       ".$(& $extNote $Rule)"
            }
            'Padding' {
                $bits = @(
                    switch (& $g 'NUMBERPADDING') {
                        '1' {
                            "zero-pads every number to " +
                            "$(& $g 'NUMBERPADDINGLENGTH') digits (years and " +
                            'versions too)'
                        }
                        '2' { 'removes zero padding from every number' }
                    }
                    (& $on $Rule 'TEXTPADDING') ?
                        ("pads the whole name to " +
                         "$(& $g 'TEXTPADDINGLENGTH') characters with " +
                         "$(& $fmt (& $g 'TEXTPADDINGCHARS')) on the " +
                         (((& $g 'TEXTPADDINGPOSITION') -eq '2') ?
                            'right' : 'left')) : $null
                ) | Where-Object { $_ }
                if (-not $bits) { return 'Does nothing (padding off).' }
                $s = $bits -join ' and '
                return $s.Substring(0, 1).ToUpper() + $s.Substring(1) +
                       ".$(& $extNote $Rule)"
            }
            'CleanUp' {
                $brackets = @(
                    (& $on $Rule 'BRACKETSROUND') ? '(…)' : $null
                    (& $on $Rule 'BRACKETSSQUARE') ? '[…]' : $null
                    (& $on $Rule 'BRACKETSCURVY') ? '{…}' : $null
                ) | Where-Object { $_ }
                $seps = @(
                    (& $on $Rule 'SPACESDOT') ? '.' : $null
                    (& $on $Rule 'SPACESCOMMA') ? ',' : $null
                    (& $on $Rule 'SPACESUNDERSCORE') ? '_' : $null
                    (& $on $Rule 'SPACESPLUS') ? '+' : $null
                    (& $on $Rule 'SPACESHYPHEN') ? '-' : $null
                    (& $on $Rule 'SPACESWEB') ? '%20' : $null
                ) | Where-Object { $_ }
                $sepText = ($seps | ForEach-Object { '`' + $_ + '`' }) -join ' '
                $bits = @(
                    $brackets ?
                        "removes $($brackets -join ' ') with their content" :
                        $null
                    $seps ? ("turns $sepText into spaces" +
                             ((& $on $Rule 'SPACESSKIPVERSIONS') ?
                                ' (keeping version numbers like v1.2.3)' : '')) : $null
                    (& $on $Rule 'INSERTSPACEBEFORECAPITALS') ?
                        'splits CamelCase words' : $null
                    (& $on $Rule 'PREPAREFORSHAREPOINT') ?
                        'makes the name SharePoint-safe' : $null
                    (& $on $Rule 'NORMALIZESPACES') ?
                        'turns Unicode spaces into normal spaces' : $null
                    (& $on $Rule 'STRIPUNICODEMARKS') ?
                        'strips accents (café → cafe)' : $null
                    (& $on $Rule 'STRIPUNICODEEMOJI') ? 'strips emoji' : $null
                    (& $on $Rule 'SPACESFIX') ?
                        'collapses repeated spaces and trims the ends' : $null
                ) | Where-Object { $_ }
                if (-not $bits) { return 'Does nothing (all options off).' }
                $s = $bits -join ', '
                return 'Cleans up: ' + $s + ".$(& $extNote $Rule)"
            }
            'Translit' {
                $pairs = @((& $g 'ALPHABET') -split "`r?`n" |
                    Where-Object { $_ -match '=' }).Count
                $dir = ((& $g 'DIRECTION') -eq '2') ? 'backward' : 'forward'
                return "Transliterates characters with an embedded map of " +
                       "$pairs pairs ($dir" +
                       ((& $on $Rule 'ADJUSTCASE') ? ', case-adjusted' : '') +
                       ").$(& $extNote $Rule)"
            }
            'ReformatDate' {
                $src = (& $g 'SOURCEFORMATS') -split '\|'
                $s = "Rewrites dates written as $(& $fmtList $src 5) into " +
                     "$(& $fmt (& $g 'TARGETFORMAT'))"
                if (& $on $Rule 'ADJUSTTIME') {
                    $part = @{ '1' = 'years'; '2' = 'months'; '3' = 'days';
                               '4' = 'hours'; '5' = 'minutes';
                               '6' = 'seconds'; '7' = 'milliseconds'
                             }[(& $g 'ADJUSTTIMEPART')]
                    $s += ", shifted by $(& $g 'ADJUSTTIMEBY') $part"
                }
                if (& $on $Rule 'WHOLEWORDSONLY') { $s += ' (whole words only)' }
                return "$s.$(& $extNote $Rule)"
            }
            'RegEx' {
                $cs = (& $on $Rule 'CASESENSITIVE') ?
                    'case-sensitive' : 'case-insensitive'
                return "Replaces every match of the regular expression " +
                       "$(& $fmt (& $g 'EXPRESSION') 90) with " +
                       "$(& $fmt (& $g 'REPLACE')) ($cs)." +
                       (& $extNote $Rule)
            }
            'PascalScript' {
                $key = $c.Contains('SOURCEUTF8') ? 'SOURCEUTF8' : 'SOURCE'
                $src = & $g $key
                $lines = @($src -split "`r?`n").Count
                # Use the script's first comment as its summary when present.
                $summary = ''
                if ($src -match '^\s*(?:\{([^}]*)\}|//\s*(.+))') {
                    $first = (($Matches[1] ?? $Matches[2]) -split "`r?`n" |
                        Where-Object { $_.Trim() } | Select-Object -First 1)
                    if ($first) {
                        $summary = " Its header says: '$($first.Trim())'."
                    }
                }
                $legacy = ($key -eq 'SOURCE') ?
                    ' (legacy ANSI SOURCE key, pre-ReNamer 7)' : ''
                $role = ($Rule.Comment -and
                         $Rule.Comment.Contains('[fm-collision]')) ?
                    ' It is the collision serializer and must stay last.' : ''
                return "Runs a $lines-line Pascal script$legacy.$summary$role"
            }
            'UserInput' {
                # Lines are separated by a bare CR in presets ReNamer saves.
                $lines = @((& $g 'INPUT') -split "`r`n|`r|`n" |
                    Where-Object { $_ })
                $act = @{
                    '0' = 'Replaces the name of file n with line n of'
                    '1' = 'Puts line n in front of the name of file n, from'
                    '2' = 'Puts line n after the name of file n, from'
                }[(& $g 'ACTION')]
                return "$act a typed list of $($lines.Count) line(s) " +
                       "($(& $fmtList $lines 3)), in file-table order; " +
                       'files beyond the end of the list keep their names.' +
                       (& $extNote $Rule)
            }
            'Mapping' {
                # Rows are joined with '|' (one row per file name).
                $src = @((& $g 'SOURCE') -split '\|')
                $dst = @((& $g 'TARGET') -split '\|')
                $top = [Math]::Min(3, [Math]::Min($src.Count, $dst.Count))
                $pairs = for ($i = 0; $i -lt $top; $i++) {
                    "$(& $fmt $src[$i] 25) → $(& $fmt $dst[$i] 25)"
                }
                $more = $src.Count - $top
                $inv = & $on $Rule 'INVERSEMAPPING'
                $s = "Renames by a lookup table of $($src.Count) row(s)" +
                     ($inv ? ' used in reverse (new name → old name)' : '') +
                     ": $($pairs -join ', ')" +
                     (($more -gt 0) ? " and $more more" : '')
                if ($src.Count -ne $dst.Count) {
                    $s += " (WARNING: $($dst.Count) TARGET rows, so some " +
                          'files would get an empty name)'
                }
                if (& $on $Rule 'PARTIALMATCH') {
                    $s += '; a partial match replaces the whole name'
                }
                if (& $on $Rule 'ALLOWREUSE') {
                    $s += '; a row can map several files'
                }
                return "$s.$(& $extNote $Rule)"
            }
            default {
                return "Unknown rule ID '$($Rule.ID)': ReNamer silently " +
                       'skips it when the preset loads.'
            }
        }
    }
}

process {
    foreach ($item in $LiteralPath) {
        $path = Convert-Path -LiteralPath $item
        $preset = Read-RnpPreset -LiteralPath $path
        $rules = @($preset.Rules)
        $fileName = $preset.FileName
        $baseName = [IO.Path]::GetFileNameWithoutExtension($fileName)
        $variant = ($fileName -cmatch '^(FILE|CONTENTS) ') ? $Matches[1] : $null
        $displayName = $variant ? $baseName.Substring($variant.Length + 1) :
            $baseName

        # SPEC ─────────────────────────────────────────────────────────────────
        # Config values stay strings so '01' or '' survive exactly. A $null
        # marked/comment means the line is absent in the file (legacy).
        $specRules = foreach ($r in $rules) {
            $cfg = [ordered]@{}
            foreach ($k in $r.Config.Keys) { $cfg[$k] = [string]$r.Config[$k] }
            [ordered]@{
                id      = $r.ID
                marked  = ($r.Marked -match '^\d+$') ? [int]$r.Marked : $r.Marked
                comment = $r.Comment
                config  = $cfg
            }
        }
        $filters = $null
        if ($null -ne $preset.Filters) {
            $filters = [ordered]@{}
            foreach ($k in $preset.Filters.Keys) {
                $filters[$k] = $preset.Filters[$k]
            }
        }
        $spec = [ordered]@{
            name           = $displayName
            variants       = @($variant | Where-Object { $_ })
            outputFileName = $fileName
            casing         = [ordered]@{ mode = 'verbatim' }
            collisions     = 'none'
            filters        = $filters
            rules          = @($specRules)
        }

        # LOSSLESS CHECK ───────────────────────────────────────────────────────
        $reason = $null
        if ($preset.HasBom) { $reason = 'the file starts with a BOM' }
        elseif ($preset.HasBareLf) { $reason = 'it has bare LF line endings' }
        elseif (-not $preset.EndsWithCrLf) {
            $reason = 'the last line has no CRLF'
        }
        elseif ($preset.Issues.Count) {
            $reason = 'structural issues: ' + ($preset.Issues -join '; ')
        }
        elseif (-not $preset.IsCanonical) {
            $reason = 'values or layout are not in the canonical form ' +
                      'ReNamer writes'
        }
        elseif (@($rules | Where-Object { $_.ID -cnotin
                   @((Get-RnpRuleCatalog).Keys) })) {
            $reason = 'it contains an unknown rule ID'
        }

        $specPath = Join-Path $outDir "$baseName.spec.json"
        if (-not $reason) {
            $json = $spec | ConvertTo-Json -Depth 10
            [IO.File]::WriteAllText($specPath, $json + "`n",
                [Text.UTF8Encoding]::new($false))

            # Prove it: rebuild from the written spec and compare bytes.
            $tmp = Join-Path ([IO.Path]::GetTempPath()) (
                'rnp-roundtrip-' + [guid]::NewGuid().ToString('N'))
            try {
                $null = & $builder -LiteralPath $specPath -OutputDirectory $tmp `
                    2>&1
                $rebuilt = Join-Path $tmp $fileName
                $same = (Test-Path -LiteralPath $rebuilt) -and
                    ((Get-FileHash -LiteralPath $rebuilt).Hash -eq
                     (Get-FileHash -LiteralPath $path).Hash)
                if (-not $same) {
                    $reason = 'the rebuilt preset differs from the original'
                }
            }
            finally {
                Remove-Item -LiteralPath $tmp -Recurse -Force `
                    -ErrorAction SilentlyContinue
            }
            if ($reason) { Remove-Item -LiteralPath $specPath -Force }
        }
        if ($reason) {
            $notLossless++
            $specPath = $null
            Write-Error ("Cannot decode '$fileName' losslessly: $reason. " +
                'No spec was written; the explanation still was.') `
                -ErrorAction Continue
        }

        # EXPLANATION ──────────────────────────────────────────────────────────
        $md = [Text.StringBuilder]::new()
        [void]$md.AppendLine("# $baseName")
        [void]$md.AppendLine()
        $what = switch ($variant) {
            'FILE' {
                'renames exactly the files and folders you pass to it, ' +
                'never what is inside the folders'
            }
            'CONTENTS' {
                'renames what is inside the folders you pass to it, ' +
                'including subfolders'
            }
            default {
                'has no FILE/CONTENTS prefix, so what it renames depends on ' +
                'its [Filters] block'
            }
        }
        $active = @($rules | Where-Object { $_.Marked -ne '0' }).Count
        [void]$md.AppendLine(
            "``$fileName`` $what. It has $($rules.Count) rule(s), " +
            "$active active, applied top to bottom: each rule works on the " +
            'result of the one before.')
        [void]$md.AppendLine()

        [void]$md.AppendLine('## Filters')
        [void]$md.AppendLine()
        if ($null -eq $preset.Filters) {
            [void]$md.AppendLine(
                'No [Filters] block: ReNamer keeps whatever filter settings ' +
                'the GUI last used, so results can differ between runs.')
        }
        else {
            $f = $preset.Filters
            $bits = @(
                ($f['AddFilesFromFolders'] -eq '1') ?
                    'files inside passed folders are added' : $null
                ($f['AddFoldersAsFiles'] -eq '1') ?
                    'passed folders are renamed themselves' : $null
                ($f['IncludeSubfolders'] -eq '1') ?
                    'subfolders are scanned' : $null
                ($f['Masks']) ? "only names matching ``$($f['Masks'])``" : $null
                ($f['MasksExclude']) ?
                    "except ``$($f['MasksExclude'])``" : $null
            ) | Where-Object { $_ }
            $line = $bits ? ($bits -join '; ') : 'default settings'
            [void]$md.AppendLine(
                $line.Substring(0, 1).ToUpper() + $line.Substring(1) + '.')
        }
        [void]$md.AppendLine()

        [void]$md.AppendLine('## Rules')
        [void]$md.AppendLine()
        foreach ($r in $rules) {
            $sentence = & $describe $r
            $off = ($r.Marked -eq '0') ? ' *(disabled)*' : ''
            $cmt = ($r.Comment) ? " — *$($r.Comment)*" : ''
            [void]$md.AppendLine(
                "$($r.Index + 1). **$($r.ID)**$off$cmt  ")
            [void]$md.AppendLine("   $sentence")
        }
        [void]$md.AppendLine()

        # Validator findings, Legacy profile, most important first.
        $findings = @(& $validator -LiteralPath $path -Profile Legacy |
            Where-Object Level -ne 'Info' | Sort-Object Level, Check)
        [void]$md.AppendLine('## Notes')
        [void]$md.AppendLine()
        if ($reason) {
            [void]$md.AppendLine(
                "- Not decodable losslessly ($reason); edit it in the GUI " +
                'or rebuild it from a fresh spec.')
        }
        # @() keeps .Count meaningful for zero or one group.
        $grouped = @($findings | Group-Object Check, Message)
        foreach ($grp in ($grouped | Select-Object -First 15)) {
            $first = $grp.Group[0]
            $rulesHit = @($grp.Group | Where-Object { $null -ne $_.Rule } |
                ForEach-Object { $_.Rule + 1 } | Sort-Object)
            $where = $rulesHit ? " (rule $($rulesHit -join ', '))" : ''
            [void]$md.AppendLine(
                "- $($first.Level), check $($first.Check)${where}: " +
                "$($first.Message)")
        }
        if ($grouped.Count -gt 15) {
            [void]$md.AppendLine("- … and $($grouped.Count - 15) more.")
        }
        if (-not $findings -and -not $reason) {
            [void]$md.AppendLine('- No validator findings.')
        }

        $explanation = $md.ToString()
        $mdPath = Join-Path $outDir "$baseName.md"
        [IO.File]::WriteAllText($mdPath, $explanation,
            [Text.UTF8Encoding]::new($false))

        [pscustomobject]@{
            Path         = $path
            SpecPath     = $specPath
            MarkdownPath = $mdPath
            RuleCount    = $rules.Count
            Lossless     = -not $reason
            Reason       = $reason
            Explanation  = $explanation
        }
    }
}

end {
    exit ($notLossless ? 1 : 0)
}
