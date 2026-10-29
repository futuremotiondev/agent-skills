#Requires -Version 7.4
<#
.SYNOPSIS
    Converts widget files. # TODO-free help text
#>
[CmdletBinding(DefaultParameterSetName = 'Path')]
[OutputType([pscustomobject])]
param(
    [Parameter(Mandatory, ParameterSetName = 'Path')]
    [string] $Path,

    [switch] $Force
)

begin {
    function Get-Inner([string] $Name) {
        return "inner-$Name"
    }
    $fmt = {
        param([string] $Value, [int] $Max = 60)
        $Value.Substring(0, [Math]::Min($Max, $Value.Length))
    }
    $words = 'TODO FIXME'   # a TODO inside a comment counts; the string above does not
}

process {
    & $fmt (Get-Inner $Path)
}
