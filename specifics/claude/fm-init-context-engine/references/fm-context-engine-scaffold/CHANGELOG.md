# Changelog

Changes to what the engine seeds into projects, newest first. `Update-ContextEngine.ps1 -RefreshSeeds` reads this file: it reports the entries newer than a project's last refresh for the project's adapter chain (plus `core`), and runs each `Detect:` pattern as a regular expression over the project's git-tracked source, so the refresh report says where code may need to follow. The file is never installed.

Format: `## <engine version>`, then `### <adapter name or core>`, then one bullet per change, `- **Kind:** what changed`, with optional sub-bullets `- Impact: …` and `- Detect: <regex in backticks>`. Kinds: **Fact** (a correction or new platform fact), **Deprecation** (a platform removal; code impact likely), **Guardrail** (a security or correctness rule changed), **Default** (a recommended choice changed), **Floor** (a release-channel reference floor moved), **Structure** (a file added, renamed, or removed). How to write entries: `docs/REFRESHING-STACKS.md`.

## 2026.09.30

### obsidian-plugin

- **Structure:** New stack for Obsidian community plugins on the public (1.13.0+) or Early access (1.14.0+) channel. It inherits `typescript` and seeds `obsidian-plugin-style.md`, `.claude/rules/obsidian-plugin-boundaries.md`, `.claude/rules/obsidian-plugin-manifest.md`, and `regenerate-obsidian-manifest-index.ps1`. Facts were verified against 1.13.7 (public) and 1.14.3 (Early access) on 2026-09-30.
  - Impact: none for existing installs; `/fm-init-context-engine obsidian-plugin` installs it.

## 2026.09.29.2

### core

- **Structure:** Installed projects can now take template improvements: `Update-ContextEngine.ps1 -RefreshSeeds` three-way merges the engine's current templates into the seeded files, and `-CompleteRefresh` records what was resolved. `.claude/context-engine.psd1` gains `SeedRefreshExclude`, and `Context/USAGE.md` describes the refresh.
  - Impact: none until you refresh. `/fm-init-context-engine refresh` drives it.

## 2026.09.29.1

### core

- **Structure:** Every conventions README gains a "Facts, guardrails, and defaults" section: the three kinds of statement, the deviation protocol, and a note that the agent-rules Do lists hold guardrails and binding decisions while defaults stay in the style documents.
  - Impact: none in code. An agent now proposes deviations from a default instead of refusing the work.
- **Structure:** `/validate-context` (engine-owned) no longer reports a recorded deviation from a **Default:** as drift; it suggests recording an unrecorded one instead of reverting the code.

### typescript

- **Default:** `typescript-style.md` marks its recommended choices **Default:** (extra compiler flags, module shape, `Promise.all`, lint and format in CI); strict mode, `any` at boundaries, input validation, and floating promises stay guardrails.

### csharp

- **Default:** `csharp-style.md` marks its recommended choices **Default:** (file and namespace layout, records and sealed classes, collection types, exception types, async naming); nullable reference types, swallowed exceptions, `async void`, and sync-over-async stay guardrails.

### python

- **Default:** `python-style.md` marks its recommended choices **Default:** (pyproject and src layout, ruff, pytest, typing style, pathlib, docstrings); the virtual environment, context managers, and narrow exception handling stay guardrails.

### powershell-module

- **Default:** `powershell-style.md` marks its recommended choices **Default:** (function shape, parameter layout, the output contract, collection types); `-LiteralPath`, `-WhatIf`, thread-safe collections in `-Parallel`, and exit-code checks stay guardrails.
- **Fact:** A non-zero native exit does set `$?` to `$false`. The trap is that it writes no error record, so `try`/`catch` and `-ErrorAction` miss it unless `$PSNativeCommandUseErrorActionPreference` is on (stable since PowerShell 7.4).
  - Impact: a native call guarded only by `try`/`catch` fails silently; check `$LASTEXITCODE` after it.
- **Fact:** .NET resolves relative paths against the process directory, not the current PowerShell location, which is why user paths go through `GetUnresolvedProviderPathFromPSPath` first.

### cpp

- **Default:** `cpp-style.md` marks its recommended choices **Default:**; `cpp-boundaries.md` no longer mandates `#pragma once` or an include order (it requires an include guard of any kind and self-contained includes).

### rust

