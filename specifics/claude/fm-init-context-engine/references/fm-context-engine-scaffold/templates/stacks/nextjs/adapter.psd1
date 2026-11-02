@{
    # Next.js App Router applications. Inherits the web base, which already
    # supplies the route-map regenerator and watches covering next.config.*
    # and every component dialect — so this adapter only narrows the surface
    # and the dirty hint (ConfigDefaults merge is per-key last-wins).
    Inherits         = 'web'
    PrimaryExtension = 'tsx'

    ConfigDefaults = @{
        PublicSurface = 'A new route (page.tsx or route.ts), a new Server Action, or a new exported component in the shared UI layer'
        DirtyHint     = 'Next.js source changed without a verifying build. Run the typecheck and build (e.g. npm run build), then delete .claude/.dirty-marker. If routes changed, run /refresh-context too.'
    }

    # Refresh metadata (engine-side, never copied; see docs/REFRESHING-STACKS.md):
    # the authoritative pages to re-read when refreshing this stack, and the
    # known time bombs to check every time.
    Sources = @(
        'https://nextjs.org/blog'
        'https://nextjs.org/docs/app/guides/upgrading'
    )
    RefreshChecks = @(
        'Did the latest Next.js major change caching defaults, Server Action behavior, or App Router file conventions?'
    )
}
