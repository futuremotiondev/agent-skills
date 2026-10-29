# Output Specification

## Markdown report

Emit as a `.md` file when `report` is in `outputs`. Section order is fixed.

### 1. Run header — 4 lines max

Topic, platform (Microsoft 365 Copilot), resolved arguments, counts (candidates found / verified /
cataloged / dropped), timestamp.

### 2. Ranked catalog table — FIRST, always

Immediately after the header. Not after methodology, not after a summary paragraph. This is the
deliverable; everything else is support.

```markdown
| # | Name | Type | Score | Authority | Fit | Stars | Updated | Flags | Source |
|---|------|------|-------|-----------|-----|-------|---------|-------|--------|
| 1 | ... | Agent | 84 | Microsoft | Purpose-built | 3.1k | 2026-07 | — | [repo](url) |
| 2 | ... | Plugin | 71 | Certified ISV | Strong | 890 | 2026-05 | `remote-mcp` `preview` | [repo](url) |
```

- `Type`: `Agent` (declarative) · `Plugin` · `Skill` · `Connector` · `Studio Template` · `CEA` (custom engine agent) · `Instructions` · `Store Listing`
- `Score`: composite only here; full breakdown goes in the per-entry section
- `Stars`: fetched this run, or blank. Never a guess.
- `Flags`: supply-chain flags from `verification.md`, or `—`
- Sort by score descending. Cap at `max_results`; overflow to §6.

### 3. Coverage summary by facet

One row per facet from step 2 of the workflow, **including the empty ones**.

```markdown
| Facet | Coverage | Best option | Score |
|-------|----------|-------------|-------|
| <facet> | Covered | <name> | 84 |
| <facet> | Portable | <name> (built for <other agent>) | 58 |
| <facet> | Uncovered | — | — |
```

### 4. Per-entry detail

For each cataloged entry, in rank order:

```markdown
### <n>. <Name> — <score> (<band>)

**Auth <n> / Comp <n> / Adopt <n> / Maint <n> / Fit <n>**
<one line: what it is good at, and the one thing it does not cover>

- **Source:** <url> · **Author:** <who> · **Verified:** <timestamp>
- **Install:** the acquisition path — `atk install --file-path <pkg.zip> --scope Personal` (sideload), admin center **Agents > All agents** or **Agents > Tools > Registry > Upload**, Agent Store install, Copilot Studio Agent Library "Customize & download", `atk new sample <name>` / `git clone` for source, or `wiqd plugin import <source>` for Agent-Plugins-format sources
- **Compatibility evidence:** <level 1–4 from verification.md, with the sentence or file that proves it>
- **Contents:** <primary artifact size, app package with agent manifest, plugin/OpenAPI definitions, skills, and toolkit pipeline>
- **Flags:** <supply-chain flags with one line of context, or none>
- **Mirrors:** <count, if vendored elsewhere>
```

Keep to ~8 lines. This section is scannable reference, not prose.

### 5. Gap analysis and build recommendations

The section that most often justifies the run.

For every **Partial**, **Adjacent**, **Portable**, or **Uncovered** facet:

```markdown
### <facet> — <classification>

<one or two sentences on what exists and why it falls short>

**Build it yourself:**
- **Suggested name:** `<slug>`
- **Draft description:** `<a real trigger-rich description>`
- **Native format to use:** <the M365 Copilot artifact type from artifact-types.md>
- **References it would need:** <list>
- **Closest thing to fork or port:** <url, or "nothing close">
```

Draft a real description — the trigger phrasing is the hardest part of authoring and the most
useful thing to hand over.

### 6. Also found — below threshold

Everything verified but scoring under `min_score`. Compact table, one line of why each was excluded.
Documents that they were evaluated rather than missed.

### 7. Unverified

Only when `include_unverified` is true. Claim, source of claim, what was attempted, why it failed.
Never formatted to resemble §2.

### 8. Method and coverage

Sources worked, query count, what was **not** searched and why. If the depth budget was hit before
all facets were covered, say which facets were left and what queries remain unrun.

---

## Excel workbook

Emit `.xlsx` when `xlsx` is in `outputs`. **Four sheets.**

### Sheet 1 — `Catalog`

One row per verified entry. Freeze the header row, autofilter on, columns sized to content.

