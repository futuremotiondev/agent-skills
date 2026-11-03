#Requires -Version 7.4
<#
    RnpCommon.psm1 - shared engine for the fm-renamer-preset-creator scripts.

    Everything that more than one script needs lives here so the builder,
    validator, decoder and harness can never disagree about the file format:

      * the rule catalog (canonical key order, defaults, required keys,
        value types and enum ranges) - transcribed from
        references/rnp-format.md section 4, which is verified by probes
      * the ReNamer value codec (encode / decode)
      * the .rnp parser and the byte-exact writer
      * the [Filters] blocks, the casing dictionary selection (casing.md §2)
        and the CamelCase rejoin pairs (casing.md §5)

    Import with:  Import-Module (Join-Path $PSScriptRoot 'RnpCommon.psm1')
#>

Set-StrictMode -Version Latest

# REGION - RULE CATALOG
# ──────────────────────────────────────────────────────────────────────────────

# Canonical key order and skill defaults for all 18 rules, exactly as ReNamer
# 7.10 writes them (rnp-format.md section 4). An empty default is either a
# genuinely empty value or a REQUIRED key (listed in $script:RequiredKeys).
$script:RuleTemplates = [ordered]@{
    Insert       = 'TEXT:;WHERE:;POSITION:1;INSERTAFTERTEXT:;' +
                   'INSERTBEFORETEXT:;RIGHTTOLEFT:0;SKIPEXTENSION:1'
    Delete       = 'FROM:1;UNTIL:;FROMPOSITION:1;UNTILCOUNT:1;' +
                   'FROMDELIMITER:;UNTILDELIMITER:;DELETECURRENTNAME:0;' +
                   'RIGHTTOLEFT:0;SKIPEXTENSION:1;LEAVEDELIMITER:0'
    Remove       = 'TEXT:;WHICH:3;SKIPEXTENSION:1;CASESENSITIVE:0;' +
                   'USEWILDCARDS:0;WHOLEWORDSONLY:0'
    Replace      = 'TEXTWHAT:;TEXTWITH:;WHICH:3;SKIPEXTENSION:1;' +
                   'CASESENSITIVE:0;USEWILDCARDS:0;WHOLEWORDSONLY:0'
    Rearrange    = 'DELIMITERTYPE:0;RIGHTTOLEFT:0;DELIMETERS:;NEWPATTERN:;' +
                   'SKIPEXTENSION:1'
    Extension    = 'NEWEXTENSION:1;EXTENSION:;APPEND:0;USEBINSIGN:0;' +
                   'REMOVEDUPLICATES:0;CASESENSITIVE:0'
    Strip        = 'CHECKENGLISHLETTERS:0;CHECKDIGITS:0;CHECKSYMBOLS:0;' +
                   'CHECKBRACKETS:0;CHECKUSERDEFINED:0;CHECKUNICODERANGE:0;' +
                   'TEXTUSERDEFINED:;TEXTUNICODERANGE:;WHERE:0;' +
                   'STRIPALLEXCEPTSELECTED:0;CASESENSITIVE:0;SKIPEXTENSION:1'
    Case         = 'WHAT:0;PRESERVECASE:0;SKIPEXTENSION:1;' +
                   'EXTENSIONALWAYSLOWERCASE:1;EXTENSIONALWAYSUPPERCASE:0;' +
                   'FORCECASE:0;FRAGMENTSTEXT:'
    Serialize    = 'TYPE:1;WHERE:2;POSITION:1;INDEX:1;STEP:1;REPEAT:1;' +
                   'RESETIFFOLDERCHANGES:0;RESETIFFILENAMECHANGES:0;' +
                   'RESETEVERY:0;RESETEVERYCOUNT:1;LENGTH:1;UNIQUE:1;' +
                   'PADTOLENGTH:0;PADTOLENGTHVALUE:1;SKIPEXTENSION:1;' +
                   'NUMERALSYSTEM:1;CUSTOMSYMBOLS:'
    Randomize    = 'LENGTH:8;UNIQUE:1;WHERE:2;POSITION:1;SKIPEXTENSION:1;' +
                   'USEDIGITS:1;USEENGLISHLETTERS:0;USEUSERDEFINED:0;' +
                   'USERDEFINEDCHARS:'
    Padding      = 'NUMBERPADDING:;NUMBERPADDINGLENGTH:2;TEXTPADDING:0;' +
                   'TEXTPADDINGLENGTH:1;TEXTPADDINGPOSITION:1;' +
                   'TEXTPADDINGCHARS:;SKIPEXTENSION:1'
    CleanUp      = 'BRACKETSROUND:0;BRACKETSSQUARE:0;BRACKETSCURVY:0;' +
                   'SPACESDOT:0;SPACESCOMMA:0;SPACESUNDERSCORE:0;' +
                   'SPACESPLUS:0;SPACESHYPHEN:0;SPACESWEB:0;' +
                   'SPACESSKIPVERSIONS:0;SPACESFIX:1;SKIPEXTENSION:1;' +
                   'PREPAREFORSHAREPOINT:0;INSERTSPACEBEFORECAPITALS:0;' +
                   'NORMALIZESPACES:0;STRIPUNICODEMARKS:0;STRIPUNICODEEMOJI:0'
    Translit     = 'ALPHABET:;DIRECTION:1;ADJUSTCASE:1;SKIPEXTENSION:1'
    ReformatDate = 'SOURCEFORMATS:;TARGETFORMAT:;USECUSTOMSHORTMONTHS:0;' +
                   'USECUSTOMLONGMONTHS:0;CUSTOMSHORTMONTHS:;' +
                   'CUSTOMLONGMONTHS:;WHOLEWORDSONLY:1;SKIPEXTENSION:1;' +
                   'ADJUSTTIME:0;ADJUSTTIMEBY:0;ADJUSTTIMEPART:1'
    RegEx        = 'EXPRESSION:;REPLACE:;CASESENSITIVE:0;SKIPEXTENSION:1'
    PascalScript = 'SOURCEUTF8:'
    UserInput    = 'INPUT:;ACTION:0;SKIPEXTENSION:1'
    Mapping      = 'ALLOWREUSE:0;PARTIALMATCH:0;INVERSEMAPPING:0;' +
                   'CASESENSITIVE:0;SKIPEXTENSION:1;SOURCE:;TARGET:'
}

