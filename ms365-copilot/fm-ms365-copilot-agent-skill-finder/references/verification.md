# Verification

The gate between "found a mention" and "goes in the catalog". Nothing reaches `Catalog` without
clearing every rule here.

## The core rule

**A search snippet is not evidence.** Aggregator listings, blog roundups, and search results
describe extensions that were renamed, archived, or never existed. Fetch the artifact.

Every `Catalog` row must have a URL that was fetched during **this run** and returned the artifact.
Record `verified_at` as the run timestamp.

## Existence check

Fetch the candidate and confirm it matches **one** of the qualifying artifact shapes in
`references/artifact-types.md`. Fails all of them → not a M365 Copilot extension. Drop it, or
move it to Unverified with the reason.

**Things that look like extensions and are not:**

| Looks like | Actually is |
|---|---|
| A README listing extensions | Documentation. Follow it to the real artifacts. |
| A blog post titled "10 best extensions for X" | A pointer. Verify each item independently. |
| A prompt template repo | Not a extension unless it ships a conformant artifact. |
| A vendored copy in a mega-collection | A mirror. Resolve upstream. |
| `.github/skills/*/SKILL.md`, `.github/copilot-instructions.md`, `*.agent.md` | **GitHub Copilot** customization. Different product. Exclude. |
| A paste-ready instruction block for Agent Builder | Real and useful, but not a deployable package. Catalog as type `Instructions` with Comprehensiveness scored on the text; never as `Agent`. |
| A `manifest.json` with only `bots` / `composeExtensions` and no `copilotAgents` | An ordinary Teams app or message extension. Message extensions are maintenance-mode for Copilot. |
| A Copilot Studio agent shared inside one tenant | Not discoverable or installable outside that tenant. Record only if the template or export is public. |
| An Office Add-in (`Samples/excel-copilot-skill`) | Add-in sample, not an M365 Copilot extension. Out of scope. |
| Microsoft Learn "agent skills" training page | Unrelated support/training content. Ignore. |

## Platform attribution

A extension must be shown to work on **M365 Copilot** specifically. Evidence, strongest first:

1. It is listed in a M365 Copilot first-party registry or official docs.
2. Its own README, manifest, or install instructions name M365 Copilot.
3. It uses a format M365 Copilot is documented to load, placed where M365 Copilot
   is documented to look.
4. A cross-platform aggregator tags it as M365 Copilot-compatible — **weakest**; aggregator
   tags are often inferred from format alone.

Record which level applied in the `Compatibility Evidence` column. A extension with only level-4
evidence scores no higher than **Portable** in the gap analysis unless you confirm level 3 by
reading the artifact yourself.

**M365-specific fingerprints, strongest first:** `manifest.json` containing `copilotAgents.declarativeAgents[]`, `agentSkills[]`, or `agentConnectors[]`; a `declarativeAgent*.json` with `"version": "v1.x"` and `$schema` under `developer.microsoft.com/json-schemas/copilot/declarative-agent/`; a plugin JSON with `"schema_version": "v2.x"` and `runtimes[]` (`OpenApi` / `LocalPlugin` / `RemoteMCPServer`); `main.tsp` using `@agent` / `@instructions` decorators; `m365agents.yml` (Agents Toolkit project). The Teams manifest `$schema` URL alone is **not** a discriminator — ordinary Teams apps share it. For store listings, the Partner Center "Microsoft 365 and Copilot" program and AppSource category "AI Apps and Agents" are the public attribution.

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

**Attribute stars to the right thing.** A extension inside a 40k-star monorepo does not have 40k
stars. Record the repo's stars and note that the extension is one of N in that repo — the Adoption
rubric handles the discount.

## Content check for ranked candidates

For anything that will score above `min_score`, read the actual `declarativeAgent.json` (agents), `SKILL.md` (skills), or the plugin manifest — whichever the extension type dictates. Score
comprehensiveness from what it contains, never from repo popularity or README claims.

Record:

- **Body length** — rough line count of the primary artifact
- **Bundled resources** — `appPackage/` contents (icons, `declarativeAgent.json`, `plugin.json`, OpenAPI spec, `skills/<name>/SKILL.md` with `references/`), `m365agents.yml` pipeline, TypeSpec sources, connector schema
- **Depth signals** — concrete code, version-specific guidance, decision tables, anti-patterns,
  worked examples
- **Shallowness signals** — generic advice restating vendor docs, no version anchoring, obvious
  LLM-generated filler, a body that is mostly headings

A 900-line artifact that is 800 lines of generic platitudes scores below a 180-line one with real
version-specific guidance and a reference tree. Length is a weak proxy; read it.

## Canonicalization and dedup

The same extension is routinely vendored across many registries and mega-collections.

1. Resolve every candidate to its **upstream source repository**. Registry manifests often give this
   directly — prefer that over guessing.
2. Group by upstream `(repo, path)`.
3. Keep one row per group. Record mirror count as a metric, not as separate rows.
4. When upstream is genuinely unclear (no attribution, no manifest), catalog the copy you can
   verify and flag `Upstream: unresolved`.

Mirror count is a mild adoption signal — many independent registries vendoring the same extension
suggests real usage. It is not a substitute for stars or installs.

## Supply-chain flags

Installing a extension can execute code or grant data access. Flag, per row, whether it bundles:

| Flag | Why it matters |
|---|---|
| `actions-write` | Plugin actions (`OpenApi` / `RemoteMCPServer`) that perform writes, not just reads — check `functions[]` and the OpenAPI verbs |
| `graph-scopes` | Connector or agent requests broad Microsoft Graph permissions |
| `scripts` | Skill bundles executable scripts (sandboxed, no network at runtime in preview — but review anyway) |
| `remote-mcp` | `RemoteMCPServer` runtime or `agentConnectors[].toolSource.remoteMcpServer` — external endpoint with `OAuthPluginVault` or API-key auth |
| `cea-hosting` | Custom engine agent requiring Azure Bot Service / Foundry hosting the user must operate |
| `preview` | Relies on preview features (Frontier Program skills, `wiqd` plugin surface) — may change or be unavailable in the user's tenant |
| `uncertified` | Store listing shows publisher attestation but not Microsoft 365 certification |
| `unpinned` | No pinned commit SHA or version in the registry entry |

Report these **separately from the score**. A high-quality extension with elevated permissions is
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

Version-anchored extensions go stale faster than concept extensions. A extension pinned to a
superseded framework version is stale even with recent commits.

## Unverified handling

When something is probably real but cannot be confirmed — repo private, org renamed, only ever
referenced secondhand — it does **not** go in `Catalog`.

If `include_unverified` is true, list it in a clearly separated section with: the claim, where the
claim came from, what was attempted, and why it failed. If false, omit it entirely and note the
count in the Run Log.

Never soften an unverified item into a verified-looking row.
