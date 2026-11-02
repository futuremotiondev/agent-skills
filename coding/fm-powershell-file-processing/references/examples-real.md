# Real Examples — FMDevToolbox

Stripped-down skeletons from actual FMDevToolbox functions. These demonstrate the
architecture and style patterns in production code. Business logic is stubbed out
to keep focus on structure.

---

## Example 1: Convert-WoffToFont

**Variant:** Parallel + external CLI (ftcli) + directory recursion + parameter cloning

Demonstrates: `List[string]` accumulation, separate parallel loops for directories vs
files, `($Using:var).Clone()` inside parallel blocks, preserving `$WarningPreference`.

```powershell
using namespace System.IO
using namespace System.Collections.Generic

function Convert-WoffToFont {
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName,
            HelpMessage = "Literal path to one or more WOFF/WOFF2 files to convert."
        )]
        [Alias('PSPath')]
        [ValidateNotNullOrEmpty()]
        [string[]] $LiteralPath,

        [Parameter(
            ValueFromPipelineByPropertyName,
            HelpMessage = "Directory to save converted font files."
        )]
        [string] $OutputDirectory,

        [Parameter(
            ValueFromPipelineByPropertyName,
            HelpMessage = "Recurse into subdirectories."
        )]
        [switch] $Recurse,

        [Parameter(
            ValueFromPipelineByPropertyName,
            HelpMessage = "Skip bounding box recalculation."
        )]
        [switch] $NoRecalculateBBoxes,

        [Parameter(
            ValueFromPipelineByPropertyName,
            HelpMessage = "Reorder font tables after conversion."
        )]
        [switch] $ReorderTables,

        [Parameter(
            ValueFromPipelineByPropertyName,
            HelpMessage = "The amount of threads to use for parallel processing."
        )]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $MaxThreads = [Math]::Max(1, [int]([Environment]::ProcessorCount * 0.75))
    )

    begin {
        # External tool — fail fast
        $cmdFtcli = Get-FoundryToolsFtcli -EA Stop

        [string[]] $validExtensions = @('.woff', '.woff2')
        [List[string]] $resolvedPaths       = @()
        [List[string]] $resolvedDirectories = @()
    }

    process {
        foreach ($aPath in $LiteralPath) {
            [string] $resolvedPath = $PSCmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath($aPath)

            if (-not (Test-Path -LiteralPath $resolvedPath)) {
                Write-Warning "Path doesn't exist ($resolvedPath). Skipping."
                continue
            }

            $item = Get-Item -LiteralPath $resolvedPath -EA Stop

            if ($item.PSIsContainer) {
                if ($PSBoundParameters.ContainsKey('Recurse')) {
                    $resolvedDirectories.Add($resolvedPath)
                } else {
                    Write-Warning "Directory passed without -Recurse, skipping: $resolvedPath"
                }
                continue
            }

            [string] $ext = [Path]::GetExtension($resolvedPath).ToLowerInvariant()
            if ($ext -in $validExtensions) {
                $resolvedPaths.Add($resolvedPath)
            } else {
                Write-Warning "Not a .woff/.woff2 file ($resolvedPath). Skipping."
            }
        }
    }

    end {
        # Validate output directory
        [string] $outputDir = $null
        if ($PSBoundParameters.ContainsKey('OutputDirectory')) {
            [string] $resolvedOutput = $PSCmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
            if (-not (Test-Path -LiteralPath $resolvedOutput)) {
                [Directory]::CreateDirectory($resolvedOutput) | Out-Null
            }
            $outputDir = $resolvedOutput
        }

        # Build base parameter array for ftcli
        [string[]] $ftcliParams = @('converter', 'wf2ft', '-no-ow')
        if ($NoRecalculateBBoxes) { $ftcliParams += '-no-rbb' }
        if ($ReorderTables)       { $ftcliParams += '-rtb' }

        # Parallel loop for directories (with -r flag)
        if ($PSBoundParameters.ContainsKey('Recurse') -and $resolvedDirectories.Count -gt 0) {
            [string[]] $ftcliParamsDir = $ftcliParams.Clone()
            $ftcliParamsDir += '-r'

            $resolvedDirectories | ForEach-Object -Parallel {
                $curDir         = $_
                $cmdFtcli       = $Using:cmdFtcli
                # Clone inside parallel — each thread gets its own copy
                $ftcliParamsDir = ($Using:ftcliParamsDir).Clone()
                $outputDir      = $Using:outputDir

                if ($outputDir) { $ftcliParamsDir += @('-out', $outputDir) }
                $ftcliParamsDir += $curDir

                & $cmdFtcli $ftcliParamsDir
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "Error converting fonts in '$curDir'."
                }
            } -ThrottleLimit $MaxThreads
        }

        # Parallel loop for individual files
        if ($resolvedPaths.Count -gt 0) {
            $resolvedPaths | ForEach-Object -Parallel {
                $curWoff     = $_
                $cmdFtcli    = $Using:cmdFtcli
                $ftcliParams = ($Using:ftcliParams).Clone()
                $outputDir   = $Using:outputDir

                if ($outputDir) { $ftcliParams += @('-out', $outputDir) }
                $ftcliParams += $curWoff

                & $cmdFtcli $ftcliParams
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "Error converting $([Path]::GetFileName($curWoff))."
                }
            } -ThrottleLimit $MaxThreads
        }

        Write-Verbose "WOFF to font conversion complete."
    }
}
```

