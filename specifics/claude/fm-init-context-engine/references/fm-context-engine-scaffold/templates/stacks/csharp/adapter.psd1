@{
    # Base adapter for C# class libraries; parent of winui3 / wpf / avalonia.
    PrimaryExtension = 'cs'

    ConfigDefaults = @{
        PublicSurface = 'A new public type or member in the library source (the published API)'
        DirtyHint     = 'C# source changed without a verifying build. Run dotnet build, then delete .claude/.dirty-marker.'
        Watches       = @(
            @{ Glob = '**/*.cs'; Action = 'MarkDirty'; Hint = 'run dotnet build to verify' }
        )
        Regenerators  = @(
            'Context/scripts/regenerate-api-index.ps1'
        )
    }

    # Refresh metadata (engine-side, never copied; see docs/REFRESHING-STACKS.md):
    # the authoritative pages to re-read when refreshing this stack, and the
    # known time bombs to check every time.
    Sources = @(
        'https://learn.microsoft.com/dotnet/csharp/whats-new/'
        'https://learn.microsoft.com/dotnet/core/whats-new/'
        'https://learn.microsoft.com/dotnet/standard/design-guidelines/'
    )
    RefreshChecks = @(
        'Which .NET and C# versions are current, and does a newer built-in replace anything the style doc recommends?'
        'Did the nullable or async analyzers change their defaults?'
    )
}
