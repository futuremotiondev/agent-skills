# Discovery Sources — Figma skills

Work these in tier order. Everything ranked must be traced back to its upstream artifact — a
Community skill page or an upstream repository. There are **two separate Figma skill ecosystems**
and they have different sources, different install paths, and different adoption signals:

| Surface | What it is | Where it lives | Runs in |
|---|---|---|---|
| `community` | Single-file Markdown skills (Agent Skills spec, no `scripts/` / `references/` / `assets/`) | The Figma Community AI skills library | The Figma agent (Design, Make; FigJam/Slides "coming soon") — **not** external coding agents |
| `mcp` | `SKILL.md` skills, often multi-file, that teach an external agent to drive the Figma MCP server (or REST / Plugin API) | `figma/mcp-server-guide`, `figma/community-resources`, vendor repos, GitHub at large | Claude Code, Cursor, Codex, Copilot, Gemini CLI, Grok, Kiro, Warp, … — **not** inside Figma |

The `surface` argument decides which tiers run. With `both`, run every tier. Facts below were
current as of 2026-10-25; Figma's agent surfaces changed monthly through 2026, so record drift in
the Run Log — especially renamed skills, moved repos, and changes to the Community URL scheme.

---

## Tier 1a — The Figma Community AI skills library (`community` surface)

| Source | What it is | Fetch |
|---|---|---|
| `https://www.figma.com/community/ai-skills` (canonical `?resource_type=skills`) | The "AI skills library for design agents". ~300–340 single-file skills; cards show name, author, likes, users, one-line description, "Try it out". Sort is **Popular only**. Pages `?page=1` … `?page=7` at 48 cards/page | Page every listing page; parse `a[href^="/community/skill/"]` blocks |
| Six category hubs — `/community/ai-research-skills`, `/community/ai-generation-skills`, `/community/ai-brand-skills`, `/community/ai-design-systems-skills`, `/community/ai-review-skills`, `/community/ai-orchestrate-prompt-skills` (each `?resource_type=skills`, each paged) | Research & strategy · Generation · Brand · Design systems · Critique · Workflows. Marketing copy names a seventh ("handoff") that has no pill | Page each hub when the facet maps to it |
| Tag pages `/community/<category-slug>/<tag-slug>` (e.g. `/community/ai-generation-skills/copy-content`, `/visuals`, `/micro-interactions`) | Tag-level sub-listings from `community-tags-sitemap.xml` | Use when a facet matches a known tag |
| Skill page `https://www.figma.com/community/skill/<5-digit-id>/<slug>` | Type label "Skill", likes, users, "Try it out", Preview (≤ 9 images), **Instructions** (the full skill body, line-numbered), `#tags`, "Last updated", Support contact, Community Free Resource License. Author profile `/@<handle>` | Fetch every candidate; the Instructions block is the primary artifact |
| `https://www.figma.com/community/skills` | The **older editorial page** ("Skills — New") — a hand-picked list of Figma + community *MCP* skills with GitHub links (Edenspiekermann, Uber uSpec, One North, Firebender, Warp, Augment, Rad Collab, prototype-to-figma). Despite the URL it lists `mcp` skills, not Community skills | Fetch once; every entry has an upstream repo link — a Tier 1c source in disguise |

**Mechanics that matter.** `robots.txt` disallows generic fetchers under `/community` and the
search endpoint (`/community/search?…`) outright — `WebFetch` returns `robots_disallowed`. Use a
scraping tool (Firecrawl works) or a browser. Pages are server-rendered, so no JS interaction is
needed. There is **no JSON API, RSS feed, or skills sitemap** (`figma-community-index.xml` has
sitemaps for plugins, widgets, and every file type, but none for skills). Like and user counts are
abbreviated (`1.4k`); record them as shown with the fetch date. Figma-authored entries are published
under the display name **"Figma Community"** — there is no badge. Localized mirrors
(`/pt-br/comunidade/…`, `/ko-kr/community/…`) normalize to `/community/`.

