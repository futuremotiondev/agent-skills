# Discovery Sources — xAI Grok Build

Work these in tier order. Everything ranked must be traced back to its upstream repository.
The Grok-specific layer is thin; the installable layer (everything Grok reads via Claude/Cursor
compat) is huge. Search the Grok-specific sources first, then fall back to the Claude Code / Agent
Skills corpus and **boost** for Grok-specific signals rather than treating all of it as native.

Facts below were current as of 2026-10-24. Grok Build is five months old and ships weekly;
`github.com/topics/*` pages returned 403 during research (counts came from the search API).
Record drift in the Run Log.

---

## Tier 1 — First-party sources

| Source | What it is | Fetch |
|---|---|---|
| `raw.githubusercontent.com/xai-org/plugin-marketplace/main/.grok-plugin/marketplace.json` | **The official catalog — source of truth.** 36 plugins; each entry has `name`, `source` (SHA-pinned `url` or local `path`), `description`, `category`, `keywords`, `domains`, `homepage`. | **Fetch first.** Match facets against `keywords`, `domains`, `description` |
| `…/.grok-plugin/plugin-index.json` | Generated component index — which skills, commands, agents, MCP servers, hooks, LSP servers each plugin ships. | Fetch second; it answers "does this plugin have an authored skill or is it MCP-only?" without cloning |
| `github.com/xai-org/plugin-marketplace` | Repo page: `plugins/` (xAI first-party), `external_plugins/` (third-party), `CONTRIBUTING.md` (review criteria and security red flags), daily `chore(plugins): daily pin bumps` commits. 307★ / 1.0k forks. | Read CONTRIBUTING.md once for the red-flag list |
| `docs.x.ai/build/features/skills-plugins-marketplaces` (`.md` twin available) | Official skills/plugins/marketplaces doc — frontmatter, load paths, compat layer. | Authoritative |
| `docs.x.ai/build/cli/reference`, `/build/settings/reference`, `/build/features/hooks`, `/build/features/mcp-servers`, `/build/features/project-rules` | CLI subcommands, config keys, hooks schema, MCP config, instruction-file rules. | Authoritative; index at `docs.x.ai/llms.txt` |
| `x.ai/news/grok-build-cli` (2026-05-25), `x.ai/news/grok-plugin-marketplace` (2026-06-11), `x.ai/changelog/build` | Launch posts and the versioned changelog. | Date features; the changelog is the staleness clock |
| `github.com/xai-org/grok-build-plugin-cc` | xAI's **Claude Code** plugin that delegates to Grok. Not a Grok skill — note only to avoid misclassifying it. | Skip as a candidate |

If a shell with Grok Build is available: `grok plugin marketplace list`, `grok plugin list`,
`grok inspect --json` show what the user has and every discovered skill/plugin with its origin.
`/marketplace` in the TUI browses the official catalog.

---

## Tier 2 — GitHub structured search

**Code search** — highest-precision Grok markers first. Syntax built from verified filenames;
verify the first query returns sane results.

```
path:.grok-plugin/marketplace.json         # native Grok marketplaces
path:.grok-plugin/plugin.json              # native Grok plugin manifests
path:.grok/skills/**/SKILL.md              # project-scoped Grok skills
"when-to-use:" path:SKILL.md               # Grok-specific frontmatter — strong intent signal
"grok plugin install" path:README.md       # README install snippets
"grok plugin marketplace add" path:README.md
path:.grokignore                           # Grok-prepared repos (weak signal)
```

Then the compat corpus, which Grok reads natively — **classify as Portable unless a marker above is
also present:**

```
path:.claude-plugin/marketplace.json
path:.claude-plugin/plugin.json
path:.cursor-plugin/plugin.json
path:.agents/skills/**/SKILL.md
path:**/SKILL.md "description:" <facet>
```

**Namespace exclusions (mandatory):** `-fluentd -logstash -elasticsearch -"grok pattern"` — the
`grok` log-parser namespace pollutes every keyword search (`grok-plugin in:name` returns 391 hits,
mostly parsers and Claude-side wrappers).

**Topic tags** — `github.com/topics/<tag>` (search-API counts, 2026-10-24):

```
grok-plugin (32 — precise)  · grok-skills (5)  · grok-build-skills (≥1)
grok-build (324 — mostly orchestrators/proxies/GUIs; filter hard)
grok-bot (Grok Bot, not Build)
agent-skills · coding-agent-plugins · plugin-marketplace
```

