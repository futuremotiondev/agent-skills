---
name: fm-antigravity-agent-skill-finder
description: Research and rank Agent Skills, plugins, and extensions for Google's agent surfaces — Antigravity (App, IDE, and the `agy` CLI) and the legacy Gemini CLI extension ecosystem — for a given topic, language, framework, or workflow, then produce a scored Markdown report and an .xlsx catalog. Use this whenever the user asks to find, discover, research, compare, audit, or recommend Antigravity or Gemini skills, plugins, or extensions — including phrasings like "what Antigravity skills exist for X", "find me a Gemini CLI extension for Y", "best agy plugins for Z", "is there a Google agent skill that does W", or "audit the Gemini ecosystem for V". Also use when the user wants to know whether coverage exists before writing a skill themselves.
---

# Antigravity & Gemini Agent Skill Finder

Deep-research the Google Antigravity and Gemini CLI skill ecosystem for a requested topic. Produce a verified,
scored, deduplicated catalog — never a plausible-sounding list.

**The failure mode this skill exists to prevent:** inventing skills that don't exist.
This ecosystem forked in mid-2026: Gemini CLI was replaced by Antigravity CLI (`agy`) for consumer tiers, extensions became plugins, and the official Antigravity marketplace has no public source repo. The risk is reporting a Gemini CLI extension as if it were a current Antigravity plugin, citing a gallery entry that was never validated for Antigravity, or treating a bare `SKILL.md` repo tagged `antigravity-skills` as Google-endorsed. Reporting three real skills and an honest gap analysis beats twelve
fabricated rows. Every row in every output must trace to a URL fetched during this run.

**Scope boundary:** In scope — `SKILL.md` skills Antigravity or Gemini CLI load, Antigravity plugins (`plugin.json` with the `antigravity.google` schema), Gemini CLI extensions (`gemini-extension.json`), and the galleries and marketplaces that distribute them. Out of scope — Gemini Code Assist (`.gemini/config.yaml`, `styleguide.md`) and Jules (`AGENTS.md` only), which consume instruction files but have no skill mechanism; the Google Agents CLI (ADK scaffolding), which is a different tool. `GEMINI.md`/`AGENTS.md`/rules files are readiness signals, not skills.

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
| `surface` | `both` | `antigravity` · `gemini-cli` · `both`. Narrows which ecosystem's load paths and registries are searched |

**Clarify before starting only if `topic` is genuinely ambiguous** — a bare "find me some skills"
with no domain. A topic that is merely broad is not ambiguous; decompose it instead.

State the resolved arguments in one line before beginning, so the run is reproducible:

> Researching **<topic>** for Antigravity · depth `standard` · max 25 · min score 50 · outputs report+xlsx · as of <date>

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

Budget roughly: 40% first-party sources (the geminicli.com gallery, `gemini-cli-extensions` org, Google vendor orgs, Antigravity marketplace), 35% GitHub code and topic search, 25% cross-platform aggregators. Scrape the gallery browse page early — it is ~2,200 pre-validated candidates with component tags, and Google's own crawler keys on the `gemini-cli-extension` topic.

## 4. Verify — mandatory gate

Nothing enters the ranked table without passing `references/verification.md`. In short:

- **Fetch the URL.** A search snippet is not verification. 404 or redirect-to-org → drop the row.
- **Confirm it is a real Antigravity skill** — see `references/artifact-types.md` for the
  exact files and manifests that qualify. A README describing skills is not a skill.
- **Read the actual `SKILL.md` (or the extension/plugin manifest for packaged bundles)** for anything scoring above `min_score`. Score
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
| **Partial** | Only covered incidentally by a broader skill, or by an MCP-only extension with no authored skill, or a Gemini CLI extension that needs `agy plugin import gemini` to work on Antigravity rather than authored guidance |
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
- [ ] Supply-chain flags set for anything bundling hooks, scripts, MCP servers, `excludeTools` overrides, or sensitive `settings[]` env vars
- [ ] Ranked table is the first thing after the run header
- [ ] `Sources` sheet lists every query run, including the ones that returned nothing
- [ ] Nothing from a different platform was cataloged as native — a Gemini CLI extension with `gemini-extension.json` is **Portable** to Antigravity (via `agy plugin import gemini`), not native; a repo tagged `antigravity-skills` that is only a `SKILL.md` tree is format-compatible but not Google-endorsed

**A short honest catalog outranks a long speculative one.** If a facet has two real skills,
report two.
