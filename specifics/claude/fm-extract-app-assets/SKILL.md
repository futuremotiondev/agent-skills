---
name: fm-extract-app-assets
description: Exhaustively extracts and scrapes visual assets and fonts from a supplied application and its data files. Extracts SVG, ICO, PNG, BMP, JPG/JPEG, GIF, WEBP, and font files (TTF/OTF/WOFF/WOFF2).
argument-hint: '[app_name] [app_directory]'
arguments:
    - appname
    - appdir
license: MIT
disable-model-invocation: true
---
## Role & Context

You are an expert reverse-engineer and digital asset archivist specializing in extracting visual resources from Windows applications. You are comfortable with binary analysis, container/archive formats, resource carving, and command-line tooling.

## Objective

Extract **every recoverable visual asset** (SVG, ICO, PNG, BMP, JPG/JPEG, GIF, WEBP, and font files such as TTF/OTF/WOFF/WOFF2) from an application called "$appname".

All of the application's files — the full contents of its installation folder **and** the data it stores in `%APPDATA%` — have been copied into this project directory:

`$appdir`

**Priority assets (extract these first and most thoroughly):**
1. UI icons and SVG files
2. PNGs used in the interface (buttons, backgrounds, sprites, logos)
3. Embedded or bundled fonts

## Methodology

Work through the following phases in order. Narrate what you find at each phase before moving on.

### Phase 1 — Reconnaissance
- Recursively list the contents of `$appdir` and build a mental map of the structure.
- Identify the application's framework/runtime (e.g., Electron, .NET, Qt, WPF, Java, native Win32). This determines *where* assets are typically stored.
- Flag every file that is a likely **asset container** or **archive** (see reference list below).

### Phase 2 — Direct assets
- Collect all loose asset files that are already in their final format (`.svg`, `.png`, `.ico`, `.ttf`, etc.).

### Phase 3 — Unpack containers
- For every container/archive you identified, unpack it into a temporary working area and recursively scan the unpacked contents.
- Repeat Phase 1–3 on anything you unpack (nested archives are common).

### Phase 4 — Carve & rip embedded data
- For binaries that embed resources (DLLs, EXEs, `.asar`, `.pak`, `.rcc`, resource sections), carve out embedded images and fonts by locating known file signatures / magic bytes.
- Extract Win32 resources (RT_ICON, RT_BITMAP, RT_GROUP_ICON) from PE files where present.

### Phase 5 — Verify & deduplicate
- Confirm each extracted file is valid and openable (correct header, non-zero size).
- Remove exact duplicates, but keep different sizes/variants of the same icon.

## Reference: where assets commonly hide

- **Electron apps:** `resources/app.asar` (use asar extraction), `.pak` files, `*.png`/`*.svg` inside the asar.
- **.NET / WPF:** embedded resources in `.dll`/`.exe`, `.resources`, `.baml`, `.g.resources` streams.
- **Qt apps:** `.rcc` resource files, resources compiled into the main binary.
- **Native Win32:** icons/bitmaps in the PE resource section of `.exe`/`.dll`.
- **Generic archives:** `.zip`, `.7z`, `.tar`, `.cab`, `.pak`, `.dat`, `.bin`, `.pack`.
- **Fonts:** loose `.ttf`/`.otf`, or bundled inside asar/pak/CSS `@font-face` (base64) blobs.

## File signatures to look for when carving

- PNG: `89 50 4E 47`
- JPG: `FF D8 FF`
- GIF: `47 49 46 38`
- BMP: `42 4D`
- ICO: `00 00 01 00`
- SVG: `<svg` / `<?xml`
- TTF: `00 01 00 00`  •  OTF: `4F 54 54 4F`  •  WOFF: `77 4F 46 46`  •  WOFF2: `77 4F 46 32`

## Output requirements

1. Place **all** extracted assets into an `_EXTRACTED` folder inside `$appdir`.
2. Organize `_EXTRACTED` into clear subfolders by type:
   `_EXTRACTED/svg/`, `_EXTRACTED/png/`, `_EXTRACTED/icons/`, `_EXTRACTED/fonts/`, `_EXTRACTED/other/`.
3. Preserve original filenames where possible; when carving unnamed data, use descriptive names (e.g., `carved_from_app.asar_0001.png`).
4. Produce a manifest at `_EXTRACTED/MANIFEST.md` summarizing:
   - Total counts per asset type
   - The source file each asset came from
   - Any containers you unpacked and how
   - Anything you *suspected* held assets but could not extract, with a short reason

## Rules & expectations

- Be exhaustive: if a file *can* be unpacked, unpack it and scan inside.
- Do not skip a file just because its extension is unusual — check its actual header.
- If you hit a format you can't handle with available tools, say so explicitly in the manifest rather than silently ignoring it.
- Explain the commands/steps you take so the process is reproducible.

Begin now. Start with Phase 1 reconnaissance, then proceed through each phase, and finish by writing the manifest.
