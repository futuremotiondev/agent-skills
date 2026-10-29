# Verification

The gate between "found a mention" and "goes in the catalog". Nothing reaches `Catalog` without
clearing every rule here.

## The core rule

**A search snippet is not evidence.** Aggregator listings, blog roundups, and search results
describe skills that were renamed, archived, or never existed. Fetch the artifact.

Every `Catalog` row must have a URL that was fetched during **this run** and returned the artifact.
Record `verified_at` as the run timestamp.

## Existence check

Fetch the candidate and confirm it matches **one** of the qualifying artifact shapes in
`references/artifact-types.md`. Fails all of them → not a Figma skill. Drop it, or
move it to Unverified with the reason.

**Things that look like skills and are not:**

| Looks like | Actually is |
|---|---|
| A README listing skills | Documentation. Follow it to the real artifacts. |
| A blog post titled "10 best skills for X" | A pointer. Verify each item independently. |
| A prompt template repo | Not a skill unless it ships a conformant artifact. |
| A vendored copy in a mega-collection | A mirror. Resolve upstream. |
| A Figma plugin or widget (`figma.com/community/plugin/…`, `manifest.json` with `api` / `main` / `editorType`, `@figma/plugin-typings`) | Code that runs inside Figma. Not a skill — even the plugin titled "SKILLS for Figma Agent Design" (a plugin that *distributes* in-app skills; follow it to the skills it ships). |
| A generative plugin (`code.ts` + `ui.html`) or shader (`main.ts`, `.build/main.js`, `features.json`) | AI-authored Figma resources. Targets of the `figma-generative-plugins` / `figma-shaders` skills, not skills. |
| Anything at `figma.com/community/file/…` — Design, FigJam, Slides, Sites, Buzz templates and **Make projects** | A file. Make "prompts" and "templates" are files, not skills. |
| A Weave tool (`/community/weave_tool/…`) or AI workflow (`/community/ai-workflows`) | Node-based graph automation. Figma itself says these are not skills. |
| An MCP-client listing at `figma.com/community/app/…` (`figma-mcp-in-claude-code`, `kiro`, `grok`, …) | A directory entry for a client, not a skill. |
| `figma.config.json`, `*.figma.ts|tsx|swift|kt`, Code Connect template files | Code Connect mapping config. The skill that *writes* them is `figma-code-connect`. |
| Variables REST JSON, `*.tokens.json`, DTCG exports, `figma/variables-github-action-example` | Token data or sync config. A skill only if a `SKILL.md` wraps it. |
| Output of the `create_design_system_rules` MCP prompt, `figma-power/steering/*.md`, `.cursor/rules/figma-design-system.mdc` | Agent rules files — Adjacent config, not skills. |
| A Figma MCP server with no `SKILL.md` (Framelink `GLips/Figma-Context-MCP`, `arinspunk/claude-talk-to-figma-mcp`, `grab/cursor-talk-to-figma-mcp`, figwright, plumb-mcp, tellfigma, figma-mcp-free) | MCP, not a skill. **Partial** coverage at most. Note the servers that *do* ship a skill: `southleft/figma-console-mcp-skills`, `planetabhi/figma-mcp-server` (`.agents/skills/figma-agent`), `noemuch/bridge` (`bridge-ds`). |
| A `SKILL.md` citing `mcp.canva.com`, `@penpot/mcp`, `framer-mcp`, or "Pencil MCP" | A skill for an adjacent design tool. Classify **Adjacent**, never Figma. |
| A blog roundup ("Figma skills for Claude Code: Complete Guide", "10 Claude Skills for Design", "Figma Skills for Codex") | A pointer. Verify each item independently. |

## Platform attribution

A skill must be shown to run on a **specific Figma surface** — inside Figma (the Figma agent, Figma Make) or in a named external agent against the Figma MCP server. Record the surface first, then the evidence level for each runtime claimed, strongest first:

