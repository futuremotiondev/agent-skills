---
last_verified: {{TODAY}}
---

# Firefox Extension Style

Seeded by the context-engine `firefox-extension` adapter for Firefox-only extensions, on the latest Release channel (Firefox 156+ as seeded) or the enterprise ESR channel (153+). What holds in every browser lives in [Browser extension style](browser-extension-style.md); this document adds what is specific to Firefox and to addons.mozilla.org (AMO), and it wins where the two disagree. Statements are platform facts, guardrails, or **Default:** choices (see the conventions README).

## Release channel and floor

The project's channel and floor are recorded in the Toolchain table and in `Context/scripts/extension-targets.psd1`, and `strict_min_version` in the manifest matches them. The rest of this document applies to either channel: where a fact depends on the version it says so, and the version-gated features table lists everything newer than the enterprise floor.

### Latest channel: Firefox Release

- The floor is a recent release: 156.0 as seeded. Release ships every two weeks. Raise the floor when you want a newer API, not for its own sake.
- Everything at or below the floor is used directly, without feature detection.
- ESR users cannot install or update the extension, and that includes most managed enterprise installs.

### Enterprise channel: Firefox ESR

- The floor is the oldest ESR the audience runs: 153.0 as seeded. ESR 140 reaches end of life on 2026-10-13, when its users move to 153.
- ESR receives security fixes, not features. Anything that lands in Release after the floor does not reach ESR users until the next ESR, about a year later. Feature-detect every row of the version-gated table above the floor, or do without it.
- The `sandbox` key arrives in 154, so an ESR 153 extension has no sandboxed page for a library that needs `eval`. Choose libraries that do not need it.
- Test on the ESR build itself with `web-ext run --firefox=<path to Firefox ESR>`. `web-ext lint` checks APIs against `strict_min_version`.
- Plan the floor raise for when the older ESR reaches end of life, not when the new ESR appears.

### Changing channel or raising the floor

1. Read the "Changes for add-on developers" section of every Firefox release between the old and new floor.
2. Update `extension-targets.psd1`, `strict_min_version`, and the Toolchain table in one commit.
3. Remove feature detection for everything now at or below the floor, and add it for anything a lower floor loses. Moving to ESR lowers the floor.
4. Record a channel change in an ADR: it changes who can install the extension.

## Version-gated features

Features and behavior changes newer than the enterprise floor (ESR 153). Use a row unconditionally only when the project's floor is at or above its version; below that, feature-detect or do without.

| Version | Feature or change                                                  | Note                                                                                     |
| ------- | ------------------------------------------------------------------ | ---------------------------------------------------------------------------------------- |
| 154     | `sandbox` manifest key: sandboxed pages for code that needs `eval` | No equivalent on ESR 153                                                                 |
| 156     | Theme `backgrounds_area` (`window`, `top_toolbars`, `auto`)        | Themes only                                                                              |
| 158     | `runtime.getVersion()`                                             | In beta on 2026-09-28 and above every current floor; use `runtime.getManifest().version` |

## Identity, signing, and consent

- `browser_specific_settings.gecko.id` is required to sign an MV3 extension, and AMO does not assign one. Use an email-like id (`@my-extension`, `name@example.com`) or a `{GUID}`. Never change it after the first release: it is the extension's identity for updates and stored data.
- `browser_specific_settings.gecko.data_collection_permissions` is required for every extension first submitted after 2025-11-03, and once one version uses it, every later version must. Declare `{ "required": ["none"] }` when no data leaves the browser; `none` must then be the only required entry. `technicalAndInteraction` may only be optional.
- Required data types appear in the install prompt, and the user must accept them to install. Optional types stay off until the extension calls `permissions.request({ data_collection: [...] })` from a user action. A new required type in an update re-prompts every user, so treat a data-collection change like a permission change.
- Firefox ignores Chrome's `key`. The `moz-extension://` origin is a random UUID per install, so never hard-code an extension URL; build it with `runtime.getURL()`.
- `incognito: "split"` is not supported; Firefox treats it as `not_allowed`.
- Firefox release and beta accept only signed add-ons, whether listed or unlisted. Unsigned loading is for development (`about:debugging`, `web-ext run`).

**Default** manifest for the Release channel (on ESR, `strict_min_version` is `"153.0"`):

```json
{
  "manifest_version": 3,
  "name": "My Extension",
  "version": "1.0.0",
  "browser_specific_settings": {
    "gecko": {
      "id": "@my-extension",
      "strict_min_version": "156.0",
      "data_collection_permissions": { "required": ["none"] }
    }
  },
  "background": { "scripts": ["background.js"], "type": "module" },
  "action": { "default_popup": "popup.html" },
  "permissions": ["storage"],
  "optional_host_permissions": ["https://*/*"]
}
```

