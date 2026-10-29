using namespace System.Collections.Generic
using namespace System.IO

<#
.SYNOPSIS
    [Brief one-line description of what the function does.]

.DESCRIPTION
    [Detailed description. Mention supported file types, external tools used,
    and whether processing is parallel or sequential.]

.PARAMETER LiteralPath
    One or more file or directory paths to process.

.PARAMETER Recurse
    Recurse into subdirectories when directory paths are provided.

.PARAMETER MaxThreads
    Maximum parallel threads. Defaults to 75% of available cores.

.EXAMPLE
    Get-ChildItem *.ttf | Convert-ExampleFileOperation -Verbose

.EXAMPLE
    Convert-ExampleFileOperation -LiteralPath "C:\Fonts" -Recurse -MaxThreads 8
#>
function Convert-ExampleFileOperation {
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName,
            HelpMessage = "One or more file or directory paths to process."
        )]
        [Alias('PSPath')]
        [ValidateNotNullOrEmpty()]
        [string[]] $LiteralPath,

        [Parameter(
            ValueFromPipelineByPropertyName,
            HelpMessage = "Recurse into subdirectories."
        )]
        [switch] $Recurse,

        [Parameter(
            ValueFromPipelineByPropertyName,
            HelpMessage = "The amount of threads to use for parallel processing."
        )]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $MaxThreads = [Math]::Max(1, [int]([Environment]::ProcessorCount * 0.75))
    )

    begin {
        # Resolve external tool — fail fast if missing
        $cmdSomeExe = Get-Command "C:\BIN\some_executable.exe" -CommandType Application -ErrorAction Stop

        # Define acceptable file types for this function
        [string[]] $validExtensions = @('.ttf', '.otf', '.woff', '.woff2')

        # Accumulation lists — populated in process, consumed in end
        [List[string]] $resolvedFiles       = @()
        [List[string]] $resolvedDirectories = @()

        Write-Verbose "Initialized with $($validExtensions.Count) valid extensions."
    }

    process {
        foreach ($aPath in $LiteralPath) {
            # Verify existence
            if (-not (Test-Path -LiteralPath $aPath)) {
                Write-Error "Path does not exist: '$aPath'" -ErrorAction Continue
                continue
            }

            # Resolve to absolute path
            [string] $resolved = $PSCmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath($aPath)
            $resolvedItem = Get-Item -LiteralPath $resolved

            # Classify: file or directory
            if (-not $resolvedItem.PSIsContainer) {
                if ($resolvedItem.Extension -in $validExtensions) {
                    $resolvedFiles.Add($resolved)
                    Write-Verbose "Queued file: $resolved"
                }
                continue
            }

            if ($resolvedItem.PSIsContainer) {
                $resolvedDirectories.Add($resolved)
                Write-Verbose "Queued directory: $resolved"
            }
        }
    }

    end {
        # Expand directories if -Recurse was specified
        if ($Recurse -and $resolvedDirectories.Count -gt 0) {
            foreach ($dir in $resolvedDirectories) {
                $childFiles = Get-ChildItem -LiteralPath $dir -Recurse -File |
                    Where-Object { $_.Extension -in $validExtensions }
                foreach ($f in $childFiles) {
                    $resolvedFiles.Add($f.FullName)
                }
            }
        }

        if ($resolvedFiles.Count -eq 0) {
            Write-Warning "No valid files found to process."
            return
        }

        Write-Verbose "Processing $($resolvedFiles.Count) file(s) across $MaxThreads thread(s)."

        # Parallel processing
        $resolvedFiles | ForEach-Object -Parallel {
            $cmdPath = ($using:cmdSomeExe | Select-Object -First 1).Source
            [string[]] $params = @('--input', $_, '--output', "$_.processed")

            & $cmdPath @params

            if ($LASTEXITCODE -ne 0) {
                Write-Error "Failed processing: $_  (exit code $LASTEXITCODE)"
            }
        } -ThrottleLimit $MaxThreads

        Write-Verbose "Processing complete."
    }
}
