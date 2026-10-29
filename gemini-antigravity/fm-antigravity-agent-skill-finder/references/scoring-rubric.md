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

Who stands behind it. Bands are specific to the Google Antigravity and Gemini CLI ecosystem.

| Band | Points | Criteria |
|---|---|---|
| Google-authored | 30 | In the `gemini-cli-extensions` org, `GoogleCloudPlatform`, `googleworkspace`, `firebase`, `flutter`, `dart-lang`, or the `antigravity-plugins-official` marketplace |
| Vendor-authored | 27 | Published by the org that owns the technology (Stripe, Firecrawl, Supabase shipping their own extension or skill) |
| Google-gallery-validated | 22 | Listed on `geminicli.com/extensions/browse/` — passed Google's daily validator — but not Google-authored |
| Community-curated | 17 | In `Piebald-AI/awesome-gemini-cli(-extensions)`, `rmyndharis/antigravity-skills`, or a `sickn33/agentic-awesome-skills` entry with Antigravity tagging; or a skills.sh entry with substantial installs |
| Established independent | 12 | Recognizable maintainer, sustained commit history, real documentation |
| Unaffiliated | 6 | Real and verified, no institutional signal |
| Anonymous / no history | 2 | Verified to exist, nothing else |

**The Antigravity official marketplace is closed and curated** — listing is by Google interest form, not open crawl, and no public source repo was found. Entries there (firebase, flutter, gdocs, gsheets, google_slides, gcalendar, workspace, and more under "Build with Google") are top-band. **The Gemini CLI gallery is open and auto-indexed** — presence proves validation, not endorsement; recognize Google-authored entries by the `@gemini-cli-extensions/`, `@googleworkspace/`, `@GoogleCloudPlatform/` handles. **Vendor authorship is the underrated band** — `stripe/ai`, `firecrawl/firecrawl-mcp-server`, `googleworkspace/cli` carry the `gemini-cli-extension` topic and rarely appear in curated lists.

---

## Comprehensiveness — 25

Scored from reading the `SKILL.md` (or the extension/plugin manifest for packaged bundles), not from stars or README claims.

| Band | Points | Criteria |
|---|---|---|
| Deep, structured | 25 | Substantial body plus bundled `references/` / `scripts/` tree, or bundled commands, agents, rules, and MCP config; version-anchored; concrete code; documents anti-patterns and edge cases |
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

The gallery shows star counts per extension card — a fetched, per-repo signal. skills.sh install counts apply to Antigravity-targetable skills since the `skills` CLI writes to `.agents/skills/`. The `sickn33/agentic-awesome-skills` repo (48k+ stars, 2,750+ skills) is a grab-bag: no individual skill in it inherits those stars.

---

## Maintenance — 15

| Band | Points | Criteria |
|---|---|---|
| Active | 15 | Commits within ~3 months; issues answered |
| Maintained | 11 | Commits within ~9 months |
| Dormant | 6 | Older than ~9 months but not archived, and content is still accurate |
| Stale | 3 | Content references superseded versions or removed APIs |
| Archived | 0 | Explicitly archived. Catalog only if it uniquely covers a facet — and say so. |

Judge staleness by **content currency**, not commit date alone. An extension that has not been updated since the May 2026 transition and lacks `migratedTo` or an Antigravity import path is aging fast — Gemini CLI still runs on paid keys, but new work has moved to `agy`. An Antigravity plugin whose `mcp_config.json` still uses legacy `url`/`httpUrl` keys instead of `serverUrl` is stale.

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
over mirror → native Antigravity artifact over a ported one.

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
