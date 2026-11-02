---
name: fm-powershell-windows-admin
description: >
  PowerShell 7 non-pipeline functions for Windows 11 system administration and utility tasks.
  Use this skill when creating functions that manage Windows services, processes, registry keys,
  scheduled tasks, Explorer shell operations, icon/thumb caches, file associations, system tray,
  or any elevated admin operation. Also trigger when the user mentions restarting explorer.exe,
  killing and relaunching processes from elevated context, AutoRestartShell, /NoUACCheck,
  de-elevation patterns, service stop/start orchestration, or writing standalone admin scripts
  for the x:\.admin directory. Trigger when the user says "write a Windows utility function",
  "admin script", "system maintenance script", or similar.
---

# PowerShell 7 Windows Admin & Utility Functions

Target: **PowerShell 7.4+, Windows 11 only.** Do not target Windows PowerShell 5.

Before writing code, use Context7, deepwiki, ref, or other documentation MCP tools to
retrieve the latest PowerShell 7 docs for any cmdlets, .NET APIs, or Win32 calls used.

## When This Skill Applies

Use this skill for functions that **do not process file/directory input via pipeline**.
These functions typically:

- Manage Windows services, processes, or scheduled tasks
- Modify registry keys and values
- Interact with Explorer shell state
- Require administrator privileges
- Perform system maintenance (cache cleanup, association resets, etc.)
- Orchestrate stop → work → restore sequences

For functions that **do** process files/directories via pipeline (`$LiteralPath` parameter
with `begin/process/end` accumulation), use the `powershell-file-processing` skill instead.

## Architecture: Capture → Modify → Restore

Admin functions follow a state-management pattern, not a pipeline pattern. The function
captures current system state, performs modifications, then restores what was changed.

```text
Phase 1: Pre-flight
    1. Check admin privileges (throw if not elevated and elevation is required)
    2. Locate external tools with Get-Command
    3. Discover dynamic targets (cache files, running services, etc.)
    4. Early-exit if nothing to do

Phase 2: Capture State
    1. Snapshot running services/processes that will be affected
    2. Save registry values that will be modified
    3. Capture Explorer windows or other UI state to restore later
    4. Store everything in typed variables for the restore phase

Phase 3: Modify
    1. Stop services and processes in dependency order
    2. Perform the actual admin operation (delete files, modify registry, etc.)
    3. Use Write-Verbose at every step for runtime traceability

Phase 4: Restore
    1. Restart services and processes in reverse dependency order
    2. Restore registry values to captured originals
    3. Re-open Explorer windows or other UI state
    4. Clean up temporary resources (scheduled tasks, PSDrives, etc.)
```

## Function Structure Template

```powershell
using namespace System.IO
using namespace System.Collections.Generic
using namespace System.Security.Principal

function Verb-WindowsNoun {
    <#
    .SYNOPSIS
        Brief one-line description.
    .DESCRIPTION
        What the function does and why admin privileges are needed.
    .EXAMPLE
        Verb-WindowsNoun
        Runs the operation with default settings.
    .NOTES
        Author: Futuremotion
        Date: YYYY-MM-DD
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param (
        # Parameters specific to the operation
    )

    # ── Phase 1: Pre-flight ──────────────────────────────────────
    $isAdmin = ([WindowsPrincipal][WindowsIdentity]::GetCurrent()
    ).IsInRole([WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        throw "Verb-WindowsNoun requires Administrator privileges."
    }

    # Locate tools, discover targets, validate preconditions
    # Early-exit if nothing to do:
    # if ($targets.Count -eq 0) { Write-Warning "Nothing to do."; return }

    # ── Phase 2: Capture State ───────────────────────────────────
    # Snapshot services, processes, registry, Explorer windows

    # ── Phase 3: Modify ──────────────────────────────────────────
    # Stop services, kill processes, perform the operation

    # ── Phase 4: Restore ─────────────────────────────────────────
    # Restart services/processes, restore registry, reopen windows

    # Return result object
    [PSCustomObject]@{
        Operation    = 'Verb-WindowsNoun'
        Success      = $true
        ErrorMessage = $null
    }
}
```

## Critical Pattern: Restarting Explorer from Elevated Context

