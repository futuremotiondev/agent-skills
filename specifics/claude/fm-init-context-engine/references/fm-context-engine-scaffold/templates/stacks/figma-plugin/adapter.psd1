@{
    # Figma plugins (Plugin API) for Figma design, FigJam, Dev Mode, Slides,
    # and Buzz. Inherits the TypeScript base. Covers widgets too — a widget is
    # the same manifest plus @figma/widget-typings and a JSX factory.
    #
    # NOTE: this adapter and the browser-extension family (browser-extension,
    # firefox-extension, chrome-extension) all watch manifest.json, but the
    # two manifests are unrelated formats. A Figma manifest declares
    # "editorType" + "api" + "id"; a WebExtension manifest declares
    # "manifest_version". Only one adapter installs per project.
    Inherits         = 'typescript'
    PrimaryExtension = 'ts'

    ConfigDefaults = @{
        PublicSurface = 'A new menu command, plugin parameter, relaunch button, or message type crossing the main-thread/UI boundary'
        DirtyHint     = 'Plugin source or manifest changed without a verifying build. Run the build, then re-run the plugin in Figma (manifest changes need the plugin re-imported), and delete .claude/.dirty-marker.'
        # Manifest and UI globs come FIRST: only the first matching watch per
        # Action kind fires, so specific hints must win over the generic source
        # hint. Overrides the typescript base wholesale to cover ui.html and
        # plain JavaScript plugins.
        Watches       = @(
            @{ Glob = '**/manifest.json'; Action = 'MarkDirty'; Hint = 'rebuild and RE-IMPORT the plugin in Figma — manifest changes are not picked up by a plain re-run' }
            @{ Glob = '**/*.html';        Action = 'MarkDirty'; Hint = 'rebuild — the UI iframe is inlined into the bundle at build time' }
            @{ Glob = '**/*.ts';          Action = 'MarkDirty'; Hint = 'run the build, then re-run the plugin in Figma to verify' }
            @{ Glob = '**/*.tsx';         Action = 'MarkDirty'; Hint = 'run the build, then re-run the plugin in Figma to verify' }
            @{ Glob = '**/*.js';          Action = 'MarkDirty'; Hint = 'run the build, then re-run the plugin in Figma to verify' }
            @{ Glob = '**/*.jsx';         Action = 'MarkDirty'; Hint = 'run the build, then re-run the plugin in Figma to verify' }
        )
        Regenerators  = @(
            'Context/scripts/regenerate-figma-manifest-index.ps1'
        )
    }

    # Refresh metadata (engine-side, never copied; see docs/REFRESHING-STACKS.md):
    # the authoritative pages to re-read when refreshing this stack, and the
    # known time bombs to check every time.
    Sources = @(
        'https://www.figma.com/plugin-docs/updates/'
        'https://www.figma.com/plugin-docs/manifest/'
    )
    RefreshChecks = @(
        'Is documentAccess "dynamic-page" still required, and did more synchronous APIs become async-only?'
        'Did the manifest gain or change a required field?'
    )
}
