@{
    # Chrome-only Manifest V3 extensions, on the Stable channel (Chrome 154+ as
    # seeded) or the Extended Stable channel (152+). A project's own floor is
    # data (Context/scripts/extension-targets.psd1 and the Toolchain table); the
    # Channels table below holds only the engine's reference floors. Inherits
    # the browser-neutral browser-extension base; this
    # overlay adds service-worker, offscreen, side-panel, and Chrome Web Store
    # facts, and narrows the inherited regenerator to Chrome checks by
    # overriding extension-targets.psd1 at the same path.
    Inherits         = 'browser-extension'
    PrimaryExtension = 'ts'

    # Release channels and their reference floors: engine-side data, never
    # copied into a project. /fm-init-context-engine reads it to seed the
    # Channel and MinVersion in Context/scripts/extension-targets.psd1 from the
    # channel the user picks. Update the floors when the templates are
    # refreshed (Extended Stable moves every eight weeks; Stable every two).
    Channels = @{
        Default  = 'stable'
        stable   = @{ Label = 'Latest (Chrome Stable)'; Floor = '154' }
        extended = @{ Label = 'Enterprise (Chrome Extended Stable)'; Floor = '152' }
    }

    ConfigDefaults = @{
        PublicSurface = 'A new message type handled in the service worker, a new content-script match pattern, a new offscreen-document reason, or a new manifest-declared capability: a permission, host permission, command, side panel, externally_connectable entry, or web-accessible resource'
        DirtyHint     = 'Extension source or manifest changed without a verifying build. Run the Chrome build (see the commands table in CLAUDE.md), reload the extension at chrome://extensions (a manifest change needs the reload; refresh open tabs to re-inject content scripts), then delete .claude/.dirty-marker.'
        # Manifest globs come FIRST (the first match per Action kind wins).
        # Replaces the base list wholesale: a single-target project has no
        # per-target manifest.*.json files to watch.
        Watches       = @(
            @{ Glob = '**/manifest.json'; Action = 'MarkDirty'; Hint = 'rebuild and reload at chrome://extensions (a new permission with a warning disables the extension for existing users until they accept, and needs a Privacy practices justification), then run /refresh-context' }
            @{ Glob = '**/wxt.config.*';  Action = 'MarkDirty'; Hint = 'rebuild for Chrome; the generated manifest changes with this config' }
            @{ Glob = '**/*.ts';          Action = 'MarkDirty'; Hint = 'run the Chrome build to verify' }
            @{ Glob = '**/*.tsx';         Action = 'MarkDirty'; Hint = 'run the Chrome build to verify' }
            @{ Glob = '**/*.js';          Action = 'MarkDirty'; Hint = 'run the Chrome build to verify' }
            @{ Glob = '**/*.jsx';         Action = 'MarkDirty'; Hint = 'run the Chrome build to verify' }
        )
        # Regenerators: inherited from browser-extension (per-key last-wins).
    }

    # Refresh metadata (engine-side, never copied; see docs/REFRESHING-STACKS.md):
    # the authoritative pages to re-read when refreshing this stack, and the
    # known time bombs to check every time.
    Sources = @(
        'https://developer.chrome.com/docs/extensions/whats-new'
        'https://developer.chrome.com/docs/webstore/program-policies'
        'https://chromiumdash.appspot.com/schedule'
    )
    RefreshChecks = @(
        'Is the "rolling out gradually" caveat on Promise-returning onMessage listeners still in the messaging docs?'
        'Has the Chrome Web Store API v1 end date (2026-10-15) passed?'
        'Which milestone is Extended Stable on? Update Channels.'
    )
}