# Keys marked "-" (required) in rnp-format.md section 3. The builder never
# fills these from the template; the preset-spec must state them (an explicit
# empty string is allowed, e.g. RegEx REPLACE).
$script:RequiredKeys = @{
    Insert       = @('TEXT', 'WHERE')
    Delete       = @('UNTIL')
    Remove       = @('TEXT')
    Replace      = @('TEXTWHAT', 'TEXTWITH')
    Rearrange    = @('DELIMETERS', 'NEWPATTERN')
    Extension    = @('EXTENSION')
    Padding      = @('NUMBERPADDING')
    Translit     = @('ALPHABET')
    ReformatDate = @('SOURCEFORMATS', 'TARGETFORMAT')
    RegEx        = @('EXPRESSION', 'REPLACE')
    PascalScript = @('SOURCEUTF8')
    UserInput    = @('INPUT')
    Mapping      = @('SOURCE', 'TARGET')
}

# Integer (non-enum) keys. Every other key whose default is 0/1 is a boolean;
# every key with an empty default is free text.
$script:IntKeys = @{
    Insert       = @('POSITION')
    Delete       = @('FROMPOSITION', 'UNTILCOUNT')
    Serialize    = @('POSITION', 'INDEX', 'STEP', 'REPEAT', 'RESETEVERYCOUNT',
                     'LENGTH', 'PADTOLENGTHVALUE')
    Randomize    = @('LENGTH', 'POSITION')
    Padding      = @('NUMBERPADDINGLENGTH', 'TEXTPADDINGLENGTH')
    ReformatDate = @('ADJUSTTIMEBY')
}

# Enum keys: Allowed values, and Legacy values that ReNamer still reads but
# the skill must never emit (validator check 4).
$script:EnumKeys = @{
    Insert       = @{ WHERE = @{ Allowed = 1, 2, 4, 5, 6, 7; Legacy = 3 } }
    Delete       = @{ FROM  = @{ Allowed = 1, 2 }
                      UNTIL = @{ Allowed = 1, 2, 3 } }
    Remove       = @{ WHICH = @{ Allowed = 1, 2, 3 } }
    Replace      = @{ WHICH = @{ Allowed = 1, 2, 3 } }
    Rearrange    = @{ DELIMITERTYPE = @{ Allowed = 0, 1, 2 } }
    Strip        = @{ WHERE = @{ Allowed = 0, 1, 2 } }
    Case         = @{ WHAT = @{ Allowed = 0, 1, 2, 3, 4, 5, 7; Legacy = 6 } }
    Serialize    = @{ TYPE          = @{ Allowed = 1; Legacy = 2 }
                      WHERE         = @{ Allowed = 1, 2, 4, 7; Legacy = 3 }
                      NUMERALSYSTEM = @{ Allowed = 1..7 } }
    Randomize    = @{ WHERE = @{ Allowed = 1, 2, 4, 7 } }
    Padding      = @{ NUMBERPADDING       = @{ Allowed = 0, 1, 2 }
                      TEXTPADDINGPOSITION = @{ Allowed = 1, 2 } }
    Translit     = @{ DIRECTION = @{ Allowed = 1, 2 } }
    ReformatDate = @{ ADJUSTTIMEPART = @{ Allowed = 1..7; Legacy = 0 } }
    UserInput    = @{ ACTION = @{ Allowed = 0, 1, 2 } }
}

# Parsed catalog cache: ID -> [ordered] key -> default (decoded string).
$script:Catalog = $null

function Get-RnpRuleCatalog {
    <#
    .SYNOPSIS
        Returns the verified rule catalog: key order, defaults and types.

    .DESCRIPTION
        Parses the canonical rule templates once and returns a hashtable keyed
        by rule ID. Each entry holds Defaults (ordered key -> default),
        Required, Int, Bool, Text and Enum metadata. The builder uses it to
        fill defaults in canonical order; the validator uses it for checks
        2-4. The data mirrors references/rnp-format.md section 4.

    .INPUTS
        None.

    .OUTPUTS
        System.Collections.Hashtable
        Rule ID -> PSCustomObject with Defaults, Required, Int, Bool, Text,
        Enum.

    .EXAMPLE
        (Get-RnpRuleCatalog).Case.Defaults
        Lists the Case rule keys with their defaults, in write order.

    .EXAMPLE
        (Get-RnpRuleCatalog).Keys
        Lists the 18 valid rule IDs.

    .EXAMPLE
        (Get-RnpRuleCatalog).Insert.Required
        Returns TEXT and WHERE, the keys a preset-spec must state.

    .NOTES
        Rule IDs are case-sensitive in ReNamer; an unknown ID is silently
        skipped when a preset loads, so callers must reject unknown IDs.

    .LINK
        https://github.com/futuremotiondev

    .LINK
        ConvertTo-RnpValue
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    if ($script:Catalog) { return $script:Catalog }

    $catalog = [ordered]@{}
    foreach ($id in $script:RuleTemplates.Keys) {
        $keys = [ordered]@{}
        foreach ($pair in ($script:RuleTemplates[$id] -split ';')) {
            $kv = $pair -split ':', 2
            $keys[$kv[0]] = $kv[1]
        }
        $required = @($script:RequiredKeys[$id] ?? @())
        $int = @($script:IntKeys[$id] ?? @())
        $enum = $script:EnumKeys[$id] ?? @{}

        # A key is boolean when its default is 0/1 and it is neither an
        # integer, an enum nor a required value; empty defaults are text.
        $bool = @($keys.Keys | Where-Object {
            $keys[$_] -in '0', '1' -and
            $_ -notin $int -and -not $enum.ContainsKey($_)
        })
        $text = @($keys.Keys | Where-Object {
            $_ -notin $bool -and $_ -notin $int -and
            -not $enum.ContainsKey($_)
        })
        $catalog[$id] = [pscustomobject]@{
            Defaults = $keys
            Required = $required
            Int      = $int
            Bool     = $bool
            Text     = $text
            Enum     = $enum
        }
    }
    $script:Catalog = $catalog
    return $catalog
}

