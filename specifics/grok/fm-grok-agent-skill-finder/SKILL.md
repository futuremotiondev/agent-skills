---
name: fm-grok-agent-skill-finder
description: Research and rank skills, plugins, and plugin marketplaces for xAI's Grok Build coding agent (the `grok` CLI) for a given topic, language, framework, or workflow, then produce a scored Markdown report and an .xlsx catalog. Covers the official xai-org plugin marketplace, native `.grok-plugin/` packages, and the Claude Code and Agent Skills corpora that Grok Build consumes with zero configuration. Use this whenever the user asks to find, discover, research, compare, audit, or recommend Grok skills or plugins — including phrasings like "what Grok Build skills exist for X", "find me a Grok plugin for Y", "best plugins in the xAI marketplace for Z", "is there a grok skill that does W", or "audit the Grok ecosystem for V". Also use when the user wants to know whether Grok coverage exists before writing a skill themselves.
---

# Grok Build Agent Skill Finder

Deep-research the xAI Grok Build skill ecosystem for a requested topic. Produce a verified,
scored, deduplicated catalog — never a plausible-sounding list.

**The failure mode this skill exists to prevent:** inventing skills that don't exist.
Grok Build reads Claude Code marketplaces, skills, and plugins natively, so the installable corpus is huge while the Grok-*specific* corpus is small (one official catalog of ~36 plugins, a 32-repo topic tag, one awesome-list). The risk is cataloging every Claude Code skill as a "Grok skill" with no Grok intent, mixing in the consumer "Grok Skills" feature on grok.com or Grok Bot skills (different products, no file format), or citing the `grok` log-parser namespace (Logstash/fluentd) by keyword accident. Reporting three real skills and an honest gap analysis beats twelve
fabricated rows. Every row in every output must trace to a URL fetched during this run.

**Scope boundary:** In scope — `SKILL.md` skills Grok Build loads (`.grok/skills/`, `~/.agents/skills/`, plugin `skills/`), Grok plugins (`.grok-plugin/plugin.json` or Claude/Cursor manifests Grok reads), and marketplaces (`.grok-plugin/marketplace.json`, `.claude-plugin/marketplace.json`). Out of scope — consumer **Grok Skills** on grok.com/iOS/Android (conversational, no file format); **Grok Bot** skills, routines, and the `x.ai/bot/marketplace`; xAI API server-side tools (`web_search`, `code_interpreter`, collections); the `grok-code-fast-1` model ("Grok Code" is a model, not an agent). `AGENTS.md` / `CLAUDE.md` / `.grok/rules/` are readiness signals, not skills.

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

> Researching **<topic>** for Grok · depth `standard` · max 25 · min score 50 · outputs report+xlsx · as of <date>

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

Budget roughly: 40% first-party (`xai-org/plugin-marketplace` catalog and its generated `plugin-index.json`), 35% GitHub code and topic search for `.grok-plugin/` and `.grok/skills/`, 25% the Claude Code / Agent Skills corpus that Grok consumes. Parse the official `marketplace.json` first — its `keywords` and `domains` fields were designed to match requests, and `plugin-index.json` tells you which skills each plugin ships without cloning.

## 4. Verify — mandatory gate

Nothing enters the ranked table without passing `references/verification.md`. In short:

- **Fetch the URL.** A search snippet is not verification. 404 or redirect-to-org → drop the row.
- **Confirm it is a real Grok skill** — see `references/artifact-types.md` for the
  exact files and manifests that qualify. A README describing skills is not a skill.
- **Read the actual `SKILL.md` (and `.grok-plugin/plugin.json` for plugins)** for anything scoring above `min_score`. Score
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
| **Partial** | Only covered incidentally by a broader skill, or by an MCP-only plugin with no authored skill (most vendor catalog entries), or a Claude-format plugin with no Grok-specific `when-to-use` tuning rather than authored guidance |
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
- [ ] Supply-chain flags set for anything bundling hooks, scripts, MCP servers, or `.lsp.json` language servers
- [ ] Ranked table is the first thing after the run header
- [ ] `Sources` sheet lists every query run, including the ones that returned nothing
- [ ] Nothing from a different platform was cataloged as native — a repo with only `.claude-plugin/` is installable by Grok but is **Portable**, not native — native means `.grok-plugin/`, a `grok plugin install` README snippet, `when-to-use` frontmatter, or an entry in the xAI catalog; and the consumer grok.com "Skills" feature and Grok Bot skills are different products entirely

**A short honest catalog outranks a long speculative one.** If a facet has two real skills,
report two.
