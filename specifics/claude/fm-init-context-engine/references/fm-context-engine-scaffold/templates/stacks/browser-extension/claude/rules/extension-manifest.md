---
paths:
  - "**/manifest.json"
  - "**/manifest.*.json"
  - "**/wxt.config.*"
---

# Extension Manifest Rules

Auto-loaded when editing a WebExtension manifest or the config that generates one. Seeded by the context-engine `browser-extension` adapter; a single-browser stack adds its own manifest rule on top.

These are platform facts and guardrails only. Defaults (tooling, layout, code shape) live in `Context/conventions/` and can be overridden there.

- Every permission, host permission, content-script match, and `web_accessible_resources` entry is public surface: it changes the install prompt and the store review. Say so in the commit message, and run `/refresh-context` so `Context/generated/manifest-index.md` stays accurate.
- Host patterns go in `host_permissions` or `optional_host_permissions`, never in `permissions`.
- Anything not needed at install goes in `optional_permissions` / `optional_host_permissions` and is requested at runtime from a user action.
- Never add a remote script source or relax the extension-page CSP beyond `'wasm-unsafe-eval'` without an ADR.
- `web_accessible_resources` uses the narrowest `matches`; never `<all_urls>` for convenience.
- `version` is one to four dot-separated integers.
- Check every key and permission against the floors in `Context/scripts/extension-targets.psd1`. A key the target does not support is ignored with a warning at best and blocks signing or loading at worst.
