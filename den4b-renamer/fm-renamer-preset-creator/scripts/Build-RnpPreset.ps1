#Requires -Version 7.4
<#
.SYNOPSIS
    Builds den4b ReNamer presets (.rnp) from a preset-spec JSON file.

.DESCRIPTION
    Turns a preset-spec (references/preset-spec.md) into one .rnp file per
    variant (FILE and/or CONTENTS), byte-for-byte in the format ReNamer 7.10
    saves. The build runs in this order:

      1. Validate the spec and resolve every user rule against the verified
         rule catalog: canonical key order, defaults for omitted keys, an
         error for missing required keys, unknown keys, bad types or legacy
         enum values.
      2. Insert the CamelCase rejoin Replace (and the optional digit-capital
         repair RegEx) right after the first CleanUp split rule.
      3. Append the casing tail for casing.mode, with dictionary fragments
         selected, deduped and sorted per casing.md §2.
      4. Append the standard extension-lowercase Case rule only when the
         lowercase-extension guarantee (casing.md §1) is not already met.
      5. Append the collision serializer (last rule, [fm-collision] marker)
         unless -SkipCollisionRule removes a GUI-only one for harness runs.
      6. Encode values, number sections from 0, add the variant's [Filters]
         block (plus mask overrides) and write UTF-8 without BOM, CRLF.

    casing.mode 'verbatim' skips steps 2-5 and writes rules, key order,
    Marked/Comment presence and filters exactly as given; ConvertFrom-Rnp.ps1
    produces such specs, and rebuilding them is byte-identical. A rule with
    "strict": true in a verbatim spec (new or changed in the modify flow) is
    still resolved and checked like a normal rule.

    The spec is checked strictly: unknown keys anywhere (spec, casing,
    rules, tests), tests without an assertion and invalid values fail the
    build with a message naming the problem.

    The same spec always produces byte-identical output.

.PARAMETER LiteralPath
    Path to one or more preset-spec JSON files.

.PARAMETER SpecJson
    A preset-spec as a JSON string, instead of a file.

.PARAMETER OutputDirectory
    Folder to write the .rnp files to. Defaults to StagingDir from
    config.json (%TEMP%\rnp-staging). Never point this at the live Presets
    folder: deliver from staging after validation.

.PARAMETER SkipCollisionRule
    Omit a GUI-only collision serializer (nopad/pad2/pad3/pad4). Used for
    harness runs, because those scripts need two GUI previews. The CLI-safe
    'stock' serializer is always kept.

.INPUTS
    System.String[]
    Pipe spec file paths or FileInfo objects.

.OUTPUTS
    System.Management.Automation.PSCustomObject
    One object per written preset: Name, Variant, Path, RuleCount,
    DictionaryTerms, FragmentsBytes, Collision, StrictRules (1-based numbers
    of rules marked "strict" in a verbatim spec; pass them to
    Test-RnpPreset.ps1 -StrictRules), Warnings.

.EXAMPLE
    ./Build-RnpPreset.ps1 -LiteralPath .\remove-envato-timestamp.json
    Builds FILE and CONTENTS presets into %TEMP%\rnp-staging.

.EXAMPLE
    Get-ChildItem .\specs\*.json | ./Build-RnpPreset.ps1 -OutputDirectory .\out
    Builds several specs from the pipeline into .\out.

.EXAMPLE
    ./Build-RnpPreset.ps1 .\t14.json -SkipCollisionRule -OutputDirectory $h
    Builds the harness copy of a preset whose serializer is GUI-only.

.NOTES
    Requires scripts\RnpCommon.psm1 plus the data, assets and config.json of
    the fm-renamer-preset-creator skill. Exits with code 1 when any spec
    fails to build.

.LINK
    https://github.com/futuremotiondev

.LINK
    Test-RnpPreset.ps1

.LINK
    ConvertFrom-Rnp.ps1
