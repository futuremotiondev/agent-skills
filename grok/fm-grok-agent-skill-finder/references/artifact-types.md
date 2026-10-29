# What counts as a Grok Build skill

**First, the product boundary.** Three things at xAI are called "skills":

| Product | What "skill" means | In scope? |
|---|---|---|
| **Grok Build** — the `grok` terminal coding agent (TUI, headless `-p`, ACP), launched 2026-05-25 | `SKILL.md` folders, plugins, marketplaces | **Yes** |
| Consumer Grok on grok.com / iOS / Android (since 2026-05-18) | Conversational "Grok Skills" with a Skill Creator; no file format, directory, CLI, or registry | No |
| Grok Bot | Per-Bot private skill libraries, "Teach a task" recordings, routines; `x.ai/bot/marketplace` | No (unless asked) |

Also not an agent: "Grok Code" is the `grok-code-fast-1` model. xAI API server-side tools
(`web_search`, `x_search`, `code_interpreter`, collections, remote MCP) are a tool layer, not skills.
Filter on developer artifacts (`SKILL.md`, `.grok-plugin/`, `grok plugin install`), never on the
phrase "Grok skill".

Facts verified against `docs.x.ai/build/*` (every page has a `.md` twin; index at
`docs.x.ai/llms.txt`) and `xai-org/plugin-marketplace` as of 2026-10-24. The CLI ships weekly
(v1.0.67 on 2026-10-21); record drift in the Run Log.

## 1. Skill — `SKILL.md`

```
<skill-name>/
├── SKILL.md       # YAML frontmatter; "Extra keys are ignored"
├── scripts/  references/  assets/
```

**Frontmatter (official):** `name` (defaults to directory name), `description` (defaults to first
body paragraph), **`when-to-use`** (alias `when_to_use`) — Grok-specific, drives auto-invocation —
`paths`, `allowed-tools`, `argument-hint`, `user-invocable` (default true), `disable-model-invocation`
(default false), `metadata` (`author`, `short-description` shown in UI). Accepted but not applied:
`model`, `effort`, `license`, `compatibility`. Large skill files are capped at 25k tokens.

**Load paths (official):**

| Scope | Path |
|---|---|
| Project | `./.grok/skills/` — walked up to the repo root |
| User | `~/.grok/skills/`, `~/.agents/skills/`, `~/.agents/commands/` |
| Plugin | any enabled plugin's `skills/` |
| Extra | `[skills] paths` in `~/.grok/config.toml` |
| **Compat** | `~/.claude/skills/` (via `[compat.claude] skills = true`, default on) |

User-invocable skills appear as `/<skill-name>`; collisions use `/local:commit` form. `/skillify`
captures a session as a new skill. `/skills` opens the extensions modal.

**Agent Skills standard:** de facto compatible (same `SKILL.md` + `name`/`description`, reads
`~/.agents/skills/`), but xAI/Grok is **absent** from the agentskills.io Client Showcase and xAI docs
never cite the standard. Treat any spec-conformant skill as installable; treat `when-to-use` as the
marker of Grok-specific authoring.

## 2. Plugin — `.grok-plugin/plugin.json` (or Claude/Cursor manifests)

```
<plugin>/
├── .grok-plugin/plugin.json   # native manifest (optional — "adds metadata or overrides component paths")
├── .claude-plugin/plugin.json # also accepted "for Claude-ecosystem plugins"
├── skills/<name>/SKILL.md
├── commands/  agents/
├── hooks/hooks.json
├── .mcp.json                  # requires the {"mcpServers": {…}} wrapper
├── .lsp.json
```

A plugin bundles "additional skills, agents, hooks, MCP servers, and LSP servers." The
`.grok-plugin/plugin.json` **field schema is not published**; only its existence and that
`grok plugin validate .` checks it are confirmed. Third parties note it has no `interface.displayName`
(unlike Codex) and that Grok's marketplace schema has no `metadata.version` (unlike Claude's).

**Load paths:** `./.grok/plugins/`, `~/.grok/plugins/`, marketplace installs under
`~/.grok/plugins/marketplaces/`, `[plugins] paths` in config, `--plugin-dir <PATH>`. Env:
`GROK_PLUGIN_ROOT`, `GROK_PLUGIN_DATA`. Project `.grok/config.toml` may set `[plugins] enabled`
("project plugins may default off").

**CLI (official reference):** `grok plugin list|install|uninstall|update|enable|disable|details|validate`
and `grok plugin marketplace list|add|remove|update`. Install argument shapes (combined evidence):
catalog name (`superpowers`), `name@marketplace` (`browser-use@browser-use`), GitHub `owner/repo`
shorthand (verified against the real CLI by third parties), local path. `--trust` appears in the
launch announcement and third-party docs but **not** on the CLI reference page; it grants folder
trust (hooks, MCP, LSP) per the hooks docs. TUI: `/plugins` (alias `/plugin`), `/marketplace` then
`i` to install, `/hooks-trust`, `/import-claude`. `grok inspect [--json]` shows everything discovered.

## 3. Marketplace — `.grok-plugin/marketplace.json`

