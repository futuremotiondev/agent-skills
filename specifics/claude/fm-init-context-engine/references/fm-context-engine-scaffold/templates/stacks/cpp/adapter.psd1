@{
    # C++ projects built with CMake (any compiler / generator / package manager —
    # those are captured in cpp-style.md's Toolchain table, not modelled here).
    PrimaryExtension = 'cpp'

    ConfigDefaults = @{
        PublicSurface = 'A new exported function, class, or type declared in a public header (the published API)'
        DirtyHint     = 'C++ source or CMake files changed without a verifying build. Run the configured CMake build (see the commands table in CLAUDE.md), then delete .claude/.dirty-marker.'
        # Native builds are slow -> every watch is MarkDirty, never Run.
        # Globs assume CMake; on Meson / raw MSBuild replace the build-file entries.
        Watches       = @(
            @{ Glob = '**/*.cpp';          Action = 'MarkDirty'; Hint = 'run the CMake build to verify' }
            @{ Glob = '**/*.c';            Action = 'MarkDirty'; Hint = 'run the CMake build to verify' }
            @{ Glob = '**/*.h';            Action = 'MarkDirty'; Hint = 'run the CMake build to verify (a header change may recompile many translation units)' }
            @{ Glob = '**/*.hpp';          Action = 'MarkDirty'; Hint = 'run the CMake build to verify (a header change may recompile many translation units)' }
            @{ Glob = '**/CMakeLists.txt'; Action = 'MarkDirty'; Hint = 're-run the CMake configure + build' }
            @{ Glob = '**/*.cmake';        Action = 'MarkDirty'; Hint = 're-run the CMake configure + build' }
            @{ Glob = 'CMakePresets.json'; Action = 'MarkDirty'; Hint = 're-run the CMake configure + build' }
        )
        # No regenerator yet — a reliable public-header index scanner is a later addition.
    }

    # Refresh metadata (engine-side, never copied; see docs/REFRESHING-STACKS.md):
    # the authoritative pages to re-read when refreshing this stack, and the
    # known time bombs to check every time.
    Sources = @(
        'https://en.cppreference.com/w/cpp/compiler_support'
        'https://cmake.org/cmake/help/latest/release/index.html'
        'https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines'
    )
    RefreshChecks = @(
        'Did CMake deprecate or change a command or policy the doc names?'
        'Does every compiler in a typical Toolchain table support the facilities the doc cites (for example std::expected)?'
    )
}
