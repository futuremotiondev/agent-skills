---
last_verified: {{TODAY}}
---

# Browser Extension Style

Seeded by the context-engine `browser-extension` adapter. This document holds what is true of **every** Manifest V3 WebExtension, whichever browser runs it. Language rules live in [TypeScript style](typescript-style.md). A single-browser project also has a browser document ([Firefox extension style](firefox-extension-style.md) or [Chrome extension style](chrome-extension-style.md)) that adds that browser's facts and wins wherever the two disagree.

Statements here are platform facts, guardrails, or **Default:** choices; the conventions README explains the difference and how to deviate.

## Toolchain

The target browsers, their release channels, and their minimum versions decide which APIs and manifest keys are safe to use without a check. Chrome (from 153) and Firefox (from 155) both release every two weeks, so a floor ages quickly: re-read the browser document whenever you raise one.

<!-- Filled at init by /fm-init-context-engine from the interview. Expected shape: a table with one row per layer —
     Target browsers, each with its release channel and minimum version (one row per browser, e.g.
     Firefox Release 156+, Firefox ESR 153+, Chrome Stable 154+, Chrome Extended Stable 152+),
     Manifest version (V3 unless an ADR says otherwise),
     Build tooling (WXT / CRXJS / plain Vite / web-ext only / none),
     Extension API typings, Test runners (unit / end-to-end), Package manager,
     Distribution (AMO listed / unlisted / self-hosted; Chrome Web Store public / unlisted / private; enterprise policy).
     One line each. Keep the browser, channel, and floor values identical to Context/scripts/extension-targets.psd1. -->
{{TOOLCHAIN}}

## The background is event-driven and disposable

Every MV3 browser unloads the background when it is idle and starts it again for the next event. Chrome runs it as a service worker and Firefox as an event page; the browser document covers the mechanics. Either way:

- Hold no state in module-level variables. Anything that must survive goes to `storage.session` (in memory, cleared when the browser closes) or `storage.local` (on disk). A module-level cache that works while you watch it drops data in the field.
- Register every event listener synchronously at the top level of the background entry point. A listener added after an `await` or inside a callback is missing when the background restarts, and the event that woke it is lost.
- Make handlers idempotent. A restart can interrupt a run halfway and deliver the next event to a fresh background.
- Use `runtime.onInstalled` for one-time setup (context menus, default settings, storage migrations keyed on `details.reason` and `details.previousVersion`) and `runtime.onStartup` for per-browser-session setup. Neither runs on every wake.
- Use `alarms`, never `setTimeout` or `setInterval`, for anything that must fire after the background may have unloaded. Timers die with it.
- Chunk long work and persist progress so the next event can resume it.
- Create context menus in `onInstalled` and handle clicks with `onClicked`; the `onclick` property does not work in a non-persistent background.

## API namespace and promises

- Use the `browser.*` namespace with promises and `async`/`await`. Firefox has always provided it; Chrome provides it from 148 (for every extension from 152), and there `chrome.tabs === browser.tabs`.
- Do not add `webextension-polyfill`. It stops wrapping on Chrome 148 and later, and Mozilla archived it in July 2026.
- A few methods still answer synchronously; the common one is `contextMenus.create` / `menus.create`, which returns the menu id.
- Do not read `runtime.lastError` in promise code. A failed call rejects; catch it.

## Messaging

