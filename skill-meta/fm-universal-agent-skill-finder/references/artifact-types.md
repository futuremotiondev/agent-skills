# What counts as a skill — across agents

One format underlies almost everything: the open **Agent Skills** standard (agentskills.io). A skill
is a directory with a `SKILL.md` whose YAML frontmatter has `name` (≤64 chars, lowercase/digits/
hyphens, matches the directory) and `description` (≤1024 chars); optional `license`, `compatibility`
(≤500 chars free text, "most skills do not need" it), `metadata` (string map — the sanctioned
extension point), `allowed-tools` (experimental). Conventional subdirectories `scripts/`,
`references/`, `assets/`. Validate with `npx skills-ref validate ./my-skill`. The spec page carries
**no version number** — record the fetch date, not a version.

Around that shared core, each agent adds a **load layout**, a **plugin/extension manifest**, and
**vendor frontmatter**. Those three things are what compatibility evidence is made of.
`references/compatibility-matrix.md` has the per-agent table; this file explains the shapes.

## 1. Skill — `SKILL.md`

Qualifies anywhere. Where it sits determines *who* reads it:

| Layout | Who reads it (documented) | Signal |
|---|---|---|
| `.agents/skills/<name>/` | Codex, Cursor, GitHub Copilot, VS Code, Gemini CLI (alias), Antigravity, Zed, Amp, Goose, Roo, OpenCode, Devin, Windsurf/Devin Desktop, Factory, Mistral Vibe, Hermes, OpenClaw, TRAE (opt-in), Grok (user scope) | **The convergent neutral path.** Format-compatible with nearly everyone; intent-neutral |
| `skills/<name>/` at repo root | `npx skills add`, Claude plugins, Codex plugins, most plugin formats | Pack layout; intent-neutral |
| Root `SKILL.md` | Claude plugins, `skills` CLI, OpenClaw git installs | Single-skill repo |
| Vendor dot-dir (`.claude/skills/`, `.github/skills/`, `.grok/skills/`, `.cursor/skills/`, `.gemini/skills/`, `.kiro/skills/`, `.roo/skills/`, …) | That agent natively; several others via compat (Copilot, Cursor, Grok, OpenCode, Amp, Goose, Cline all read `.claude/skills/`) | **Intent signal for that agent** |
| Inside a plugin's `skills/` | The agent that installed the plugin | Depends on the manifest |