**Path-segment classification is the law here:** `/community/skill/` is a skill. `/community/plugin/`,
`/widget/`, `/file/` (Design, FigJam, Slides, Sites, Buzz **and Make projects**), `/shader/`,
`/weave_tool/`, `/app/` are not — regardless of title.

## Tier 1b — Figma's first-party MCP skills (`mcp` surface)

| Source | What it is | Fetch |
|---|---|---|
| `https://github.com/figma/mcp-server-guide` — `skills/<name>/SKILL.md` | The official pack: 16 skills (`figma-use`, `figma-use-figjam`, `figma-use-slides`, `figma-use-motion`, `figma-implement-motion`, `figma-generate-design`, `figma-generate-library`, `figma-generate-diagram`, `figma-design-to-code`, `figma-code-connect`, `figma-code-workflows`, `figma-create-new-file`, `figma-generative-plugins`, `figma-shaders`, `figma-spec`, `figma-swiftui`) + `workflow-skills/{video-interaction-mapper,generate-project-plan}` + Cursor-only `skills-figquery/` (same 14 names, generated — do not catalog separately) | Read `raw.githubusercontent.com/figma/mcp-server-guide/main/skills/<name>/SKILL.md`; `.claude-plugin/plugin.json` carries the live version |
| Live `skill://index.json` via the Figma MCP tool `get_figma_skill` | Agent Skills discovery index (`schemas.agentskills.io/discovery/0.2.0`) of the same 16 skills; `skill://figma/<name>/SKILL.md` and `skill://figma/<name>/references/<path>` | If the Figma MCP server is connected in the session, read the index — it is the only always-current machine-readable list |
| `https://help.figma.com/hc/en-us/articles/39166810751895` ("Figma skills for MCP") | Figma's own descriptions of the core and example skills, with per-skill GitHub links and the zip `…/archive/refs/heads/main.zip` | Fetch once for descriptions and plan requirements |
| `https://developers.figma.com/docs/figma-mcp-server/` and `…/tools-and-prompts/` | Tool list (~41 tools + prompt `create_design_system_rules`), which skills gate which tools, supported clients | Fetch once per run; the tool names are the search vocabulary for Tier 2 |
| `https://developers.figma.com/docs/figma-mcp-server/create-skills/` | Figma's authoring guide for MCP skills — the template for gap-analysis "build it yourself" drafts | Read when drafting recommendations |

The same repo is simultaneously the Claude Code plugin (`.claude-plugin/plugin.json`), Cursor plugin
(`.cursor-plugin/plugin.json` → `skills-figquery/`), Copilot plugin (`.github/plugin/plugin.json`),
Gemini CLI extension (`gemini-extension.json`, MCP only), Kiro Power (`figma-power/POWER.md`), and
MCP Registry entry (`server.json`, `com.figma.mcp/mcp`). One upstream, many containers — **one row
per skill, never one per container.**

## Tier 1c — Figma-curated third-party MCP skills

| Source | What it is | Fetch |
|---|---|---|
| `https://raw.githubusercontent.com/figma/community-resources/main/agent_skills/README.md` | **The best single feed for community MCP skills.** ~36 entries by category (Accessibility, AI Behavior, Components, Design Generation, Design Process, Design Systems, FigJam, Localization), each as `#### <name>` / `[SOURCE CODE](url) · [LICENSE](url)` / `**MCP Tools:** …` / description. Submission by PR (`Add [skill] <name>`) with topics `figma` + `figma-mcp`; names must **not** start with "Figma" | **Read first.** Parse every entry; the MCP-tools line is a facet signal and the source link resolves the upstream |
| `https://www.figma.com/community/skills` | Editorial list (see Tier 1a) | Already fetched above |
| Figma blog and resource library — `figma.com/blog/the-figma-canvas-is-now-open-to-agents`, `…/got-skills-make-the-figma-agent-a-better-collaborator/`, `…/try-these-10-skills-and-show-off-your-own/`, `…/agent-custom-tools-context-skills/`, `figma.com/resource-library/claude-skills-for-design` | Figma-written roundups naming community skills and their authors | Pointers only; verify each |