#>
[CmdletBinding(DefaultParameterSetName = 'Path')]
[OutputType([pscustomobject])]
param(
    [Parameter(
        Mandatory, Position = 0, ValueFromPipeline,
        ValueFromPipelineByPropertyName, ParameterSetName = 'Path',
        HelpMessage = 'Literal path to one or more preset-spec JSON files.'
    )]
    [Alias('PSPath')]
    [ValidateNotNullOrEmpty()]
    [String[]] $LiteralPath,

    [Parameter(Mandatory, ParameterSetName = 'Json')]
    [ValidateNotNullOrEmpty()]
    [String] $SpecJson,

    [String] $OutputDirectory,

    [Switch] $SkipCollisionRule
)

begin {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    Import-Module (Join-Path $PSScriptRoot 'RnpCommon.psm1') -Force

    $catalog = Get-RnpRuleCatalog
    $skillRoot = Get-RnpSkillRoot
    $config = Get-RnpConfig
    $failures = 0

    $validModes = 'none', 'preserve', 'title', 'sentence', 'lower', 'upper',
                  'kebab', 'snake', 'verbatim'
    $collisionAssets = @{
        nopad = 'serialize-duplicates-nopad.pas'
        pad2  = 'serialize-duplicates-pad2.pas'
        pad3  = 'serialize-duplicates-pad3.pas'
        pad4  = 'serialize-duplicates-pad4.pas'
        stock = 'serialize-duplicates-stock.pas'
    }
    $collisionComments = @{
        nopad = 'Serialize duplicates: Name 1, Name 2 (GUI only, preview ' +
                'twice) [fm-collision]'
        pad2  = 'Serialize duplicates: Name 01, Name 02 (GUI only, preview ' +
                'twice) [fm-collision]'
        pad3  = 'Serialize duplicates: Name 001, Name 002 (GUI only, ' +
                'preview twice) [fm-collision]'
        pad4  = 'Serialize duplicates: Name 0001, Name 0002 (GUI only, ' +
                'preview twice) [fm-collision]'
        stock = 'Serialize duplicates: Name (2), Name (3) (CLI-safe) ' +
                '[fm-collision]'
    }

    # KNOWN SPEC KEYS ──────────────────────────────────────────────────────────
    # A misspelt key ('colisions') would otherwise fall back to its default
    # without a word, so every object in the spec is checked against these.
    $knownKeys = @{
        spec       = 'name', 'variants', 'filters', 'casing', 'camelCaseRejoin',
                     'collisions', 'rules', 'tests', 'outputFileName',
                     'acceptance', 'referenceRules', 'description', '$schema'
        casing     = 'mode', 'dictionary', 'preserveCase', 'lastWordRule'
        dictionary = 'sources', 'tiers', 'optInPacks', 'reviewTerms',
                     'extraTerms'
        rejoin     = 'enabled', 'includeReview', 'repairDigitCapitals'
        rule       = 'id', 'comment', 'marked', 'config', 'sourceFile',
                     'strict'
        test       = 'name', 'variant', 'files', 'inputs', 'expect',
                     'expectExit', 'in', 'out'
    }
    $assertKeys = {
        param([Collections.IDictionary] $Object, [string] $Kind,
              [string] $Where)
        if ($null -eq $Object) { return }
        foreach ($k in $Object.Keys) {
            if ($k -cnotin $knownKeys[$Kind]) {
                throw "${Where}: unknown key '$k'. Valid keys: " +
                      "$($knownKeys[$Kind] -join ', ')."
            }
        }
    }

    # VALUE NORMALIZATION ──────────────────────────────────────────────────────
    # JSON gives booleans, integers and strings; ReNamer stores text. true and
    # false map to 1 and 0 so specs can use either style.
    $toText = {
        param($Value)
        if ($null -eq $Value) { return '' }
        if ($Value -is [bool]) { return ($Value ? '1' : '0') }
        return [string]$Value
    }

    # RULE FACTORY ─────────────────────────────────────────────────────────────
    # Resolves one rule against the catalog. Normal mode fills defaults in
    # canonical order and type-checks; verbatim mode keeps keys as given.
    $newRule = {
        param(
            [string] $Id,
            [Collections.IDictionary] $Config,
            [AllowNull()] $Comment,
            [AllowNull()] $Marked = 1,
            [bool] $Verbatim = $false,
            [string] $Where = 'rule'
        )
        # ReNamer silently skips an unknown ID when it loads a preset, and
        # IDs are case-sensitive, so 'regex' must fail here, not at run time.
        if ($Id -cnotin @($catalog.Keys)) {
            throw "${Where}: unknown rule ID '$Id'. Valid IDs (case-" +
                  "sensitive): $($catalog.Keys -join ', ')."
        }
        $entry = $catalog[$Id]
        $cfg = [ordered]@{}
        $Config = $Config ?? [ordered]@{}

        # LIST VALUES ──────────────────────────────────────────────────────────
        # Mapping SOURCE/TARGET and User Input INPUT also accept a JSON array
        # of rows/lines. ReNamer stores Mapping rows joined with '|' and User
        # Input lines joined with a bare CR (CRLF or LF is refused).
        if (-not $Verbatim) {
            $conv = [ordered]@{}
            foreach ($k in $Config.Keys) {
                $v = $Config[$k]
                $isMapRows = $Id -ceq 'Mapping' -and $k -cin 'SOURCE', 'TARGET'
                $isLines = $Id -ceq 'UserInput' -and $k -ceq 'INPUT'
                if ($v -is [array]) {
                    $items = @($v | ForEach-Object { [string]$_ })
                    if ($isMapRows) {
                        if (@($items | Where-Object {
                                $_ -match '[|\r\n]' }).Count) {
                            throw "${Where} ($Id): a $k row contains '|' or " +
                                  'a line break.'
                        }
                        $v = $items -join '|'
                    }
                    elseif ($isLines) { $v = $items -join "`r" }
                    else { throw "${Where} ($Id): $k does not take a list." }
                }
                elseif ($isLines -and $v -is [string]) {
                    $v = $v -replace "`r`n|`n", "`r"
                }
                $conv[$k] = $v
            }
            $Config = $conv
        }

        if (-not $Verbatim -and $null -ne $Marked -and
            (& $toText $Marked) -notin '0', '1') {
            throw "${Where} ($Id): marked must be 0 or 1, got '$Marked'."
        }
        if ($Verbatim) {
            foreach ($k in $Config.Keys) { $cfg[$k] = & $toText $Config[$k] }
        }
        else {
            foreach ($k in $Config.Keys) {
                if ($k -cne $k.ToUpperInvariant()) {
                    throw "${Where} ($Id): key '$k' must be UPPERCASE."
                }
                if (-not $entry.Defaults.Contains($k)) {
                    throw "${Where} ($Id): unknown key '$k'. Valid keys: " +
                          "$($entry.Defaults.Keys -join ', ')."
                }
            }
            foreach ($k in $entry.Defaults.Keys) {
                if ($Config.Contains($k)) {
                    $cfg[$k] = & $toText $Config[$k]
                }
                elseif ($k -in $entry.Required) {
                    throw "${Where} ($Id): required key '$k' is missing."
                }
                else { $cfg[$k] = $entry.Defaults[$k] }
            }

            # TYPE AND ENUM CHECKS ─────────────────────────────────────────────
            foreach ($k in $entry.Bool) {
                if ($cfg[$k] -notin '0', '1') {
                    throw "${Where} ($Id): $k must be 0 or 1, got " +
                          "'$($cfg[$k])'."
                }
            }
            foreach ($k in $entry.Int) {
                if ($cfg[$k] -notmatch '^-?\d+$') {
                    throw "${Where} ($Id): $k must be an integer, got " +
                          "'$($cfg[$k])'."
                }
            }
            if ($Id -ceq 'Mapping') {
                # Fewer TARGET rows rename unmatched files to an EMPTY name
                # (verified), so row counts must match and rows be non-empty.
                $src = @($cfg['SOURCE'] -split '\|')
                $dst = @($cfg['TARGET'] -split '\|')
                if ($src.Count -ne $dst.Count) {
                    throw "${Where} ($Id): $($src.Count) SOURCE rows but " +
                          "$($dst.Count) TARGET rows."
                }
                if (@($src + $dst | Where-Object { $_ -eq '' }).Count) {
                    throw "${Where} ($Id): empty SOURCE or TARGET row."
                }
                if ("$($cfg['SOURCE'])$($cfg['TARGET'])" -match '[\r\n]') {
                    throw "${Where} ($Id): rows are separated by '|', not " +
                          'line breaks.'
                }
            }
            foreach ($k in $entry.Enum.Keys) {
                $e = $entry.Enum[$k]
                $v = $cfg[$k]
                $isLegacy = $e.Contains('Legacy') -and
                            $v -in @($e.Legacy | ForEach-Object { "$_" })
                if ($isLegacy) {
                    throw "${Where} ($Id): $k=$v is a legacy value; never " +
                          'emit it (rnp-format.md section 3).'
                }
                if ($v -notin @($e.Allowed | ForEach-Object { "$_" })) {
                    throw "${Where} ($Id): $k=$v is not valid. Allowed: " +
                          "$($e.Allowed -join ', ')."
                }
            }
        }
        [pscustomobject]@{
            ID      = $Id
            Config  = $cfg
            Marked  = if ($null -eq $Marked) { $null } else { & $toText $Marked }
            Comment = $Comment
        }
    }

    # STANDARD RULES ───────────────────────────────────────────────────────────
    # Short helpers for the rules the builder appends itself.
    $caseRule = {
        param([int] $What, [int] $Preserve, [string] $Fragments,
              [string] $Comment)
        & $newRule -Id 'Case' -Comment $Comment -Where 'casing tail' -Config (
            [ordered]@{
                WHAT          = $What
                PRESERVECASE  = $Preserve
                FORCECASE     = ($Fragments ? 1 : 0)
                FRAGMENTSTEXT = $Fragments
            })
    }
    $regexRule = {
        param([string] $Expression, [string] $Replace, [string] $Comment)
        & $newRule -Id 'RegEx' -Comment $Comment -Where 'casing tail' -Config (
            [ordered]@{
                EXPRESSION    = $Expression
                REPLACE       = $Replace
                CASESENSITIVE = 1
                SKIPEXTENSION = 1
            })
    }
}

