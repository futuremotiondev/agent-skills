# What counts as an Antigravity / Gemini skill

Google's agent surfaces split in 2026. **Antigravity** (App 2.0, IDE, and the `agy` CLI — released
May 19, 2026) is current; **Gemini CLI** stopped serving consumer/free tiers on June 18, 2026 but
remains open source and usable with paid API keys or Code Assist Standard/Enterprise licences. Both
implement the open **Agent Skills** standard. Gemini CLI *extensions* became Antigravity *plugins*.

Facts here were verified against `antigravity.google/docs/*` (every page has a `.md` twin) and the
`google-gemini/gemini-cli` docs tree as of 2026-10-24. The `agy` binary is closed-source; its repo
(`google-antigravity/antigravity-cli`, v1.4.7 on 2026-10-24) holds only README, changelog, and
examples. Record any drift in the Run Log.

## 1. Skill — `SKILL.md` (both surfaces)

```
<skill-name>/
├── SKILL.md       # required — frontmatter: description (required), name (optional on Antigravity)
├── scripts/  references/  assets/   # open-spec conventions; Antigravity docs also name examples/, resources/
```

**Frontmatter per Antigravity docs:** `description` required; `name` optional ("defaults to the
folder name"), lowercase + hyphens. Gemini CLI follows the open spec (`name` + `description`).

**Where Antigravity loads skills — note `.agents/` is plural:**

| Surface | Workspace | Global |
|---|---|---|
| App | `<workspace>/.agents/skills/<skill>/` | `~/.gemini/config/skills/<skill>/` |
| IDE | `<workspace>/.agents/skills/<skill>/` | `~/.gemini/config/skills/<skill>/` (legacy `~/.gemini/antigravity/skills/`) |
| CLI | `<workspace>/.agents/skills/<skill>/` | `~/.gemini/antigravity-cli/skills/<skill>/` plus `~/.gemini/antigravity-cli/plugins/<name>/skills/` |

The third-party installer default `~/.agents/skills` (written by `npx skills` and `agents-cli`) is
picked up by the Antigravity **App** but **not** by the Antigravity **CLI**. The legacy singular
`.agent/` is for rules only. CLI auto-converts every skill into a `/<skill-name>` slash command;
`/skills` lists them.

**Where Gemini CLI loads skills (lowest → highest precedence):** built-in → extension `skills/` →
user `~/.gemini/skills/` or alias `~/.agents/skills/` → workspace `.gemini/skills/` or alias
`.agents/skills/`. Within a tier the `.agents/skills/` alias wins. Activation goes through an
`activate_skill` tool with a consent prompt.

**There is no `agy skills install`.** Skills reach Antigravity by copying, by `npx skills add`, or
bundled inside a plugin. Gemini CLI has `gemini skills install <git-url> [--path <subdir>] [--scope
user|workspace] --consent`, `gemini skills list --all`, `gemini skills uninstall <name>`, and
in-session `/skills list|link|enable|disable|reload`.

## 2. Antigravity Plugin — `plugin.json`

```
<plugin>/
├── plugin.json        # required marker and manifest
├── mcp_config.json    # optional MCP servers (serverUrl key, not url/httpUrl)
├── hooks.json         # optional
├── skills/<name>/SKILL.md
├── agents/<name>.md
└── rules/<name>.md
```

**Manifest:** `{"$schema": "https://antigravity.google/schemas/v1/plugin.json", "name": "...",
"description": "..."}`. `name` matches `^[a-zA-Z0-9-_]+$`; required for CLI, defaults to folder name
in App/IDE. Schema sets `additionalProperties: false` — a manifest with extra keys is invalid.

**Install (official):**

```
agy plugin install <plugin-name>@antigravity-plugins-official
agy plugin install <plugin-name>                 # defaults to @antigravity-plugins-official
agy plugin install https://github.com/<owner>/<repo>
agy plugin install </path/to/local/plugin>
agy plugin list [--json]                         # --json includes skills/agents/rules/mcpServers/hooks
agy plugin enable|disable|uninstall <plugin-name>
agy plugin import gemini                         # migrates Gemini CLI extensions → plugins
```

In-TUI: `/plugin` (alias `/plugins`) opens a manager with **Discover** and **Installed** tabs.
`agy plugin validate` and `agy plugin link` appear only in a third-party cheat sheet — **unverified**.

**On disk:** CLI `~/.gemini/antigravity-cli/plugins/<name>/`; App/IDE manual install
`.agents/plugins/` (workspace) or `~/.gemini/config/plugins/` (global).

**The `antigravity-plugins-official` marketplace** carries Google's curated plugins (firebase, flutter
with 23 skills and a `dart-mcp-server`, gdocs, gsheets, google_slides, gcalendar, workspace, and
more under "Build with Google"). Listing is by interest form. **No public source repo was found** —
enumerate it from inside `agy`, not from GitHub.

