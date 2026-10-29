#Requires -Version 7.1
using namespace System.Collections.Generic
using namespace System.IO

# Shared implementation for the Install-Futuremotion*Skills.ps1 scripts in the
# repository root. Each of those scripts dot-sources this file and then calls
# Get-FMSkillFolder and Install-FMSkill with its own provider folder and
# target directory.
#
# This file is dot-sourced rather than imported as a module on purpose. A
# module has its own session state, so its functions do not see the calling
# script's -WhatIf / -Verbose preference variables, and -WhatIf on the script
# would silently stop protecting the copy. Dot-sourced functions run in child
# scopes of the calling script and inherit those preferences naturally.

# REGION - GUARD
# ──────────────────────────────────────────────────────────────────────────────

# Running this file directly only defines functions in a scope that is thrown
# away immediately, which looks like a silent no-op. Say so instead.
if ($MyInvocation.InvocationName -ne '.') {
    Write-Warning ('SkillInstallerCore.ps1 only defines helper functions. ' +
        'Run one of the Install-Futuremotion*Skills.ps1 scripts instead.')
}

# ENDREGION

# REGION - SHARED STATE
# ──────────────────────────────────────────────────────────────────────────────

# An installer that targets several directories (Gemini / Antigravity) runs
# Install-FMSkill once per directory, which validates every skill each time.
# Manifest warnings are reported once per skill per run rather than once per
# target; this set records which skills have already been reported. It lives
# in the calling script's scope because this file is dot-sourced.
$fmReportedSkills = [HashSet[String]]::new([StringComparer]::OrdinalIgnoreCase)

# ENDREGION

# REGION - FUNCTIONS
# ──────────────────────────────────────────────────────────────────────────────

<#
.SYNOPSIS
    Finds the skill folders that a provider installer should deploy.

.DESCRIPTION
    Scans one or more provider folders under a skills repository root (for
    example 'claude' and 'universal') and emits one object per top-level
    directory that carries a SKILL.md file. Dotted directories (.old, .git,
    .vscode, ...) are always skipped, as are names listed in -Exclude.

    Folders are scanned in the order given. Every provider installer mirrors
    its own folder and the shared 'universal' folder into one flat skills
    directory, so two skills with the same folder name would overwrite each
    other at the destination. That collision is treated as a repository
    error: the function throws before emitting anything and names both
    source paths so the duplicate can be fixed.

    A provider folder that does not exist produces a warning rather than an
    error, so a provider with no specific skills still installs the
    universal set.

.PARAMETER LiteralPath
    The skills repository root, which is the directory that contains the
    provider folders. Accepts a literal path; wildcards are not expanded.

.PARAMETER Folder
    One or more provider folder names under the repository root to scan, for
    example 'claude', 'universal'. Folders are scanned in the order given.

.PARAMETER Exclude
    Skill folder names to skip, matched exactly (case-insensitive) against
    each skill's directory name. Applies to every scanned folder.

.INPUTS
    System.String[]
    Pipe one or more repository root paths.

.OUTPUTS
    System.Management.Automation.PSCustomObject
    One object per skill folder with Name, Origin (the provider folder it
    came from), and FullName (the absolute path to the skill folder).

.EXAMPLE
    Get-FMSkillFolder -LiteralPath $PSScriptRoot -Folder claude, universal

    Lists every Claude-specific and universal skill in the repository.

