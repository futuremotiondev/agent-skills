---
last_verified: {{TODAY}}
---

# Figma Plugin Style

Seeded by the context-engine `figma-plugin` adapter. General TypeScript rules live in [TypeScript style](typescript-style.md); this document covers the Plugin API, the two-context execution model, and the manifest.

Statements here are platform facts, guardrails, or **Default:** choices; the conventions README explains the difference and how to deviate.

## Toolchain

<!-- Filled at init by /fm-init-context-engine from the interview. Expected shape: a table with one row per layer —
     Editor types (figma / figjam / dev / slides / buzz — note dev+figjam is unsupported),
     Plugin API version (the manifest "api" field), documentAccess (must be dynamic-page),
     Typings (@figma/plugin-typings, plus @figma/widget-typings for widgets),
     Build tooling (esbuild / webpack / Create Figma Plugin / vite), Package manager.
     One line each. -->
{{TOOLCHAIN}}

## The two-context model

This is the architecture of every Figma plugin, and nearly every confusing bug traces back to it.

- The **main thread** runs `main` (typically `code.ts`) in a **sandbox**. It owns the `figma` global and the document scene graph. It has modern JavaScript (ES2020+, `Promise`, `Map`, `Proxy`, typed arrays, `structuredClone`) and a minimal `console`, but **no browser APIs**: no DOM, no `fetch`, no `XMLHttpRequest`, no `setTimeout`.
- The **UI** runs `ui` (an HTML file) in an `<iframe>` opened by `figma.showUI()`. It has the full browser environment including network access, but **no `figma` global** and no access to the scene.
- The two communicate **only by message passing**. Everything else is a boundary violation.

Practical consequences:

- All network requests happen in the UI. The main thread asks the UI to fetch, and the UI posts the result back.
- Need a delay on the main thread? There is no `setTimeout`. Either restructure around promises or have the UI drive the timing.
- Need the DOM, `canvas`, or WebAssembly? That belongs in the UI iframe.
- A plugin with no UI can still open a hidden iframe (`figma.showUI(__html__, { visible: false })`) purely to borrow browser APIs.

## Messaging

- **Default:** one **message registry module**, imported by both sides, owns every message type and its payload shape. A stringly-typed message used in two places is a bug factory. This is the same discipline the Electron and browser-extension adapters apply to their own boundaries.
- **Default:** model messages as a discriminated union on a `type` field and handle them exhaustively.
- Payloads cross by structured clone: plain JSON-compatible data only. **A node object cannot be sent.** Send its `id` and re-resolve with `figma.getNodeByIdAsync()` on the main thread.
- Main to UI is `figma.ui.postMessage(msg)`; UI to main is `parent.postMessage({ pluginMessage: msg }, '*')`. The `pluginMessage` wrapper is required and is a common first-time mistake.
- Treat UI messages as untrusted input on the main thread. The iframe can load remote content.

## Dynamic page loading and async APIs

Figma loads pages on demand. `"documentAccess": "dynamic-page"` is **required in the manifest for all new plugins**, and with it a set of synchronous APIs is deprecated and **throws**. Their async replacements load the data if needed.

- Node and style lookup: `getNodeByIdAsync()`, `getStyleByIdAsync()`, `getFileThumbnailNodeAsync()`.
- Local style enumeration: `getLocalTextStylesAsync()`, `getLocalPaintStylesAsync()`, `getLocalEffectStylesAsync()`, `getLocalGridStylesAsync()`.
- Variables: `figma.variables.getVariableByIdAsync()`, `getVariableCollectionByIdAsync()`, `getLocalVariablesAsync()`, `getLocalVariableCollectionsAsync()`, `createVariableAliasByIdAsync()`.
- Relationships: `ComponentNode.getInstancesAsync()`, `InstanceNode.getMainComponentAsync()`, `BaseStyle.getStyleConsumersAsync()`.
- Style assignment by id: `setFillStyleIdAsync()`, `setEffectStyleIdAsync()`, `setRangeTextStyleIdAsync()`, `setRangeFillStyleIdAsync()` and friends, rather than assigning to `fillStyleId` and its siblings.
- Page navigation: `figma.setCurrentPageAsync()`; page contents need `PageNode.loadAsync()`, or `figma.loadAllPagesAsync()` when the plugin genuinely spans the whole file.

