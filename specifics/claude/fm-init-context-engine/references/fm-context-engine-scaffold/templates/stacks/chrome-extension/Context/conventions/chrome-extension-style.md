---
last_verified: {{TODAY}}
---

# Chrome Extension Style

Seeded by the context-engine `chrome-extension` adapter for Chrome-only extensions, on the latest Stable channel (Chrome 154+ as seeded) or the enterprise Extended Stable channel (152+). What holds in every browser lives in [Browser extension style](browser-extension-style.md); this document adds what is specific to Chrome and the Chrome Web Store (CWS), and it wins where the two disagree. Statements are platform facts, guardrails, or **Default:** choices (see the conventions README). Chromium derivatives (Edge, Brave, Opera) usually run the same code on their own schedules and stores; if the project ships to them, record that in the Toolchain table and check their gaps.

## Release channel and floor

The project's channel and floor are recorded in the Toolchain table and in `Context/scripts/extension-targets.psd1`, and `minimum_chrome_version` in the manifest matches them. Users below the floor cannot install the extension, and **existing users on an older Chrome silently stop receiving updates**, so the floor decides who keeps getting fixes. The rest of this document applies to either channel.

### Latest channel: Chrome Stable

- The floor is a recent Stable milestone: 154 as seeded. Stable ships every two weeks, starting with 153.
- Everything at or below the floor is used directly.
- Extended Stable users stop receiving updates, and most of them are managed enterprise installs.
- Raise the floor with a staged rollout, after reading "What's new in Chrome extensions" for every milestone in between.

### Enterprise channel: Chrome Extended Stable

- The floor is the current Extended Stable milestone: 152 as seeded. Extended Stable keeps an eight-week cycle, so it trails Stable by a few milestones and moves every eight weeks.
- Never raise the floor above the current Extended Stable milestone. The Chromium release dashboard (chromiumdash.appspot.com) shows which milestone that is.
- Feature-detect every row of the version-gated table above the floor, or do without it.

### Changing channel or raising the floor

1. Read "What's new in Chrome extensions" for every milestone between the old and new floor.
2. Update `extension-targets.psd1`, `minimum_chrome_version`, and the Toolchain table in one commit, and publish with a staged rollout.
3. Remove feature detection for everything now at or below the floor, and add it for anything a lower floor loses.
4. Record a channel change in an ADR: it changes who keeps receiving updates.

## Version-gated features

Features and behavior changes newer than the enterprise floor (Extended Stable 152). Use a row unconditionally only when the project's floor is at or above its version.

| Version | Feature or change                                            | Note                                                     |
| ------- | ------------------------------------------------------------ | -------------------------------------------------------- |
| 153     | `publicSuffix` API (`publicSuffix` permission)               | Registrable-domain lookups without a bundled suffix list |
| 154     | All `webRequest` listeners for an event run in a single task | Behavior change; test ordering assumptions               |
| 155     | `runtime.onEnabled`; `tabs.createSplit()` and `unsplit()`    | In beta on 2026-09-28                                    |

## Default manifest

**Default** manifest for the Stable channel (on Extended Stable, `minimum_chrome_version` is `"152"`):

```json
{
  "manifest_version": 3,
  "name": "My Extension",
  "version": "1.0.0",
  "minimum_chrome_version": "154",
  "background": { "service_worker": "background.js", "type": "module" },
  "action": { "default_popup": "popup.html" },
  "permissions": ["storage"],
  "optional_host_permissions": ["https://*/*"]
}
```

## The background is a service worker

- The background is `background.service_worker`; add `"type": "module"` for static `import`. When `service_worker` is present, Chrome ignores `background.scripts`.
- Chrome terminates the worker in three cases:
  - It has been idle for 30 seconds.
  - A single event or extension API call has run longer than 5 minutes.
  - A `fetch()` response has taken longer than 30 seconds.
- Extension events and API calls reset the idle timer. So do:
  - Messages sent over a port (just opening one does not).
  - WebSocket traffic.
  - A native-messaging port.
  - An attached `debugger` session.
  - Messages from an offscreen document.
- Design for termination rather than fighting it.
- The worker has no DOM, `window`, `localStorage`, or `XMLHttpRequest`; use `fetch`. DOM work goes in an offscreen document.
- Static `import` and `importScripts()` work; dynamic `import()` does not.
- Alarms fire at most every 30 seconds in a packed extension. Unpacked extensions are exempt, so a shorter period that works in development silently stretches in production. Alarm names over 1,024 bytes throw (150).
- **Default:** set `persistAcrossSessions` on alarms explicitly (150; it defaults to `true`), and re-check expected alarms in `onStartup`.
- `runtime.getContexts()` lists the live extension contexts: tabs, popup, side panel, and offscreen document.
- Chrome installs an update only when the extension is idle. An open popup, side panel, or options page, or a worker that never goes idle, delays updates.

