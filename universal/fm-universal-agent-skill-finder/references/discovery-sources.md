# Discovery Sources — all agents

Work these in tier order. Everything ranked must be traced back to its upstream repository. There
is **no neutral skills registry** comparable to the MCP Registry — expect fragmentation across
skills.sh, per-vendor marketplaces (Claude, Codex, Gemini gallery, awesome-copilot, xAI), vendor
hubs (ClawHub, Hermes), and npm. The job is to union them and resolve duplicates.

Facts below were current as of 2026-10-24. Every major ecosystem reorganized during 2026; the
sibling platform-specific finders carry deeper, per-platform source lists — when `agents` names a
single major ecosystem, their Tier 1 tables are the better starting point. Record drift in the
Run Log.

---

## Tier 1a — Cross-agent sources

| Source | What it is | Fetch |
|---|---|---|
| `agentskills.io/specification` and `agentskills.io/clients` | The open spec (no version number — record fetch date) and the 46-entry Client Showcase with per-client setup-doc links. Repo `agentskills/agentskills` (25.3k★, Apache 2.0 / CC-BY-4.0). | Validate frontmatter; use client links to fetch any long-tail agent's docs |
| `skills.sh` + `github.com/vercel-labs/skills` | Vercel's directory and the `npx skills add` CLI (79 agent targets). Per-skill install counts — the only cross-agent popularity signal. Pages `skills.sh/<owner>/<repo>/<skill>`, `skills.sh/agent/<id>`, badges `skills.sh/b/<owner>/<repo>`. **No public API**; `/llms.txt` 404s. `docs/agents.md` and `docs/creating-skills.md` in the repo are the authoritative path tables. | Scrape skill pages for facet terms; read the two docs files once |
| `agents.md` | AGENTS.md standard (Agentic AI Foundation). Its example link `path:AGENTS.md NOT is:fork NOT is:archived` is a model code-search query. | Context only — AGENTS.md files are not skills |
| `agent-plugins.org` + `github.com/agentplugins/agent-plugins-spec` | The neutral plugin manifest (1.0.0, 2026-08-06). Repos using its `$schema` are strong multi-agent candidates. | Search for the schema URL literal |
| Multi-agent reference collections with real plumbing | `obra/superpowers` (nine per-agent shims + `gemini-extension.json`; `brainstorming` ≈399k skills.sh installs); `microsoft/azure-skills` (`.claude-plugin/`, `.cursor-plugin/`, `gemini-extension.json`, `plugin.json`, `apm.yml`); `microsoft/skills` (175 skills, mirrored `.claude-plugin/`, `.opencode/`); `anthropics/skills` (canonical examples, `.claude-plugin/`). | Enumerate; these calibrate what "multi-agent" really looks like |

## Tier 1b — Per-ecosystem first-party registries

Run the rows for every agent in `agents` (all of them when `agents` is `all`). **Read manifests,
not rendered pages** — each resolves dozens of upstreams in one fetch.

| Agent | First-party registry / catalog | Manifest or index to read |
|---|---|---|
| `claude-code` | `anthropics/claude-plugins-official` (`/plugins`, `/external_plugins`), `anthropics/claude-plugins-community`, `anthropics/skills` | `.claude-plugin/marketplace.json` in each |
| `codex` | `openai/plugins` (current), `openai/skills` (deprecated; `.system/`, `.curated/`, `.experimental/`), ChatGPT/Codex Plugins Directory (in-app) | `.agents/plugins/marketplace.json`; tier directory listings |
| `antigravity` | `antigravity-plugins-official` (no public repo — `agy plugin list --json` / `/plugin` Discover) | in-CLI only; `antigravity.google/docs/build-with-google` |
| `gemini-cli` | Gallery `geminicli.com/extensions/browse/` (~2,200, validator-passed, component tags); org `gemini-cli-extensions` (48 repos) | Gallery cards; org listing |
| `github-copilot` | `github/awesome-copilot` (built-in marketplace), `github/copilot-plugins`, `microsoft/skills` | `awesome-copilot.github.com/llms.txt`; `marketplace` branch `.github/plugin/marketplace.json`; `copilot-plugins` manifest |
| `grok` | `xai-org/plugin-marketplace` (36 plugins, SHA-pinned) | `.grok-plugin/marketplace.json` (`keywords`, `domains`), `.grok-plugin/plugin-index.json` |
| `ms365-copilot` | `pnp/copilot-pro-dev-samples`, `microsoft/m365-agent-templates` — skills binding only | sample folders with `agentSkills[]` / `agent_skills[]` |
| `cursor` | `cursor/plugins` (seen as `pstack` in the xAI catalog); Cursor docs `cursor.com/docs/context/skills` | `.cursor-plugin/marketplace.json` |
| `openclaw` | ClawHub via `openclaw skills install`; `VoltAgent/awesome-openclaw-skills` (5,400+ filtered from the official registry) | — |
| `hermes-agent` | Hermes Skills Hub (`.hub/lock.json`, quarantine, audit) | — |
| `trae` | built-in marketplace | — |
| `droid` | `droid plugin marketplace add` | — |
| Vendor orgs (all agents) | `supabase/agent-skills`, `vercel-labs/agent-skills`, `firebase/agent-skills`, `flutter/agent-plugins`, `dart-lang/skills`, `cloudflare/skills`, `stripe/ai`, `mongodb/agent-skills`, `prisma/skills`, `clerk/skills`, `railwayapp/railway-skills`, `netlify/context-and-tools`, `wix/skills`, `base44/skills`, `axiomhq/skills`, `remotion-dev/skills` | Search each org for `SKILL.md` — vendors rarely appear in aggregators |

---

## Tier 2 — GitHub structured search