**Vendor frontmatter you will encounter** (ignored by agents that don't know it): VS Code/Copilot
`argument-hint`, `user-invocable`, `disable-model-invocation`, `context`; Codex side-file
`agents/openai.yaml` (`interface`, `policy`, `dependencies.tools`); Grok `when-to-use`, `paths`,
`metadata.author`, `metadata.short-description`; Devin `triggers`; Qwen `paths:`, `hooks:`,
`source: auto-skill`; Hermes `metadata.hermes.tags|config`; Cursor/Zed `disable-model-invocation: true`
on migrated rules. Their presence is level-2 evidence of intent for that agent.

## 2. Plugin / extension — per-agent manifests

| Agent | Manifest | Layout notes |
|---|---|---|
| Claude Code | `.claude-plugin/plugin.json`; marketplace `.claude-plugin/marketplace.json` | `skills/`, `commands/`, `agents/`, `hooks/hooks.json`, `.mcp.json`; `/plugin-name:skill` namespacing. **Read natively by Codex (legacy-compatible), GitHub Copilot CLI, Grok, Amp, Kimi** |
| Codex / ChatGPT | root `plugin.json` (`$schema` agent-plugins.org 1.0.0) with `extensions["com.openai"]`; `.codex-plugin/plugin.json` overlay; marketplace `.agents/plugins/marketplace.json` | `skills/`, `mcp.json` (portable — needs transport `type`), `hooks/hooks.json`, `.app.json` |
| GitHub Copilot | root `plugin.json` (agent-plugins.org 1.0.0/1.1.0) with `com.github.copilot/` namespace; legacy Copilot format; marketplace `.github/plugin/marketplace.json` **or** `.claude-plugin/marketplace.json` | `skills/`, `agents/*.agent.md`, `hooks/hooks.json`, `mcp.json`, `lsp.json` |
| Antigravity | root `plugin.json` (`$schema` `antigravity.google/schemas/v1/plugin.json`, `additionalProperties: false`) | `skills/`, `agents/*.md`, `rules/*.md`, `mcp_config.json` (`serverUrl`), `hooks.json` |
| Gemini CLI | root `gemini-extension.json` | `skills/`, `commands/*.toml`, `agents/`, `hooks/hooks.json`, `GEMINI.md`, `mcpServers`; importable into Antigravity with `agy plugin import gemini` |
| Grok Build | `.grok-plugin/plugin.json` (schema unpublished); marketplace `.grok-plugin/marketplace.json` (SHA-pinned `url` sources) | `skills/`, `commands/`, `agents/`, `hooks/hooks.json`, `.mcp.json` (needs `mcpServers` wrapper), `.lsp.json`; **also reads `.claude-plugin/*` and `.cursor-plugin/*`** |
| Cursor | `.cursor-plugin/plugin.json` / `marketplace.json` | Read by Grok and the xAI catalog generator too |
| Factory Droid | plugin with `${DROID_PLUGIN_ROOT}`; `droid plugin marketplace add` | — |
| Kimi Code CLI | `.kimi-plugin/plugin.json` | Merges `kimi > claude > codex` brand dirs |
| Devin, Hermes, Muse, Antigravity (shim), pi, OpenCode | `.devin-plugin/`, `.hermes-plugin/`, `.muse-plugin/`, `.antigravity-plugin/`, `.pi/extensions/`, `.opencode/` | Seen as shims in `obra/superpowers` |
| OpenClaw | `openclaw.plugin.json` with `skills` dirs; ClawHub `.clawhub/lock.json` | — |
| Microsoft 365 Copilot | `manifest.json` with `agentSkills[]`; declarative agent `agent_skills[]` (v1.9, preview) | Only the skills binding is in scope here; `wiqd plugin import` / `atk import openplugin` convert Claude/Cursor/Agent-Plugins sources |

**The Agent Plugins schema** (`agent-plugins.org`, spec repo `agentplugins/agent-plugins-spec`,
1.0.0 published 2026-08-06; TSC from AWS, Cursor, Microsoft, OpenAI, Vercel; launch clients ChatGPT &
Codex, Cursor, GitHub Copilot, Kiro, VS Code) is the emerging neutral plugin manifest: root
`plugin.json`, `skills/<dir>/SKILL.md`, `mcp.json`, vendor settings under reverse-domain
`extensions{}` namespaces. A repo using it is a strong multi-agent signal.

## 3. Marketplace — catalog files

A `marketplace.json` (Claude, Copilot, Codex `.agents/plugins/`, Grok `.grok-plugin/`, Cursor) or
the Gemini gallery's topic-crawl. **One marketplace manifest fetch resolves dozens of upstreams** —
read these before keyword searching. Cross-reading is widespread: Codex, Copilot CLI, and Grok all
accept `.claude-plugin/marketplace.json`.

## 4. Skill Pack / Collection

A repo of `skills/*/SKILL.md` with no manifest (installable via `npx skills add`), or a large
curated collection. Credibility heuristics: (1) more than one per-agent manifest present, (2) a
machine-readable index (`skills_index.json`, `marketplace.json`, `llms.txt`), (3) provenance files
(`.source.json`), (4) install telemetry on skills.sh. README claims alone are level 4.

## Not skills — classify correctly

| Artifact | Treatment |
|---|---|
| `AGENTS.md` (and `AGENTS.override.md`), `CLAUDE.md`, `GEMINI.md`, `REVIEW.md` | Always-on project instructions; stewarded by the Agentic AI Foundation (Linux Foundation) since 2025-12-09; read by ~two dozen agents; byte caps differ (Codex 32 KiB combined, Devin 16 KiB/file). **Readiness signal, not a skill.** |
| `.cursor/rules/*.mdc`, `.clinerules/`, `.windsurfrules`, `.rules`, `.agents/rules/*.md`, Kiro steering, Antigravity rules | Rules — always-on or glob-triggered. Not skills. Cursor and Zed migrate some rules *into* skills; note that as Adjacent. |
| MCP configs (`mcp.json`, `.mcp.json`, `mcp_config.json`, `~/.claude.json`, `.cursor/mcp.json`, `[mcp_servers.*]` TOML) | MCP, not skills. An MCP-only plugin is **Partial** coverage. The MCP Registry (`registry.modelcontextprotocol.io`) indexes servers, not skills. |
| Devin Playbooks, Goose recipes, Kiro Powers, Windsurf Workflows, Factory custom droids, Copilot prompt files | Agent-specific adjacent formats. Note as Adjacent when relevant to the facet. |
| M365 declarative agents, Copilot Studio agents, Agent Store listings | Different product family — the M365 finder's domain. |
| Consumer grok.com Grok Skills, Grok Bot skills/routines | No file format. Out of scope. |
| GitHub-App Copilot Extensions | Sunset 2025-11-10. |

## What ports, and what doesn't

**Ports with no change:** any spec-conformant `SKILL.md` placed under `.agents/skills/` loads in
every agent that documents that path (the convergent list above); `.claude/skills/` content loads in
Copilot, Cursor, Grok, OpenCode, Amp, Goose, Cline, Windsurf (when enabled). Claude marketplaces are
addable to Codex, Copilot CLI, and Grok.

**Ports with one step:** Gemini extension → Antigravity (`agy plugin import gemini`); Claude/Cursor
plugin → M365 package (`wiqd plugin import`); Agent Plugins layout → M365 (move `plugin.json` to
`.plugin/`, rename `mcp.json` → `.mcp.json`); Claude `.mcp.json` → Grok (add `mcpServers` wrapper if
missing); Copilot `.chatmode.md` → `.agent.md` (rename).

**Does not port:** vendor frontmatter semantics (`when-to-use`, `agents/openai.yaml`, `triggers`) —
silently ignored elsewhere; Claude `/plugin:skill` namespacing; agent-specific hook event names;
Antigravity `plugin.json` vs agent-plugins.org `plugin.json` (same filename, incompatible schemas,
`additionalProperties: false` on Antigravity's); Copilot custom agents (`.agent.md`) and M365
declarative agents (different formats entirely).

Classify every ported find as **Portable** in the gap analysis, name the agents it is native to, and
name the one step for each agent it is not.