1. **Figma first-party listing.** The skill page exists at `figma.com/community/skill/<id>/` (proves it runs in the Figma agent and Make); or it is in `figma/mcp-server-guide/skills/` or the live `skill://index.json`; or it is on the editorial `figma.com/community/skills` page or in `community-resources/agent_skills/README.md` (proves Figma accepted it as an MCP skill).
2. **The artifact names its runtime.** The `SKILL.md`, README, or manifest names the agent (`.claude-plugin/`, `agents/openai.yaml`, `.cursor-plugin/`, `gemini-extension.json`, `.github/plugin/`, `POWER.md`) or names Figma MCP tools (`use_figma`, `get_design_context`, …); or a Community page's instructions reference Figma-agent features.
3. **Format and placement.** A spec-conformant `SKILL.md` under a path the agent documents (`.agents/skills/`, `.claude/skills/`) whose body is about Figma; or a single-file skill that *could* be uploaded to the Figma agent — compatible, not proven.
4. **Aggregator or roundup tag.** skills.sh, claudemarketplaces, skillsmp, a blog list, or a README claim of "works with Figma" — **weakest**; title keywords ("skill", "AI", "Figma") prove nothing, as the Community *plugin* titled "SKILLS for Figma Agent Design" shows.

Record which level applied in the `Compatibility Evidence` column. A skill with only level-4
evidence scores no higher than **Portable** in the gap analysis unless you confirm level 3 by
reading the artifact yourself.

**Surface first, agent second.** Every row records a `Surface` — `community` (runs in the Figma agent and Figma Make) or `mcp` (runs in an external agent against the Figma MCP server) — and only `mcp` rows carry per-agent compatibility. **Community skills:** the page itself is level-1 evidence that it runs in the Figma agent; `figma-make` is implied, because Community skills are single-file by construction. **Official MCP skills:** `figma/mcp-server-guide/skills/figma-*` (frontmatter `name`, `description`, `disable-model-invocation`; bodies reference `use_figma` and a `skillNames` logging parameter), also served live at `skill://figma/<name>/SKILL.md`. **Third-party MCP skills:** the strongest discriminator is a `SKILL.md` whose description or body names Figma MCP tools — `use_figma`, `get_design_context`, `get_variable_defs`, `search_design_system`, `get_figjam`, `generate_diagram`, `create_new_file`, `get_code_connect_map`, `get_metadata`, `get_screenshot` — or REST endpoints (`/v1/files/:key/variables/local`, `/v1/files/:key/versions`). A `references/` tree on the Plugin API, variables, or `.figma.ts` templates is a second strong signal. **Per-agent evidence for `mcp` rows** follows the manifest ladder: `.claude-plugin/` → Claude Code; `.codex-plugin/` or `agents/openai.yaml` → Codex; `.cursor-plugin/` → Cursor; `gemini-extension.json` → Gemini CLI; `.github/plugin/` or `.github/skills/` → Copilot; `.grok-plugin/` or xAI marketplace pinning → Grok; `figma-power/POWER.md` → Kiro; `.agents/skills/` → neutral (Warp uses `.agents/.skills/`). **Naming is a provenance heuristic:** Figma's own skills are prefixed `figma-`; `community-resources` requires third-party names *not* to start with "Figma", so curated third-party skills are usually suffixed `-figma` (`lint-design-figma`, `export-tokens-figma`).

## Metrics discipline

**Never state a number from memory.** Star counts, install counts, download counts, contributor
counts, and last-commit dates are either fetched this run or omitted.

Omitted is fine — an empty cell is honest. A confidently wrong star count destroys trust in every
other cell.

| Source | Reliability |
|---|---|
| Repo page fetched now | High — use it |
| Registry manifest or official catalog entry | High for metadata; usually carries no popularity data |
| Aggregator listing | Low — often stale or self-reported. Use only if the repo is unreachable, and label it |

**Attribute stars to the right thing.** A skill inside a 40k-star monorepo does not have 40k
stars. Record the repo's stars and note that the skill is one of N in that repo — the Adoption
rubric handles the discount.

## Content check for ranked candidates

