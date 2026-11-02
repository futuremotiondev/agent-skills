@{
    # Target browser, release channel, and minimum version: the
    # machine-readable twin of the Toolchain table in
    # Context/conventions/browser-extension-style.md. Seeded by the
    # firefox-extension adapter with the Release channel and the Firefox 156
    # floor; /fm-init-context-engine switches it to ESR (153) when the project
    # targets enterprise users. Read by
    # Context/scripts/regenerate-manifest-index.ps1. Project-owned: change the
    # channel or floor here, in the manifest's strict_min_version, and in the
    # Toolchain table together (see "Changing channel or raising the floor" in
    # firefox-extension-style.md).
    #
    # Channel    : 'release' or 'esr'
    # MinVersion : the major version the code is written against
    Targets = @(
        @{ Browser = 'firefox'; Channel = 'release'; MinVersion = '156' }
    )
}
