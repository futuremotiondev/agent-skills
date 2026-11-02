@{
    # Websites and web applications: the framework-independent base. Install it
    # directly for a plain HTML/CSS/Sass site or a client-only SPA, or inherit
    # it from a meta-framework overlay (nextjs, astro, ...).
    #
    # The route-map regenerator lives here rather than in the overlays: every
    # modern meta-framework uses file-based routing, so one script serves them
    # all and degrades to a clear "no file-based routing found" message.
    Inherits         = 'typescript'
    PrimaryExtension = 'ts'

    ConfigDefaults = @{
        PublicSurface = 'A new route or page, a new server endpoint, or a new exported component in the shared UI layer'
        DirtyHint     = 'Web source changed without a verifying build. Run the typecheck/build (and the linter if it gates CI), then delete .claude/.dirty-marker.'
        # Config and route files come FIRST so their specific hints win — only
        # the first matching watch per Action kind fires. Covers every component
        # dialect so a single base serves React, Vue, Svelte, and Astro trees.
        Watches       = @(
            @{ Glob = '**/next.config.*';     Action = 'MarkDirty'; Hint = 'restart the dev server — framework config is read at boot, not hot-reloaded' }
            @{ Glob = '**/astro.config.*';    Action = 'MarkDirty'; Hint = 'restart the dev server — framework config is read at boot, not hot-reloaded' }
            @{ Glob = '**/nuxt.config.*';     Action = 'MarkDirty'; Hint = 'restart the dev server — framework config is read at boot, not hot-reloaded' }
            @{ Glob = '**/svelte.config.*';   Action = 'MarkDirty'; Hint = 'restart the dev server — framework config is read at boot, not hot-reloaded' }
            @{ Glob = '**/vite.config.*';     Action = 'MarkDirty'; Hint = 'restart the dev server — build config is read at boot' }
            @{ Glob = '**/tailwind.config.*'; Action = 'MarkDirty'; Hint = 'rebuild styles (Tailwind v4 projects configure in CSS via @theme instead)' }
            @{ Glob = '**/*.astro';           Action = 'MarkDirty'; Hint = 'run the build; re-run /refresh-context if this added or removed a route' }
            @{ Glob = '**/*.svelte';          Action = 'MarkDirty'; Hint = 'run the typecheck/build to verify' }
            @{ Glob = '**/*.vue';             Action = 'MarkDirty'; Hint = 'run the typecheck/build to verify' }
            @{ Glob = '**/*.tsx';             Action = 'MarkDirty'; Hint = 'run the typecheck/build to verify' }
            @{ Glob = '**/*.jsx';             Action = 'MarkDirty'; Hint = 'run the typecheck/build to verify' }
            @{ Glob = '**/*.ts';              Action = 'MarkDirty'; Hint = 'run the typecheck/build to verify' }
            @{ Glob = '**/*.scss';            Action = 'MarkDirty'; Hint = 'rebuild styles to verify' }
            @{ Glob = '**/*.css';             Action = 'MarkDirty'; Hint = 'rebuild styles to verify' }
        )
        Regenerators  = @(
            'Context/scripts/regenerate-route-map.ps1'
        )
    }

    # Refresh metadata (engine-side, never copied; see docs/REFRESHING-STACKS.md):
    # the authoritative pages to re-read when refreshing this stack, and the
    # known time bombs to check every time.
    Sources = @(
        'https://web.dev/articles/vitals'
        'https://www.w3.org/WAI/standards-guidelines/wcag/'
        'https://tailwindcss.com/docs'
    )
    RefreshChecks = @(
        'Are the Core Web Vitals "good" thresholds unchanged (LCP 2.5 s, INP 200 ms, CLS 0.1)?'
        'Did Tailwind change how it is configured (v4 @theme)?'
        'Is WCAG AA at the version the doc assumes still the usual target?'
    )
}
