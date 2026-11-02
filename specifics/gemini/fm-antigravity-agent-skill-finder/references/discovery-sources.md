# Discovery Sources — Google Antigravity and Gemini CLI

Work these in tier order. Everything ranked must be traced back to its upstream repository.

Facts below were current as of 2026-10-24. This ecosystem reorganized in May–June 2026 and the
`agy` CLI ships releases weekly. Treat this as a starting map, verify what you fetch, and note drift
in the Run Log. `geminicli.com/docs` and `antigravity.google/docs` may be blocked by a default
fetch allowlist — the raw GitHub docs tree and the `.md` twins of Antigravity pages are the
crawler-friendly alternatives.

---

## Tier 1 — First-party sources

| Source | What it is | Fetch |
|---|---|---|
| `geminicli.com/extensions/browse/` | **The Gemini CLI gallery.** ~2,200 auto-indexed, validator-passed extensions with component tags (`MCP` `Context` `Commands` `Skills` `Hooks`) and stars. Google's crawler keys on GitHub topic `gemini-cli-extension` + root `gemini-extension.json`. | Scrape early; filter cards tagged `Skills` for authored guidance |
| `github.com/gemini-cli-extensions` | Google's org of first-party extensions — 48 repos (`conductor` 3.8k★, `nanobanana`, `security`, `workspace`, `code-review`, `stitch`, `sre`, `cicd`, `vertex`, `bigquery-*`, `looker-*`, `google-secops`). Several now describe themselves as Antigravity/`agy`-compatible. | Enumerate the org; these are top authority for both surfaces |
| `antigravity-plugins-official` marketplace | Google's curated Antigravity plugins. **No public repo.** Visible only via `agy` (`/plugin` Discover tab, `agy plugin list --json`). | Enumerate from a shell if one is available; otherwise rely on `antigravity.google/docs/build-with-google` and `/docs/marketplace` |
| Google vendor orgs | `firebase/agent-skills`, `flutter/agent-plugins`, `dart-lang/skills`, `GoogleCloudPlatform/cloud-run-mcp`, `googleworkspace/cli` (31.8k★, "includes AI agent skills"), `googleworkspace/developer-tools`. | Search each org for `SKILL.md` and `gemini-extension.json` |
| `antigravity.google/docs/skills` · `/docs/plugins` · `/docs/marketplace` · `/docs/rules` · `/docs/mcp` · `/docs/cli/gcli-migration` | Official Antigravity docs. Append `.md` for raw text. | Authoritative on load paths, manifest schema, CLI |
| `raw.githubusercontent.com/google-gemini/gemini-cli/main/docs/extensions/{index,reference,releasing}.md` and `docs/cli/skills.md` | Official Gemini CLI docs, crawler-friendly. | Authoritative on extension manifest, gallery rules, skills precedence |
| `agentskills.io/specification` | The open spec both surfaces implement. Gemini CLI is a listed adopter; Antigravity's docs cite it but it is not on the showcase. | Validate frontmatter |
| Google codelabs | "Authoring Google Antigravity Skills" (uses `rominirani/antigravity-skills`), "How to use AI Agent Skills" (Gemini CLI + Firebase), "Getting Started with Gemini CLI Extensions". | Confirm official install recommendations (`npx skills add` for both surfaces) |

**Scrape the gallery before keyword searching.** It is a validated mirror of the `gemini-cli-extension`
topic with structured cards. Every entry is also an Antigravity candidate via `agy plugin import
gemini`.

---

## Tier 2 — GitHub structured search

**Code search** — syntax built from verified filenames; verify the first query returns sane results.

```
path:gemini-extension.json                                  # Gemini CLI extensions
"antigravity.google/schemas/v1/plugin.json" path:plugin.json # Antigravity plugins
path:.agents/skills/**/SKILL.md                             # convergent skill layout (both surfaces)
path:.gemini/skills/**/SKILL.md                             # legacy Gemini CLI layout
path:**/SKILL.md "description:" <facet>                     # generic Agent Skills by description
```

Two-file conditions (e.g. "extension that also ships skills") cannot be expressed in one query —
search for `gemini-extension.json`, then check each hit for a `skills/` directory, or filter the
gallery by the `Skills` tag instead.

