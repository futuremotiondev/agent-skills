# Format, frontmatter, invocation, and lifecycle of in-app Figma skills

Evidence tiers used throughout: **Documented** (stated on a Figma help-center or developer page),
**Observed** (seen in published skills or a named third-party flow), **Unverified** (no source
settles it). Dates refer to what was true on 2026-11-02.

## The format in one paragraph

A skill for Figma's built-in agent is one Markdown file that "follows the Agent Skills
specification". Figma reads three things: a **name** (which becomes the slash command), a
**description** (the routing text the agent uses to decide when to apply the skill), and the
**instructions** body. Folders are unsupported: `scripts/`, `references/`, and `assets/` do not
exist in-app, zipped bundles and `.skill` files are rejected, and Figma Make accepts standalone
files only. Skills belong to the account and are available in every file.

## Three ways a skill enters Figma

| Route | Where | What happens to a `---` frontmatter block |
| --- | --- | --- |
| Ask the agent | Agent chat: "Take this conversation and turn it into a skill", or "Revise the attached skill.md to fit my design system" | The agent drafts name, description, and body; a preview and a Markdown editor follow (since 2026-08-13) |
| Upload a `.md` | Add context (+) > Skills > Add skill > Upload a file | Name and description are filled from the block and shown for review before Add (Documented review step; Observed auto-fill) |
| Start from scratch | Add context (+) > Skills > Add skill > Start from scratch | You type name and description into fields and paste the body. A pasted `---` block stays as literal text in the instructions, so delete it (Observed; the Qredence plugin instructions say so, and published pages show pasted blocks verbatim) |

Consequence: the UI name field, not any `name:` inside the body, sets the slash command. A
frontmatter block left inside the instructions is dead text that can mislead the model about its
own name (Figma's own `hifi-mockup-presenter` example ships with two stacked blocks, and a popular
third-party skill carries `name: design-review` under a listing named `superfuture-design-review`).

Ship two editions when you distribute: an **upload edition** with exactly one clean frontmatter
block at line 1, and a **paste edition** with no frontmatter. The build script does this.

## Frontmatter and body: what each runtime accepts

| Element | Figma in-app (Design, Make) | Evidence | agentskills.io spec | Claude Code |
| --- | --- | --- | --- | --- |
| Package shape | Single `.md`; folders unsupported; zip and `.skill` rejected; Make standalone only | Documented | Directory with `SKILL.md`; optional `scripts/`, `references/`, `assets/` | `.claude/skills/<name>/SKILL.md` plus supporting files |
| `name` | UI field; becomes the slash command; every published example is lowercase-hyphen | Documented (field, slash); Observed (kebab-case); Unverified (length, charset, uniqueness) | Required; 1 to 64 chars; lowercase letters, digits, hyphens; no leading, trailing, or double hyphen; must match the parent directory | Same, plus no `anthropic` or `claude`, no XML tags |
| `description` | UI field; the routing text; shown as the Community "Preview" text | Documented (field, trigger advice); Unverified (length limit) | Required; 1 to 1024 chars; what it does and when to use it | Recommended; `description` plus `when_to_use` truncated at 1,536 chars in the listing |
| Body | Markdown; tables, fenced code, and HTML comments survive publishing (comments are visible text) | Documented (Markdown); Observed | No format restrictions; under 500 lines and about 5,000 tokens recommended | Under 500 lines recommended |
| `license` | No Figma statement | Unverified | Optional | Accepted, not acted on |
| `compatibility` | No Figma statement; one Qredence skill ships it without reported problems | Unverified | Optional, max 500 chars | Accepted, not acted on |
| `metadata` | No Figma statement | Unverified | Optional string-to-string map; put `version` here as a quoted string | Accepted, ignored |
| `allowed-tools` | Never mentioned by Figma | Unverified | Experimental, space-separated | Supported; grants tools for the invoking turn |
| `disable-model-invocation` | No equivalent key; the enable/disable toggle blocks both auto and slash use | Unverified (key); Documented (toggle) | Not in spec | Supported |
| Other Claude Code keys (`when_to_use`, `argument-hint`, `model`, `context`, `hooks`, `paths`, ...) | No Figma statement | Unverified | Not in spec | Claude Code only |
| Relative links (`references/x.md`, `./`, `../`) | Cannot resolve | Documented (no folders) | One level deep recommended | Work |
| Images and external URLs in the body | No source | Unverified | Allowed | Allowed |
| Size limits | None published | Unverified | Recommendations only | 1,536-char listing cap |

