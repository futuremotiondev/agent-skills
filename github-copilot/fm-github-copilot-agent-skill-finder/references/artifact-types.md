# What counts as a GitHub Copilot customization

**First, the product boundary.** GitHub Copilot is the developer product — Copilot cloud/coding
agent, Copilot CLI, Copilot code review, the GitHub Copilot app, and Copilot in VS Code, Visual
Studio, JetBrains, Eclipse, Xcode. Its customizations are files in `.github/` (repo), `~/.copilot/`
(personal), or an org's `.github` / `.github-private` repo. **Microsoft 365 Copilot is a different
product** (declarative agents, Copilot Studio, Agent Store) with a different finder; nothing from
`learn.microsoft.com/microsoft-365/copilot/*` is cataloged here.

GitHub uses **"customization"** as the umbrella term. Six types qualify. Facts verified against
GitHub Docs and VS Code docs as of 2026-10-24; this surface reorganized several times in 2025–2026,
so record drift in the Run Log.

## Support matrix (from GitHub's customization cheat sheet)

| Type | Path | Trigger | VS Code | VS | JetBrains | Eclipse | Xcode | GitHub.com | CLI |
|---|---|---|---|---|---|---|---|---|---|
| Repository instructions | `.github/copilot-instructions.md` | automatic | ✓ | ✓ | P | P | P | ✓ | ✓ |
| Path-specific instructions | `.github/instructions/**/*.instructions.md` | by `applyTo` glob | ✓ | ✓ | ✓ | P | ✓ | ✓ | ✓ |
| Prompt files | `.github/prompts/*.prompt.md` | manual `/name` | ✓ | ✓ | P | ✗ | P | ✗ | ✗ |
| Custom agents | `.github/agents/*.agent.md` | selected / assigned | ✓ | ✓ | P | P | P | ✓ | ✓ |
| Agent skills | `.github/skills/*/SKILL.md` | automatic when relevant | ✓ | ✓ | P | ✗ | ✗ | ✓ | ✓ |
| Hooks | `.github/hooks/*.json` | lifecycle events | P | ✗ | ✗ | ✗ | ✗ | ✓ | ✓ |

P = preview. Record the surfaces a customization actually works on in the `Surfaces` column.

## 1. Agent Skill — `SKILL.md`

