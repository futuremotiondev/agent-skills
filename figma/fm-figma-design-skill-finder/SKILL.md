---
name: fm-figma-design-skill-finder
description: Research and rank Figma-specific agent skills — both the single-file skills in the Figma Community AI skills library (figma.com/community/ai-skills) that run inside the Figma agent and Figma Make, and the SKILL.md skills for external coding agents (Claude Code, Cursor, Codex, Copilot, Gemini CLI, Grok, Kiro) that drive the Figma MCP server — across figma/mcp-server-guide, figma/community-resources, vendor design-system repos, GitHub, and skill aggregators, then produce a scored Markdown report and an .xlsx catalog. Use whenever the user asks to find, discover, research, compare, audit, or recommend Figma skills — "what Figma skills exist for X", "find a skill that does design-to-code from Figma", "is there a FigJam / Slides / Code Connect / variables skill", "which Figma skills work in Cursor", "audit the Figma skill ecosystem for Y" — or wants to know whether coverage exists before authoring one. Figma plugins, widgets, Make templates, Code Connect files, and MCP servers are classified, not cataloged.
---

# Figma Design Skill Finder

Deep-research the Figma skill ecosystem for a requested topic. Produce a verified,
scored, deduplicated catalog — never a plausible-sounding list.

**The failure mode this skill exists to prevent:** inventing skills that don't exist.
Figma now has **two separate skill ecosystems that do not interoperate**: single-file Community skills that run inside the Figma agent and Figma Make (invoked by slash command — Figma's own FAQ says they do not run in Claude Code, Cursor, or Codex), and SKILL.md skills that external coding agents load to drive the Figma MCP server. The classic failures are conflating the two; cataloging a Figma *plugin*, *widget*, *Make template*, *Code Connect file*, or *MCP server* as a skill because its title says "AI" or "skill"; counting Figma's 16 first-party skills five times across the OpenAI, Warp, Cursor, OpenCode, and open-design mirrors; and inventing a FigJam or variables skill because the facet "obviously" should exist. Reporting three real skills and an honest gap analysis beats twelve
fabricated rows. Every row in every output must trace to a URL fetched during this run.

**Scope boundary:** In scope — (a) **Community AI skills**: entries at `figma.com/community/skill/<id>/<slug>` (single `.md`, Agent Skills spec, run in the Figma agent and Figma Make); (b) **MCP skills for external agents**: `SKILL.md` skills whose instructions drive the Figma MCP server (`use_figma`, `get_design_context`, `get_variable_defs`, …) or the Figma REST / Plugin API, wherever they live — `figma/mcp-server-guide`, `figma/community-resources/agent_skills`, vendor and design-system repos, personal monorepos, mirrors; (c) the agent plugins, marketplaces, and catalogs that package them. Out of scope — Figma plugins and widgets (`manifest.json`, `@figma/plugin-typings`), generative plugins and shaders, Make projects / templates / kits, Weave tools and AI workflows, Code Connect files (`figma.config.json`, `*.figma.ts`), variable and token JSON, Figma MCP *servers* with no authored skill, and skills for adjacent tools (Canva, Penpot, Pencil, Framer). Record those as context when the topic needs them — never as `Catalog` rows.

## 1. Resolve arguments

Skills are model-invoked and receive no `$ARGUMENTS`. Parse the following from the user's request.
Apply defaults silently; never interrogate the user about parameters they didn't raise.

| Argument | Default | Notes |
|---|---|---|
| `topic` | **required** | Free text. May be multi-part — decompose in step 2. |
| `depth` | `standard` | `quick` ≈ 8–15 tool calls · `standard` ≈ 25–40 · `exhaustive` ≈ 60–90 |
| `max_results` | `25` | Ranked rows in the main table. Overflow → "Also found" appendix. |
| `min_score` | `50` | 0–100. Below this, a row moves to the appendix. |
| `outputs` | `report,xlsx` | Any of `report`, `xlsx`, `json`, `install` |
| `include_unverified` | `false` | When true, unverified finds appear in a clearly separated section |
| `as_of` | today | Freshness anchor recorded in every output |
| `exclude` | none | Author, org, or registry to skip |
| `surface` | `both` | `community` (Figma Community AI skills — run inside the Figma agent / Make) · `mcp` (SKILL.md skills for external agents via the Figma MCP server) · `both`. Decides which halves of `discovery-sources.md` run and which install forms are emitted |
| `agents` | `all` | For `mcp` rows: comma list of external agents whose compatibility to report — `claude-code`, `cursor`, `codex`, `github-copilot`, `gemini-cli`, `antigravity`, `grok`, `kiro`, `warp`, `windsurf`, `vscode`, `claude-desktop`. `all` reports every agent with evidence |
| `products` | `all` | Comma list narrowing the Figma product surface — `design`, `figjam`, `slides`, `make`, `dev-mode`, `code-connect`, `variables`, `specs`, `motion`, `weave`, `sites`, `buzz`, `draw`. Filters facets (see `references/figma-facets.md`), not sources |

**Clarify before starting only if `topic` is genuinely ambiguous** — a bare "find me some skills"
with no domain. A topic that is merely broad is not ambiguous; decompose it instead.

State the resolved arguments in one line before beginning, so the run is reproducible:

> Researching **<topic>** for Figma · depth `standard` · max 25 · min score 50 · outputs report+xlsx · as of <date>

## 2. Decompose the topic

Split the topic into 4–10 **facets** before searching. Multi-part requests (a language *and* its
frameworks *and* its migration paths) are several searches, not one.

For each facet record: the canonical name, known aliases and abbreviations, adjacent ecosystem terms,
and the vocabulary a skill author would actually use in a description or manifest. Search the
author's vocabulary, not the user's — a WinUI 3 skill may describe itself as "Windows desktop",
"Fluent", "WinAppSDK", or "XAML" and never say "WinUI".

Present the facet list before searching. It is the outline of the final report.

## 3. Discover

Work the sources in `references/discovery-sources.md` in tier order. Do not stop at aggregator
sites — they lag and duplicate. Reach the upstream repository for everything you intend to rank.

Budget roughly: 45% Figma first-party sources (the Community AI skills library and its six category hubs; `figma/mcp-server-guide` or the live `skill://index.json`; the `figma/community-resources/agent_skills` README), 30% GitHub topic and code search keyed on Figma MCP tool names, 25% vendor and design-system orgs plus cross-agent aggregators. Read `community-resources/agent_skills/README.md` first — one fetch yields ~36 third-party MCP skills with source repo, license, and the MCP tools each uses. Then page the Community library (`?page=1..7` plus each category hub): it is server-rendered but `robots.txt` disallows generic fetchers on `/community`, so use a scraping tool or a browser, not `WebFetch`. Skip `community` sources when `surface` is `mcp`, and vice versa.

## 4. Verify — mandatory gate

Nothing enters the ranked table without passing `references/verification.md`. In short:

- **Fetch the URL.** A search snippet is not verification. 404 or redirect-to-org → drop the row.
- **Confirm it is a real Figma skill** — see `references/artifact-types.md` for the
  exact files and manifests that qualify. A README describing skills is not a skill.
- **Read the actual `SKILL.md` (or, for a Community skill, the page's **Instructions** block — which *is* the single-file skill body)** for anything scoring above `min_score`. Score
  comprehensiveness from content, never from repo stars or marketing copy.
- **Never state a star count, install count, or date from memory.** Fetched this run, or omitted.
- **Canonicalize.** The same skill is vendored across many registries and collections. Resolve
  to the upstream source repo and record mirrors as a count, not as separate rows.

## 5. Score

Apply the rubric in `references/scoring-rubric.md`. Weighted 0–100 across Authority (30),
Comprehensiveness (25), Adoption (20), Maintenance (15), and Topic Fit (10), with an explicit
supply-chain risk flag that is reported separately rather than folded into the score.

Show the sub-scores. A bare composite number is unauditable.

## 6. Report gaps honestly

This step is not optional and is often the most valuable output.

For every facet from step 2, classify coverage:

| Class | Meaning |
|---|---|
| **Covered** | A dedicated, verified skill scoring ≥ `min_score` |
| **Partial** | Only covered incidentally by a broader skill, or by an MCP server or Figma plugin with no authored skill, a design-system skill that treats Figma as one input among several, or a Community skill whose instructions cannot leave the Figma app rather than authored guidance |
| **Adjacent** | Nothing direct; the nearest real thing needs adaptation |
| **Portable** | Nothing native, but a verified skill for another agent exists that the open Agent Skills format makes usable here — see `references/artifact-types.md` for what ports cleanly |
| **Uncovered** | Nothing found. Say so plainly. |

For **Partial**, **Adjacent**, **Portable**, and **Uncovered** facets, propose what the user would
author themselves: a one-line description draft, the reference files it would need, and any
existing skill worth forking or porting. Under-served facets are build opportunities, and saying
"no coverage" is a correct, useful result.

## 7. Emit outputs

Follow `references/output-spec.md` for the exact report structure and workbook schema.

Non-negotiables:

- The **ranked Markdown table comes first**, immediately after the run header. Not after the
  methodology, not after the summary.
- The `.xlsx` has **four sheets**: `Catalog`, `Gaps`, `Sources`, `Run Log`. The last two make the
  run auditable and repeat runs comparable.
- Every row carries `Verified` and `Verified At`.
- Unverified finds never appear in `Catalog`. They go to a separate section, and only when
  `include_unverified` is true.

## Reference files

| File | Read when |
|---|---|
| `references/artifact-types.md` | Step 2 — before searching, so you know what you are looking for |
| `references/discovery-sources.md` | Step 3 — every run |
| `references/verification.md` | Step 4 — every run |
| `references/scoring-rubric.md` | Step 5 — every run |
| `references/output-spec.md` | Step 7 — every run |
| `references/figma-facets.md` | Step 2 — the Figma facet taxonomy, product-surface matrix, and the MCP-tool fingerprint of each facet |

## Quality bar

Before emitting, confirm:

- [ ] Every `Catalog` row has a URL fetched during this run
- [ ] No star count, install count, or date is stated from memory
- [ ] Duplicates collapsed to upstream source repos
- [ ] Every facet from step 2 appears in the gap analysis, including the empty ones
- [ ] Sub-scores shown, not just composites
- [ ] Supply-chain flags set for anything bundling Plugin-API JavaScript executed through `use_figma`, write-to-canvas tools, REST tokens (`FIGMA_TOKEN` / `FIGMA_ACCESS_TOKEN`), third-party MCP bridges, or credit-consuming tools (Weave, generative plugins, `generate_image`)
- [ ] Ranked table is the first thing after the run header
- [ ] `Sources` sheet lists every query run, including the ones that returned nothing
- [ ] Nothing from a different platform was cataloged as native — a Community AI skill runs only inside the Figma agent and Figma Make and is **not** a Claude Code / Cursor / Codex skill however good its instructions; an MCP skill does not run inside Figma; a Canva, Penpot, Pencil, or Framer skill shaped exactly like a Figma skill is **Adjacent**, not Figma

**A short honest catalog outranks a long speculative one.** If a facet has two real skills,
report two.