When an admin function must kill and restart `explorer.exe`, there are two problems:

1. **Winlogon auto-restart** — Windows automatically restarts the shell process when it
   dies, but launches it with the `/NoUACCheck` flag, which has security implications
   (bypasses UAC elevation prompts).
2. **Elevation inheritance** — Any process launched directly from an elevated PowerShell
   session inherits the admin token or triggers `/NoUACCheck`.

**Every naive approach fails:**

| Approach                                 | Problem                                   |
|------------------------------------------|-------------------------------------------|
| `Start-Process explorer.exe`             | Inherits elevated token                   |
| `& explorer.exe`                         | Inherits elevated token                   |
| `cmd /c start explorer.exe`              | Adds `/NoUACCheck` flag                   |
| `Invoke-Expression "start explorer.exe"` | `start` is a PS alias for `Start-Process` |
| Let winlogon auto-restart                | Restarts with `/NoUACCheck`               |

**The correct solution** is a scheduled task at `Limited` run level with `AutoRestartShell`
temporarily disabled:

```powershell
# BEFORE killing explorer — disable winlogon's automatic shell restart
$winlogonKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
$originalAutoRestart = (Get-ItemProperty -LiteralPath $winlogonKey `
    -Name 'AutoRestartShell' -EA SilentlyContinue).AutoRestartShell
Set-ItemProperty -LiteralPath $winlogonKey `
    -Name 'AutoRestartShell' -Value 0 -Type DWord
Write-Verbose "Disabled AutoRestartShell (was: $originalAutoRestart)"

# Kill explorer (and any other processes)
taskkill /F /IM explorer.exe

# ... do work while explorer is dead ...

# Restart explorer via scheduled task at Limited (non-elevated) run level
$taskName  = 'FMDevToolbox_RestartExplorer'
$action    = New-ScheduledTaskAction -Execute "$env:SystemRoot\explorer.exe"
$principal = New-ScheduledTaskPrincipal `
    -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName $taskName `
    -Action $action -Principal $principal -Force | Out-Null
Start-ScheduledTask -TaskName $taskName
Start-Sleep -Milliseconds 500
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
Write-Verbose "Explorer restarted via scheduled task; task cleaned up"

# Restore AutoRestartShell to its original value
$restoreValue = if ($null -eq $originalAutoRestart) { 1 } else {
    $originalAutoRestart
}
Set-ItemProperty -LiteralPath $winlogonKey `
    -Name 'AutoRestartShell' -Value $restoreValue -Type DWord
