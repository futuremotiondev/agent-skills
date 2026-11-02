@{
    # Avalonia cross-platform desktop apps. Thin variant of the C# base adapter.
    Inherits         = 'csharp'
    PrimaryExtension = 'cs'

    ConfigDefaults = @{
        PublicSurface = 'A new view, control, or public service/ViewModel type in the app source'
        DirtyHint     = 'App source changed without a verifying build. Run dotnet build on the app project, then delete .claude/.dirty-marker.'
        Watches       = @(
            @{ Glob = '**/*.cs';    Action = 'MarkDirty'; Hint = 'run dotnet build to verify' }
            @{ Glob = '**/*.axaml'; Action = 'MarkDirty'; Hint = 'run dotnet build (AXAML compiles at build time)' }
        )
    }

    # Refresh metadata (engine-side, never copied; see docs/REFRESHING-STACKS.md):
    # the authoritative pages to re-read when refreshing this stack, and the
    # known time bombs to check every time.
    Sources = @(
        'https://docs.avaloniaui.net/'
        'https://github.com/AvaloniaUI/Avalonia/releases'
    )
    RefreshChecks = @(
        'Which Avalonia version is current, and did compiled bindings, x:DataType, or the platform markup extensions change?'
    )
}
