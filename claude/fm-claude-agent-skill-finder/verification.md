# Verification

The gate between "found a mention" and "goes in the catalog". Nothing reaches `Catalog` without
clearing every rule here.

## The core rule

**A search snippet is not evidence.** Aggregator listings, blog roundups, and search results
describe skills that were renamed, archived, or never existed. Fetch the artifact.

Every `Catalog` row must have a URL that was fetched during **this run** and returned the artifact.
Record `verified_at` as the run timestamp.

## Existence check

Fetch the candidate and confirm **one** of:

1. A `SKILL.md` exists at the stated path with valid YAML frontmatter containing `name` and
   `description`.
2. A `.claude-plugin/plugin.json` exists and declares skills, commands, agents, hooks, or MCP
   servers.
3. A marketplace `marketplace.json` entry names it, with a resolvable `source.url` **and** the
   source itself resolves.

Fails all three → not a skill. Drop it, or move it to Unverified with the reason.

**Things that look like skills and are not:**

| Looks like | Actually is |
|---|---|
| A README listing skills | Documentation. Follow it to the real artifacts. |
| A blog post titled "10 best skills for X" | A pointer. Verify each item independently. |
| A `.cursorrules` / `AGENTS.md` / `CLAUDE.md` | A different format. Note as adjacent; do not catalog as a skill. |
| A prompt template repo | Not a skill unless it ships conformant `SKILL.md` files. |
| An MCP server with no skills | A plugin component. Catalog only if the topic asks for MCP, and label the type. |
| A vendored copy in a mega-collection | A mirror. Resolve upstream. |

## Metrics discipline

**Never state a number from memory.** Star counts, install counts, download counts, contributor
counts, and last-commit dates are either fetched this run or omitted.

Omitted is fine — an empty cell is honest. A confidently wrong star count destroys trust in every
other cell.

Where a number came from matters:

| Source | Reliability |
|---|---|
| Repo page fetched now | High — use it |
| Marketplace manifest | High for pinned SHA and metadata; carries no popularity data |
| Aggregator listing | Low — often stale or self-reported. Use only if the repo is unreachable, and label it |

**Attribute stars to the right thing.** A skill inside a 40k-star monorepo does not have 40k stars.
Record the repo's stars and note that the skill is one of N in that repo — the Adoption rubric
handles the discount.

## Content check for ranked candidates

For anything that will score above `min_score`, read the actual `SKILL.md` body. Score
comprehensiveness from what it contains, never from repo popularity or README claims.

Record:

- **Body length** — rough line count of `SKILL.md`
- **Bundled resources** — `references/`, `scripts/`, `assets/`, `templates/` present?
- **Depth signals** — concrete code, version-specific guidance, decision tables, anti-patterns,
  worked examples
- **Shallowness signals** — generic advice restating language docs, no version anchoring, obvious
  LLM-generated filler, a body that is mostly headings

A 900-line skill that is 800 lines of generic platitudes scores below a 180-line skill with real
version-specific guidance and a reference tree. Length is a weak proxy; read it.

## Canonicalization and dedup

The same skill is routinely vendored across many marketplaces and mega-collections.

1. Resolve every candidate to its **upstream source repository**. Marketplace manifests give this
   directly via `source.url` — prefer that over guessing.
2. Group by upstream `(repo, path)`.
3. Keep one row per group. Record mirror count as a metric, not as separate rows.
4. When upstream is genuinely unclear (no attribution, no manifest), catalog the copy you can
   verify and flag `Upstream: unresolved`.

Mirror count is a mild adoption signal — many independent marketplaces vendoring the same skill
suggests real usage. It is not a substitute for stars or installs.

## Supply-chain flags

Installing a plugin can execute code. Flag, per row, whether it bundles:

| Flag | Why it matters |
|---|---|
| `hooks` | Runs shell commands on lifecycle events — the highest-risk component |
| `scripts` | Executable code the skill may invoke |
| `mcp` | Adds an MCP server, potentially with network and credential access |
| `network` | Skill instructions direct fetches to non-obvious endpoints |
| `unpinned` | Marketplace entry has no pinned commit SHA |

Report these **separately from the score**. A high-quality skill with hooks is still high-quality;
the user decides their own risk tolerance. Do not silently downrank for it, and do not silently
omit it either.

## Freshness

Fetch and record the last commit date where available.

| Age | Treatment |
|---|---|
| < 3 months | Current |
| 3–9 months | Note the age |
| > 9 months | Flag `stale` — for a fast-moving toolchain this is a real risk |
| Archived | Flag `archived`. Catalog only if nothing else covers the facet, and say why. |

Version-anchored skills go stale faster than concept skills. A skill pinned to a superseded
framework version is stale even with recent commits.

## Unverified handling

When something is probably real but cannot be confirmed — repo private, org renamed, only ever
referenced secondhand — it does **not** go in `Catalog`.

If `include_unverified` is true, list it in a clearly separated section with: the claim, where the
claim came from, what was attempted, and why it failed. If false, omit it entirely and note the
count in the Run Log.

Never soften an unverified item into a verified-looking row.