| Column | Notes |
|---|---|
| Rank | |
| Name | |
| Type | `Agent` (declarative) · `Plugin` · `Skill` · `Connector` · `Studio Template` · `CEA` (custom engine agent) · `Instructions` · `Store Listing` |
| Platform | `M365 Copilot` — constant for this skill; present so workbooks from sibling finders can be merged |
| Category | Top-level facet |
| Subcategory | Specific facet |
| Score | 0–100 |
| Band | Essential · Recommended · Situational · Marginal |
| Authority Score | 0–30 |
| Comprehensiveness Score | 0–25 |
| Adoption Score | 0–20 |
| Maintenance Score | 0–15 |
| Fit Score | 0–10 |
| Authority Tier | Named band |
| Author / Org | |
| Upstream Repo URL | The canonical source, not the mirror |
| Artifact Path | Path within the repo to the primary artifact |
| Artifact Format | `manifest.json` + `declarativeAgent.json` · plugin `v2.x` JSON · `SKILL.md` · `main.tsp` · connector `Manifest.json` · Copilot Studio export `.zip` · AppSource listing |
| Registry | Where listed, or blank |
| Install Command | Exact command or acquisition step |
| Compatibility Evidence | 1–4 per `verification.md` |
| Homepage | |
| License | |
| Stars | Blank if not fetched — never guessed |
| Installs | Blank if not fetched |
| Last Updated | ISO date |
| Freshness | Current · Aging · Stale · Archived |
| Primary Artifact Lines | Rough size |
| Extension Type | `agent` · `plugin` · `skill` · `connector` · `studio` · `cea` |
| Schema Version | declarative agent `v1.x` · plugin `v2.x` · manifest `1.xx` |
| Source Form | `code` · `store` · `template` |
| Certification | `certified` · `attested` · `n/a` — from AppSource / admin center when fetched |
| Tenant Gated | Y/N — requires tenant login to view or install |
| Risk Flags | Comma-separated |
| Mirror Count | |
| Strength | One line |
| Limitation | One line — the thing it does not cover |
| Verified | Y/N |
| Verified At | Timestamp |

### Sheet 2 — `Gaps`

| Facet | Category | Coverage | Best Existing | Best Score | Suggested Name | Draft Description | Native Format | Fork / Port Candidate |

One row per facet, including covered ones — a complete picture is more useful than a filtered one.

### Sheet 3 — `Sources`

| Source | Type | URL | Queried At | Results Found | Results Verified | Notes |

**Include queries that returned nothing.** Null results are evidence for the gap analysis and are
what make a repeat run comparable.

### Sheet 4 — `Run Log`

Key–value: topic, platform, resolved arguments, `as_of`, tool-call count, elapsed, candidates
found, verified, dropped with reasons grouped, unverified count, budget hit Y/N, and any drift
noticed in `discovery-sources.md` (renamed registries, moved repos, dead aggregators, changed CLI
commands).

The Run Log is what makes this skill reusable across topics — it lets a later run tell "the
ecosystem changed" apart from "the search was shallower this time".

---

## Conventions

- **Empty cells over guesses.** A blank `Stars` is honest; a fabricated one poisons every other cell.
- **ISO dates** throughout (`2026-10-24`).
- **Upstream URLs**, not aggregator listing pages, in `Upstream Repo URL`.
- **Exact install commands** — copy-pasteable, not paraphrased.
- Filenames: `ms365-copilot-research-<topic-slug>-<YYYY-MM-DD>.md` / `.xlsx`.

## JSON output

When `json` is in `outputs`, emit `Catalog` and `Gaps` as a single JSON document with the same field
names in `snake_case`, plus a `run` object mirroring the Run Log. For piping into other tooling, and
for merging with sibling finders' output.

## Install output

When `install` is in `outputs`, append a fenced block of the exact commands for every entry scoring
≥ `min_score`, ordered by rank, with any registry-add or prerequisite lines first and de-duplicated:

```bash
# source samples
git clone https://github.com/pnp/copilot-pro-dev-samples   # then samples/da-<name>
atk new sample <sample-name>
# templates
git clone https://github.com/microsoft/m365-agent-templates.git
# sideload a built package
atk install --file-path ./appPackage/build/appPackage.zip --scope Personal
# import an Agent-Plugins / Claude / Cursor plugin as an M365 plugin
wiqd plugin import <source>
atk import openplugin --path ./my-plugin --output ./my-plugin-project --privacy-url <url> --terms-url <url>
```

Commands only — no commentary inside the block, so it can be pasted wholesale. Store items have no CLI — give the AppSource URL and the admin-center path instead. Mark anything that requires the Frontier Program or the `wiqd` preview surface.
