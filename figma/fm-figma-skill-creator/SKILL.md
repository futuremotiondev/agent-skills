---
name: fm-figma-skill-creator
description: Creates, converts, reviews, tests, and publishes skills that run inside Figma's built-in AI agent, and ports them to and from coding-agent SKILL.md skills that drive the Figma MCP server. These are single-file Markdown skills invoked with a slash command in Figma Design and Figma Make. Use whenever the user wants to create a Figma skill, write a skill for the Figma agent, turn a workflow, checklist, critique rubric, audit, or design-system rules into a Figma skill, convert an existing Claude Code, Cursor, or Codex skill to run inside Figma (or the reverse), lint or review a Figma skill, write its Community listing, or test and publish one, and whenever the user has only a vague idea for a Figma skill and wants options. Not for Figma plugins or widgets (use fm-figma-plugin-creator), not for custom shaders (use fm-figma-shader-creation), and not for building the design system itself.
license: MIT
compatibility: Scripts need Node 18 or newer. The Figma MCP server is optional and used only for the coding-agent edition.
metadata:
  version: "1.2"
  author: "Futuremotion Studio"
  category: "Workflows"
  tags: "skill authoring, figma agent, templates, validator, publishing, mcp porting"
  applies-to: "skill files, templates, listings"
  runtimes: "mcp"
---

# Figma skill creator

Produces a complete, validated Figma skill package: a master `SKILL.md` written in the house style, an overlay for the coding-agent edition, trigger-eval queries, an eval log, Community listing copy, and a `dist/` folder holding the three shipping editions (upload, paste, coding-agent) built by the scripts in this folder. The master is the only file a human edits; everything in `dist/` is regenerated.

Figma provides no linter, template, or test harness for in-app skills. This skill supplies all three and encodes what the research established about how the Figma agent reads, routes, and runs a skill. Read the hard rules before writing anything.

## Hard rules

These are facts about the runtime, not preferences. Violating one produces a skill that silently misbehaves.

| Rule | Why |
| --- | --- |
| One Markdown file. No `references/`, `scripts/`, `assets/`, zips, or `.skill` bundles. | Figma accepts a single `.md`; folders are rejected or dead. |
| `name` is the slash command and must match `^[a-z0-9]+(-[a-z0-9]+)*$`, 1 to 64 chars, prefixed `fm-`. | Spec rule; generic names collide in the slash menu. |
| `description` is the only routing text. Capability first, then "Use whenever...", then "Not for X (use /y)". Under 1,024 chars, no `<` or `>`. | Figma auto-selects and previews from it; Claude Code truncates listings. |
| Phrase triggers as requirements ("Always use this skill when..."), never restrictions ("only when", "unless"). | Figma's own guidance; restrictive phrasing suppresses auto-selection. |
| Only the first skill mentioned in a prompt runs. Never invoke `/other-skill` mid-instruction. | Point to siblings only as "Not for X (use /y)". |
| Two Figma editions: upload (one clean frontmatter block, name and description only) and paste (no frontmatter). | Upload fills the form from the block; Start from scratch keeps the block as literal text. |
| `<!-- target:figma-app -->` and `<!-- target:mcp -->` sections exist only in the master. The build strips them. | Figma renders HTML comments as visible text; MCP tools do not exist in-app and in-app tools do not exist over MCP. |
| The tool-neutral core never names a tool. Design actions only: "bind the fill to the matched variable", "place the frame 80 px to the right". | The same core must run in Figma, Claude Code, Cursor, and Codex. |
| Prototyping, vector editing, slots, asset export, and diagrams get plan-only wording. | Coming soon or unsupported for the in-app agent as of November 2026. |
| Scope gates with a verbatim numbered question when nothing is selected. Never expand to the page or file silently. | Whole-file runs burn AI credits and are the top complaint pattern. |
| Work on duplicates. Never move, edit, or delete the source. Verify by reading the canvas back in a later step. | Undo reverts one step and there is no diff view. |
| Numbers, names, and thresholds instead of adjectives. Named rules with Do and Do-not examples. | Figma's "customized vs generic" lesson: adjectives produce generic output. |
| The validator passes with zero errors on the master and on every edition before anything is handed over. | `scripts/validate-figma-skill.mjs --rules` is the authoritative rule list. |

