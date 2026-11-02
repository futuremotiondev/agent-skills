---
paths:
  - "src/background/**"
  - "src/content/**"
  - "src/popup/**"
  - "src/options/**"
  - "src/shared/**"
  - "entrypoints/**"
  - "src/entrypoints/**"
---

# Browser Extension Boundary Rules

Auto-loaded when editing background, content-script, extension-page, or shared code. Seeded by the context-engine `browser-extension` adapter; a single-browser stack layers its own rule file on top of this one. If the project's directory names differ, fix the `paths:` globs above.

These are platform facts and guardrails only. Defaults (tooling, layout, code shape) live in `Context/conventions/` and can be overridden there.

## In the background

- The background unloads when idle in every MV3 browser. Keep no state in module-level variables; write it to `storage.session` or `storage.local`.
- Register every listener synchronously at the top level. A listener added after an `await` misses the event that woke the background.
- Use `alarms`, not `setTimeout` or `setInterval`, for anything that must fire after the background may have unloaded.
- Validate every message payload before acting on it. Content-script messages originate next to untrusted page content.
- Never pass an `async` function directly to `runtime.onMessage.addListener`; it answers every message, including ones meant for other listeners.

## In content scripts

- Isolated world: page JavaScript is invisible here and vice versa. Never assume a page global exists.
- The page is hostile input. No `eval` of page strings, no `innerHTML` with page- or network-derived strings, no trusting DOM attributes as structured data.
- Privileged work and cross-origin requests go through a message to the background.

## In extension pages

- A popup is destroyed when it closes. Persist input before it can be dismissed.
- Read state from storage on open instead of assuming the background pushed it.

## In shared code

- Keep code that depends on one context's APIs out of modules every context imports; it breaks in the others.
- If the project uses the shared message registry (the default), declare every new message type there with its payload and result, and handle it exhaustively on the receiving side.
