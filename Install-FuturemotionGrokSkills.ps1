#Requires -Version 7.1

<#
.SYNOPSIS
    Installs the Grok and universal skills in this repository into the
    user-level directory that xAI's Grok Build loads skills from.

.DESCRIPTION
    Scans the 'grok' and 'universal' folders of the repository (by default
    the folder this script lives in) for skill directories that contain a
    SKILL.md file and mirrors each one into <SkillsRoot>\<skill name>.

    The default SkillsRoot is the 'skills' folder of the Grok Build home
    directory: $env:GROK_HOME\skills when GROK_HOME is set, otherwise
    ~\.grok\skills, which xAI documents as the user skills location for the
    grok CLI. Installed skills appear as /<skill-name> slash commands.

    Both source folders install into the same flat directory, so a skill
    folder name that exists in both is a repository error. The script stops
    before copying anything and names both copies.

    Each skill is mirrored with robocopy /MIR, so files removed from the
    repository copy are also removed from the installed copy. Only the
    matching <SkillsRoot>\<skill name> folder is ever written to; other
    skills in SkillsRoot are never touched or pruned. Every SKILL.md is
    checked against the Agent Skills specification before it is copied.

.PARAMETER LiteralPath
    The repository root that contains the 'grok' and 'universal' folders.
    Defaults to the directory containing this script. Accepts a literal
    path; wildcards are not expanded.

.PARAMETER SkillsRoot
    The user-level skills directory to install into. Defaults to
    $env:GROK_HOME\skills, or ~\.grok\skills when GROK_HOME is not set.
    Created if it does not exist.

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
    ErrorMessage.

.EXAMPLE
    .\Install-FuturemotionGrokSkills.ps1

    Installs every Grok and universal skill into ~\.grok\skills.

.EXAMPLE
    .\Install-FuturemotionGrokSkills.ps1 -WhatIf

    Lists what would be installed without copying anything.

.EXAMPLE
    .\Install-FuturemotionGrokSkills.ps1 -Exclude fm-renamer-preset-creator

    Installs everything except the named skill.

.EXAMPLE
    .\Install-FuturemotionGrokSkills.ps1 -SkillsRoot 'D:\Staging\grok-skills'

    Mirrors the skills into an alternate directory.

.NOTES
    Requires Windows (robocopy) and PowerShell 7.1 or later. The shared
    install logic lives in installer\SkillInstallerCore.ps1, which this
    script dot-sources.

    Grok Build also reads ~\.agents\skills and, through its Claude
    compatibility layer (on by default), ~\.claude\skills. If the
    ChatGPT / Codex or Claude installers have also been run, Grok sees more
    than one copy of each universal skill and qualifies colliding slash
    commands (for example /local:<name>). To use only this install, set
    skills = false under [compat.claude] in ~\.grok\config.toml, or keep all
    installs on the same repository revision so the copies are identical.

.LINK
    https://github.com/futuremotiondev

.LINK
    https://docs.x.ai/build/features/skills-plugins-marketplaces

.LINK
    Install-FuturemotionClaudeSkills.ps1

.LINK
    Install-FuturemotionChatGPTCodexSkills.ps1

.LINK
    Install-FuturemotionGeminiAntigravitySkills.ps1

.LINK
    Install-FuturemotionGitHubCopilotSkills.ps1

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

    # An empty GROK_HOME is treated as unset; Path.Combine('', 'skills') would
    # otherwise yield a relative 'skills' folder in the current directory.
    [Parameter(HelpMessage = 'User-level skills directory to install into.')]
    [ValidateNotNullOrEmpty()]
    [String] $SkillsRoot = [Path]::Combine(
        $(if ($env:GROK_HOME) { $env:GROK_HOME }
          else { [Path]::Combine($HOME, '.grok') }),
        'skills'),

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

$skills = Get-FMSkillFolder -LiteralPath $LiteralPath `
    -Folder 'grok', 'universal' -Exclude $Exclude

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

$skills | Install-FMSkill -SkillsRoot $SkillsRoot -Target 'Grok Build' `
    -RepositoryRoot $LiteralPath

# ENDREGION
