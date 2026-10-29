# What counts as a Codex skill

Codex implements the open **Agent Skills** standard (agentskills.io) and layers a **plugin** packaging
format on top. Four artifact shapes qualify for the catalog. Anything else is context, not a skill.

Facts here were verified against OpenAI docs as of 2026-10-24. Note that `developers.openai.com/codex/*`
doc URLs 302-redirect to `learn.chatgpt.com/docs/*`; plugin docs stay on `developers.openai.com`.
Appending `.md` to either returns raw Markdown. Record any drift in the Run Log.

## 1. Skill — `SKILL.md`

```
<skill-name>/
├── SKILL.md              # required — YAML frontmatter: name, description
├── agents/openai.yaml    # optional, Codex-specific
├── scripts/  references/  assets/
```

**Frontmatter:** `name` (≤64 chars, lowercase/digits/hyphens, matches the directory) and `description`
(≤1024 chars, drives implicit matching) are required. Optional per the open spec: `license`,
`compatibility`, `metadata`, `allowed-tools`.

**`agents/openai.yaml`** is the Codex-specific marker. Fields: `interface` (`display_name`,
`short_description`, `icon_small`, `icon_large`, `brand_color`, `default_prompt`), `policy`
(`allow_implicit_invocation`, default `true`), `dependencies.tools` (entries with `type`, `value`,
`description`, `transport`, `url` — typically an MCP server). Its presence means the author
targeted Codex deliberately.

**Where Codex loads skills from (official):**

| Scope | Path |
|---|---|
| Repo | `$CWD/.agents/skills`, `$CWD/../.agents/skills`, `$REPO_ROOT/.agents/skills` — scanned from CWD up to repo root, symlinks followed |
| User | `$HOME/.agents/skills` |
| Admin | `/etc/codex/skills` |
| System | bundled with Codex (`skill-installer`, `skill-creator`, `plugin-creator`, `openai-docs`, `imagegen`) |
| Plugin | `skills/<name>/SKILL.md` inside an installed plugin |
| **Legacy** | `$CODEX_HOME/skills` → `~/.codex/skills` — still referenced by `openai/skills` README and `$skill-installer`; not in current official load-path docs. Scan both. |

Same-name skills are not merged; both appear in selectors. Invocation: `/skills` or `$skill-name`.
Config: `[[skills.config]]` with `path`/`enabled` and `skills.max_context_tokens` in `~/.codex/config.toml`.

## 2. Plugin — `plugin.json` / `.codex-plugin/plugin.json`

```
<plugin>/
├── plugin.json               # portable manifest — canonical entry point
├── .codex-plugin/plugin.json # optional overlay; applies only when extensions["com.openai"] is absent from root
├── mcp.json  (.mcp.json)     # bundled MCP servers
├── skills/<name>/SKILL.md
├── hooks/hooks.json
├── .app.json  assets/
```

**`plugin.json`:** `$schema` = `https://agent-plugins.org/schemas/1.0.0/plugin.schema.json`, `name`
(kebab-case), `version`, `description`; optional `author`, `homepage`, `repository`, `license`,
`keywords`. OpenAI settings under `extensions["com.openai"]`: `apps`, `hooks`, `interface`,
`onboardingSkill`. Skills are discovered from the root `skills/` directory without a manifest field.

**`mcp.json` (portable)** requires a transport `type` per server (e.g. `"streamable-http"`) — a
plugin that just renamed Claude's `.mcp.json` without adding `type` is malformed for the portable
format. Auth per server under `extensions["com.openai"].auth`: `none`, `oauth`, `mixed`, `api_key`.

The manifest shape changed during 2026 (an earlier `components` / `install_policy` form existed).
Accept either `plugin.json` or `.codex-plugin/plugin.json`; do not reject on internal field set.

## 3. Marketplace — `marketplace.json`

| Location | Status |
|---|---|
| `$REPO_ROOT/.agents/plugins/marketplace.json` | Current, repo scope |
| `~/.agents/plugins/marketplace.json` | Current, personal |
| `$REPO_ROOT/.claude-plugin/marketplace.json` | **Legacy-compatible** — Codex reads Claude Code marketplaces directly |

Each `plugins[]` entry: `name`, `source` (types `local`, `url`, `git-subdir` with `ref`/`sha`, `npm`;
`source.path` starts with `./`), `policy` (`installation`: `AVAILABLE` / `INSTALLED_BY_DEFAULT` /
`NOT_AVAILABLE`; `authentication`: `ON_INSTALL` / `ON_FIRST_USE`), `category`.

CLI: `codex plugin marketplace add owner/repo [--ref main]`, `... add <git-url> --sparse .agents/plugins`,
`... add ./local-root`, `list`, `upgrade [name]`, `remove <name>`. **No official `codex plugin install`
subcommand is documented** — installation happens from the ChatGPT desktop Plugins Directory or
`/plugins`. Cache: `~/.codex/plugins/cache/$MARKETPLACE/$PLUGIN/$VERSION/`. Enable per repo in
`.codex/config.toml` with key `plugin-name@marketplace-name`.

**Because `.claude-plugin/marketplace.json` is accepted, every Claude Code marketplace is a Codex
marketplace.** Catalog such entries as **Portable** unless they show Codex-specific intent (§1 marker,
`plugin.json`, or a Codex install snippet).

## 4. Skill Pack — a repo of skills with no manifest

A repo whose `skills/<name>/SKILL.md` tree (or root `SKILL.md`) is installable via
`npx skills add <owner>/<repo>` or `$skill-installer <github-dir-url>`. Vendor skills (Supabase,
Vercel, Firebase) ship this way and almost never name Codex — compatibility is implied by the
`skills` CLI's `codex` target writing to `.agents/skills/`.

## Not skills — classify correctly

| Artifact | Treatment |
|---|---|
| `AGENTS.md` / `AGENTS.override.md` | Always-on project instructions (global `~/.codex/AGENTS.md`, per-directory concatenation root→CWD, 32 KiB cap). Readiness signal only. |
| `.codex/agents/*.toml` | Custom subagent definitions (`name`, `description`, `developer_instructions`, `model`, `sandbox_mode`). Type `Agent` only when the topic asks for agents. |
| `[mcp_servers.<name>]` in `config.toml` | MCP configuration, not a skill. A plugin that is MCP-only with no authored skill is **Partial** coverage at best. |
| ChatGPT custom GPT / Project / Apps SDK app | Different product. Out of scope. |
| `openai/skills` `.experimental/` entries | Real, installable, but prototypes — cap Authority at the community band. |

## Install forms the catalog may record

| Form | When |
|---|---|
| `$skill-installer <name>` | Named curated skill from `openai/skills` |
| `$skill-installer install <path-or-github-dir-url>` | Experimental or third-party skill folder |
| `npx skills add <owner>/<repo> [--skill <name>] [-a codex]` | Any Agent-Skills repo; writes to `.agents/skills/` |
| `codex plugin marketplace add <owner>/<repo>` → `/plugins` | Plugin via marketplace |
| Manual copy into `.agents/skills/` | Fallback; always valid |

## What ports cleanly

Any valid Agent Skills `SKILL.md` written for Claude Code, Copilot, Cursor, or Gemini loads in Codex
once placed under `.agents/skills/`. What does **not** port: Claude-specific `allowed-tools` grammar
(`Bash(git:*)`) is accepted by the spec but Codex policy is governed by `agents/openai.yaml`;
Claude `/plugin-name:skill` namespacing; hooks keyed to Claude event names. Classify such finds as
**Portable** and name the one thing that needs adjusting.
