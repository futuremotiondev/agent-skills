@{
    # Firefox-only Manifest V3 extensions, on the Release channel (Firefox 156+
    # as seeded) or the ESR channel (153+). A project's own floor is data
    # (Context/scripts/extension-targets.psd1 and the Toolchain table); the
    # Channels table below holds only the engine's reference floors. Inherits
    # the browser-neutral browser-extension base,
    # which supplies the shared conventions, the neutral rules, and the
    # manifest-index regenerator. This overlay adds Firefox and AMO facts, and
    # narrows the regenerator to Firefox checks by overriding
    # extension-targets.psd1 at the same path.
    Inherits         = 'browser-extension'
    PrimaryExtension = 'ts'

    # Release channels and their reference floors: engine-side data, never
    # copied into a project. /fm-init-context-engine reads it to seed the
    # Channel and MinVersion in Context/scripts/extension-targets.psd1 from the
    # channel the user picks. Update the floors when the templates are
    # refreshed (ESR moves about once a year; Release every two weeks).
    Channels = @{
        Default = 'release'
        release = @{ Label = 'Latest (Firefox Release)'; Floor = '156' }
        esr     = @{ Label = 'Enterprise (Firefox ESR)'; Floor = '153' }
    }

    ConfigDefaults = @{
        PublicSurface = 'A new message type handled in the background, a new content-script match pattern, or a new manifest-declared capability: a permission, host permission, data-collection type, command, sidebar, or web-accessible resource'
        DirtyHint     = 'Extension source or manifest changed without a verifying build. Run the Firefox build and web-ext lint on its output (see the commands table in CLAUDE.md), reload the extension (web-ext run reloads on change; otherwise use about:debugging), then delete .claude/.dirty-marker.'
        # Manifest globs come FIRST (the first match per Action kind wins).
        # Replaces the base list wholesale: a single-target project has no
        # per-target manifest.*.json files to watch.
        Watches       = @(
            @{ Glob = '**/manifest.json'; Action = 'MarkDirty'; Hint = 'rebuild, run web-ext lint, and reload (a new permission or required data-collection type re-prompts users), then run /refresh-context' }
            @{ Glob = '**/wxt.config.*';  Action = 'MarkDirty'; Hint = 'rebuild for Firefox and run web-ext lint on the output; the generated manifest changes with this config' }
            @{ Glob = '**/*.ts';          Action = 'MarkDirty'; Hint = 'run the Firefox build to verify' }
            @{ Glob = '**/*.tsx';         Action = 'MarkDirty'; Hint = 'run the Firefox build to verify' }
            @{ Glob = '**/*.js';          Action = 'MarkDirty'; Hint = 'run the Firefox build to verify' }
            @{ Glob = '**/*.jsx';         Action = 'MarkDirty'; Hint = 'run the Firefox build to verify' }
        )
        # Regenerators: inherited from browser-extension (per-key last-wins).
    }

    # Refresh metadata (engine-side, never copied; see docs/REFRESHING-STACKS.md):
    # the authoritative pages to re-read when refreshing this stack, and the
    # known time bombs to check every time.
    Sources = @(
        'https://developer.mozilla.org/en-US/docs/Mozilla/Firefox/Releases'
        'https://extensionworkshop.com/documentation/publish/'
        'https://whattrainisitnow.com/calendar/'
    )
    RefreshChecks = @(
        'What are the current Release and ESR versions? Update Channels and the version-gated tables.'
        'Has ESR 140 reached end of life (scheduled for 2026-10-13)?'
        'Is data_collection_permissions still required for new AMO submissions?'
    )
}
