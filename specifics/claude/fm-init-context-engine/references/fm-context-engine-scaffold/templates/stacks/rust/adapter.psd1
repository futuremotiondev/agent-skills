@{
    # Rust crates and workspaces built with cargo. Channel / target triple /
    # edition are captured in rust-style.md's Toolchain table, not modelled here.
    PrimaryExtension = 'rs'

    ConfigDefaults = @{
        PublicSurface = 'A new pub item reachable from the crate root (lib.rs), or a new extern "C" export'
        DirtyHint     = 'Rust source or Cargo manifests changed without a verifying build. Run cargo build (or cargo check), then delete .claude/.dirty-marker.'
        # cargo build is slow -> MarkDirty. On a small crate `cargo check` is fast
        # enough to become a Run watch (Command = 'cargo check'); opt in per
        # project rather than by default. build.rs is listed before **/*.rs so
        # its more specific hint wins (first match per Action kind fires).
        Watches       = @(
            @{ Glob = '**/build.rs';   Action = 'MarkDirty'; Hint = 'run cargo build (build scripts re-run at build time)' }
            @{ Glob = '**/*.rs';       Action = 'MarkDirty'; Hint = 'run cargo build (or cargo check) to verify' }
            @{ Glob = '**/Cargo.toml'; Action = 'MarkDirty'; Hint = 'run cargo build to re-resolve dependencies and verify' }
        )
        # No regenerator yet — `cargo public-api` could back one later.
    }

    # Refresh metadata (engine-side, never copied; see docs/REFRESHING-STACKS.md):
    # the authoritative pages to re-read when refreshing this stack, and the
    # known time bombs to check every time.
    Sources = @(
        'https://blog.rust-lang.org/'
        'https://doc.rust-lang.org/edition-guide/'
        'https://rust-lang.github.io/rust-clippy/master/index.html'
    )
    RefreshChecks = @(
        'Is there a new edition, and did a lint the doc names change its default level?'
    )
}