# ENDREGION

# REGION - VALUE CODEC
# ──────────────────────────────────────────────────────────────────────────────

function ConvertTo-RnpValue {
    <#
    .SYNOPSIS
        Encodes a raw value the way ReNamer writes Config/Comment values.

    .DESCRIPTION
        Encodes the UTF-8 bytes of Value one by one: A-Z, a-z and 0-9 stay
        literal, a space becomes '+', and every other byte becomes %XX with
        uppercase hex. This reproduces ReNamer's own output byte for byte
        (6,860 of 6,860 values in Futuremotion's 158 presets round-trip).

    .PARAMETER Value
        The raw (decoded) value to encode. Null is treated as empty.

    .INPUTS
        System.String

    .OUTPUTS
        System.String

    .EXAMPLE
        ConvertTo-RnpValue ':File_FolderName: '
        Returns %3AFile%5FFolderName%3A+

    .EXAMPLE
        'a;b', 'c:d' | ConvertTo-RnpValue
        Encodes several values from the pipeline.

    .EXAMPLE
        ConvertTo-RnpValue "line1`r`nline2"
        Returns line1%0D%0Aline2 (multi-line Pascal or Translit text).

    .NOTES
        [Filters] values are NOT encoded; never pass masks through this.

    .LINK
        https://github.com/futuremotiondev

    .LINK
        ConvertFrom-RnpValue
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Position = 0, ValueFromPipeline)]
        [AllowEmptyString()]
        [AllowNull()]
        [String] $Value
    )
    process {
        $sb = [Text.StringBuilder]::new()
        foreach ($b in [Text.Encoding]::UTF8.GetBytes([string]$Value)) {
            $isAlnum = ($b -ge 48 -and $b -le 57) -or
                       ($b -ge 65 -and $b -le 90) -or
                       ($b -ge 97 -and $b -le 122)
            if ($isAlnum) { [void]$sb.Append([char]$b) }
            elseif ($b -eq 32) { [void]$sb.Append('+') }
            else { [void]$sb.Append(('%{0:X2}' -f $b)) }
        }
        $sb.ToString()
    }
}

function ConvertTo-RnpConfigValue {
    <#
    .SYNOPSIS
        Encodes one Config value the way ReNamer writes it for a given rule
        and key, including the Mapping row exception.

    .DESCRIPTION
        Every Config value uses the ConvertTo-RnpValue encoding, with one
        exception verified from GUI-saved presets (calibration C1): the
        Mapping rule's SOURCE and TARGET hold one row per file name, and
        ReNamer encodes each row on its own and joins the rows with a RAW
        '|' (never %7C). An encoded %7C is read as a literal character, so
        'aa%7Cbb' is one row. File names cannot contain '|', so the raw
        separator is unambiguous. Pass the decoded value with rows joined by
        '|' (e.g. 'aa|bb').

        User Input needs no exception: its INPUT lines are joined with a
        bare CR, which the normal encoding writes as %0D.

    .PARAMETER Id
        The rule ID, e.g. Mapping.

    .PARAMETER Key
        The Config key, e.g. SOURCE.

    .PARAMETER Value
        The decoded value.

    .INPUTS
        None.

    .OUTPUTS
        System.String

    .EXAMPLE
        ConvertTo-RnpConfigValue Mapping SOURCE 'a b|c'
        Returns a+b|c

    .EXAMPLE
        ConvertTo-RnpConfigValue Replace TEXTWHAT 'a|b'
        Returns a%7Cb (the normal encoding).

    .EXAMPLE
        ConvertTo-RnpConfigValue UserInput INPUT "new1`rnew2"
        Returns new1%0Dnew2

    .NOTES
        Write-RnpPresetText, the validator (check 5) and the encoder
        round-trip test all use this function.

    .LINK
        https://github.com/futuremotiondev

    .LINK
        ConvertTo-RnpValue
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [String] $Id,

        [Parameter(Mandatory, Position = 1)]
        [String] $Key,

        [Parameter(Position = 2)]
        [AllowEmptyString()]
        [AllowNull()]
        [String] $Value
    )
    if ($Id -ceq 'Mapping' -and $Key -cin 'SOURCE', 'TARGET') {
        return (@(([string]$Value) -split '\|') |
            ForEach-Object { ConvertTo-RnpValue $_ }) -join '|'
    }
    ConvertTo-RnpValue $Value
}

function ConvertFrom-RnpValue {
    <#
    .SYNOPSIS
        Decodes a ReNamer Config/Comment value back to raw text.

    .DESCRIPTION
        Turns '+' into a space and %XX sequences into UTF-8 bytes. The reader
        in ReNamer is lenient (raw punctuation, lowercase hex), and so is this
        function; use (ConvertTo-RnpValue (ConvertFrom-RnpValue $v)) -ceq $v
        to test whether a value was written in canonical form.

    .PARAMETER Value
        The encoded value as it appears after 'KEY:' in a Config line.

    .INPUTS
        System.String

    .OUTPUTS
        System.String

    .EXAMPLE
        ConvertFrom-RnpValue '%3AFile%5FFolderName%3A+'
        Returns ':File_FolderName: '

    .EXAMPLE
        'a%3Bb' | ConvertFrom-RnpValue
        Returns 'a;b'.

    .EXAMPLE
        ConvertFrom-RnpValue 'Prefix+with+parent+folder+name'
        Decodes a rule comment.

    .NOTES
        Uses [Uri]::UnescapeDataString, which leaves malformed escapes as-is.

    .LINK
        https://github.com/futuremotiondev

    .LINK
        ConvertTo-RnpValue
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Position = 0, ValueFromPipeline)]
        [AllowEmptyString()]
        [AllowNull()]
        [String] $Value
    )
    process {
        [Uri]::UnescapeDataString(([string]$Value).Replace('+', ' '))
    }
}

