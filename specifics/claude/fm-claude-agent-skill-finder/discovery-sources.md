# Discovery Sources

Work these in tier order. Tier 1 is authoritative and cheap; Tier 3 is high-recall and
high-noise. Everything ranked must be traced back to its upstream repository regardless of where
you found it.

Facts below were current as of this file's authoring. **Registry names, URLs, and repo layouts
change.** Treat this as a starting map, verify what you fetch, and note any drift in the Run Log.

---

## Tier 1 — First-party registries

Highest authority signal. Anything here starts at the top of the Authority band.

| Source | What it is |
|---|---|
| `anthropics/claude-plugins-official` | Anthropic-curated directory. Ships pre-configured in recent Claude Code. `/plugins` = Anthropic-built; `/external_plugins` = vetted partner and community. Inclusion is at Anthropic's discretion. |
| `anthropics/claude-plugins-community` | Community marketplace; entries pass automated validation and safety screening and are pinned to a commit SHA. Read-only mirror — submissions flow through a review pipeline. |
| `anthropics/skills` | Anthropic's public Agent Skills repo. Registerable as a marketplace. Source of the document skills and reference implementations. |
| `agentskills/agentskills` | The open Agent Skills specification. Use to validate that a candidate is a conformant skill. |
| `code.claude.com/docs` | Plugin, marketplace, and skill documentation. Authoritative on mechanics. |

**Read the manifests directly, not the rendered pages.** A marketplace's
`.claude-plugin/marketplace.json` is a structured catalog: every entry carries `name`,
`description`, `source.url`, `source.path`, and usually a pinned `sha` and `homepage`. Fetching one
manifest yields dozens of verified candidates in a single call, with the upstream URL already
resolved for you. This is the single highest-yield move in the whole workflow — do it before any
keyword searching.

Entries may declare skills directly with `strict: false` and an explicit `skills` array when the
source repo ships `SKILL.md` files without a `plugin.json`. Those paths are relative to
`source.path`.

If a shell is available, `/plugin marketplace list` and `/plugin marketplace update` show what the
user already has registered — check before recommending something already installed.

---

## Tier 2 — GitHub structured search

Higher precision than web search because it matches on the artifact itself.

**Code search** — finds skills that no marketplace has indexed:

```
path:**/SKILL.md <facet term>
path:**/SKILL.md "description:" <framework name>
path:.claude-plugin/marketplace.json <facet term>
path:.claude-plugin/plugin.json <facet term>
```

Search the **`description:` frontmatter line specifically** — that is where a skill declares its
triggers, and it is the closest thing to a semantic index the ecosystem has.

**Topic tags** — `github.com/topics/<tag>`:

```
claude-skills · agent-skills · claude-skill · anthropic-skills
claude-code-plugin · claude-code-plugins
claude-code-plugins-marketplace · claude-code-plugin-marketplace
claude-plugins · claude-cowork
```

Combine with language filters (`?l=csharp`, `?l=typescript`) when the topic is language-bound.

**Vendor org search.** For any framework in the topic, check whether the vendor ships skills
directly — search the vendor's GitHub org for `SKILL.md`. Vendor-authored skills are the strongest
non-Anthropic authority signal and are frequently absent from every aggregator.

---

## Tier 3 — Aggregators and community lists

High recall, unreliable metadata, heavy duplication. Use to **find candidates**, never to **verify
or score** them. Numbers on these sites are often stale or self-reported.

- `claudemarketplaces.com` — directory ranked by installs and stars
- `claudepluginhub.com` — marketplace and plugin browser
- `pluginmarketplace.ai` — curated directory with install counts
- `aitmpl.com/plugins` — plugin and skill collections
- `tonsofskills.com` — large open-source skill index with a CLI
- `awesome-claude-code`-style curated lists (several exist; check recency before trusting)

Large community collections (multi-hundred-skill monorepos) frequently **vendor copies of upstream
skills**. Always resolve to the original author before ranking, and treat a vendored copy as a
mirror, not a find.

---

## Search technique

**Search the author's vocabulary, not the user's.** A skill for a given framework may describe
itself by the parent platform, the design language, the SDK name, the markup language, or the
company — and never use the term the user typed. Generate 3–6 phrasings per facet before concluding
nothing exists.

**Version terms are unreliable.** A skill written for one version rarely names later ones. Search
the unversioned concept and inspect content for version coverage, rather than searching for the
version string.

**Run at least one deliberately broad query per facet.** Narrow queries confirm what you expect;
broad ones surface the thing you didn't know to look for.

**Log queries that return nothing.** A null result is evidence for the gap analysis and belongs in
the `Sources` sheet. It is also what makes a repeat run comparable.

---

## Budget by depth

| Depth | Tier 1 | Tier 2 | Tier 3 | Total |
|---|---|---|---|---|
| `quick` | 2–3 manifests | 4–6 searches | 2–4 | 8–15 |
| `standard` | 3–5 manifests | 10–15 searches | 8–15 | 25–40 |
| `exhaustive` | all Tier 1 + vendor orgs | 25–35 searches | 20–30 | 60–90 |

If a run would exceed the `exhaustive` budget, deliver what is verified, mark the remaining facets
as **not yet searched** in the gap table, and say which queries were left unrun. Never pad a thin
result to fill the budget.