**Default:** install `eslint-plugin-figma-plugins`. It finds these call sites and auto-fixes most of them, which is far more reliable than grepping.

## Working with the scene graph

- **Load fonts before touching text.** `await figma.loadFontAsync(node.fontName as FontName)` before setting `characters` or any range style, or the call throws. This is the single most common plugin bug. Mixed-font text reports `figma.mixed`, so load every font in the range.
- Node references go stale. A node the user deleted has `node.removed === true`; check it before use on any reference held across an `await`.
- **Default:** prefer `findAllWithCriteria` over a manual recursive walk: it is implemented natively and is dramatically faster on large documents.
- The API can only see what is in the file. Library components and styles must be imported first, for example with `importComponentByKeyAsync()`. File metadata, comments, and version history are REST API territory, not Plugin API.
- **Default:** batch scene mutations. Each write is cheap individually but a tight loop over thousands of nodes is not.

## Editor types

`editorType` is required and is an array of `figma`, `figjam`, `dev`, `slides`, or `buzz`.

- `dev` and `figjam` **cannot be combined**; Figma rejects that manifest.
- Multi-editor plugins must branch at runtime on `figma.editorType`. An API valid in one editor throws in another: `figma.createSticky()` works in FigJam and fails in Figma design.
- Dev Mode is read-only for the document. A plugin that writes to the scene will fail there.
- The `codegen` and `inspect` capabilities only do anything when `dev` is among the editor types.

## Manifest rules

- `documentAccess` must be `"dynamic-page"`. Omitting it makes Figma preload the entire file on first run, which is a 20 to 30 second stall in a large document.
- `networkAccess` is required. Use `{"allowedDomains": ["none"]}` when the plugin makes no requests; that is a selling point on the Community page, where the domain list is shown to users.
- `reasoning` is required when `allowedDomains` contains `"*"` or a local development server. Put development servers in `devAllowedDomains` instead so the published plugin does not request them.
- Domain patterns support `*` for subdomains and optional `http`/`https`/`ws`/`wss` schemes. A trailing slash means "this path and below"; no trailing slash pins the exact resource.
- `enableProposedApi` **does not work in published plugins**. It is a local development flag only, and shipping it set is a release bug.
- Menu `command` strings reach the code as `figma.command`. Keep them stable: renaming one silently breaks any relaunch button referencing it.
- Bump `api` deliberately. Figma does not auto-upgrade it, so an old value quietly locks the plugin out of newer features.

## Lifecycle

- Call `figma.closePlugin()` when the work is done. A plugin that never closes shows a "Running…" toast until the user kills the tab.
- Close on every path, including error paths. Wrap the body and close in a `finally`.
- A plugin with parameters and `parameterOnly` runs headless from the quick-actions bar; it must still close itself.
- Use `figma.notify()` for user-facing messages; `console.log` goes to the developer console only.

## Storage

- `figma.clientStorage` is per-user, per-device, asynchronous, and invisible to other users. Good for preferences, not for anything that must travel with the file.
- Plugin data on nodes (`setPluginData` / `setSharedPluginData`) travels with the document. `setSharedPluginData` is readable by other plugins; plain `setPluginData` is namespaced to this plugin.
- Neither is a secret store. Never put a token in either one.

## Publishing

- The manifest `id` is assigned by Figma. Do not hand-edit it.
- The `allowedDomains` list and the requested `permissions` are shown on the Community listing, so keep both minimal.
- Review rejects remote code execution. Everything must be bundled into the files the manifest names.

## Layout and boundaries

**Default** split: `src/main/` or `code.ts` (sandbox, owns `figma`), `src/ui/` (the iframe), `src/shared/` (types and the message registry only). The path-scoped rule at `.claude/rules/figma-plugin-boundaries.md` auto-loads when editing any of them; if this project uses different directory names, update BOTH that rule's `paths:` globs and this section.

`Context/generated/figma-manifest-index.md` is a machine-generated inventory of the manifest, including a validation report. Regenerate it with `/refresh-context` after any manifest change.
