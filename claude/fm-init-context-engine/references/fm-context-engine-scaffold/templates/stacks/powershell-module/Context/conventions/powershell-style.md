---
last_verified: {{TODAY}}
---

# PowerShell 7 Style

Seeded by the context-engine `powershell-module` adapter — a condensed, generic cut of conventions proven in production PowerShell modules. Tighten and extend as the project develops.

Statements here are platform facts, guardrails, or **Default:** choices; the conventions README explains the difference and how to deviate.

## Function shape

- **Default:** advanced functions only: `[CmdletBinding()]` + `[OutputType(...)]`, one function per file, file name exactly matches function name, placed under the module's `Public/<Category>/` tree.
- **Default:** file-processing functions use the `begin`/`process`/`end` skeleton: `begin` initializes (tool lookups, accumulators — throw here if the function cannot possibly work), `process` validates and accumulates pipeline input (per-item problems are `Write-Warning` + `continue`, never `throw`), `end` does the heavy work.
- Destructive functions declare `SupportsShouldProcess` and honor `-WhatIf` with zero footprint.

## Parameters

- **Default:** type and name on one line with a space: `[string[]] $LiteralPath`.
- **Default:** the primary path input is `-LiteralPath` with `[Alias('PSPath')]`, `Position = 0`, pipeline binding, and `HelpMessage` on every parameter.
- Resolve user paths with `$PSCmdlet.SessionState.Path.GetUnresolvedProviderPathFromPSPath(...)` before handing them to .NET, which resolves relative paths against the process directory rather than the current PowerShell location.

## Paths and filesystem

- `-LiteralPath` (never `-Path`) on `Test-Path`, `Get-Item`, `Remove-Item`, `Copy-Item` — `[1]` in a filename is a wildcard class under `-Path`.
- **Default:** `[System.IO.Path]::Combine(...)` for joins; `[System.IO.Directory]::CreateDirectory(...)` for creation (idempotent).

## Output contract

- **Default:** work functions emit one `[PSCustomObject]` per input item: source first, output next, then `Successful` (bool) and `ErrorMessage` (`$null` on success, never `''`). Success and failure records share one stream — callers filter with `Where-Object`.
- **Default:** destructive functions are silent on success; structured records are opt-in via `-PassThru`.
- **Default:** no `Write-Host` in functions — success stream for data, `Write-Warning`/`Write-Verbose`/`Write-Error` for diagnostics.

## Collections and parallelism

- **Default:** `[List[T]]` for accumulators and `[HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)` for path sets, rather than `+=` on an array in a loop.
- Inside `ForEach-Object -Parallel`, collect into a thread-safe collection such as `[ConcurrentBag[T]]`.
- Reads in parallel, filesystem mutations sequential — collision detection cannot race.

## External processes

- **Default:** resolve tools in `begin` (`Get-Command <tool> -CommandType Application -ErrorAction Stop`); build an argument array and invoke with `&`.
- Check `$LASTEXITCODE` immediately after every native call. A non-zero exit sets `$?` to `$false` but writes no error record, so `try`/`catch` and `-ErrorAction` miss it unless `$PSNativeCommandUseErrorActionPreference` is `$true` (stable since PowerShell 7.4).

## Known traps (from production)

- `[string] $x = $null` coerces to `''` — test with `[string]::IsNullOrEmpty()`, and leave variables untyped when the null/empty distinction matters. The coercion also applies to .NET method string arguments.
- A typed `if`-expression assignment (`[HashSet[string]] $x = if (...) { ... }`) re-creates the collection via the default constructor, silently dropping a custom comparer.
- Nested `function` declarations inside script blocks can leak into AST-based manifest discovery — use scriptblock variables for helpers inside parallel blocks.
