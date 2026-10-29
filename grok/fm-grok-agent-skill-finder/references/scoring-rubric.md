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

Who stands behind it. Bands are specific to the xAI Grok Build ecosystem.

| Band | Points | Criteria |
|---|---|---|
| xAI-authored | 30 | In `xai-org/plugin-marketplace` under `plugins/` ("first-party plugins owned and maintained by xAI") or Grok's default skills (`docx`, `pptx`) |
| xAI-catalog-listed vendor | 27 | A `url` or `external_plugins/` entry in the official catalog authored by the vendor's own org (Vercel, Sentry, Cloudflare, MongoDB, Stripe, Supabase, Unity, Figma…) — SHA-pinned, code-owner reviewed, legitimacy of source org is an explicit xAI review criterion |
| xAI-catalog-listed community | 22 | A catalog entry from a personal or community org (`obra/superpowers`, `browser-use/plugins`) — reviewed and pinned, but not vendor-official |
| Community-curated | 17 | In `DominikTobureto/awesome-grok-build`, a cross-platform marketplace shipping a native `.grok-plugin/` (`kieranklaassen/compound-engineering-plugin`, `duyet/claude-plugins`), or a skills.sh entry with substantial installs |
| Established independent | 12 | Recognizable maintainer, sustained commit history, real documentation |
| Unaffiliated | 6 | Real and verified, no institutional signal |
| Anonymous / no history | 2 | Verified to exist, nothing else |

**The xAI catalog is small (36 plugins on 2026-10-24) and vendor-heavy** — mostly hosted-MCP integrations with a single skill, listed so Grok Build's plugin CTA can suggest them. It is the only xAI-curated registry; its 1.0k forks vs 307 stars reflects the PR-submission workflow, not popularity. **xAI explicitly disclaims** authoring, controlling, or verifying third-party plugins. **Vendor-authored is the underrated band**: vendors name their repos `<vendor>-grok-plugin` or `<vendor>/grok-plugin` and exist primarily to be catalog-listed — search for that naming pattern.

---

## Comprehensiveness — 25

Scored from reading the `SKILL.md` (and `.grok-plugin/plugin.json` for plugins), not from stars or README claims.

| Band | Points | Criteria |
|---|---|---|
| Deep, structured | 25 | Substantial body plus bundled `references/` / `scripts/` tree, or bundled commands, agents, hooks, MCP and LSP configs; version-anchored; concrete code; documents anti-patterns and edge cases |
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

No Grok-specific install-count surface exists. skills.sh install counts apply to Grok-targetable skills (the `skills` CLI targets `grok` → `.grok/skills/`, and Grok also reads `~/.agents/skills/`). A plugin inside the 36-entry catalog does not inherit the catalog repo's stars; score the upstream repo. Topic counts: `grok-plugin` 32 repos (precise), `grok-skills` 5, `grok-build` 324 (mostly infrastructure noise).

---

## Maintenance — 15

| Band | Points | Criteria |
|---|---|---|
| Active | 15 | Commits within ~3 months; issues answered |
| Maintained | 11 | Commits within ~9 months |
| Dormant | 6 | Older than ~9 months but not archived, and content is still accurate |
| Stale | 3 | Content references superseded versions or removed APIs |
| Archived | 0 | Explicitly archived. Catalog only if it uniquely covers a facet — and say so. |

Judge staleness by **content currency**, not commit date alone. Grok Build ships weekly (v1.0.67 on 2026-10-21; launched 2026-05-25; marketplace 2026-06-11). The official catalog runs daily SHA-bump automation — an entry whose pinned `sha` lags its upstream HEAD by months is a maintenance signal in itself. A plugin whose `.mcp.json` lacks the `{"mcpServers": {…}}` wrapper, or whose README predates the `name@marketplace` install form (v0.2.102, July 2026), is stale.

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
over mirror → native Grok artifact over a ported one.

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