Safest frontmatter for a file that must upload cleanly: `name` and `description` only. Keep
`metadata.version` (quoted) in the master and strip it from the Figma edition until you have run an
upload test that proves extra keys are tolerated.

## Invocation

- **Slash command** is the documented, dependable path: `/fm-spacing-rhythm-audit`. The `/` menu
  shows "a handful" of skills; the full list is under Add context > Skills > Manage skills. When the
  menu omits a skill, typing its name after `/` "often surfaces and runs it" (Figma support).
- **Picker**: [+] > Skills > Use skills, select, Send.
- **Automatic invocation** exists (a disabled skill "cannot be invoked automatically in chat or
  directly"). Figma publishes no selection algorithm. The one documented lever is wording:
  "Use active, unambiguous language to describe when to use the skill... Soft phrasing like 'use
  only when X is selected' tends to get read as 'don't use it unless X'... Phrase the trigger
  condition as a requirement rather than a restriction so it fires reliably."
- **Only the first skill mentioned in a prompt runs.** Skills cannot be chained by naming them in
  one message. Never instruct a skill to invoke another; point to it only as "Not for X (use /y)".
- **Make**: standalone files only; no skill can be invoked on the first prompt after a model switch.
- **Connectors** combine with skills in one prompt ("Use /build-from-prd ... from @Notion"). In
  Design, `@` also references library components, variables, and styles.
- Treat `/name` as the contract and auto-triggering as a bonus you tune with trigger evals.

## Naming

- The name is the slash command and the Community URL slug.
- Figma: use "a specific, non-generic name if you plan on publishing... Avoid generic names like
  'design-critique'... A simple addition of your name, team, or company." House rule: prefix every
  skill with `fm-`.
- Lowercase letters, digits, hyphens; no `claude` or `anthropic`; for the coding-agent edition the
  folder name must equal `name`.
- For the `figma/community-resources` index, names should not start with "figma".
- Renaming at publish: "only other users will see the new name. Your version of the skill will
  retain the existing name."

## Lifecycle

| Action | Where | Notes |
| --- | --- | --- |
| Enable / disable | Manage skills | Disabling blocks automatic and direct use; for a published skill it affects only your account |
| Edit | Manage skills > Edit (Markdown editor) | Figma: once a skill works, edit it directly rather than regenerating it each session (regeneration costs credits) |
| Export | Manage skills > "..." > Export | "so you can use it with your own agents"; exported shape and frontmatter round-trip are Unverified; never treat the Figma copy as master |
| Publish | Manage skills > More actions > Publish | Private (team or organization) or Community; see publishing-kit.md |
| Publish changes | Manage skills > Publish changes | No version number, changelog, or rollback; the page shows only "Last updated" |
| Unpublish | Manage skills | Retains the skill for you, removes it for others (documented for team and org) |
| Delete | Manage skills | Permanent; deleting a published skill removes it for all users; export first |

Known issues reported on the forum (July to October 2026): team-published skills visible in
Manage skills but not reachable by `/`; guests get no skills even with a Full seat, and it fails
silently.

## Access, cost, and visibility

- "Available on all plans. Users with Full seats can chat with the agent in Figma Design and Figma
  Make files. Users with View, Dev, or Collab seats can try the agent in Drafts. Requires edit
  access to the file." Other pages give narrower plan lists; state "needs edit access and agent
  access" in a listing rather than a plan list.
- The agent reached general availability on 2026-10-06 and consumes AI credits. Monthly seat pools:
  Starter 500 (150 per day cap), Professional Full 3,000, Organization Full 3,500, Enterprise Full
  4,250. Sample costs: a font change about 30, a canvas summary about 100, a five-screen flow about
  300. Hover the AI credits icon under a completed prompt to see what it cost.
- A whole-file audit can burn a Starter day in one run. Scope every skill to the selection by
  default, and say so in the skill text.
- Agent chats are visible to file collaborators by default since 2026-06-23. Keep secrets out of
  prompts and skills.

## Products

- The in-app agent is generally available in **Figma Design**. **Figma Make** shares the skills
  system but edits React project code (Files and Review tabs, optional Payload or Supabase
  backend, publish to web); instructions about frames and variables mean nothing there, so a
  cross-product skill must branch on the surface up front.
- **FigJam and Slides** agents are in closed beta (free while in beta); on 2026-10-07 Figma staff
  said the agent "is currently only available in Figma Design files". Gate FigJam and Slides
  instructions behind a surface check and fall back to a plan.