# ENDREGION

# REGION - PARSER AND WRITER
# ──────────────────────────────────────────────────────────────────────────────

function Read-RnpPreset {
    <#
    .SYNOPSIS
        Parses a .rnp preset into rules, filters and structure diagnostics.

    .DESCRIPTION
        Reads the file as bytes, records encoding facts (BOM, bare LF line
        endings, trailing CRLF), then parses [RuleN] and [Filters] sections.
        Each rule carries its decoded Config (ordered), the raw encoded
        values, Marked and the decoded Comment ($null when the line is
        absent, as in presets saved before ReNamer 7.6.0.1).

        Issues collects every structural problem found (unknown sections,
        duplicate keys, non-contiguous numbering, malformed Config pairs).
        IsCanonical is true when re-writing the parsed data reproduces the
        file byte for byte, which is what makes a lossless decode possible.

    .PARAMETER LiteralPath
        Path to the .rnp file.

    .INPUTS
        System.String

    .OUTPUTS
        System.Management.Automation.PSCustomObject
        Path, FileName, HasBom, HasBareLf, EndsWithCrLf, Rules, Filters,
        Issues, IsCanonical.

    .EXAMPLE
        (Read-RnpPreset 'C:\Tools\den4b Renamer\Presets\FILE CASE Kebab.rnp').Rules
        Lists the three rules of the kebab preset.

    .EXAMPLE
        Get-ChildItem *.rnp | ForEach-Object { Read-RnpPreset $_.FullName }
        Parses every preset in the current folder.

    .EXAMPLE
        (Read-RnpPreset .\x.rnp).IsCanonical
        True when the file can be decoded and rebuilt byte-identically.

    .NOTES
        Never throws on malformed content; inspect Issues instead.

    .LINK
        https://github.com/futuremotiondev

    .LINK
        Write-RnpPresetText
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(
            Mandatory, Position = 0, ValueFromPipeline,
            ValueFromPipelineByPropertyName,
            HelpMessage = 'Literal path to a ReNamer .rnp preset.'
        )]
        [Alias('PSPath')]
        [ValidateNotNullOrEmpty()]
        [String] $LiteralPath
    )
    process {
        # Accept provider paths (PSPath) from the pipeline as well.
        $LiteralPath = Convert-Path -LiteralPath $LiteralPath
        $bytes = [IO.File]::ReadAllBytes($LiteralPath)
        $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and
                  $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
        $offset = $hasBom ? 3 : 0
        $text = [Text.Encoding]::UTF8.GetString(
            $bytes, $offset, $bytes.Length - $offset)
        $issues = [Collections.Generic.List[string]]::new()
        $rules = [Collections.Generic.List[object]]::new()
        $filters = $null

        # LINE ENDINGS ─────────────────────────────────────────────────────────
        $hasBareLf = $text -match '(?<!\r)\n'
        $endsCrLf = $text.EndsWith("`r`n")
        $lines = $text -split '\r?\n'
        if ($lines.Count -and $lines[-1] -eq '') {
            $lines = $lines[0..($lines.Count - 2)]
        }

        # SECTIONS ─────────────────────────────────────────────────────────────
        $current = $null
        $expected = 0
        foreach ($line in $lines) {
            if ($line -match '^\[(Rule(\d+)|Filters)\]$') {
                if ($Matches[1] -eq 'Filters') {
                    if ($null -ne $filters) {
                        $issues.Add('Duplicate [Filters] section.')
                    }
                    $filters = [ordered]@{}
                    $current = 'Filters'
                    continue
                }
                if ($null -ne $filters) {
                    $issues.Add("[$($Matches[1])] appears after [Filters].")
                }
                $n = [int]$Matches[2]
                if ($n -ne $expected) {
                    $issues.Add(
                        "Section [$($Matches[1])] found where [Rule$expected] " +
                        'was expected (numbering must be contiguous from 0).')
                }
                $expected = $n + 1
                $current = [pscustomobject]@{
                    Index     = $rules.Count
                    Section   = $Matches[1]
                    ID        = $null
                    Config    = [ordered]@{}
                    ConfigRaw = [ordered]@{}
                    HasConfig = $false
                    Marked    = $null
                    Comment   = $null
                    KeyOrder  = [Collections.Generic.List[string]]::new()
                }
                $rules.Add($current)
                continue
            }
            if ($line -eq '') { continue }
            if ($null -eq $current) {
                $issues.Add("Content before the first section: '$line'")
                continue
            }
            $eq = $line.IndexOf('=')
            if ($eq -lt 1) {
                $issues.Add("Unparseable line: '$line'")
                continue
            }
            $key = $line.Substring(0, $eq)
            $value = $line.Substring($eq + 1)

            if ($current -is [string]) {
                if ($filters.Contains($key)) {
                    $issues.Add("Duplicate [Filters] key '$key'.")
                }
                $filters[$key] = $value
                continue
            }
            if ($current.KeyOrder.Contains($key)) {
                $issues.Add("[$($current.Section)] duplicate key '$key'.")
            }
            $current.KeyOrder.Add($key)
            switch -CaseSensitive ($key) {
                'ID' { $current.ID = $value }
                'Marked' { $current.Marked = $value }
                'Comment' {
                    $current.Comment = ConvertFrom-RnpValue $value
                }
                'Config' {
                    $current.HasConfig = $true
                    if ($value -eq '') { break }
                    foreach ($pair in ($value -split ';')) {
                        $colon = $pair.IndexOf(':')
                        if ($colon -lt 1) {
                            $issues.Add(
                                "[$($current.Section)] malformed Config " +
                                "pair '$pair'.")
                            continue
                        }
                        $k = $pair.Substring(0, $colon)
                        $raw = $pair.Substring($colon + 1)
                        if ($current.ConfigRaw.Contains($k)) {
                            $issues.Add(
                                "[$($current.Section)] duplicate Config " +
                                "key '$k'.")
                        }
                        $current.ConfigRaw[$k] = $raw
                        $current.Config[$k] = ConvertFrom-RnpValue $raw
                    }
                }
                default {
                    $issues.Add(
                        "[$($current.Section)] unknown key '$key'.")
                }
            }
        }

        # CANONICAL FORM CHECK ─────────────────────────────────────────────────
        # Rebuild the file from the parsed data. Equality proves the decode is
        # lossless: key order, optional lines and value encoding all survive.
        $isCanonical = $false
        if (-not $hasBom -and -not $hasBareLf -and $endsCrLf -and
            $issues.Count -eq 0 -and
            -not ($rules | Where-Object { -not $_.HasConfig -or -not $_.ID })) {
            $rebuilt = Write-RnpPresetText -Rules $rules -Filters $filters
            $isCanonical = $rebuilt -ceq $text
        }

        [pscustomobject]@{
            Path         = $LiteralPath
            FileName     = [IO.Path]::GetFileName($LiteralPath)
            HasBom       = $hasBom
            HasBareLf    = $hasBareLf
            EndsWithCrLf = $endsCrLf
            Rules        = $rules.ToArray()
            Filters      = $filters
            Issues       = $issues.ToArray()
            IsCanonical  = $isCanonical
        }
    }
}