---

## Example 2: Convert-SVGColor

**Variant:** Parallel + regex replacement + multiple output modes (OutputDirectory / Overwrite / AutoDirectory)

Demonstrates: compiled `[Regex]`, `$Using:` for multiple variables in parallel blocks,
conditional output path logic, `[IO.File]::ReadAllText()` / `WriteAllText()` for performance.

```powershell
using namespace System.IO
using namespace System.Collections.Generic
using namespace System.Text.RegularExpressions

function Convert-SVGColor {
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName,
            HelpMessage = "One or more SVG file or directory paths."
        )]
        [Alias('PSPath')]
        [ValidateNotNullOrEmpty()]
        [string[]] $LiteralPath,

        [Parameter(
            ValueFromPipelineByPropertyName,
            HelpMessage = "New hex color for fill attributes."
        )]
        [ValidatePattern('^#(?:[0-9a-fA-F]{3,4}){1,2}$')]
        [string] $NewFillColor,

        [Parameter(
            ValueFromPipelineByPropertyName,
            HelpMessage = "New hex color for stroke attributes."
        )]
        [ValidatePattern('^#(?:[0-9a-fA-F]{3,4}){1,2}$')]
        [string] $NewStrokeColor,

        [Parameter(
            ValueFromPipelineByPropertyName,
            HelpMessage = "Output directory for recolored SVGs."
        )]
        [string] $OutputDirectory,

        [Parameter(
            ValueFromPipelineByPropertyName,
            HelpMessage = "Overwrite source files in place."
        )]
        [switch] $Overwrite,

        [Parameter(
            ValueFromPipelineByPropertyName,
            HelpMessage = "Auto-create subfolder next to source files."
        )]
        [string] $AutoDirectory = 'SVG Recolored',

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
        [string[]] $validExtensions = @('.svg')
        [List[string]] $resolvedFiles = @()

        # Build compiled regex patterns for fill/stroke replacement
        # (Full color pattern omitted for brevity — covers hex, rgb, hsl, named colors)
        [string] $colorPattern = '#(?:[0-9a-fA-F]{3,4}){1,2}\b'

        [Regex] $rxFill = [Regex]::new(
            "(fill\s*[=:]\s*[`"']?)($colorPattern)(\s*[;`"'}])",
            [RegexOptions]::Compiled -bor [RegexOptions]::IgnoreCase
        )
        [Regex] $rxStroke = [Regex]::new(
            "(stroke\s*[=:]\s*[`"']?)($colorPattern)(\s*[;`"'}])",
            [RegexOptions]::Compiled -bor [RegexOptions]::IgnoreCase
        )

        # Determine output mode
        [bool] $hasOutDir = $PSBoundParameters.ContainsKey('OutputDirectory')
        [bool] $overwrite = $Overwrite.IsPresent

        Write-Verbose "Fill: $NewFillColor | Stroke: $NewStrokeColor | Mode: $(
            if ($overwrite) { 'Overwrite' }
            elseif ($hasOutDir) { 'OutputDirectory' }
            else { "AutoDirectory ($AutoDirectory)" }
        )"
    }

    process {
        foreach ($aPath in $LiteralPath) {
            if (-not (Test-Path -LiteralPath $aPath)) {
                Write-Error "Path does not exist: '$aPath'" -ErrorAction Continue
                continue
            }
            [string] $resolved = $PSCmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath($aPath)
            $resolvedItem = Get-Item -LiteralPath $resolved

            if (-not $resolvedItem.PSIsContainer -and $resolvedItem.Extension -in $validExtensions) {
                $resolvedFiles.Add($resolved)
            }
            elseif ($resolvedItem.PSIsContainer -and $Recurse) {
                Get-ChildItem -LiteralPath $resolved -Recurse -File -Filter '*.svg' |
                    ForEach-Object { $resolvedFiles.Add($_.FullName) }
            }
        }
    }

    end {
        if ($resolvedFiles.Count -eq 0) {
            Write-Warning "No SVG files found to process."
            return
        }

        # Validate output directory if specified
        if ($hasOutDir -and -not (Test-Path -LiteralPath $OutputDirectory)) {
            [Directory]::CreateDirectory($OutputDirectory) | Out-Null
        }

        Write-Verbose "Processing $($resolvedFiles.Count) SVG(s) across $MaxThreads thread(s)."

        $resolvedFiles | ForEach-Object -Parallel {
            [string] $filePath   = $_
            [string] $newFill    = $Using:NewFillColor
            [string] $newStroke  = $Using:NewStrokeColor
            [Regex]  $rxFill     = $Using:rxFill
            [Regex]  $rxStroke   = $Using:rxStroke
            [bool]   $overwrite  = $Using:overwrite
            [bool]   $hasOutDir  = $Using:hasOutDir
            [string] $outputDir  = $Using:OutputDirectory
            [string] $autoDir    = $Using:AutoDirectory

            # Read SVG content
            [string] $content = [System.IO.File]::ReadAllText($filePath)

            # Apply replacements
            if ($newFill)   { $content = $rxFill.Replace($content, "`${1}$newFill`${3}") }
            if ($newStroke) { $content = $rxStroke.Replace($content, "`${1}$newStroke`${3}") }

            # Determine output path
            [string] $fileName = [System.IO.Path]::GetFileName($filePath)
            [string] $fileDir  = [System.IO.Path]::GetDirectoryName($filePath)

            [string] $outputPath = if ($overwrite) { $filePath }
            elseif ($hasOutDir) { [System.IO.Path]::Combine($outputDir, $fileName) }
            else {
                [string] $autoOutputDir = [System.IO.Path]::Combine($fileDir, $autoDir)
                if (-not (Test-Path -LiteralPath $autoOutputDir)) {
                    $null = New-Item -Path $autoOutputDir -ItemType Directory -Force
                }
                [System.IO.Path]::Combine($autoOutputDir, $fileName)
            }

            [System.IO.File]::WriteAllText($outputPath, $content)
        } -ThrottleLimit $MaxThreads

        Write-Verbose "SVG color replacement complete."
    }
}
```

---

## Example 3: Copy-GitRepository

**Variant:** Non-LiteralPath input (URLs) + parallel cloning + Internal- helper function

Demonstrates: URL-based `$RepositoryURL` parameter instead of `$LiteralPath`, helper
function with `Internal-` prefix, `[PSCustomObject]` structured output, conditional
flag building.

```powershell
using namespace System.IO
using namespace System.Collections.Generic

