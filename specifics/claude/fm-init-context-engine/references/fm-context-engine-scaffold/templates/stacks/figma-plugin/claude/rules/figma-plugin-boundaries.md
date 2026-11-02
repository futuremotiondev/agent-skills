---
paths:
  - "src/**"
  - "code.ts"
  - "ui.ts"
  - "ui.tsx"
---

# Figma Plugin Boundary Rules

Auto-loaded when editing plugin source. Seeded by the context-engine `figma-plugin` adapter — if the project's layout differs, fix the `paths:` globs above.

These are platform facts and guardrails only. Defaults (tooling, layout, code shape) live in `Context/conventions/` and can be overridden there.

## In main-thread code (the `figma` sandbox)

- **No browser APIs.** No `fetch`, no `XMLHttpRequest`, no `setTimeout`, no DOM, no `window`. They do not exist here. Network and timing work goes to the UI iframe, driven by a message.
- **Use the async Plugin API.** With `documentAccess: dynamic-page` the synchronous variants throw. Reach for `getNodeByIdAsync`, `getStyleByIdAsync`, `getLocalVariablesAsync`, `getMainComponentAsync`, `setCurrentPageAsync`, and the `set*StyleIdAsync` setters rather than their sync or property-assignment forms.
- **`await figma.loadFontAsync(...)` before writing text.** Setting `characters` or a range style without it throws. Mixed-font ranges report `figma.mixed`, so load every font present.
- Re-check `node.removed` on any node reference held across an `await`; the user can delete it while the plugin runs.
- Treat messages from the UI as untrusted input and validate before acting on the scene.
- Call `figma.closePlugin()` on every exit path, success and failure alike, or the plugin hangs with a "Running…" toast.

## In UI code (the iframe)

- **No `figma` global.** The scene is unreachable from here. Anything touching the document is a typed message to the main thread.
- Send with `parent.postMessage({ pluginMessage: msg }, '*')`. The `pluginMessage` wrapper is required.
- This is where network requests belong, and every domain used must appear in the manifest's `networkAccess.allowedDomains` or the request is blocked by CSP.
- Never send a node object; send its id and re-resolve on the main thread.

## In `src/shared/`

- No runtime code that depends on either context's APIs; it breaks in the other.
- If the project uses the shared message registry (the default), declare every new message type there with its payload shape, and handle it exhaustively on the receiving side.

## Manifest changes

- `editorType`, `permissions`, `capabilities`, `networkAccess`, menu commands, parameters, and relaunch buttons are public surface: they change what users see and what review examines. Say so in the commit and run `/refresh-context`.
- `documentAccess` stays `"dynamic-page"`. Never remove it to make a sync API work; migrate the call instead.
- `enableProposedApi` must not be committed as `true`; it is inert in published plugins.