Copilot implements the open **Agent Skills** standard ("an open standard … used by a range of
different AI systems"; `gh skill publish --dry-run` validates against `agentskills.io/specification`).
Shipped 2025-12-18 (coding agent, CLI, VS Code Insiders), stable VS Code early January 2026.

```
<skill-name>/
├── SKILL.md       # required — frontmatter: name, description; optional license, allowed-tools
├── scripts/  references/  assets/
```

**Frontmatter:** `name` (lowercase-hyphen, matches directory), `description` (required), `license`,
`allowed-tools` (e.g. `shell` — GitHub warns not to pre-approve `shell`/`bash` in unreviewed skills).
VS Code adds `argument-hint`, `user-invocable` (default true), `disable-model-invocation` (default
false), `context` (experimental; `fork`). Skills surface as slash commands (`/webapp-testing`).

**Load paths:**

| Scope | Paths |
|---|---|
| Project | `.github/skills/`, `.claude/skills/`, `.agents/skills/` |
| Personal | `~/.copilot/skills/`, `~/.agents/skills/` (VS Code also `~/.claude/skills/`) |
| Plugin | `skills/<name>/SKILL.md` inside an installed plugin |

`.github/skills/` is the strongest signal of Copilot intent. Use a review-focused directory name
(e.g. `code-review`) to ensure Copilot code review reads a skill.

**Install:** `gh skill search <q>` · `gh skill preview <owner>/<repo> <skill>` · `gh skill install
<owner>/<repo> <skill> [@TAG|@SHA] [--pin] [--agent] [--scope]` · `gh skill update --all` · `gh skill
publish [--dry-run] [--fix]` (GitHub CLI ≥ 2.90.0, public preview). `install` writes provenance
(source repo, ref, tree SHA) into the frontmatter. CLI: `copilot skill list|add <FILE|URL|DIR>|
disable|enable`; in-session `/skills list|info|add|reload|remove`. VS Code settings:
`chat.agentSkillsLocations`, `github.copilot.chat.skillTool.enabled`.

## 2. Custom agent — `*.agent.md`

Replaced VS Code "custom chat modes" (`.chatmode.md` → rename to `.agent.md`;
`chat.modeFilesLocations` deprecated).

**Locations:** repo `.github/agents/<name>.agent.md` or `.md`; user `~/.copilot/agents/`; org
`/agents/<name>.md` in the org's `.github` or `.github-private` repo; enterprise `.github-private`.
VS Code also reads `.claude/agents/*.md` and `~/.claude/agents/`. Precedence repo > org > enterprise.

**Frontmatter (GitHub reference):** `name` (optional), `description` (**required**), `target`
(`vscode` | `github-copilot`), `tools` (list or comma string; `["*"]` all; MCP tools as
`server/tool` or `server/*`), `model`, `disable-model-invocation`, `user-invocable`, `mcp-servers`
(cloud agent only), `metadata`; `infer` retired. Body ≤ 30,000 chars. VS Code adds `argument-hint`,
`agents`, `reasoning-effort`, `handoffs`, `hooks`. Tool aliases: `execute` (shell/Bash/powershell),
`read`, `edit`, `search`, `agent`, `web`, `todo`.

## 3. Instructions

- **Repository:** `.github/copilot-instructions.md` — no frontmatter, always applied. Personal:
  `~/.copilot/copilot-instructions.md`.
- **Path-specific:** `.github/instructions/**/*.instructions.md` with frontmatter `applyTo` (glob;
  `**` = all), `name`, `description`. Personal: `~/.copilot/instructions/**/*.instructions.md`.
- **Agent files:** `AGENTS.md` (nested files along the path; `chat.useNestedAgentsMdFiles`),
  `CLAUDE.md` (root, `.claude/CLAUDE.md`, `~/.claude/CLAUDE.md`, `CLAUDE.local.md`), `GEMINI.md`,
  `REVIEW.md` (code review). Copilot *reads* these; catalog them as readiness signals, not as
  ranked customizations, unless the topic is "instructions".
- **`.claude/rules/*.md`** with `paths` frontmatter — read by VS Code as instructions.

"Custom instructions are not taken into account for inline suggestions."

## 4. Prompt file — `*.prompt.md`

`.github/prompts/*.prompt.md` (VS Code-centric; not on GitHub.com or CLI). Frontmatter (all
optional): `description`, `name`, `argument-hint`, `agent` (`ask`|`agent`|`plan`|custom), `model`,
`tools`. The older `mode` key is gone. Variables `${selection}`, `${input:name}`; references
`#file:`, `#tool:`. VS Code documents a migration path "convert prompt files to skills".

## 5. Hook — `.github/hooks/*.json`

Lifecycle-event commands. Supported on GitHub.com cloud agent and CLI; VS Code preview. Personal
hooks in `~/.copilot/hooks/`. Always flag `hooks`.

## 6. Plugin and marketplace

**Plugin** = installable package of agents (`agents/*.agent.md`), skills (`skills/*/SKILL.md`),
hooks (`hooks.json`), MCP config, LSP config (`lsp.json`). Manifest `plugin.json` at root using the
open **Agent Plugins** schema (`$schema` = `https://agent-plugins.org/schemas/1.0.0/plugin.schema.json`
or `1.1.0`; required `name` 1–64 lowercase alnum/hyphen/period; optional `version`, `description`,
`author`, `homepage`, `repository`, `license`, `keywords`, `extensions{}`). Copilot-specific pieces
live under `com.github.copilot/` (`agents/`, `commands/`, `rules/`, `hooks/hooks.json`, `lsp.json`).
A legacy Copilot plugin format (no `$schema`, `name` kebab ≤64, `description` ≤1024) is also read.
MCP transports `stdio`, `streamable-http`, `sse`; env `PLUGIN_ROOT`, `PLUGIN_DATA`.

**Marketplace** = `marketplace.json` in `.github/plugin/` — **or `.claude-plugin/`**, which Copilot
CLI also reads. Fields: `name`, `owner{name,email}`, `metadata{description,version}`, `plugins[]`
(`name`, `description`, `version`, `source`). GitHub's own docs show `copilot plugin marketplace add
anthropics/claude-code`, and `github/copilot-plugins` symlinks `.claude-plugin/marketplace.json` →
`.github/plugin/marketplace.json`. **Every Claude Code marketplace is therefore addable to Copilot
CLI**; Claude-only components are ignored rather than failing. Catalog as **Portable** unless it
also shows Copilot intent.

**Default marketplaces:** `awesome-copilot` (built in, "cannot be removed", auto-updates in trusted
dirs). `copilot-plugins` — GitHub Docs pages disagree on whether it is still default; treat it as
needing `copilot plugin marketplace add github/copilot-plugins`.

**CLI:** `copilot plugin install SPEC` (`plugin@marketplace`, `OWNER/REPO`, `OWNER/REPO:PATH`, git
URL, local path) · `uninstall` · `list [--json]` · `update NAME|--all` · `enable|disable` ·
`copilot plugin marketplace add|list|browse NAME|update|remove`. Slash: `/plugin` (Marketplace and
Installed views). Installed to `~/.copilot/installed-plugins/{marketplace}/{plugin}/` or
`_direct/`. MCP servers are **not** installed by `plugin install` — use `/mcp` or `copilot mcp add`.
VS Code: Extensions view `@agentPlugins`, "Chat: Install Plugin From Source", `chat.plugins.marketplaces`.
Cloud agent: `enabledPlugins` and `extraKnownMarketplaces` in `.github/copilot/settings.json`.

## Not customizations — classify correctly

| Artifact | Treatment |
|---|---|
| Declarative agent, Copilot Studio agent, Agent Store listing, `declarativeAgent.json` | **Microsoft 365 Copilot.** Exclude. |
| GitHub Marketplace "Copilot Extension" (GitHub App) | Sunset 2025-11-10; replaced by MCP and the GitHub MCP Registry (`github.com/mcp`). Dead. |
| VS Code chat-participant extension | Still supported, but a VS Code extension, not a Copilot customization file. Catalog only if asked. |
| `mcp.json` / `.vscode/mcp.json` / `~/.copilot/mcp-config.json` / repo MCP settings | MCP configuration. An MCP-only plugin with no authored skill or agent is **Partial** coverage. |
| `~/.copilot/extensions/`, `awesome-copilot/extensions/` | CLI/app extensions, unrelated to the sunset Marketplace Extensions. |
| `.github/copilot/settings.json` | Project settings (`enabledPlugins`, `extraKnownMarketplaces`), not a customization. |

## What ports cleanly

Any valid Agent Skills `SKILL.md` loads in Copilot from `.claude/skills/` or `.agents/skills/` with
no change — Claude-Code-first repos are largely Copilot-compatible as-is. Claude Code plugin
marketplaces are addable directly. What does **not** port: Claude `/plugin:skill` namespacing;
Codex `agents/openai.yaml`; Antigravity `plugin.json` (different schema); Microsoft 365 declarative
agents (different product). Classify such finds as **Portable** and name the one adjustment needed.
