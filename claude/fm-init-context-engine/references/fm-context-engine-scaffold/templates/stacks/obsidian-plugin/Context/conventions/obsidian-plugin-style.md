---
last_verified: {{TODAY}}
---

# Obsidian Plugin Style

Seeded by the context-engine `obsidian-plugin` adapter for Obsidian community plugins, on the public channel (1.13.0+ as seeded) or the Early access channel (1.14.0+). General TypeScript rules live in [TypeScript style](typescript-style.md); this document covers the Obsidian API, the plugin lifecycle, and the Community directory. Statements are platform facts, guardrails, or **Default:** choices (see the conventions README).

## Toolchain

<!-- Filled at init by /fm-init-context-engine from the interview. Expected shape: a table with one row per layer —
     Channel (public / early-access), Floor (manifest "minAppVersion"; keep the two identical),
     Platforms (desktop + mobile, or desktop only = "isDesktopOnly": true),
     Typings (the "obsidian" package version), Build tooling (esbuild per the sample plugin / other),
     Lint (eslint-plugin-obsidianmd version), Tests (unit / end-to-end, or none yet), Package manager,
     Distribution (Community directory / BRAT betas / private). One line each. -->
{{TOOLCHAIN}}

## Release channel and floor

The project's floor is `minAppVersion` in `manifest.json`, and the Toolchain table records the same floor and its channel. Obsidian installs a plugin release only when the app is at or above its `minAppVersion`. For an older app it reads `versions.json` on the default branch (plugin version → the `minAppVersion` it needs) and installs the newest release that still fits. Raising the floor leaves older apps on an older release; it does not remove the plugin.

- The app version and the installer version are separate. The app updates itself; the installer (Electron, which decides the Chromium and Node versions) changes only when the user reinstalls. The newest installer is Electron 43 (Chromium 150, Node 24, shipped with 1.13.6), and many users run older ones. The installer, not `minAppVersion`, decides which JavaScript syntax runs.
- Typings lag the app. The `obsidian` package is published only when the API changes: npm has 1.13.1, the repository has unpublished 1.13.2 types, and no 1.14 types exist yet (checked 2026-09-30).

### Public channel

- The floor is a public minor: 1.13.0 as seeded, where the declarative settings API arrived. The latest public releases are 1.13.7 (desktop) and 1.13.8 (mobile).
- Everything at or below the floor is used directly. Newer rows of the version-gated table are feature-detected with `requireApiVersion()`, or done without.

### Early access channel

- The floor is the current Early access minor: 1.14.0 as seeded (1.14.0 through 1.14.3 are Early access, from 2026-09-02). Early access builds need a Catalyst license.
- Until that minor goes public, a release with this floor installs only for Early access users. A new plugin is unusable for everyone else, and existing users stay on the newest release `versions.json` allows.
- Choose it for work that ships after the minor goes public, or for betas tested on Early access builds.

### Changing channel or raising the floor

1. Read the Obsidian changelog (developer notes) for every release between the old and new floor, and check the `@since` tags in `obsidian.d.ts`.
2. Update `minAppVersion`, add the `versions.json` entry, and update the Toolchain table in one commit.
3. Remove `requireApiVersion()` checks for everything now at or below the floor, and add them for anything a lower floor loses.
4. Record a channel change in an ADR: it decides which users receive new releases.

## Version-gated APIs

Newer than the public floor (1.13.0). Use a row unconditionally only when the project's floor is at or above its version; otherwise guard it with `requireApiVersion('<version>')`.

| Version | API or change | Note |
| ------- | ------------- | ---- |
| 1.13.1 | `Setting.addDisplayValue()`, `DisplayValueComponent`; group `search`; page `displayValue` and `status`; slider `displayFormat` | Declarative settings additions |
| 1.13.2 | `type: 'secret'` setting control (`SettingSecretControl`) | In the repository typings only; not in npm 1.13.1 |
| 1.13.5 | `disabled` on every setting definition (`SettingDefinitionBase`) | Changelog only; controls and actions have had `disabled` since 1.13.0 |
| 1.14.0 | `SettingDefinitionItem#id` | Early access; no typings yet |
| 1.14.0 | The workspace mirrors for right-to-left languages; `$$` math lines get `.HyperMD-math` | Behavior; check layouts that assume left-to-right |
| 1.14.1 | Math renders with MathJax 4.1.3 (was MathJax 3); `--font-preferred-size` | Retest code that post-processes math output |
| 1.14.3 | New `--tooltip-*`, `--notice-*`, `--hotkey*`, `--tab-inner-*`, `--tab-container-*` variables | |