**Agent-neutral code search** (syntax from GitHub's documented qualifiers; verify the first query):

```
path:**/SKILL.md NOT is:fork NOT is:archived          # the whole corpus — narrow with description text
path:**/SKILL.md "description:" <facet>
path:.agents/skills/**/SKILL.md                        # convergent neutral layout
path:/SKILL\.md$/ content:"compatibility:"             # skills declaring environment requirements
"agent-plugins.org/schemas" path:plugin.json           # neutral plugin manifest
```

**Per-agent fingerprints** — run for each requested agent (the sibling finders list more):

```
path:.claude/skills/**/SKILL.md    path:.claude-plugin/marketplace.json     # claude-code
path:agents/openai.yaml            path:.codex-plugin/plugin.json           # codex
"antigravity.google/schemas/v1/plugin.json" path:plugin.json               # antigravity
path:gemini-extension.json                                                  # gemini-cli
path:.github/skills/**/SKILL.md    path:.github/agents/*.agent.md           # github-copilot
path:.grok-plugin/plugin.json      "when-to-use:" path:SKILL.md             # grok
path:.cursor-plugin/plugin.json    path:.cursor/skills/**/SKILL.md          # cursor
path:.kiro/skills/**/SKILL.md      path:.roo/skills/**/SKILL.md  …          # long tail, from the matrix
```

**Topic tags** — `github.com/topics/<tag>` (counts where captured, 2026-10-24):

```
agent-skills (15,558) · ai-agent-skills · agentskills · skill-library · coding-agent-plugins · agent-plugins
claude-skills · claude-code-skills · codex-skills · gemini-cli-extension (1,797) · antigravity-skills (195)
cursor-skills · opencode-skills · openclaw-skills · grok-plugin (32) · github-copilot · custom-agents
```

`coding-agent-plugins` and `gemini-cli-extension` co-occur with many agent-specific tags — repos
carrying three or more are multi-agent candidates worth fetching.

---

## Tier 3 — Aggregators and large collections

Use to **find candidates**, never to **verify or score**. Resolve every entry upstream.

| Source | Scope | Reliability notes |
|---|---|---|
| `sickn33/agentic-awesome-skills` | 48.4k★, 2,750+ skills; per-agent installers (`--cursor`, `--gemini`, `--codex`, `--antigravity`); publishes `skills_index.json` | Grab-bag; good machine index; stars not inheritable |
| `jeremylongshore/tons-of-skills-marketplace` (`tonsofskills.com`, `ccpi`) | 2,881 skills / 435 plugins; labels mirrors via `.source.json` | Explicit about provenance; **verifies Claude Code only** |
| `davila7/claude-code-templates` (`aitmpl.com`) | 1,900+ components; **documented CORS JSON API** `/api/v1/catalog.json` | Claude-only |
| `claudemarketplaces.com` | 23,600+ skills, 2,700+ marketplaces | Claude-scoped; no API |
| `ComposioHQ/awesome-codex-skills`, `Piebald-AI/awesome-gemini-cli(-extensions)`, `rmyndharis/antigravity-skills`, `DominikTobureto/awesome-grok-build`, `TheSoftwareHouse/copilot-collections`, `hesreallyhim/awesome-claude-code`, `alirezarezvani/claude-skills` (28.7k★), `wshobson/agents` (38.8k★), `addyosmani/agent-skills` (87k★) | Per-ecosystem and multi-agent awesome-lists | Pointers |
| `K-Dense-AI/scientific-agent-skills`, `seb1n/awesome-ai-agent-skills`, `majiayu000/spellbook`, `Leon-Drq/openagentskill`, `SkillsCat/skillscat` | Self-described multi-agent | Unfetched during research; verify |
| `skills.cat`, `skillsmp.com`, `claudeskills.info`, `skillselion.com`, `playbooks.com/skills`, `mcpservers.org/agent-skills`, `smithery.ai/skills`, `tessl.io/registry/skills`, `llmbase.ai`, `skillrank.it.com` | Mirror directories | Low metadata reliability; some show security scores (skills.cat) |
| `registry.modelcontextprotocol.io` | The MCP Registry (API frozen v0.1) | Indexes MCP servers, not skills — a few entries bundle skills |

---

## Search technique

**Start from the user's agents.** With `agents` set, run those ecosystems' Tier 1b rows first and
weight their fingerprints. With `all`, run the five major ecosystems' Tier 1b at minimum and let
skills.sh carry the long tail.

**Search the author's vocabulary, not the user's.** Generate 3–6 phrasings per facet.

**Resolve before you count.** A skill in a vendor repo, `anthropics/skills`, `awesome-copilot`,
`superpowers`, skills.sh, and four mirror sites is one row with a mirror count of 8.

**Score compatibility per agent, never in aggregate.** The matrix columns exist so that
"works everywhere" is a conclusion you earn one agent at a time.

**Log queries that return nothing** — per agent. "No Grok-native result for facet X, but three
portable Claude skills" is the kind of finding this finder exists to produce.

---

## Budget by depth

| Depth | Tier 1a+1b | Tier 2 | Tier 3 | Total |
|---|---|---|---|---|
| `quick` | skills.sh + 2–3 ecosystem manifests | 4–6 searches | 2–4 | 8–15 |
| `standard` | skills.sh + all requested ecosystems' manifests | 10–15 searches | 8–15 | 25–40 |
| `exhaustive` | all of 1a + 1b for every requested agent + vendor orgs | 25–35 searches | 20–30 | 60–90 |

With `agents: all` at `standard`, cap per-ecosystem Tier 1 at one manifest each so the budget
spreads; recommend the sibling platform finder in the report for any ecosystem that deserves a
deeper pass. If a run would exceed the `exhaustive` budget, deliver what is verified, mark
remaining agents and facets **not yet searched**, and say which queries were left unrun.
