---
name: fm-github-copilot-agent-skill-finder
description: Research and rank GitHub Copilot customizations — Agent Skills (SKILL.md), custom agents (.agent.md), repository and path-specific instructions, prompt files, hooks, and Copilot CLI plugins and marketplaces — for a given topic, language, framework, or workflow, then produce a scored Markdown report and an .xlsx catalog. Covers the Copilot cloud/coding agent, Copilot CLI, Copilot code review, and Copilot in VS Code, Visual Studio, and JetBrains. Use this whenever the user asks to find, discover, research, compare, audit, or recommend GitHub Copilot skills, agents, instructions, prompts, or plugins — including phrasings like "what Copilot skills exist for X", "find me a custom agent for Y", "best copilot-instructions for Z", "is there an awesome-copilot entry for W", or "audit the Copilot customization ecosystem for V". NOT for Microsoft 365 Copilot — that is a different product with a different finder.
---

# GitHub Copilot Customization Finder

Deep-research the GitHub Copilot customization ecosystem for a requested topic. Produce a verified,
scored, deduplicated catalog — never a plausible-sounding list.

**The failure mode this skill exists to prevent:** inventing customizations that don't exist.
GitHub Copilot reads `.claude/skills/` and `.agents/skills/` natively, so nearly every Agent Skills repo on GitHub is technically Copilot-compatible — the risk is cataloging the whole SKILL.md universe as "Copilot skills" with no Copilot-specific intent, mixing in Microsoft 365 Copilot agents because the names collide, or citing the sunset GitHub-App Copilot Extensions as current. Reporting three real customizations and an honest gap analysis beats twelve
fabricated rows. Every row in every output must trace to a URL fetched during this run.

**Scope boundary:** In scope — `SKILL.md` skills under `.github/skills/`, `.claude/skills/`, or `.agents/skills/`; custom agents `.github/agents/*.agent.md` (and `.md`); repository instructions `.github/copilot-instructions.md`; path-specific `.github/instructions/**/*.instructions.md`; prompt files `.github/prompts/*.prompt.md`; hooks `.github/hooks/*.json`; Copilot CLI plugins (`plugin.json`) and marketplaces (`.github/plugin/marketplace.json`, `.claude-plugin/marketplace.json`). Out of scope — **Microsoft 365 Copilot** declarative agents, Copilot Studio, Agents Toolkit (`learn.microsoft.com/microsoft-365/copilot/*`); GitHub-App-based Copilot Extensions (sunset 2025-11-10); VS Code chat-participant extensions unless the topic asks for them. `AGENTS.md` / `CLAUDE.md` are readiness signals, not customizations to rank.

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
| `types` | `all` | Comma list of `skill`, `agent`, `instructions`, `prompt`, `hook`, `plugin` to narrow the customization types searched |
| `surface` | `all` | `cloud-agent` · `cli` · `vscode` · `code-review` · `all` — filters by the support matrix |

**Clarify before starting only if `topic` is genuinely ambiguous** — a bare "find me some customizations"
with no domain. A topic that is merely broad is not ambiguous; decompose it instead.

State the resolved arguments in one line before beginning, so the run is reproducible:

> Researching **<topic>** for GitHub Copilot · depth `standard` · max 25 · min score 50 · outputs report+xlsx · as of <date>

## 2. Decompose the topic

Split the topic into 4–10 **facets** before searching. Multi-part requests (a language *and* its
frameworks *and* its migration paths) are several searches, not one.

For each facet record: the canonical name, known aliases and abbreviations, adjacent ecosystem terms,
and the vocabulary a customization author would actually use in a description or manifest. Search the
author's vocabulary, not the user's — a WinUI 3 customization may describe itself as "Windows desktop",
"Fluent", "WinAppSDK", or "XAML" and never say "WinUI".

Present the facet list before searching. It is the outline of the final report.

## 3. Discover

Work the sources in `references/discovery-sources.md` in tier order. Do not stop at aggregator
sites — they lag and duplicate. Reach the upstream repository for everything you intend to rank.

Budget roughly: 45% first-party sources (`github/awesome-copilot` via `llms.txt` and its `marketplace` branch, `github/copilot-plugins`, `microsoft/skills`), 30% GitHub code search on the exact file globs, 25% cross-platform aggregators. Fetch `awesome-copilot.github.com/llms.txt` first — it is a machine-readable index of ~222 agents and ~90 instruction sets plus skills.

## 4. Verify — mandatory gate

Nothing enters the ranked table without passing `references/verification.md`. In short:

- **Fetch the URL.** A search snippet is not verification. 404 or redirect-to-org → drop the row.
- **Confirm it is a real GitHub Copilot customization** — see `references/artifact-types.md` for the
  exact files and manifests that qualify. A README describing customizations is not a customization.
- **Read the actual `SKILL.md`, `*.agent.md`, `*.instructions.md`, or `*.prompt.md` — whichever the customization type dictates** for anything scoring above `min_score`. Score
  comprehensiveness from content, never from repo stars or marketing copy.
- **Never state a star count, install count, or date from memory.** Fetched this run, or omitted.
- **Canonicalize.** The same customization is vendored across many registries and collections. Resolve
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
| **Covered** | A dedicated, verified customization scoring ≥ `min_score` |
| **Partial** | Only covered incidentally by a broader customization, or by an MCP server configuration with no authored guidance, or a `copilot-instructions.md` that mentions the facet in one line rather than authored guidance |
| **Adjacent** | Nothing direct; the nearest real thing needs adaptation |
| **Portable** | Nothing native, but a verified skill for another agent exists that the open Agent Skills format makes usable here — see `references/artifact-types.md` for what ports cleanly |
| **Uncovered** | Nothing found. Say so plainly. |

For **Partial**, **Adjacent**, **Portable**, and **Uncovered** facets, propose what the user would
author themselves: a one-line description draft, the reference files it would need, and any
existing customization worth forking or porting. Under-served facets are build opportunities, and saying
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
- [ ] Supply-chain flags set for anything bundling hooks, `allowed-tools: shell` grants, MCP servers, or plugin LSP configs
- [ ] Ranked table is the first thing after the run header
- [ ] `Sources` sheet lists every query run, including the ones that returned nothing
- [ ] Nothing from a different platform was cataloged as native — **Microsoft 365 Copilot is a different product** — exclude anything about declarative agents, Copilot Studio, Agent Store, or `learn.microsoft.com/microsoft-365/copilot`. Separately, a bare `SKILL.md` under `.claude/skills/` is **Portable** (Copilot reads it) but not Copilot-native unless it sits under `.github/skills/`, documents a Copilot surface, or is listed in awesome-copilot

**A short honest catalog outranks a long speculative one.** If a facet has two real customizations,
report two.