## Tier 1d — Platform marketplaces that pin or mirror Figma's bundle

Use these to **resolve mirrors and record install provenance**, not to find new skills.

| Registry | Entry | What to record |
|---|---|---|
| `anthropics/claude-plugins-official/.claude-plugin/marketplace.json` | `figma` → `figma/mcp-server-guide.git` pinned by SHA | Claude Code install path; pinned SHA lags `main` |
| `xai-org/plugin-marketplace/.grok-plugin/marketplace.json` | `figma` → same repo, different SHA | Grok install path (`grok plugin install figma --trust`) |
| `openai/plugins/plugins/figma/` (`.codex-plugin/plugin.json`, v2.0.x, 7 skills) and `openai/skills/skills/.curated/{figma,figma-use,figma-implement-design}` | OpenAI's older-structured copies; `openai/skills` is deprecated | Codex path; **alias map**: `figma-implement-design` = `figma-design-to-code`, `figma-code-connect-components`, `figma-create-design-system-rules` |
| Cursor marketplace `cursor.com/marketplace/skills/figma-*` | Per-skill pages for the 14 `skills-figquery/` variants | Cursor path (`/add-plugin figma`) |
| `anomalyco/opencode/packages/plugins/figma/skills/` (`NOTICE.md`, `skills-source.json`) and `warpdotdev/warp/resources/bundled/mcp_skills/figma/` | Verbatim or pinned mirrors | Mirror count only |
| `thelandinlook/open-design`, `nexu-io/open-design` | Catalog repos re-advertising Figma's skills ("curated from Figma's MCP server guide") | Mirror count only; `github.com/figma/skills` cited by them is **unverified** |

---

## Tier 2 — GitHub structured search (`mcp` surface)

**Topics** (`github.com/topics/<tag>`; counts where captured, 2026-10-25):

```
figma-mcp        # the productive one — mixes skill repos with MCP servers; filter on SKILL.md
figma-skill (5)  # small, precise: Uxcel-Lab/product-skills, planetabhi/figma-mcp-server, robukh/figma-suite, …
figma-skills (2) # Tmmy-inter/figma-product-design-director, Qredence/skills
code-connect     # tiny, mostly tools (figma-connecter, design-passport) — not skills
figma-plugin · design-to-code · figma-api   # large and mostly plugins/tools; useless without the SKILL.md filter
```