## The background is an event page

- Firefox runs the MV3 background from `background.scripts` (or `background.page`) as an **event page**. It does not support `background.service_worker`; with both keys present, Firefox uses `scripts`.
- `persistent: true` is an error in MV3. The page unloads after about 30 seconds idle. Open message ports do not keep it alive, and DOM timers stop when it unloads, so everything in the browser document's background section applies.
- The event page has a DOM and `window`. `DOMParser`, `Blob` URLs, and canvas work there directly. Firefox does not implement the `offscreen` API and does not need it.
- `"type": "module"` works for background scripts.
- An open DevTools toolbox on the background keeps it alive. Test unload behavior with the toolbox closed.
- A background that crashes restarts only when one of its listeners fires.

## Messaging in Firefox

- `runtime.onMessage` listeners may return a Promise, which MDN calls the preferred form, and the shared dispatcher's `sendResponse` + `return true` form also works. **Default:** keep the dispatcher's form so the in-memory test fake keeps working and a later Chrome target needs no change. Switching to a returned Promise is a one-line edit inside the dispatcher.
- Firefox copies messages with structured clone, so a `Map` or `Date` survives here but would not in Chrome. **Default:** keep payloads plain JSON anyway, so the registry stays portable and simple to validate.

## Content scripts and the page

- Isolated-world content scripts see page objects through **Xray vision**: native DOM properties only, never page-defined properties or overridden methods. `obj.wrappedJSObject` reaches the page's own version; treat anything read that way as hostile input.
- To hand data to page JavaScript, copy it into the page's scope with `cloneInto(value, window)` or `window.structuredClone(value)`. Since 149, a bare `structuredClone` copies into the content script's own scope instead. To expose a callable function, use `exportFunction`.
- **Default:** for code that must live in the page, prefer `scripting.executeScript({ world: "MAIN" })` and pass it only plain data.
- A content script's global object is not `window`; `window` is its prototype. Use `addEventListener` rather than `element.onclick =`, whose handlers are shared across worlds.
- In MV3, content scripts share the extension's CSP, so `eval` is blocked there too. Most loads a content script triggers in the DOM follow the page's CSP.
- A content script's `fetch` runs with the page's origin and CORS rules; host permissions do not apply, and `content.fetch` is gone in MV3. Route cross-origin requests through the background.
- Content scripts cannot use `storage.session` in Firefox at all (`setAccessLevel` is not implemented).
- Since 152, no API can inject into `moz-extension:` documents, including the extension's own pages. Give those pages their own `runtime.onMessage` handlers.
- Since 153, content scripts can read and set `document.adoptedStyleSheets` directly.

## Permissions in Firefox

- MV3 host permissions are shown at install and granted by default (since 127), but users can revoke them per site at any time. Check with `permissions.contains` at startup and after `permissions.onRemoved`.
- Host permissions added by an update are not prompted for. After such an update, check for the permission and request it rather than assuming it.
- `permissions.request` works only inside a user-action handler: a toolbar button or page-action click, the extension's own menu item or keyboard shortcut, a button on an extension page, or an omnibox suggestion. Awaiting anything first loses the gesture.
- Since 153, `file://` access is its own "Access local files" opt-in, off by default even for installed extensions, and `<all_urls>` no longer covers it. Detect it with `extension.isAllowedFileSchemeAccess()`.
- Collecting personal data must be opt-in, and declining technical and interaction data must not cost the user any feature. That is AMO policy.

## Firefox APIs and UI

