---
paths:
  - "**/manifest.json"
  - "**/wxt.config.*"
---

# Firefox Manifest Rules

Auto-loaded together with `extension-manifest.md`. Seeded by the context-engine `firefox-extension` adapter. Platform facts and guardrails only.

- `browser_specific_settings.gecko.id` is present, and never changes after the first release.
- `strict_min_version` matches the floor in `Context/scripts/extension-targets.psd1` (`"156.0"` on the Release channel as seeded, `"153.0"` on ESR).
- `data_collection_permissions` is present. `required: ["none"]` must stand alone, and `technicalAndInteraction` may only be optional. A new required type re-prompts every user; say so in the commit.
- The background declares `scripts`. A `service_worker`-only background does not run in Firefox.
- `userScripts` goes only in `optional_permissions`.
- Chrome-only keys and permissions (`side_panel`, `sidePanel`, `offscreen`, `declarativeContent`, `debugger`, `externally_connectable`, `key`, `minimum_chrome_version`) stay out unless the project adds a Chrome target.
- `gecko_android` appears only if Firefox for Android is a recorded target.
- Run `web-ext lint` on the built output after any manifest change; it checks features against `strict_min_version`.