- **Default:** `rust-style.md` marks its recommended choices **Default:** (thiserror/anyhow, clippy gates, `pub(crate)`, cbindgen); `rust-boundaries.md` drops the `pub(crate)` preference, which is a default.
- **Fact:** Edition 2024 warns on `unsafe_op_in_unsafe_fn` by default.

### winui3

- **Default:** `winui3-style.md` marks its recommended choices **Default:** (CommunityToolkit.Mvvm, `x:Bind`, resource dictionaries); `xaml-winui3.md` states the `x:Bind` `OneTime` default as a fact instead of preferring `x:Bind`.

### wpf

- **Default:** `wpf-style.md` marks its recommended choices **Default:** (CommunityToolkit.Mvvm, freezing Freezables, shallow templates, resource dictionaries); `xaml-wpf.md` keeps only binding, theming, virtualization, and accessibility facts and guardrails.

### avalonia

- **Default:** `avalonia-style.md` marks its recommended choices **Default:**, and platform-specific markup is no longer called a hack: small per-platform values can use `OnPlatform` and `OnFormFactor`, which resolve once at startup.

### electron

- **Default:** The channel registry and `invoke`/`handle` are marked **Default:**; the process-model rules are named guardrails, and `electron-boundaries.md` phrases the registry conditionally.
- **Guardrail:** `src/shared/` excludes code that depends on one process's APIs, rather than all runtime code, so pure helpers may be shared.

### web

- **Default:** `web-style.md` marks its recommended choices **Default:** (URL style, styling approach, performance budget, SEO, forms); the server/client boundary, routing, and accessibility rules stay guardrails.

### nextjs

- **Default:** `nextjs-style.md` marks its recommended choices **Default:** (pushing the client boundary down, fetch placement, `server-only`, `Link`, the font loader); `nextjs-boundaries.md` states why a page-level `"use client"` costs, instead of forbidding it.

### astro

- **Default:** `astro-style.md` marks its directive choices **Default:**; `astro-boundaries.md` keeps what each `client:*` directive does and drops which one to prefer.

### figma-plugin

- **Default:** The message registry, `findAllWithCriteria`, batching, and `eslint-plugin-figma-plugins` are marked **Default:**; `figma-plugin-boundaries.md` phrases the registry conditionally.

### browser-extension

- **Structure:** `extension-manifest.md` gains the facts-and-guardrails line its sibling rules carry, and the conventions README's closing paragraph names the agent-rules Do lists.

## 2026.09.29

### core

- **Structure:** Installs record the stack, adapter chain, installer answers, config defaults, and a baseline snapshot of every seeded file (manifest schema 2, `.claude/context-engine/baseline/`), the merge base later refreshes need.

### browser-extension

- **Structure:** `browser-extension` becomes the browser-neutral base for the new `firefox-extension` and `chrome-extension` stacks. New: `.claude/rules/extension-manifest.md` and `Context/scripts/extension-targets.psd1`; the manifest index now checks each manifest against the targets recorded there.
  - Impact: record the project's target browsers, channels, and floors in `extension-targets.psd1`.
- **Deprecation:** `webextension-polyfill` was archived on 2026-07-30 and stops wrapping on Chrome 148 and later. Below 148, `globalThis.browser ??= chrome` is the documented guard.
  - Impact: remove the polyfill once the Chrome floor is 148 or later.
  - Detect: `webextension-polyfill`
- **Guardrail:** Never pass an `async` function directly to `runtime.onMessage.addListener`: it answers every message, including ones meant for other listeners.
  - Impact: such a listener steals replies; route messages through one plain dispatcher.
  - Detect: `onMessage\.addListener\(\s*async`
- **Default:** WXT is the default toolchain; CRXJS, plain Vite, or `web-ext` alone remain valid choices.

### firefox-extension

- **Structure:** New stack for Firefox-only extensions on the Release (156+) or ESR (153+) channel.

### chrome-extension

- **Structure:** New stack for Chrome-only extensions on the Stable (154+) or Extended Stable (152+) channel.

## 2026.09.11

### electron

- **Structure:** `electron` inherits the new `typescript` base, which adds `Context/conventions/typescript-style.md` (compiler settings, types at boundaries, modules, errors and async, tooling); `electron-style.md` defers general TypeScript rules to it.
  - Impact: none in code. A refresh adds the document and its row in the conventions README.

<!-- markdownlint-configure-file { "MD024": { "siblings_only": true } } -->
