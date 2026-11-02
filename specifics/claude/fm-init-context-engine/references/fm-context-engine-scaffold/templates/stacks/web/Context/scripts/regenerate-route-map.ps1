#Requires -Version 7.1
using namespace System.IO

<#
.SYNOPSIS
    Regenerates Context/generated/route-map.md — the site's URL surface, walked
    from the filesystem.

.DESCRIPTION
    Seeded by the context-engine web adapter; project-owned — tune the detection
    or add a framework freely.

    Detects the routing convention in use and walks the route directory:

      Next.js App Router    app/ or src/app/         page.* and route.*
      Next.js Pages Router  pages/ or src/pages/     *.tsx, with pages/api/* as endpoints
      Astro                 src/pages/               *.astro|md|mdx, with *.ts as endpoints
      Nuxt                  pages/ or app/pages/     *.vue, with server/api/* as endpoints
      SvelteKit             src/routes/              +page.svelte and +server.*

    Route groups and private folders are stripped from the URL the way each
    framework strips them, and dynamic segments are preserved in the framework's
    own bracket syntax so they stay recognizable.

    Each row carries a rendering note where the filesystem can prove one: a
    Next.js page marked "use client", a SvelteKit route with a server load, the
    client islands an Astro page hydrates.

    A client-only SPA defines routes in code rather than on disk, so no
    filesystem walk can find them. In that case this reports what it did find
    (the router config) and says so plainly rather than inventing a route table.

    Contract (Context/scripts/README.md): standalone, fast, writes exactly one
    banner-prefixed artifact into Context/generated/.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR }
            else { (Get-Location).ProviderPath }
$outPath = [Path]::Combine($repoRoot, 'Context', 'generated', 'route-map.md')

# ── Helpers ─────────────────────────────────────────────────────────────────

function Get-Array {
    # @($null) is a one-element array holding $null, and a function returning
    # @() emits nothing at all. The unary comma makes an empty array survive.
    param([AllowNull()] $Value)
    if ($null -eq $Value) { return , @() }
    return , @($Value)
}

function Test-RepoPath {
    param([Parameter(Mandatory)] [string] $Relative)
    return (Test-Path -LiteralPath ([Path]::Combine($repoRoot, $Relative)))
}

function Get-FirstMatch {
    # First existing path from a candidate list, as a repo-relative string.
    param([Parameter(Mandatory)] [string[]] $Candidates)
    foreach ($c in $Candidates) { if (Test-RepoPath $c) { return $c } }
    return $null
}

function Get-RelativePath {
    param([Parameter(Mandatory)] [string] $FullPath)
    return ($FullPath.Substring($repoRoot.Length + 1) -replace '\\', '/')
}

function Test-UseClient {
    # True when the file opens with a "use client" directive. Only the first few
    # lines matter: the directive must precede all other statements.
    param([Parameter(Mandatory)] [string] $FullPath)
    try {
        $head = Get-Content -LiteralPath $FullPath -TotalCount 5 -ErrorAction Stop
    }
    catch { return $false }
    foreach ($line in (Get-Array $head)) {
        $t = "$line".Trim()
        if (-not $t -or $t.StartsWith('//') -or $t.StartsWith('/*') -or $t.StartsWith('*')) { continue }
        return ($t -match '^["'']use client["'']')
    }
    return $false
}

function Get-AstroIsland {
    # Client directives used on a page, e.g. client:load / client:visible.
    # Every stage is wrapped in @() so an empty result stays an empty ARRAY —
    # returning $null here would make .Count throw at the call site.
    param([Parameter(Mandatory)] [string] $FullPath)
    try { $text = Get-Content -LiteralPath $FullPath -Raw -ErrorAction Stop }
    catch { return , @() }
    $found = @([regex]::Matches($text, 'client:(load|idle|visible|media|only)') |
        ForEach-Object { $_.Value })
    $unique = @($found | Sort-Object -Unique)
    return , $unique
}

function Convert-SegmentToUrl {
    # Joins route segments into a URL path. $Strip is a regex for segments the
    # framework removes from the URL (route groups, private folders).
    #
    # Note: do NOT pipe Get-Array here. Its protective comma wrapper unrolls on
    # the pipeline, handing Where-Object the whole array as a single item — the
    # filter then runs against an array and the join yields "System.Object[]".
    # $Segments is already [string[]], so @() alone is the right normalization.
    param([AllowNull()] [string[]] $Segments, [string] $Strip)
    # The outer @() is required: assigning an if-expression unrolls a
    # single-element array into a bare scalar.
    $all = @(if ($null -eq $Segments) { @() } else { $Segments })
    $kept = @($all | Where-Object {
        $_ -and ($_ -ne '') -and -not ($Strip -and $_ -match $Strip)
    })
    if (-not $kept.Count) { return '/' }
    return '/' + ($kept -join '/')
}

function Remove-IndexSegment {
    # Drops a trailing "index" segment. Two guards needed:
    #   * the outer @() below — assigning an if-expression unrolls a
    #     single-element array into a scalar, and .Count then throws;
    #   * the Count -gt 1 test — $a[0..($n-2)] with one element becomes
    #     $a[0..-1], which PowerShell reads as the WHOLE array, not an
    #     empty slice.
    param([AllowNull()] [string[]] $Segments)
    $all = @(if ($null -eq $Segments) { @() } else { $Segments })
    if ($all.Count -and $all[-1] -eq 'index') {
        if ($all.Count -gt 1) { return , @($all[0..($all.Count - 2)]) }
        return , @()
    }
    return , $all
}

# ── Detect the framework ────────────────────────────────────────────────────

$configGlobs = @{
    nextjs    = @('next.config.js', 'next.config.mjs', 'next.config.ts', 'next.config.cjs')
    astro     = @('astro.config.mjs', 'astro.config.js', 'astro.config.ts')
    nuxt      = @('nuxt.config.ts', 'nuxt.config.js')
    sveltekit = @('svelte.config.js', 'svelte.config.ts')
}

$framework = $null
$configFile = $null
foreach ($name in @('nextjs', 'astro', 'nuxt', 'sveltekit')) {
    $hit = Get-FirstMatch -Candidates $configGlobs[$name]
    if ($hit) { $framework = $name; $configFile = $hit; break }
}

$rows = [System.Collections.Generic.List[object]]::new()
$routeRoot = $null
$convention = $null

function Add-Row {
    param([string] $Route, [string] $Kind, [string] $File, [string] $Note)
    $rows.Add([pscustomobject]@{
        Route = $Route; Kind = $Kind; File = $File
        Note  = if ($Note) { $Note } else { '' }
    })
}

# ── Walk ────────────────────────────────────────────────────────────────────

switch ($framework) {

    'nextjs' {
        $appRoot = Get-FirstMatch -Candidates @('app', 'src/app')
        $pagesRoot = Get-FirstMatch -Candidates @('pages', 'src/pages')

        if ($appRoot) {
            $convention = 'Next.js App Router'
            $routeRoot = $appRoot
            $base = [Path]::Combine($repoRoot, $appRoot)
            $files = Get-ChildItem -LiteralPath $base -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { $_.BaseName -in @('page', 'route') -and $_.Extension -in @('.tsx', '.jsx', '.ts', '.js', '.mdx') }

            foreach ($f in ($files | Sort-Object FullName)) {
                $relDir = [Path]::GetDirectoryName($f.FullName).Substring($base.Length).TrimStart('\', '/')
                $segments = @($relDir -split '[\\/]' | Where-Object { $_ })
                # Parallel routes (@slot) and private folders (_x) are not URLs.
                if ($segments | Where-Object { $_.StartsWith('@') -or $_.StartsWith('_') }) { continue }
                # Route groups (group) and intercepting markers are stripped.
                $url = Convert-SegmentToUrl -Segments $segments -Strip '^\(.*\)$'
                $kind = if ($f.BaseName -eq 'route') { 'Endpoint' } else { 'Page' }
                $note = if ($kind -eq 'Page' -and (Test-UseClient $f.FullName)) {
                    'client component'
                } elseif ($kind -eq 'Page') { 'server component' } else { '' }
                Add-Row -Route $url -Kind $kind -File (Get-RelativePath $f.FullName) -Note $note
            }
        }
        elseif ($pagesRoot) {
            $convention = 'Next.js Pages Router'
            $routeRoot = $pagesRoot
            $base = [Path]::Combine($repoRoot, $pagesRoot)
            $files = Get-ChildItem -LiteralPath $base -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Extension -in @('.tsx', '.jsx', '.ts', '.js', '.mdx') -and $_.BaseName -notmatch '^_' }

            foreach ($f in ($files | Sort-Object FullName)) {
                $rel = $f.FullName.Substring($base.Length).TrimStart('\', '/')
                $noExt = [Path]::ChangeExtension($rel, $null).TrimEnd('.')
                $segments = @($noExt -split '[\\/]' | Where-Object { $_ })
                $segments = Remove-IndexSegment -Segments $segments
                $isApi = $rel -match '^api[\\/]'
                Add-Row -Route (Convert-SegmentToUrl -Segments $segments -Strip $null) `
                    -Kind $(if ($isApi) { 'Endpoint' } else { 'Page' }) `
                    -File (Get-RelativePath $f.FullName) -Note ''
            }
        }
    }

    'astro' {
        $convention = 'Astro'
        $routeRoot = 'src/pages'
        if (Test-RepoPath $routeRoot) {
            $base = [Path]::Combine($repoRoot, $routeRoot)
            $files = Get-ChildItem -LiteralPath $base -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Extension -in @('.astro', '.md', '.mdx', '.ts', '.js') -and -not $_.Name.StartsWith('_') }

            foreach ($f in ($files | Sort-Object FullName)) {
                $rel = $f.FullName.Substring($base.Length).TrimStart('\', '/')
                $noExt = [Path]::ChangeExtension($rel, $null).TrimEnd('.')
                $segments = @($noExt -split '[\\/]' | Where-Object { $_ })
                $segments = Remove-IndexSegment -Segments $segments
                $isEndpoint = $f.Extension -in @('.ts', '.js')
                $note = ''
                if (-not $isEndpoint -and $f.Extension -eq '.astro') {
                    $islands = Get-AstroIsland $f.FullName
                    $note = if ($islands.Count) { "islands: $($islands -join ', ')" } else { 'zero JS' }
                }
                Add-Row -Route (Convert-SegmentToUrl -Segments $segments -Strip $null) `
                    -Kind $(if ($isEndpoint) { 'Endpoint' } else { 'Page' }) `
                    -File (Get-RelativePath $f.FullName) -Note $note
            }
        }
    }

    'nuxt' {
        $convention = 'Nuxt'
        $routeRoot = Get-FirstMatch -Candidates @('pages', 'app/pages', 'src/pages')
        if ($routeRoot) {
            $base = [Path]::Combine($repoRoot, $routeRoot)
            foreach ($f in (Get-ChildItem -LiteralPath $base -Recurse -File -Filter '*.vue' -ErrorAction SilentlyContinue | Sort-Object FullName)) {
                $rel = $f.FullName.Substring($base.Length).TrimStart('\', '/')
                $noExt = [Path]::ChangeExtension($rel, $null).TrimEnd('.')
                $segments = @($noExt -split '[\\/]' | Where-Object { $_ })
                $segments = Remove-IndexSegment -Segments $segments
                Add-Row -Route (Convert-SegmentToUrl -Segments $segments -Strip $null) `
                    -Kind 'Page' -File (Get-RelativePath $f.FullName) -Note ''
            }
        }
        foreach ($srvDir in @('server/api', 'server/routes')) {
            if (-not (Test-RepoPath $srvDir)) { continue }
            $base = [Path]::Combine($repoRoot, $srvDir)
            foreach ($f in (Get-ChildItem -LiteralPath $base -Recurse -File -ErrorAction SilentlyContinue | Sort-Object FullName)) {
                Add-Row -Route "/$($srvDir -replace '^server/', '')/$(([Path]::ChangeExtension($f.FullName.Substring($base.Length).TrimStart('\','/'), $null)).TrimEnd('.') -replace '\\', '/')" `
                    -Kind 'Endpoint' -File (Get-RelativePath $f.FullName) -Note ''
            }
        }
    }

    'sveltekit' {
        $convention = 'SvelteKit'
        $routeRoot = 'src/routes'
        if (Test-RepoPath $routeRoot) {
            $base = [Path]::Combine($repoRoot, $routeRoot)
            $files = Get-ChildItem -LiteralPath $base -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match '^\+(page\.svelte|server\.(ts|js))$' }

            foreach ($f in ($files | Sort-Object FullName)) {
                $dir = [Path]::GetDirectoryName($f.FullName)
                $relDir = $dir.Substring($base.Length).TrimStart('\', '/')
                $segments = @($relDir -split '[\\/]' | Where-Object { $_ })
                $url = Convert-SegmentToUrl -Segments $segments -Strip '^\(.*\)$'
                if ($f.Name -match '^\+server\.') {
                    Add-Row -Route $url -Kind 'Endpoint' -File (Get-RelativePath $f.FullName) -Note ''
                }
                else {
                    $note = if (Test-Path -LiteralPath ([Path]::Combine($dir, '+page.server.ts'))) { 'server load' }
                            elseif (Test-Path -LiteralPath ([Path]::Combine($dir, '+page.ts'))) { 'universal load' }
                            else { 'no load function' }
                    Add-Row -Route $url -Kind 'Page' -File (Get-RelativePath $f.FullName) -Note $note
                }
            }
        }
    }
}

# ── Emit ────────────────────────────────────────────────────────────────────

$sb = [System.Text.StringBuilder]::new()
$null = $sb.AppendLine('<!-- GENERATED FILE — DO NOT EDIT — regenerated by Context/scripts/regenerate-route-map.ps1 -->')
$null = $sb.AppendLine('<!-- Source: filesystem walk of the framework route directory -->')
$null = $sb.AppendLine("<!-- Last run: $(Get-Date -AsUTC -Format 'yyyy-MM-ddTHH:mm:ssZ') -->")
$null = $sb.AppendLine('')
$null = $sb.AppendLine('# Route Map')
$null = $sb.AppendLine('')

if (-not $framework) {
    $null = $sb.AppendLine('**No file-based routing framework detected.**')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('No `next.config.*`, `astro.config.*`, `nuxt.config.*`, or `svelte.config.*` was found at the repo root. Two common reasons:')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('- **A client-only SPA.** Routes are declared in code (a router config array), not on disk, so no filesystem walk can enumerate them. Document them by hand in `Context/architecture/` instead.')
    $null = $sb.AppendLine('- **A plain static site.** Pages are whatever HTML files ship; list them by hand if the set is worth tracking.')
    $spaHints = @(@('vite.config.ts', 'vite.config.js', 'src/router/index.ts', 'src/routes.tsx', 'src/App.tsx', 'angular.json') |
        Where-Object { Test-RepoPath $_ })
    if ($spaHints.Count) {
        $null = $sb.AppendLine('')
        $null = $sb.AppendLine('Files found that suggest where routes are defined:')
        $null = $sb.AppendLine('')
        foreach ($h in $spaHints) { $null = $sb.AppendLine("- ``$h``") }
    }
}
elseif (-not $rows.Count) {
    $null = $sb.AppendLine("Detected **$convention** (``$configFile``), but no route files were found under ``$routeRoot``.")
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('Either the project has not added routes yet, or it uses a non-default route directory. Adjust the walk in the regenerator if so.')
}
else {
    $pages = @($rows | Where-Object { $_.Kind -eq 'Page' })
    $endpoints = @($rows | Where-Object { $_.Kind -eq 'Endpoint' })
    $dynamic = @($rows | Where-Object { $_.Route -match '[\[:]' })

    $null = $sb.AppendLine("Detected **$convention** (``$configFile``), routes under ``$routeRoot``.")
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine("$($pages.Count) page(s), $($endpoints.Count) endpoint(s), $($dynamic.Count) with dynamic segments.")
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('Every route here is **public surface**: renaming or removing one breaks existing links and needs a redirect.')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('| Route | Kind | Rendering | Source |')
    $null = $sb.AppendLine('| ----- | ---- | --------- | ------ |')
    foreach ($r in ($rows | Sort-Object Kind, Route)) {
        $note = if ($r.Note) { $r.Note } else { '—' }
        $null = $sb.AppendLine("| ``$($r.Route)`` | $($r.Kind) | $note | [$($r.File)](../../$($r.File)) |")
    }

    $dupes = @($rows | Group-Object Route, Kind | Where-Object { $_.Count -gt 1 })
    if ($dupes.Count) {
        $null = $sb.AppendLine('')
        $null = $sb.AppendLine('## Findings')
        $null = $sb.AppendLine('')
        foreach ($d in $dupes) {
            $null = $sb.AppendLine("- Route ``$($d.Group[0].Route)`` is served by $($d.Count) files of the same kind — one shadows the other.")
        }
    }
}

$null = $sb.AppendLine('')
$null = [Directory]::CreateDirectory([Path]::GetDirectoryName($outPath))
[File]::WriteAllText($outPath, $sb.ToString().Replace("`r`n", "`n"), [System.Text.UTF8Encoding]::new($false))
Write-Host "route-map: $($rows.Count) route(s)$(if ($convention) { " ($convention)" }) -> Context/generated/route-map.md"
exit 0
