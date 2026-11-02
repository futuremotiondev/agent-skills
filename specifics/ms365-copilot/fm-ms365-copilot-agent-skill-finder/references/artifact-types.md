# What counts as a Microsoft 365 Copilot extension

**First, the product boundary.** Microsoft 365 Copilot is the work/enterprise Copilot in Teams, Word,
Excel, Outlook, and the Microsoft 365 Copilot app, extended through app packages built with Copilot
Studio, the Microsoft 365 Agents Toolkit, or Work IQ Dev Tools. **GitHub Copilot is a different
product** with a different finder; its artifacts (`.github/skills/`, `copilot-instructions.md`,
`.agent.md`) are never cataloged here. Copilot Studio further muddies this by calling one of its
runtimes the "GitHub Copilot harness" — that is a runtime name, not the GitHub product.

There is **no single SKILL.md-style unit**. The deployable artifact is an **app package** (`.zip`
with `manifest.json` — the Teams unified app manifest — plus icons) that references one or more of
the extension types below. In 2026 Microsoft also introduced a customer-facing **"Microsoft 365
Copilot plugin"**: an installable package bundling agents, skills, connector references, and remote
MCP server references, governed in the admin center under **Agents > Tools > Registry**.

Facts verified against Microsoft Learn as of 2026-10-24. Schema versions move; record drift.

## 1. Declarative agent — `declarativeAgent.json` (schema v1.9)

The core extension type: Copilot's own model and orchestrator, configured with instructions,
knowledge, and actions.

```
appPackage/
├── manifest.json              # unified app manifest; copilotAgents.declarativeAgents[] → { id, file }
├── declarativeAgent.json      # the agent manifest
├── plugin.json                # optional — API/MCP actions (schema v2.4)
├── skills/<name>/SKILL.md     # optional — agent_skills[] (v1.9, preview)
├── color.png (192×192)  outline.png (32×32)
```

**Manifest (v1.9, current):** `$schema` =
`https://developer.microsoft.com/json-schemas/copilot/declarative-agent/v1.9/schema.json`;
required `version` (`v1.9`), `name` (≤100), `description` (≤1,000), `instructions` (≤8,000).
Optional: `id`, `capabilities` (enum: `WebSearch`, `OneDriveAndSharePoint`, `GraphConnectors`,
`GraphicArt`, `CodeInterpreter`, `Dataverse`, `TeamsMessages`, `Email`, `EmailActions`, `People`,
`ScenarioModels`, `Meetings`, `MeetingActions`, `Fabric`, `EmbeddedKnowledge`),
`conversation_starters` (≤12), `actions` (1–10 plugin refs), `agent_skills` (≤8), `behavior_overrides`,
`disclaimer`, `sensitivity_label`, `editorial_answers`, `worker_agents`, `user_overrides`.

Prior versions 1.0–1.8 exist at `.../declarative-agent-manifest-1.X`; a sample pinned below ~1.6 is
stale. Validate offline with `wiqd agent validate`. Copilot Studio exports the same format
("download the .zip … open the declarativeAgent.json").

Agents Toolkit convention: `appPackage/declarativeAgent.json`, project pipeline `m365agents.yml` /
`m365agents.local.yml`. TypeSpec alternative: `main.tsp` with `@agent`, `@instructions`,
`@capabilities`, `@actions`, `@conversationStarter` decorators compiles to these JSON files.

## 2. API / MCP plugin — plugin manifest (schema v2.4)

Actions used *inside* a declarative agent ("not enabled as standalone experiences").

Required: `schema_version: "v2.4"`, `name_for_human`, `namespace` (`^[A-Za-z0-9]+`),
`description_for_human`. `runtimes[].type` ∈ `OpenApi`, `LocalPlugin`, `RemoteMCPServer` (v2.4
added MCP; MCP spec object has `url`, `mcp_tool_description`). Schema:
`https://developer.microsoft.com/json-schemas/copilot/plugin/v2.4/schema.json`. Referenced from the
agent as `"actions": [{ "id": "...", "file": "plugin.json" }]` or inline.

**Terminology trap:** Microsoft's own docs use "plugin" for both this technical action manifest *and*
the customer-facing installable package (§4). Classify by content, not by the word.

## 3. Agent Skill — `SKILL.md` (preview)

The open Agent Skills format, consumed in three places:

| Binding | Where | Status |
|---|---|---|
| Declarative agent | `agent_skills[]` in declarativeAgent.json v1.9 → `{ "folder": "./skills/<name>" }` | **Preview, Frontier Program only.** ISVs told not to submit to Partner Center yet. |
| Standalone / plugin | `agentSkills[]` in `manifest.json` → `{ "folder": "./skills/<name>" }` (Cowork plugins, Copilot plugins) | Preview via `wiqd` |
| Copilot Studio | **Build > Skills** on agents using the "GitHub Copilot harness" (name/description/Markdown; create, generate, or upload a package) | Available |

**Preview limits (declarative agents):** ≤8 skills/agent; Agent Builder uploads `.zip` ≤50 MB,
Agents Toolkit uses a directory within a 10 MB package; ≤350 files; depth ≤3; `SKILL.md`
instructions <20,000 chars; scripts (`.py .js .mjs .cjs .ts .mts .sh .bash`) run sandboxed with
**no network**; "reuse across agents: not supported at this stage". Tooling: `atk add skill --name
<n> --description <d>` / `--from <path>`; `wiqd plugin add skill`.