function Write-RnpPresetText {
    <#
    .SYNOPSIS
        Serializes rules and filters to ReNamer's exact .rnp text layout.

    .DESCRIPTION
        Produces the layout ReNamer 7.10 saves: one block per [RuleN] with
        ID, Config, Marked and Comment lines, an optional [Filters] block,
        CRLF after every line, one blank line between blocks and no blank
        line at the end. Config and Comment values are encoded here; filter
        values are written raw. Marked or Comment lines are omitted when the
        rule's value is $null (legacy presets), which keeps round-trips exact.

    .PARAMETER Rules
        Rule objects exposing ID, Config (ordered key -> decoded value),
        Marked and Comment.

    .PARAMETER Filters
        Ordered [Filters] key -> raw value, or $null for no section.

    .INPUTS
        None.

    .OUTPUTS
        System.String

    .EXAMPLE
        Write-RnpPresetText -Rules $rules -Filters (Get-RnpFiltersBlock FILE)
        Returns the text of a FILE preset.

    .EXAMPLE
        $p = Read-RnpPreset .\x.rnp
        Write-RnpPresetText -Rules $p.Rules -Filters $p.Filters
        Re-serializes a parsed preset (identical when IsCanonical).

    .EXAMPLE
        [IO.File]::WriteAllText($out, (Write-RnpPresetText $rules $null),
            [Text.UTF8Encoding]::new($false))
        Writes a preset without a [Filters] section, UTF-8 without BOM.

    .NOTES
        Always write the result as UTF-8 WITHOUT a BOM.

    .LINK
        https://github.com/futuremotiondev

    .LINK
        Read-RnpPreset
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyCollection()]
        [object[]] $Rules,

        [Parameter(Position = 1)]
        [AllowNull()]
        [Collections.IDictionary] $Filters
    )

    $blocks = [Collections.Generic.List[string]]::new()
    $n = 0
    foreach ($rule in $Rules) {
        $sb = [Text.StringBuilder]::new()
        [void]$sb.Append("[Rule$n]`r`n")
        [void]$sb.Append("ID=$($rule.ID)`r`n")
        $pairs = foreach ($k in $rule.Config.Keys) {
            '{0}:{1}' -f $k, (ConvertTo-RnpConfigValue $rule.ID $k (
                [string]$rule.Config[$k]))
        }
        [void]$sb.Append('Config=' + (@($pairs) -join ';') + "`r`n")
        if ($null -ne $rule.Marked) {
            [void]$sb.Append("Marked=$($rule.Marked)`r`n")
        }
        if ($null -ne $rule.Comment) {
            [void]$sb.Append(
                'Comment=' + (ConvertTo-RnpValue $rule.Comment) + "`r`n")
        }
        $blocks.Add($sb.ToString())
        $n++
    }
    if ($null -ne $Filters) {
        $sb = [Text.StringBuilder]::new()
        [void]$sb.Append("[Filters]`r`n")
        foreach ($k in $Filters.Keys) {
            [void]$sb.Append("$k=$($Filters[$k])`r`n")
        }
        $blocks.Add($sb.ToString())
    }
    return ($blocks -join "`r`n")
}

# ENDREGION

# REGION - FILTERS, SKILL ROOT AND CONFIG
# ──────────────────────────────────────────────────────────────────────────────

function Get-RnpSkillRoot {
    <#
    .SYNOPSIS
        Returns the skill's root folder (the parent of scripts\).

    .DESCRIPTION
        All data, asset and config paths are resolved relative to this folder
        so the skill works wherever it is installed.

    .INPUTS
        None.

    .OUTPUTS
        System.String

    .EXAMPLE
        Join-Path (Get-RnpSkillRoot) 'data\casing-dictionary.tsv'
        Resolves the dictionary path.

    .EXAMPLE
        Get-RnpSkillRoot
        Prints the install folder.

    .EXAMPLE
        Test-Path (Join-Path (Get-RnpSkillRoot) 'config.json')
        Checks that the config file exists.

    .NOTES
        Based on this module's own location.

    .LINK
        https://github.com/futuremotiondev

    .LINK
        Get-RnpConfig
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()
    Split-Path -Parent $PSScriptRoot
}