.EXAMPLE
    Get-FMSkillFolder -LiteralPath . -Folder grok, universal `
        -Exclude fm-summarize-codebase

    Lists the Grok and universal skills, leaving out one skill.

.EXAMPLE
    'D:\AI\Skills\futuremotion-skills' | Get-FMSkillFolder -Folder universal

    Pipes a repository root and lists only the universal skills.

.NOTES
    Defined in installer\SkillInstallerCore.ps1 and dot-sourced by the
    Install-Futuremotion*Skills.ps1 scripts; it is not exported from a
    module.

.LINK
    https://github.com/futuremotiondev

.LINK
    Install-FMSkill

.LINK
    Test-FMSkillManifest
#>
function Get-FMSkillFolder {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(
            Mandatory, Position = 0, ValueFromPipeline,
            ValueFromPipelineByPropertyName,
            HelpMessage = 'Literal path to the skills repository root.'
        )]
        [Alias('PSPath')]
        [ValidateNotNullOrEmpty()]
        [String[]] $LiteralPath,

        [Parameter(
            Mandatory,
            HelpMessage = 'Provider folder names to scan, in order.'
        )]
        [ValidateNotNullOrEmpty()]
        [String[]] $Folder,

        [Parameter(HelpMessage = 'Skill folder names to skip.')]
        [String[]] $Exclude = @()
    )

    process {
        foreach ($rootPath in $LiteralPath) {
            $repositoryRoot = Convert-Path -LiteralPath $rootPath `
                -ErrorAction Stop

            # Keyed case-insensitively because Windows paths are. The value is
            # the first source path seen, so a collision can name both copies.
            $seen = [Dictionary[String, String]]::new(
                [StringComparer]::OrdinalIgnoreCase)
            $found = [List[PSCustomObject]]::new()

            foreach ($folderName in $Folder) {
                $folderPath = [Path]::Combine($repositoryRoot, $folderName)
                $folderExists = Test-Path -LiteralPath $folderPath `
                    -PathType Container
                if (-not $folderExists) {
                    Write-Warning "Skill folder not found, skipped: $folderPath"
                    continue
                }

                # A skill is any top-level directory that carries a SKILL.md.
                # Matching on SKILL.md rather than the fm- prefix keeps this
                # honest if a skill is ever added without the prefix.
                $skillDirs = Get-ChildItem -LiteralPath $folderPath -Directory |
                    Where-Object {
                        -not $_.Name.StartsWith('.') -and
                        ($Exclude -notcontains $_.Name) -and
                        (Test-Path -LiteralPath (
                            [Path]::Combine($_.FullName, 'SKILL.md')))
                    } |
                    Sort-Object Name

                foreach ($skillDir in $skillDirs) {
                    if ($seen.ContainsKey($skillDir.Name)) {
                        $message = (
                            "Skill '{0}' exists in more than one folder and " +
                            "would overwrite itself at the destination:" +
                            "`n  {1}`n  {2}`nRename or remove one copy."
                        ) -f $skillDir.Name, $seen[$skillDir.Name],
                            $skillDir.FullName
                        throw $message
                    }

                    $seen[$skillDir.Name] = $skillDir.FullName
                    $found.Add([PSCustomObject]@{
                        Name     = $skillDir.Name
                        Origin   = $folderName
                        FullName = $skillDir.FullName
                    })
                }
            }

            # Emit only after every folder is scanned. Emitting as we go would
            # let a downstream Install-FMSkill copy the first skills before a
            # later collision throws, leaving a half-installed set.
            $found
        }
    }
}

<#
.SYNOPSIS
    Checks a skill folder's SKILL.md frontmatter against the Agent Skills
    specification.

.DESCRIPTION
    Reads the YAML frontmatter at the top of SKILL.md and reports problems
    that would stop an agent from loading the skill (errors) or that break
    the Agent Skills specification at agentskills.io (warnings).

    Errors, which make IsValid false:
    - SKILL.md is missing.
    - SKILL.md has no frontmatter block delimited by '---' lines.
    - The frontmatter has no 'name' or no 'description'.

    Warnings, which leave IsValid true:
    - 'name' does not match the folder name. The specification requires
      them to match, and agents list the skill under 'name'.
    - 'name' is longer than 64 characters or is not lowercase letters,
      digits, and single hyphens.
    - 'description' is longer than 1024 characters.

    The frontmatter is read with a small line-based parser rather than a
    YAML library, so the installers have no module dependency. It handles
    plain, quoted, folded (>) and literal (|) scalars, which covers every
    form used in this repository.

.PARAMETER LiteralPath
    Path to one or more skill folders, each containing a SKILL.md. Accepts
    literal paths; wildcards are not expanded.

.INPUTS
    System.String[]
    Pipe skill folder paths, DirectoryInfo objects, or the objects emitted
    by Get-FMSkillFolder (bound through their FullName property).