**Code search** (GitHub qualifier syntax; verify the first query's syntax before fanning out):

```
path:**/SKILL.md "use_figma"                       # write-to-canvas skills — the strongest fingerprint
path:**/SKILL.md "get_design_context"              # design-to-code / read skills
path:**/SKILL.md "get_variable_defs"               # tokens / variables
path:**/SKILL.md "search_design_system"            # design-system-aware generation
path:**/SKILL.md "get_figjam" OR "generate_diagram"   # FigJam
path:**/SKILL.md "mcp.figma.com"                   # any skill that configures the server itself
path:**/SKILL.md ".figma.ts"                       # Code Connect
path:**/SKILL.md "/v1/files/" figma                # REST automation
path:**/SKILL.md "Figma Make"                      # Make-targeted guidance
"description:" figma path:**/SKILL.md NOT is:fork NOT is:archived   # the broad net — narrow with facet terms
```

Search **MCP tool names and endpoints, not the word "Figma"** — the word appears in thousands of
plugin and template repos; the tool names appear almost only in real skills. Skip repos whose only
Figma file is `manifest.json` + `code.ts` (a plugin) or `figma.config.json` (Code Connect config).

**Layouts seen in the wild** — scan recursively, repo names are unreliable: `skills/<name>/SKILL.md`
(southleft, edenspiekermann, figma), `.agents/skills/<name>/` (planetabhi, alma-oss/spirit),
`.agents/.skills/<name>/` (warpdotdev/figma-skills), `.claude/skills/<name>/` (tallneil's monorepo),
`plugins/<plugin>/skills/<name>/` (openai/plugins, abhattacherjee, patternfly/ai-helpers),
`src/skills/<name>/` (orchestkit), `library/specializations/…/skills/<name>/` (a5c-ai/babysitter).

---

## Tier 3 — Vendor, design-system, and agency sources (`mcp` surface)

Figma is usually **one facet of a broader design-system skill** here; none of these appear in
Figma's catalogs. Search each org for `SKILL.md` naming Figma MCP tools.

| Org / repo | What it ships |
|---|---|
| `southleft/skills-for-figma`, `southleft/figma-console-mcp-skills` (22 skills; 4 REST skills need `FIGMA_TOKEN`) | The largest third-party Figma skill set; the first is the community-named subset of the second |
| `edenspiekermann/Skills` | `apply-design-system`, `audit-design-system`, `fix-design-system-finding` — `SKILL.md` + `agents/openai.yaml` |
| `redongreen/uspec` (Uber) | `create-structure`, `create-property`, `create-anatomy`, `create-api`, `create-voice` — spec annotations into Figma |
| `nvillapiano/component-contracts-figma` (One North), `nolanperk/rad-spacing`, `firebenders/sync-figma-token-skill`, `warpdotdev/figma-skills`, `AugmentedAJ/skills` (`augment-multi-agent-figma`), `alima-max/prototype-to-figma-skill` | The editorial-page community set |
| `thiagoxikota/figma-maxxing` (8 skills; `.claude-plugin/`, `.codex-plugin/`, `.cursor-plugin/`, `gemini-extension.json`, `skills.sh.json`) | Plugin-API gotchas, click flows, handoff gate, slop check |
| `robukh/figma-suite`, `natdexterra/work-with-design-systems`, `Hosseinkm89/figma-skills`, `noemuch/bridge`, `Uxcel-Lab/product-skills` (59, Make-oriented), `Tmmy-inter/figma-product-design-director`, `shoemakerk/throughline-skill`, `Klionskiy/claude-mobile-mvp-skills`, `let-sunny/canicode` | Independent collections |
| `coinbase/cds` (`skills/cds-design-to-code`), `kajabi/pine` (`skills/pine-figma`), `alma-oss/spirit-design-system` (`.agents/skills/figma-to-code`), `patternfly/ai-helpers` (`plugins/pf-workshop/skills/figma-diff`), IBM Carbon `carbon-builder` (zip from carbondesignsystem.com; `/carbon-builder-figma-make-react` for Make), `AnimaApp/mcp-server-guide` (`skills/anima`), shadcndesign (paid, no GitHub) | Design-system vendors |
| `zhaono1/agent-playbook` (`figma-designer`), `yonatangross/orchestkit` (`figma-design-handoff`), `a5c-ai/babysitter` (`figma-api`), `oakoss/agent-skills` (`figma-developer`), `abhattacherjee/claude-code-skills`, `terminalskills/skills` (`figma-to-code`), `t4sh/dotfiles` (`figma-to-code`), `lum1104/understand-anything` (`understand-figma`), `aiskillstore/marketplace` (`7nohe/figjam-plugin`), `equalexperts/kuat-agent-rules` (`skills/install/figma-make.md`) | Figma skills inside general collections |
| **Not found as of 2026-10-25** (absence not proven): Builder.io, Locofy, Tokens Studio, Style Dictionary, Atlassian, Fluent, Material, Radix, v0, Lovable, Framer, Webflow | Re-check, do not assume |

**Community MCP servers** — for the **Partial** classification and the `third-party-mcp` flag, not
for `Catalog`: `GLips/Figma-Context-MCP` (Framelink; no skill), `southleft/figma-console-mcp`
(121 tools; skills live in the separate `-skills` repo), `arinspunk/claude-talk-to-figma-mcp` and
`grab/cursor-talk-to-figma-mcp` (bridge plugins; no skill), `planetabhi/figma-mcp-server`
(ships `.agents/skills/figma-agent`), `awdr74100/figwright`, `tathagat22/plumb-mcp`,
`mrpeterperez/tellfigma`, `karthikyaddana/figma-mcp-free`, `TranHoaiHung/figma-ui-mcp`.

---

## Tier 4 — Aggregators and collections

Use to **find candidates**, never to **verify or score**. Resolve every entry upstream.

| Source | Scope | Reliability notes |
|---|---|---|
| `skills.sh/figma` | Scoped to the **figma GitHub org** only — shows `mcp-server-guide`'s install count; search is robots-blocked | Good for one number; useless for community recall |
| `mcpservers.org/agent-skills/author/figma`, `skillsmp.com/creators/figma`, `cursor.com/marketplace/skills/figma-*` | Per-skill pages for Figma's and OpenAI's copies; site-specific counts | Mirrors with metadata; store counts with site + date |
| `claudemarketplaces.com/skills/category/design-ui` | Community Figma skills with view counts (`agent-playbook/figma-designer`, `mindrally/skills/figma-integration`, `absolutelyskilled/figma-to-code`) | Claude-scoped; no API |
| `awesomeskill.ai`, `verified-skill.com`, `agent-skills.techleads.club`, `skillsdirectory.com` | Roundups and badge sites | Pointers |
| `ComposioHQ/awesome-claude-skills` (`figma-automation`), `sickn33/agentic-awesome-skills` (`figma-automation`), `hashgraph-online/awesome-codex-plugins` (lists figma-maxxing) | Mega-collections with one or two Figma entries | Grab-bags; stars not inheritable |
| The Community **plugin** "SKILLS for Figma Agent Design" (`/community/plugin/1658560369867451806/…`, "60+ skills by category") | A plugin that distributes in-app skills for upload | Not a skill; follow it to what it ships, then verify each |
| **No `awesome-figma-skills` repo exists** (searched 2026-10-25) | — | Figma's own catalogs are the de-facto curated lists |

---

## Search technique

**Pick the surface from the user's words.** "Inside Figma", "Figma agent", "Make", "slash
command", "/design-crit" → `community`. "Claude Code", "Cursor", "Codex", "MCP", "design-to-code",
"Code Connect", "SKILL.md" → `mcp`. Anything else → `both`, and say so in the run header.

**Search the author's vocabulary.** Community authors write for designers ("design crit", "type
scale", "variable library", "usability test guide"); MCP authors write for engineers ("design
context", "variables → DTCG", "parserless `.figma.ts`", "auto layout → flex"). Generate phrasings
for both registers per facet; `references/figma-facets.md` lists them.

**Dedupe on `name` + body hash.** Figma's skills exist in at least seven copies; OpenAI renamed
three of them. One row, mirror count, alias list.

**Classify by path and fingerprint, never by title.** Community path segment for the `community`
surface; MCP tool names, REST endpoints, and `references/` contents for `mcp`.

**Log queries that return nothing — per surface.** "No Community skill for Code Connect, four MCP
skills" and "no MCP skill for brand voice, nine Community skills" are exactly the findings this
finder exists to produce.

---

## Budget by depth

| Depth | Tier 1 | Tier 2 | Tier 3 + 4 | Total |
|---|---|---|---|---|
| `quick` | `agent_skills` README + Community landing page + 1 category hub | 3–4 code searches | 2–3 | 8–15 |
| `standard` | README + all Community pages (7) + relevant hubs + `mcp-server-guide` skills for the facets | 8–12 | 8–12 | 25–40 |
| `exhaustive` | everything in Tier 1 including the editorial page, blog roundups, and all six hubs paged | 20–30 | 20–30 | 60–90 |

With `surface: community`, reallocate Tier 2/3 budget to paging every hub and fetching every
candidate skill page (the Instructions block is the artifact — it must be read). With `surface: mcp`,
skip Tier 1a except the editorial page. If a run would exceed the `exhaustive` budget, deliver what
is verified, mark remaining facets and surfaces **not yet searched**, and name the unrun queries.
