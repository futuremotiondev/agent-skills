@{
    # WPF desktop apps. Thin variant of the C# base adapter.
    Inherits         = 'csharp'
    PrimaryExtension = 'cs'

    ConfigDefaults = @{
        PublicSurface = 'A new window, control, or public service/ViewModel type in the app source'
        DirtyHint     = 'App source changed without a verifying build. Run dotnet build on the app project, then delete .claude/.dirty-marker.'
        Watches       = @(
            @{ Glob = '**/*.cs';   Action = 'MarkDirty'; Hint = 'run dotnet build to verify' }
            @{ Glob = '**/*.xaml'; Action = 'MarkDirty'; Hint = 'run dotnet build (XAML compiles at build time)' }
        )
    }

    # Refresh metadata (engine-side, never copied; see docs/REFRESHING-STACKS.md):
    # the authoritative pages to re-read when refreshing this stack, and the
    # known time bombs to check every time.
    Sources = @(
        'https://learn.microsoft.com/dotnet/desktop/wpf/'
        'https://learn.microsoft.com/dotnet/communitytoolkit/mvvm/'
    )
    RefreshChecks = @(
        'Did .NET change a WPF default the doc relies on (binding, theming, Fluent styles)?'
    )
}
