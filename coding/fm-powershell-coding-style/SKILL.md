---
name: fm-powershell-coding-style
description: PowerShell coding style conventions for Futuremotion projects. Covers region headers, comment formatting, general comment documentation, naming, structural patterns, and doc-comment creation compatible with platyPS. Applies to all PowerShell code — scripts, functions, modules, and admin utilities.
---

# PowerShell Coding Style — Futuremotion

This skill defines visual and structural style conventions for all PowerShell code.
Domain skills (fm-powershell-windows-admin, fm-powershell-file-processing, etc.) define
*what* the code does; this skill defines *how it looks*.

**What this skill covers:**

- Variable Naming Conventions
- Region Sections
- Inline Section Comments (Not full Regions)
- General Comments Explaining Important Logic
- Doc-Comments that are platyPS compatible
- Enforcement of 80 column length code

## Variable Naming Conventions

- All function and script parameters MUST be in PascalCase
- All non-parameter variables MUST be in camelCase
- All "command" variables that are assigned from `Get-Command` must start with `$cmd`
- Example of a "command" variable: `$cmdSvgo = Get-Command svgo.cmd -CommandType Application`
- The Function and Script parameter that sets the value of `-ThrottleLimit` in a `ForEach-Object -Parallel` block MUST be named `$MaxThreads`.
- The `$MaxThreads` value should by default always be set to `(Internal-GetModuleConfig).Threads.Percent75` unless specified otherwise.
- The `$MaxThreads` parameter should always include a `[ValidateRange(1, 128)]` decorator to limit its range.
- All functions and scripts that primarily operate on directories or files must always have a parameter named `$LiteralPath`.
- The `$LiteralPath` parameter must always be defined exactly like this:

  ```powershell
  [Parameter(
      Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName,
      HelpMessage = "Literal path to one or more TTF/OTF files to convert."
  )]
  [Alias('PSPath')]
  [ValidateNotNullOrEmpty()]
  [String[]] $LiteralPath,
  ```

## Code Length Enforcement - 80 Columns

All PowerShell code SHOULD be formatted to fit within an 80-column horizontal
limit. This applies to executable statements, function signatures, parameter
declarations, hashtable literals, switch blocks, and pipeline expressions.

### Rules

- The 80-column limit is a strong default, not an absolute ceiling.
- Aim for 80 first; exceed it only when wrapping would harm readability.
- Use your best judgement. The goal is reader comfort in side-by-side diffs and
  narrow terminals — not pedantic adherence to a counter.
- When in doubt, wrap. The cost of an extra line is small; the cost of
  horizontal scrolling in diffs and narrow panes is large.

### When Exceeding 80 is Acceptable

Exceptions are allowed when wrapping a line would be extremely awkward. Examples
where it is reasonable to exceed 80:

- A regex literal that loses meaning when split across lines.
- A single long URL or filesystem path that has no natural break point.
- A short one-liner that reads naturally at 82–85 columns and would become
  significantly less readable when broken across two lines.
- A `[ValidateSet(...)]` or `[ValidatePattern(...)]` literal where the contents
  are a single logical unit and splitting introduces visual noise.

In all other cases, prefer wrapping.

### Preferred Wrapping Points

When a line must be wrapped, prefer natural boundaries in this order:

- After a pipe `|` (continuation line is indented one level).
- After a comma in an argument list.
- After an opening parenthesis `(`, bracket `[`, `@(`, or `@{`.
- Before a binary operator (`-and`, `-or`, `+`, etc.) at the start of the
  continuation line.
- Use PowerShell's natural line-continuation contexts (open `(`, `{`, `@(`,
  `@{`, an unterminated pipeline) — these do NOT require a backtick.

