@{
    # Obsidian community plugins, on the public channel (1.13.0+ as seeded, the
    # declarative-settings API) or the Early access channel (1.14.0+). A
    # project's own floor is data: "minAppVersion" in manifest.json and the
    # Channel row of the Toolchain table. The Channels table below holds only
    # the engine's reference floors. Inherits the TypeScript base.
    #
    # NOTE: this adapter, figma-plugin, and the browser-extension family all
    # watch manifest.json, but the formats are unrelated. An Obsidian plugin
    # manifest declares "id" + "minAppVersion" and neither "manifest_version"
    # (WebExtension) nor "editorType"/"api" (Figma). An Obsidian theme manifest
    # has no "id". Only one adapter installs per project.
    Inherits         = 'typescript'
    PrimaryExtension = 'ts'

    # Release channels and their reference floors: engine-side data, never
    # copied into a project. /fm-init-context-engine reads it to seed
    # minAppVersion and the Toolchain table's Channel row from the channel the
    # user picks. Update the floors when the templates are refreshed: when an
    # Early access minor goes public, it becomes the public floor. Seed
    # refreshes do not print floor advisories for this stack (they read only
    # extension-targets.psd1), so a floor move ships as a CHANGELOG "Floor"
    # entry whose Detect pattern matches minAppVersion.
    Channels = @{
        Default        = 'public'
        public         = @{ Label = 'Latest public release'; Floor = '1.13.0' }
        'early-access' = @{ Label = 'Early access (Catalyst)'; Floor = '1.14.0' }
    }

    ConfigDefaults = @{
        PublicSurface = 'A new command, view type, Bases view, settings definition, ribbon icon, status-bar item, Markdown code-block language or post-processor, editor extension, CLI handler, obsidian:// protocol action, or registered file extension; or a change to minAppVersion or isDesktopOnly in manifest.json'
        DirtyHint     = 'Plugin source, styles, or manifest changed without a verifying build. Run the build (see the commands table in CLAUDE.md), reload the plugin in the test vault (obsidian plugin:reload id=<plugin-id>; restart Obsidian after a manifest change), check obsidian dev:errors, then delete .claude/.dirty-marker.'
        # Manifest and style globs come FIRST: only the first matching watch
        # per Action kind fires, so specific hints must win over the generic
        # source hint. Overrides the typescript base wholesale to cover
        # styles.css, plain JavaScript, and the esbuild config.
        Watches       = @(
            @{ Glob = '**/manifest.json'; Action = 'MarkDirty'; Hint = 'Obsidian reads manifest.json at startup: rebuild, restart Obsidian (obsidian restart), then run /refresh-context; a changed minAppVersion also needs a versions.json entry' }
            @{ Glob = '**/*.css';         Action = 'MarkDirty'; Hint = 'reload the plugin (obsidian plugin:reload id=<plugin-id>); styles.css is read when the plugin loads' }
            @{ Glob = '**/*.ts';          Action = 'MarkDirty'; Hint = 'run the build, reload the plugin (obsidian plugin:reload id=<plugin-id>), then check obsidian dev:errors' }
            @{ Glob = '**/*.tsx';         Action = 'MarkDirty'; Hint = 'run the build, reload the plugin (obsidian plugin:reload id=<plugin-id>), then check obsidian dev:errors' }
            @{ Glob = '**/*.js';          Action = 'MarkDirty'; Hint = 'run the build, reload the plugin (obsidian plugin:reload id=<plugin-id>), then check obsidian dev:errors' }
            @{ Glob = '**/*.jsx';         Action = 'MarkDirty'; Hint = 'run the build, reload the plugin (obsidian plugin:reload id=<plugin-id>), then check obsidian dev:errors' }
            @{ Glob = '**/*.mjs';         Action = 'MarkDirty'; Hint = 'the build configuration changed: rebuild and reload the plugin' }
        )
        Regenerators  = @(
            'Context/scripts/regenerate-obsidian-manifest-index.ps1'
        )
    }

    # Refresh metadata (engine-side, never copied; see docs/REFRESHING-STACKS.md):
    # the authoritative pages to re-read when refreshing this stack, and the
    # known time bombs to check every time.
    Sources = @(
        'https://obsidian.md/changelog/'
        'https://github.com/obsidianmd/obsidian-api/commits/master/obsidian.d.ts'
        'https://docs.obsidian.md/Plugins/Releasing/Plugin+guidelines'
        'https://docs.obsidian.md/Developer+policies'
        'https://docs.obsidian.md/Reference/Manifest'
        'https://github.com/obsidianmd/eslint-plugin/releases'
        'https://github.com/obsidianmd/obsidian-sample-plugin'
        'https://help.obsidian.md/cli'
    )
    RefreshChecks = @(
        'Has 1.14 (or a later minor) reached the public channel? Move Channels.public to it and early-access to the next Early access minor, update the version-gated table, and add a Floor entry to CHANGELOG.md.'
        'Did obsidian-api publish typings for a newer minor, and did any @since tag land above the public floor?'
        'Did eslint-plugin-obsidianmd change what its recommended config runs, or which rules the Community directory scan keeps as errors?'
        'Did the Community directory ship plugin access declarations (network, file system, clipboard) or change what blocks a release?'
        'Did the sample plugin change its build tool, target, externals, or release workflow?'
    )
}
