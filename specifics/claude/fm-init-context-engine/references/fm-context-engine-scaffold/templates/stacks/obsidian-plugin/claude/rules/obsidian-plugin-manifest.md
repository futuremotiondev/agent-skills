---
paths:
  - "manifest.json"
  - "manifest-beta.json"
  - "versions.json"
---

# Obsidian Manifest Rules

Auto-loaded when editing the plugin manifest or `versions.json`. Seeded by the context-engine `obsidian-plugin` adapter. Platform facts and guardrails only.

- `id` is lowercase letters and hyphens, contains no "obsidian", does not end with "plugin", matches the plugin's folder name, and never changes after publishing.
- `name` is Basic Latin without emoji, contains no "Obsidian" and no word "Plugin", and is not the name of a core feature.
- `description` is at most 250 characters, ends with a period, has no emoji, and does not start with "This is a plugin".
- `version` is `x.y.z`, and the GitHub release tag equals it exactly (no `v`).
- `minAppVersion` is the project's floor and matches the Toolchain table in `Context/conventions/obsidian-plugin-style.md`. Changing it needs a `versions.json` entry, or older apps cannot find a compatible release.
- `isDesktopOnly` is present, and `true` whenever the plugin uses Node or Electron APIs without a `Platform` guard.
- Only documented keys: `id`, `name`, `version`, `minAppVersion`, `description`, `author`, `authorUrl`, `fundingUrl`, `isDesktopOnly`. There is no permissions key.
- The `manifest.json` on the default branch is what the Community directory lists. A change to `name`, `description`, `minAppVersion`, or `isDesktopOnly` is public surface: say so in the commit and run `/refresh-context`.
