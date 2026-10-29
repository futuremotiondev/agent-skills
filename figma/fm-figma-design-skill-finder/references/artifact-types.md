# What counts as a Figma skill

One format underlies both Figma ecosystems — the open **Agent Skills** standard (agentskills.io): a
Markdown file with YAML frontmatter `name` (lowercase, hyphens) and `description`, optional
`compatibility`, `metadata`, `allowed-tools`. Figma's own definition: *"An AI skill is a short
Markdown file (a SKILL.md) that tells an AI agent how to handle a specific task … not design files
or code."* What differs is **where it runs** and **what it can contain**. Those two things decide
the `Surface` and `Single-File` columns and most of the compatibility story.

| | Community skill | MCP skill |
|---|---|---|
| Runs in | The Figma agent (Design, Make; FigJam/Slides agent announced) | An external agent (Claude Code, Cursor, Codex, Copilot, Gemini CLI, Grok, Kiro, Warp…) connected to `https://mcp.figma.com/mcp` |
| Shape | **Single `.md`** — Figma Make "accepts only standalone skill files"; `scripts/`, `references/`, `assets/` are not supported | Folder with `SKILL.md`; optional `scripts/`, `references/`, `assets/`; often a per-agent manifest beside it |
| Invoked by | `/slash-command` in the Figma prompt box (the `name` is the command); "Skills > Use skills" | The agent's own skill mechanism (`/name`, `$name`, model-invoked) |
| Published to | Team / organization (private) or the Figma Community (thumbnail, ≤ 9 images, tagline, category, support contact); updated via "Publish changes"; no review badge | GitHub; optionally Figma's curated index (`community-resources/agent_skills`) and agent marketplaces |
| License | Community Free Resource License | Whatever the repo says (CC0 recommended by Figma; official skills under the Figma Developer Terms) |
| Can it cross over? | Instructions can be copied out ("Copy to clipboard", "Export as Markdown") and dropped into an external agent — but only if they don't depend on in-app agent features. Figma: "Many of these skills also work with Figma's MCP server in third party agents" | A **single-file** MCP skill can be uploaded into the Figma agent (Add skill → upload `.md`); a multi-file one cannot without flattening |

Figma's FAQ is unambiguous on the split: Community skills "run directly inside the Figma app …
MCP skills are built for coding tools like Claude Code, Cursor, or Codex … and they don't run
inside the Figma app itself." Catalog them under different `Surface` values and never let one stand
in for the other.

## 1. Community skill — `figma.com/community/skill/<id>/<slug>`

Qualifies when the URL path segment is `/community/skill/` (5-digit numeric id — plugins, widgets,
files, and shaders use 19-digit ids). The page carries: creator link(s) (co-creators possible — "Figma
Community and Neha Kodi"), the type label **"Skill"**, likes, users, "Try it out", **Preview** (≤ 9
carousel images served from the `custom_skills/carousel/img/<id>/` bucket, or a text description that
doubles as the trigger text), **Instructions** (the full body, line-numbered — this is the primary
artifact; `better-interface` runs 800+ lines), `#tags`, "Last updated", Support, license.

Record: `Community ID`, likes, users, Instructions line count, publisher handle (`Figma Community`
= Figma-authored), category hub(s) it appears in, tags. `Runs In` = `figma-agent, figma-make`.
`Single-File` = Y always.

## 2. MCP skill — `SKILL.md` for an external agent

Qualifies when a `SKILL.md` with valid frontmatter has a body about operating Figma — through the
Figma MCP server, the REST API, or the Plugin API via `use_figma`. Where it sits determines *which
agent* reads it natively:

| Layout | Who reads it | Signal |
|---|---|---|
| `skills/<name>/SKILL.md` inside a repo with `.claude-plugin/plugin.json` | Claude Code (and Codex, Copilot CLI, Grok, which read Claude plugins) | Figma's own repo, southleft, edenspiekermann, robukh |
| `.cursor-plugin/plugin.json` → a `skills` dir (Figma points it at `skills-figquery/`) | Cursor | Figma, figma-maxxing |
| `.codex-plugin/plugin.json`, `agents/openai.yaml` beside `SKILL.md`, `.agents/plugins/marketplace.json` | Codex | `openai/plugins/plugins/figma`, edenspiekermann, figma-maxxing |
| `.github/plugin/plugin.json`, `.github/skills/<name>/` | GitHub Copilot | Figma, IBM Carbon install docs |
| `gemini-extension.json` | Gemini CLI (Figma's declares MCP only, no skills) | Figma, figma-maxxing |
| `figma-power/POWER.md` + `steering/*.md` | Kiro | Figma |
| `.agents/skills/<name>/` (Warp: `.agents/.skills/`) | The convergent neutral path — Codex, Cursor, Copilot, Antigravity, Warp, Amp, OpenCode, … | planetabhi, alma-oss/spirit, warpdotdev/figma-skills |
| `.claude/skills/<name>/` | Claude Code natively; Copilot, Cursor, Grok, OpenCode via compat | tallneil, natdexterra installs |
| Pinned entry in `anthropics/claude-plugins-official`, `xai-org/plugin-marketplace`, `openai/plugins` | That platform's users, at the pinned SHA | Figma's bundle only, so far |

**Fingerprints of a real Figma MCP skill**, strongest first: (1) frontmatter `description` or body
names Figma MCP tools — `use_figma`, `get_design_context`, `get_variable_defs`,
`search_design_system`, `get_figjam`, `generate_diagram`, `create_new_file`, `get_code_connect_map`,
`get_metadata`, `get_screenshot`, `get_motion_context` — or REST endpoints
(`/v1/files/:key/variables/local`, `/v1/files/:key/versions`, `/v1/files/:key/comments`);
(2) `references/` on the Plugin API (`plugin-api-standalone.d.ts`), variables, FigJam/Slides node
recipes, or `.figma.ts` templates; (3) an install surface (per-agent manifest, `skills.sh.json`,
`npx skills add` line). Official skills additionally carry `disable-model-invocation` in frontmatter
and instruct the agent to pass a `skillNames` logging parameter (`resource:` prefix when loaded from
`skill://`).

Record: `MCP Tools Used`, `Requires Native Figma MCP` (N when bound to figma-console-mcp, bridge,
talk-to-figma, or REST only), `Single-File`, `Agent Compat` per requested agent, `Figma Products`.

**Alias map** (one skill, several names): `figma-design-to-code` ≡ `figma-implement-design` (OpenAI,
Warp); `figma-code-connect` ≡ `figma-code-connect-components` (OpenAI); OpenAI's
`figma-create-design-system-rules` corresponds to Figma's MCP *prompt* `create_design_system_rules`,
not to a current skill. Southleft's full set uses the `figma-` prefix (`figma-export-tokens`); its
community-indexed subset uses the `-figma` suffix (`export-tokens-figma`) — same skills.

## 3. Containers — plugin, skill pack, marketplace

| Container | What it is | Treatment |
|---|---|---|
| `figma/mcp-server-guide` as a Claude / Cursor / Copilot plugin, Gemini extension, Kiro Power, MCP `server.json` | One repo, seven packagings of the same 16 skills | Catalog the **skills**; record the containers as install paths on each row. Type `Plugin` only when the user asks about the bundle itself |
| A repo of `skills/*/SKILL.md` with no manifest (`southleft/figma-console-mcp-skills`, `Hosseinkm89/figma-skills`) | Skill pack installable via `npx skills add` or copy | Catalog each skill; note pack membership |
| A `marketplace.json` entry pointing at Figma's repo | Provenance, not a new skill | `Registry` column + mirror count |
| The Community *plugin* "SKILLS for Figma Agent Design" (60+ in-app skills for upload) | A distribution plugin | Not a skill; follow it to the skills it ships and verify each as a Community-shaped single file |

## Not skills — classify correctly

| Observed signal | Class | Treatment |
|---|---|---|
| `/community/plugin/<19-digit>/…`; `manifest.json` with `name`, `id`, `api`, `main`, `editorType` (`figma` · `figjam` · `dev` · `slides` · `buzz`), `capabilities`, `networkAccess`; `@figma/plugin-typings` | **Plugin** — including "AI plugins" that call an LLM (`figma/ai-plugin-template`) | Out of scope. Note as context for a plugin-development facet |
| `/community/widget/…`; `@figma/widget-typings`, `figma.widget.h`, `npm init @figma/widget` | **Widget** | Out of scope |
| Generative plugin (`code.ts` + `ui.html`, PropsKit `fig-*`, no editable manifest) · shader (`main.ts`, `.build/main.js`, `features.json`) | **AI-authored Figma resource** | Out of scope; the skills that author them (`figma-generative-plugins`, `figma-shaders`) are in scope |
| `/community/file/<id>/…` — Design, FigJam, Slides, Sites, Buzz templates, **and every Make project** (`/community/make` hub) | **File** | Out of scope. Make "prompts", "templates", "kits" (npm packages of guidelines/tokens) are configuration, not skills |
| `/community/weave_tool/<small-int>/…`; `/community/ai-workflows` | **Weave tool / AI workflow** (node graph) | Out of scope; Figma: "Unlike Community AI workflows … skills are lightweight Markdown instructions" |
| `/community/app/<id>/…` (`figma-mcp-in-claude-code`, `kiro`, `grok`, `linear`, …) | **MCP-client / app listing** | Out of scope |
| `figma.config.json` (`codeConnect.{include,exclude,parser,label,…}`), `*.figma.ts|tsx|swift|kt`, `figma.<fw>.config.json` | **Code Connect config** | Out of scope; `figma-code-connect` is the skill that writes them. Parsers are frozen — templates (`.figma.ts`) only |
| Variables REST JSON (`variableCollections`, `valuesByMode`), `*.tokens.json`, DTCG exports, `figma/variables-github-action-example` | **Token data / sync config** | Out of scope unless a `SKILL.md` wraps it |
| `create_design_system_rules` output, `figma-power/steering/*.md`, `.cursor/rules/figma-design-system.mdc`, `CLAUDE.md` / `AGENTS.md` sections about Figma | **Agent rules** | Adjacent config — note when the facet is "agent rules generation" |
| MCP servers with no skill (Framelink, talk-to-figma bridges, figwright, plumb-mcp, tellfigma) | **MCP server** | **Partial** coverage; `third-party-mcp` flag on skills that depend on them |
| `SKILL.md` naming `mcp.canva.com`, `@penpot/mcp`, `help.penpot.app/mcp`, `framer-mcp`, "Pencil MCP" / `pen.dev` | **Adjacent-tool skill** (Canva, Penpot, Framer, Pencil) | **Adjacent**, never Figma. Same file shapes, different vendor tokens |
| `/community/skill/` page whose Instructions only *describe* other skills | Documentation | Follow to the real skills |

Title words — "skill", "AI", "agent", "template", "prompt", "Figma" — appear across every class above.
**The path segment and the on-disk fingerprint always win over the title.**

## What ports, and what doesn't

**Community → external agent.** Copy the Instructions into `<name>/SKILL.md`; it works wherever the
body only relies on Figma MCP tools the agent has (write-to-canvas via `use_figma`, reads via
`get_design_context`). It will not port if it relies on in-app agent affordances (selection
context, "Try in" file binding, connectors) or on Make's app-building loop. Classify as **Portable**
with the caveat stated.

**External agent → Figma agent / Make.** Upload works only for a **single file**; strip
`references/` and `scripts/` first (official skills like `figma-use`, whose value is its bundled
`.d.ts`, lose most of it). Also check the body doesn't instruct `claude mcp add` or agent-specific
tool calls. Classify as **Portable** with `Single-File: N → flatten required` when applicable.

**External agent → external agent.** As for any Agent Skill: a `SKILL.md` under `.agents/skills/`
loads in every agent that documents that path; Claude plugins (Figma's included) are addable to
Codex, Copilot CLI, and Grok; Gemini's extension is MCP-only (skills must be added separately);
vendor frontmatter (`agents/openai.yaml`, `disable-model-invocation`) is silently ignored elsewhere.

**Does not port anywhere:** plan gating. Code Connect (Organization/Enterprise — help center says
Professional too; unresolved), Variables REST (Enterprise), Specs (`specs_enabled`), write-to-canvas
on Starter/View/Collab seats (6 tool calls/month). Record `plan-gated` and the plan on the row; a
skill that only works on a plan the user doesn't have is **Partial** for them.