function Internal-ParseGitUrl {
    <# Parses a git URL and returns owner + repo name. #>
    param([string] $Url)

    [string] $cleaned = $Url.TrimEnd('/') -replace '\.git$', ''
    [uri] $parsed = [uri]$cleaned
    [string[]] $segments = $parsed.AbsolutePath.Trim('/').Split('/')

    [PSCustomObject]@{
        Host     = $parsed.Host
        Owner    = if ($segments.Count -ge 2) { $segments[0] } else { '' }
        RepoName = if ($segments.Count -ge 2) { $segments[-1] } else { $segments[0] }
        IsValid  = $segments.Count -ge 2
    }
}

function Copy-GitRepository {
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName,
            HelpMessage = "Git repository URL(s) to clone."
        )]
        [Alias('URL', 'Uri')]
        [ValidateNotNullOrEmpty()]
        [string[]] $RepositoryURL,

        [Parameter(
            Position = 1,
            ValueFromPipelineByPropertyName,
            HelpMessage = "Directory to clone repositories into."
        )]
        [string] $OutputPath = '.',

        [Parameter(
            ValueFromPipelineByPropertyName,
            HelpMessage = "Prepend owner/org name to cloned folder."
        )]
        [switch] $AutoUserPrefix,

        [Parameter(
            ValueFromPipelineByPropertyName,
            HelpMessage = "Skip --recurse-submodules -j8 flags."
        )]
        [switch] $NoRecurseSubmodules,

        [Parameter(
            ValueFromPipelineByPropertyName,
            HelpMessage = "Maximum parallel clone operations."
        )]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $MaxThreads = [Math]::Max(1, [int]([Environment]::ProcessorCount * 0.75))
    )

    begin {
        $cmdGit = Get-Command git -CommandType Application -ErrorAction Stop
        [List[PSCustomObject]] $reposToClone = @()
    }

    process {
        # Validate and accumulate — no cloning here
        foreach ($url in $RepositoryURL) {
            [string] $trimmed = $url.Trim()
            if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }

            $parsed = Internal-ParseGitUrl -Url $trimmed
            $reposToClone.Add([PSCustomObject]@{
                URL      = $trimmed
                Owner    = $parsed.Owner.ToLowerInvariant()
                RepoName = $parsed.RepoName
                IsValid  = $parsed.IsValid
            })
        }
    }

    end {
        if ($reposToClone.Count -eq 0) {
            Write-Warning "No valid repository URLs provided."
            return
        }

        # Resolve and create output directory
        [string] $resolvedOutput = $PSCmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
        if (-not (Test-Path -LiteralPath $resolvedOutput)) {
            [Directory]::CreateDirectory($resolvedOutput) | Out-Null
        }

        Write-Verbose "Cloning $($reposToClone.Count) repo(s) to '$resolvedOutput'."

        $reposToClone | ForEach-Object -Parallel {
            $repo       = $_
            $cmdGit     = ($Using:cmdGit | Select-Object -First 1).Source
            $outBase    = $Using:resolvedOutput
            $usePrefix  = $Using:AutoUserPrefix
            $noSubmod   = $Using:NoRecurseSubmodules

            # Build folder name
            [string] $folderName = if ($usePrefix -and $repo.Owner) {
                "$($repo.Owner)-$($repo.RepoName)"
            } else { $repo.RepoName }

            [string] $targetDir = [System.IO.Path]::Combine($outBase, $folderName)

            # Build git arguments
            [List[string]] $gitArgs = @('clone')
            if (-not $noSubmod) { $gitArgs.AddRange([string[]]@('--recurse-submodules', '-j8')) }
            $gitArgs.Add($repo.URL)
            $gitArgs.Add($targetDir)

            & $cmdGit @gitArgs 2>&1 | Out-Null

            [PSCustomObject]@{
                URL     = $repo.URL
                Path    = $targetDir
                Success = ($LASTEXITCODE -eq 0)
            }
        } -ThrottleLimit $MaxThreads
    }
}
```
