#Requires -Version 7.1

<#
.SYNOPSIS
    Installs the Gemini / Antigravity and universal skills in this repository
    into the user-level skill directories of Gemini CLI and Google
    Antigravity.

.DESCRIPTION
    Scans the 'gemini-antigravity' and 'universal' folders of the repository
    (by default the folder this script lives in) for skill directories that
    contain a SKILL.md file and mirrors each one into every selected target
    directory as <target>\<skill name>.

    Google's agent surfaces do not share a user skills directory, so one
    copy cannot serve all of them. -Target picks which to install:

    GeminiCli       ~\.gemini\skills
                    Gemini CLI user skills.
    AntigravityApp  ~\.gemini\config\skills
                    Antigravity App, and Antigravity IDE (which reads the
                    App paths plus a legacy folder this script does not use).
    AntigravityCli  ~\.gemini\antigravity-cli\skills
                    The Antigravity CLI (agy). It does not read the App path
                    or ~\.agents\skills, so it needs its own copy.

    All three are installed by default. Passing -SkillsRoot replaces them
    with a single custom directory.

    Both source folders install into the same flat directory, so a skill
    folder name that exists in both is a repository error. The script stops
    before copying anything and names both copies.

    Each skill is mirrored with robocopy /MIR, so files removed from the
    repository copy are also removed from the installed copy. Only the
    matching <target>\<skill name> folder is ever written to; other skills in
    a target directory are never touched or pruned. Every SKILL.md is checked
    against the Agent Skills specification before it is copied; manifest
    warnings are reported once per skill rather than once per target.

.PARAMETER LiteralPath
    The repository root that contains the 'gemini-antigravity' and
    'universal' folders. Defaults to the directory containing this script.
    Accepts a literal path; wildcards are not expanded.

.PARAMETER Target
    One or more agent surfaces to install into: GeminiCli, AntigravityApp,
    AntigravityCli. Defaults to all three. Ignored when -SkillsRoot is
    given.

.PARAMETER SkillsRoot
    A single custom skills directory to install into instead of the -Target
    directories. Created if it does not exist.

.PARAMETER Exclude
    One or more skill folder names to skip for this run, matched exactly
    (case-insensitive) against the skill's directory name in either source
    folder.

.INPUTS
    None. This script does not accept pipeline input.

.OUTPUTS
    System.Management.Automation.PSCustomObject
    One result per skill per target with Name, Origin, Target, Source,
    Destination, FilesCopied, FilesRemoved, Status, Warnings, and
    ErrorMessage.

.EXAMPLE
    .\Install-FuturemotionGeminiAntigravitySkills.ps1

    Installs every Gemini / Antigravity and universal skill into all three
    target directories.

.EXAMPLE
    .\Install-FuturemotionGeminiAntigravitySkills.ps1 -Target AntigravityCli

    Installs only for the Antigravity CLI.

.EXAMPLE
    .\Install-FuturemotionGeminiAntigravitySkills.ps1 -WhatIf |
        Format-Table Target, Name, Status

    Lists what would be installed on each surface without copying anything.

.EXAMPLE
    .\Install-FuturemotionGeminiAntigravitySkills.ps1 `
        -SkillsRoot 'D:\Staging\gemini-skills'

    Mirrors the skills into one alternate directory.

.NOTES
    Requires Windows (robocopy) and PowerShell 7.1 or later. The shared
    install logic lives in installer\SkillInstallerCore.ps1, which this
    script dot-sources. In Gemini CLI, run /skills reload (or restart) after
    installing.

    Gemini CLI also reads ~\.agents\skills, and that alias takes precedence
    over ~\.gemini\skills. If Install-FuturemotionChatGPTCodexSkills.ps1 has
    also been run, Gemini CLI uses the ~\.agents\skills copy of any skill
    present in both; keep both installs on the same repository revision.
    The Antigravity App also reads ~\.agents\skills.

.LINK
    https://github.com/futuremotiondev

.LINK
    https://antigravity.google/docs/skills

.LINK
    Install-FuturemotionClaudeSkills.ps1

.LINK
    Install-FuturemotionChatGPTCodexSkills.ps1

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

    [Parameter(HelpMessage = 'Agent surfaces to install into.')]
    [ValidateSet('GeminiCli', 'AntigravityApp', 'AntigravityCli')]
    [String[]] $Target = @('GeminiCli', 'AntigravityApp', 'AntigravityCli'),

    [Parameter(HelpMessage = 'Single custom directory to install into.')]
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

# Each surface's user skills directory, per Google's Gemini CLI and
# Antigravity documentation. The legacy ~\.gemini\antigravity\skills folder
# is deliberately absent: the IDE still reads it, but it also reads the App
# path, so installing there too would load every skill twice.
$targetRoots = [ordered]@{
    GeminiCli      = [Path]::Combine($HOME, '.gemini', 'skills')
    AntigravityApp = [Path]::Combine($HOME, '.gemini', 'config', 'skills')
    AntigravityCli = [Path]::Combine(
        $HOME, '.gemini', 'antigravity-cli', 'skills')
}

if ($PSBoundParameters.ContainsKey('SkillsRoot')) {
    $installTargets = [ordered]@{ Custom = $SkillsRoot }
}
else {
    $installTargets = [ordered]@{}
    foreach ($targetName in ($Target | Select-Object -Unique)) {
        $installTargets[$targetName] = $targetRoots[$targetName]
    }
}

# ENDREGION

# REGION - DISCOVERY
# ──────────────────────────────────────────────────────────────────────────────

$skills = Get-FMSkillFolder -LiteralPath $LiteralPath `
    -Folder 'gemini-antigravity', 'universal' -Exclude $Exclude

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

foreach ($entry in $installTargets.GetEnumerator()) {
    Write-Verbose "Installing for $($entry.Key) into $($entry.Value)"
    $skills | Install-FMSkill -SkillsRoot $entry.Value -Target $entry.Key `
        -RepositoryRoot $LiteralPath
}

# ENDREGION