.OUTPUTS
    System.Management.Automation.PSCustomObject
    One result per skill folder with Name, DeclaredName, DescriptionLength,
    IsValid, Errors, and Warnings.

.EXAMPLE
    Test-FMSkillManifest -LiteralPath .\universal\fm-powershell-coding-style

    Validates a single skill.

.EXAMPLE
    Get-FMSkillFolder -LiteralPath . -Folder universal |
        Test-FMSkillManifest | Where-Object Warnings

    Lists every universal skill that breaks the specification.

.EXAMPLE
    Get-ChildItem .\claude -Directory | Test-FMSkillManifest |
        Format-Table Name, IsValid, DescriptionLength

    Validates directories piped straight from Get-ChildItem.

.NOTES
    Defined in installer\SkillInstallerCore.ps1. Install-FMSkill calls this
    for every skill before copying it.

.LINK
    https://github.com/futuremotiondev

.LINK
    https://agentskills.io/specification

.LINK
    Install-FMSkill
#>
function Test-FMSkillManifest {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(
            Mandatory, Position = 0, ValueFromPipeline,
            ValueFromPipelineByPropertyName,
            HelpMessage = 'Literal path to one or more skill folders.'
        )]
        [Alias('PSPath', 'FullName')]
        [ValidateNotNullOrEmpty()]
        [String[]] $LiteralPath
    )

    process {
        foreach ($skillPath in $LiteralPath) {
            $skillDir = Convert-Path -LiteralPath $skillPath -ErrorAction Stop
            $folderName = [Path]::GetFileName(
                [Path]::TrimEndingDirectorySeparator($skillDir))
            $errors = [List[String]]::new()
            $warnings = [List[String]]::new()
            $declaredName = $null
            $description = $null

            $manifestPath = [Path]::Combine($skillDir, 'SKILL.md')
            $frontmatter = $null
            if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
                $errors.Add('SKILL.md not found.')
            }
            else {
                $text = [File]::ReadAllText($manifestPath)
                $match = [regex]::Match(
                    $text,
                    '\A\uFEFF?---[ \t]*\r?\n(?<fm>.*?)\r?\n---[ \t]*(?:\r?\n|\z)',
                    [Text.RegularExpressions.RegexOptions]::Singleline)
                if ($match.Success) {
                    $frontmatter = $match.Groups['fm'].Value
                }
                else {
                    $errors.Add('SKILL.md has no YAML frontmatter block.')
                }
            }

            # PARSE FRONTMATTER ────────────────────────────────────────────────
            if ($null -ne $frontmatter) {
                $lines = $frontmatter -split '\r?\n'
                $keyPattern = '^(?<key>name|description):(?<v>.*)$'
                for ($i = 0; $i -lt $lines.Count; $i++) {
                    if ($lines[$i] -notmatch $keyPattern) { continue }
                    $key = $Matches['key']
                    $value = $Matches['v'].Trim()

                    # Folded (>) and literal (|) block scalars put the value on
                    # the following indented lines; plain and quoted scalars
                    # can also continue onto indented lines. Either way, the
                    # value runs until the next unindented line.
                    $parts = [List[String]]::new()
                    if ($value -notmatch '^[>|][+-]?\d*$') {
                        $parts.Add($value)
                    }
                    while ($i + 1 -lt $lines.Count -and
                        $lines[$i + 1] -match '^(\s|$)') {
                        $i++
                        if ($lines[$i].Trim()) { $parts.Add($lines[$i].Trim()) }
                    }

                    $joined = ($parts -join ' ').Trim()
                    if ($joined -match '^(?<q>["''])(?<inner>.*)\k<q>$') {
                        $joined = $Matches['inner']
                    }

                    if ($key -eq 'name') { $declaredName = $joined }
                    else { $description = $joined }
                }

                if (-not $declaredName) {
                    $errors.Add("Frontmatter has no 'name'.")
                }
                if (-not $description) {
                    $errors.Add("Frontmatter has no 'description'.")
                }
            }

            # SPECIFICATION CHECKS ─────────────────────────────────────────────
            # Each message is built in a variable before .Add(). Inside a .NET
            # method call a comma separates method arguments, so writing
            # .Add($format -f $a, $b) would pass $b to Add() instead of -f.
            if ($declaredName -and $declaredName -cne $folderName) {
                $message = (
                    "Frontmatter name '{0}' does not match folder '{1}'. " +
                    "The Agent Skills spec requires them to match; agents " +
                    "will list the skill as '{0}'."
                ) -f $declaredName, $folderName
                $warnings.Add($message)
            }
            if ($declaredName -and (
                    $declaredName.Length -gt 64 -or
                    $declaredName -cnotmatch '^[a-z0-9]+(-[a-z0-9]+)*$')) {
                $message = (
                    "Name '{0}' is not 1-64 lowercase letters, digits, and " +
                    "single hyphens as the Agent Skills spec requires."
                ) -f $declaredName
                $warnings.Add($message)
            }
            if ($description -and $description.Length -gt 1024) {
                $message = (
                    'Description is {0} characters; the Agent Skills spec ' +
                    'allows 1024. Stricter agents may truncate or reject ' +
                    'the skill.'
                ) -f $description.Length
                $warnings.Add($message)
            }

            [PSCustomObject]@{
                Name              = $folderName
                DeclaredName      = $declaredName
                DescriptionLength = $description ? $description.Length : 0
                IsValid           = $errors.Count -eq 0
                Errors            = $errors.ToArray()
                Warnings          = $warnings.ToArray()
            }
        }
    }
}

