@{
    # ─────────────────────────────────────────────────────────────────────────
    # context-engine per-project configuration
    #
    # This file is PROJECT-OWNED: /fm-init-context-engine authors it once and the
    # maintainer edits it freely afterward. A plain engine update only bumps
    # EngineVersion. A seed refresh (Update-ContextEngine.ps1 -RefreshSeeds)
    # also merges in changed adapter defaults (Watches, Regenerators,
    # DirtyHint, PublicSurface), key by key, keeping every value set here.
    # The engine-owned scripts (.claude/hooks/*.ps1) and the context-keeper
    # skill read their project-specific values from here.
    # ─────────────────────────────────────────────────────────────────────────

    # Engine template version this project was scaffolded from.
    EngineVersion = '{{ENGINE_VERSION}}'

    # ── PostToolUse watches (read by hooks/post-edit-watch.ps1) ──────────────
    # Each entry: Glob (repo-relative; ** spans dirs, * within a segment) plus
    #   Action = 'Run'       -> Command (executed immediately from repo root),
    #                           optional Message (success text)
    #   Action = 'MarkDirty' -> optional Hint (what to run later); appends to
    #                           .claude/.dirty-marker, surfaced at next session
    # First matching watch per Action kind fires. Empty list = hook is a no-op.
    Watches = @(
        # @{ Glob = 'src/**/*.cs'; Action = 'MarkDirty'; Hint = 'run dotnet build to verify' }
        # @{ Glob = 'src/**/*.ts'; Action = 'Run'; Command = 'npm run typecheck'; Message = 'typecheck passed' }
    )

    # Custom text for the session-start "stale build output" nudge shown while
    # .claude/.dirty-marker exists. Empty = generic default text.
    DirtyHint = ''

    # ── Regenerators (read by /refresh-context) ──────────────────────────────
    # Repo-relative paths to Context/scripts/*.ps1 regenerators. Each writes
    # one artifact into Context/generated/. See Context/scripts/README.md for
    # the contract. Empty list = /refresh-context reports nothing configured.
    Regenerators = @(
        # 'Context/scripts/regenerate-api-index.ps1'
    )

    # ── Public surface definition (read by the context-keeper skill) ─────────
    # One sentence describing what counts as "new public surface" in this
    # project — the trigger for context-keeper Operation A. Examples:
    #   'A new exported function file under Module/Public/<Category>/'
    #   'A new public type or member in src/MyLib/ (the published API)'
    #   'A new IPC channel registered in src/main/ipc/ or a new preload export'
    #   'A new public function or class in the package''s top-level __init__ exports'
    PublicSurface = '{{PUBLIC_SURFACE}}'

    # ── Seed refresh opt-outs (read by Update-ContextEngine.ps1) ─────────────
    # Repo-relative globs (same semantics as Watches) of seeded files this
    # project owns outright: a seed refresh never merges into them and only
    # reports when the engine's template changes. Example:
    #   'Context/conventions/typescript-style.md'
    SeedRefreshExclude = @(
    )
}
