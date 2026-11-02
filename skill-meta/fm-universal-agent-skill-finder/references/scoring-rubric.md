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

Who stands behind it. Bands are specific to the any AI coding agent ecosystem.

| Band | Points | Criteria |
|---|---|---|
| Standard-steward or platform first-party | 30 | `anthropics/skills`; `openai/skills` `.curated/` or `openai/plugins`; `gemini-cli-extensions` org or `antigravity-plugins-official`; `github/copilot-plugins` or GitHub-maintained `awesome-copilot` items; `xai-org/plugin-marketplace` `plugins/`; or bundled with an agent |
| Vendor-authored | 27 | Published by the org that owns the technology (`microsoft/skills`, `supabase/agent-skills`, `vercel-labs/agent-skills`, `firebase/agent-skills`, `stripe/ai`, `cloudflare/skills`…) — frequently absent from every aggregator |
| Official-marketplace-listed third-party | 22 | Vetted into an official marketplace without being authored there: Claude `claude-plugins-official` `/external_plugins`, the ChatGPT/Codex plugin directory, the Gemini CLI gallery (validator-passed), `awesome-copilot` (code-owner reviewed), xAI catalog `url` sources (SHA-pinned, reviewed) |
| Community-vetted | 17 | Claude `claude-plugins-community` (automated screening), `ComposioHQ/awesome-codex-skills`, `Piebald-AI/awesome-gemini-cli`, `DominikTobureto/awesome-grok-build`, multi-agent collections with real per-agent plumbing, or a skills.sh entry with substantial installs |
| Established independent | 12 | Recognizable maintainer, sustained commit history, real documentation |
| Unaffiliated | 6 | Real and verified, no institutional signal |
| Anonymous / no history | 2 | Verified to exist, nothing else |

**Authority is per source, not per agent.** A vendor skill scores 27 regardless of how many agents it targets; what varies per agent is the compatibility evidence level, which lives in the matrix, not in this dimension. **Multi-agent collections are not authorities** — `sickn33/agentic-awesome-skills` (48k★, 2,750 skills), `jeremylongshore/tons-of-skills-marketplace` (2,881 skills), `davila7/claude-code-templates` (32.7k★) mostly vendor upstream work; `tonsofskills` labels mirrors via `.source.json`, which helps. Resolve every entry upstream and score the upstream. **`obra/superpowers`** is the reference implementation of "one `skills/` tree, many per-agent shims" — use it to calibrate what real multi-agent plumbing looks like.

---

## Comprehensiveness — 25

Scored from reading the `SKILL.md` (or the agent-specific manifest for packaged plugins and extensions), not from stars or README claims.

| Band | Points | Criteria |
|---|---|---|
| Deep, structured | 25 | Substantial body plus bundled `references/` / `scripts/` tree and per-agent manifests; version-anchored; concrete code; documents anti-patterns and edge cases |
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

**skills.sh install counts are the only cross-agent, per-skill popularity signal** (e.g. `brainstorming` from `obra/superpowers` at ~399k installs). Platform-specific signals (gallery stars, awesome-copilot presence, xAI catalog pinning) apply only to their platform column. GitHub stars on a multi-agent monorepo are not inherited by any one skill in it. `aitmpl.com` exposes a documented JSON API (`/api/v1/catalog.json`) but is Claude-only; `claudemarketplaces.com` (23,600+ skills) is Claude-scoped with no API.

---

## Maintenance — 15

| Band | Points | Criteria |
|---|---|---|
| Active | 15 | Commits within ~3 months; issues answered |
| Maintained | 11 | Commits within ~9 months |
| Dormant | 6 | Older than ~9 months but not archived, and content is still accurate |
| Stale | 3 | Content references superseded versions or removed APIs |
| Archived | 0 | Explicitly archived. Catalog only if it uniquely covers a facet — and say so. |

Judge staleness by **content currency**, not commit date alone. Cross-agent staleness clocks differ: Codex changed load paths and manifest shape in 2026; Gemini CLI was superseded by Antigravity in June 2026; Copilot renamed chat modes to agents and sunset Extensions; Grok ships weekly. A skill maintained for one agent can be stale for another — record per-agent notes when they diverge rather than one blended verdict.

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
over mirror → native target-agent artifact over a ported one.

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
