---
name: fm-ms365-copilot-agent-skill-finder
description: Research and rank Microsoft 365 Copilot extensions — declarative agents, Copilot plugins, Agent Skills (SKILL.md), Copilot connectors, Copilot Studio agents and templates, and custom engine agents — for a given business scenario, data source, or workflow, then produce a scored Markdown report and an .xlsx catalog. Use this whenever the user asks to find, discover, research, compare, audit, or recommend Microsoft 365 Copilot or Copilot Studio agents, plugins, skills, or connectors — including phrasings like "what M365 Copilot agents exist for X", "find a declarative agent for Y", "best Copilot Studio templates for Z", "is there a Copilot connector for W", or "audit the Microsoft 365 Copilot extensibility ecosystem for V". NOT for GitHub Copilot — that is a different product with a different finder.
---

# Microsoft 365 Copilot Extension Finder

Deep-research the Microsoft 365 Copilot extension ecosystem for a requested topic. Produce a verified,
scored, deduplicated catalog — never a plausible-sounding list.

**The failure mode this skill exists to prevent:** inventing extensions that don't exist.
Microsoft 365 Copilot has no single SKILL.md-style unit: the deployable artifact is an app package containing a declarative agent manifest, and Agent Skills support is new and preview-only. The word "skill" is overloaded across Microsoft docs (actions, Bot Framework skills, Office skills, Copilot Studio skills). The risk is cataloging a GitHub Copilot skill, a generic SKILL.md repo, or an Office Add-in as an M365 Copilot extension — or treating an Agent Builder instruction block as a deployable package. Reporting three real extensions and an honest gap analysis beats twelve
fabricated rows. Every row in every output must trace to a URL fetched during this run.

**Scope boundary:** In scope — app packages with `copilotAgents`, `agentSkills`, or `agentConnectors` in `manifest.json`; declarative agent manifests (`declarativeAgent*.json`, schema v1.x); API/MCP plugin manifests (`schema_version: v2.x`); Agent Skills directories referenced by `agent_skills[]` / `agentSkills[]`; Copilot connectors; Copilot Studio agents, templates, and the Agent Library; custom engine agents built on the Microsoft 365 Agents SDK, Teams SDK, or Foundry; AppSource/Agent Store listings. Out of scope — **GitHub Copilot** customizations (`.github/skills/`, `copilot-instructions.md`, `.agent.md`), Office Add-ins that are not Copilot extensions, and the Microsoft Learn training page confusingly titled "agent skills".

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
| `types` | `all` | Comma list of `agent`, `plugin`, `skill`, `connector`, `studio`, `cea` to narrow the extension types searched |
| `source_form` | `both` | `code` (GitHub source), `store` (AppSource / Agent Store listings), or `both` |

**Clarify before starting only if `topic` is genuinely ambiguous** — a bare "find me some extensions"
with no domain. A topic that is merely broad is not ambiguous; decompose it instead.

State the resolved arguments in one line before beginning, so the run is reproducible:

> Researching **<topic>** for M365 Copilot · depth `standard` · max 25 · min score 50 · outputs report+xlsx · as of <date>

## 2. Decompose the topic

Split the topic into 4–10 **facets** before searching. Multi-part requests (a language *and* its
frameworks *and* its migration paths) are several searches, not one.

For each facet record: the canonical name, known aliases and abbreviations, adjacent ecosystem terms,
and the vocabulary a extension author would actually use in a description or manifest. Search the
author's vocabulary, not the user's — a WinUI 3 extension may describe itself as "Windows desktop",
"Fluent", "WinAppSDK", or "XAML" and never say "WinUI".

Present the facet list before searching. It is the outline of the final report.

## 3. Discover

Work the sources in `references/discovery-sources.md` in tier order. Do not stop at aggregator
sites — they lag and duplicate. Reach the upstream repository for everything you intend to rank.

Budget roughly: 45% first-party sources (Microsoft and PnP sample repos, Agent Library, Microsoft Learn), 30% GitHub code search on manifest fingerprints, 25% AppSource and community lists. Read `pnp/copilot-pro-dev-samples` and `microsoft/m365-agent-templates` first — they are the richest verified corpora, and the `da-` folder prefix is a free classifier.

## 4. Verify — mandatory gate

Nothing enters the ranked table without passing `references/verification.md`. In short:

- **Fetch the URL.** A search snippet is not verification. 404 or redirect-to-org → drop the row.
- **Confirm it is a real M365 Copilot extension** — see `references/artifact-types.md` for the
  exact files and manifests that qualify. A README describing extensions is not a extension.
- **Read the actual `declarativeAgent.json` (agents), `SKILL.md` (skills), or the plugin manifest — whichever the extension type dictates** for anything scoring above `min_score`. Score
  comprehensiveness from content, never from repo stars or marketing copy.
- **Never state a star count, install count, or date from memory.** Fetched this run, or omitted.
- **Canonicalize.** The same extension is vendored across many registries and collections. Resolve
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
| **Covered** | A dedicated, verified extension scoring ≥ `min_score` |
| **Partial** | Only covered incidentally by a broader extension, or by a connector or MCP plugin with no authored agent instructions, or a Copilot Studio template that must be rebuilt rather than installed rather than authored guidance |
| **Adjacent** | Nothing direct; the nearest real thing needs adaptation |
| **Portable** | Nothing native, but a verified skill for another agent exists that the open Agent Skills format makes usable here — see `references/artifact-types.md` for what ports cleanly |
| **Uncovered** | Nothing found. Say so plainly. |

For **Partial**, **Adjacent**, **Portable**, and **Uncovered** facets, propose what the user would
author themselves: a one-line description draft, the reference files it would need, and any
existing extension worth forking or porting. Under-served facets are build opportunities, and saying
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
- [ ] Supply-chain flags set for anything bundling API/MCP actions with write scopes, connectors with broad Graph permissions, skills bundling scripts, or custom engine agents requiring Azure hosting
- [ ] Ranked table is the first thing after the run header
- [ ] `Sources` sheet lists every query run, including the ones that returned nothing
- [ ] Nothing from a different platform was cataloged as native — **GitHub Copilot and Microsoft 365 Copilot are different products.** A repo whose only Copilot content is `.github/copilot-instructions.md`, `.github/skills/`, or `.agent.md` files is GitHub Copilot — exclude it unless `manifest.json` with `copilotAgents`/`agentSkills` is also present. A `declarative-agents` skill in `github/awesome-copilot` is a GitHub Copilot skill *about authoring* M365 agents, not an M365 extension

**A short honest catalog outranks a long speculative one.** If a facet has two real extensions,
report two.