- **Default:** one message registry module (`src/shared/messages.ts`) declares every message type with its payload and result, and both senders and handlers import it. The shape matters more than the mechanism: a small hand-written registry and a library such as `@webext-core/messaging` both qualify.
- Model messages as a discriminated union on `type`, handled exhaustively.
- A message from a content script is untrusted input, because the page can drive the content script. Validate the payload in the background before acting on it.
- Never pass an `async` function straight to `runtime.onMessage.addListener`. It answers every message, including ones meant for another listener.
- **Default:** one dispatcher listener per context. It is a plain (non-`async`) function that returns `false` for message types it does not handle, so it never steals another listener's messages. For types it handles, it calls `sendResponse` when the handler settles and returns `true`. That form works in every browser at every floor and in the in-memory test fakes. Handlers are ordinary `async` functions; only the dispatcher knows how a reply travels, so changing that later is a one-place edit.
- **Default:** reply with an envelope, `{ ok: true, value }` or `{ ok: false, error }`, instead of relying on a rejected promise reaching the sender.
- **Default:** keep payloads plain JSON-compatible data. Chrome serializes messages as JSON by default and Firefox uses structured clone; plain data behaves the same in both and is easy to validate.
- `runtime.sendMessage` rejects when nothing is listening ("Receiving end does not exist"). Treat that as an expected condition, not a crash.

**Default** shape, framework-free:

```ts
// src/shared/messages.ts: every message type, its payload, and its result.
export interface MessageMap {
  getSettings: { payload: null; result: { theme: 'light' | 'dark' } };
  saveNote: { payload: { url: string; text: string }; result: { id: string } };
}

export type MessageType = keyof MessageMap;
export type Payload<K extends MessageType> = MessageMap[K]['payload'];
export type Result<K extends MessageType> = MessageMap[K]['result'];
export type Message = { [K in MessageType]: { type: K; payload: Payload<K> } }[MessageType];
export type Reply<T> = { ok: true; value: T } | { ok: false; error: string };

export async function send<K extends MessageType>(type: K, payload: Payload<K>): Promise<Result<K>> {
  const reply = (await browser.runtime.sendMessage({ type, payload })) as Reply<Result<K>>;
  if (!reply.ok) throw new Error(reply.error);
  return reply.value;
}
```

```ts
// src/background/dispatch.ts: the only code that knows how a reply travels.
import type { Message, MessageType, Payload, Result } from '../shared/messages';

type Sender = Parameters<Parameters<typeof browser.runtime.onMessage.addListener>[0]>[1];
type Handlers = { [K in MessageType]: (payload: Payload<K>, sender: Sender) => Promise<Result<K>> };

// Call once, synchronously, at the top level of the background entry point.
export function listen(handlers: Handlers, isMessage: (raw: unknown) => raw is Message): void {
  browser.runtime.onMessage.addListener((raw: unknown, sender, sendResponse) => {
    if (!isMessage(raw)) return false; // not ours: leave it for another listener
    const handle = handlers[raw.type] as (payload: unknown, sender: Sender) => Promise<unknown>;
    handle(raw.payload, sender).then(
      (value) => sendResponse({ ok: true, value }),
      (error: unknown) => sendResponse({ ok: false, error: String(error) }),
    );
    return true; // keep the channel open until sendResponse runs
  });
}
```

`isMessage` is where payload validation lives: a schema library or hand-written guards, checked against untrusted input.

## Content scripts

- A content script runs in an **isolated world**. It shares the page's DOM but not its JavaScript, so it cannot see page variables and the page cannot see its own.
- Treat the page as hostile. Never `eval` page-supplied strings, never trust page-set attributes as structured data, and never insert page- or network-derived strings with `innerHTML`; use `textContent` or DOM construction.
- Content scripts get a restricted API surface. Privileged work goes through a message to the background.
- Cross-origin network requests belong in the background, where host permissions apply. A content script's `fetch` runs with the page's origin and is subject to the page's CORS rules.
- `storage.session` is not readable from content scripts by default. Share state through `storage.local` or messages.
- **Default:** prefer declarative `content_scripts` in the manifest when the match patterns are known at build time. They are reviewable and need no runtime registration.
- **Default:** write `scripting.executeScript` / `insertCSS` file paths from the extension root with a leading slash (`/content/inject.js`). Both browsers resolve `scripting` paths from the extension root; the slash makes that visible to readers.
- **Default:** re-register dynamic content scripts and user scripts in `runtime.onInstalled` on both `install` and `update`. Firefox clears them on update, and re-registering after `getRegisteredContentScripts()` is cheap.
- `world: "MAIN"` runs code in the page's own JavaScript world, with no extension APIs and no isolation. Use it only for code that must touch page JavaScript, and hand it nothing privileged.

