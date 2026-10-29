---
paths:
  - "**/manifest.json"
  - "**/wxt.config.*"
---

# Chrome Manifest Rules

Auto-loaded together with `extension-manifest.md`. Seeded by the context-engine `chrome-extension` adapter. Platform facts and guardrails only.

- `minimum_chrome_version` matches the floor in `Context/scripts/extension-targets.psd1` (`"154"` on the Stable channel as seeded, `"152"` on Extended Stable). Users below it cannot install, and existing users on older Chrome silently stop receiving updates.
- The background declares `service_worker`. `background.scripts` is MV2-only in Chrome.
- Firefox-only keys and permissions (`sidebar_action`, `page_action`, `browser_specific_settings`, `menus`, `webRequestFilterResponse`, `contextualIdentities`) stay out unless the project adds a Firefox target.
- No `webRequestBlocking`: in MV3 it is available only to policy-installed extensions.
- `externally_connectable` lists exactly who may connect. Once declared, anything it does not list is cut off.
- Every new permission needs a matching justification in the Chrome Web Store Privacy practices tab. Say so in the commit.
