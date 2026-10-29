# Verification

The gate between "found a mention" and "goes in the catalog". Nothing reaches `Catalog` without
clearing every rule here.

## The core rule

**A search snippet is not evidence.** Aggregator listings, blog roundups, and search results
describe skills that were renamed, archived, or never existed. Fetch the artifact.

Every `Catalog` row must have a URL that was fetched during **this run** and returned the artifact.
Record `verified_at` as the run timestamp.

## Existence check

Fetch the candidate and confirm it matches **one** of the qualifying artifact shapes in
`references/artifact-types.md`. Fails all of them → not a Codex skill. Drop it, or
move it to Unverified with the reason.

**Things that look like skills and are not:**

| Looks like | Actually is |
|---|---|
| A README listing skills | Documentation. Follow it to the real artifacts. |
| A blog post titled "10 best skills for X" | A pointer. Verify each item independently. |
| A prompt template repo | Not a skill unless it ships a conformant artifact. |
| A vendored copy in a mega-collection | A mirror. Resolve upstream. |
| A ChatGPT custom GPT or Apps SDK app | A different product. Out of scope unless it ships a plugin with `skills/`. |
| An `AGENTS.md` file | Always-on project instructions, not a skill. Note as a readiness signal. |
| A `.codex/agents/*.toml` subagent | A Codex subagent definition, not a skill. Catalog as type `Agent` only if the topic asks for it. |
| A repo in `openai/skills` `.experimental/` | Real but explicitly a prototype — cap Authority at the community-vetted band. |

## Platform attribution

A skill must be shown to work on **Codex** specifically. Evidence, strongest first:

1. It is listed in a Codex first-party registry or official docs.
2. Its own README, manifest, or install instructions name Codex.
3. It uses a format Codex is documented to load, placed where Codex
   is documented to look.
4. A cross-platform aggregator tags it as Codex-compatible — **weakest**; aggregator
   tags are often inferred from format alone.

Record which level applied in the `Compatibility Evidence` column. A skill with only level-4
evidence scores no higher than **Portable** in the gap analysis unless you confirm level 3 by
reading the artifact yourself.

**Codex-specific markers, strongest first:** `agents/openai.yaml` beside `SKILL.md` (Codex-only metadata — the best discriminator between a generic Agent Skill and one tuned for Codex); `plugin.json` with `extensions["com.openai"]` or `.codex-plugin/plugin.json`; a `.agents/plugins/marketplace.json` entry; a README `$skill-installer` or `codex plugin marketplace add` snippet; presence in `openai/skills` or `openai/plugins`. A bare `SKILL.md` under `.agents/skills/` is format-compatible with Codex but carries no Codex-specific intent.

## Metrics discipline

**Never state a number from memory.** Star counts, install counts, download counts, contributor
counts, and last-commit dates are either fetched this run or omitted.

Omitted is fine — an empty cell is honest. A confidently wrong star count destroys trust in every
other cell.

| Source | Reliability |
|---|---|
| Repo page fetched now | High — use it |
| Registry manifest or official catalog entry | High for metadata; usually carries no popularity data |
| Aggregator listing | Low — often stale or self-reported. Use only if the repo is unreachable, and label it |

**Attribute stars to the right thing.** A skill inside a 40k-star monorepo does not have 40k
stars. Record the repo's stars and note that the skill is one of N in that repo — the Adoption
rubric handles the discount.

## Content check for ranked candidates

For anything that will score above `min_score`, read the actual `SKILL.md` (and `agents/openai.yaml` when present). Score
comprehensiveness from what it contains, never from repo popularity or README claims.

Record:

- **Body length** — rough line count of the primary artifact
- **Bundled resources** — `scripts/`, `references/`, `assets/`, `agents/openai.yaml` (interface, policy, MCP dependencies)
- **Depth signals** — concrete code, version-specific guidance, decision tables, anti-patterns,
  worked examples
- **Shallowness signals** — generic advice restating vendor docs, no version anchoring, obvious
  LLM-generated filler, a body that is mostly headings

A 900-line artifact that is 800 lines of generic platitudes scores below a 180-line one with real
version-specific guidance and a reference tree. Length is a weak proxy; read it.

## Canonicalization and dedup

The same skill is routinely vendored across many registries and mega-collections.

1. Resolve every candidate to its **upstream source repository**. Registry manifests often give this
   directly — prefer that over guessing.
2. Group by upstream `(repo, path)`.
3. Keep one row per group. Record mirror count as a metric, not as separate rows.
4. When upstream is genuinely unclear (no attribution, no manifest), catalog the copy you can
   verify and flag `Upstream: unresolved`.

Mirror count is a mild adoption signal — many independent registries vendoring the same skill
suggests real usage. It is not a substitute for stars or installs.

## Supply-chain flags

Installing a skill can execute code or grant data access. Flag, per row, whether it bundles:

| Flag | Why it matters |
|---|---|
| `hooks` | Plugin ships `hooks/hooks.json` — runs commands on lifecycle events |
| `scripts` | Executable code the skill may invoke |
| `mcp` | Plugin bundles `mcp.json` / `.mcp.json`, or `agents/openai.yaml` declares `dependencies.tools` — network and credential access |
| `implicit` | `agents/openai.yaml` leaves `allow_implicit_invocation` true (default) — Codex may run it without an explicit `$skill` mention |
| `network` | Skill instructions direct fetches to non-obvious endpoints |
| `unpinned` | No pinned commit SHA or version in the registry entry |

Report these **separately from the score**. A high-quality skill with elevated permissions is
still high-quality; the user decides their own risk tolerance. Do not silently downrank for it, and
do not silently omit it either.

## Freshness

Fetch and record the last commit or update date where available.

| Age | Treatment |
|---|---|
| < 3 months | Current |
| 3–9 months | Note the age |
| > 9 months | Flag `stale` — for a fast-moving toolchain this is a real risk |
| Archived | Flag `archived`. Catalog only if nothing else covers the facet, and say why. |

Version-anchored skills go stale faster than concept skills. A skill pinned to a
superseded framework version is stale even with recent commits.

## Unverified handling

When something is probably real but cannot be confirmed — repo private, org renamed, only ever
referenced secondhand — it does **not** go in `Catalog`.

If `include_unverified` is true, list it in a clearly separated section with: the claim, where the
claim came from, what was attempted, and why it failed. If false, omit it entirely and note the
count in the Run Log.

Never soften an unverified item into a verified-looking row.