## Extension pages

Popup, options page, and the sidebar or side panel page:

- A popup is destroyed when it closes. Persist anything the user entered before it can be dismissed.
- Read state from storage when the page opens rather than assuming the background pushed it.
- Pages use the same message registry as every other context.

## Storage

- `storage.local` holds durable data, `storage.session` holds per-session state that must survive a background restart, and `storage.sync` is only for small user preferences (tight quotas, and no syncing on Firefox for Android).
- `storage.local.getKeys()` is available in both browsers at current floors.
- **Default:** version the stored schema and migrate in `runtime.onInstalled` when `details.reason === "update"`.
- Storage is readable by anyone with access to the browser profile. Never keep a secret there that you cannot afford to leak.

## Permissions

- Request the narrowest set that works. Every permission is a line in the install prompt and a question at review.
- Host patterns go in `host_permissions` or `optional_host_permissions`, never in `permissions` (that is the MV2 shape).
- Put anything not needed at install in `optional_permissions` / `optional_host_permissions` and request it with `permissions.request` from a user action. Call it before any `await` in the handler; awaiting first loses the user gesture.
- **Host permissions are not guaranteed at runtime.** Users can revoke them per site in both browsers. Check with `permissions.contains` before relying on one, and handle the denial path.
- Try `activeTab` before reaching for broad host permissions. It covers most "act on the current page when the user asks" features.
- `file://` access is a separate user opt-in in both browsers. Check `extension.isAllowedFileSchemeAccess()` and explain the setting when it is off.
- A permission added in an update can re-prompt users, disable the extension until they accept, or stay ungranted. Treat a permission change as a release decision, not an implementation detail.

## Security

