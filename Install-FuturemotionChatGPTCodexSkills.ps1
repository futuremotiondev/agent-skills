#Requires -Version 7.1

<#
.SYNOPSIS
    Installs the ChatGPT / Codex and universal skills in this repository into
    the user-level directory that OpenAI Codex loads skills from.

.DESCRIPTION
    Scans the 'chatgpt-codex' and 'universal' folders of the repository (by
    default the folder this script lives in) for skill directories that
    contain a SKILL.md file and mirrors each one into
    <SkillsRoot>\<skill name>.

    The default SkillsRoot is ~\.agents\skills, the USER scope in OpenAI's
    "Build skills" documentation. Codex CLI, the Codex IDE extension, and
    Codex in the ChatGPT desktop app all read it. OpenAI's documentation no
    longer lists ~\.codex\skills, so this script does not write there;
    writing to both could make Codex load two copies, because Codex does not
    merge skills that share a name.

    Both source folders install into the same flat directory, so a skill
    folder name that exists in both is a repository error. The script stops
    before copying anything and names both copies.

    Each skill is mirrored with robocopy /MIR, so files removed from the
    repository copy are also removed from the installed copy. Only the
    matching <SkillsRoot>\<skill name> folder is ever written to; other
    skills in SkillsRoot are never touched or pruned. Every SKILL.md is
    checked against the Agent Skills specification before it is copied.

.PARAMETER LiteralPath
    The repository root that contains the 'chatgpt-codex' and 'universal'
    folders. Defaults to the directory containing this script. Accepts a
    literal path; wildcards are not expanded.

.PARAMETER SkillsRoot
    The user-level skills directory to install into. Defaults to
    ~\.agents\skills. Created if it does not exist.

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
    .\Install-FuturemotionChatGPTCodexSkills.ps1

    Installs every ChatGPT / Codex and universal skill into
    ~\.agents\skills.

.EXAMPLE
    .\Install-FuturemotionChatGPTCodexSkills.ps1 -WhatIf

    Lists what would be installed without copying anything.

.EXAMPLE
    .\Install-FuturemotionChatGPTCodexSkills.ps1 `
        -SkillsRoot "$HOME\.codex\skills"

    Installs into the legacy ~\.codex\skills directory instead, for an older
    Codex build that predates ~\.agents\skills.

.EXAMPLE
    .\Install-FuturemotionChatGPTCodexSkills.ps1 `
        -Exclude fm-renamer-preset-creator

    Installs everything except the named skill.

.NOTES
    Requires Windows (robocopy) and PowerShell 7.1 or later. The shared
    install logic lives in installer\SkillInstallerCore.ps1, which this
    script dot-sources. Restart Codex after installing so it rescans its
    skills.

    ~\.agents\skills is a vendor-neutral directory, not a Codex-only one.
    Gemini CLI, the Antigravity App and IDE, GitHub Copilot, and Grok Build
    also read it, so every skill this script installs, including the
    Codex-specific ones, also appears in those agents.

    A skill can be switched off in Codex without deleting it through a
    [[skills.config]] entry with enabled = false in ~\.codex\config.toml.

.LINK
    https://github.com/futuremotiondev

.LINK
    https://learn.chatgpt.com/docs/build-skills

.LINK
    Install-FuturemotionClaudeSkills.ps1

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
    [String] $SkillsRoot = [Path]::Combine($HOME, '.agents', 'skills'),

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
    -Folder 'chatgpt-codex', 'universal' -Exclude $Exclude

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

$skills | Install-FMSkill -SkillsRoot $SkillsRoot -Target 'Codex' `
    -RepositoryRoot $LiteralPath

# ENDREGION