Available at the public floor, and often missed by code written for older versions: deferred views, `onUserEnable()`, and a Promise-returning `revealLeaf()` (1.7.2); `App.loadLocalStorage()` / `saveLocalStorage()`, `getLanguage()`, and `Notice.messageEl` (1.8.7); Bases views and `App.isDarkMode()` (1.10.0); `SettingGroup` (1.11.0); `app.secretStorage` (1.11.4); `registerCliHandler()` (1.12.2); `Vault.appendBinary()` (1.12.3); declarative settings, `Setting.setErrorMessage()`, `ButtonComponent.setDestructive()`, and `ConfirmationModal` (1.13.0).

Deprecated or removed; use the replacement:

- `SettingTab.display()` → `getSettingDefinitions()` (1.13.0). `display()` is not called when the definitions are non-empty.
- `ButtonComponent.setWarning()` → `setDestructive()`. `SliderComponent.setDynamicTooltip()` is obsolete; the value is always shown.
- `Workspace.activeLeaf` → `getActiveViewOfType()` or `getActiveFile()`. `MarkdownRenderer.renderMarkdown()` → `MarkdownRenderer.render()`. `Notice.noticeEl` → `messageEl`. `splitActiveLeaf()` and `getUnpinnedLeaf()` → `getLeaf()`.
- Removed from the typings: `CloseableComponent` (use `HistoryHandler`), `SliderComponent.showTooltip()`, and `prepareQuery()` / `fuzzySearch()` (use `prepareFuzzySearch()`).
- The `tag`, `alias`, and `cssclass` frontmatter keys are unsupported since 1.9.10; use the list-valued `tags`, `aliases`, and `cssclasses`.

## Lifecycle and load time

- `onload()` only registers: commands, views, settings tab, events, processors. Startup work goes in `this.app.workspace.onLayoutReady(cb)`. Load time is shown under Settings → General → Advanced.
- `vault.on('create')` fires for every file while the vault loads. Register it inside `onLayoutReady`.
- Views restored at startup construct during load, so a view constructor stays cheap.
- Everything registered through the plugin is torn down on unload: `registerEvent()`, `registerDomEvent()`, `registerInterval()`, `register(cb)`, and children added with `addChild()`. A listener, timer, or observer attached any other way outlives the plugin; register it.
- `onunload()` does not detach leaves. Obsidian restores them when the plugin loads again, and detaching loses the user's layout.
- `onUserEnable()` runs when the user enables the plugin, not at every startup. Open a first-run view there, not in `onload()`.
- `onExternalSettingsChange()` runs when `data.json` changes on disk, for example through Obsidian Sync. Reload settings there.
- `console.log` is not for production: by default the console shows only errors. `eslint-plugin-obsidianmd` flags every `console` method except `warn`, `error`, and `debug`.

## Settings and secrets

- Plugin data is `loadData()` / `saveData()`, stored in the plugin's `data.json` and synced with the vault.
- Merge loaded data over a copy of the defaults, never into the defaults object. Spread and `Object.assign` are shallow, so nested default objects must be cloned too.
- At a 1.13+ floor, a settings tab implements `getSettingDefinitions()`. Only definitions appear in the settings search, and `display()` is deprecated, so it is not kept as a fallback. The default `getControlValue()` / `setControlValue()` read and persist `this.plugin.settings[key]`; override them to store elsewhere. Call `update()` when the definitions depend on state that changed.
- Headings: only when the tab has more than one section, never containing the word "settings", and never HTML heading elements (use groups, or `setHeading()`).
- Secrets (API keys, tokens) never go in `data.json`, which is plain text and synced. Use `app.secretStorage` (1.11.4): the user picks or creates a secret with `SecretComponent` (or a `type: 'secret'` control from 1.13.2), the plugin stores only the secret's id, and it reads the value with `getSecret(id)`.
- Per-device values (window positions, caches) use `App.saveLocalStorage()` / `loadLocalStorage()`, which are scoped to the vault. Raw `localStorage` is shared by every vault on the device.

**Default** settings shape:

```ts
// src/settings.ts
import { PluginSettingTab, type SettingDefinitionItem } from 'obsidian';

export interface NoteToolsSettings {
  inboxFolder: string;
  showRibbon: boolean;
}

export const DEFAULT_SETTINGS: NoteToolsSettings = { inboxFolder: 'Inbox', showRibbon: true };

export class NoteToolsSettingTab extends PluginSettingTab {
  getSettingDefinitions(): SettingDefinitionItem[] {
    return [
      { name: 'Inbox folder', desc: 'Where captured notes are created.', control: { type: 'text', key: 'inboxFolder' } },
      { name: 'Show ribbon icon', control: { type: 'toggle', key: 'showRibbon', defaultValue: true } },
    ];
  }
}

// src/main.ts, in the Plugin subclass (declare settings: NoteToolsSettings;)
//   this.settings = { ...structuredClone(DEFAULT_SETTINGS), ...((await this.loadData()) as Partial<NoteToolsSettings> | null) };
//   this.addSettingTab(new NoteToolsSettingTab(this.app, this));
```

## Vault and files

- The Vault API, not `vault.adapter`: the Vault caches and serializes operations. The adapter is only for paths the Vault does not index, such as the config folder. It is a `FileSystemAdapter` on desktop and a `CapacitorAdapter` on mobile, so check `instanceof` before using desktop-only members.
- The active note is edited through the `Editor` (`editorCallback`, `app.workspace.activeEditor`), which keeps the cursor and undo history.
- Background edits use `Vault.process(file, fn)`: atomic, with a synchronous callback. For async work, read with `cachedRead()`, compute, then apply with `process()` and check that the content has not changed in between.
- Frontmatter goes through `FileManager.processFrontMatter()`, never string edits.
- Deleting uses `FileManager.trashFile()`, which honours the user's deletion setting. Renaming or moving uses `FileManager.renameFile()`, which updates links; `Vault.rename()` does not.
- Look files up with `getFileByPath()`, `getFolderByPath()`, or `getAbstractFileByPath()`, never by iterating `getFiles()`. Narrow with `instanceof TFile` / `TFolder`, never a cast.
- User-supplied and constructed paths go through `normalizePath()`. The config folder is `this.app.vault.configDir`; users can rename `.obsidian`.
- Headings, links, tags, and frontmatter come from `metadataCache.getFileCache(file)`, without reading and parsing the file. Listen to `metadataCache.on('changed')` for updates.
- Links are generated with `FileManager.generateMarkdownLink()`, which follows the user's link settings.

**Default** edit shapes:

```ts
await this.app.vault.process(file, (text) => text.replace(/^- \[ \] /gm, '- [x] '));
await this.app.fileManager.processFrontMatter(file, (fm: Record<string, unknown>) => {
  fm['reviewed'] = true;
});
```

## Views

- `registerView(type, (leaf) => new MyView(leaf))`. The view type is stored in the user's saved workspace, so renaming it strands their open leaves.
- Views are deferred (1.7.2): a restored leaf holds a `DeferredView` until it is shown. Check `leaf.view instanceof MyView` before use, and `await workspace.revealLeaf(leaf)` before talking to a view. `leaf.loadIfDeferred()` exists, but loading hidden views costs startup time.
- The plugin never stores a view reference. Find views with `workspace.getLeavesOfType(type)` when needed.
- Bases views (1.10.0) register with `registerBasesView(viewId, registration)` and extend `BasesView`, implementing `onDataUpdated()`. Read options through the registration's `options(config)`; since 1.12 `shouldHide` no longer receives `config`.

## Editor and rendering

- Editor features are CodeMirror 6 extensions registered with `registerEditorExtension([...])` in `onload()`. To reconfigure, mutate that same array and call `workspace.updateOptions()`.
- `@codemirror/*` and `@lezer/*` are provided by the app and stay external in the bundle. A second bundled copy of `@codemirror/state` breaks extensions ("Unrecognized extension value").
- Reading view uses `registerMarkdownPostProcessor()` and `registerMarkdownCodeBlockProcessor(lang, …)`. Anything with state attaches a `MarkdownRenderChild` through `ctx.addChild()`, which unloads it with its element.
- `MarkdownRenderer.render(app, markdown, el, sourcePath, component)` takes a component that owns the rendered content, such as the view or a render child, never the plugin. Content owned by the plugin lives until the plugin unloads.

## DOM, text, and styling

