# Parameter Guide

Reference for validation attributes, argument completers, and advanced parameter patterns.
Read this file when building parameters beyond the core LiteralPath/MaxThreads definitions.

## Table of Contents

1. [Validation Attributes](#validation-attributes)
2. [ArgumentCompletions (simple)](#argumentcompletions-simple)
3. [ArgumentCompleter (advanced)](#argumentcompleter-advanced)
4. [Combined Example](#combined-example)

---

## Validation Attributes

Apply these between the `[Parameter()]` block and the type/name declaration.

| Attribute                    | Use when                                         | Example                                                                |
|------------------------------|--------------------------------------------------|------------------------------------------------------------------------|
| `[ValidateNotNull()]`        | Null must be rejected                            | —                                                                      |
| `[ValidateNotNullOrEmpty()]` | Null or empty string/collection must be rejected | —                                                                      |
| `[ValidateRange(min, max)]`  | Numeric bounds                                   | `[ValidateRange(1, 100)]`                                              |
| `[ValidateSet('A','B','C')]` | Constrained string choices (enforced)            | Add `IgnoreCase = $true` if needed                                     |
| `[ValidatePattern(regex)]`   | Must match a regex                               | `[ValidatePattern('^[a-zA-Z][\w-]*$', ErrorMessage = '...')]`          |
| `[ValidateScript({block})]`  | Custom logic                                     | `[ValidateScript({ Test-Path $_ }, ErrorMessage = "Path not found.")]` |
| `[ValidateLength(min, max)]` | String length bounds                             | `[ValidateLength(2, 64)]`                                              |
| `[ValidateCount(min, max)]`  | Collection element count                         | `[ValidateCount(1, 50)]`                                               |
| `[ValidateDrive('C','D')]`   | Restrict PSDrive roots                           | —                                                                      |
| `[SupportsWildcards()]`      | Parameter accepts wildcards                      | Pair with `-like` in function body                                     |
| `[AllowEmptyString()]`       | Override mandatory empty-string rejection        | —                                                                      |
| `[AllowEmptyCollection()]`   | Override mandatory empty-collection rejection    | —                                                                      |
| `[AllowNull()]`              | Override mandatory null rejection                | —                                                                      |

### Stacking order

When combining multiple attributes, follow this order (top to bottom):

```powershell
[Parameter(
    Mandatory = $true,
    Position = 0,
    ValueFromPipeline,
    ValueFromPipelineByPropertyName,
    HelpMessage = "Description here."
)]
[ValidateNotNullOrEmpty()]
[ValidatePattern('^[a-zA-Z]:\\\', ErrorMessage = 'Must be a rooted path')]
[ValidateLength(3, 260)]
[ValidateCount(1, 20)]
[ValidateDrive('C', 'D')]
[ValidateScript({ Test-Path $_ -PathType Container }, ErrorMessage = "Must be a folder.")]
[string[]] $ExamplePath
```

---

## ArgumentCompletions (simple)

Use `[ArgumentCompletions()]` for a static suggestion list that does **not** enforce values.

```powershell
[Parameter(Mandatory, Position = 0)]
[ValidateNotNullOrEmpty()]
[ArgumentCompletions('Dracula', 'Monokai', 'Nord', 'Catppuccin', 'Gruvbox', 'OneDark')]
[string] $Theme
```

---

## ArgumentCompleter (advanced)

Use `[ArgumentCompleter({...})]` when completions are dynamic or depend on other bound
parameters. The scriptblock must accept these five parameters in this exact order:

```powershell
[ArgumentCompleter({
    param(
        [string] $CommandName,
        [string] $ParameterName,
        [string] $WordToComplete,
        [System.Management.Automation.Language.CommandAst] $CommandAst,
        [System.Collections.IDictionary] $FakeBoundParameters
    )

    # Build candidates — can be dynamic (filesystem, API, registry, etc.)
    $candidates = @('Alpha', 'Bravo', 'Charlie', 'Delta', 'Echo')

    # Optionally adapt based on already-bound parameters
    if ($FakeBoundParameters.ContainsKey('Scope') -and
        $FakeBoundParameters['Scope'] -eq 'Limited') {
        $candidates = @('Alpha', 'Bravo')
    }

    # Filter and emit CompletionResult objects
    $candidates |
        Where-Object { $_ -like "$WordToComplete*" } |
        ForEach-Object {
            [System.Management.Automation.CompletionResult]::new(
                $_,               # completionText
                $_,               # listItemText
                'ParameterValue', # resultType
                $_                # toolTip
            )
        }
})]
```

---

## Combined Example

A parameter using ValidateSet, ValidateRange, ArgumentCompletions, and custom validation:

```powershell
param(
    [Parameter(
        Mandatory = $true,
        Position = 0,
        ValueFromPipeline,
        ValueFromPipelineByPropertyName,
        HelpMessage = "Directories to scan."
    )]
    [ValidateNotNullOrEmpty()]
    [ValidateCount(1, 12)]
    [ValidateScript({ Test-Path $_ -PathType Container }, ErrorMessage = "Must be a folder.")]
    [string[]] $ScanPath,

    [Parameter(
        ValueFromPipelineByPropertyName,
        HelpMessage = "Output format for the report."
    )]
    [ValidateSet('JSON', 'CSV', 'XML', IgnoreCase = $true)]
    [string] $Format = 'JSON',

    [Parameter(
        ValueFromPipelineByPropertyName,
        HelpMessage = "Minimum file size in bytes to include."
    )]
    [ValidateRange(0, [long]::MaxValue)]
    [long] $MinSize = 0,

    [Parameter(
        ValueFromPipelineByPropertyName,
        HelpMessage = "The amount of threads to use for parallel processing."
    )]
    [ValidateRange(1, [int]::MaxValue)]
    [int] $MaxThreads = [Math]::Max(1, [int]([Environment]::ProcessorCount * 0.75))
)
```
