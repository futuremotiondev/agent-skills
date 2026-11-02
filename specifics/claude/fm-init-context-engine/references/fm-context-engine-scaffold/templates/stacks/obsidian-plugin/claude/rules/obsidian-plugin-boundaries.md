---
paths:
  - "src/**"
  - "main.ts"
  - "styles.css"
---

# Obsidian Plugin Rules

Auto-loaded when editing plugin source or styles. Seeded by the context-engine `obsidian-plugin` adapter — if the project's layout differs, fix the `paths:` globs above.

These are platform facts and guardrails only. Defaults (tooling, layout, code shape) live in `Context/conventions/` and can be overridden there.

## Lifecycle

- `onload()` registers; startup work goes in `workspace.onLayoutReady()`. Register `vault.on('create')` there too, or it fires for every file at load.
- Attach every listener, timer, and observer through `registerEvent()`, `registerDomEvent()`, `registerInterval()`, `register()`, or `addChild()`, so unloading the plugin removes it.
- Never detach leaves in `onunload()`, and never store a view on the plugin. Find views with `getLeavesOfType()` and check `leaf.view instanceof MyView`; restored leaves are deferred until shown.
- Pass `MarkdownRenderer.render()` a component that owns the output (a view or render child), never the plugin.

## APIs and the floor

- Every API used exists at the project's `minAppVersion`. Above it, guard with `requireApiVersion()`; the version-gated table in `obsidian-plugin-style.md` lists what is newer than the public floor.
- At a 1.13+ floor, settings tabs implement `getSettingDefinitions()`, not the deprecated `display()`.

## Files and data

- Use the Vault API, not `vault.adapter`, and narrow with `instanceof TFile` / `TFolder`, never a cast.
- Edit the active note through the `Editor`, background files through `Vault.process()`, and frontmatter through `FileManager.processFrontMatter()`.
- Delete with `FileManager.trashFile()` and rename with `FileManager.renameFile()`.
- Find files with `getFileByPath()` / `getAbstractFileByPath()`, never by iterating `getFiles()`.
- Pass user-supplied and constructed paths through `normalizePath()`, and use `vault.configDir`, never a literal `.obsidian`.
- Secrets go in `app.secretStorage`, never in `data.json`. Merge loaded settings over a copy of the defaults, never into the defaults object.

## DOM, UI, and windows

- Build DOM with `createEl()` / `createDiv()` / `createSpan()` and `setText()`. No `innerHTML`, `outerHTML`, `insertAdjacentHTML`, `<style>`, or `<link>`, and no `el.style.*` assignments.
- All UI text is sentence case. Settings headings use groups or `setHeading()`, never HTML headings.
- Use `el.doc`, `el.win`, `activeDocument`, and `activeWindow`, not the bare `document` / `window`. Timers are `activeWindow.setTimeout()` / `setInterval()`. Cross-window checks use `el.instanceOf()`.

## Platform and security

- Node and Electron APIs need `"isDesktopOnly": true` or a `Platform.isDesktopApp` guard with a dynamic `require`. Detect platforms with `Platform`, never `navigator` or `process.platform`.
- No regex lookbehind unless the plugin is desktop only (iOS below 16.4 lacks it).
- HTTP goes through `requestUrl()`. No `eval`, `new Function`, or string timers, and no code downloaded and run.
- Use `this.app`, not the global `app`. Import `moment` from `obsidian`.
- Treat `obsidian://` action parameters, CLI handler input, and file contents as untrusted.

## Commands and surface

- Command ids and names never repeat the plugin id or name and never contain the word "command". No default `hotkeys`.
- Command ids, view types, CLI handler ids, and settings keys are public surface: users' hotkeys, workspaces, scripts, and saved data depend on them. Renaming one is a breaking change; say so in the commit and run `/refresh-context`.
