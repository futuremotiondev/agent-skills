# Discovery Sources — OpenAI Codex

Work these in tier order. Tier 1 is authoritative and cheap; Tier 3 is high-recall and high-noise.
Everything ranked must be traced back to its upstream repository regardless of where you found it.

Facts below were current as of 2026-10-24. **Registry names, URLs, and repo layouts change** — the
Codex docs host, skills load path, and plugin manifest shape all changed during 2026. Treat this as a
starting map, verify what you fetch, and note any drift in the Run Log.

---

## Tier 1 — First-party sources

| Source | What it is | Fetch |
|---|---|---|
| `github.com/openai/plugins` | **Current** official home for Codex skill and plugin examples. Catalog at `.agents/plugins/marketplace.json`; plugins under `plugins/<name>/` with `.codex-plugin/plugin.json`, `skills/`, `.mcp.json`, `.app.json`. | Read the marketplace manifest first — it resolves every upstream for you |
| `github.com/openai/skills` | **Deprecated** but still the only OpenAI-reviewed list of skill names. Tiers: `skills/.system` (auto-installed), `skills/.curated` (passed OpenAI review, ~38 skills incl. `gh-fix-ci`, `vercel-deploy`, `figma`, `linear`, `sentry`, `playwright`, `aspnet-core`, `winui-app`), `skills/.experimental` (prototypes). 19k+ stars. | Enumerate tier directories; treat `.curated` as top authority |
| ChatGPT/Codex Plugins Directory | The universal plugin directory shared by ChatGPT and Codex; in-app via `/plugins`. Submission via `platform.openai.com/plugins`. | No public web index found — enumerate from inside Codex if a shell is available |
| `learn.chatgpt.com/docs/build-skills` | Official skills doc (redirect target of `developers.openai.com/codex/skills`). Append `.md` for raw Markdown. | Authoritative on load paths and frontmatter |
| `developers.openai.com/codex/plugins/build` and `developers.openai.com/plugins/build/plugins` | Official plugin packaging docs — manifest fields, marketplace format, CLI commands. | Authoritative on plugin mechanics |
| `agentskills.io/specification` | The open spec Codex implements. | Validate frontmatter against it |

**Read the manifests directly, not the rendered pages.** `.agents/plugins/marketplace.json` entries
carry `name`, `source` (with `sha` for pinned sources), `policy`, `category`. One fetch yields dozens
of verified candidates with upstream URLs already resolved. Do this before any keyword searching.

If a shell with Codex is available: `codex plugin marketplace list` shows what the user has
registered; `$skill-installer list` shows installed skills. Check before recommending something
already present.

---

## Tier 2 — GitHub structured search

**Code search** — matches the artifact itself. Syntax built from documented qualifiers; verify the
first query returns sane results before trusting counts.

```
path:.agents/skills/**/SKILL.md            # skills in the Codex/convergent layout
path:agents/openai.yaml                    # Codex-specific skill metadata — highest-precision marker
path:.codex-plugin/plugin.json             # Codex plugin overlay manifest
"agent-plugins.org/schemas/1.0.0/plugin.schema.json" path:plugin.json
path:.agents/plugins/marketplace.json      # Codex marketplaces
path:.claude-plugin/marketplace.json       # legacy-compatible — Codex reads these too
path:**/SKILL.md "description:" <facet>    # generic Agent Skills, filtered by description text
```

Search the **`description:` frontmatter line specifically** — it is the closest thing to a semantic
index the ecosystem has.

**Topic tags** — `github.com/topics/<tag>`:

```
codex-skills · openai-codex · codex-plugin · codex-hooks · codex-cli
coding-agent-plugins · agent-skills · agentskills · ai-agent-skills
```

`coding-agent-plugins` co-occurs with `codex-skills`, `claude-code-skills`, `cursor-skills`,
`gemini-cli-skills`, `openclaw-skills` — a good pivot for multi-agent repos.

**Vendor org search.** For any framework in the topic, check whether the vendor ships skills:
search the vendor's GitHub org for `SKILL.md`. Confirmed vendor repos: `supabase/agent-skills`,
`vercel-labs/agent-skills`, `firebase/agent-skills`, `flutter/agent-plugins`, `dart-lang/skills`,
`microsoft/skills`, `cloudflare/skills`, `stripe/ai`. Vendors document `npx skills add` and rarely
say "Codex" — compatibility is implied by the `skills` CLI's `codex` target.

---

## Tier 3 — Aggregators and community lists

High recall, unreliable metadata, heavy duplication. Use to **find candidates**, never to **verify or
score** them.

| Source | Notes |
|---|---|
| `ComposioHQ/awesome-codex-skills` | ~17k stars, the largest Codex-specific curated list. Also cross-compatible with Claude Code. Repo may redirect to `composio-community/`. |
| `skills.sh` | Vercel's directory for `npx skills add`; 89k+ skills, per-skill install counts, agent page at `skills.sh/agent/codex`. **No public API** — scrape skill pages `skills.sh/<owner>/<repo>/<skill>`. |
| `skills.cat` | Indexes OpenAI built-ins (e.g. `openai/codex/plugin-creator`); shows AI and VirusTotal security scores; `npx skillscat add <slug>`. |
| `skillsmp.com` | Claims 500k–1.6M `SKILL.md` files; compatibility claims unverified. Candidates only. |
| `claudeskills.info`, `skillselion.com`, `playbooks.com/skills`, `mcpservers.org/agent-skills` | Mirror directories that index both Codex and Claude skills. Low metadata reliability. |
| `codex.danielvaughan.com` | Dated, versioned third-party deep dives on Codex skills/plugins/marketplace — useful for ecosystem history, not as a registry. |
| Roundups: Firecrawl "best Codex skills", Composio "Top 10 Codex Skills", gradually.ai, theguidex.com | Pointers. Verify each item independently. |

**Not found:** "tonsofskills" did not surface in Codex-specific searches; it is Claude-scoped (see
cross-platform notes). Do not cite it as a Codex source.

---

## Search technique

**Search the author's vocabulary, not the user's.** A skill may describe itself by the parent
platform, SDK name, or company and never use the user's term. Generate 3–6 phrasings per facet.

**Version terms are unreliable.** Search the unversioned concept and inspect content for version
coverage.

**Run at least one deliberately broad query per facet.** Narrow queries confirm expectations; broad
ones surface what you didn't know to look for.

**Log queries that return nothing.** Null results are evidence for the gap analysis and belong in
the `Sources` sheet.

**Dedup aggressively.** The same skill routinely appears in `openai/skills`, a vendor repo,
`awesome-codex-skills`, skills.sh, and three mirror sites. Resolve to upstream `(repo, path)`.

---

## Budget by depth

| Depth | Tier 1 | Tier 2 | Tier 3 | Total |
|---|---|---|---|---|
| `quick` | 2 manifests | 4–6 searches | 2–4 | 8–15 |
| `standard` | both official repos + directory | 10–15 searches | 8–15 | 25–40 |
| `exhaustive` | all Tier 1 + vendor orgs | 25–35 searches | 20–30 | 60–90 |

If a run would exceed the `exhaustive` budget, deliver what is verified, mark remaining facets
**not yet searched**, and say which queries were left unrun. Never pad a thin result.