function Get-RnpConfig {
    <#
    .SYNOPSIS
        Loads config.json with environment variables expanded.

    .DESCRIPTION
        Reads ReNamerPath, PresetsSubfolder, StagingDir and BackupDir from the
        skill's config.json and expands %VARIABLE% references such as %TEMP%.

    .INPUTS
        None.

    .OUTPUTS
        System.Management.Automation.PSCustomObject

    .EXAMPLE
        (Get-RnpConfig).ReNamerPath
        Returns C:\Tools\den4b Renamer by default.

    .EXAMPLE
        (Get-RnpConfig).StagingDir
        Returns the expanded staging folder.

    .EXAMPLE
        Join-Path (Get-RnpConfig).ReNamerPath 'Presets'
        Resolves the live Presets folder.

    .NOTES
        Missing keys fall back to the documented defaults.

    .LINK
        https://github.com/futuremotiondev

    .LINK
        Get-RnpSkillRoot
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $path = Join-Path (Get-RnpSkillRoot) 'config.json'
    $raw = if (Test-Path -LiteralPath $path) {
        Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable
    } else { @{} }
    $expand = { param($v) [Environment]::ExpandEnvironmentVariables($v) }
    [pscustomobject]@{
        ReNamerPath      = & $expand ($raw.ReNamerPath ??
                                      'C:\Tools\den4b Renamer')
        PresetsSubfolder = $raw.PresetsSubfolder ?? ''
        StagingDir       = & $expand ($raw.StagingDir ??
                                      '%TEMP%\rnp-staging')
        BackupDir        = & $expand ($raw.BackupDir ?? '%TEMP%\rnp-backups')
    }
}

function Get-RnpFiltersBlock {
    <#
    .SYNOPSIS
        Returns Futuremotion's canonical [Filters] block for FILE or CONTENTS.

    .DESCRIPTION
        Reads assets\filters\<Variant>.ini (key=value lines under [Filters])
        into an ordered dictionary. FILE renames exactly the passed items;
        CONTENTS renames what is inside the passed folders, recursively.

    .PARAMETER Variant
        FILE or CONTENTS.

    .INPUTS
        System.String

    .OUTPUTS
        System.Collections.Specialized.OrderedDictionary

    .EXAMPLE
        Get-RnpFiltersBlock FILE
        Returns AddFilesFromFolders=0, AddFoldersAsFiles=1, ...

    .EXAMPLE
        (Get-RnpFiltersBlock CONTENTS).IncludeSubfolders
        Returns '1'.

    .EXAMPLE
        $f = Get-RnpFiltersBlock FILE; $f.Masks = '*.svg'
        Starts from the canonical block and adds a mask override.

    .NOTES
        Values are raw text: masks are never percent-encoded.

    .LINK
        https://github.com/futuremotiondev

    .LINK
        Write-RnpPresetText
    #>
    [CmdletBinding()]
    [OutputType([Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateSet('FILE', 'CONTENTS')]
        [String] $Variant
    )
    $path = Join-Path (Get-RnpSkillRoot) 'assets' 'filters' "$Variant.ini"
    $block = [ordered]@{}
    foreach ($line in [IO.File]::ReadAllLines($path)) {
        if ($line -match '^([A-Za-z]+)=(.*)$') {
            $block[$Matches[1]] = $Matches[2]
        }
    }
    return $block
}

# ENDREGION

# REGION - CASING DICTIONARY
# ──────────────────────────────────────────────────────────────────────────────

# Deterministic comparison used for FRAGMENTSTEXT: whitespace-token count
# ascending, then length ascending, then ordinal. Later fragments win overlaps
# in ReNamer, so phrases must come after the words they contain.
$script:CompareFragments = [Comparison[string]] {
    param($a, $b)
    $ta = @($a.Trim() -split '\s+').Count
    $tb = @($b.Trim() -split '\s+').Count
    if ($ta -ne $tb) { return $ta.CompareTo($tb) }
    if ($a.Length -ne $b.Length) { return $a.Length.CompareTo($b.Length) }
    return [string]::CompareOrdinal($a, $b)
}

function Get-RnpMinorWords {
    <#
    .SYNOPSIS
        Returns the 22 APA minor words from data\apa-minor-words.txt.

    .DESCRIPTION
        Reads the file in order, skipping blank lines and '#' comments. The
        order matters: it is the order the words are emitted at the start of
        a title-mode FRAGMENTSTEXT.

    .INPUTS
        None.

    .OUTPUTS
        System.String[]

    .EXAMPLE
        Get-RnpMinorWords
        Returns and, as, but, for, if, nor, or, so, yet, a, an, the, ...

    .EXAMPLE
        'the' -in (Get-RnpMinorWords)
        True.

    .EXAMPLE
        (Get-RnpMinorWords).Count
        Returns 22.

    .NOTES
        See references/casing.md §4.

    .LINK
        https://github.com/futuremotiondev

    .LINK
        Get-RnpDictionarySelection
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param()
    $path = Join-Path (Get-RnpSkillRoot) 'data' 'apa-minor-words.txt'
    @([IO.File]::ReadAllLines($path) |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith('#') })
}