## Which workflow

| The user wants to... | Workflow | Start with |
| --- | --- | --- |
| Has a vague or exploratory idea ("something for our design system", "help with handoff") | 0. Ideate | ask the grounding question, then the concept cards |
| Make a new skill for the Figma agent (critique, audit, generator, conventions, synthesis, process) | A. Create | `templates/skill-master.md` plus the matching `templates/type-*.md` |
| Run an existing Claude Code, Cursor, or Codex skill inside Figma | B. Port to Figma | `scripts/build-skill-editions.mjs --flatten` |
| Run an existing Figma skill from a coding agent over MCP | C. Port to a coding agent | the exported or pasted body |
| Check, lint, or improve a Figma skill | D. Review | `scripts/validate-figma-skill.mjs` then the authoring rubric |
| Write the Community or team listing, pick artwork, publish | E. Listing and publish | `templates/listing-copy.md` |
| Test triggering and behaviour, iterate after a live run | F. Test and iterate | `templates/eval-queries.md`, `templates/EVAL-LOG.md` |
| Emit a design-system-specific skill from another skill (for example fm-figma-design-system-creator) | A with `type-design-system-conventions.md` | fill the token, component, and naming tables from the system |

Before starting Workflows A to F, confirm three things with the user if they are not already stated: what the skill does in one sentence, whether it runs in Figma only or in Figma and coding agents (default: both), and whether it changes the canvas or only reports. Ask once, together, then proceed. Workflow 0 asks one grounding question instead and pre-fills these three from the chosen card.

## Workflow 0: a vague idea

For a user who knows the moment that hurts but not the skill that would fix it. Ask one question, look at the file if one is offered, pitch five concept cards, and hand the chosen card to Workflow A.

1. **Ask one grounding question**, verbatim: "What is the moment you wish this skill already existed, and what do people do by hand there?" Wait.
2. **Offer recon** if a file is at hand: "If you give me the file link I'll look at how it is built before suggesting anything." If a key arrives, run the read-only inventory (the recon script below) and keep five observations: pages and their purpose by name, component-set and component counts, variable collections with mode names, text and colour style counts, and naming patterns or anything unusual (the naming sample, empty pages, Scratch pages, a Make project).
3. **Generate five concept cards** with `templates/concept-cards.md`:
   - **Mapping:** map the grounding answer to surfaces and patterns through the seeds' `tags` and `fits when` lines in `references/skill-idea-catalog.md`.
   - **Card sourcing:** take at least two cards from matched cells, at least one from an empty cell, and one wildcard.
   - **Landscape check:** check `references/skill-landscape.md` so each card says "new" or "better than X".
   - **Feasibility check:** check feasibility against `references/agent-capabilities-and-tools.md`.
   - **Cost model:** cost with the observed model (about 10 credits to ask, 22 to 24 per page-scale audit, 18 per five fixes) scaled by scope.
   - **Ranking and wildcard:** rank by value to the user's stated moment; card 5 is the wildcard.
   - **Plan-only rule:** unsupported ideas are reshaped into plan-only form or dropped; at most one plan-only card.
   - **Validator step:** before showing the deck, run each Does line from this skill's folder with `node scripts/validate-figma-skill.mjs --description "<Does line>"`, passing the whole line as one argument and escaping any double quotes inside it, and rewrite any line that warns.
