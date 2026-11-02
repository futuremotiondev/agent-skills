@{
    # Target browser, release channel, and minimum version: the
    # machine-readable twin of the Toolchain table in
    # Context/conventions/browser-extension-style.md. Seeded by the
    # chrome-extension adapter with the Stable channel and the Chrome 154
    # floor; /fm-init-context-engine switches it to Extended Stable (152) when
    # the project targets enterprise users. Read by
    # Context/scripts/regenerate-manifest-index.ps1. Project-owned: change the
    # channel or floor here, in the manifest's minimum_chrome_version, and in
    # the Toolchain table together (see "Changing channel or raising the
    # floor" in chrome-extension-style.md).
    #
    # Channel    : 'stable' or 'extended'
    # MinVersion : the major version the code is written against
    Targets = @(
        @{ Browser = 'chrome'; Channel = 'stable'; MinVersion = '154' }
    )
}
