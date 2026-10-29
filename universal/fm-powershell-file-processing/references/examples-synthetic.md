# Synthetic Examples

Generic stubs demonstrating the same three architecture variants. Business logic is
intentionally minimal so the agent focuses on structural patterns rather than
domain-specific details.

---

## Example 1: Convert-ImageToWebP

**Variant:** Parallel + external binary (cwebp) + directory recursion

```powershell
using namespace System.IO
using namespace System.Collections.Generic

function Convert-ImageToWebP {
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName,
            HelpMessage = "One or more image file or directory paths to convert."
        )]
        [Alias('PSPath')]
        [ValidateNotNullOrEmpty()]
        [string[]] $LiteralPath,

        [Parameter(
            ValueFromPipelineByPropertyName,
            HelpMessage = "Directory to save converted WebP files."
        )]
        [string] $OutputDirectory,

        [Parameter(
            ValueFromPipelineByPropertyName,
            HelpMessage = "WebP compression quality (0-100)."
        )]
        [ValidateRange(0, 100)]
        [int] $Quality = 80,

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
        $cmdCwebp = Get-Command "cwebp.exe" -CommandType Application -ErrorAction Stop

        [string[]] $validExtensions = @('.png', '.jpg', '.jpeg', '.tiff', '.bmp')
        [List[string]] $resolvedFiles       = @()
        [List[string]] $resolvedDirectories = @()
    }

    process {
        foreach ($aPath in $LiteralPath) {
            if (-not (Test-Path -LiteralPath $aPath)) {
                Write-Error "Path does not exist: '$aPath'" -ErrorAction Continue
                continue
            }

            [string] $resolved = $PSCmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath($aPath)
            $item = Get-Item -LiteralPath $resolved

            if ($item.PSIsContainer) {
                if ($Recurse) { $resolvedDirectories.Add($resolved) }
                else { Write-Warning "Directory passed without -Recurse: $resolved" }
                continue
            }

            if ($item.Extension.ToLowerInvariant() -in $validExtensions) {
                $resolvedFiles.Add($resolved)
            }
        }
    }

    end {
        # Expand directories
        if ($Recurse -and $resolvedDirectories.Count -gt 0) {
            foreach ($dir in $resolvedDirectories) {
                Get-ChildItem -LiteralPath $dir -Recurse -File |
                    Where-Object { $_.Extension.ToLowerInvariant() -in $validExtensions } |
                    ForEach-Object { $resolvedFiles.Add($_.FullName) }
            }
        }

        if ($resolvedFiles.Count -eq 0) {
            Write-Warning "No valid image files found to convert."
            return
        }

        # Resolve output directory
        [string] $outDir = $null
        if ($PSBoundParameters.ContainsKey('OutputDirectory')) {
            $outDir = $PSCmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
            if (-not (Test-Path -LiteralPath $outDir)) {
                [Directory]::CreateDirectory($outDir) | Out-Null
            }
        }

        Write-Verbose "Converting $($resolvedFiles.Count) image(s) to WebP (q=$Quality)."

        $resolvedFiles | ForEach-Object -Parallel {
            [string] $filePath = $_
            [string] $cmdPath  = ($Using:cmdCwebp | Select-Object -First 1).Source
            [int]    $quality  = $Using:Quality
            [string] $outDir   = $Using:outDir

            [string] $baseName = [System.IO.Path]::GetFileNameWithoutExtension($filePath)
            [string] $destDir  = if ($outDir) { $outDir }
                                 else { [System.IO.Path]::GetDirectoryName($filePath) }
            [string] $outFile  = [System.IO.Path]::Combine($destDir, "$baseName.webp")

            [string[]] $cwebpParams = @('-q', $quality, $filePath, '-o', $outFile)
            & $cmdPath @cwebpParams

            if ($LASTEXITCODE -ne 0) {
                Write-Error "cwebp failed for: $filePath (exit $LASTEXITCODE)"
            }
        } -ThrottleLimit $MaxThreads

        Write-Verbose "WebP conversion complete."
    }
}
```

---

## Example 2: Get-FileHashAudit

**Variant:** Sequential processing in end block + directory recursion (no parallel)

Demonstrates: sequential `foreach` instead of `ForEach-Object -Parallel`, no `$MaxThreads`
parameter, structured `[PSCustomObject]` output for each file, `.NET` hash computation.

