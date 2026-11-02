---
name: fm-codex-agent-skill-finder
description: Research and rank OpenAI Codex compatible Agent Skills, plugins, and plugin marketplaces for a given topic, language, framework, or workflow, then produce a scored Markdown report and an .xlsx catalog. Covers Codex CLI, the Codex IDE extension, Codex in the ChatGPT desktop app, and the shared ChatGPT/Codex plugin directory. Use this whenever the user asks to find, discover, research, compare, audit, or recommend Codex skills or plugins — including phrasings like "what Codex skills exist for X", "find me a Codex plugin for Y", "best skills for Codex CLI", "is there an OpenAI skill that does W", or "audit the Codex ecosystem for V". Also use when the user wants to know whether Codex coverage exists before writing a skill themselves.
---

# Codex Agent Skill Finder

Deep-research the OpenAI Codex skill ecosystem for a requested topic. Produce a verified,
scored, deduplicated catalog — never a plausible-sounding list.

**The failure mode this skill exists to prevent:** inventing skills that don't exist.
Codex speaks the open Agent Skills standard, so the corpus is large and heavily cross-posted — the risk is less "nothing exists" and more cataloging the same skill five times under different marketplaces, or listing a Claude-only plugin as Codex-native because the formats look identical. Reporting three real skills and an honest gap analysis beats twelve
fabricated rows. Every row in every output must trace to a URL fetched during this run.

**Scope boundary:** In scope — `SKILL.md` skills Codex loads, Codex/ChatGPT plugins (`plugin.json` / `.codex-plugin/plugin.json`), and the marketplaces that distribute them. Out of scope — ChatGPT custom GPTs, ChatGPT Projects, and Apps SDK apps (`chatgpt.com/apps`) unless they ship a plugin with a `skills/` folder; `AGENTS.md` files are repo-readiness signals, not skills. Do not confuse the `openai/skills` catalog (deprecated) with `openai/plugins` (current).

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

**Clarify before starting only if `topic` is genuinely ambiguous** — a bare "find me some skills"
with no domain. A topic that is merely broad is not ambiguous; decompose it instead.

State the resolved arguments in one line before beginning, so the run is reproducible:

> Researching **<topic>** for Codex · depth `standard` · max 25 · min score 50 · outputs report+xlsx · as of <date>

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

Budget roughly: 40% first-party sources (`openai/plugins`, `openai/skills`, official marketplaces), 35% GitHub code and topic search, 25% cross-platform aggregators. Read the `.agents/plugins/marketplace.json` manifests first — one fetch yields dozens of verified candidates with upstream URLs already resolved.

## 4. Verify — mandatory gate

Nothing enters the ranked table without passing `references/verification.md`. In short:

- **Fetch the URL.** A search snippet is not verification. 404 or redirect-to-org → drop the row.
- **Confirm it is a real Codex skill** — see `references/artifact-types.md` for the
  exact files and manifests that qualify. A README describing skills is not a skill.
- **Read the actual `SKILL.md` (and `agents/openai.yaml` when present)** for anything scoring above `min_score`. Score
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
| **Partial** | Only covered incidentally by a broader skill, or by an MCP-only plugin with no authored skill rather than authored guidance |
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

## Quality bar

Before emitting, confirm:

- [ ] Every `Catalog` row has a URL fetched during this run
- [ ] No star count, install count, or date is stated from memory
- [ ] Duplicates collapsed to upstream source repos
- [ ] Every facet from step 2 appears in the gap analysis, including the empty ones
- [ ] Sub-scores shown, not just composites
- [ ] Supply-chain flags set for anything bundling hooks, scripts, MCP servers, or `allow_implicit_invocation` policies
- [ ] Ranked table is the first thing after the run header
- [ ] `Sources` sheet lists every query run, including the ones that returned nothing
- [ ] Nothing from a different platform was cataloged as native — a Claude Code plugin whose `.claude-plugin/marketplace.json` Codex merely tolerates is **Portable**, not native, unless it also ships `agents/openai.yaml`, `plugin.json`, or documents a Codex install path

**A short honest catalog outranks a long speculative one.** If a facet has two real skills,
report two.
