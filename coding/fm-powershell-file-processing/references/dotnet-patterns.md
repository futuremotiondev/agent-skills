# .NET Patterns for PowerShell 7

Reference for .NET types, collections, and methods preferred over native PowerShell
equivalents. Read this file when the function needs high-performance collection handling,
regex, timing, or file path manipulation.

## Table of Contents

1. [Collections](#collections)
2. [Path Operations](#path-operations)
3. [Regex](#regex)
4. [Timing](#timing)
5. [File I/O](#file-io)

---

## Collections

Always prefer generic collections over native arrays. Native array `+=` copies the entire
array on every append — O(n²) for n items.

```powershell
using namespace System.Collections.Generic

# List<T> — ordered, allows duplicates
[List[string]] $files = @()
$files.Add('C:\data\file1.txt')
$files.AddRange([string[]]@('file2.txt', 'file3.txt'))

# HashSet<T> — unordered, deduplicates automatically
[HashSet[string]] $seen = @()
$seen.Add('C:\data\file1.txt')   # returns $true (added)
$seen.Add('C:\data\file1.txt')   # returns $false (duplicate)

# Dictionary<TKey,TValue> — key-value lookup
[Dictionary[string, int]] $counts = @{}
$counts['processed'] = 0
$counts['skipped']   = 0
```

### When to use which

| Type              | Use case                                                   |
|-------------------|------------------------------------------------------------|
| `List<T>`         | Default choice for accumulating paths, results, parameters |
| `HashSet<T>`      | Deduplication, membership checks                           |
| `Dictionary<K,V>` | Counters, lookup tables, grouping                          |
| `Queue<T>`        | FIFO work queues                                           |
| `Stack<T>`        | LIFO / undo operations                                     |

---

## Path Operations

```powershell
using namespace System.IO

# Combine paths (replaces Join-Path)
[string] $output = [Path]::Combine($rootDir, 'subfolder', $filename)

# Change extension
[string] $pngPath = [Path]::ChangeExtension($inputFile, '.png')

# Get components
[string] $dir  = [Path]::GetDirectoryName($filePath)
[string] $name = [Path]::GetFileNameWithoutExtension($filePath)
[string] $ext  = [Path]::GetExtension($filePath)

# Temp files
[string] $tmpFile = [Path]::GetTempFileName()
[string] $tmpDir  = [Path]::GetTempPath()
```

---

## Regex

Use compiled regex when the pattern is reused across many iterations.

```powershell
using namespace System.Text.RegularExpressions

# Compiled regex for hot loops
[Regex] $rx = [Regex]::new(
    '(?<ip>\d{1,3}(?:\.\d{1,3}){3})\s+-\s+\[(?<date>[^\]]+)\]',
    [RegexOptions]::Compiled
)

# Usage in a loop
foreach ($line in [IO.File]::ReadLines($logPath)) {
    $m = $rx.Match($line)
    if ($m.Success) {
        [string] $ip   = $m.Groups['ip'].Value
        [string] $date = $m.Groups['date'].Value
    }
}

# Simple one-off replacements — static methods are fine
[string] $clean = [Regex]::Replace($input, '\s+', ' ')
```

---

## Timing

```powershell
using namespace System.Diagnostics

[Stopwatch] $sw = [Stopwatch]::StartNew()

# ... do work ...
$elapsed = $sw.Elapsed
Write-Verbose "Phase 1 completed in $($elapsed.TotalMilliseconds) ms"

# ... more work ...
$sw.Stop()
Write-Verbose "Total elapsed: $($sw.Elapsed.TotalSeconds) s"
```

---

## File I/O

For line-by-line reading of large files, avoid `Get-Content` (slow, high memory).

```powershell
# Stream lines without loading entire file into memory
foreach ($line in [IO.File]::ReadLines($filePath)) {
    # process $line
}

# Read all text at once (small files only)
[string] $content = [IO.File]::ReadAllText($filePath)

# Write output
[IO.File]::WriteAllText($outputPath, $content)
[IO.File]::WriteAllLines($outputPath, [string[]]$lines)
```
