---
name: fm-universal-agent-skill-finder
description: Research and rank agent skills, plugins, extensions, and marketplaces across every AI coding agent — Claude Code, Codex/ChatGPT, Gemini CLI and Antigravity, GitHub Copilot, Grok Build, Cursor, Windsurf/Devin, OpenCode, Amp, Kiro, Cline, Roo, Goose, Zed, and other Agent-Skills-compatible tools — for a topic, language, framework, or workflow, producing a scored Markdown report with a per-agent compatibility matrix and an .xlsx catalog. Use whenever the user asks to find, discover, research, compare, audit, or recommend skills without naming one platform, names several, or asks which agents a skill works with — e.g. "what skills exist for X across agents", "find a skill for Y that works in Codex and Claude", "best agent skills for Z", "which tools support W". Also use to check whether coverage exists anywhere before authoring a skill. For a deep single-platform run, the sibling platform-specific finders go further.
---

# Universal Agent Skill Finder

Deep-research the any AI coding agent skill ecosystem for a requested topic. Produce a verified,
scored, deduplicated catalog — never a plausible-sounding list.

**The failure mode this skill exists to prevent:** inventing skills that don't exist.
The open Agent Skills format is shared by 46+ listed adopters and dozens more, so a bare `SKILL.md` is technically loadable almost everywhere — the risk is marking every skill "works with all agents" on format alone, when no machine-readable compatibility field exists and real compatibility depends on load paths, vendor frontmatter, plugin manifests, and whether a given agent's harness even reads the directory the skill sits in. The opposite failure is also real: concluding a facet is uncovered because the one agent you searched had nothing, when a sibling ecosystem covers it and the skill ports in one command. Reporting three real skills and an honest gap analysis beats twelve
fabricated rows. Every row in every output must trace to a URL fetched during this run.

**Scope boundary:** In scope — `SKILL.md` skills in any agent's layout; agent-specific plugin and extension packages (Claude `.claude-plugin/`, Codex `plugin.json` / `.codex-plugin/`, Antigravity `plugin.json`, Gemini `gemini-extension.json`, Copilot plugins, Grok `.grok-plugin/`, Cursor `.cursor-plugin/`, Kimi `.kimi-plugin/`, Devin `.devin-plugin/`, Hermes `.hermes-plugin/`, etc.); marketplaces in any format; cross-agent installers and registries. Microsoft 365 Copilot is covered only at the level of its Agent Skills binding (`agentSkills[]` / `agent_skills[]`) — its declarative agents and Copilot Studio artifacts are a different product family and belong to the dedicated finder. Out of scope — always-on instruction files (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, rules, steering), MCP servers as such, consumer-app "skills" with no file format (grok.com, Grok Bot), and Copilot Studio / declarative agents.

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
| `agents` | `all` | Comma list of agent ids from `references/compatibility-matrix.md` (e.g. `claude-code,codex,cursor`). Narrows which native layouts, registries, and install commands are searched and reported. `all` runs the cross-agent sources and reports compatibility for every agent in the matrix |
| `require_native` | `false` | When true, only rows with level-1 or level-2 compatibility evidence for at least one requested agent enter `Catalog`; portable-only finds go to the appendix |

**Clarify before starting only if `topic` is genuinely ambiguous** — a bare "find me some skills"
with no domain. A topic that is merely broad is not ambiguous; decompose it instead.

State the resolved arguments in one line before beginning, so the run is reproducible:

> Researching **<topic>** for the target agents · depth `standard` · max 25 · min score 50 · outputs report+xlsx · as of <date>

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

Budget roughly: 35% cross-agent sources (skills.sh, the Agent Skills adopter list, multi-agent collections with per-agent manifests), 35% the first-party registries of the requested agents (official marketplaces and catalogs — read their manifests, not their rendered pages), 30% GitHub code and topic search on `SKILL.md` and manifest fingerprints. When `agents` is `all`, run the Tier 1 sources of the five major ecosystems (Claude Code, Codex, Gemini/Antigravity, GitHub Copilot, Grok) at minimum.

## 4. Verify — mandatory gate

Nothing enters the ranked table without passing `references/verification.md`. In short:

- **Fetch the URL.** A search snippet is not verification. 404 or redirect-to-org → drop the row.
- **Confirm it is a real target-agent skill** — see `references/artifact-types.md` for the
  exact files and manifests that qualify. A README describing skills is not a skill.
- **Read the actual `SKILL.md` (or the agent-specific manifest for packaged plugins and extensions)** for anything scoring above `min_score`. Score
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
| **Partial** | Only covered incidentally by a broader skill, or by an MCP-only plugin with no authored skill, or a skill whose only evidence for a requested agent is an aggregator tag rather than authored guidance |
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
| `references/compatibility-matrix.md` | Steps 1, 4, 7 — agent ids, native paths, manifests, install commands per agent |

## Quality bar

Before emitting, confirm:

- [ ] Every `Catalog` row has a URL fetched during this run
- [ ] No star count, install count, or date is stated from memory
- [ ] Duplicates collapsed to upstream source repos
- [ ] Every facet from step 2 appears in the gap analysis, including the empty ones
- [ ] Sub-scores shown, not just composites
- [ ] Supply-chain flags set for anything bundling hooks (any agent's event system), scripts, MCP servers, LSP servers, or pre-approved tool grants
- [ ] Ranked table is the first thing after the run header
- [ ] `Sources` sheet lists every query run, including the ones that returned nothing
- [ ] Nothing from a different platform was cataloged as native — a skill is **native** to an agent only with level-1 or level-2 evidence for that agent (see `references/verification.md`); format compatibility alone makes it **Portable**, and the matrix must say so per agent rather than painting every column green

**A short honest catalog outranks a long speculative one.** If a facet has two real skills,
report two.
