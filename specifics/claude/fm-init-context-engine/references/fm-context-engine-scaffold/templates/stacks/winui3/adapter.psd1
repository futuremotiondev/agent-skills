@{
    # WinUI 3 / Windows App SDK desktop apps. Inherits the C# base adapter
    # (csharp-style.md + api-index regenerator install first, then this
    # adapter's files overlay).
    Inherits         = 'csharp'
    PrimaryExtension = 'cs'

    ConfigDefaults = @{
        PublicSurface = 'A new page, control, or public service/ViewModel type in the app source'
        DirtyHint     = 'App source changed without a verifying build. Run dotnet build on the app project, then delete .claude/.dirty-marker.'
        Watches       = @(
            @{ Glob = '**/*.cs';   Action = 'MarkDirty'; Hint = 'run dotnet build to verify' }
            @{ Glob = '**/*.xaml'; Action = 'MarkDirty'; Hint = 'run dotnet build (XAML compiles at build time)' }
        )
        # Regenerators deliberately not overridden — inherits the csharp api-index.
    }

    # Refresh metadata (engine-side, never copied; see docs/REFRESHING-STACKS.md):
    # the authoritative pages to re-read when refreshing this stack, and the
    # known time bombs to check every time.
    Sources = @(
        'https://learn.microsoft.com/windows/apps/windows-app-sdk/'
        'https://learn.microsoft.com/windows/apps/winui/winui3/'
        'https://learn.microsoft.com/dotnet/communitytoolkit/mvvm/'
    )
    RefreshChecks = @(
        'Which Windows App SDK version is current, and do the x:Bind and Window gotchas still hold?'
    )
}
