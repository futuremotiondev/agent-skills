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

Who stands behind it. Bands are specific to the Microsoft 365 Copilot ecosystem.

| Band | Points | Criteria |
|---|---|---|
| Microsoft-authored | 30 | In `microsoft/*`, `OfficeDev/*`, or `microsoftgraph/*` repos; Agent Library templates (`microsoft/m365-agent-templates`); Microsoft-published AppSource agents |
| Microsoft-certified ISV | 27 | AppSource / Agent Store listing with Microsoft 365 certification (not just publisher attestation), or a vendor shipping its own agent for its own product |
| PnP community (semi-official) | 22 | In `pnp/copilot-pro-dev-samples` — Microsoft-referenced but explicitly "Microsoft doesn't own or curate these samples" |
| Store-listed, attested | 17 | AppSource / Teams Store listing with publisher attestation only; or in the Microsoft Adoption Sample Solution Gallery |
| Established independent | 12 | Recognizable maintainer, sustained commit history, real documentation |
| Unaffiliated | 6 | Real and verified, no institutional signal |
| Anonymous / no history | 2 | Verified to exist, nothing else |

**`OfficeDev/Copilot-for-M365-Samples` was archived 2026-01-02** and redirects to `pnp/copilot-pro-dev-samples` — do not cite the archived repo as current. **Certification vs attestation** is surfaced per agent in the admin center (tenant-authenticated) and on AppSource listings; it is the strongest trust signal available for store items. **Agent Builder instruction collections** (e.g. `kesslernity/awesome-copilot-studio-agents`, 103 instruction sets) are real and popular but are text, not packages — score Authority on the maintainer, not on an implied Microsoft endorsement.

---

## Comprehensiveness — 25

Scored from reading the `declarativeAgent.json` (agents), `SKILL.md` (skills), or the plugin manifest — whichever the extension type dictates, not from stars or README claims.

| Band | Points | Criteria |
|---|---|---|
| Deep, structured | 25 | Substantial body plus bundled app package with agent manifest, plugin/OpenAPI definitions, skills, and toolkit pipeline; version-anchored; concrete code; documents anti-patterns and edge cases |
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
| Ecosystem-standard | 20 | Very high stars or installs; referenced by other extensions or registries |
| Widely used | 15 | Clearly popular within its niche; multiple independent mirrors |
| Established | 10 | Real usage signals — forks, issues, contributors |
| Emerging | 6 | Small but genuine activity |
| Unproven | 2 | No measurable signal |

**Discount monorepo stars.** A extension in a 40k-star collection does not inherit those stars.
Weight by whether the collection is *known for* this extension or merely contains it — one of 300
in a grab-bag repo scores at most `Established` on repo stars alone.

There is no public install-count surface for the Agent Store. AppSource listings show ratings and review counts — fetch them. GitHub stars apply to sample repos (`microsoft/Agents` 1.1k★, `kesslernity/awesome-copilot-studio-agents` ~498★) but a single `da-*` sample inside `pnp/copilot-pro-dev-samples` does not inherit the repo's stars.

---

## Maintenance — 15

| Band | Points | Criteria |
|---|---|---|
| Active | 15 | Commits within ~3 months; issues answered |
| Maintained | 11 | Commits within ~9 months |
| Dormant | 6 | Older than ~9 months but not archived, and content is still accurate |
| Stale | 3 | Content references superseded versions or removed APIs |
| Archived | 0 | Explicitly archived. Catalog only if it uniquely covers a facet — and say so. |

Judge staleness by **content currency**, not commit date alone. Schema versions are the staleness clock: current is declarative agent **v1.9** and plugin **v2.4**; app manifest 1.28–1.30. A sample pinned to declarative agent v1.0–v1.5 or plugin v2.1 is stale even with recent commits. Samples built on Teams Toolkit (pre-Agents Toolkit) or Bot Framework SDK (pre-Agents SDK) need migration.

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
over mirror → native M365 Copilot artifact over a ported one.

## Reporting

Show the breakdown. `Score: 78 (Auth 22 / Comp 19 / Adopt 15 / Maint 15 / Fit 7)` lets a reader
disagree with one number instead of dismissing the ranking.

Add a one-line **why** per row that is not a restatement of the score — what it is good at, and the
one thing it does not cover.

## Calibration

Do not compress every candidate into 60–80. If the best find for a facet is genuinely Marginal, say
so — that is the finding, and it is what the gap analysis acts on.

Score against the ecosystem as a whole, not against the other candidates in this run. Five mediocre
extensions do not make the least-mediocre one Recommended.
