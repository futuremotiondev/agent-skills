@{
    # Target browsers, release channels, and minimum versions: the
    # machine-readable twin of the Toolchain table in
    # Context/conventions/browser-extension-style.md. Read by
    # Context/scripts/regenerate-manifest-index.ps1 to decide which manifest
    # checks apply. Project-owned: edit it when a target is added, a channel
    # changes, or a floor is raised, and update the Toolchain table in the
    # same commit.
    #
    # Browser    : 'chrome' or 'firefox'
    # Channel    : 'stable' or 'extended' for Chrome, 'release' or 'esr' for
    #              Firefox, or '' when not decided yet
    # MinVersion : the major version the code is written against, or '' when
    #              not decided yet (floor checks are then skipped)
    Targets = @(
        @{ Browser = 'chrome';  Channel = ''; MinVersion = '' }
        @{ Browser = 'firefox'; Channel = ''; MinVersion = '' }
    )
}
