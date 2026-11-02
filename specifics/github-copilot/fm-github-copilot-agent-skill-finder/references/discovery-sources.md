# Discovery Sources — GitHub Copilot

Work these in tier order. Everything ranked must be traced back to its upstream repository.
**Never conflate with Microsoft 365 Copilot** — drop hits from `learn.microsoft.com/microsoft-365/copilot/*`,
anything mentioning Copilot Studio, declarative agents, Agents Toolkit, or Agent Store; keep
`docs.github.com/en/copilot`, `code.visualstudio.com/docs/agent-customization`, `.github/skills`,
`.agent.md`, `copilot plugin install`, `gh skill`.

Facts below were current as of 2026-10-24. This surface reorganized repeatedly in 2025–2026
(chat modes → agents, Extensions sunset, awesome-copilot directory changes). Record drift in the
Run Log.

---

## Tier 1 — First-party sources

| Source | What it is | Fetch |
|---|---|---|
| `awesome-copilot.github.com/llms.txt` | **Machine-readable index** of `github/awesome-copilot` — ~222 agents, ~90 instruction sets, skills, Learning Hub. Raw file patterns `raw.githubusercontent.com/github/awesome-copilot/main/agents/<slug>.agent.md` and `.../instructions/<slug>.instructions.md`. | **Fetch first.** Grep for facet terms |
| `github.com/github/awesome-copilot` | GitHub-owned, 40.4k★, MIT, last commit 2026-10-22. Top-level: `agents/`, `instructions/`, `skills/`, `plugins/`, `hooks/`, `workflows/`, `extensions/`, `cookbook/`. **No longer has** `prompts/`, `chatmodes/`, `collections/`. Built-in marketplace in CLI and VS Code. | Enumerate `skills/` and `plugins/`; website per-type pages at `awesome-copilot.github.com/{agents,instructions,skills,plugins}` |
| `raw.githubusercontent.com/github/awesome-copilot/marketplace/.github/plugin/marketplace.json` | The published plugin manifest — note the **`marketplace` branch**. | Read for plugin list and sources |
| `github.com/github/copilot-plugins` | "The official GitHub Copilot plugins collection", MIT, 376★. `.github/plugin/marketplace.json` (symlinked from `.claude-plugin/`). Lists external plugins: `github/copilot-advanced-security-plugin`, `microsoft/azure-devops-copilot-plugin`, `microsoft/skills-for-fabric`, `microsoft/cpp-language-server`, `microsoft/Dataverse-skills`, `microsoft/power-platform-skills`. | Read the manifest; follow every external source |
| `github.com/microsoft/skills` | 175 Azure SDK + Microsoft Foundry skills under `.github/skills/<name>` (core, foundry, `-py`, `-dotnet`, `-ts`, `-java`, `-rust`), plugins under `.github/plugins/`, 3.1k★, MIT. Skill Explorer at `microsoft.github.io/skills/`. | Enumerate `.github/skills/`; the vendor-official template |
| `github.com/microsoft/azure-skills` | "Official agent plugin providing skills and MCP server configurations for Azure"; ships `.claude-plugin/`, `.cursor-plugin/`, `gemini-extension.json`, `plugin.json`. | Enumerate |
| `docs.github.com/en/copilot/reference/customization-cheat-sheet` | The one-page support matrix. | Authoritative on types, paths, surfaces |
| `docs.github.com/en/copilot/concepts/agents/about-agent-skills`, `.../reference/custom-agents-configuration`, `.../reference/copilot-cli-reference/cli-plugin-reference`, `.../reference/custom-instructions-support` | Authoritative on frontmatter, plugin format, CLI commands. | Validate claims |
| `code.visualstudio.com/docs/agent-customization/*` (`overview`, `agent-skills`, `custom-agents`, `custom-instructions`, `prompt-files`, `agent-plugins`, `migrate-customizations`) and `code.visualstudio.com/llms.txt` | VS Code side of the same surface. | Authoritative on VS Code-only frontmatter |
| `github.com/anthropics/skills` | GitHub Docs cite it as a compatible shared skills source. | Candidates; classify as Portable unless Copilot-specific |
| `agentskills.io/specification` | The open spec; GitHub Copilot is a listed adopter. | Validate frontmatter |

If a shell with Copilot CLI is available: `copilot plugin marketplace list` and `copilot plugin
list --json` show what the user has; `gh skill search <query>` searches skills directly.

---

## Tier 2 — GitHub structured search

**Code search** — the exact file globs are the discriminator. Syntax inferred from documented
qualifiers; verify the first query returns sane results.