**Topic tags** — `github.com/topics/<tag>` (counts as of 2026-10-24 where captured):

```
gemini-cli-extension (1,797)  · gemini-cli-extensions · gemini-cli · gemini-skills · gemini-cli-skills
antigravity-skills (195) · antigravity · antigravity-skill · antigravity-plugin · agy-plugin · agy-skill
antigravity-rules · antigravity-tools · antigravity-ide · google-antigravity
agent-skills · agentskills · ai-agent-skills
```

`gemini-cli-extension` co-occurs with `agent-skills`, `claude-code-plugin`, `codex-plugin`,
`antigravity`, `openclaw-skills` — repos carrying several of these are multi-agent candidates.

**Vendor org search.** For any framework in the topic, search the vendor's org for `SKILL.md` or
`gemini-extension.json`. Confirmed vendors on the `gemini-cli-extension` topic: `stripe/ai` (2k★),
`firecrawl/firecrawl-mcp-server` (7.7k★), `wonderwhy-er/DesktopCommanderMCP`, `samber/cc-skills-golang`.

---

## Tier 3 — Aggregators and community lists

Use to **find candidates**, never to **verify or score**.

| Source | Notes |
|---|---|
| `skills.sh` | Vercel's directory for `npx skills add`; agent pages at `skills.sh/agent/gemini` and `skills.sh/agent/antigravity`; per-skill install counts. **No public API** — scrape `skills.sh/<owner>/<repo>/<skill>`. Writes to `.agents/skills/`, which both surfaces read. |
| `sickn33/agentic-awesome-skills` | 48.4k★, 2,750+ skills, tagged `gemini-cli` / `antigravity`; ships `npx agentic-awesome-skills --gemini` / `--antigravity` installers and a machine-readable `skills_index.json`. Grab-bag — resolve every entry upstream. Forks named `antigravity-awesome-skills` exist; relationship unverified. |
| `Piebald-AI/awesome-gemini-cli` and `Piebald-AI/awesome-gemini-cli-extensions` | Curated lists with an "Official" section. |
| `rmyndharis/antigravity-skills` | 1.8k★, "curated collection of Agent Skills for Google Antigravity". |
| `devohmycode/Skills-Atlas`, `agentskill-sh/ags`, `MichaelZelbel/awesome-antigravity` | Smaller browsers and lists tagged `antigravity-skills`. |
| `skills.cat`, `claudemarket.ai`, `typingmind.com/skills`, `handsonai.info/platforms/google-gemini/skills/` | Mirror directories. Low metadata reliability. |
| `google-labs-code/jules-awesome-list` | Jules **prompts**, not skills. Do not catalog. |

**Not found:** "tonsofskills" did not surface for Gemini or Antigravity; it is Claude-scoped. Do not
cite it as a source here.

---

## Search technique

**Search the author's vocabulary, not the user's.** A Gemini extension for a framework may describe
itself by the MCP server it wraps, the Google product it integrates, or the vendor — generate 3–6
phrasings per facet.

**Respect the `surface` argument.** With `antigravity`, lead with `plugin.json` and the official
marketplace, and classify extensions as Portable. With `gemini-cli`, lead with the gallery. With
`both` (default), run both and record `Surface` per row.

**Watch for `migratedTo`.** Extensions that moved repos declare the successor in their manifest —
follow it rather than cataloging the stale source.

**Log queries that return nothing**, including gallery searches with no `Skills`-tagged hits for a
facet.

---

## Budget by depth

| Depth | Tier 1 | Tier 2 | Tier 3 | Total |
|---|---|---|---|---|
| `quick` | gallery search + `gemini-cli-extensions` org | 4–6 searches | 2–4 | 8–15 |
| `standard` | gallery + org + 2–3 vendor orgs | 10–15 searches | 8–15 | 25–40 |
| `exhaustive` | all Tier 1 + every vendor org for the topic | 25–35 searches | 20–30 | 60–90 |

If a run would exceed the `exhaustive` budget, deliver what is verified, mark remaining facets
**not yet searched**, and say which queries were left unrun. Never pad a thin result.