function Get-RnpDictionarySelection {
    <#
    .SYNOPSIS
        Selects, dedupes and sorts casing-dictionary terms for a casing mode.

    .DESCRIPTION
        Implements references/casing.md §2 exactly:

          defaults  preserve/sentence -> tiers core+proper; title -> core;
                    sources base+added; no packs, review or extra terms
          select    (source in Sources AND tier in Tiers)
                    OR (pack in OptInPacks AND tier in Tiers)
                    OR (pack in OptInPacks AND pack is roman or code)
                    OR (tier = review AND term in ReviewTerms)
          add       ExtraTerms
          drop      terms whose lowercase is an APA minor word (warning)
          dedupe    case-insensitively: extra > review > base > added > legacy
          sort      token count, then length, then ordinal (ascending)

        Returns the sorted terms, the FRAGMENTSTEXT string (minor words first
        in title mode), the <LC> alternation used by the title fix-ups, and
        warnings for the build report.

    .PARAMETER Mode
        The casing mode: preserve, title or sentence select terms; any other
        mode returns an empty selection.

    .PARAMETER Dictionary
        The preset-spec casing.dictionary object (hashtable) or $null.

    .INPUTS
        None.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
        Terms, FragmentsText, LowercaseAlternation, TermCount, Warnings.

    .EXAMPLE
        (Get-RnpDictionarySelection -Mode title).TermCount
        Returns 1892 with the shipped dictionary.

    .EXAMPLE
        Get-RnpDictionarySelection -Mode preserve -Dictionary @{
            optInPacks = @('audio') }
        Adds the legacy audio pack to the default preserve selection.

    .EXAMPLE
        (Get-RnpDictionarySelection -Mode title).LowercaseAlternation
        Returns the escaped iPhone|npm|macOS|... alternation.

    .NOTES
        Throws on unknown sources, tiers or packs, on review terms that are
        not review-tier rows, and on extra terms containing commas.

    .LINK
        https://github.com/futuremotiondev

    .LINK
        Get-RnpMinorWords
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [String] $Mode,

        [AllowNull()]
        [Collections.IDictionary] $Dictionary
    )

    $warnings = [Collections.Generic.List[string]]::new()
    $minor = Get-RnpMinorWords
    $empty = [pscustomobject]@{
        Terms = @(); FragmentsText = ''; LowercaseAlternation = ''
        TermCount = 0; Warnings = @()
    }
    if ($Mode -notin 'preserve', 'title', 'sentence') { return $empty }

    # RESOLVE OPTIONS AND DEFAULTS ─────────────────────────────────────────────
    $d = $Dictionary ?? @{}
    $sources = @($d['sources'] ?? @('base', 'added'))
    $tiers = @($d['tiers'] ??
        ($Mode -eq 'title' ? @('core') : @('core', 'proper')))
    $packs = @($d['optInPacks'] ?? @())
    $reviewTerms = @($d['reviewTerms'] ?? @())
    $extraTerms = @($d['extraTerms'] ?? @())

    $path = Join-Path (Get-RnpSkillRoot) 'data' 'casing-dictionary.tsv'
    $rows = @(Import-Csv -LiteralPath $path -Delimiter "`t" -Encoding utf8)
    $knownPacks = @($rows.pack | Sort-Object -Unique)
    foreach ($s in $sources) {
        if ($s -notin 'base', 'added', 'legacy') {
            throw "Unknown dictionary source '$s' (base, added, legacy)."
        }
    }
    foreach ($t in $tiers) {
        if ($t -notin 'core', 'proper', 'review') {
            throw "Unknown dictionary tier '$t' (core, proper, review)."
        }
    }
    foreach ($p in $packs) {
        if ($p -notin $knownPacks) {
            throw "Unknown pack '$p'. Known: $($knownPacks -join ', ')."
        }
    }

    # SELECT ROWS ──────────────────────────────────────────────────────────────
    $reviewSet = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase)
    foreach ($r in $reviewTerms) {
        $row = $rows | Where-Object { $_.term -eq $r } | Select-Object -First 1
        if (-not $row -or $row.tier -ne 'review') {
            throw "reviewTerms: '$r' is not a review-tier dictionary row."
        }
        [void]$reviewSet.Add($row.term)
        $warnings.Add("Review-tier term included on request: $($row.term)")
    }
    $selected = @($rows | Where-Object {
        ($_.source -in $sources -and $_.tier -in $tiers) -or
        ($_.pack -in $packs -and $_.tier -in $tiers) -or
        ($_.pack -in $packs -and $_.pack -in 'roman', 'code') -or
        ($_.tier -eq 'review' -and $reviewSet.Contains($_.term))
    })

    # DEDUPE BY PRECEDENCE ─────────────────────────────────────────────────────
    # Candidates are queued in precedence order; the first spelling of each
    # case-insensitive key wins. The TSV has no internal duplicates, so the
    # precedence only matters against extraTerms and review terms.
    $sourceRank = @{ base = 0; added = 1; legacy = 2 }
    $queue = [Collections.Generic.List[string]]::new()
    foreach ($t in $extraTerms) {
        if ([string]::IsNullOrWhiteSpace($t) -or $t.Contains(',')) {
            throw "extraTerms: '$t' is empty or contains a comma."
        }
        $queue.Add($t.Trim())
    }
    foreach ($t in $reviewSet) { $queue.Add($t) }
    $selected | Sort-Object { $sourceRank[$_.source] } -Stable |
        ForEach-Object { $queue.Add($_.term) }

    $seen = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase)
    $terms = [Collections.Generic.List[string]]::new()
    $dropped = [Collections.Generic.List[string]]::new()
    foreach ($t in $queue) {
        if ($t.ToLowerInvariant() -in $minor) { $dropped.Add($t); continue }
        if ($seen.Add($t)) { $terms.Add($t) }
    }
    if ($dropped.Count) {
        $warnings.Add(
            'Dropped terms that equal APA minor words: ' +
            ($dropped -join ', '))
    }

    # SORT AND EMIT ────────────────────────────────────────────────────────────
    $terms.Sort($script:CompareFragments)
    $fragments = if ($Mode -eq 'title') { @($minor) + $terms } else { $terms }

    # <LC>: dictionary terms (never minor words) that start with a lowercase
    # letter, regex-escaped, longest first then ordinal. They stop the title
    # fix-ups from capitalizing iPhone, npm, macOS and friends.
    $lc = [Collections.Generic.List[string]]::new()
    foreach ($t in $terms) {
        if ([char]::IsLower($t[0])) {
            if ($t[-1] -notmatch '\w') {
                $warnings.Add(
                    "<LC> term '$t' ends in a non-word character; \b may " +
                    'not protect it.')
            }
            $lc.Add($t)
        }
    }
    # Sort the raw terms (length descending, then ordinal), THEN escape, so
    # the order matches the probe-verified T4b pipeline exactly.
    $lc.Sort([Comparison[string]] {
        param($a, $b)
        if ($a.Length -ne $b.Length) { return $b.Length.CompareTo($a.Length) }
        return [string]::CompareOrdinal($a, $b)
    })
    $escaped = @($lc | ForEach-Object { $_ -replace '([\\^$.|?*+()\[\]{}])', '\$1' })

    [pscustomobject]@{
        Terms                = $terms.ToArray()
        FragmentsText        = ($fragments -join ',')
        LowercaseAlternation = ($escaped -join '|')
        TermCount            = $terms.Count
        Warnings             = $warnings.ToArray()
    }
}