```
path:.github/skills/**/SKILL.md            # Copilot-intent skills — strongest signal
path:.github/agents/*.agent.md             # custom agents (also *.md in that dir)
path:.github/instructions/*.instructions.md
path:.github/copilot-instructions.md
path:.github/prompts/*.prompt.md
path:.github/hooks/*.json
path:.github/plugin/marketplace.json       # Copilot marketplaces
path:.claude-plugin/marketplace.json       # also read by Copilot CLI
"agent-plugins.org/schemas" path:plugin.json
path:.claude/skills/**/SKILL.md            # read by Copilot — Portable tier
path:.agents/skills/**/SKILL.md            # read by Copilot — Portable tier
path:**/*.chatmode.md                      # legacy — convertible
"target: github-copilot"                   # agents explicitly targeting Copilot
```

Search the **`description:` frontmatter line** with facet terms — it is the closest thing to a
semantic index.

**Topic tags** — `github.com/topics/<tag>`:

```
github-copilot · copilot-instructions · custom-agents · copilot-customization · copilot-cli
agent-skills (15,558 repos) · agentskills · ai-agent-skills · agent-plugins
```

`awesome-copilot` carries `agent-skills`, `custom-agents`, `github-copilot`; `microsoft/skills`
carries `agent-skills`, `azure`, `foundry`, `mcp`, `sdk`, `skills`.

**Vendor org search.** For any framework in the topic, search the vendor's org for `.github/skills/`
or `SKILL.md`. Microsoft orgs are the richest (`microsoft/*`, `Azure-Samples/*`); GitHub MCP docs
reference `microsoft/mcp`, `microsoft/azure-devops-mcp`, `getsentry/sentry-mcp`,
`makenotion/notion-mcp-server`, `cloudflare/mcp-server-cloudflare`, `atlassian/atlassian-mcp-server`
(MCP, not skills — Partial coverage).

---

## Tier 3 — Aggregators and community lists

Use to **find candidates**, never to **verify or score**.

| Source | Notes |
|---|---|
| `skills.sh` | Vercel's directory; agent filter includes GitHub Copilot; `npx skills add <owner>/<repo>` installs to `.github/skills/` for Copilot. Per-skill install counts. **No public API** — scrape `skills.sh/<owner>/<repo>/<skill>`. |
| `TheSoftwareHouse/copilot-collections` (`copilot-collections.tsh.io`) | Agents, Prompts, Skills, Integrations; MIT; changelog through 2026-08. |
| `github.com/agentfinder` | GitHub's discovery service for MCP servers, tools, agents, skills (Agentic Resource Discovery spec). |
| `mcpservers.org/agent-skills/<owner>/<repo>/<skill>` | Indexes skills with `npx skills add` snippets; no Copilot filter. |
| `wshobson/agents` | 38.8k★ "multi-harness agentic plugin marketplace" naming GitHub Copilot among harnesses. Grab-bag — resolve upstream. |
| VS Code "Customization Marketplace" (`chat.customizations.marketplace.enabled`) | Experimental in-editor discovery. Not fetchable. |
| `ArtemisAI/skills-for-copilot`, `ilderaj/agent-plugin-marketplace`, `smithery.ai/skills`, `playbooks.com/skills/github` | Surfaced in search only; unverified. |

**Not found:** "tonsofskills" is Claude-scoped; do not cite it as a Copilot source. No Copilot-only
aggregator with ranking beyond `awesome-copilot.github.com` was verified.

---

## Search technique

**Search the author's vocabulary, not the user's.** Generate 3–6 phrasings per facet; a .NET skill
may say "C#", "dotnet", "ASP.NET", "NuGet" and never "`.NET 10`".

**Respect `types` and `surface`.** `--types instructions` leads with `copilot-instructions.md` and
`*.instructions.md`; `--surface cli` excludes prompt files (not supported on CLI) and VS Code-only
frontmatter.

**Dedup across the three homes.** The same skill routinely exists in a vendor repo, `awesome-copilot`,
`anthropics/skills`, and skills.sh. Resolve to upstream `(repo, path)`.

**Flag legacy formats, don't drop them.** `.chatmode.md` converts by rename — catalog with
`legacy-format` so the user knows the one step needed.

**Log queries that return nothing.**

---

## Budget by depth

| Depth | Tier 1 | Tier 2 | Tier 3 | Total |
|---|---|---|---|---|
| `quick` | `llms.txt` + `copilot-plugins` manifest | 4–6 searches | 2–4 | 8–15 |
| `standard` | both + `microsoft/skills` + docs | 10–15 searches | 8–15 | 25–40 |
| `exhaustive` | all Tier 1 + vendor orgs | 25–35 searches | 20–30 | 60–90 |

If a run would exceed the `exhaustive` budget, deliver what is verified, mark remaining facets
**not yet searched**, and say which queries were left unrun. Never pad a thin result.
