# Compatibility Matrix — agent ids, native paths, manifests, install commands

Use the **agent id** column as the value for the `agents` argument and as the key in every
`Compat: <id>` column. For each requested agent, compatibility evidence is scored 1–4 per
`references/verification.md`; the **Native project path** and **Manifest** columns are what you
test mechanically for level 3.

Verified against each agent's own docs as of 2026-10-24 unless marked. `.agents/skills/` is the
convergent neutral project path; `~/.agents/skills/` the neutral user path. Where an agent reads
another agent's directories, that is listed under **Also reads** — it makes the other agent's
skills *Portable*, not native. Record drift in the Run Log.

## Major ecosystems

| Agent id | Product | Native project path | Native user path | Also reads | Plugin / extension manifest | Marketplace | Install |
|---|---|---|---|---|---|---|---|
| `claude-code` | Claude Code (Anthropic) | `.claude/skills/<n>/` (and nested `<subdir>/.claude/skills/`) | `~/.claude/skills/<n>/` | plugin `skills/` | `.claude-plugin/plugin.json` | `.claude-plugin/marketplace.json`; official `anthropics/claude-plugins-official`, community `anthropics/claude-plugins-community` | `/plugin marketplace add <owner>/<repo>` · `/plugin install <name>@<marketplace>` |
| `codex` | OpenAI Codex / ChatGPT | `.agents/skills/` (CWD → repo root) | `~/.agents/skills/`; admin `/etc/codex/skills`; legacy `~/.codex/skills` | `.claude-plugin/marketplace.json` (legacy-compatible) | `plugin.json` (agent-plugins.org) + `.codex-plugin/plugin.json`; side-file `agents/openai.yaml` | `.agents/plugins/marketplace.json`; `openai/plugins` | `$skill-installer <name\|path\|url>` · `codex plugin marketplace add <owner>/<repo>` → `/plugins` |
| `antigravity` | Google Antigravity (App, IDE, `agy` CLI) | `.agents/skills/<n>/` | App/IDE `~/.gemini/config/skills/`; CLI `~/.gemini/antigravity-cli/skills/`; legacy `~/.gemini/antigravity/skills/` | `~/.agents/skills` (App only, **not CLI**); Gemini extensions via import | `plugin.json` (`antigravity.google/schemas/v1`) | `antigravity-plugins-official` (no public repo) | `agy plugin install <name>@antigravity-plugins-official` · `agy plugin install <github-url>` · `agy plugin import gemini` |
| `gemini-cli` | Google Gemini CLI (paid/enterprise since 2026-06-18) | `.gemini/skills/` or alias `.agents/skills/` | `~/.gemini/skills/` or alias `~/.agents/skills/` | extension `skills/` | `gemini-extension.json` | Gallery `geminicli.com/extensions/browse/` (topic `gemini-cli-extension`) | `gemini skills install <git-url> --consent` · `gemini extensions install <source>` |
| `github-copilot` | GitHub Copilot (cloud agent, CLI, code review, VS Code, VS, JetBrains) | `.github/skills/`, `.claude/skills/`, `.agents/skills/` | `~/.copilot/skills/`, `~/.agents/skills/` (VS Code also `~/.claude/skills/`) | `.claude/agents/`, `.claude/rules/`, `CLAUDE.md`, `AGENTS.md`; `.claude-plugin/marketplace.json` | `plugin.json` (agent-plugins.org, `com.github.copilot/` ns); agents `.github/agents/*.agent.md` | `.github/plugin/marketplace.json`; built-in `awesome-copilot`; `github/copilot-plugins` | `gh skill install <owner>/<repo> <skill>` · `copilot plugin install <name>@<marketplace>` · `copilot skill add <url>` |
| `grok` | xAI Grok Build (`grok` CLI) | `.grok/skills/` (→ repo root) | `~/.grok/skills/`, `~/.agents/skills/`, `~/.agents/commands/` | `~/.claude/skills/`, `.claude-plugin/*`, `.cursor-plugin/*`, `~/.claude.json`, `.mcp.json`, `.claude/settings.json`, `CLAUDE.md` | `.grok-plugin/plugin.json` (schema unpublished) | `.grok-plugin/marketplace.json`; official `xai-org/plugin-marketplace` (36, SHA-pinned) | `grok plugin install <name\|owner/repo> --trust` · `grok plugin marketplace add <repo>` |
| `ms365-copilot` | Microsoft 365 Copilot (skills binding only) | `appPackage/skills/<n>/` referenced by `agentSkills[]` / `agent_skills[]` | — (tenant-deployed) | Claude/Cursor/Agent-Plugins sources via `wiqd plugin import`, `atk import openplugin` | `manifest.json` + `declarativeAgent.json` v1.9 | Agent Store (tenant), AppSource | `atk add skill --from <path>` · `wiqd plugin add skill` · `atk install --file-path <zip>` |