<#
.SYNOPSIS
    Mirrors one or more skill folders into a user-level agent skills
    directory.

.DESCRIPTION
    Copies each skill folder to <SkillsRoot>\<skill folder name> with
    robocopy /MIR, so files removed from the repository copy are also
    removed from the installed copy. Only the matching
    <SkillsRoot>\<skill folder name> folder is ever written to. Skills that
    live in SkillsRoot but were not passed in (third-party skills,
    plugin-installed skills, skills created in the agent's own UI) are never
    touched or pruned.

    Before copying, every skill is checked with Test-FMSkillManifest. A
    skill with manifest errors is not installed (Status 'Invalid'); manifest
    warnings are reported once per skill per run and still installed.

    An optional -Preflight script block lets a caller enforce limits that
    only apply to one agent, such as Copilot Cowork's file-count cap. The
    block receives the skill folder path as its first argument and returns
    zero or more reason strings. Any reason marks the skill 'Incompatible'
    and it is not installed on that target.

    SkillsRoot is created if it does not exist. When -RepositoryRoot is
    given, a SkillsRoot inside the repository is refused, because it would
    copy the repository into itself.

.PARAMETER LiteralPath
    Path to one or more skill folders to install. Binds from pipeline
    objects through their FullName or PSPath property, so the output of
    Get-FMSkillFolder and Get-ChildItem can be piped directly. Accepts
    literal paths; wildcards are not expanded.

.PARAMETER Origin
    The repository folder the skill came from, for example 'universal'.
    Used only for reporting; binds from the Origin property emitted by
    Get-FMSkillFolder.

.PARAMETER SkillsRoot
    The agent's user-level skills directory to install into.

.PARAMETER Target
    A label for the agent surface being installed, for example
    'Claude Code' or 'AntigravityCli'. Used only for reporting, which makes
    the results readable when one run installs to several directories.

.PARAMETER RepositoryRoot
    The skills repository root. When given, the function refuses a
    SkillsRoot inside it.

.PARAMETER Preflight
    A script block run for each skill after manifest validation. It
    receives the skill folder path as its first argument and returns the
    reasons, if any, that the skill cannot be installed on this target.

.INPUTS
    System.Management.Automation.PSCustomObject
    Objects with a FullName (and optionally Origin) property, such as the
    output of Get-FMSkillFolder.

    System.IO.DirectoryInfo
    Skill directories piped from Get-ChildItem.

    System.String[]
    Skill folder paths.

.OUTPUTS
    System.Management.Automation.PSCustomObject
    One result per skill with Name, Origin, Target, Source, Destination,
    FilesCopied, FilesRemoved, Status, Warnings, and ErrorMessage. Status
    is one of Updated (files copied or removed), Current, Skipped (-WhatIf
    or declined), Invalid (manifest errors), Incompatible (rejected by
    -Preflight), or Failed (robocopy error).

.EXAMPLE
    Get-FMSkillFolder -LiteralPath . -Folder claude, universal |
        Install-FMSkill -SkillsRoot "$HOME\.claude\skills" -Target Claude

    Installs the Claude and universal skills into Claude Code's user skills
    directory.

.EXAMPLE
    Get-FMSkillFolder -LiteralPath . -Folder grok, universal |
        Install-FMSkill -SkillsRoot "$HOME\.grok\skills" -WhatIf

    Shows what would be mirrored without copying anything.

.EXAMPLE
    $limit = { param($Path) if ((Get-ChildItem $Path -File -Recurse).Count `
        -gt 20) { 'Too many files.' } }
    Get-ChildItem .\universal -Directory |
        Install-FMSkill -SkillsRoot D:\Staging\skills -Preflight $limit

    Installs piped directories, skipping any skill the preflight rejects.

.NOTES
    Requires robocopy, which ships with Windows. robocopy exit codes 0-7
    all mean success (they are a bitmask of "files copied", "extras
    removed", and so on); 8 and above indicate a failure and are reported
    per skill rather than aborting the run.

    $LASTEXITCODE is reset to 0 when the function finishes so a caller
    does not see robocopy's non-zero success bitmask.

.LINK
    https://github.com/futuremotiondev

.LINK
    Get-FMSkillFolder

.LINK
    Test-FMSkillManifest
#>
function Install-FMSkill {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(
            Mandatory, Position = 0, ValueFromPipeline,
            ValueFromPipelineByPropertyName,
            HelpMessage = 'Literal path to one or more skill folders.'
        )]
        [Alias('PSPath', 'FullName')]
        [ValidateNotNullOrEmpty()]
        [String[]] $LiteralPath,

        [Parameter(
            ValueFromPipelineByPropertyName,
            HelpMessage = 'Repository folder the skill came from.'
        )]
        [AllowEmptyString()]
        [String] $Origin = '',

        [Parameter(
            Mandatory,
            HelpMessage = 'User-level skills directory to install into.'
        )]
        [ValidateNotNullOrEmpty()]
        [String] $SkillsRoot,

        [Parameter(HelpMessage = 'Label for the agent surface.')]
        [String] $Target = '',

        [Parameter(HelpMessage = 'Repository root SkillsRoot must avoid.')]
        [String] $RepositoryRoot,

        [Parameter(HelpMessage = 'Per-skill check returning reject reasons.')]
        [ScriptBlock] $Preflight
    )

    begin {
        # robocopy is the copy engine because /MIR gives a true mirror (stale
        # files in the destination are removed) in one call, and it is present
        # on every Windows install. Resolve it up front so a missing binary
        # fails before any skill is half-copied.
        $cmdRobocopy = Get-Command robocopy -CommandType Application `
            -ErrorAction Stop

        $destinationRoot = [Path]::TrimEndingDirectorySeparator(
            [Path]::GetFullPath($SkillsRoot))

        # Compare with a trailing separator on both sides so a sibling such as
        # 'futuremotion-skills-backup' is not mistaken for a folder inside
        # 'futuremotion-skills'.
        if ($RepositoryRoot) {
            $separator = [Path]::DirectorySeparatorChar
            $repoPrefix = [Path]::TrimEndingDirectorySeparator(
                [Path]::GetFullPath($RepositoryRoot)) + $separator
            if (($destinationRoot + $separator).StartsWith(
                    $repoPrefix, [StringComparison]::OrdinalIgnoreCase)) {
                throw ("SkillsRoot must not be inside the repository root " +
                    "(would mirror the repo into itself): $destinationRoot")
            }
        }

        $rootExists = Test-Path -LiteralPath $destinationRoot `
            -PathType Container
        $createAction = 'Create skills directory'
        if (-not $rootExists -and
            $PSCmdlet.ShouldProcess($destinationRoot, $createAction)) {
            $null = New-Item -ItemType Directory -Path $destinationRoot `
                -Force
        }
    }

    process {
        foreach ($skillPath in $LiteralPath) {
            $source = Convert-Path -LiteralPath $skillPath -ErrorAction Stop
            $name = [Path]::GetFileName(
                [Path]::TrimEndingDirectorySeparator($source))
            $destination = [Path]::Combine($destinationRoot, $name)
            $result = [PSCustomObject]@{
                Name         = $name
                Origin       = $Origin
                Target       = $Target
                Source       = $source
                Destination  = $destination
                FilesCopied  = 0
                FilesRemoved = 0
                Status       = 'Skipped'
                Warnings     = [String[]] @()
                ErrorMessage = $null
            }

            # VALIDATE MANIFEST ────────────────────────────────────────────────
            $manifest = Test-FMSkillManifest -LiteralPath $source
            $result.Warnings = $manifest.Warnings
            if ($fmReportedSkills.Add($source)) {
                foreach ($warning in $manifest.Warnings) {
                    Write-Warning "${name}: $warning"
                }
            }

            if (-not $manifest.IsValid) {
                $result.Status = 'Invalid'
                $result.ErrorMessage = $manifest.Errors -join ' '
                Write-Error -Message "${name}: $($result.ErrorMessage)" `
                    -ErrorAction Continue
                $result
                continue
            }

            # TARGET-SPECIFIC LIMITS ───────────────────────────────────────────
            if ($Preflight) {
                $reasons = @(& $Preflight $source | Where-Object { $_ })
                if ($reasons.Count -gt 0) {
                    $result.Status = 'Incompatible'
                    $result.ErrorMessage = $reasons -join ' '
                    Write-Warning ("${name}: not installed on " +
                        "$($Target ? $Target : $destinationRoot). " +
                        $result.ErrorMessage)
                    $result
                    continue
                }
            }

            # MIRROR ───────────────────────────────────────────────────────────
            $action = "Mirror skill '$name'" + ($Origin ? " from $Origin" : '')
            if (-not $PSCmdlet.ShouldProcess($destination, $action)) {
                $result
                continue
            }

            # /MIR mirrors the tree and deletes destination files the source no
            # longer has. /XD .git guards against a skill that carries its own
            # repository: a nested .git must never land in a live skills
            # folder. /NFL /NDL /NJH /NP silence the per-file, per-directory,
            # header, and progress output; the job summary is deliberately
            # kept because its "Files :" line is where the copied count comes
            # from (/NJS would remove it). robocopy returns a bitmask where 0-7
            # are all success states, so the exit code is compared against 8.
            $output = & $cmdRobocopy $source $destination `
                /MIR /XD .git /NFL /NDL /NJH /NP /R:2 /W:1 2>&1
            $exitCode = $LASTEXITCODE

            if ($exitCode -ge 8) {
                $result.Status = 'Failed'
                $result.ErrorMessage = "robocopy exit $exitCode`n" +
                    ($output -join "`n")
                Write-Error -Message $result.ErrorMessage -ErrorAction Continue
                $result
                continue
            }

            # The "Files :" summary line has the form
            #   Files :  Total  Copied  Skipped  Mismatch  FAILED  Extras
            # so the second number is the copied count. Under /MIR, Extras are
            # destination files that were deleted because the source no longer
            # has them; counting them keeps a run that only removed files from
            # being reported as 'Current'.
            $filesLine = $output | Where-Object { $_ -match '^\s*Files\s*:' } |
                Select-Object -First 1
            $countPattern = '^\s*Files\s*:\s*\d+\s+(\d+)(?:\s+\d+){3}\s+(\d+)'
            if ($filesLine -match $countPattern) {
                $result.FilesCopied = [int] $Matches[1]
                $result.FilesRemoved = [int] $Matches[2]
            }

            $changed = $result.FilesCopied + $result.FilesRemoved -gt 0
            $result.Status = $changed ? 'Updated' : 'Current'
            $result
        }
    }

    end {
        # Reset the exit code so a caller checking $LASTEXITCODE does not see
        # robocopy's non-zero success bitmask from the final skill.
        $global:LASTEXITCODE = 0
    }
}

# ENDREGION
