---
name: fm-powershell-file-processing
description: >
  PowerShell 7 function creation for batch file/directory processing. Use this skill
  whenever the user asks to create, write, or scaffold a PowerShell function that processes
  files or folders — including conversion, renaming, extraction, transformation, or any
  operation that iterates over filesystem paths. Also trigger when the user mentions
  begin/process/end block architecture, ForEach-Object -Parallel for file operations,
  LiteralPath parameters, or building PowerShell wrappers around external CLI tools
  (e.g., ImageMagick, ffmpeg, rsvg-convert, ftcli). Trigger even if the user just says
  "write me a PS7 function to batch-convert fonts" or similar shorthand requests.
---

# PowerShell 7 File/Directory Processing Functions

Target: **PowerShell 7.4+, Windows only.** Do not target Windows PowerShell 5.

Before writing code, use Context7, deepwiki, ref, or other documentation MCP tools to
retrieve the latest PowerShell 7 docs and release notes for any cmdlets or .NET APIs used.

## Architecture: begin → process (collect) → end (work)

All file/directory processing happens in the **end** block. The process block only
validates and accumulates paths — it never does real work.

```text
begin {
    1. Declare using-namespaces at the top of the file (System.Collections.Generic, etc.)
    2. Store external commands via Get-Command → $cmd* variable
    3. Define $valid* collections for extension/type filtering
    4. Initialize List<string> collections ($resolved*) for validated paths
}

process {
    1. Verify each path exists (Test-Path)
    2. Resolve to full path via $PSCmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath()
    3. Get-Item to inspect type (file vs directory) and extension
    4. Filter and accumulate into $resolved* collections
    5. Skip invalid items with Write-Error -ErrorAction Continue
}

end {
    1. Validate/create output directories if needed
    2. Build parameter arrays or splats for external calls
    3. Process via ForEach-Object -Parallel (or sequential foreach when parallel is inappropriate)
    4. Check $LASTEXITCODE after external process calls
    5. Deactivate Python venvs or perform other cleanup if applicable
}
```

> **Exception:** Functions that do NOT process files/directories should do their work in
> the `process` block per standard idiomatic PowerShell.

## Naming Conventions

| Element              | Convention                                  | Example                       |
|----------------------|---------------------------------------------|-------------------------------|
| Function name        | `Verb-Noun` with approved verb (`Get-Verb`) | `Convert-FontFormat`          |
| Helper function      | `Internal-*` verb                           | `Internal-BuildArgList`       |
| Parameters           | PascalCase                                  | `$LiteralPath`, `$MaxThreads` |
| Local variables      | camelCase, strongly typed                   | `[string] $outputDir`         |
| Resolved-path lists  | `$resolved*` prefix                         | `$resolvedFonts`              |
| Command variables    | `$cmd*` prefix                              | `$cmdMagick`                  |
| Valid-extension sets | `$valid*` prefix                            | `$validExtensions`            |

## Coding Standards

- Every function is an **advanced function** with `[CmdletBinding()]`.
- Add `using namespace` statements at the **top of the file** (not inside the function) for
  any System namespaces used. Omit namespace prefixes in code after declaring them.
- **CRITICAL — `using namespace` does NOT work for external assembly types in modules.**
  When a `.ps1` file is dot-sourced inside a `.psm1`, `using namespace` resolves at parse
  time within the file, but `[OutputType()]` and other attribute type arguments are resolved
  at *invocation time* in the *module's* scope — where the `using namespace` no longer
  exists. This causes `Unable to find type [ShortTypeName]` errors at runtime. **Always use
  fully-qualified type names** for types from external DLLs (loaded via `RequiredAssemblies`
  or `Add-Type`). `using namespace System.*` is fine because those are always loaded.

  ```powershell
  # WRONG — fails at runtime when dot-sourced in a module:
  using namespace MyLib.Schemas
  function Get-Thing {
      [OutputType([MyResult])]        # Unable to find type [MyResult]
      param() ...
  }

  # CORRECT — always works:
  function Get-Thing {
      [OutputType([MyLib.Schemas.MyResult])]
      param() ...
      $r = [MyLib.Schemas.MyResult]::new()
  }
  ```

