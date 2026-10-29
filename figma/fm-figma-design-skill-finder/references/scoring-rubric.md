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

Who stands behind it. Bands are specific to the Figma ecosystem.

| Band | Points | Criteria |
|---|---|---|
| Figma-authored | 30 | In `figma/mcp-server-guide` (`skills/`, `workflow-skills/`), the live `skill://index.json`, or a Community skill published by **Figma Community** (`@figma`) |
| Figma-curated third-party | 25 | On the editorial `figma.com/community/skills` page, in `figma/community-resources/agent_skills/README.md`, or in a Figma blog / resource-library roundup — accepted by Figma, explicitly "not endorsed" |
| Vendor / design-system owner | 23 | Published by the org that owns the design system or tool (IBM Carbon, Coinbase CDS, Kajabi Pine, Alma Spirit, PatternFly, shadcndesign, Warp, Uber uSpec, Anima) |
| Platform-marketplace-pinned | 22 | Figma's bundle as pinned by `anthropics/claude-plugins-official`, `xai-org/plugin-marketplace`, `openai/plugins`, or the Cursor marketplace — authority flows to the upstream, not the mirror |
| Community-vetted | 17 | Agencies with sustained Figma skill work (Southleft, Edenspiekermann, One North, Rad Collab); `thiagoxikota/figma-maxxing`, `robukh/figma-suite`; a `figma-mcp`-topic repo with real adoption; a Community skill with ≥ 1k users |
| Established independent | 12 | Recognizable maintainer, commit history, real documentation, or a Community skill with meaningful likes and users |
| Unaffiliated | 6 | Real and verified, no institutional signal |
| Anonymous / no history | 2 | Verified to exist, nothing else |

**Figma publishes no verification badge on either surface.** On the Community library the only authority signals are the publisher handle ("Figma Community" is Figma; co-creators such as "Figma Community and Neha Kodi" exist), likes, and users. **`community-resources/agent_skills` is a curated index, not an endorsement** — its README says so — but acceptance requires an active project, a license, and the `figma` + `figma-mcp` topics, which is real vetting. **Mirrors are not authorities:** OpenAI's `openai/skills` `.curated/figma*` and `openai/plugins/plugins/figma`, Warp's bundled copies, OpenCode's `packages/plugins/figma`, Cursor's `skills-figquery/` pages, and `thelandinlook/open-design` / `nexu-io/open-design` all vendor Figma's skills — score the Figma upstream and record them as mirrors. OpenAI's copies use older names (`figma-implement-design` = `figma-design-to-code`; `figma-create-design-system-rules`; `figma-code-connect-components`) — treat as aliases, not separate skills. **Vendor design-system skills are the underrated band** — Figma is one facet of `cds-design-to-code`, `pine-figma`, `carbon-builder`, Spirit `figma-to-code`; they never appear in Figma's catalogs and are found only by searching the vendor org for a `SKILL.md` naming Figma MCP tools.

---

## Comprehensiveness — 25

Scored from reading the `SKILL.md` (or, for a Community skill, the page's **Instructions** block — which *is* the single-file skill body), not from stars or README claims.

| Band | Points | Criteria |
|---|---|---|
| Deep, structured | 25 | Substantial body plus bundled `references/` / `scripts/` tree and per-agent manifests (none for Community skills — record Instructions line count); version-anchored; concrete code; documents anti-patterns and edge cases |
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

**Community skills expose likes and users on every card** (abbreviated — `1.4k`, `5.1k`); record both with the fetch date. They are the best adoption signal in the whole ecosystem and apply only to the `community` surface. **For `mcp` skills,** skills.sh install counts exist only for `figma/mcp-server-guide` (its `/figma` page is scoped to the figma GitHub org); claudemarketplaces.com, skillsmp.com, and mcpservers.org show view or install counts that are site-specific — store with site + date, never compare across sites. GitHub stars on `figma/mcp-server-guide` or `figma/community-resources` are repo-level; no single skill inherits them. Mirror count is unusually informative here — a skill vendored by OpenAI, Warp, Cursor, and OpenCode is ecosystem-standard.

---

## Maintenance — 15

| Band | Points | Criteria |
|---|---|---|
| Active | 15 | Commits within ~3 months; issues answered |
| Maintained | 11 | Commits within ~9 months |
| Dormant | 6 | Older than ~9 months but not archived, and content is still accurate |
| Stale | 3 | Content references superseded versions or removed APIs |
| Archived | 0 | Explicitly archived. Catalog only if it uniquely covers a facet — and say so. |

Judge staleness by **content currency**, not commit date alone. Figma's agent surfaces moved fast through 2026 — Config (June 24) opened the agent beta, in-app skills launched July 1, the MCP server's skill names changed (`figma-implement-design` → `figma-design-to-code`), write-to-canvas and Specs are in beta, and the Gemini CLI extension was folded into `mcp-server-guide`. A skill that still documents `figma-implement-design`, the deprecated `list_shader_effects` / `get_shader_fill` tools, parser-based `.figma.tsx` Code Connect (parsers are frozen; templates only), or the `dev-mode-mcp-server-guide` repo is `Stale` regardless of commit date. Community skill pages show a relative "Last updated"; record the fetch date alongside it.

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
over mirror → native Figma artifact over a ported one.

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