## 3. Gemini CLI Extension — `gemini-extension.json`

```
<extension>/
├── gemini-extension.json   # required, at repo root (or release-archive root)
├── GEMINI.md               # context file (name set by contextFileName)
├── commands/<name>.toml    # → /name ; commands/gcs/sync.toml → /gcs:sync
├── skills/<name>/SKILL.md
├── agents/*.md  hooks/hooks.json  policies/*.toml
```

**Manifest fields:** `name` (lowercase/digits/dashes, should match directory), `version`,
`description` (shown in the gallery), `mcpServers` (map; all MCP options except `trust`;
`${extensionPath}` / `${workspacePath}` variables), `contextFileName` (defaults to `GEMINI.md`),
`excludeTools` (e.g. `"run_shell_command(rm -rf)"`), `migratedTo` (URL of successor repo),
`plan.directory`, `settings[]` (`name`, `description`, `envVar`, `sensitive`), `themes[]`.

**Install:** `gemini extensions install <source> [--ref <ref>] [--auto-update] [--pre-release]
[--consent] [--skip-settings]`, `--path=<local>`; also `uninstall`, `disable|enable --scope
user|workspace`, `update <name>|--all`, `new <path> [mcp-server|context|custom-commands]`, `link`,
`config`, `list`. Installs to `~/.gemini/extensions/<name>/` with
`.gemini-extension-install.json` recording install type. Not available inside interactive mode.

**Gallery listing is automatic:** public GitHub repo + topic **`gemini-cli-extension`** + root
`gemini-extension.json` → crawled daily, listed at `geminicli.com/extensions/browse/` if validation
passes. The gallery showed 2,194 entries on 2026-10-24, each card with `@owner/repo`, description,
component tags (`MCP`, `Context`, `Commands`, `Skills`, `Hooks`), and stars.

**Every gallery entry is an Antigravity candidate** via `agy plugin import gemini` or
`agy plugin install <github-url>`, with MCP keys auto-migrated (`url`/`httpUrl` → `serverUrl`).
Catalog as **Portable** for Antigravity unless the repo also ships a `plugin.json`.

## 4. Skill Pack — a repo of skills with no manifest

A `skills/<name>/SKILL.md` tree (or root `SKILL.md`) installable via `npx skills add <owner>/<repo>`.
Google itself ships this way: `firebase/agent-skills` (`firebase-basics`, `firebase-hosting-basics`,
`firebase-auth-basics`, `firebase-firestore-enterprise-native-mode`), `flutter/agent-plugins`,
`dart-lang/skills`. Google codelabs recommend `npx skills add` for both surfaces.

## Not skills — classify correctly

| Artifact | Treatment |
|---|---|
| `GEMINI.md` / `AGENTS.md` | Always-on context. Gemini CLI loads `~/.gemini/GEMINI.md` → workspace/parents → JIT; renameable via `settings.json` `context.fileName`. Antigravity treats both as interchangeable rules at `<dir>/`, `<dir>/.agents/`, `~/.gemini/`, `~/.gemini/config/`. Readiness signal only. |
| `.agents/rules/*.md` (legacy `.agent/rules/`) | Antigravity rules with `trigger: always_on\|model_decision\|glob\|manual`, `description`, `globs`. 24 KB/file, 20k-token aggregate. Not a skill. |
| `mcp_config.json` / `settings.json` `mcpServers` | MCP configuration. An MCP-only bundle with no authored skill is **Partial** coverage. |
| `.gemini/config.yaml` + `styleguide.md` | Gemini Code Assist for GitHub review config. Out of scope. |
| `agents-cli` project | Google Agents CLI (ADK) scaffolding. Out of scope. |
| Jules `AGENTS.md` | Jules reads it; no skill mechanism. Out of scope. |

## Surface compatibility summary

| Artifact | Antigravity | Gemini CLI |
|---|---|---|
| `SKILL.md` under `.agents/skills/` | Native | Native (alias) |
| `plugin.json` (antigravity.google schema) | Native | — |
| `gemini-extension.json` | Portable via `agy plugin import gemini` | Native |
| `npx skills add` output in `~/.agents/skills` | App yes · **CLI no** | Yes (alias of `~/.gemini/skills`) |

## What ports cleanly

Any valid Agent Skills `SKILL.md` loads on both surfaces once placed under `.agents/skills/`.
A Gemini CLI extension ports to Antigravity with one command. What does **not** port without work:
Claude-specific `allowed-tools` grammar and `/plugin:skill` namespacing; Codex `agents/openai.yaml`;
MCP configs using legacy `url`/`httpUrl` (rename to `serverUrl`). Classify such finds as
**Portable** and name the one adjustment needed.