```powershell
using namespace System.IO
using namespace System.Collections.Generic
using namespace System.Security.Cryptography

function Get-FileHashAudit {
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName,
            HelpMessage = "One or more file or directory paths to audit."
        )]
        [Alias('PSPath')]
        [ValidateNotNullOrEmpty()]
        [string[]] $LiteralPath,

        [Parameter(
            ValueFromPipelineByPropertyName,
            HelpMessage = "Hash algorithm to use."
        )]
        [ValidateSet('SHA256', 'SHA512', 'MD5', IgnoreCase = $true)]
        [string] $Algorithm = 'SHA256',

        [Parameter(
            ValueFromPipelineByPropertyName,
            HelpMessage = "Recurse into subdirectories."
        )]
        [switch] $Recurse
    )

    begin {
        [List[string]] $resolvedFiles = @()

        # Create hasher once — reused across all files
        [HashAlgorithm] $hasher = [HashAlgorithm]::Create($Algorithm)
        Write-Verbose "Using algorithm: $Algorithm"
    }

    process {
        foreach ($aPath in $LiteralPath) {
            if (-not (Test-Path -LiteralPath $aPath)) {
                Write-Error "Path does not exist: '$aPath'" -ErrorAction Continue
                continue
            }

            [string] $resolved = $PSCmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath($aPath)
            $item = Get-Item -LiteralPath $resolved

            if (-not $item.PSIsContainer) {
                $resolvedFiles.Add($resolved)
                continue
            }

            if ($Recurse) {
                Get-ChildItem -LiteralPath $resolved -Recurse -File |
                    ForEach-Object { $resolvedFiles.Add($_.FullName) }
            }
        }
    }

    end {
        if ($resolvedFiles.Count -eq 0) {
            Write-Warning "No files found to audit."
            return
        }

        Write-Verbose "Auditing $($resolvedFiles.Count) file(s)."

        # Sequential — hash computation is I/O bound, parallelism adds overhead
        foreach ($filePath in $resolvedFiles) {
            try {
                [FileStream] $stream = [File]::OpenRead($filePath)
                [byte[]] $hashBytes = $hasher.ComputeHash($stream)
                $stream.Close()

                [PSCustomObject]@{
                    Path      = $filePath
                    FileName  = [Path]::GetFileName($filePath)
                    Algorithm = $Algorithm
                    Hash      = [BitConverter]::ToString($hashBytes) -replace '-', ''
                    SizeBytes = (Get-Item -LiteralPath $filePath).Length
                }
            }
            catch {
                Write-Error "Failed to hash '$filePath': $_" -ErrorAction Continue
            }
        }

        $hasher.Dispose()
        Write-Verbose "Hash audit complete."
    }
}
```

---

## Example 3: ConvertTo-NormalizedRecord

**Variant:** Pipeline-only processing in process block (no file/directory handling)

Demonstrates: work done in `process` block (not `end`), no `LiteralPath` parameter,
no `MaxThreads`, standard pipeline transformation pattern.

```powershell
function ConvertTo-NormalizedRecord {
    <#
    .SYNOPSIS
        Normalizes PSCustomObject records by trimming, lowering keys, and
        standardizing date formats.
    #>
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipeline,
            HelpMessage = "One or more PSCustomObject records to normalize."
        )]
        [ValidateNotNull()]
        [PSCustomObject[]] $InputRecord,

        [Parameter(
            ValueFromPipelineByPropertyName,
            HelpMessage = "Date format string for standardizing date properties."
        )]
        [string] $DateFormat = 'yyyy-MM-dd',

        [Parameter(
            ValueFromPipelineByPropertyName,
            HelpMessage = "Property names to treat as dates."
        )]
        [string[]] $DateProperties = @('Date', 'CreatedAt', 'UpdatedAt')
    )

    begin {
        Write-Verbose "Normalizing records with date format: $DateFormat"
    }

    process {
        # Work happens HERE — not in end block (no file accumulation needed)
        foreach ($record in $InputRecord) {
            [hashtable] $normalized = @{}

            foreach ($prop in $record.PSObject.Properties) {
                [string] $key   = $prop.Name.Trim().ToLowerInvariant()
                [object] $value = $prop.Value

                # Trim string values
                if ($value -is [string]) {
                    $value = $value.Trim()
                }

                # Standardize date properties
                if ($key -in ($DateProperties | ForEach-Object { $_.ToLowerInvariant() })) {
                    [datetime] $parsed = [datetime]::MinValue
                    if ([datetime]::TryParse([string]$value, [ref]$parsed)) {
                        $value = $parsed.ToString($DateFormat)
                    }
                }

                $normalized[$key] = $value
            }

            [PSCustomObject]$normalized
        }
    }

    end {
        Write-Verbose "Record normalization complete."
    }
}
```
