#Requires -Version 7.1

<#
.SYNOPSIS
    Installs the Microsoft 365 Copilot and universal skills in this
    repository into the OneDrive folder that Copilot Cowork loads personal
    skills from.

.DESCRIPTION
    Scans the 'ms365-copilot' and 'universal' folders of the repository (by
    default the folder this script lives in) for skill directories that
    contain a SKILL.md file and mirrors each one into
    <SkillsRoot>\<skill name>.

    Microsoft 365 Copilot has no local skills directory. Its only per-user
    location is in OneDrive for Business: Copilot Cowork discovers custom
    skills in /Documents/Cowork/skills/<skill>/SKILL.md at the start of
    each session. This script writes to the locally synced copy of that
    folder, <OneDrive for Business>\Documents\Cowork\skills, and the
    OneDrive sync app uploads it. The OneDrive for Business root is read
    from $env:OneDriveCommercial, falling back to the OneDrive Business1
    account in the registry.

    Cowork enforces per-skill limits that the other agents do not. A skill
    that breaks one is reported with Status 'Incompatible' and is not
    copied, because Cowork would reject it anyway:
    - SKILL.md larger than 1 MB.
    - More than 20 companion files (every file other than SKILL.md).
    - More than 10 MB in total.
    Cowork also allows at most 50 custom skills. The script warns when the
    installed and existing skills in the folder together exceed that.

    Both source folders install into the same flat directory, so a skill
    folder name that exists in both is a repository error. The script stops
    before copying anything and names both copies.

    Each skill is mirrored with robocopy /MIR, so files removed from the
    repository copy are also removed from the installed copy. Only the
    matching <SkillsRoot>\<skill name> folder is ever written to. Skills
    created in Cowork's own Customize page live in the same folder and are
    never touched or pruned.

.PARAMETER LiteralPath
    The repository root that contains the 'ms365-copilot' and 'universal'
    folders. Defaults to the directory containing this script. Accepts a
    literal path; wildcards are not expanded.

.PARAMETER SkillsRoot
    The skills directory to install into. Defaults to
    <OneDrive for Business>\Documents\Cowork\skills, resolved from the
    OneDrive sync app. Pass it explicitly when the work account is not
    Business1, when the OneDrive Documents folder has a localized name, or
    to stage a copy elsewhere. Created if it does not exist.

.PARAMETER Exclude
    One or more skill folder names to skip for this run, matched exactly
    (case-insensitive) against the skill's directory name in either source
    folder.

.INPUTS
    None. This script does not accept pipeline input.

.OUTPUTS
    System.Management.Automation.PSCustomObject
    One result per skill folder found with Name, Origin, Target, Source,
    Destination, FilesCopied, FilesRemoved, Status, Warnings, and
    ErrorMessage. Status is 'Incompatible' for skills that exceed Cowork's
    limits.

.EXAMPLE
    .\Install-FuturemotionMS365CopilotSkills.ps1

    Installs every Microsoft 365 Copilot and universal skill that fits
    Cowork's limits into the synced OneDrive Cowork skills folder.

.EXAMPLE
    .\Install-FuturemotionMS365CopilotSkills.ps1 -WhatIf |
        Format-Table Name, Status, ErrorMessage -Wrap

    Shows what would be installed and which skills Cowork would reject,
    without copying anything.

.EXAMPLE
    .\Install-FuturemotionMS365CopilotSkills.ps1 `
        -SkillsRoot 'C:\Users\me\OneDrive - Contoso\Documents\Cowork\skills'

    Installs into an explicit OneDrive folder, for example a second work
    account.

.EXAMPLE
    .\Install-FuturemotionMS365CopilotSkills.ps1 `
        -Exclude fm-git-commit-conventional

    Installs everything except a skill that is of no use in Cowork.