## Offscreen documents

- Created with `offscreen.createDocument({ url, reasons, justification })`. The reasons come from a fixed list and are reviewed; choose the ones that are true:
  - `DOM_PARSER`, `DOM_SCRAPING`, `BLOBS`, `CLIPBOARD`
  - `AUDIO_PLAYBACK`, `USER_MEDIA`, `DISPLAY_MEDIA`, `WEB_RTC`
  - `IFRAME_SCRIPTING`, `LOCAL_STORAGE`, `WORKERS`
  - `BATTERY_STATUS`, `MATCH_MEDIA`, `GEOLOCATION`, `TESTING`
- Only one offscreen document can exist at a time. `offscreen.hasDocument()` exists from 150. Guard creation with a shared promise so two events cannot race to create it.
- Only the `runtime` API exists inside it. It talks to the worker through the same message registry as every other context.
- An `AUDIO_PLAYBACK` document closes after 30 seconds of silence; the others live until closed. **Default:** close it when its work is done.

**Default** guard:

```ts
// src/background/offscreen.ts
let creating: Promise<void> | undefined;

export function ensureOffscreen(): Promise<void> {
  creating ??= (async () => {
    if (await browser.offscreen.hasDocument()) return; // Chrome 150+
    await browser.offscreen.createDocument({
      url: '/offscreen.html',
      reasons: [browser.offscreen.Reason.DOM_PARSER],
      justification: 'Parse fetched HTML',
    });
  })().finally(() => {
    creating = undefined;
  });
  return creating;
}
```

## Messaging in Chrome

- Messages are serialized as JSON by default: `undefined`, `Map`, `Set`, `Date`, and class instances do not survive. Chrome 148 added an opt-in `"message_serialization": "structured_clone"` manifest key, but it has three catches:
  - Both ends must agree.
  - Native messaging stays JSON.
  - Extensions with different settings cannot message each other.
- **Default:** stay on JSON.
- From 148, an `onMessage` listener may return a Promise. Chrome documents this as rolling out gradually and tells extensions to work whether or not it is enabled. Keep the dispatcher's `sendResponse` + `return true` form until Chrome's documentation drops that caveat.
- From 146, a listener that throws makes the sender's promise reject; this is also rolling out gradually. The dispatcher's reply envelope does not depend on it.
- `runtime.sendMessage` and `tabs.sendMessage` reject with "Could not establish connection. Receiving end does not exist." when nothing is listening, for example a tab that has not loaded the content script.

## Side panel

- The side panel is the `side_panel.default_path` key plus the `sidePanel` API. `sidePanel.open()` needs a user gesture: an action click, a command, a context-menu item, or a gesture in an extension page or content script.
- **Default:** call `sidePanel.setPanelBehavior({ openPanelOnActionClick: true })` when the panel is the extension's main UI.
- Per-tab panels come from `setOptions({ tabId, path, enabled })`. Available on both channels: `getLayout()` (140), `close()` and `onOpened` (141), and `onClosed` (142). `close({ tabId })` rejects when only the global panel is open.

## Action, menus, and commands

- `action` replaces the MV2 browser and page actions, and it has no `show()` or `hide()`. Use `enable()` / `disable()` per tab, or `declarativeContent`.
- `action.openPopup()` is available to every extension.
- Context menus use `contextMenus`; there is no `menus` namespace. The `"tab"` context exists from 150.
- Commands:
  - At most four commands can have suggested keys.
  - `_execute_action` opens the action and does not fire `onCommand`.
  - `"global"` shortcuts are limited to Ctrl+Shift+0 through 9.

## Permissions in Chrome

- Users control each extension's site access (on click, on specific sites, or on all sites) regardless of the manifest. Check `permissions.contains` before relying on a host.
- `permissions.addHostAccessRequest({ tabId, pattern })` (133) shows an "Allow" request in the extensions menu instead of a modal prompt. **Default:** declare `optional_host_permissions: ["https://*/*"]` for hosts discovered at runtime, and ask through access requests.
- `activeTab`:
  - Granted by an action click, context-menu item, command, or omnibox suggestion.
  - Lasts until the tab navigates to another origin or closes.
  - Never covers `chrome://` pages.

## User scripts

