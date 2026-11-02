@{
    # Electron desktop apps. Inherits the TypeScript base adapter
    # (typescript-style.md installs first, then this adapter's files overlay).
    Inherits         = 'typescript'
    PrimaryExtension = 'ts'

    ConfigDefaults = @{
        PublicSurface = 'A new IPC channel (main-process handler + preload exposure) or a new exported renderer-facing API'
        DirtyHint     = 'TypeScript source changed without a verifying typecheck. Run the typecheck/build (e.g. npm run typecheck), then delete .claude/.dirty-marker.'
        Watches       = @(
            @{ Glob = 'src/**/*.ts';  Action = 'MarkDirty'; Hint = 'run the typecheck/build to verify' }
            @{ Glob = 'src/**/*.tsx'; Action = 'MarkDirty'; Hint = 'run the typecheck/build to verify' }
        )
    }

    # Refresh metadata (engine-side, never copied; see docs/REFRESHING-STACKS.md):
    # the authoritative pages to re-read when refreshing this stack, and the
    # known time bombs to check every time.
    Sources = @(
        'https://www.electronjs.org/docs/latest/tutorial/security'
        'https://www.electronjs.org/docs/latest/breaking-changes'
        'https://releases.electronjs.org/'
    )
    RefreshChecks = @(
        'Did Electron change a security default (sandbox, contextIsolation, nodeIntegration) or an IPC API the doc names?'
        'Which Electron versions are still supported?'
    )
}