- Build DOM with `createEl()`, `createDiv()`, `createSpan()`, `setText()`, `setIcon()`, and `el.empty()`. `innerHTML`, `outerHTML`, and `insertAdjacentHTML` fail review. Trusted HTML goes through `sanitizeHTMLToDom()`.
- No `el.style.*` assignments and no `<style>` or `<link>` elements. Styles live in `styles.css`, which Obsidian loads from the plugin folder. For values only known at runtime, set a CSS custom property with `el.setCssProps({ '--x': value })` and use it from `styles.css`.
- All UI text is sentence case: setting names, command names, buttons, notices, and menu items. Proper nouns and acronyms keep their casing.
- Style with Obsidian's CSS variables (`--text-muted`, `--background-modifier-border`, and so on) so themes apply. Keep selectors low-specificity and avoid `!important`. Base colours are OKLCH since 1.13, and `--callout-color` takes any CSS colour, no longer an RGB triplet.
- **Default:** prefix the plugin's CSS classes with its id, and prefer logical properties (`margin-inline-start`) because the workspace mirrors in right-to-left languages from 1.14.
- Icon-only buttons get an `aria-label`; keyboard access works everywhere a click does.

## Pop-out windows

- Each pop-out window has its own `window` and `document`. Use the element's own: `el.doc` and `el.win`. Otherwise use `activeDocument` and `activeWindow`, never the bare globals.
- Timers are `activeWindow.setTimeout()` / `setInterval()`, and intervals are registered.
- Cross-window type checks use `el.instanceOf(HTMLElement)` and `evt.instanceOf(MouseEvent)`; `instanceof` fails for nodes from another window.
- Work bound to a window (a canvas, an observer) re-initializes in `el.onWindowMigrated(cb)`.

## Mobile

- Node and Electron APIs (`fs`, `path`, `child_process`, `electron`, `process`) do not exist on mobile. A plugin that uses them unguarded sets `"isDesktopOnly": true`. Otherwise it guards them behind `Platform.isDesktopApp` and a dynamic `require`.
- Detect platforms with `Platform` (`isMobile`, `isIosApp`, `isAndroidApp`, `isMacOS`), never `navigator.userAgent` or `process.platform`.
- Regex lookbehind needs iOS 16.4 or later, and review blocks it. Use it only in a desktop-only plugin.
- Status-bar items are not shown on mobile. From 1.14, mobile settings open in a sheet.
- Test with `app.emulateMobile(true)` (or `obsidian dev:mobile on`), then on a device: `chrome://inspect` for Android, and Safari Web Inspector for iOS 16.4+.

## Network and security

- Plugins run with the app's full privileges; there is no sandbox and no permission prompt. Plugin access declarations are announced for the Community directory but not shipped (checked 2026-09-30).
- HTTP goes through `requestUrl()`, which is not subject to CORS. `fetch`, axios, got, ky, and similar are flagged.
- Never execute strings: no `eval`, `new Function`, or string timers. These block a release.
- No remote code: nothing downloaded and executed, and no self-updating. No obfuscation, no client-side telemetry, and no ads loaded over the network.
- The README discloses network use (which services and why), required accounts or payments, access to files outside the vault, server-side telemetry (with a privacy policy link), and any static ads.
- Treat input from `obsidian://` protocol actions, CLI handlers, and file contents as untrusted.
- `moment` is imported from `obsidian`, never bundled. Use `this.app`, never the global `app`.

## Commands and other surface

- `addCommand({ id, name, … })` with the callback that fits: `callback`, `checkCallback` (conditionally available), or `editorCallback` / `editorCheckCallback` (needs an editor).
- Obsidian prefixes command ids with the plugin id and shows the plugin name before command names, so neither repeats them. Neither contains the word "command".
- No default `hotkeys`: they collide with users' bindings. Command ids stay stable, because users' hotkeys are bound to them.
- CLI handlers (1.12.2) need globally unique ids: `<plugin-id>` for the default command and `<plugin-id>:<action>` for others. Registering a duplicate throws. The CLI is desktop only.
- `registerExtensions()` claims a file extension for a view type. Another plugin claiming the same one conflicts.

## Release and the Community directory

