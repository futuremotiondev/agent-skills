@{
    # Python packages and tools.
    PrimaryExtension = 'py'

    ConfigDefaults = @{
        PublicSurface = 'A new public function or class exported from the package''s top-level __init__ (or a new CLI entry point)'
        # No build step -> no default watches; an empty Watches list is a valid
        # answer. Add a Run watch for ruff/pytest only if they're fast and the
        # maintainer wants save-time feedback.
        Watches       = @()
    }

    # Refresh metadata (engine-side, never copied; see docs/REFRESHING-STACKS.md):
    # the authoritative pages to re-read when refreshing this stack, and the
    # known time bombs to check every time.
    Sources = @(
        'https://docs.python.org/3/whatsnew/index.html'
        'https://docs.astral.sh/ruff/'
        'https://docs.astral.sh/uv/'
        'https://packaging.python.org/en/latest/guides/writing-pyproject-toml/'
    )
    RefreshChecks = @(
        'Which Python versions are supported, and does the typing syntax in the doc still work on the oldest one?'
        'Did ruff, uv, or the pyproject.toml guidance change a recommendation the doc repeats?'
    )
}