.NOTES
    Requires Windows (robocopy), PowerShell 7.1 or later, and the OneDrive
    sync app signed in with the same work account used for Microsoft 365
    Copilot. The shared install logic lives in
    installer\SkillInstallerCore.ps1, which this script dot-sources.

    Skills reach Cowork only after OneDrive finishes uploading them, and
    Cowork picks them up at the start of the next session. Custom skills are
    not supported in Cowork on mobile.

    This covers Copilot Cowork only. Skills inside declarative agents
    (Agent Builder or the Microsoft 365 Agents Toolkit) are packaged per
    agent, are in preview for Frontier Program tenants, and have no
    user-scoped folder, so they are out of scope for this script.

.LINK
    https://github.com/futuremotiondev

.LINK
    https://learn.microsoft.com/copilot/cowork/use-cowork#cowork-skills

.LINK
    https://learn.microsoft.com/copilot/cowork/cowork-customize#upload-a-skill

.LINK
    Install-FuturemotionClaudeSkills.ps1

.LINK
    Install-FuturemotionChatGPTCodexSkills.ps1

.LINK
    Install-FuturemotionGeminiAntigravitySkills.ps1

.LINK
    Install-FuturemotionGitHubCopilotSkills.ps1

.LINK
    Install-FuturemotionGrokSkills.ps1
#>

using namespace System.IO

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(
        Position = 0,
        HelpMessage = 'Repository root that contains the skill folders.'
    )]
    [Alias('PSPath')]
    [ValidateNotNullOrEmpty()]
    [String] $LiteralPath = $PSScriptRoot,

    [Parameter(HelpMessage = 'Skills directory to install into.')]
    [ValidateNotNullOrEmpty()]
    [String] $SkillsRoot,

    [Parameter(HelpMessage = 'Skill folder names to skip for this run.')]
    [String[]] $Exclude = @()
)

# REGION - SETUP
# ──────────────────────────────────────────────────────────────────────────────

# The helper ships beside this script, so it is located from $PSScriptRoot
# rather than -LiteralPath, which may point at a different checkout.
. ([Path]::Combine($PSScriptRoot, 'installer', 'SkillInstallerCore.ps1'))

# Cowork's documented custom-skill limits (Microsoft Learn, "Use Copilot
# Cowork" > Cowork skills).
$coworkLimits = @{
    ManifestBytes  = 1MB
    CompanionFiles = 20
    SkillBytes     = 10MB
    SkillCount     = 50
}

# ENDREGION

# REGION - RESOLVE ONEDRIVE
# ──────────────────────────────────────────────────────────────────────────────