Use backtick line-continuation (`` ` ``) sparingly. Backticks are easy to miss
in code review and break silently when trailing whitespace is added. Prefer
parenthesized expressions, splat hashtables, and natural pipeline boundaries
over backticks whenever the structure allows.

## Regions

### Region Line Length

All regions MUST have an exact length of 80 characters. This is NOT optional.

### Region Headers

- Use `# REGION` / `# ENDREGION` blocks to delineate major script sections.
- Each region gets a top and bottom separator line extending to **column 80**.

### Region Format

```powershell
# REGION - SECTION NAME IN CAPS
# ──────────────────────────────────────────────────────────────────────────────

... code ...

# ENDREGION
```

### Region Rules

1. The separator character is `─` (U+2500, BOX DRAWINGS LIGHT HORIZONTAL)
2. Each separator line MUST start with `#`, then a space, and finally fill with `─` to exactly column 80
3. The region label line MUST use the format: `# REGION - TITLE IN CAPS`
4. The word `REGION` MUST be in UPPER CASE, followed by ` - ` (space-dash-space)
5. The section title following `REGION - ` MUST be in **UPPER CASE**
6. A matching `# ENDREGION` closes the block (no separator lines needed)
7. One blank line after the closing `# ENDREGION` before the next region begins
8. `# ENDREGION` MUST be in **UPPER CASE**

### Region Separator Line (copy-paste reference)

The line below is exactly 80 columns (1 for `#`, 1 for ` `, 78 `─` characters):

```powershell
# ──────────────────────────────────────────────────────────────────────────────
```

### Region Examples

```powershell
# REGION - INTERNAL FUNCTIONS
# ──────────────────────────────────────────────────────────────────────────────

function Get-Something { ... }
function Set-Something { ... }

# ENDREGION

# REGION - VALIDATION
# ──────────────────────────────────────────────────────────────────────────────

if (-not $InputFile) { ... }

# ENDREGION

# REGION - MAIN LOGIC
# ──────────────────────────────────────────────────────────────────────────────

...

# ENDREGION
```

### When to Use Regions

Use regions for **top-level script sections** that group logically distinct phases:

- Parameter declarations (when complex)
- Internal/helper functions
- Validation
- State capture
- Main logic / modification
- Cleanup / restore
- Application launch

Do **not** nest regions or use them inside individual functions. Inside
functions, use lightweight inline comments instead.

## Inline Section Comments

For sub-sections within a function body (not full regions), use the lightweight
dash-suffixed format:

```powershell
# NORMALIZE HIVE NAMES ─────────────────────────────────────────────────────────
```

- These MUST extend to column 80 but use a shorter prefix with a hash (`#`), followed by a space.
- After the space, the sub-section title MUST be in **UPPER-CASE**
- After the sub-section title, a single space MUST follow.
- After the single space after the title, the line (`─`) MUST extend to exactly column 80.
- The sub-section title is not paired with a closing marker.

## General Comments Explaining Important Logic

When creating functions or scripts, you MUST add general comments above important code or logic.

- General comments MUST be placed immediately above the code they document.
- General comments MUST wrap at exactly column 80.
- General comments MUST describe not only WHAT the code does, but WHY.
- General comments can be as verbose as you need them to be to in order to properly document the code.

## Doc-Comments

All created functions should have PlatyPS compatible Doc-Comments, and MUST include the following sections:

- .SYNOPSIS - A short description that describes what the function does.

- .DESCRIPTION - A much longer description that completely and fully describes what the function does.

- .PARAMETER (For each function Parameter) - A description of what the parameter does and how it affects the function's operation.

- .INPUTS - The .NET or Powershell types that the function accepts as inputs.

  - Example:

  ```text
  System.String[]
  Pipe file paths or DirectoryInfo / FileInfo objects.
  ```

- .OUTPUTS - The .NET or Powershell types that the function emits or outputs.

  - Example:

  ```text
  System.Management.Automation.PSCustomObject
  One result per emitted webfont file with SourcePath, OutputPath,
  Format, Successful, ErrorMessage.
  ```

- .EXAMPLE - At least three usage examples, more if necessary. Include pipeline usage if the function supports it.

- .NOTES - Any important additional information or context

  - Example:

  ```text
  Requires FMDevToolbox.dll loaded via the module manifest. No external
  binary dependencies. Default thread count is read from
  $script:FMDevConfig.Threads.Percent75.
  ```

- .LINK (The first .LINK section should always include `https://github.com/futuremotiondev`)

- .LINK (Additional .LINK sections should reference related functions)

## Additional PlatyPS Requirements

- Ensure [Parameter()] attributes are properly used in your scripts.
- platyPS uses [Parameter()] attributes to accurately document parameter requirements.
