# Discovery Sources — Microsoft 365 Copilot

Work these in tier order. Everything ranked must be traced back to its upstream repository or
store listing. **Never conflate with GitHub Copilot** — filter out `docs.github.com/copilot`,
`code.visualstudio.com/docs/agent-customization`, `.github/skills`, `.agent.md`, `copilot plugin
install`, and `gh skill` hits; keep `learn.microsoft.com/microsoft-365/copilot/*`, Copilot Studio,
Agents Toolkit, Agent Store, AppSource.

Facts below were current as of 2026-10-24. Microsoft reorganized its sample repos in January 2026
and its Learn docs tree in 2026; URLs under `/microsoft-365/copilot/extensibility/` are the most
stable. Record drift in the Run Log.

---

## Tier 1 — First-party sources

| Source | What it is | Fetch |
|---|---|---|
| `github.com/pnp/copilot-pro-dev-samples` | **Current canonical pro-code sample home** (moved from the archived `OfficeDev/Copilot-for-M365-Samples` on 2026-01-02). Declarative agents at `samples/da-*` (`da-CareerCoach`, `da-IdeaCoach`, `da-LearningCoach`, `da-PromptCoach`, `da-WritingCoach`, `da-trey-research`, `da-trey-research-auth`), TypeSpec samples. Community-run; "Microsoft doesn't own or curate these samples." | Enumerate `samples/`; `da-` prefix = declarative agent |
| `github.com/microsoft/m365-agent-templates` | Agent Library templates — the GitHub source behind Copilot Studio's "Build with VS Code" option. | Enumerate templates |
| Agent Library (Copilot Agent Kit) | In-product hub of prebuilt agent templates and components (April 2026+). Requires Power Platform maker role. Marketplace link `aka.ms/agentlibrarymarketplace`. | Tenant-gated; cite via the GitHub source above |
| `github.com/OfficeDev/microsoft-365-agents-toolkit-samples` | Scenario-focused pro-code samples surfaced in the Toolkit's VS Code gallery. `atk list samples` enumerates the same set from the CLI. | Enumerate; or run `atk list samples` / `atk list templates` if a shell is available |
| `github.com/microsoft/Agents` (+ `Agents-for-net`, `-js`, `-python`) | Microsoft 365 Agents SDK — custom engine agent samples under `samples/`. 1.1k★. | Only when `types` includes `cea` |
| `github.com/microsoft/CopilotStudioSamples`, `microsoft/Power-CAT-Copilot-Studio-Kit`, `microsoft/skills-for-copilot-studio`, `microsoft/mcs-labs` | Copilot Studio samples, the Power CAT kit, a CAT-team authoring plugin, and labs. | Only when `types` includes `studio` |
| `github.com/microsoftgraph/msgraph-sample-github-connector-{dotnet,python,typescript}` | Connector samples. | Only when `types` includes `connector` |
| `github.com/microsoft/wiqd` | Work IQ Dev Tools — preview CLI for agents and plugins (`wiqd plugin import|create|add skill|validate|share|export`). Docs at `microsoft.github.io/wiqd/`. Source private during preview. | For plugin-format and import mechanics |
| Microsoft Adoption **Sample Solution Gallery** | `adoption.microsoft.com/sample-solution-gallery/?product=Microsoft+365+Copilot` (and `product=Copilot+connectors`). Microsoft-hosted, community-driven. | Browse; no machine feed verified |
| Microsoft 365 Copilot Connectors Gallery | Prebuilt connectors list on Microsoft Learn. | When `types` includes `connector` |
| Microsoft Learn `/microsoft-365/copilot/extensibility/` | Authoritative docs: `overview`, `agents-overview`, `declarative-agent-manifest-1.9`, `plugin-manifest-2.4`, `declarative-agent-skills`, `plugins-overview`, `plugin-type-skills`, `overview-copilot-connector`, `samples`, `publish`; Cowork plugins at `/microsoft-365/copilot/cowork/cowork-plugin-development`. | Use the Microsoft Learn MCP tool when available — it is the most reliable fetch path |
| `@microsoft/m365agentstoolkit-mcp` | Toolkit MCP server exposing schema fetchers and a "Samples and Templates Code Snippets Retriever". | If an MCP client is available, it is a programmatic sample index |

**Archived — do not cite as current:** `OfficeDev/Copilot-for-M365-Samples` (archived 2026-01-02,
redirects to PnP). The Learn page `agents-are-apps` redirects to plugin content; its URL is unstable.

---

## Tier 2 — GitHub structured search

**Code search on manifest fingerprints.** Built from verified filenames and keys; GitHub search was
not executable during research, so verify the first query returns sane results.

