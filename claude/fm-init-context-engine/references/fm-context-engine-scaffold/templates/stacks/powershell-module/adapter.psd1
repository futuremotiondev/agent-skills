@{
    # PowerShell 7 modules (the context engine's origin stack).
    PrimaryExtension = 'ps1'

    ConfigDefaults = @{
        PublicSurface = 'A new exported function file under the module''s Public/ tree (one file per function)'
        DirtyHint     = 'Public function files changed. Refresh the module manifest (the module''s build/refresh script), then delete .claude/.dirty-marker.'
        Watches       = @(
            # Seeded as MarkDirty; if the module has a fast manifest-refresh
            # script, switch to Action='Run' with that command (the origin
            # project runs its Build-QuickRefresh.ps1 here).
            @{ Glob = '**/Public/**/*.ps1'; Action = 'MarkDirty'; Hint = 'refresh the module manifest' }
        )
        Regenerators  = @(
            'Context/scripts/regenerate-function-index.ps1'
        )
    }

    # Refresh metadata (engine-side, never copied; see docs/REFRESHING-STACKS.md):
    # the authoritative pages to re-read when refreshing this stack, and the
    # known time bombs to check every time.
    Sources = @(
        'https://learn.microsoft.com/powershell/scripting/whats-new/overview'
        'https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_error_handling'
    )
    RefreshChecks = @(
        'What is the current PowerShell 7 LTS, and did native-command error handling or array += performance change?'
    )
}