if ($PSBoundParameters.ContainsKey('SkillsRoot')) {
    $coworkSkillsRoot = $SkillsRoot
}
else {
    # The OneDrive sync app sets OneDriveCommercial for the work account.
    # $env:OneDrive is deliberately not used: it can point at a personal
    # OneDrive, which Cowork never reads. The registry fallback covers a
    # session started before the variable was set.
    $oneDriveRoot = $env:OneDriveCommercial
    if (-not $oneDriveRoot) {
        $accountKey = 'HKCU:\Software\Microsoft\OneDrive\Accounts\Business1'
        $oneDriveRoot = (Get-ItemProperty -LiteralPath $accountKey `
            -Name UserFolder -ErrorAction Ignore).UserFolder
    }

    if (-not $oneDriveRoot -or
        -not (Test-Path -LiteralPath $oneDriveRoot -PathType Container)) {
        throw ("OneDrive for Business is not syncing on this machine, so " +
            "the Cowork skills folder cannot be located. Sign in to the " +
            "OneDrive sync app with your work account, or pass -SkillsRoot.")
    }

    $coworkSkillsRoot = [Path]::Combine(
        $oneDriveRoot, 'Documents', 'Cowork', 'skills')
}

Write-Verbose "Cowork skills folder: $coworkSkillsRoot"

# ENDREGION

# REGION - COWORK LIMITS
# ──────────────────────────────────────────────────────────────────────────────

# Passed to Install-FMSkill as -Preflight, which calls it with the skill
# folder path and skips the skill if it returns any reason. robocopy never
# copies .git folders, so they are left out of the counts. GetNewClosure()
# captures $coworkLimits so the block does not depend on the scope it is
# eventually invoked from.
$coworkPreflight = {
    param([String] $SkillPath)

    $files = @(Get-ChildItem -LiteralPath $SkillPath -File -Recurse -Force |
        Where-Object { $_.FullName -notmatch '[\\/]\.git([\\/]|$)' })
    $manifestPath = [System.IO.Path]::Combine($SkillPath, 'SKILL.md')
    $manifest = $files | Where-Object FullName -eq $manifestPath
    $companionCount = $files.Count - 1
    $totalBytes = ($files | Measure-Object -Property Length -Sum).Sum

    if ($manifest -and $manifest.Length -gt $coworkLimits.ManifestBytes) {
        'SKILL.md is {0:N2} MB; Cowork allows 1 MB.' -f ($manifest.Length / 1MB)
    }
    if ($companionCount -gt $coworkLimits.CompanionFiles) {
        ('{0} companion files; Cowork allows {1} per skill.' -f
            $companionCount, $coworkLimits.CompanionFiles)
    }
    if ($totalBytes -gt $coworkLimits.SkillBytes) {
        ('{0:N2} MB in total; Cowork allows 10 MB per skill.' -f
            ($totalBytes / 1MB))
    }
}.GetNewClosure()

# ENDREGION

# REGION - DISCOVERY
# ──────────────────────────────────────────────────────────────────────────────

$skills = Get-FMSkillFolder -LiteralPath $LiteralPath `
    -Folder 'ms365-copilot', 'universal' -Exclude $Exclude

if (-not $skills) {
    Write-Warning ("No skill folders (directories with SKILL.md) found " +
        "in $LiteralPath")
    return
}

Write-Verbose ("Found {0} skill folder(s) in {1}" -f
    @($skills).Count, $LiteralPath)

# ENDREGION

# REGION - INSTALL
# ──────────────────────────────────────────────────────────────────────────────

# -WhatIf sets $WhatIfPreference for this whole script, and any cmdlet that
# supports ShouldProcess turns into a no-op under it. Tee-Object -Variable and
# ForEach-Object <MemberName> both do, so the results are captured with the
# -OutVariable common parameter and names are read with Select-Object.
$installParams = @{
    SkillsRoot     = $coworkSkillsRoot
    Target         = 'Copilot Cowork'
    RepositoryRoot = $LiteralPath
    Preflight      = $coworkPreflight
    OutVariable    = 'installResults'
}
$skills | Install-FMSkill @installParams

# SKILL COUNT CAP ──────────────────────────────────────────────────────────────
# The 50-skill cap covers every custom skill in the folder, including ones
# created in Cowork itself, so existing folders count too. 'Skipped' results
# are included so -WhatIf predicts the total a real run would reach.
# Names are collected inside @(...) straight from the pipeline. Storing an
# empty pipeline in a variable first would store $null, and @($null) is a
# one-element array that would count as a phantom skill.
$plannedNames = @($installResults |
    Where-Object Status -in 'Updated', 'Current', 'Skipped' |
    Select-Object -ExpandProperty Name)
$existingNames = @()
if (Test-Path -LiteralPath $coworkSkillsRoot -PathType Container) {
    $existingNames = @(
        Get-ChildItem -LiteralPath $coworkSkillsRoot -Directory |
            Where-Object {
                Test-Path -LiteralPath (
                    [Path]::Combine($_.FullName, 'SKILL.md'))
            } |
            Select-Object -ExpandProperty Name)
}

$skillTotal = @($plannedNames + $existingNames | Sort-Object -Unique).Count
if ($skillTotal -gt $coworkLimits.SkillCount) {
    # The whole -f expression is parenthesized: in command mode a bare -f
    # after Write-Warning's argument would be parsed as a parameter name.
    $message = (
        "The Cowork skills folder holds {0} skills; Cowork allows {1}. " +
        "Remove skills or use -Exclude."
    ) -f $skillTotal, $coworkLimits.SkillCount
    Write-Warning $message
}

# ENDREGION
