---
name: fm-claude-agent-skill-finder
description: Research and rank Claude Code compatible Agent Skills, plugins, and marketplaces for a given topic, language, framework, or workflow, then produce a scored Markdown report and an .xlsx catalog. Use this whenever the user asks to find, discover, research, compare, audit, or recommend skills or plugins — including phrasings like "what skills exist for X", "find me a plugin for Y", "best agent skills for Z", "is there a skill that does W", or "audit the skill ecosystem for V". Also use when the user wants to know whether coverage exists before building a skill themselves.
---

# Agent Skill Finder

Deep-research the Claude Code skill and plugin ecosystem for a requested topic. Produce a
verified, scored, deduplicated catalog — never a plausible-sounding list.

**The failure mode this skill exists to prevent:** inventing skills that don't exist. Niche topics
(desktop UI frameworks, older language versions, regional tooling) genuinely have thin coverage.
Reporting three real skills and an honest gap analysis beats twelve fabricated rows. Every row in
every output must trace to a URL fetched during this run.

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
| `exclude` | none | Author, org, or marketplace to skip |

**Clarify before starting only if `topic` is genuinely ambiguous** — a bare "find me some skills"
with no domain. A topic that is merely broad is not ambiguous; decompose it instead.

State the resolved arguments in one line before beginning, so the run is reproducible:

> Researching **<topic>** · depth `standard` · max 25 · min score 50 · outputs report+xlsx · as of 2026-08-11

## 2. Decompose the topic

Split the topic into 4–10 **facets** before searching. Multi-part requests (a language *and* its
frameworks *and* its migration paths) are several searches, not one.

For each facet record: the canonical name, known aliases and abbreviations, adjacent ecosystem terms,
and the vocabulary a skill author would actually use in a `description:` field. Search the author's
vocabulary, not the user's — a WinUI 3 skill may describe itself as "Windows desktop", "Fluent",
"WinAppSDK", or "XAML" and never say "WinUI".

Present the facet list before searching. It is the outline of the final report.

## 3. Discover

Work the sources in `references/discovery-sources.md` in tier order. Do not stop at aggregator
sites — they lag and duplicate. Reach the upstream repository for everything you intend to rank.

Budget roughly: 40% first-party registries, 35% GitHub code and topic search, 25% aggregators and
community lists.

## 4. Verify — mandatory gate

Nothing enters the ranked table without passing `references/verification.md`. In short:

- **Fetch the URL.** A search snippet is not verification. 404 or redirect-to-org → drop the row.
- **Confirm it is a real skill or plugin** — a `SKILL.md` with valid frontmatter, or a
  `.claude-plugin/plugin.json` / `marketplace.json` entry. A README describing skills is not a skill.
- **Read the actual `SKILL.md`** for anything scoring above `min_score`. Score comprehensiveness
  from content, never from repo stars or marketing copy.
- **Never state a star count, install count, or date from memory.** Fetched this run, or omitted.
- **Canonicalize.** The same skill is vendored across many marketplaces. Resolve to the upstream
  source repo and record mirrors as a count, not as separate rows.

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
| **Covered** | A dedicated, verified skill or plugin scoring ≥ `min_score` |
| **Partial** | Only covered incidentally by a broader skill, or by an LSP/MCP plugin rather than authored guidance |
| **Adjacent** | Nothing direct; the nearest real thing needs adaptation |
| **Uncovered** | Nothing found. Say so plainly. |

For **Partial**, **Adjacent**, and **Uncovered** facets, propose what the user would author
themselves: a one-line `description:` draft, the reference files it would need, and any existing
skill worth forking. Under-served facets are build opportunities, and saying "no coverage" is a
correct, useful result.

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
- [ ] Supply-chain flags set for anything bundling hooks, scripts, or MCP servers
- [ ] Ranked table is the first thing after the run header
- [ ] `Sources` sheet lists every query run, including the ones that returned nothing

**A short honest catalog outranks a long speculative one.** If a facet has two real skills, report
two.