- The `userScripts` API needs the `userScripts` permission, host permissions, and the user's per-extension "Allow User Scripts" toggle on the extension's details page (138+). While the toggle is off, `browser.userScripts` is `undefined`, or throws if the user switched it off after the context loaded.
- Feature-detect it with `try { await browser.userScripts.getScripts(); } catch { … }`, and ship onboarding text that explains the toggle.
- `execute()` (135), multiple worlds (133), and `configureWorld({ messaging: true })` for `runtime.onUserScriptMessage` are all available on both channels. Registered user scripts are cleared on update.
- The Chrome Web Store exempts `userScripts` from the remote-code rule only for scripts the user supplies, never for code your server sends.

## Network

- `declarativeNetRequest` limits:
  - 100 static rulesets, 50 enabled at once.
  - 30,000 guaranteed static rules plus a shared global pool.
  - 30,000 dynamic "safe" rules (`block`, `allow`, `allowAllRequests`, `upgradeScheme`) and 5,000 others.
  - 5,000 session rules.
  - 1,000 regex rules.
- Response-header conditions (128) are evaluated after the request reaches the server. They can stop the response but not the request.
- `getMatchedRules` needs `declarativeNetRequestFeedback` or `activeTab`, and is rate-limited outside user gestures.
- Blocking `webRequest` is unavailable to store-installed extensions; only policy-installed ones get `webRequestBlocking`. Observational `webRequest` still works, and `onAuthRequired` works with `webRequestAuthProvider`.
- The Chrome Web Store can publish ruleset edits that contain only safe rules without a new review.

## Security in Chrome

- The extension-page CSP cannot be looser than `script-src 'self' 'wasm-unsafe-eval'; object-src 'self';`. Code that needs `eval` goes in a `sandbox` page, which gets no extension APIs and talks to its host page with `postMessage`.
- `externally_connectable` defaults are asymmetric: if the key is omitted, every other extension can message yours and no web page can. Once declared, only what it lists can connect. **Default:** declare it with exactly what must connect, and validate external messages like content-script messages.
- `web_accessible_resources` entries with `use_dynamic_url: true` are served at a per-session URL, which blunts fingerprinting.

## Chrome Web Store

- Keep the listing's single purpose and the Privacy practices tab in step with the manifest:
  - **Single purpose.** The listing describes one narrow purpose.
  - **Limited Use.** Collect only the data that purpose needs.
  - **Justifications.** The Privacy practices tab justifies every permission and certifies data use.
- No remote code: no remote `<script>`, no `eval` of fetched strings, and no interpreters running fetched code.
  - Only `debugger` and `userScripts` are exempt, plus sandboxed pages, which are still reviewed.
  - Minification is allowed; obfuscation is not.
- The publishing API is **v2** (`chromewebstore.googleapis.com/v2/…`). It supports service-account auth, staged publish, and percentage rollout for larger items. v1 stops working on 2026-10-15. **Default:** automate with v2, either `wxt submit` with `CHROME_API_VERSION=v2` or `chrome-webstore-upload-cli`.
- Verified uploads are opt-in. Once enabled, every update must be signed with your private key, and replacing a lost key takes up to a week.
- The dashboard can roll back to a previous version.

## Development loop and testing

- Unpacked extensions run only while Developer mode is on (134).
- Branded Chrome no longer accepts `--load-extension` (137) or `--disable-extensions-except` (139). **Default:** automate against Chromium or Chrome for Testing, using either:
  - Playwright's persistent context with `channel: 'chromium'`.
  - Puppeteer with `enableExtensions`.
- Reach the service worker from tests through Playwright's `context.serviceWorkers()` or `serviceworker` event, or through Puppeteer's `service_worker` target.
- Test termination on purpose: Puppeteer's `worker.close()` stops the worker, so the next event must start a fresh one.
- DevTools can view and edit extension storage directly.

## Tooling defaults

- **Default:** WXT (MV3 is its Chrome default) with `targetBrowsers: ['chrome']`. It does not set `minimum_chrome_version`, so put that in the `manifest` config. CRXJS is the alternative for a plain Vite plugin.
- Typings: `@types/chrome`, directly or through WXT's `Browser` types. It declares the `browser` global.

## Layout and boundaries

The browser document's layout section applies. The side panel page lives in `src/sidepanel/` and the offscreen document in `src/offscreen/` (or the matching `entrypoints/` folders). `.claude/rules/chrome-extension-boundaries.md` and `.claude/rules/chrome-extension-manifest.md` add Chrome rules on top of the shared ones; keep their `paths:` globs in step with the layout.
