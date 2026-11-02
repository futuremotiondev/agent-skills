<#
.SYNOPSIS
    Module helpers.
#>

function Get-Widget {
    <#
    .SYNOPSIS
        Gets a widget by name.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Name,
        [int] $Count = 1
    )
    process {
        $h = @{ a = 1 }
        Write-Output "${Name}: {"
    }
}

# Sets a widget.
function Set-Widget($Name, $Value) {
    $script:store[$Name] = $Value
}

filter Where-Big { if ($_.Size -gt 10) { $_ } }

class Widget {
    [string] $Name
    Widget([string] $name) { $this.Name = $name }
    [string] Describe() { return "Widget $($this.Name)" }
    static [Widget] Create() { return [Widget]::new('x') }
    hidden [void] Reset() {}
}

enum Size { Small; Large }
