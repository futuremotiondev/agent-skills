# Scoring Rubric

Weighted 0–100. Bands, not fake precision — score each dimension to the nearest band and show the
sub-scores so a reader can disagree with a specific number rather than the total.

| Dimension | Weight |
|---|---|
| Authority | 30 |
| Comprehensiveness | 25 |
| Adoption | 20 |
| Maintenance | 15 |
| Topic Fit | 10 |

Supply-chain risk is **not** scored. It is reported as flags (see `verification.md`) so the user
applies their own tolerance.

---

## Authority — 30

Who stands behind it. Bands are specific to the GitHub Copilot ecosystem.

| Band | Points | Criteria |
|---|---|---|
| GitHub-authored | 30 | In `github/copilot-plugins` `plugins/`, GitHub-maintained items in `github/awesome-copilot`, or `github/copilot-advanced-security-plugin` |
| Microsoft / vendor-authored | 27 | `microsoft/skills` (175 Azure SDK + Foundry skills), `microsoft/azure-skills`, `microsoft/skills-for-fabric`, `microsoft/power-platform-skills`, `microsoft/Dataverse-skills`, `microsoft/azure-devops-copilot-plugin`; or any vendor shipping skills for its own product |
| awesome-copilot community | 22 | Merged into `github/awesome-copilot` — code-owner reviewed by `@github/awesome-copilot-core-maintainers`, but community-authored ("sourced from third-party developers") |
| Community-curated | 17 | In `TheSoftwareHouse/copilot-collections`, a skills.sh entry with substantial installs, or `anthropics/skills` (GitHub Docs cite it as a compatible shared source) |
| Established independent | 12 | Recognizable maintainer, sustained commit history, real documentation |
| Unaffiliated | 6 | Real and verified, no institutional signal |
| Anonymous / no history | 2 | Verified to exist, nothing else |

**`github/awesome-copilot` is the de facto official registry** — GitHub-owned, 40k+ stars, MIT, a built-in marketplace that Copilot CLI says "cannot be removed" — but its *contents* are community-contributed. Score the repo's curation as the band above, not as GitHub authorship of each item. **`github/copilot-plugins`** is the official plugins collection; GitHub Docs pages disagree on whether it is still a default marketplace — treat only `awesome-copilot` as guaranteed built-in. **Vendor authorship is the underrated band**: Microsoft's pattern (skills under `.github/skills/`, plugins under `.github/plugins/<name>/`, mirrored `.claude-plugin/`) is the template for vendor-official Copilot skills.

---

## Comprehensiveness — 25

Scored from reading the `SKILL.md`, `*.agent.md`, `*.instructions.md`, or `*.prompt.md` — whichever the customization type dictates, not from stars or README claims.

| Band | Points | Criteria |
|---|---|---|
| Deep, structured | 25 | Substantial body plus bundled `references/` / `scripts/` tree, or bundled agents, hooks, MCP and LSP configs; version-anchored; concrete code; documents anti-patterns and edge cases |
| Solid single-file | 19 | Focused, real code, specific guidance, no reference tree but no filler either |
| Adequate | 13 | Correct and useful, mostly restates official docs, thin on edge cases |
| Thin | 7 | Short, generic, could apply to any technology in its category |
| Stub | 2 | Mostly headings, placeholder text, or obvious generated filler |

**Progressive-disclosure structure is a strong positive signal** — a lean primary file pointing at a
real reference tree usually indicates a deliberate author, and scores above a single sprawling file
of equal word count.

**Length is a weak proxy.** A 900-line artifact of platitudes scores below a 180-line one with real
version-specific guidance.

---

## Adoption — 20

Use fetched numbers only. Missing data → score the band you can defend and mark the cell `unknown`;
do not guess.

| Band | Points | Criteria |
|---|---|---|
| Ecosystem-standard | 20 | Very high stars or installs; referenced by other customizations or registries |
| Widely used | 15 | Clearly popular within its niche; multiple independent mirrors |
| Established | 10 | Real usage signals — forks, issues, contributors |
| Emerging | 6 | Small but genuine activity |
| Unproven | 2 | No measurable signal |

**Discount monorepo stars.** A customization in a 40k-star collection does not inherit those stars.
Weight by whether the collection is *known for* this customization or merely contains it — one of 300
in a grab-bag repo scores at most `Established` on repo stars alone.

`gh skill install` writes provenance (source repo, ref, tree SHA) into installed skill frontmatter — a verification hook, not an adoption signal. skills.sh install counts apply to Copilot-targetable skills (the `skills` CLI writes to `.agents/skills/` or `.github/skills/`). A single item in `awesome-copilot` (40k★) or `microsoft/skills` (3.1k★) does not inherit the repo's stars.

---

## Maintenance — 15

| Band | Points | Criteria |
|---|---|---|
| Active | 15 | Commits within ~3 months; issues answered |
| Maintained | 11 | Commits within ~9 months |
| Dormant | 6 | Older than ~9 months but not archived, and content is still accurate |
| Stale | 3 | Content references superseded versions or removed APIs |
| Archived | 0 | Explicitly archived. Catalog only if it uniquely covers a facet — and say so. |

Judge staleness by **content currency**, not commit date alone. The customization surface reorganized fast: `.chatmode.md` → `.agent.md`; `infer` retired; `mode` dropped from prompt frontmatter; `awesome-copilot` removed its top-level `prompts/`, `chatmodes/`, and `collections/` directories; GitHub-App Copilot Extensions sunset 2025-11-10. Content still using the old names is `Dormant` at best even with recent commits.

---

## Topic Fit — 10

How directly it serves the requested facet.

| Band | Points | Criteria |
|---|---|---|
| Purpose-built | 10 | Written for exactly this facet |
| Strong overlap | 7 | Built for a superset; the facet is a first-class section |
| Incidental | 4 | Touches the facet in passing |
| Adaptable | 2 | Different target, transferable approach |

---

## Composite bands

| Score | Label | Meaning |
|---|---|---|
| 85–100 | Essential | Install without much deliberation |
| 70–84 | Recommended | Strong fit, minor caveats |
| 55–69 | Situational | Useful for specific needs — state which |
| 40–54 | Marginal | Appendix unless the facet is otherwise uncovered |
| < 40 | Not recommended | Exclude, or list only to document that it was evaluated |

## Tie-breaks

In order: **Maintenance** → **Comprehensiveness** → fewer supply-chain flags → upstream original
over mirror → native GitHub Copilot artifact over a ported one.

## Reporting

Show the breakdown. `Score: 78 (Auth 22 / Comp 19 / Adopt 15 / Maint 15 / Fit 7)` lets a reader
disagree with one number instead of dismissing the ranking.

Add a one-line **why** per row that is not a restatement of the score — what it is good at, and the
one thing it does not cover.

## Calibration

Do not compress every candidate into 60–80. If the best find for a facet is genuinely Marginal, say
so — that is the finding, and it is what the gap analysis acts on.

Score against the ecosystem as a whole, not against the other candidates in this run. Five mediocre
customizations do not make the least-mediocre one Recommended.
