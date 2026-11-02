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

Who stands behind it. Bands are specific to the OpenAI Codex ecosystem.

| Band | Points | Criteria |
|---|---|---|
| OpenAI-authored | 30 | In `openai/skills` `.system/` or `.curated/`, in `openai/plugins`, or bundled with Codex |
| Vendor-authored | 27 | Published by the org that owns the technology (Supabase, Vercel, Figma, Linear shipping their own skill or plugin) |
| OpenAI-reviewed third-party | 22 | Listed in the official ChatGPT/Codex plugin directory via the submission portal |
| Community-curated | 17 | In `ComposioHQ/awesome-codex-skills` or `openai/skills` `.experimental/`; or a skills.sh entry with substantial install counts |
| Established independent | 12 | Recognizable maintainer, sustained commit history, real documentation |
| Unaffiliated | 6 | Real and verified, no institutional signal |
| Anonymous / no history | 2 | Verified to exist, nothing else |

**`openai/skills` is deprecated but still authoritative as a list.** Its README now points to `openai/plugins` as the main source, yet its `.curated/` tier remains the only OpenAI-reviewed catalog of skill *names*. Score curated-tier skills at the top band; new official examples land in `openai/plugins`. **Vendor authorship is the underrated band** — vendors document only the `npx skills add` path and rarely name Codex, so search vendor orgs directly.

---

## Comprehensiveness — 25

Scored from reading the `SKILL.md` (and `agents/openai.yaml` when present), not from stars or README claims.

| Band | Points | Criteria |
|---|---|---|
| Deep, structured | 25 | Substantial body plus bundled `references/` / `scripts/` tree and `agents/openai.yaml`; version-anchored; concrete code; documents anti-patterns and edge cases |
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
| Ecosystem-standard | 20 | Very high stars or installs; referenced by other skills or registries |
| Widely used | 15 | Clearly popular within its niche; multiple independent mirrors |
| Established | 10 | Real usage signals — forks, issues, contributors |
| Emerging | 6 | Small but genuine activity |
| Unproven | 2 | No measurable signal |

**Discount monorepo stars.** A skill in a 40k-star collection does not inherit those stars.
Weight by whether the collection is *known for* this skill or merely contains it — one of 300
in a grab-bag repo scores at most `Established` on repo stars alone.

skills.sh install counts are the best per-skill adoption signal for Codex-targetable skills, since the `skills` CLI writes to `.agents/skills/` which Codex reads. The deprecated `openai/skills` repo's star count (19k+) must not be inherited by any individual skill in it.

---

## Maintenance — 15

| Band | Points | Criteria |
|---|---|---|
| Active | 15 | Commits within ~3 months; issues answered |
| Maintained | 11 | Commits within ~9 months |
| Dormant | 6 | Older than ~9 months but not archived, and content is still accurate |
| Stale | 3 | Content references superseded versions or removed APIs |
| Archived | 0 | Explicitly archived. Catalog only if it uniquely covers a facet — and say so. |

Judge staleness by **content currency**, not commit date alone. Codex's plugin manifest shape changed during 2026 (components-style → `extensions["com.openai"]` with the agent-plugins.org schema) and the skills path migrated from `~/.codex/skills` to `~/.agents/skills`. A skill or plugin whose README still documents only the old paths is `Dormant` at best.

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
over mirror → native Codex artifact over a ported one.

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
