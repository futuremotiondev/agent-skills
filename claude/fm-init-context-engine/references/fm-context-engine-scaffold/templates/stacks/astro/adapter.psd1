@{
    # Astro sites. Inherits the web base, which already supplies the route-map
    # regenerator (it reports each page's client islands) and watches covering
    # astro.config.* and *.astro — so this adapter only narrows the surface and
    # the dirty hint (ConfigDefaults merge is per-key last-wins).
    Inherits         = 'web'
    PrimaryExtension = 'astro'

    ConfigDefaults = @{
        PublicSurface = 'A new page or endpoint under src/pages/, a new content collection or schema field, or a new exported component'
        DirtyHint     = 'Astro source changed without a verifying build. Run astro check and the build, then delete .claude/.dirty-marker. If routes or collections changed, run /refresh-context too.'
    }

    # Refresh metadata (engine-side, never copied; see docs/REFRESHING-STACKS.md):
    # the authoritative pages to re-read when refreshing this stack, and the
    # known time bombs to check every time.
    Sources = @(
        'https://astro.build/blog/'
        'https://docs.astro.build/en/reference/directives-reference/'
    )
    RefreshChecks = @(
        'Did Astro add, rename, or change a client:* or server:* directive, or change content collections?'
    )
}
