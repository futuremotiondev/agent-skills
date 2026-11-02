---
paths:
  - "src/background/**"
  - "src/content/**"
  - "src/popup/**"
  - "src/options/**"
  - "src/sidebar/**"
  - "src/shared/**"
  - "entrypoints/**"
  - "src/entrypoints/**"
---

# Firefox Extension Rules

Auto-loaded together with `extension-boundaries.md`. Seeded by the context-engine `firefox-extension` adapter for Firefox Release (156+ as seeded) or ESR (153+). Platform facts and guardrails only; fix the `paths:` globs if the layout differs.

## Background (event page)

- Firefox runs the MV3 background as an event page from `background.scripts`. It unloads after about 30 seconds idle; its DOM is available but is not a place for state.
- Firefox has no offscreen documents. DOM work (`DOMParser`, canvas, `Blob` URLs) runs in the event page itself.
- An open DevTools toolbox keeps the event page alive. Check unload behavior with the toolbox closed.

## Content scripts

- Page objects arrive through Xray vision. Anything read through `wrappedJSObject` is hostile input.
- Hand data to page JavaScript with `cloneInto(value, window)` or `window.structuredClone(value)`, and functions with `exportFunction`. Never expose privileged objects or functions.
- A content script's `fetch` uses the page's origin; cross-origin requests go through the background.
- `storage.session` does not exist for content scripts in Firefox.
- Nothing can inject into `moz-extension:` pages (152+). Those pages handle their own messages.

## Versions

- Anything above the project's floor (`Context/scripts/extension-targets.psd1`) must be feature-detected; see the version-gated features table in `firefox-extension-style.md`. Example: `runtime.getVersion()` arrives in 158; use `runtime.getManifest().version`.