4. **Ask which to build.** Plain text is canonical and works in every host: "Which one should I build first? 1 to 5, or tell me what to change." In a host with a structured question tool (Claude Code's AskUserQuestion, which allows at most four options and adds Other itself), also ask through it: the deck stays five cards; cards 1 to 4 are the options, each with its hook as the description, and the question text reads "Card 5 is the wildcard: choose Other and type 5, or describe a change." Decided by Futuremotion on 2026-11-02: lose a button, never a card. In a host with a structured question tool, show the plain-text footer question and follow it once with the structured question; in a host without one, ask once, in plain text only.
5. **Hand off to Workflow A** with the card's Does line as the description draft, its Type as the template, its Writes line as the canvas-change answer, and its Reads, Produces, and Needs as the intake answers. Its Runs in line answers the runtime question, and its Confirm before building questions are asked before Workflow A step 1. Append the chosen card to `## Promoted from sessions` in the catalog with the date.

### Recon script (MCP hosts)

Read-only, one call, no page switching. Load the `figma-use` skill, call `create_session` with the file key, then run the script below through `use_figma` and keep the five observations from step 2. Counts and the naming sample cover the current page only, so name that page when reporting them. Comment volume is not observed, because comments are not readable through the script path; the naming sample stands in for naming patterns. Without the Figma MCP server, skip recon and say so.

```javascript
// Workflow 0 recon: read-only inventory of the open file. No writes, no page switching.
const page = figma.currentPage;
const pages = figma.root.children.map((p) => ({ id: p.id, name: p.name }));
// One traversal of the current page, tallied by node type.
const found = page.findAllWithCriteria({ types: ["COMPONENT_SET", "COMPONENT", "INSTANCE"] });
const counts = { componentSets: 0, components: 0, instances: 0 };
for (const node of found) {
  if (node.type === "COMPONENT_SET") counts.componentSets += 1;
  else if (node.type === "COMPONENT") counts.components += 1;
  else counts.instances += 1;
}
const localCollections = await figma.variables.getLocalVariableCollectionsAsync();
const collections = localCollections.map((c) => ({
  name: c.name,
  modes: c.modes.map((m) => m.name),
  variables: c.variableIds.length,
}));
const styles = {
  text: (await figma.getLocalTextStylesAsync()).length,
  paint: (await figma.getLocalPaintStylesAsync()).length,
};
// Naming-pattern sample: the first ten top-level layers on the current page.
const namingSample = page.children.slice(0, 10).map((n) => n.name);
return { page: page.name, pages, counts, collections, styles, namingSample };
```

## Workflow A: create a new skill

1. **Classify the skill type** and copy the template:

   | Type | Template | Default output |
   | --- | --- | --- |
   | Critique or review | `type-critique-review.md` | chat report, read-only |
   | Standards, QA, or audit | `type-standards-qa-audit.md` | ranked table, fix after confirmation |
   | Generation or builder | `type-generation-builder.md` | new frame beside the source |
   | Design-system conventions | `type-design-system-conventions.md` | rules applied to the selection |
   | Research or synthesis | `type-research-synthesis.md` | themes with verbatim evidence |
   | Workflow or process | `type-workflow-process.md` | staged run with checkpoints |
   | None of these | `skill-master.md` | shape it from the skeleton |

2. **Create the folder** `figma/fm-<verb>-<object>/` (or a subfolder the user names) with `SKILL.md`, `overlay.claude.yaml` from `templates/overlay.claude.yaml`, `eval-queries.md`, `EVAL-LOG.md`, and `listing/listing-copy.md`. The `name` must equal the folder name.

3. **Write the description first.** Formula: third-person capability that names the output, then "Use whenever the user asks to ..." with three to five quoted or near-verbatim phrases, then "Not for ... (use /fm-other)". Read it back: would a designer who has never seen the skill type one of those phrases? If not, rewrite before touching the body.

4. **Write the body in the skeleton order:** title and lede, When to use, Before you start (surface check, scope question verbatim, inputs), Instructions (numbered, one question per message, a Verify step), Output contract, Do and do not (named rules with real values), Examples, Common edge cases, Helper scripts (only when the skill runs code), Final gate. `references/skeleton-guide.md` explains each section. `references/authoring-styles.md` has the verbatim idioms from Figma's own skills and the Cheddar customized-vs-generic lesson; read it the first time you author in a session.

5. **Replace every angle-bracket placeholder.** Agent fill-ins such as `<n>` in an output contract may stay; authoring placeholders such as `<Step name>` may not. Keep the core tool-neutral.

6. **Put helper code in the core, then add the target sections** at the end of the body. Code lives in a core `## Helper scripts` section after Common edge cases and before the Final gate: one fenced `javascript` block per helper whose first body line is `// helper: <name>`, with the name matching `^[a-z][a-z0-9-]*$` (lowercase, hyphenated). Each helper is self-contained, returns values with `return`, re-fetches nodes by id, works in batches of about 25, measures in a later call, and loads fonts before text edits. The build inlines every helper in the Figma editions and moves each to `scripts/<name>.js` in the coding-agent edition; a helper fence inside a target section would ship to one runtime only, and the validator warns about it (`helper-placement`). Both target sections run the helpers by name: `target:figma-app` through `evaluate_script`, with a prose fallback sentence; `target:mcp` with the `figma-use` prerequisite, `create_session`, and `use_figma` with `skillNames`, sending each helper without its `(async () => {` and `})();` wrapper lines. `references/agent-capabilities-and-tools.md` lists what each runtime has.

7. **Validate and build:**

   ```bash
   node scripts/validate-figma-skill.mjs figma/fm-<name>/SKILL.md --edition master
   node scripts/build-skill-editions.mjs figma/fm-<name>/SKILL.md --out figma/fm-<name>/dist --validate
   ```

   Fix every error. Keep a warning only with a one-line reason in `EVAL-LOG.md`.

8. **Fill `eval-queries.md`** with ten positive and ten negative prompts (40 percent held out) and `listing/listing-copy.md` with the description pasted verbatim.

9. **Hand over for the live test.** Give the user the path to `dist/<name>.figma.md` for Manage skills > Add skill > Upload, the paste edition plus `dist/<name>.paste.fields.txt` (the name and description to type into the Start-from-scratch form; the form caps the description at 1,024 characters), and the first three positive eval prompts. Tell them to test on a duplicate file. Log the result in `EVAL-LOG.md` and record any answer to the open questions in `references/troubleshooting.md`.

## Workflow B: port a coding-agent skill to Figma

1. Flatten: `node scripts/build-skill-editions.mjs --flatten path/to/skill --out dist/`. The flat file inlines `references/*.md` and lists `scripts/` and `assets/` for manual conversion.
2. Walk the 14-step porting table in `references/porting-and-dual-target.md`: move Claude Code keys to the overlay, convert scripts to ordered steps or a core helper (Workflow A step 6), convert assets to fenced blocks or tables, delete relative links, move MCP tool text into `target:mcp`, add a `target:figma-app` section with a fallback, re-check size and split at about 500 lines.
3. Rename to `fm-<verb>-<object>` if the source name is generic, and rewrite the description with the formula.
4. Validate as master, build, validate the three editions, and hand over as in Workflow A step 9.

## Workflow C: port a Figma skill to a coding agent

1. Obtain the body: Export from Manage skills if available, otherwise the pasted instructions. Treat the Figma copy as input, never as the master afterwards.
2. Wrap it: one frontmatter block with `name` (equal to the new folder name), `description`, and `metadata.version` quoted. Create `overlay.claude.yaml`.
3. Move any `evaluate_script`, `show_widget`, `get_comments`, or shader-tool text into `target:figma-app` with a prose fallback; add a `target:mcp` section that loads `figma-use` and uses `create_session` and `use_figma`. Replace selection assumptions with "ask for a node URL or pasted content" in the core.
4. Validate as master, build, run `validate-figma-skill.mjs dist/claude/<name>/SKILL.md --edition coding-agent`, and `npx skills add ./dist/claude --list` if the skills CLI is installed.

## Workflow D: review an existing skill

1. Run the validator with the right `--edition` and report its output verbatim.
2. Score the body against the rubric in `references/authoring-styles.md`: description formula; requirement-phrased triggers; scope gate present; one question per message; named rules with Do and Do-not; numbers not adjectives; output contract and cap; verify step; final gate; capability gates for unsupported features; no mid-instruction slash invocations; size.
3. Report findings as a table ranked P0 to P3 with line numbers and the exact rewrite. P0 is anything that makes the skill misroute, edit the source, or claim an unsupported capability.
4. Apply fixes only after the user confirms which rows. Re-run the validator and show the before and after summary lines.

## Workflow E: listing and publishing

1. Fill `listing/listing-copy.md`: tagline under 80 characters, category from the six (Research and strategy, Generation, Brand, Design systems, Critique, Workflows), three example prompts, artwork plan at 1920 × 1080 showing the output rather than a logo.
2. Confirm the description in the listing equals the frontmatter description character for character.
3. Give the publish path: Manage skills > select skill > More actions > Publish; team or organisation needs the file to sit in that team; Community adds tagline, category, thumbnail plus up to nine images, contributors, support contact, tags. Updates go through Publish changes. There is no documented review queue for skills.
4. For the coding-agent channel, point at the repo path and the `npx skills add futuremotiondev/agent-skills --skill <name>` line, and the `figma/community-resources` index PR titled `Add [skill] <name>` with repo topics `figma` and `figma-mcp`. `references/publishing-kit.md` has the field table and checklist.

## Workflow F: test and iterate

1. **Trigger eval.** Run the tune set three times each in a fresh chat on a duplicate file; a prompt passes at a trigger rate of 0.5 or better; a negative that triggers fails. Rewrite the description with the missed phrases and a sharper "Not for" clause, up to five rounds, then confirm on the holdout.
2. **Behaviour eval.** Run the Examples section prompts and check each line of the Final gate against the canvas. Any source edit, silent scope expansion, or unverified number is a defect.
3. **Live test log.** One entry per session in `EVAL-LOG.md`: prompt, selection, what the agent did, what it should have done, the change made. Bump `metadata.version` on every description or instruction change and re-upload; Figma keeps no version history.
4. **Settle open questions.** The first upload of any skill should record whether extra frontmatter keys survive, whether size limits exist, whether tables and images render, and whether `node.query` and `node.set` work under `evaluate_script`. Write the answers into `references/troubleshooting.md`.
5. **Probe paste-back.** When the user pastes a probe table, add it to `references/agent-capabilities-and-tools.md` under 'Observed in-app (probe results)' as a dated table for that runtime, replacing an older table for the same runtime; then revisit every `target:figma-app` section that relies on an API now marked `missing` or `error`.

## House style in one table

| Element | Write it as |
| --- | --- |
| Description | `Audits the selected frames against X and lists every Y with the exact fix. Use whenever the user asks to "check X", "audit X", or "find Y". Not for Z (use /fm-z).` |
| Scope question | `> Nothing's selected. 1. Audit the current page, or 2. select the frames you want first?` as plain text (question cards do not render Markdown), then wait |
| Question contract | One question per message, numbered options, stop. Every gate (scope, mode, fix, disclosure) says "through a structured question tool when the runtime has one", and the `target:figma-app` section names `ask_user_question`; the plain-text wording is the fallback and the record. Gates that name the tool render as cards with clickable options in-app; gates that do not render as plain text (Round 3, 2026-11-03). A follow-up that needs free text, such as row numbers, is asked as free text with no preset options. Never answer your own question or guess at an ambiguous reply. |
| Instruction | Verb first, with a number: "Snap each value to the nearest of 0, 4, 8, 12, 16, 24, 32, 40, 48, 64." |
| Named rule | `### Snap, do not nudge` with a **Do** bullet holding a real value and a **Do not** bullet holding the wrong output |
| Output contract | A fenced Markdown block the agent fills; a cap on rows; "no supported findings" instead of padding |
| Capability gate | "If the request needs prototyping, vector editing, slots, asset export, or diagrams, produce a plan only and say so." |
| Fallback in a target section | "If it is not available, perform the step with your own canvas tools and say which path you took." |
| Final gate | `## Final gate: do not finish until every line is true` with four to six checkable lines read from the canvas |

## Tool vocabulary split

| Section | May name | Must not name |
| --- | --- | --- |
| Core (tool-neutral) | design actions, Figma UI features (variables, components, styles, modes, comments, auto layout) | any tool identifier |
| `target:figma-app` | `evaluate_script`, `show_widget` and `sendPrompt` (missing in the 2026-11-03 Design-agent probe; never the only path), `read_me`, `get_comments`, shader fill tools, Figma's AI image creation capability, `ask_user_question` | MCP tools |
| `target:mcp` | `figma-use` skill, `create_session`, `use_figma` with `skillNames`, `get_design_context`, `get_screenshot`, `get_metadata`, `download_assets`, `generate_image` | in-app tools |

The evaluate_script contract is undocumented. Treat it as the Plugin API with these observed limits: nothing persists between calls, results come back through `return` and are truncated (not rejected) somewhere below 50,000 bytes, `setPluginData` throws (use `setSharedPluginData`), `figma.clientStorage` is not supported, `loadAllPagesAsync` exists but is untested (feature-check and degrade to the current page), measurements read zero in the call that built the node, and text sizing works in the order resize, then `textAutoResize`, then `characters`. `references/agent-capabilities-and-tools.md` carries the evidence tier for each claim.

## Scripts

```bash
node scripts/validate-figma-skill.mjs --rules                                   # rule table
node scripts/validate-figma-skill.mjs <file> --edition master|upload|paste|coding-agent [--strict] [--json] [--allow-placeholders]
node scripts/build-skill-editions.mjs <SKILL.md> --out <dir> [--overlay overlay.claude.yaml] [--validate] [--dry-run]
node scripts/build-skill-editions.mjs --flatten <skill-dir> --out <dir> [--dry-run]
```

Both scripts are dependency-free Node and share `scripts/lib/skill-md.mjs`. The validator exits 1 on any error. `--allow-placeholders` exists for validating the templates themselves; never use it on a skill you are shipping.

## Files in this skill

| Path | Use it when |
| --- | --- |
| `references/format-and-frontmatter.md` | you need the exact field rules, the three entry routes, naming, lifecycle, access and cost |
| `references/agent-capabilities-and-tools.md` | you are deciding what the in-app agent can do and which tool names belong where |
| `references/authoring-styles.md` | you are writing or reviewing a body: idioms, two authoring styles, the hybrid, anti-patterns |
| `references/skeleton-guide.md` | you want section-by-section guidance for the skeleton |
| `references/testing-and-maintenance.md` | you are running evals, a live test, or versioning |
| `references/publishing-kit.md` | you are writing the listing or publishing |
| `references/porting-and-dual-target.md` | you are converting in either direction or marking target sections |
| `references/troubleshooting.md` | something misbehaves, or sources disagree |
| `references/skill-landscape.md` | you need to know whether a skill idea already exists, or a concept card must say "new" or "better than X" |
| `references/skill-idea-catalog.md` | you are mapping a vague wish to gap cells and seeds in Workflow 0, or promoting a chosen card |
| `templates/skill-master.md` and `templates/type-*.md` | starting any new skill |
| `templates/overlay.claude.yaml`, `eval-queries.md`, `EVAL-LOG.md`, `listing-copy.md` | the companion files every skill folder gets |
| `templates/concept-cards.md` | you are pitching ideas in Workflow 0: the deck header, the twenty-line card, the footer question, and the deck rules |
| `examples/fm-spacing-rhythm-audit/` | a complete worked example with its built `dist/` editions |
| `examples/fm-figma-capability-probe/` | you need fresh evidence of which Plugin APIs a runtime exposes; optional, for skill authors, and its pasted-back table feeds Workflow F step 5 |
| `examples/ideation-runs.md` | you want to see Workflow 0 decks for three vague prompts and a recon smoke run |

## Final gate: do not finish until every line is true

- [ ] The user confirmed the one-sentence purpose, the target runtimes, and whether the skill changes the canvas
- [ ] `name` is `fm-` prefixed, spec-valid, and equals the folder name
- [ ] The description follows the formula, phrases triggers as requirements, and ends with a "Not for" clause
- [ ] The core names no tool; target sections carry the tool-specific text and a fallback sentence
- [ ] Every authoring placeholder is gone
- [ ] Validator: zero errors on the master and on all three editions
- [ ] `eval-queries.md`, `EVAL-LOG.md`, and `listing/listing-copy.md` exist and the listing description matches the frontmatter
- [ ] The user has the upload path, the paste fields, and the first test prompts, with the duplicate-file instruction
