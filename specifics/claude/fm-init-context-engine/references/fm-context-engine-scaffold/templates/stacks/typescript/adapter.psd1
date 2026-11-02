@{
    # TypeScript libraries, tools, and Node packages; base for every TypeScript
    # app adapter (electron, browser-extension). A child that also ships plain
    # JavaScript overrides Watches wholesale to cover .js/.jsx as well.
    PrimaryExtension = 'ts'

    ConfigDefaults = @{
        PublicSurface = 'A new exported symbol from the package entry point (the published API surface)'
        DirtyHint     = 'TypeScript source changed without a verifying typecheck. Run the typecheck/build (e.g. npm run typecheck), then delete .claude/.dirty-marker.'
        Watches       = @(
            @{ Glob = '**/*.ts';  Action = 'MarkDirty'; Hint = 'run the typecheck/build to verify' }
            @{ Glob = '**/*.tsx'; Action = 'MarkDirty'; Hint = 'run the typecheck/build to verify' }
        )
        # No regenerator — a reliable exported-symbol index needs the TS compiler
        # API; a child adapter with machine-readable surface can supply its own.
    }

    # Refresh metadata (engine-side, never copied; see docs/REFRESHING-STACKS.md):
    # the authoritative pages to re-read when refreshing this stack, and the
    # known time bombs to check every time.
    Sources = @(
        'https://www.typescriptlang.org/docs/handbook/release-notes/overview.html'
        'https://devblogs.microsoft.com/typescript/'
        'https://typescript-eslint.io/rules/no-floating-promises/'
    )
    RefreshChecks = @(
        'Did a TypeScript release change what strict mode or the recommended extra flags cover?'
        'Has the native (Go) compiler changed a tsconfig default this document relies on?'
    )
}
