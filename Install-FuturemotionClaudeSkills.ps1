#Requires -Version 7.1

<#
.SYNOPSIS
    Installs the Claude-specific and universal skills in this repository into
    the user-level Claude Code skills directory.

.DESCRIPTION
    Scans the 'claude' and 'universal' folders of the repository (by default
    the folder this script lives in) for skill directories that contain a
    SKILL.md file and mirrors each one into <SkillsRoot>\<skill name>.
    Nothing is hardcoded: adding a skill folder to either source folder is
    enough for the next run to pick it up.

    Both source folders install into the same flat directory, so a skill
    folder name that exists in both is a repository error. The script stops
    before copying anything and names both copies.

    Each skill is mirrored with robocopy /MIR, so files removed from the
    repository copy are also removed from the installed copy. Only the
    matching <SkillsRoot>\<skill name> folder is ever written to. Skills that
    live in <SkillsRoot> but not in this repository (third-party skills,
    plugin-installed skills) are never touched or pruned.

    Every SKILL.md is checked against the Agent Skills specification before
    it is copied. Missing frontmatter, name, or description stops that one
    skill; a name that differs from its folder or an over-long description
    is reported as a warning and still installed.

    Dotted directories (.old, .git, .claude, .vscode, ...) are always
    skipped, which is how retired skills parked under .old\ stay out of the
    install.

.PARAMETER LiteralPath
    The repository root that contains the 'claude' and 'universal' folders.
    Defaults to the directory containing this script, which is the normal
    case. Accepts a literal path; wildcards are not expanded.

.PARAMETER SkillsRoot
    The user-level skills directory to install into. Defaults to
    ~\.claude\skills, which is where Claude Code loads user skills from.
    Created if it does not exist.

.PARAMETER Exclude
    One or more skill folder names to skip for this run, matched exactly
    (case-insensitive) against the skill's directory name in either source
    folder. Useful for holding back a skill that is mid-edit.

.INPUTS
    None. This script does not accept pipeline input.

.OUTPUTS
    System.Management.Automation.PSCustomObject
    One result per skill folder found with Name, Origin, Target, Source,
    Destination, FilesCopied, FilesRemoved, Status, Warnings, and
    ErrorMessage.

.EXAMPLE
    .\Install-FuturemotionClaudeSkills.ps1

    Installs every Claude-specific and universal skill into
    ~\.claude\skills.

.EXAMPLE
    .\Install-FuturemotionClaudeSkills.ps1 -WhatIf

    Lists what would be installed without copying anything.

.EXAMPLE
    .\Install-FuturemotionClaudeSkills.ps1 -Exclude fm-init-context-engine

    Installs everything except the named skill.

.EXAMPLE
    .\Install-FuturemotionClaudeSkills.ps1 -SkillsRoot 'D:\Backup\claude-skills'

    Mirrors the skills into an alternate directory, for example to stage a
    copy for another machine.

.NOTES
    Requires Windows (robocopy) and PowerShell 7.1 or later. The shared
    install logic lives in installer\SkillInstallerCore.ps1, which this
    script dot-sources.

    Deployment is a plain copy: Claude Code reads the installed copy, not
    this repository, so re-run this script after editing a skill. Skills
    moved between the 'claude' and 'universal' folders keep the same
    destination folder, so a move needs no cleanup.

    Other agents also read ~\.claude\skills: GitHub Copilot in VS Code and
    Grok Build (through its default-on Claude compatibility layer). Skills
    installed here therefore also appear there.

.LINK
    https://github.com/futuremotiondev

.LINK
    Install-FuturemotionChatGPTCodexSkills.ps1

.LINK
    Install-FuturemotionGeminiAntigravitySkills.ps1

.LINK
    Install-FuturemotionGitHubCopilotSkills.ps1

.LINK
    Install-FuturemotionGrokSkills.ps1

.LINK
    Install-FuturemotionMS365CopilotSkills.ps1
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

    [Parameter(HelpMessage = 'User-level skills directory to install into.')]
    [ValidateNotNullOrEmpty()]
    [String] $SkillsRoot = [Path]::Combine($HOME, '.claude', 'skills'),

    [Parameter(HelpMessage = 'Skill folder names to skip for this run.')]
    [String[]] $Exclude = @()
)

# REGION - SETUP
# ──────────────────────────────────────────────────────────────────────────────

# The helper ships beside this script, so it is located from $PSScriptRoot
# rather than -LiteralPath, which may point at a different checkout.
. ([Path]::Combine($PSScriptRoot, 'installer', 'SkillInstallerCore.ps1'))

# ENDREGION

# REGION - DISCOVERY
# ──────────────────────────────────────────────────────────────────────────────

# 'claude' is scanned first so a collision message lists the Claude copy
# first; the order has no other effect because collisions stop the run.
$skills = Get-FMSkillFolder -LiteralPath $LiteralPath `
    -Folder 'claude', 'universal' -Exclude $Exclude

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

$skills | Install-FMSkill -SkillsRoot $SkillsRoot -Target 'Claude Code' `
    -RepositoryRoot $LiteralPath

# ENDREGION
