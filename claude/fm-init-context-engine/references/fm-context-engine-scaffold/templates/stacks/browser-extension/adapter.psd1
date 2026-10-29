@{
    # Manifest V3 browser extensions: the browser-neutral base. Install it
    # directly for an extension that targets more than one browser, or whose
    # target is not decided yet. The single-browser overlays (firefox-extension,
    # chrome-extension) inherit it and add that browser's facts.
    #
    # Everything in this adapter must hold in every MV3 browser, because every
    # file here also lands in the overlays' installs: inheritance is additive,
    # and a child cannot drop a parent file. Browser-specific content belongs in
    # an overlay. The one deliberate exception is the "Adding or changing a
    # target browser" section of browser-extension-style.md.
    #
    # Targets are data: Context/scripts/extension-targets.psd1 (which the
    # overlays override at the same path) tells the shared regenerator which
    # manifest checks to run.
    Inherits         = 'typescript'
    PrimaryExtension = 'ts'

    ConfigDefaults = @{
        PublicSurface = 'A new message type handled in the background, a new content-script match pattern, or a new manifest-declared capability (permission, host permission, command, or web-accessible resource)'
        DirtyHint     = 'Extension source or manifest changed without a verifying build. Run the extension build for every target browser (see the commands table in CLAUDE.md), reload the extension in each, then delete .claude/.dirty-marker.'
        # Manifest globs come FIRST: only the first matching watch per Action
        # kind fires, so the specific manifest hint must win over the generic
        # source hint. Overrides the typescript base wholesale to cover plain
        # JavaScript extensions too.
        Watches       = @(
            @{ Glob = '**/manifest.json';   Action = 'MarkDirty'; Hint = 'rebuild and RELOAD the extension in every target browser (manifest changes are not hot-reloaded, and new permissions re-prompt users), then run /refresh-context' }
            @{ Glob = '**/manifest.*.json'; Action = 'MarkDirty'; Hint = 'rebuild the per-target manifests and reload the extension in each target browser' }
            @{ Glob = '**/wxt.config.*';    Action = 'MarkDirty'; Hint = 'rebuild for every target; the generated manifests change with this config' }
            @{ Glob = '**/*.ts';            Action = 'MarkDirty'; Hint = 'run the extension build to verify' }
            @{ Glob = '**/*.tsx';           Action = 'MarkDirty'; Hint = 'run the extension build to verify' }
            @{ Glob = '**/*.js';            Action = 'MarkDirty'; Hint = 'run the extension build to verify' }
            @{ Glob = '**/*.jsx';           Action = 'MarkDirty'; Hint = 'run the extension build to verify' }
        )
        Regenerators  = @(
            'Context/scripts/regenerate-manifest-index.ps1'
        )
    }

    # Refresh metadata (engine-side, never copied; see docs/REFRESHING-STACKS.md):
    # the authoritative pages to re-read when refreshing this stack, and the
    # known time bombs to check every time.
    Sources = @(
        'https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions'
        'https://developer.chrome.com/docs/extensions/whats-new'
        'https://wxt.dev/'
    )
    RefreshChecks = @(
        'Do Chrome and Firefox still both release every two weeks?'
        'Does WXT still build MV2 for Firefox unless told otherwise?'
        'Has any row of the Chrome/Firefox divergence table become the same in both browsers?'
    )
}
