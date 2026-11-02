---
paths:
  - "src/background/**"
  - "src/content/**"
  - "src/popup/**"
  - "src/options/**"
  - "src/sidepanel/**"
  - "src/offscreen/**"
  - "src/shared/**"
  - "entrypoints/**"
  - "src/entrypoints/**"
---

# Chrome Extension Rules

Auto-loaded together with `extension-boundaries.md`. Seeded by the context-engine `chrome-extension` adapter for Chrome Stable (154+ as seeded) or Extended Stable (152+). Platform facts and guardrails only; fix the `paths:` globs if the layout differs.

## Service worker

- No DOM, `window`, `localStorage`, or `XMLHttpRequest` (`fetch` only). DOM work goes to the offscreen document through a message.
- No dynamic `import()`; static `import` and `importScripts()` only.
- Terminated after 30 seconds idle, after a single event runs longer than 5 minutes, or when a `fetch` response takes longer than 30 seconds. Design for termination; never add keep-alive hacks.
- Alarms fire at most every 30 seconds in a packed extension. Unpacked extensions are exempt, so a short period seen in development is not proof.

## Offscreen document

- One at a time. Create it through the shared guard function, never directly.
- Only `runtime` exists inside it. It talks to the worker through the message registry.
- Its `reasons` must be true; a new reason changes what the store reviews.

## Messaging

- Do not rely on a Promise returned from `onMessage`. Chrome documents it as rolling out gradually from 148; reply through `sendResponse` + `return true`.
- Messages are JSON-serialized: `undefined`, `Map`, `Set`, `Date`, and class instances do not survive the trip.

## Side panel

- `sidePanel.open()` works only from a user gesture.
- An open side panel, popup, or options page delays extension updates; do not keep one open programmatically.

## Versions

- Anything above the project's floor (`Context/scripts/extension-targets.psd1`) must be feature-detected; see the version-gated features table in `chrome-extension-style.md`.