- No remote code: no `eval`, no `new Function`, no scripts loaded from outside the package. MV3 forbids it and both stores reject it.
- Keep the default extension-page CSP; `'wasm-unsafe-eval'` is the only relaxation MV3 allows for scripts. A library that needs `eval` runs in a sandboxed page (the `sandbox` manifest key) with no extension-API access. Adding one needs an ADR.
- `web_accessible_resources` lets any matching page load, and so detect, the file. Use the narrowest `matches`, never `<all_urls>` for convenience.
- Never ship an API key or secret in the package; it sits in plain text on the user's disk.
- Minified code is allowed in both stores (AMO also wants the source). Obfuscated code is banned in both.
- **Default:** lint with `eslint-plugin-no-unsanitized` (AMO's linter runs the same rules) and with typed `@typescript-eslint/no-floating-promises`, since every extension API returns a promise.

## Network interception

- **Default:** use `declarativeNetRequest` with static rule files. Rules are declarative and reviewable, and never see request bodies.
- Rule limits differ between browsers; the browser document lists them. If the project ships more than a handful of rules, record the limits it depends on in an ADR.

## Localization

- **Default:** put user-visible strings in `_locales/<lang>/messages.json` from day one, set `default_locale`, and reference them as `__MSG_name__` in the manifest and with `i18n.getMessage()` in code. Retrofitting localization later touches every string.

## Testing

- **Default:** unit tests run under Vitest against an in-memory fake of the extension APIs (`@webext-core/fake-browser`, or `fakeBrowser` from WXT's testing module), reset before each test.
- Test the unload path on purpose. A feature that works only while the background stays alive is a bug the fake will not find.
- End-to-end tooling is browser-specific; see the browser document.

## Packaging and versions

- `version` is one to four dot-separated integers. Keep to that in every store.
- **Default:** one source tree, built per target, with the lockfile committed.
- Record each store's build and submission commands in the commands table in `CLAUDE.md`.

## Adding or changing a target browser

This section ships in every install on purpose: a single-browser project should know what changes if it later adds a browser. Until then, a single-browser project can skip it.

- Record the new target and floor in the Toolchain table and in `Context/scripts/extension-targets.psd1` in the same commit. The manifest index then checks the manifest against both.
- **Default:** generate the manifest per target (a build config, or WXT's per-browser `manifest` function) rather than hand-maintaining divergent copies.
- Feature-detect APIs that exist in only one browser (`if (browser.sidePanel) { … }`) and keep browser-specific code behind one module.
- A Chrome floor below 148 needs `globalThis.browser ??= chrome;` at startup, Google's documented guard, instead of the archived polyfill. The dispatcher's `sendResponse` form already works there.

| Area                                 | Chrome / Chromium                                                                    | Firefox                                                                                                       |
| ------------------------------------ | ------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------- |
| Background                           | `background.service_worker`: no DOM; DOM work goes to an offscreen document          | `background.scripts` event page with a DOM; `service_worker` unsupported                                      |
| Both background keys present         | Uses `service_worker`, ignores `scripts`                                             | Uses `scripts`                                                                                                |
| Sidebar                              | `side_panel` key + `sidePanel` API                                                   | `sidebar_action` key + `sidebarAction` API (desktop only)                                                     |
| Page action                          | Merged into `action`                                                                 | Separate `page_action` retained                                                                               |
| Context menus                        | `contextMenus` only                                                                  | `menus`, with `contextMenus` as an alias                                                                      |
| Extension id                         | `key` (stable id during development)                                                 | `browser_specific_settings.gecko.id` (required to sign)                                                       |
| Minimum version                      | `minimum_chrome_version`                                                             | `browser_specific_settings.gecko.strict_min_version`                                                          |
| Data-collection disclosure           | Chrome Web Store dashboard (Privacy practices tab)                                   | `gecko.data_collection_permissions` in the manifest (required for new extensions)                             |
| Message serialization                | JSON by default (`structured_clone` opt-in from 148)                                 | Structured clone                                                                                              |
| `onMessage` returning a Promise      | From 148, rolling out gradually                                                      | Supported                                                                                                     |
| `storage.session` in content scripts | Opt-in with `setAccessLevel`                                                         | Not available                                                                                                 |
| `userScripts` permission             | Install-time permission plus the user's "Allow User Scripts" toggle                  | `optional_permissions` only, requested alone                                                                  |
| Relative `url()` in injected CSS     | Resolves against the page                                                            | Resolves against the CSS file                                                                                 |
| Blocking network                     | DNR; blocking `webRequest` only for policy-installed extensions                      | DNR plus blocking `webRequest` and `filterResponseData`                                                       |
| Only in this browser                 | `offscreen`, `sidePanel`, `declarativeContent`, `debugger`, `externally_connectable` | `sidebarAction`, `contextualIdentities`, `theme`, `dns`, `find`, `browserSettings`, `pkcs11`, `captivePortal` |

## Layout and boundaries

**Default** split:

- `src/background/`: the background entry point and its handlers.
- `src/content/`: content scripts.
- `src/popup/`, `src/options/`, and the browser's sidebar or side panel page: extension pages.
- `src/shared/`: types, constants, and the message registry.

WXT projects use `entrypoints/` instead (or `src/entrypoints/` with `srcDir: 'src'`). The path-scoped rules in `.claude/rules/extension-boundaries.md` and `.claude/rules/extension-manifest.md` auto-load when you edit these. If this project uses different directory names, update BOTH those rules' `paths:` globs and this section.

`Context/generated/manifest-index.md` is a machine-generated inventory of every manifest in the repo, checked against the targets in `Context/scripts/extension-targets.psd1`. Regenerate it with `/refresh-context` after any manifest change.
