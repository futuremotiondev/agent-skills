#Requires -Version 7.4
<#
.SYNOPSIS
    Proves the documented value encoder reproduces ReNamer's own output: decodes every Config value (and Comment) in every
    .rnp under the given folders, re-encodes it with ConvertTo-RnpValue and compares byte-for-byte.
.EXAMPLE
    ./Test-RnpEncoderRoundTrip.ps1 -Path 'C:\Tools\den4b Renamer\Presets', 'C:\Tools\den4b Renamer\Presets Disabled'
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string[]] $Path)
begin {
    Set-StrictMode -Version Latest
    function ConvertTo-RnpValue([string] $Value) {
        $sb = [Text.StringBuilder]::new()
        foreach ($b in [Text.Encoding]::UTF8.GetBytes($Value)) {
            if (($b -ge 48 -and $b -le 57) -or ($b -ge 65 -and $b -le 90) -or ($b -ge 97 -and $b -le 122)) { [void]$sb.Append([char]$b) }
            elseif ($b -eq 32) { [void]$sb.Append('+') }
            else { [void]$sb.Append(('%{0:X2}' -f $b)) }
        }
        $sb.ToString()
    }
    function ConvertFrom-RnpValue([string] $Value) { [Uri]::UnescapeDataString($Value.Replace('+', ' ')) }
    $files = Get-ChildItem -LiteralPath $Path -Recurse -Filter *.rnp -File
    $values = 0; $mismatch = [Collections.Generic.List[string]]::new()
}
end {
    foreach ($f in $files) {
        foreach ($line in [IO.File]::ReadAllLines($f.FullName)) {
            $raw = @()
            if ($line -match '^Config=(.*)$') { $raw = $Matches[1] -split ';' | ForEach-Object { ($_ -split ':', 2)[1] } }
            elseif ($line -match '^Comment=(.+)$') { $raw = @($Matches[1]) }
            foreach ($v in $raw) {
                if ($null -eq $v) { continue }
                $values++
                $re = ConvertTo-RnpValue (ConvertFrom-RnpValue $v)
                if ($re -cne $v) { $mismatch.Add("$($f.Name): '$($v.Substring(0, [Math]::Min(80, $v.Length)))' -> '$($re.Substring(0, [Math]::Min(80, $re.Length)))'") }
            }
        }
    }
    "Presets: $($files.Count)  Values checked: $values  Mismatches: $($mismatch.Count)"
    $mismatch | Select-Object -First 25
}