**Interop:** `wiqd plugin import` recognizes Open Plugin, Claude plugin, or Cursor plugin sources;
`wiqd plugin export --format claude-plugin|cursor-plugin|open-plugin`; `atk import openplugin
--path <dir>` reads `.claude-plugin/plugin.json` (or `.cursor-plugin/`, `.plugin/`), `.mcp.json`,
`skills/`. Agent Plugins 1.0 layout (root `plugin.json`, `mcp.json`) must be moved to
`.plugin/plugin.json` and `.mcp.json` first. Microsoft sits on the Agent Plugins 1.0 TSC.

A generic SKILL.md repo is therefore **Portable** into M365 with wrapping — flag the sandbox limits.

## 4. Microsoft 365 Copilot plugin (customer-facing package)

"An installable package that brings together capabilities for a specific task" — declarative
agents, skills, connector references, remote MCP server references. Built with `wiqd plugin
create|add skill|add connector|validate|provision|package|share --scope users|tenant|export`.
`wiqd plugin create` pins `manifestVersion: "1.29"`; the v1.28 schema is strict
(`additionalProperties: false`). `agentConnectors[]` entries carry `toolSource.remoteMcpServer`
with `mcpServerUrl`, optional `mcpToolDescription`, and `authorization` (`OAuthPluginVault`).
The `wiqd plugin` surface is public preview; "doesn't provide public-store submission or a
`wiqd plugin publish` command".

## 5. Copilot connector (formerly Graph connector)

Brings external data into Copilot's index. Declared to an agent via capability `GraphConnectors`
+ `connections[].connection_id`. On-prem SDK connectors use `Manifest.json` (`connectorId` GUID,
`AuthTypes`), `ConnectionInfo.json`, `CustomConnectorPortMap.json`. Agents Toolkit has a
"Copilot connector" template; samples at `microsoftgraph/msgraph-sample-github-connector-{dotnet,python,typescript}`.
Prebuilt gallery: Microsoft 365 Copilot Connectors Gallery (Microsoft Learn). A connector alone is
**Partial** coverage — data without authored behavior.

## 6. Copilot Studio agent / template

Low-code agents. Discoverable via the **Agent Library** (Copilot Agent Kit, April 2026+; tabs All /
Templates / Components; source `microsoft/m365-agent-templates`; needs Power Platform "CSK -
Maker" role), Copilot Studio's in-product templates, and `microsoft/CopilotStudioSamples`. Agent
Library declarative-agent templates offer "Customize & download" (solution `.zip`), "Use Agent
Builder", or "Build with VS Code" (clone + Agents Toolkit). Template fields mirror the declarative
agent manifest. **Copilot Studio agents are not individually shareable in any public catalog** —
sharing is tenant-scoped; catalog only templates and public exports.

## 7. Custom engine agent (CEA)

Your own model and orchestrator, surfaced in Copilot/Teams. Built with Copilot Studio, Teams SDK,
**Microsoft 365 Agents SDK** (`microsoft/Agents`, `Agents-for-net|js|python`; successor to Bot
Framework), or Foundry. Requires a bot resource and hosting; only Teams SDK / Agents SDK / Foundry
agents can be published to the Commercial Marketplace via the Toolkit. Marketplace policy 1140:
"must always include a conversation bot based on LLMs". Classify as `CEA`; lower value for a
"find a skill" question unless the user wants full agents. Flag `cea-hosting`.

## Not extensions — classify correctly

| Artifact | Treatment |
|---|---|
| `.github/skills/`, `.github/copilot-instructions.md`, `.github/agents/*.agent.md`, `.github/prompts/` | **GitHub Copilot.** Exclude. |
| `github/awesome-copilot` "declarative-agents" skill | A GitHub Copilot skill about *authoring* M365 agents. Exclude as an M365 extension; may be cited in the gap analysis as a build aid. |
| Agent Builder instruction block (text only) | Type `Instructions`. Useful, not deployable. |
| `manifest.json` with only `bots` / `composeExtensions` | Ordinary Teams app or message extension (maintenance mode for Copilot). |
| Office Add-in samples (e.g. `Samples/excel-copilot-skill`) | Add-ins, not Copilot extensions. |
| "Office skills" (Copilot Studio lite file generation), Dataverse `skill` field | Unrelated uses of the word. |
| Microsoft Learn "agent skills" training page | Unrelated. |

## Acquisition paths the catalog may record

| Form | When |
|---|---|
| Agent Store (in-product; collections "Built by your org", "Agents for your team") | End-user install; tenant-authenticated; no public API |
| AppSource (`appsource.microsoft.com`) | Public listing surface — Teams Store listings propagate here; category "AI Apps and Agents" |
| Admin center **Agents > All agents** / **Agents > Tools > Registry > Upload** | Tenant deployment of packages, plugins, skills, MCP servers |
| `atk install --file-path <pkg.zip> --scope Personal` | Developer sideload |
| `atk new sample <name>` · `atk list samples|templates` | Toolkit sample gallery (CLI only) |
| `git clone` of a sample/template repo | Source |
| `wiqd plugin import <source>` · `wiqd plugin share --scope users|tenant` | Plugin preview surface |
| Agent Library "Customize & download" | Copilot Studio templates |

## What ports cleanly

A valid Agent Skills `SKILL.md` ports into an app package via `wiqd plugin import` or
`atk import openplugin`, subject to the preview sandbox (no network, no package install, <20k-char
instructions, file-type allowlist, ≤8 per agent). Claude/Cursor plugin manifests import directly.
Agent Plugins 1.0 layouts need the two-file rename first. GitHub Copilot custom agents
(`.agent.md`) do **not** port — different schema entirely. Classify ported candidates as
**Portable** and state the limit that bites.