- Use `LiteralPath` (never `Path`) as the primary path parameter.
- Add `Write-Verbose` at all critical processing steps.
- Add inline comments at non-obvious logic.
- Max line length: **80 characters.** Use splats or line breaks for long calls.
- Prefer .NET over cmdlets for performance:
  - `[IO.Path]::Combine()` over `Join-Path`
  - `[Diagnostics.Stopwatch]::StartNew()` over `Measure-Command`
  - `[Regex]::new(pattern, 'Compiled')` over `-match`/`-replace`
  - `[List[string]]::new()` over `[string[]]` with `+=`
  - `[HashSet[string]]` when deduplication is needed
- Define external commands in `begin` using `Get-Command`:

  ```powershell
  $cmdMagick = Get-Command "C:\BIN\ImageMagick\magick.exe" -CommandType Application -ErrorAction Stop
  ```

- Always create splats for calls with 3+ parameters.

## Core Parameters

### LiteralPath (required for all file/dir functions)

```powershell
[Parameter(
    Mandatory = $true,
    Position = 0,
    ValueFromPipeline,
    ValueFromPipelineByPropertyName,
    HelpMessage = "One or more file or directory paths to process."
)]
[Alias('PSPath')]
[ValidateNotNullOrEmpty()]
[string[]] $LiteralPath
```

Rules: always `Mandatory`, always `Position = 0`, always aliased `PSPath`, always
`ValidateNotNullOrEmpty()`. Add domain aliases when useful (e.g., `'FontPath'`).

### MaxThreads (required when using ForEach-Object -Parallel)

```powershell
[Parameter(
    ValueFromPipelineByPropertyName,
    HelpMessage = "The amount of threads to use for parallel processing."
)]
[ValidateRange(1, [int]::MaxValue)]
[int] $MaxThreads = [Math]::Max(1, [int]([Environment]::ProcessorCount * 0.75))
```

Rules: always the **last** parameter. Default to 75% of cores. Adjust the default only
when the function's context demands it (e.g., lower for rate-limited downloads, higher
for CPU-light I/O work). Always include `HelpMessage`.

### All Other Parameters

- Include `[Parameter()]` block with `ValueFromPipelineByPropertyName` and `HelpMessage`.
- Always place `ValueFromPipelineByPropertyName` and `HelpMessage` on separate indented lines within the parameter block. Example:

    ```powershell
    [Parameter(
        ValueFromPipelineByPropertyName,
        HelpMessage = "An informative help message goes here."
    )]
    [Int] $SomeInteger = 0,
    ```

- Omit `Mandatory = $false` (it's the default).
- Place type and name on the **same line**: `[string[]] $ValidExtensions`
- Separate `=` in attributes with spaces: `Mandatory = $true` (not `Mandatory=$true`).
- Add `[switch] $Recurse` when recursive directory traversal makes sense.

For the full parameter validation catalog (ValidateSet, ValidateRange, ValidatePattern,
ArgumentCompleter, etc.), read `references/parameter-guide.md`.

## Reference Files

Read these on demand — do not load them all upfront.

| File                               | When to read                                                                                                 |
|------------------------------------|--------------------------------------------------------------------------------------------------------------|
| `references/template.ps1`          | When scaffolding a new function — use as the starting skeleton                                               |
| `references/examples-real.md`      | When writing a new function — review for style, naming, and structure patterns from real FMDevToolbox code   |
| `references/examples-synthetic.md` | When writing a new function — review for architecture variant patterns (parallel, sequential, pipeline-only) |
| `references/parameter-guide.md`    | When adding validation attributes, ArgumentCompleters, or complex parameter definitions                      |
| `references/dotnet-patterns.md`    | When using .NET collections, Regex, Stopwatch, or IO methods                                                 |

## Quick Checklist

Before delivering a function, verify:

- [ ] `using namespace` declarations at file top (System.* only — FQ names for external DLL types)
- [ ] `[CmdletBinding()]` present
- [ ] `LiteralPath` is `[string[]]`, `Mandatory`, `Position = 0`, aliased `PSPath`
- [ ] All parameters have `ValueFromPipelineByPropertyName` and `HelpMessage`
- [ ] Type and name on same line for all parameters
- [ ] `$resolved*` lists initialized as `[List[string]]::new()` in `begin`
- [ ] External commands stored via `Get-Command` into `$cmd*` in `begin`
- [ ] `process` block only validates/accumulates — no processing
- [ ] `end` block does all work
- [ ] `$LASTEXITCODE` checked after external process calls
- [ ] `Write-Verbose` at key steps
- [ ] No line exceeds 110 characters
- [ ] Variables are camelCase and strongly typed
- [ ] Parameters are PascalCase
- [ ] `MaxThreads` is last parameter (if parallel)