function Get-RnpRejoinPairs {
    <#
    .SYNOPSIS
        Returns the CamelCase rejoin pairs for the Replace rule (7.5).

    .DESCRIPTION
        Reads data\camelcase-rejoin.tsv, keeps every kind=brand row plus the
        review rows named in IncludeReview, and sorts them by token count
        descending, then split length descending, then ordinal, so that a
        three-word split rejoins before a two-word split it contains.

    .PARAMETER IncludeReview
        Review-row terms to include by name (e.g. GoogleDrive).

    .INPUTS
        None.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
        Split and Term per pair, already in emission order.

    .EXAMPLE
        (Get-RnpRejoinPairs).Count
        Returns 419 with the shipped table.

    .EXAMPLE
        Get-RnpRejoinPairs -IncludeReview GoogleDrive
        Adds the 'Google Drive' -> 'GoogleDrive' pair.

    .EXAMPLE
        (Get-RnpRejoinPairs)[0]
        Shows the first (longest) pair.

    .NOTES
        Throws when an IncludeReview term is not a review row.

    .LINK
        https://github.com/futuremotiondev

    .LINK
        Get-RnpDictionarySelection
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [String[]] $IncludeReview = @()
    )
    $path = Join-Path (Get-RnpSkillRoot) 'data' 'camelcase-rejoin.tsv'
    $rows = @(Import-Csv -LiteralPath $path -Delimiter "`t" -Encoding utf8)
    foreach ($t in $IncludeReview) {
        $hit = $rows | Where-Object { $_.term -eq $t -and $_.kind -eq 'review' }
        if (-not $hit) {
            throw "camelCaseRejoin.includeReview: '$t' is not a review row."
        }
    }
    $list = [Collections.Generic.List[object]]::new()
    foreach ($r in $rows) {
        if ($r.kind -eq 'brand' -or $r.term -in $IncludeReview) {
            $list.Add([pscustomobject]@{ Split = $r.split; Term = $r.term })
        }
    }
    $list.Sort([Comparison[object]] {
        param($a, $b)
        $ta = @($a.Split -split ' ').Count
        $tb = @($b.Split -split ' ').Count
        if ($ta -ne $tb) { return $tb.CompareTo($ta) }
        if ($a.Split.Length -ne $b.Split.Length) {
            return $b.Split.Length.CompareTo($a.Split.Length)
        }
        return [string]::CompareOrdinal($a.Split, $b.Split)
    })
    return $list.ToArray()
}

# ENDREGION

# REGION - JSON
# ──────────────────────────────────────────────────────────────────────────────

function ConvertFrom-RnpJson {
    <#
    .SYNOPSIS
        Parses preset-spec JSON exactly as written: no date conversion.

    .DESCRIPTION
        ConvertFrom-Json in PowerShell 7.4 turns ISO date-time strings such as
        "2024-05-01T10:20:30" into DateTime objects, which would then be
        written back as "05/01/2024 10:20:30": a silent, filename-illegal
        change. This parser uses System.Text.Json instead and returns ordered
        dictionaries (key order preserved), object arrays, strings, Int64 or
        Double numbers, booleans and $null, with every string untouched.

    .PARAMETER Json
        The JSON text.

    .INPUTS
        System.String

    .OUTPUTS
        System.Collections.Specialized.OrderedDictionary (for a JSON object)

    .EXAMPLE
        $spec = Get-Content .\x.json -Raw | ConvertFrom-RnpJson
        Parses a preset-spec file.

    .EXAMPLE
        (ConvertFrom-RnpJson '{"a":"2024-05-01T10:20:30"}').a
        Returns the string unchanged.

    .EXAMPLE
        (ConvertFrom-RnpJson '{"rules":[]}').rules.Count
        Returns 0.

    .NOTES
        Comments and trailing commas are allowed, as in hand-written specs.

    .LINK
        https://github.com/futuremotiondev

    .LINK
        Read-RnpPreset
    #>
    [CmdletBinding()]
    [OutputType([Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [String] $Json
    )
    process {
        $options = [Text.Json.JsonDocumentOptions]::new()
        $options.CommentHandling = [Text.Json.JsonCommentHandling]::Skip
        $options.AllowTrailingCommas = $true
        $doc = [Text.Json.JsonDocument]::Parse($Json, $options)
        try { ConvertFrom-RnpJsonElement $doc.RootElement }
        finally { $doc.Dispose() }
    }
}

# Recursive JsonElement -> PowerShell conversion (internal helper).
function ConvertFrom-RnpJsonElement {
    param([Text.Json.JsonElement] $El)
    switch ($El.ValueKind) {
        'Object' {
            $o = [ordered]@{}
            foreach ($p in $El.EnumerateObject()) {
                $o[$p.Name] = ConvertFrom-RnpJsonElement $p.Value
            }
            return $o
        }
        'Array' {
            $list = [Collections.Generic.List[object]]::new()
            foreach ($item in $El.EnumerateArray()) {
                $list.Add((ConvertFrom-RnpJsonElement $item))
            }
            # The comma keeps empty and one-element arrays as arrays.
            return , $list.ToArray()
        }
        'String' { return $El.GetString() }
        'Number' {
            [long] $n = 0
            if ($El.TryGetInt64([ref] $n)) { return $n }
            return $El.GetDouble()
        }
        'True' { return $true }
        'False' { return $false }
        default { return $null }
    }
}

# ENDREGION

Export-ModuleMember -Function @(
    'Get-RnpRuleCatalog', 'ConvertTo-RnpValue', 'ConvertTo-RnpConfigValue',
    'ConvertFrom-RnpValue',
    'Read-RnpPreset', 'Write-RnpPresetText', 'Get-RnpSkillRoot',
    'Get-RnpConfig', 'Get-RnpFiltersBlock', 'Get-RnpMinorWords',
    'Get-RnpDictionarySelection', 'Get-RnpRejoinPairs', 'ConvertFrom-RnpJson'
)