Write-Verbose "Restored AutoRestartShell to: $restoreValue"
```

**Key details:**

- Always use `$env:SystemRoot\explorer.exe` (full path) in the scheduled task action
- `RunLevel Limited` ensures the new Explorer runs as a standard user process
- `LogonType Interactive` ensures it gets the user's desktop session
- Clean up the task immediately after starting it
- Always restore `AutoRestartShell` even if the original value was `$null` (default to 1)

## Pattern: Admin Privilege Check

Always check at the top of the function, before any work. Use `throw` — not `Write-Error` —
because the entire function is invalid without elevation.

```powershell
$isAdmin = ([WindowsPrincipal][WindowsIdentity]::GetCurrent()
).IsInRole([WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    throw "FunctionName requires Administrator privileges."
}
```

Requires `using namespace System.Security.Principal` at the top of the file.

## Pattern: Service State Capture and Restore

When stopping services to perform maintenance, always capture their running state first
and only restart those that were actually running.

```powershell
# Capture — check a list of possible service names
$serviceNames = @('ServiceName1', 'ServiceName2 (variant)')
[string] $runningServiceName = $serviceNames |
    Where-Object {
        (Get-Service -Name $_ -EA SilentlyContinue).Status -eq 'Running'
    } |
    Select-Object -First 1

# Stop — only if it was running
if ($runningServiceName) {
    Stop-Service -Name $runningServiceName -Force -EA SilentlyContinue
    Write-Verbose "Stopped service: $runningServiceName"
}

# ... do work ...

# Restore — only restart what was running before
if ($runningServiceName) {
    Start-Service -Name $runningServiceName
    Write-Verbose "Restarted service: $runningServiceName"
}
```

## Pattern: Process State Capture and Restore

Similar to services, but for user-mode processes. Capture the executable path so you can
relaunch the exact binary.

```powershell
# Capture
$processNames = @('ProcessName', 'ProcessName64')
[string] $runningProcessName = $processNames |
    Where-Object { Get-Process -Name $_ -EA SilentlyContinue } |
    Select-Object -First 1

[string] $processPath = if ($runningProcessName) {
    (Get-Process -Name $runningProcessName -EA SilentlyContinue).Path
} else { $null }

# Kill (via taskkill for reliability)
if ($processPath) {
    $processFile = [Path]::GetFileName($processPath)
    Invoke-Expression "taskkill /F /IM $processFile"
    Write-Verbose "Killed process: $processFile"
}

# ... do work ...

# Restart — launch the original exe at user privilege level
if ($processPath) {
    $cmdStart = 'start "" "{0}"' -f $processPath
    Start-Process 'cmd' -ArgumentList "/c $cmdStart" -WindowStyle Minimized
    Write-Verbose "Restarted process: $processPath"
}
```

**Important:** Do NOT kill/restart shell extension processes like `Direct Folders`
(`df.exe`/`df64.exe`). These hook into the Explorer shell and survive Explorer restarts
on their own. Killing and relaunching them breaks their shell hooks.

## Pattern: Registry Backup and Restore

Always capture the original value before modifying, and restore it in the cleanup phase.
Handle the case where the value did not previously exist.

```powershell
# Capture original
$regPath = 'HKLM:\SOFTWARE\Some\Key'
$original = (Get-ItemProperty -LiteralPath $regPath `
    -Name 'ValueName' -EA SilentlyContinue).ValueName

# Modify
Set-ItemProperty -LiteralPath $regPath `
    -Name 'ValueName' -Value $newValue -Type DWord
Write-Verbose "Set ValueName to $newValue (was: $original)"

# ... do work ...

# Restore
$restoreValue = if ($null -eq $original) { $defaultValue } else { $original }
Set-ItemProperty -LiteralPath $regPath `
    -Name 'ValueName' -Value $restoreValue -Type DWord
Write-Verbose "Restored ValueName to $restoreValue"
```

## Pattern: Win32 P/Invoke via Add-Type

When calling Windows APIs (SHChangeNotify, etc.), use `Add-Type` with a type-existence
guard to avoid re-definition errors on repeated runs.

```powershell
if (-not ('FMDevToolbox.Win32.ShellNotify' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace FMDevToolbox.Win32 {
    public static class ShellNotify {
        [DllImport("Shell32.dll")]
        private static extern int SHChangeNotify(
            uint eventId, uint flags, IntPtr item1, IntPtr item2);
        public static void AssociationChanged() {
            SHChangeNotify(0x08000000u, 0x1000u, IntPtr.Zero, IntPtr.Zero);
        }
    }
}
'@ -Language CSharp
}

# Usage
[FMDevToolbox.Win32.ShellNotify]::AssociationChanged()
```

Use the `FMDevToolbox.Win32` namespace for all P/Invoke types in this module.

## Pattern: Force Explorer View Refresh (SHChangeNotify)

Explorer caches folder icons, file listings, and attributes aggressively. After
programmatic changes (setting folder icons via `desktop.ini`, creating files/folders,
changing attributes), Explorer may not reflect the change until the user presses F5.

Use `SHChangeNotify` to tell the shell *exactly what changed*. This is the proper,
API-level equivalent of pressing F5 — but targeted and immediate.

### P/Invoke Setup

```powershell
if (-not ('FMDevToolbox.Win32.ShellRefresh' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace FMDevToolbox.Win32 {
    public static class ShellRefresh {
        [DllImport("Shell32.dll", CharSet = CharSet.Unicode)]
        private static extern void SHChangeNotify(
            uint wEventId, uint uFlags,
            [MarshalAs(UnmanagedType.LPWStr)] string dwItem1,
            [MarshalAs(UnmanagedType.LPWStr)] string dwItem2);

        [DllImport("Shell32.dll")]
        private static extern void SHChangeNotify(
            uint wEventId, uint uFlags,
            IntPtr dwItem1, IntPtr dwItem2);

        // Event IDs (wEventId)
        private const uint SHCNE_CREATE       = 0x00000002;
        private const uint SHCNE_DELETE       = 0x00000004;
        private const uint SHCNE_MKDIR        = 0x00000008;
        private const uint SHCNE_RMDIR        = 0x00000010;
        private const uint SHCNE_ATTRIBUTES   = 0x00000800;
        private const uint SHCNE_UPDATEDIR    = 0x00001000;
        private const uint SHCNE_UPDATEITEM   = 0x00002000;
        private const uint SHCNE_UPDATEIMAGE  = 0x00008000;
        private const uint SHCNE_ASSOCCHANGED = 0x08000000;
        private const uint SHCNE_ALLEVENTS    = 0x7FFFFFFF;

        // Flags (uFlags)
        private const uint SHCNF_PATH         = 0x0005;
        private const uint SHCNF_FLUSH        = 0x1000;
        private const uint SHCNF_FLUSHNOWAIT  = 0x3000;
        private const uint SHCNF_IDLIST       = 0x0000;

        // Folder icon changed via desktop.ini
        public static void FolderIconChanged(string folderPath) {
            SHChangeNotify(SHCNE_UPDATEDIR,
                SHCNF_PATH | SHCNF_FLUSH, folderPath, null);
        }

        // File or folder created
        public static void ItemCreated(string path, bool isFolder) {
            uint evt = isFolder ? SHCNE_MKDIR : SHCNE_CREATE;
            SHChangeNotify(evt,
                SHCNF_PATH | SHCNF_FLUSHNOWAIT, path, null);
        }

        // File or folder deleted
        public static void ItemDeleted(string path, bool isFolder) {
            uint evt = isFolder ? SHCNE_RMDIR : SHCNE_DELETE;
            SHChangeNotify(evt,
                SHCNF_PATH | SHCNF_FLUSHNOWAIT, path, null);
        }

        // Attributes changed (hidden, read-only, etc.)
        public static void AttributesChanged(string path) {
            SHChangeNotify(SHCNE_ATTRIBUTES,
                SHCNF_PATH | SHCNF_FLUSHNOWAIT, path, null);
        }

        // Existing item modified (contents changed)
        public static void ItemUpdated(string path) {
            SHChangeNotify(SHCNE_UPDATEITEM,
                SHCNF_PATH | SHCNF_FLUSHNOWAIT, path, null);
        }

        // Folder contents changed (general refresh for a dir)
        public static void DirectoryUpdated(string folderPath) {
            SHChangeNotify(SHCNE_UPDATEDIR,
                SHCNF_PATH | SHCNF_FLUSHNOWAIT, folderPath, null);
        }

        // File associations changed (icon cache + thumbnail)
        public static void AssociationChanged() {
            SHChangeNotify(SHCNE_ASSOCCHANGED,
                SHCNF_IDLIST | SHCNF_FLUSH, IntPtr.Zero, IntPtr.Zero);
        }

        // Nuclear option: refresh everything
        public static void RefreshAll() {
            SHChangeNotify(SHCNE_ALLEVENTS,
                SHCNF_IDLIST | SHCNF_FLUSH, IntPtr.Zero, IntPtr.Zero);
        }
    }
}
'@ -Language CSharp
}
```

### Usage by Scenario

```powershell
# After setting a folder icon via desktop.ini
# (SHCNE_UPDATEDIR is required — UPDATEITEM won't refresh
#  folder display properties like custom icons)
Set-Content -LiteralPath "$folder\desktop.ini" -Value $iniContent
attrib +S +H "$folder\desktop.ini"
attrib +R $folder
[FMDevToolbox.Win32.ShellRefresh]::FolderIconChanged($folder)

# After creating a folder programmatically
[IO.Directory]::CreateDirectory($newFolder)
[FMDevToolbox.Win32.ShellRefresh]::ItemCreated($newFolder, $true)

# After creating a file
[IO.File]::WriteAllText($newFile, $content)
[FMDevToolbox.Win32.ShellRefresh]::ItemCreated($newFile, $false)

# After changing file attributes
attrib +H $somePath
[FMDevToolbox.Win32.ShellRefresh]::AttributesChanged($somePath)

# After changing file type associations or icon handlers
[FMDevToolbox.Win32.ShellRefresh]::AssociationChanged()

# Broad refresh of a directory (like pressing F5)
[FMDevToolbox.Win32.ShellRefresh]::DirectoryUpdated($folder)

# Last resort: refresh everything
[FMDevToolbox.Win32.ShellRefresh]::RefreshAll()
```

### Which Event for Which Scenario

| Scenario                      | Method                       | Why                                                   |
|-------------------------------|------------------------------|-------------------------------------------------------|
| Folder icon via `desktop.ini` | `FolderIconChanged`          | `SHCNE_UPDATEDIR` refreshes folder display properties |
| New file created              | `ItemCreated($path, $false)` | `SHCNE_CREATE` for non-folder items                   |
| New folder created            | `ItemCreated($path, $true)`  | `SHCNE_MKDIR` for folders                             |
| File/folder deleted           | `ItemDeleted`                | `SHCNE_DELETE` / `SHCNE_RMDIR`                        |
| Attributes changed            | `AttributesChanged`          | `SHCNE_ATTRIBUTES` (hidden, readonly)                 |
| File contents modified        | `ItemUpdated`                | `SHCNE_UPDATEITEM` for existing items                 |
| General dir refresh (F5)      | `DirectoryUpdated`           | `SHCNE_UPDATEDIR` refreshes folder view               |
| File association / icon cache | `AssociationChanged`         | `SHCNE_ASSOCCHANGED` flushes icon cache               |
| Everything (nuclear)          | `RefreshAll`                 | `SHCNE_ALLEVENTS` — slow, use sparingly               |

### Flush Flags

- **`SHCNF_FLUSH`** — Blocks until all Explorer windows have processed the
  notification. Use for operations where the user expects to see the result
  immediately (folder icons, associations).
- **`SHCNF_FLUSHNOWAIT`** — Begins notification delivery but returns immediately.
  Use for bulk operations (creating many files) where blocking would be slow.
- **`SHCNF_PATH`** — Pass file/folder paths as strings. This is what you want
  from PowerShell. Always combine with a flush flag.

### Important: desktop.ini Folder Icons

For folder icons set via `desktop.ini`, the full sequence is:

1. Write the `desktop.ini` file with `[.ShellClassInfo]` and `IconResource`
2. Set `desktop.ini` as System + Hidden: `attrib +S +H "$folder\desktop.ini"`
3. Set the **folder itself** as ReadOnly: `attrib +R $folder`
   (this is what tells Explorer to check for `desktop.ini`)
4. Call `FolderIconChanged($folder)` to force the refresh

If step 3 is missing, Explorer ignores the `desktop.ini` entirely.

## Pattern: Dynamic File Discovery

Prefer dynamic discovery over hardcoded file lists. Windows cache files, log files, and
temp artifacts change across versions.

```powershell
$cacheFiles = [List[string]]@()
if (Test-Path -LiteralPath $searchDir) {
    $found = Get-ChildItem -LiteralPath $searchDir `
        -Filter 'pattern_*' -File -EA SilentlyContinue
    foreach ($f in $found) { $cacheFiles.Add($f.FullName) }
}

if ($cacheFiles.Count -eq 0) {
    Write-Warning "No target files found. Nothing to do."
    return
}
Write-Verbose "Discovered $($cacheFiles.Count) file(s) in '$searchDir'"
```

## Pattern: Explorer Window Capture and Restore

When restarting Explorer, capture open windows beforehand and restore them after.
Uses FMDevToolbox module functions.

```powershell
# Capture before killing Explorer
$openWindows = Get-OpenDirectories
Write-Verbose "Captured $(@($openWindows).Count) open Explorer window(s)"

# ... kill explorer, do work, restart explorer ...

# Restore after Explorer is back
if ($openWindows) {
    Open-WindowsExplorerTo -LiteralPath $openWindows -WindowStyle Minimized
    Write-Verbose "Restored $(@($openWindows).Count) Explorer window(s)"
}
```

## Pattern: HKCR Registry Access

`HKEY_CLASSES_ROOT` has no built-in PSDrive. Create a temporary one and clean it up.

```powershell
# Create in begin/setup
Remove-PSDrive -Name HKCR -Force -EA SilentlyContinue
New-PSDrive -PSProvider Registry -Name HKCR -Root 'HKEY_CLASSES_ROOT' | Out-Null

# Use it
if (Test-Path -LiteralPath "HKCR:\$extension") { ... }

# Clean up when done
Remove-PSDrive -Name HKCR -Force -EA SilentlyContinue
```

## Naming Conventions

| Element            | Convention                        | Example                       |
|--------------------|-----------------------------------|-------------------------------|
| Function name      | `Verb-WindowsNoun` or `Verb-Noun` | `Reset-WindowsIconCache`      |
| Parameters         | PascalCase                        | `$Extension`, `$ServiceName`  |
| Local variables    | camelCase, strongly typed         | `[string] $regPath`           |
| Command variables  | `$cmd*` prefix                    | `$cmdLockhunter`              |
| State capture vars | descriptive, typed                | `[bool] $timeBrokerIsRunning` |
| Boolean state      | `$*IsRunning`, `$*WasEnabled`     | `[bool] $svcIsRunning`        |

Use **approved PowerShell verbs** (`Get-Verb`). Common choices for admin functions:

| Verb                   | When to use                                  |
|------------------------|----------------------------------------------|
| `Reset-`               | Restore something to its default/clean state |
| `Clear-`               | Remove contents but keep the container       |
| `Remove-`              | Delete something entirely                    |
| `Stop-` / `Start-`     | Service/process control                      |
| `Enable-` / `Disable-` | Toggle a feature or setting                  |
| `Show-`                | Make something visible in the UI             |
| `Repair-`              | Fix a broken state                           |
| `Sync-`                | Align two sources of truth                   |
| `Optimize-`            | Improve performance of something             |

## Critical Pattern: Guaranteed Cleanup with try/finally

Admin scripts modify shared system state. If an error occurs during the Modify phase,
the Restore phase **must still run** — otherwise you leave services stopped, registry
keys modified, `AutoRestartShell` disabled, etc.

Wrap Phases 3 and 4 in `try/finally`:

```powershell
# ── Phase 2: Capture State ───────────────────────────────────
$openWindows = Get-OpenDirectories
$originalAutoRestart = (Get-ItemProperty -LiteralPath $winlogonKey `
    -Name 'AutoRestartShell' -EA SilentlyContinue).AutoRestartShell

try {
    # ── Phase 3: Modify ──────────────────────────────────────
    Set-ItemProperty -LiteralPath $winlogonKey `
        -Name 'AutoRestartShell' -Value 0 -Type DWord
    Invoke-Expression "taskkill /F /IM explorer.exe"

    # ... do the actual work ...
}
finally {
    # ── Phase 4: Restore (runs even if Phase 3 throws) ───────
    # Restart Explorer via scheduled task
    $taskName  = 'FMDevToolbox_RestartExplorer'
    $action    = New-ScheduledTaskAction `
        -Execute "$env:SystemRoot\explorer.exe"
    $principal = New-ScheduledTaskPrincipal `
        -UserId $env:USERNAME -LogonType Interactive `
        -RunLevel Limited
    Register-ScheduledTask -TaskName $taskName `
        -Action $action -Principal $principal -Force | Out-Null
    Start-ScheduledTask -TaskName $taskName
    Start-Sleep -Milliseconds 500
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false

    # Restore registry
    $restoreValue = if ($null -eq $originalAutoRestart) { 1 }
        else { $originalAutoRestart }
    Set-ItemProperty -LiteralPath $winlogonKey `
        -Name 'AutoRestartShell' -Value $restoreValue -Type DWord

    # Restore services and Explorer windows
    if ($runningServiceName) {
        Start-Service -Name $runningServiceName
    }
    if ($openWindows) {
        Open-WindowsExplorerTo -LiteralPath $openWindows `
            -WindowStyle Minimized
    }

    Write-Verbose "Cleanup complete"
}
```

**Why this matters:** Without `finally`, a thrown exception or `Ctrl+C` during cache
deletion leaves Explorer dead, `AutoRestartShell` disabled, and services stopped. The
user must manually fix their system. With `finally`, the system always recovers.

## Pattern: Self-Elevation

For scripts that the user double-clicks or runs from a non-admin terminal, re-launch
as admin automatically instead of just throwing an error:

```powershell
$isAdmin = ([WindowsPrincipal][WindowsIdentity]::GetCurrent()
).IsInRole([WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $psExe = (Get-Process -Id $PID).Path
    Start-Process $psExe -Verb RunAs -ArgumentList @(
        '-NoProfile'
        '-ExecutionPolicy', 'Bypass'
        '-File', "`"$PSCommandPath`""
    )
    return
}
```

Use self-elevation for **standalone scripts** in `x:\.admin`. For **module functions**,
prefer `throw` — the caller should decide how to handle elevation.

## Pattern: Common Windows Paths

Always use `[Environment]::GetFolderPath()` or environment variables — never hardcode
user profile paths like `C:\Users\username\...`.

```powershell
# User-specific paths
$localAppData = [Environment]::GetFolderPath(
    [Environment+SpecialFolder]::LocalApplicationData)
$appData      = [Environment]::GetFolderPath(
    [Environment+SpecialFolder]::ApplicationData)
$userProfile  = [Environment]::GetFolderPath(
    [Environment+SpecialFolder]::UserProfile)

# System paths
$systemRoot   = $env:SystemRoot          # C:\Windows
$programFiles = $env:ProgramFiles        # C:\Program Files
$programX86   = ${env:ProgramFiles(x86)} # C:\Program Files (x86)
$commonStart  = [Environment]::GetFolderPath(
    [Environment+SpecialFolder]::CommonStartMenu)
```

## Coding Standards

Same baseline as `powershell-file-processing`, plus:

- `SupportsShouldProcess` on any function that modifies system state
- Use `$PSCmdlet.ShouldProcess($target, 'Action')` before destructive operations
- `using namespace System.Security.Principal` when checking admin privileges
- Use `taskkill /F /IM` via `Invoke-Expression` for reliable process termination
  (more reliable than `Stop-Process` for system processes)
- Use `Write-Verbose` extensively — admin scripts are debugged via `-Verbose` flag
- Use `Write-Host` with PwshSpectreConsole formatting for user-facing status
  (admin scripts are interactive, not pipeline-composable)
- Max line length: **110 characters.** Use backtick continuation or splats.

## Standalone Admin Scripts (x:\.admin)

Scripts in `x:\.admin` are standalone — they define their function and call it at the
end of the file. They are NOT part of the FMDevToolbox module.

```powershell
using namespace System.IO
using namespace System.Security.Principal

function Reset-WindowsIconCache {
    [CmdletBinding()]
    param ()

    # ... function body ...
}

# Self-execute
Reset-WindowsIconCache
```

These scripts:

- CAN use FMDevToolbox module functions if the module is loaded (auto-loaded via profile)
- Should NOT assume the module is loaded for critical operations
- Should include `Clear-Host` at the start for clean terminal output
- May use `Read-Host` at the end to prevent premature console closure

## Quick Checklist

Before delivering an admin function, verify:

- [ ] `using namespace` declarations at file top (including `System.Security.Principal`)
- [ ] `[CmdletBinding()]` present (add `SupportsShouldProcess` if modifying state)
- [ ] Admin privilege check at top of function (if elevation is required)
- [ ] All affected state captured BEFORE any modifications
- [ ] All captured state restored AFTER work is done (even on error paths)
- [ ] Explorer restart uses scheduled task pattern (not direct launch)
- [ ] Registry values backed up before modification and restored after
- [ ] Services/processes only restarted if they were running before
- [ ] `Write-Verbose` at every significant step
- [ ] Temporary resources cleaned up (scheduled tasks, PSDrives, temp files)
- [ ] `$LASTEXITCODE` checked after external process calls
- [ ] No line exceeds 110 characters
- [ ] Variables are camelCase and strongly typed
- [ ] Parameters are PascalCase with `HelpMessage`