## Other agents with documented SKILL.md support

| Agent id | Product | Native project path | Native user path | Also reads | Notes |
|---|---|---|---|---|---|
| `cursor` | Cursor | `.agents/skills/`, `.cursor/skills/` | `~/.cursor/skills/` | `.claude/skills/`, `.codex/skills/`, `~/.claude/skills/`, `~/.codex/skills/` | Rules `.cursor/rules/*.mdc`; "Apply Intelligently" rules migrate to skills; `.cursor-plugin/` manifests |
| `windsurf` | Windsurf / Devin Desktop (Cognition) | `.agents/skills/`, `.windsurf/skills/` | `~/.agents/skills/`; enterprise `/etc/devin/skills/` etc. | `.claude/skills/` when enabled | Rules (`always_on`/`glob`/`model_decision`/`manual`) and Workflows are separate formats |
| `devin` | Devin (cloud) | `.agents/skills/` (recommended), `.devin/skills/`, `.github/skills/`, `.claude/skills/`, `.cognition/skills/`, `.windsurf/skills/` | — | — | Reads `triggers`, `argument-hint`; `AGENTS.md` capped 16 KiB/file; Playbooks are separate |
| `opencode` | OpenCode | `.opencode/skills/`, `.claude/skills/`, `.agents/skills/` | `~/.config/opencode/skills/`, `~/.claude/skills/`, `~/.agents/skills/` | — | `permission.skill` allow/deny/ask in `opencode.json` |
| `amp` | Amp (Sourcegraph) | `.agents/skills/` (and parents), `.claude/skills/` | `~/.config/agents/skills/`, `~/.agents/skills/`, `~/.config/amp/skills/`, `~/.claude/skills/`, `~/.claude/plugins/cache/` | — | `amp skill add <source>`; recursive to 5 levels |
| `kiro` | Kiro (AWS) | `.kiro/skills/` | `~/.kiro/skills/` | — | Custom agents need `skill://.kiro/skills/**/SKILL.md` in `.kiro/agents/<a>.json`; Steering and Powers are separate |
| `cline` | Cline | `.cline/skills/` (recommended), `.clinerules/skills/`, `.claude/skills/` | `~/.cline/skills/` | — | `.clinerules/` rules always active |
| `roo` | Roo Code | `.roo/skills/`, `.agents/skills/`; mode-specific `skills-<mode>/` | `~/.roo/skills/`, `~/.agents/skills/` | — | — |
| `goose` | Goose (Block) | `.agents/skills/`; back-compat `.goose/skills/`, `.claude/skills/` | `~/.agents/skills/`, `~/.claude/skills/` | — | Requires Summon extension, v1.25.0+. (`skills` CLI table still says `.goose/skills/` — discrepancy) |
| `zed` | Zed | `<worktree>/.agents/skills/` **only** | `~/.agents/skills/` only | — | "No remote registry"; rules library replaced by Skills in v1.4.0 |
| `droid` | Factory Droid | `.factory/skills/`, `.agents/skills/`, `.agent/skills/` | `~/.factory/skills/`, `~/.agents/skills/`, `~/.agent/skills/` | plugin `skills/` | `droid plugin marketplace add <url>` |
| `vibe` | Mistral Vibe | `.agents/skills/` (trusted), `.vibe/skills/` | `~/.vibe/skills/`, `~/.agents/skills/` | — | `skill_paths` in `config.toml` |
| `qwen` | Qwen Code | `.qwen/skills/` | `~/.qwen/skills/` | — | Frontmatter `paths:`, `hooks:`; `/learn` auto-skills |
| `kimi` | Kimi Code CLI (Moonshot) | brand dirs merged (`kimi > claude > codex`) + generic | — | all brand dirs | `.kimi-plugin/plugin.json`; flat `.md` skills accepted; exact native paths not captured |
| `hermes-agent` | Hermes Agent (Nous) | project-local | `~/.hermes/skills/<category>/<skill>/`, `~/.agents/skills/` | — | Skills Hub with `.hub/lock.json`; `metadata.hermes.*` |
| `openclaw` | OpenClaw | `<workspace>/skills`, `.agents/skills` | `~/.agents/skills`, `~/.openclaw/skills` | plugin `openclaw.plugin.json` | ClawHub `openclaw skills install`; `.clawhub/lock.json` |
| `trae` | TRAE (ByteDance) | `.trae/skills/`; `.agents/skills/` (opt-in setting) | `~/.trae/skills` | — | Built-in marketplace |
| `continue` | Continue | `.continue/skills/` (per `skills` CLI) | `~/.continue/skills/` | — | **Official docs not located** — treat as unverified |

