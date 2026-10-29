# Verification

The gate between "found a mention" and "goes in the catalog". Nothing reaches `Catalog` without
clearing every rule here.

## The core rule

**A search snippet is not evidence.** Aggregator listings, blog roundups, and search results
describe customizations that were renamed, archived, or never existed. Fetch the artifact.

Every `Catalog` row must have a URL that was fetched during **this run** and returned the artifact.
Record `verified_at` as the run timestamp.

## Existence check

Fetch the candidate and confirm it matches **one** of the qualifying artifact shapes in
`references/artifact-types.md`. Fails all of them → not a GitHub Copilot customization. Drop it, or
move it to Unverified with the reason.

**Things that look like customizations and are not:**

| Looks like | Actually is |
|---|---|
| A README listing customizations | Documentation. Follow it to the real artifacts. |
| A blog post titled "10 best customizations for X" | A pointer. Verify each item independently. |
| A prompt template repo | Not a customization unless it ships a conformant artifact. |
| A vendored copy in a mega-collection | A mirror. Resolve upstream. |
| A declarative agent, Copilot Studio agent, or `declarativeAgent.json` | **Microsoft 365 Copilot.** Different product. Exclude. |
| A GitHub Marketplace "Copilot Extension" (GitHub App) | Sunset 2025-11-10; category removed. Dead unless it is a VS Code chat-participant extension. |
| `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `REVIEW.md` | Agent instruction files Copilot reads. Readiness signals, not customizations. |
| `*.chatmode.md` | Legacy VS Code custom chat mode — convertible by renaming to `.agent.md`. Catalog as `Agent` with flag `legacy-format`. |
| `~/.copilot/extensions/` or `awesome-copilot/extensions/` entries | Copilot CLI/app extensions, unrelated to the sunset Marketplace Extensions. Catalog only if the topic asks. |
| A `.vscode/mcp.json` alone | MCP configuration. Not a customization to rank. |

## Platform attribution

A customization must be shown to work on **GitHub Copilot** specifically. Evidence, strongest first:

1. It is listed in a GitHub Copilot first-party registry or official docs.
2. Its own README, manifest, or install instructions name GitHub Copilot.
3. It uses a format GitHub Copilot is documented to load, placed where GitHub Copilot
   is documented to look.
4. A cross-platform aggregator tags it as GitHub Copilot-compatible — **weakest**; aggregator
   tags are often inferred from format alone.

Record which level applied in the `Compatibility Evidence` column. A customization with only level-4
evidence scores no higher than **Portable** in the gap analysis unless you confirm level 3 by
reading the artifact yourself.

**Copilot-specific markers, strongest first:** files under `.github/skills/`, `.github/agents/`, `.github/instructions/`, `.github/prompts/`, `.github/hooks/`, `.github/copilot/settings.json`, `.github/plugin/marketplace.json`; a `*.agent.md` with `target: github-copilot`; listing in `awesome-copilot.github.com/llms.txt` or the `github/copilot-plugins` manifest; a README `copilot plugin install` or `gh skill install` snippet; frontmatter `argument-hint` / `user-invocable` (VS Code/Copilot extensions to the spec). Files under `.claude/skills/`, `.claude/agents/`, `.claude/rules/`, or `.agents/skills/` are read by Copilot but indicate another agent's intent — level 3 at best.

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

**Attribute stars to the right thing.** A customization inside a 40k-star monorepo does not have 40k
stars. Record the repo's stars and note that the customization is one of N in that repo — the Adoption
rubric handles the discount.

## Content check for ranked candidates

For anything that will score above `min_score`, read the actual `SKILL.md`, `*.agent.md`, `*.instructions.md`, or `*.prompt.md` — whichever the customization type dictates. Score
comprehensiveness from what it contains, never from repo popularity or README claims.

Record:

- **Body length** — rough line count of the primary artifact
- **Bundled resources** — `scripts/`, `references/`, `assets/`; for agents: `tools`, `mcp-servers`, `hooks` frontmatter; for plugins: `agents/`, `skills/`, `hooks/hooks.json`, `mcp.json`, `lsp.json`
- **Depth signals** — concrete code, version-specific guidance, decision tables, anti-patterns,
  worked examples
- **Shallowness signals** — generic advice restating vendor docs, no version anchoring, obvious
  LLM-generated filler, a body that is mostly headings

A 900-line artifact that is 800 lines of generic platitudes scores below a 180-line one with real
version-specific guidance and a reference tree. Length is a weak proxy; read it.

## Canonicalization and dedup

The same customization is routinely vendored across many registries and mega-collections.

1. Resolve every candidate to its **upstream source repository**. Registry manifests often give this
   directly — prefer that over guessing.
2. Group by upstream `(repo, path)`.
3. Keep one row per group. Record mirror count as a metric, not as separate rows.
4. When upstream is genuinely unclear (no attribution, no manifest), catalog the copy you can
   verify and flag `Upstream: unresolved`.

Mirror count is a mild adoption signal — many independent registries vendoring the same customization
suggests real usage. It is not a substitute for stars or installs.

## Supply-chain flags

Installing a customization can execute code or grant data access. Flag, per row, whether it bundles:

| Flag | Why it matters |
|---|---|
| `hooks` | `.github/hooks/*.json`, plugin `hooks/hooks.json`, or agent-scoped `hooks` frontmatter — runs commands on lifecycle events |
| `shell-preapproved` | SKILL.md `allowed-tools` includes `shell` / `bash` / `execute` — GitHub explicitly warns against pre-approving in unreviewed skills |
| `scripts` | Executable code the skill may invoke |
| `mcp` | Plugin `mcp.json`, agent `mcp-servers`, or repo MCP settings — network and credential access |
| `lsp` | Plugin ships `lsp.json` — installs a language server |
| `legacy-format` | `.chatmode.md`, retired `infer` field, or pre-`.agent.md` layout |
| `network` | Instructions direct fetches to non-obvious endpoints |
| `unpinned` | No pinned commit SHA or version in the registry entry |

Report these **separately from the score**. A high-quality customization with elevated permissions is
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

Version-anchored customizations go stale faster than concept customizations. A customization pinned to a
superseded framework version is stale even with recent commits.

## Unverified handling

When something is probably real but cannot be confirmed — repo private, org renamed, only ever
referenced secondhand — it does **not** go in `Catalog`.

If `include_unverified` is true, list it in a clearly separated section with: the claim, where the
claim came from, what was attempted, and why it failed. If false, omit it entirely and note the
count in the Run Log.

Never soften an unverified item into a verified-looking row.