- The sidebar is the `sidebar_action` key plus the `sidebarAction` API, on desktop only. `open()`, `close()`, and `toggle()` need a user action.
- `page_action` still exists alongside `action`.
- Context menus use the `menus` namespace, with `contextMenus` as an alias.
- `action.openPopup()` needs no user gesture since 149, but it rejects if a `windowId` is given and that window is not focused.
- `documentId` (153) identifies one document instance. **Default:** where an API accepts it, target a document by `documentId` rather than `tabId` + `frameId`, so a stale operation fails instead of hitting whatever document replaced the one you meant.
- Firefox-only APIs available on both channels:
  - `contextualIdentities` (containers)
  - `theme`
  - `proxy` (a different design from Chrome's)
  - `dns`, `find`, `browserSettings`, `pkcs11`, `captivePortal`
  - `publicSuffix` (153)
  - `runtime.getDocumentId()` (153)
  - `runtime.getBrowserInfo()`
- Not in Firefox:
  - `offscreen`, `sidePanel`, `declarativeContent`, `debugger`
  - The `dom` namespace (use `element.openOrClosedShadowRoot`)
  - `externally_connectable`
  - `storage.session.setAccessLevel`
  - `web_accessible_resources.use_dynamic_url`

## Network

- `declarativeNetRequest` is supported, with limits lower than Chrome's: 5,000 dynamic rules and 5,000 session rules. `getMatchedRules` and `onRuleMatchedDebug` are not implemented, though `testMatchOutcome` is. Redirects and header changes need host permissions for both the request URL and its initiator.
- Blocking `webRequest` still works in MV3 (`webRequestBlocking`), and Mozilla has no plan to deprecate it. `webRequest.filterResponseData` also needs `webRequestFilterResponse`.
- **Default:** use DNR first. Use blocking `webRequest` when DNR cannot express the behavior, and record the reason in an ADR, because it widens review.

## User scripts

- The MV3 `userScripts` API exists (desktop 136, Android 138; `execute()` since 153). Its permission is **optional-only**: declare it in `optional_permissions` and request it alone, from a user action.
- AMO allows `userScripts` only in user-script managers.
- Registered user scripts are cleared on update, so re-register them in `onInstalled`.

## Firefox for Android

- Decide explicitly whether Android is a target, and record it in the Toolchain table.
- AMO lists an extension for Android only if the manifest has `browser_specific_settings.gecko_android`; an empty object is enough.
- Missing on Android:
  - `menus`, `commands`, `sidebarAction`, `tabGroups`, `theme`, `find`
  - `bookmarks`, `history`, `sessions`, `windows`, `downloads`
  - `contextualIdentities`
  - The user-script messaging events
- `storage.sync` does not sync on Android.
- Mozilla's Android guide still recommends MV2 there, because Android has no host-permission request indicator and users cannot edit host grants. An Android-first extension that needs host permissions decides MV2 or MV3 in an ADR.

## Manifest V2 is still an option

Firefox supports MV2 with no deprecation plan. **Default:** MV3, which everything in these documents assumes. MV2 remains a legitimate choice, recorded in an ADR, for a Firefox-only extension that MV3 makes awkward (Android host-permission UX, for example).

## AMO submission

- Bundled, minified, transpiled, or generated code requires a source submission with every version. Submit the source, the lockfile, and a README with exact build steps, operating system, and tool versions. Build tools must be open source and run locally. Check the reviewers' current build environment on Extension Workshop's source-code submission page.
- AMO now tries to rebuild the package from the submitted source. **Default:** add an npm script named `build-for-amo` that produces the Firefox build, and list every dev dependency in `package.json`.
- AMO policy bans all of the following:
  - Obfuscated code.
  - Modified or non-release versions of third-party libraries.
  - Remote code.
  - Unencrypted data in transit.
  - Surprising features that are on by default rather than opt-in.
- Every submission gets automated validation; human review can come later, even after publication. AMO can roll back to a previous version.
- **Default:** run `web-ext lint --warnings-as-errors` on the built output before every submission. It is the linter AMO runs.
- **Default:** submit with `web-ext sign --channel listed` (or `unlisted` for self-distribution):
  - Credentials go in `WEB_EXT_API_KEY` / `WEB_EXT_API_SECRET`.
  - The source archive goes in `--upload-source-code`.
  - A first listed version needs `--amo-metadata`.
  - `wxt submit` wraps the same flow.

## Tooling defaults

- **Default:** WXT with `manifestVersion: 3` and `targetBrowsers: ['firefox']`.
  - WXT builds **MV2** for Firefox unless told otherwise.
  - It sets neither `strict_min_version` nor `data_collection_permissions`, so put both in the `manifest` config.
  - `wxt zip -b firefox` also produces the sources zip AMO needs.
- **Default:** `web-ext run` for the development loop; it reloads on change. `about:debugging` → "Load Temporary Add-on" works too, but it skips install-time permission prompts, so test permission UX in a signed build.
- Typings:
  - With WXT, use its `Browser` types, extended by declaration merging for Firefox-only APIs.
  - Without WXT, use `@types/firefox-webext-browser`. Never install it alongside `@types/chrome`, because both declare a global `browser`.
  - The Firefox typings trail the browser (they are generated from an older Firefox), so APIs newer than the typings need a local declaration.
- End-to-end tests: Playwright does not load Firefox extensions. **Default:** Selenium with geckodriver's temporary add-on install, or any WebDriver BiDi client (`webExtension.install`, temporary by default since Firefox 138).

## Layout and boundaries

The browser document's layout section applies. The sidebar page lives in `src/sidebar/` (or `entrypoints/sidebar/`). `.claude/rules/firefox-extension-boundaries.md` and `.claude/rules/firefox-extension-manifest.md` add Firefox rules on top of the shared ones; keep their `paths:` globs in step with the layout.
