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

Who stands behind it.

| Band | Points | Criteria |
|---|---|---|
| Anthropic-authored | 30 | In `anthropics/skills` or the `/plugins` directory of `claude-plugins-official` |
| Vendor-authored | 27 | Published by the org that owns the technology (the framework's own vendor shipping a skill for it) |
| Officially listed third-party | 22 | In `/external_plugins` of the official marketplace — vetted, not authored, by Anthropic |
| Community-marketplace vetted | 17 | In `claude-plugins-community` — passed automated validation and safety screening |
| Established independent | 12 | Recognizable maintainer, sustained commit history, real documentation |
| Unaffiliated | 6 | Real and verified, no institutional signal |
| Anonymous / no history | 2 | Verified to exist, nothing else |

**Vendor authorship is the underrated band.** A framework vendor shipping their own skill often
beats a generic community skill on accuracy and currency, and is regularly missing from every
aggregator. Search vendor orgs directly.

---

## Comprehensiveness — 25

Scored from reading the `SKILL.md`, not from stars or README claims.

| Band | Points | Criteria |
|---|---|---|
| Deep, structured | 25 | Substantial body plus a populated `references/` or `scripts/` tree; version-anchored; concrete code; documents anti-patterns and edge cases |
| Solid single-file | 19 | Focused, real code, specific guidance, no reference tree but no filler either |
| Adequate | 13 | Correct and useful, mostly restates official docs, thin on edge cases |
| Thin | 7 | Short, generic, could apply to any technology in its category |
| Stub | 2 | Mostly headings, placeholder text, or obvious generated filler |

**Progressive-disclosure structure is a strong positive signal** — a lean `SKILL.md` pointing at a
real `references/` tree usually indicates a deliberate author, and scores above a single sprawling
file of equal word count.

**Length is a weak proxy.** A 900-line skill of platitudes scores below a 180-line skill with real
version-specific guidance.

---

## Adoption — 20

Use fetched numbers only. Missing data → score the band you can defend and mark the cell `unknown`;
do not guess.

| Band | Points | Criteria |
|---|---|---|
| Ecosystem-standard | 20 | Very high stars or installs; referenced by other skills or marketplaces |
| Widely used | 15 | Clearly popular within its niche; multiple independent mirrors |
| Established | 10 | Real usage signals — forks, issues, contributors |
| Emerging | 6 | Small but genuine activity |
| Unproven | 2 | No measurable signal |

**Discount monorepo stars.** A skill in a 40k-star collection does not inherit those stars. Weight
by whether the collection is *known for* this skill or merely contains it — a skill that is one of
300 in a grab-bag repo scores at most `Established` on repo stars alone.

Mirror count across independent marketplaces is a mild positive. Copies within one author's own
repos are not.

---

## Maintenance — 15

| Band | Points | Criteria |
|---|---|---|
| Active | 15 | Commits within ~3 months; issues answered |
| Maintained | 11 | Commits within ~9 months |
| Dormant | 6 | Older than ~9 months but not archived, and content is still accurate |
| Stale | 3 | Content references superseded versions or removed APIs |
| Archived | 0 | Explicitly archived. Catalog only if it uniquely covers a facet — and say so. |

Judge staleness by **content currency**, not commit date alone. A concept skill can be accurate
after a year; a version-pinned skill can be stale in three months.

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
over mirror.

## Reporting

Show the breakdown. `Score: 78 (Auth 22 / Comp 19 / Adopt 15 / Maint 15 / Fit 7)` lets a reader
disagree with one number instead of dismissing the ranking.

Add a one-line **why** per row that is not a restatement of the score — what it is good at, and the
one thing it does not cover.

## Calibration

Do not compress every candidate into 60–80. If the best find for a facet is genuinely Marginal, say
so — that is the finding, and it is what the gap analysis acts on.

Score against the ecosystem as a whole, not against the other candidates in this run. Five mediocre
skills do not make the least-mediocre one Recommended.