**Official catalog:** `github.com/xai-org/plugin-marketplace` — `.grok-plugin/marketplace.json` is
"the source of truth"; `.grok-plugin/plugin-index.json` is a generated component catalog listing each
plugin's skills/commands/agents/MCP/hooks/LSP ("never hand-edit"; regenerate with
`python3 scripts/generate-plugin-index.py`; validate with `scripts/validate-catalog.py`).

**Schema:** `{ "name", "description", "owner": { "name" }, "plugins": [] }`. Per plugin: `name`
(required, kebab), `source` (required), `description`, `category` (`development`, `database`,
`deployment`, `productivity`, `observability`, `monitoring`, `security`, `media`), `homepage`,
`keywords` ("terms that suggest this plugin for a request"), `domains` ("hosts/URLs that suggest
this plugin when pasted"), `version`, `author`, `tags`. Remote: `{"source": "url", "url": "…git",
"sha": "<40-hex>"}` — **every remote source must pin a full SHA; Grok re-verifies
`git rev-parse HEAD == sha` after cloning.** Local: `{"type": "local", "path": "./plugins/x"}`.

Contents on 2026-10-24: `name: xai-official`, 36 plugins (32 remote, 4 local under
`external_plugins/`), e.g. vercel, sentry, chrome-devtools, cloudflare, superpowers, mongodb,
stripe, supabase, figma, firecrawl, exa, tavily, browser-use, datadog, unity, clerk, railway,
netlify, neon, calcom. Layout: `plugins/` = xAI first-party; `external_plugins/` = third-party.
Submission by PR with CI + code-owner review; xAI's review criteria include source legitimacy
(official org vs personal account) and security red flags.

**Compat marketplaces:** Grok reads `.claude-plugin/marketplace.json` "with zero configuration".
The catalog's own index generator looks up manifests in order **grok → cursor → claude**. Empirically,
official catalog entries `obra/superpowers` and `cloudflare/skills` ship **only** `.claude-plugin/`
manifests. Sources: `[[marketplace.sources]]` in `~/.grok/config.toml` and
`~/.grok/plugins/known_marketplaces.json`.

## 4. Skill Pack — a repo of skills with no manifest

A `skills/<name>/SKILL.md` tree installable via `npx skills add <owner>/<repo>` (targets `grok` →
`.grok/skills/`; also writes `.agents/skills/` which Grok reads at user scope). Example:
`Wangnov/grok-skills` ("installs to `.agents/skills/grok` and symlinks into each detected agent").

## Not skills — classify correctly

| Artifact | Treatment |
|---|---|
| `AGENTS.md`, `Agents.md`, `AGENT.md`, `CLAUDE.md`, `Claude.md`, `CLAUDE.local.md` | Instruction files Grok reads root→CWD (deeper wins; `.gitignore`-matched skipped). **No `GROK.md` exists.** Readiness signal. |
| `.grok/rules/*.md`, `.claude/rules/`, `.cursor/rules/` | Rules, not skills. |
| `.grokignore` | Grok-specific ignore file. Readiness signal. |
| `[mcp_servers.<name>]` in `.grok/config.toml` / `~/.grok/config.toml`, `~/.claude.json`, `.cursor/mcp.json`, `.mcp.json` | MCP configuration. An MCP-only plugin with no authored skill is **Partial** coverage — note that most vendor catalog entries are exactly this. |
| `*-grok-plugin-cc`, `grok-build-plugin-cc`, `grok-plugin-claude-code` | **Claude Code** plugins that delegate to the Grok CLI. Not Grok skills. |
| `grok2api`, `codeg`, `grokbuild-proxy`, `Grok-UI`, `grok-keysmith` | Proxies, gateways, GUIs tagged `grok-build`. Infrastructure. |
| Logstash / fluentd / Elastic `grok` parsers | Namespace collision. Exclude. |
| Consumer Grok Skills, Grok Bot skills/routines | Different products. Out of scope. |

## Install forms the catalog may record

| Form | When |
|---|---|
| `grok plugin install <name> --trust` | Official catalog entry |
| `grok plugin install <owner>/<repo> --trust` | Any GitHub repo with a readable manifest (native or Claude/Cursor) |
| `grok plugin marketplace add <repo\|path>` → `grok plugin install <name>@<marketplace>` | Self-hosted or third-party marketplace |
| `npx skills add <owner>/<repo> [--skill <name>] [-a grok]` | Standalone skills |
| Manual copy into `.grok/skills/` or `~/.agents/skills/` | Fallback |

## What ports cleanly

Any Claude Code plugin, marketplace, or skill works with zero configuration — Grok reads
`.claude-plugin/*`, `~/.claude/skills/`, `.claude/settings.json` hooks, `~/.claude.json` MCP, and
`CLAUDE.md`. Cursor equivalents likewise (`.cursor-plugin/`, `.cursor/rules/`, `.cursor/mcp.json`,
`.cursor/hooks.json`). What does **not** port silently: a Claude `.mcp.json` lacking the
`{"mcpServers": {…}}` wrapper; `commands/` are mapped into Grok's skill/slash system (works, but
differently); Codex `agents/openai.yaml` is ignored. Grok-tuned forks add `when-to-use`. Classify
compat-only finds as **Portable** and name the adjustment, if any.