```
path:declarativeAgent.json                                      # the agent manifest
path:appPackage/declarativeAgent.json                           # Agents Toolkit layout
"copilotAgents" "declarativeAgents" path:manifest.json          # app packages referencing agents
"agentSkills" path:manifest.json                                # standalone / plugin skills
"agentConnectors" "remoteMcpServer" path:manifest.json          # plugin packages with MCP connectors
"json-schemas/copilot/declarative-agent/" language:JSON         # any version of the agent schema
"schema_version" "v2.4" "runtimes" language:JSON                # current plugin manifests
"RemoteMCPServer" language:JSON                                 # MCP-backed plugins
"agent_skills" "folder" language:JSON                           # agents using skills (v1.9)
path:main.tsp "@agent("                                         # TypeSpec agents
path:m365agents.yml                                             # Agents Toolkit projects
```

Two-file conditions (`SKILL.md` *and* `copilotAgents`) need two-step filtering: find packages first,
then check for `skills/`.

**Negative filters (mandatory):** drop hits whose only Copilot content is `.github/skills/`,
`.github/copilot-instructions.md`, `.github/agents/`, or `.github/prompts/` — that is GitHub Copilot.

**Topic tags** — `github.com/topics/<tag>`. Only `copilot-for-microsoft-365`, `microsoft-365`,
`microsoft-teams`, and `copilotstudio` are confirmed as applied topics; the rest are plausible:

```
copilot-for-microsoft-365 · microsoft-365-copilot · m365-copilot · copilotstudio · copilot-studio
declarative-agent · declarative-agents · copilot-extensibility · copilot-connectors · microsoft-365
```

**Vendor search.** For any SaaS product in the topic, check the vendor's org for an M365 Copilot
agent or connector, and check AppSource for a listing under "AI Apps and Agents".

---

## Tier 3 — Stores and community lists

| Source | Notes |
|---|---|
| **AppSource** (`appsource.microsoft.com`) | The only **public, unauthenticated** surface where third-party M365 Copilot agents are listed (Teams Store listings propagate here). Partner Center categories "AI Apps and Agents" / "Machine Learning". Shows ratings, review counts, publisher, certification badges. No verified deep-link for "all Copilot agents" — search by scenario. |
| **Agent Store** (in-product) | Tenant-authenticated; collections "Built by your org", "Agents for your team". No public API found. Record store items by AppSource URL instead. |
| `kesslernity/awesome-copilot-studio-agents` | 103 paste-ready **instruction sets** for Agent Builder, 17 categories, ~498★, CC BY-SA 4.0; promotes the maintainer's paid products. Catalog as type `Instructions`, not `Agent`. |
| `github/awesome-copilot` → `declarative-agents` skill, `mcp-m365-copilot` plugin | **GitHub Copilot** artifacts *about* M365. Not M365 extensions. Cite only in the gap analysis as authoring aids. |
| Microsoft Tech Community, Microsoft 365 Developer Blog (`devblogs.microsoft.com/microsoft365dev`) | Announcements (e.g. 2026-09-30 "Bring your plugin to Microsoft Copilot with Work IQ Developer Tools"). Pointers, not a registry. |
| `luishdemetrio/agentsbestpractices` and similar | Surfaced in search only; unverified. |

**The community layer is thin.** Expect to synthesize from GitHub fingerprints + AppSource + the
PnP repo + the Adoption gallery rather than consume an existing index. Saying so in the report is
correct.

---

## Search technique

**Search by scenario and data source, not by "skill".** M365 extensions are described as "an agent
for X" or "a connector for Y" — the word "skill" mostly returns GitHub Copilot or Bot Framework
noise. Search the business vocabulary: the SaaS product name, the Microsoft 365 workload (SharePoint,
Dataverse, Outlook), the role (HR, sales ops), the document type.

**Respect `types` and `source_form`.** `--types skill` leads with `agentSkills`/`agent_skills`
fingerprints and Copilot Studio Skills; `--source-form store` leads with AppSource.

**Treat tenant-gated items honestly.** If a template or store item cannot be fetched without
login, record what the public page shows and mark `Tenant Gated = Y` — do not infer contents.

**Log queries that return nothing**, including AppSource searches with no relevant listings.

---

## Budget by depth

| Depth | Tier 1 | Tier 2 | Tier 3 | Total |
|---|---|---|---|---|
| `quick` | PnP repo + templates repo | 3–5 fingerprint searches | AppSource search | 8–15 |
| `standard` | all repos for the selected `types` + Learn docs | 8–12 searches | AppSource + community lists | 25–40 |
| `exhaustive` | all Tier 1 + vendor orgs + Adoption gallery | 20–30 searches | 15–25 | 60–90 |

If a run would exceed the `exhaustive` budget, deliver what is verified, mark remaining facets
**not yet searched**, and say which queries were left unrun. Never pad a thin result.