- A release is a GitHub release whose tag equals the manifest `version` exactly (`x.y.z`, no `v`). It has `main.js` and `manifest.json` attached individually, plus `styles.css` if the plugin has one. `main.js` is build output and is not committed.
- The directory reads `manifest.json` at the head of the default branch for the listing. The `id` cannot change after publishing.
- Every release is scanned for manifest, release, source, and build problems. Build verification runs the first of the `build`, `build:plugin`, or `compile` npm scripts and compares the result with the released `main.js`, so the build must reproduce from the committed source and lockfile.
  - Only errors block a release. For a listed plugin, a failing version is removed from search within 24 hours. A new plugin is not installable until its errors are resolved.
  - The scan keeps `no-eval`, `no-implied-eval`, `no-unsanitized/*`, `regex-lookbehind`, and `no-forbidden-elements` as errors and reports most other `eslint-plugin-obsidianmd` rules as warnings. Its exact severities are not documented.
- A LICENSE file is required and is detected by GitHub's license detection.
- Submission: sign in at community.obsidian.md, connect GitHub, add the repository, and accept the developer policies. A new GitHub release triggers a scan; "Review branch" previews one without releasing. `community-plugins.json` in `obsidianmd/obsidian-releases` is now a read-only mirror, and pull requests there are not the submission path.
- A fork is listed only with the original author's approval.
- Obsidian has no beta channel. **Default:** ship betas as GitHub pre-releases for BRAT, whose tag, release name, and manifest version match (for example `1.4.0-beta.1`), and keep the beta version off the default branch.
- **Default:** attest release assets with `actions/attest` in the release workflow, as the sample plugin does. The directory shows attestations; it does not require them.

## Development loop and testing

- Develop in a dedicated test vault, never a real one. The plugin folder is `<vault>/<configDir>/plugins/<id>/` and its name matches the manifest `id`. Restricted mode must be off.
- After a code change, reload the plugin: `obsidian plugin:reload id=<id>`, then `obsidian dev:errors` and `obsidian dev:console level=error`. The Obsidian CLI needs Obsidian running, the 1.12.7+ installer, and Settings → General → Command line interface. `dev:screenshot`, `dev:dom`, `dev:css`, and `eval` help verify UI changes.
- After a `manifest.json` change, restart Obsidian (`obsidian restart`).
- **Default:** the Hot Reload plugin, which reloads any plugin folder that contains `.git` or a `.hotreload` file when its `main.js` or `styles.css` changes. Build into the vault through a directory symlink or by cloning into the plugins folder.
- **Default:** unit tests with vitest and `obsidian-test-mocks`. End-to-end tests with `wdio-obsidian-service`, which can run the app version `earliest` (read from `minAppVersion`), `latest`, or `latest-beta` (needs Catalyst credentials), with mobile emulation or on Android. It does not support iOS.

## Tooling defaults

- **Default:** the official sample plugin's setup. That is esbuild with entry `src/main.ts`, output `main.js` at the repository root, `format: 'cjs'`, `target: 'es2021'`, a minified production build, and an inline source map in development.
- External in the bundle, whatever the tooling: `obsidian`, `electron`, `@codemirror/*`, `@lezer/*`, and Node built-ins (from `node:module`'s `builtinModules`). The app provides them.
- **Default:** `eslint-plugin-obsidianmd` (0.4.x, ESLint 9.19+) with its `recommended` flat config, linting `package.json` as well as source. Its `no-unsupported-api` rule checks API use against `minAppVersion` but uses typings pinned at 1.12.3 in 0.4.2, so it misses 1.13+ APIs; the version-gated table is the check for those.
- **Default:** `npm version patch|minor|major` with `tag-version-prefix=""` in `.npmrc` and the sample's `version-bump.mjs`, which writes the version into `manifest.json` and records it in `versions.json`.
- Commit the lockfile; build verification installs from it.

## Layout and boundaries

**Default** layout: `src/main.ts` (the `Plugin` subclass, registrations only), `src/settings.ts` (settings type, defaults, tab), and one module per feature (views, commands, processors). `styles.css`, `manifest.json`, and `versions.json` sit at the repository root. `.claude/rules/obsidian-plugin-boundaries.md` auto-loads when editing source and `.claude/rules/obsidian-plugin-manifest.md` when editing the manifest or `versions.json`; if this project uses different paths, update both rules' `paths:` globs and this section.

`Context/generated/obsidian-manifest-index.md` is a machine-generated inventory of the manifest, `versions.json`, and the surface the source registers, with a release-readiness report. Regenerate it with `/refresh-context` after any manifest change or a new registration.