`grok-plugin` co-occurs with `claude-code-plugin`, `codex-plugin`, `cursor-plugin`,
`gemini-cli-extension`, `kimi-plugin` — multi-agent marketplaces that added a native Grok manifest.

**Vendor naming pattern.** Vendors name Grok plugins `<vendor>-grok-plugin` or `<vendor>/grok-plugin`
(`firecrawl/firecrawl-grok-plugin`, `exa-labs/exa-grok-plugin`, `tavily-ai/tavily-grok-plugin`,
`getsentry/plugin-grok`, `datadog-labs/grok-plugin`, `Skyvern-AI/skyvern-grok-plugin`,
`pi-sloane/grok-plugin`, `vectorize-io/hindsight-grok-plugin`, `spider-rs/spider-grok-plugin`,
`Ambush-AI/grok-plugins`). Search `<vendor> grok-plugin` for any vendor in the topic.

---

## Tier 3 — Aggregators and community lists

Use to **find candidates**, never to **verify or score**.

| Source | Notes |
|---|---|
| `DominikTobureto/awesome-grok-build` | The one awesome-list: starter kit, 12+ `.grok/skills`, `AGENTS.md` and `.grokignore` templates, hooks, a `skill-validate.yml` CI workflow, one-command installers. Independent; "not affiliated with xAI". |
| Cross-platform marketplaces shipping native `.grok-plugin/` | `browser-use/plugins` (Claude + Grok + Cursor + Kimi), `kieranklaassen/compound-engineering-plugin`, `duyet/claude-plugins` ("Claude, Codex, Cursor, and Grok plugins"), `mvanhorn/last30days-skill`, `cocoindex-io/cocoindex-code`, `bitwise-media-group/skills`. Each documents a `grok plugin install` path. |
| `skills.sh` | Vercel's directory; `npx skills add` targets `grok` → `.grok/skills/`. Per-skill install counts. **No public API** — scrape `skills.sh/<owner>/<repo>/<skill>`. Whether it filters by Grok is unverified. |
| `Wangnov/grok-skills` | Skill pack for Grok's web/X search and media generation; `npx skills add Wangnov/grok-skills`. |
| Vendor roundups: Composio "Top Grok Build CLI skills & plugins" (2026-07-30), Firecrawl "best Grok plugins", hol.org "Best Grok plugins", marktechpost marketplace launch coverage, Towards AI | Pointers. Verify each item independently. Composio's list named `mattpocock/skills`, `juliusbrussee/caveman`, `kunchenguid/whathappened`, `nirholas/XActions`, `jame581/GodotPrompter`, `heygen-com/hyperframes`, `remotion-dev/skills`. |
| `docs.unity.com/en-us/ai/unity-plugin/grok` | Vendor docs for an official Grok plugin — an example of vendor-side documentation to look for. |
| `tessl.io/registry/skills`, `mnemoverse.com/docs/api/install-by-host`, `pi.dev` package READMEs | Surfaced in search; unverified as registries. |

**Not found:** no Grok-specific search UI comparable to skills.sh; no `xai-org/skills` or
`xai-org/grok-skills` repo; "tonsofskills" is Claude-scoped. Say so in the report rather than
implying a registry exists.

---

## Search technique

**Lead with the catalog's `keywords`/`domains`.** They were designed for request matching; a facet
that hits a catalog entry's keywords is Covered at the top authority band with one fetch.

**Then search Grok markers, then the compat corpus.** The compat corpus is where most results will
come from for a niche topic — rank them honestly as Portable and say what Grok-specific tuning
(`when-to-use`, `.mcp.json` wrapper) would help.

**Exclude the log-parser namespace on every keyword query.** Do it reflexively.

**Separate Build from Bot from consumer.** If a repo says "Grok Bot" or a page says "Skill
Creator" with no file format, it is out of scope — note it in the Run Log, don't catalog it.

**Log queries that return nothing**, including catalog keyword misses.

---

## Budget by depth

| Depth | Tier 1 | Tier 2 | Tier 3 | Total |
|---|---|---|---|---|
| `quick` | catalog + plugin-index | 4–6 searches (Grok markers only) | 2–4 | 8–15 |
| `standard` | catalog + index + docs | 10–15 searches (markers + compat) | 8–15 | 25–40 |
| `exhaustive` | all Tier 1 + vendor naming sweep | 25–35 searches | 20–30 | 60–90 |

If a run would exceed the `exhaustive` budget, deliver what is verified, mark remaining facets
**not yet searched**, and say which queries were left unrun. Never pad a thin result.