For anything that will score above `min_score`, read the actual `SKILL.md` (or, for a Community skill, the page's **Instructions** block — which *is* the single-file skill body). Score
comprehensiveness from what it contains, never from repo popularity or README claims.

Record:

- **Body length** — rough line count of the primary artifact
- **Bundled resources** — `references/` (Plugin API `.d.ts` and index, variables, FigJam / Slides node recipes, Code Connect API, motion), `scripts/*.js` run through `use_figma`, `agents/openai.yaml`, per-agent manifests. Community skills have none by construction — record the Instructions line count and preview-image count instead
- **Depth signals** — concrete code, version-specific guidance, decision tables, anti-patterns,
  worked examples
- **Shallowness signals** — generic advice restating vendor docs, no version anchoring, obvious
  LLM-generated filler, a body that is mostly headings

A 900-line artifact that is 800 lines of generic platitudes scores below a 180-line one with real
version-specific guidance and a reference tree. Length is a weak proxy; read it.

## Canonicalization and dedup

The same skill is routinely vendored across many registries and mega-collections.

1. Resolve every candidate to its **upstream source repository**. Registry manifests often give this
   directly — prefer that over guessing.
2. Group by upstream `(repo, path)`.
3. Keep one row per group. Record mirror count as a metric, not as separate rows.
4. When upstream is genuinely unclear (no attribution, no manifest), catalog the copy you can
   verify and flag `Upstream: unresolved`.

Mirror count is a mild adoption signal — many independent registries vendoring the same skill
suggests real usage. It is not a substitute for stars or installs.

## Supply-chain flags

Installing a skill can execute code or grant data access. Flag, per row, whether it bundles:

| Flag | Why it matters |
|---|---|
| `plugin-api-exec` | Ships or instructs Plugin-API JavaScript executed via `use_figma` — arbitrary edits to the user's file, including deletes |
| `write-canvas` | Uses write tools (`use_figma`, `generate_figma_design`, `html_to_figma`, `send_code_to_figma`, `upload_assets`, `create_new_file`) — modifies files; free in beta, slated to become usage-based paid |
| `rest-token` | Requires a Figma personal access token (`FIGMA_TOKEN`, `FIGMA_ACCESS_TOKEN`) — account-scoped access, often with write scopes |
| `third-party-mcp` | Bound to a non-Figma MCP server or bridge plugin (figma-console-mcp, bridge, talk-to-figma) — an extra server, WebSocket, or desktop plugin in the trust path |
| `paid-credits` | Calls Weave tools, `generate_image`, generative plugin / shader creation, or Make imports that consume Figma AI or Weave credits |
| `mcp` | Bundles MCP config (`.mcp.json`, `mcp.json`, `mcp_config.json`, `mcpServers`) — network and OAuth access |
| `hooks` | Bundles any agent's hook config — runs commands on lifecycle events |
| `scripts` | Executable code outside `use_figma` (Node, Bun, Python) |
| `plan-gated` | Needs a Dev / Full seat, an Organization / Enterprise plan (Code Connect, Variables REST), or `specs_enabled` — fails silently on other plans |
| `unpinned` | No pinned commit SHA or version in the registry entry |

Report these **separately from the score**. A high-quality skill with elevated permissions is
still high-quality; the user decides their own risk tolerance. Do not silently downrank for it, and
do not silently omit it either.

## Freshness

Fetch and record the last commit or update date where available.

| Age | Treatment |
|---|---|
| < 3 months | Current |
| 3–9 months | Note the age |
| > 9 months | Flag `stale` — for a fast-moving toolchain this is a real risk |
| Archived | Flag `archived`. Catalog only if nothing else covers the facet, and say why. |

Version-anchored skills go stale faster than concept skills. A skill pinned to a
superseded framework version is stale even with recent commits.

## Unverified handling

When something is probably real but cannot be confirmed — repo private, org renamed, only ever
referenced secondhand — it does **not** go in `Catalog`.

If `include_unverified` is true, list it in a clearly separated section with: the claim, where the
claim came from, what was attempted, and why it failed. If false, omit it entirely and note the
count in the Run Log.

Never soften an unverified item into a verified-looking row.