## Listed adopters without a verified path table

Also on the agentskills.io Client Showcase (46 entries as of 2026-10-23; opt-in by PR, so absence
is not evidence of non-support): Emdash, Junie (JetBrains), Autohand Code CLI, OpenHands, Ona,
VS Code, Firebender, Vita, Mux (Coder), Letta, Claude (claude.ai), pi, ZeroClaw, bub, Google AI
Edge Gallery, Tabnine, Laravel Boost, Superconductor, fast-agent, Deep Code, Spring AI, VT Code,
nanobot, Workshop, Agentman, Command Code, Pulumi Neo, Piebald, Snowflake Cortex Code, Databricks
Genie Code, Qodo. Use the showcase's per-client "Setup instructions" link as the doc to fetch when
one of these is requested. **Not on the showcase despite documented support:** Antigravity, Grok
Build, Windsurf/Devin Desktop, Devin, Cline, Zed, Kimi, Qwen, Continue.

## The cross-agent installer

`npx skills add <owner>/<repo> [--skill <name>] [-a <agent-id>] [-g] [--copy] [-y] [--all]`
(Vercel Labs, MIT, Node ≥22.20; 79 agent targets) auto-detects installed agents, writes
`.agents/skills/`, and symlinks into each agent's directory. Its `docs/agents.md` is the most
complete enumeration of per-agent paths; its `docs/creating-skills.md` lists ~60 vendor skill
directories it scans (`skills/`, `skills/.curated/`, `.agents/skills/`, `.claude/skills/`,
`.grok/skills/`, `.kiro/skills/`, `.roo/skills/`, `.windsurf/skills/`, `.trae/skills/`, …) plus
`.claude-plugin/*.json` manifest discovery. Other commands: `find`, `list`, `use <source>@<skill>`,
`check`, `update`, `remove`, `init`, `experimental_sync` (npm-shipped skills → `skills-lock.json`).

## Reading this matrix during a run

1. For each requested agent id, test the candidate's layout against **Native project path** /
   **Native user path** → level 3 if it matches, level 2 if it also uses that agent's frontmatter or
   manifest, level 1 if it is in that agent's official registry.
2. If the candidate matches only an **Also reads** path for an agent → level 3 but flag as Portable
   in the gap analysis for that agent.
3. If the only evidence is an aggregator tag or README claim → level 4; never emit an install line.
4. Emit install lines only from the **Install** column for agents at level ≤3.