process {
    # One spec per iteration: from files, or the single -SpecJson string.
    $sources = if ($PSCmdlet.ParameterSetName -eq 'Json') {
        @([pscustomobject]@{
            Label = '<SpecJson>'; Json = $SpecJson; Base = (Get-Location).Path
        })
    } else {
        foreach ($p in $LiteralPath) {
            [pscustomobject]@{
                Label = $p
                Json  = Get-Content -LiteralPath $p -Raw -Encoding utf8
                Base  = Split-Path -Parent (Convert-Path -LiteralPath $p)
            }
        }
    }

    foreach ($source in $sources) {
        try {
            # LOAD AND VALIDATE THE SPEC ───────────────────────────────────────
            # ConvertFrom-RnpJson keeps ISO date-like strings as strings.
            $spec = ConvertFrom-RnpJson $source.Json
            if ($spec -isnot [Collections.IDictionary]) {
                throw 'the spec must be a JSON object.'
            }
            $warnings = [Collections.Generic.List[string]]::new()
            & $assertKeys $spec 'spec' 'spec'
            # "casing": "title" is shorthand for { "mode": "title" }.
            $casing = $spec['casing'] ?? @{}
            if ($casing -is [string]) { $casing = @{ mode = $casing } }
            if ($casing -isnot [Collections.IDictionary]) {
                throw 'casing must be an object like { "mode": "title" }.'
            }
            & $assertKeys $casing 'casing' 'casing'
            & $assertKeys $casing['dictionary'] 'dictionary' 'casing.dictionary'
            & $assertKeys $spec['camelCaseRejoin'] 'rejoin' 'camelCaseRejoin'
            $mode = $casing['mode'] ?? 'preserve'
            if ($mode -notin $validModes) {
                throw "casing.mode '$mode' is not one of: $($validModes -join ', ')."
            }
            $verbatim = $mode -eq 'verbatim'
            if ($casing.Contains('dictionary') -and
                $mode -notin 'preserve', 'title', 'sentence') {
                $warnings.Add("casing.dictionary is ignored in mode '$mode'.")
            }
            foreach ($k in 'preserveCase', 'lastWordRule') {
                if ($casing.Contains($k) -and $mode -ne 'title') {
                    $warnings.Add("casing.$k only applies to mode 'title'.")
                }
            }
            # TESTS ────────────────────────────────────────────────────────────
            # The harness runs them; a misspelt key ('expected') would turn a
            # test into an assertion-free INFO case, so check them here.
            $n = 0
            foreach ($t in @($spec['tests'] ?? @())) {
                $n++
                if ($t -isnot [Collections.IDictionary]) {
                    throw "tests[$n] must be an object."
                }
                & $assertKeys $t 'test' "tests[$n]"
                $short = $t.Contains('in') -or $t.Contains('out')
                if ($short -and -not ($t.Contains('in') -and $t.Contains('out'))) {
                    throw "tests[${n}]: shorthand needs both 'in' and 'out'."
                }
                if ($short -and ($t.Contains('files') -or $t.Contains('expect'))) {
                    throw "tests[${n}]: use either in/out or files/expect."
                }
                if (-not $short -and -not $t.Contains('files')) {
                    throw "tests[${n}]: 'files' is missing."
                }
                if (-not $short -and -not $t.Contains('expect') -and
                    -not $t.Contains('expectExit')) {
                    throw "tests[${n}]: needs 'expect' and/or 'expectExit'."
                }
                if ($t.Contains('variant') -and $t['variant'] -cnotin
                        @($spec['variants'] ?? @())) {
                    throw "tests[${n}]: variant '$($t['variant'])' is not " +
                          'in variants.'
                }
            }

            $collision = $spec['collisions'] ?? 'none'
            if ($collision -ne 'none' -and
                -not $collisionAssets.ContainsKey($collision)) {
                throw "collisions '$collision' must be none, nopad, pad2, " +
                      'pad3, pad4 or stock.'
            }
            $rejoin = $spec['camelCaseRejoin'] ?? @{}
            if ($verbatim -and
                ($collision -ne 'none' -or ($rejoin['enabled'] ?? $false))) {
                throw 'verbatim mode cannot add collision or rejoin rules.'
            }

            $outputName = $spec['outputFileName']
            $variants = @($spec['variants'] ?? @())
            if ($outputName) {
                if ($outputName -notmatch '\.rnp$' -or
                    $outputName -match '[\\/:*?"<>|]') {
                    throw "outputFileName '$outputName' is not a valid " +
                          '.rnp file name.'
                }
                if ($variants.Count -gt 1) {
                    throw 'outputFileName allows at most one variant.'
                }
            } else {
                $name = [string]$spec['name']
                if ([string]::IsNullOrWhiteSpace($name) -or
                    $name -match '[\\/:*?"<>|]' -or
                    $name -match '[. ]$') {
                    throw "name '$name' is empty or not a valid file name."
                }
                if (-not $variants.Count) {
                    throw 'variants must list FILE and/or CONTENTS.'
                }
            }
            foreach ($v in $variants) {
                if ($v -cnotin 'FILE', 'CONTENTS') {
                    throw "variants: '$v' must be FILE or CONTENTS."
                }
            }
            if (@($variants | Sort-Object -Unique).Count -ne $variants.Count) {
                throw 'variants contains duplicates.'
            }

            # USER RULES ───────────────────────────────────────────────────────
            $rules = [Collections.Generic.List[object]]::new()
            $strictNumbers = [Collections.Generic.List[int]]::new()
            $i = 0
            foreach ($r in @($spec['rules'] ?? @())) {
                $i++
                & $assertKeys $r 'rule' "rules[$i]"
                # Verbatim keeps absent/null Marked and Comment (legacy
                # presets); normal mode always writes both lines. A rule with
                # "strict": true inside a verbatim spec (a new or changed rule
                # in the modify flow) is resolved like normal mode: defaults,
                # canonical order and type checks.
                $strictRule = [bool]($r['strict'] ?? $false)
                if ($strictRule -and -not $verbatim) {
                    $warnings.Add("rules[$i]: 'strict' only matters in " +
                                  'verbatim specs; every rule is strict here.')
                }
                $asVerbatim = $verbatim -and -not $strictRule
                if ($strictRule -and $verbatim) { $strictNumbers.Add($i) }
                $marked = $r.Contains('marked') ? $r['marked'] : 1
                $comment = $r.Contains('comment') ? $r['comment'] : $null
                if (-not $asVerbatim) {
                    $marked = $marked ?? 1
                    $comment = [string]$comment
                }
                # PASCAL SOURCE FILE ───────────────────────────────────────────
                # 'sourceFile' embeds a .pas file (relative to the spec's
                # folder) as SOURCEUTF8: BOM stripped, CRLF line endings.
                # Writing Pascal into a JSON string by hand is error-prone.
                $cfgIn = $r['config']
                if ($r['sourceFile']) {
                    if ($r['id'] -cne 'PascalScript') {
                        throw "rules[$i]: sourceFile is only valid for " +
                              'PascalScript rules.'
                    }
                    if ($cfgIn -and $cfgIn.Contains('SOURCEUTF8')) {
                        throw "rules[$i]: give sourceFile or SOURCEUTF8, " +
                              'not both.'
                    }
                    $pas = [IO.Path]::IsPathRooted($r['sourceFile']) ?
                        $r['sourceFile'] :
                        [IO.Path]::Combine($source.Base, $r['sourceFile'])
                    $code = [IO.File]::ReadAllText($pas).TrimStart(
                        [char]0xFEFF) -replace '\r?\n', "`r`n"
                    $cfgIn = [ordered]@{ SOURCEUTF8 = $code }
                }
                $rules.Add((& $newRule -Id $r['id'] -Config $cfgIn `
                    -Comment $comment -Marked $marked -Verbatim $asVerbatim `
                    -Where "rules[$i]"))
            }

            $termCount = 0
            if (-not $verbatim) {
                # CAMELCASE REJOIN (casing.md §5) ──────────────────────────────
                if ($rejoin['enabled'] ?? $false) {
                    $split = -1
                    for ($j = 0; $j -lt $rules.Count; $j++) {
                        $cu = $rules[$j]
                        if ($cu.ID -eq 'CleanUp' -and
                            $cu.Config['INSERTSPACEBEFORECAPITALS'] -eq '1') {
                            $split = $j; break
                        }
                    }
                    if ($split -lt 0) {
                        throw 'camelCaseRejoin needs a user CleanUp rule ' +
                              'with INSERTSPACEBEFORECAPITALS=1.'
                    }
                    $pairs = Get-RnpRejoinPairs -IncludeReview @(
                        $rejoin['includeReview'] ?? @())
                    $replace = & $newRule -Id 'Replace' -Where 'rejoin' `
                        -Comment ("Rejoin brand terms split by CamelCase " +
                                  "($($pairs.Count) pairs)") -Config (
                        [ordered]@{
                            TEXTWHAT       = ($pairs.Split -join '*|*')
                            TEXTWITH       = ($pairs.Term -join '*|*')
                            WHICH          = 3
                            CASESENSITIVE  = 1
                            WHOLEWORDSONLY = 1
                        })
                    $rules.Insert($split + 1, $replace)
                    if ($rejoin['repairDigitCapitals'] ?? $false) {
                        $rules.Insert($split + 2, (& $regexRule `
                            '(\p{L}\d+) (\p{Lu})(?=\s|$)' '$1$2' `
                            ('Rejoin a lone capital split off ' +
                             'letters+digits (3D, 4K)')))
                    }
                    $packs = @(($casing['dictionary'] ?? @{})['optInPacks'] ??
                        @())
                    if ($packs) {
                        $warnings.Add(
                            'Opt-in packs (' + ($packs -join ', ') + ') have ' +
                            'no CamelCase rejoin pairs: their CamelCase terms ' +
                            'stay split (casing.md §5).')
                    }
                    $warnings.Add(
                        'CamelCase rejoin does not handle a brand glued to ' +
                        'digits (iPhone15Pro) or to a lowercase word ' +
                        '(BackupToiCloud); see casing.md §5.')
                }

                # CASING TAIL (casing.md §3) ───────────────────────────────────
                $dict = Get-RnpDictionarySelection -Mode $mode `
                    -Dictionary $casing['dictionary']
                $termCount = $dict.TermCount
                foreach ($w in $dict.Warnings) { $warnings.Add($w) }
                $frag = $dict.FragmentsText
                switch ($mode) {
                    'preserve' {
                        $rules.Add((& $caseRule 0 1 $frag (
                            "Fix brand casing, keep everything else " +
                            "($termCount dictionary terms)")))
                    }
                    'sentence' {
                        $rules.Add((& $caseRule 7 0 $frag (
                            "Sentence case + dictionary ($termCount terms)")))
                    }
                    'title' {
                        $keep = ($casing['preserveCase'] ?? $true) ? 1 : 0
                        $rules.Add((& $caseRule 3 $keep $frag (
                            "APA title case + dictionary ($termCount terms)")))
                        $lc = $dict.LowercaseAlternation
                        $guard = $lc ? "(?!(?:$lc)\b)" : ''
                        $rules.Add((& $regexRule "^$guard(\p{Ll})" '\U$1' `
                            'APA: capitalize first word'))
                        $rules.Add((& $regexRule `
                            "( - | – | — )$guard(\p{Ll})" '$1\U$2' `
                            'APA: capitalize first word of subtitle'))
                        if ($casing['lastWordRule'] ?? $true) {
                            $rules.Add((& $regexRule `
                                "(\s)$guard(\p{Ll})(\p{L}*)$" '$1\U$2$3' `
                                'Capitalize last word (house rule, not APA)'))
                        }
                    }
                    'lower' {
                        $rules.Add((& $caseRule 1 0 '' 'All lower case'))
                    }
                    'upper' {
                        $rules.Add((& $caseRule 2 0 '' (
                            'ALL UPPER CASE (extension stays lower case)')))
                    }
                    { $_ -in 'kebab', 'snake' } {
                        $joiner = ($mode -eq 'kebab') ? '-' : '_'
                        $rules.Add((& $newRule -Id 'CleanUp' -Where 'tail' `
                            -Comment 'Separators to spaces, collapse spaces' `
                            -Config ([ordered]@{
                                SPACESUNDERSCORE = 1
                                SPACESHYPHEN     = 1
                                SPACESWEB        = 1
                                SPACESFIX        = 1
                            })))
                        $rules.Add((& $caseRule 1 0 '' 'Lower case'))
                        $rules.Add((& $newRule -Id 'Replace' -Where 'tail' `
                            -Comment "Spaces to '$joiner'" -Config (
                                [ordered]@{
                                    TEXTWHAT = ' '
                                    TEXTWITH = $joiner
                                    WHICH    = 3
                                })))
                    }
                }

                # LOWERCASE-EXTENSION GUARANTEE (casing.md §1) ─────────────────
                # Satisfied when the last marked Case rule lowercases the
                # extension and every later marked rule has SKIPEXTENSION=1.
                $lastCase = -1
                for ($j = 0; $j -lt $rules.Count; $j++) {
                    if ($rules[$j].ID -eq 'Case' -and
                        $rules[$j].Marked -ne '0') { $lastCase = $j }
                }
                $ok = $lastCase -ge 0 -and
                    $rules[$lastCase].Config['EXTENSIONALWAYSLOWERCASE'] -eq
                        '1' -and
                    $rules[$lastCase].Config['EXTENSIONALWAYSUPPERCASE'] -eq
                        '0'
                if ($ok) {
                    for ($j = $lastCase + 1; $j -lt $rules.Count; $j++) {
                        $after = $rules[$j]
                        if ($after.Marked -eq '0') { continue }
                        if (-not $after.Config.Contains('SKIPEXTENSION') -or
                            $after.Config['SKIPEXTENSION'] -ne '1') {
                            $ok = $false; break
                        }
                    }
                }
                if (-not $ok) {
                    $rules.Add((& $caseRule 0 0 '' 'Extension always lower case'))
                }

                # COLLISION SERIALIZER (always the last rule) ──────────────────
                if ($collision -ne 'none') {
                    $guiOnly = $collision -ne 'stock'
                    if ($guiOnly) {
                        $warnings.Add(
                            'Collision serializer is GUI-only: preview twice ' +
                            'in ReNamer, never from /silent or a context-' +
                            'menu rename.')
                    }
                    if (-not ($guiOnly -and $SkipCollisionRule)) {
                        $asset = Join-Path $skillRoot 'assets' 'pascal' `
                            $collisionAssets[$collision]
                        $src = [IO.File]::ReadAllText($asset).TrimStart(
                            [char]0xFEFF)
                        $src = $src -replace '\r?\n', "`r`n"
                        $rules.Add((& $newRule -Id 'PascalScript' `
                            -Where 'collisions' `
                            -Comment $collisionComments[$collision] `
                            -Config ([ordered]@{ SOURCEUTF8 = $src })))
                    }
                }
            }

            foreach ($r in $rules) {
                if ($r.ID -in 'Serialize', 'UserInput' -and $r.Marked -ne '0') {
                    $warnings.Add(
                        "$($r.ID) numbers or names files in file-table " +
                        'order; the result depends on the sort order.')
                    break
                }
            }

            # WRITE ONE PRESET PER VARIANT ─────────────────────────────────────
            # Resolve against the PowerShell location, not the process
            # directory, so relative paths work after Set-Location.
            $outDir = $PSCmdlet.GetUnresolvedProviderPathFromPSPath(
                ($OutputDirectory ? $OutputDirectory : $config.StagingDir))
            New-Item -ItemType Directory -Force -Path $outDir | Out-Null
            $targets = if ($outputName) {
                @([pscustomobject]@{
                    Variant = ($variants ? $variants[0] : $null)
                    File    = $outputName })
            } else {
                foreach ($v in $variants) {
                    [pscustomobject]@{ Variant = $v; File = "$v $name.rnp" }
                }
            }

            foreach ($t in $targets) {
                $filters = $null
                if ($verbatim) {
                    if ($null -ne $spec['filters']) {
                        $filters = [ordered]@{}
                        foreach ($k in $spec['filters'].Keys) {
                            $filters[$k] = & $toText $spec['filters'][$k]
                        }
                    }
                } elseif ($t.Variant) {
                    $filters = Get-RnpFiltersBlock $t.Variant
                    $over = $spec['filters'] ?? @{}
                    foreach ($k in $over.Keys) {
                        if (-not $filters.Contains($k)) {
                            throw "filters: unknown key '$k'. Valid keys: " +
                                  "$($filters.Keys -join ', ')."
                        }
                        $val = & $toText $over[$k]
                        if ($k -like 'Masks*' -and $val -match '%[0-9A-Fa-f]{2}') {
                            throw "filters.${k}: masks are raw text, never " +
                                  "percent-encoded ('$val')."
                        }
                        $filters[$k] = $val
                    }
                }

                $text = Write-RnpPresetText -Rules $rules.ToArray() `
                    -Filters $filters
                $path = Join-Path $outDir $t.File
                [IO.File]::WriteAllText($path, $text,
                    [Text.UTF8Encoding]::new($false))

                $fragBytes = 0
                foreach ($r in $rules) {
                    if ($r.ID -eq 'Case') {
                        $enc = ConvertTo-RnpValue $r.Config['FRAGMENTSTEXT']
                        $fragBytes = [Math]::Max($fragBytes, $enc.Length)
                    }
                }
                [pscustomobject]@{
                    Name            = $outputName ?? "$($t.Variant) $name"
                    Variant         = $t.Variant
                    Path            = $path
                    RuleCount       = $rules.Count
                    DictionaryTerms = $termCount
                    FragmentsBytes  = $fragBytes
                    Collision       = if ($collision -eq 'none') { 'none' }
                        elseif ($collision -ne 'stock' -and
                                $SkipCollisionRule) { "$collision (skipped)" }
                        else { $collision }
                    StrictRules     = $strictNumbers.ToArray()
                    Warnings        = $warnings.ToArray()
                }
            }
        }
        catch {
            $failures++
            $msg = "Build failed for $($source.Label): $($_.Exception.Message)"
            Write-Error $msg -ErrorAction Continue
        }
    }
}

end {
    # Always set an explicit exit code so callers can gate on $LASTEXITCODE.
    exit ($failures ? 1 : 0)
}
