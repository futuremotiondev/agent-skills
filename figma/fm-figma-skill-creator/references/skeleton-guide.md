# The canonical skeleton, section by section

`templates/skill-master.md` is the skeleton. This reference explains what each section is for,
what to put in it, and what to leave out. Section order matters: the agent reads top to bottom, so
routing and scope come first, execution detail last.

When a skill starts from a Workflow 0 concept card, the card maps onto this skeleton: its Does
line is the description draft; its hook and Fits your moment line seed the lede; its Try it prompt
and Fits your moment line seed When to use; its Needs line becomes Before you start; and its
Produces and Writes lines become the Output contract, with Writes deciding whether fixes wait for
confirmation.

## Frontmatter

```yaml
---
name: fm-<verb>-<object>
description: <capability naming the output>. Use whenever the user asks to "<phrase>", "<phrase>" or "<phrase>", or selects <object> and asks to <verb> it. Not for <nearest wrong task> (use /<other-skill>).
metadata:
  version: "1.0"
  author: "Futuremotion Studio"
  category: "<one of the six Community categories>"
  tags: "<comma-separated, lowercase>"
  applies-to: "<pattern and surface>"
  runtimes: "figma-design, figma-make, mcp"
---
```

- `name`: lowercase, hyphens, `fm-` prefix, verb-object. It is the slash command.
- `description`: the routing text. Third-person capability, then requirement-style triggers with
  quoted user phrases, then one exclusion. Under 1,024 characters, key use case first.
- `metadata` holds six quoted strings: `version`, `author`, `category`, `tags`, `applies-to`, and
  `runtimes`, which a later manifest generator reads. They stay in the master and the coding-agent
  edition; the build strips them from the upload edition, which keeps only name and description.

## Title and lede

A `#` title in plain words, then one paragraph: what this produces, where it lands (chat, a new
frame next to the selection, variables, a comment), and the two or three principles that matter
more than the template. Figma's `usability-test-guide` opens with "These principles matter more
than the template" and lists three.

## When to use

Three to five bullets. Each is a situation written as a requirement ("The user asks to..."; "The
user selects ... and wants ..."). End with a bold **Do not** line naming the adjacent task this
skill does not do and the skill that does.

## Before you start

The scope gate. Always three checks:

1. **Surface.** Design file: canvas layers. Make file: project code or a spec. FigJam or Slides, or
   a request that needs prototyping, vectors, slots, exports, or diagrams: plan only, say so.
2. **Scope.** Use the current selection. If nothing is selected, ask a verbatim question with
   numbered options (through a structured question tool when the runtime has one) and stop. Never
   expand to the page or file without asking.
3. **Inputs.** Library, collection, connector, brand rules. If one is missing, say what is missing
   and ask for the source of truth. Never invent values.

## Instructions (or Workflow)

Open with the interaction contract when the skill asks questions: one question per message,
numbered options, wait, act, move on; never two questions in one message; never answer your own
question; re-ask narrowly on ambiguity. Every gate (scope, mode, fix, disclosure, checkpoint) is
asked "through a structured question tool when the runtime has one", in plain text without
Markdown, and the `target:figma-app` section names `ask_user_question` for those gates: in Round 3
(2026-11-03) the gates that named the tool rendered as cards with clickable options and the ones
that did not rendered as plain text. A follow-up that needs free text, such as row numbers, is asked
as free text with no preset options; the agent otherwise invents presets the skill never defined.

Then numbered steps. Each step is a direct instruction with numbers, names, and thresholds, not
adjectives. Build on a duplicate or a new frame placed next to the source. Include a **Verify**
step that reads the result back from the canvas in a separate step.

For script-driven skills, keep the step text tool-neutral here and put the code in the core
Helper scripts section, described below.

## Output contract

"Report only:" followed by a short list. Include counts by severity, the name and position of
anything created, anything skipped and why, and a confirmation that the source was not changed.
Cap findings (five to seven) and order by impact. Fixed shapes make runs comparable and stop the
agent padding.

## Do and do not

Named rules, each with concrete **Do** and **Do not** examples drawn from the real product or
system. This is the block that turns a generic skill into a useful one. Findings should cite rule
names. Hold real strings, numbers, and layer names, not paraphrases.

## Examples

At least one: the sample request plus the selection state, and the result in chat and on canvas.
Two or three cover the main branches (nothing selected, the happy path, an unsupported request).

## Common edge cases

Each case says what to do when the ideal path fails, and why the rule exists:

- Nothing selected or the wrong node type: say what is selected and ask; do not invent a target.
- Several candidates: list them numbered and ask; picking silently is how the wrong one spreads.
- A capability is missing (font fails to load, library not connected, connector absent): report
  exactly what failed, stop that item, never substitute.
- A feature is "coming soon" or unsupported: produce the plan, hand the step to the user.

## Helper scripts (only when the skill runs code)

A core section after Common edge cases and before the Final gate. It holds one fenced `javascript`
block per helper whose first body line is `// helper: <name>`, with the name matching
`^[a-z][a-z0-9-]*$` (lowercase, hyphenated). Each helper is self-contained and returns a plain
object; nothing persists between calls. Both target sections run the helpers by name. The build
inlines every helper in the Figma editions and moves each to `scripts/<name>.js` in the
coding-agent edition, leaving a one-line pointer. A helper fence inside a target section ships to
one runtime only, so the validator warns about it (`helper-placement`), and a `// helper:` marker
anywhere else is not extracted.

```javascript
// helper: collect
// Collect: what it reads or builds, in one line.
(async () => {
  const sel = figma.currentPage.selection;
  if (sel.length === 0) return { error: "nothing selected" };
  return { ok: true };
})();
```

## Final gate

A checklist the agent must satisfy "against the canvas, not from memory" before finishing: every
question asked alone and answered; only the agreed scope touched; every reported number read back;
output matches the contract.

## Target-marked sections (optional, build-time only)

```markdown
<!-- target:figma-app -->
## In-app execution (Figma agent)
If a script-execution tool such as `evaluate_script` is available, run the collect helper in Helper
scripts for steps 2 and 3: return values with `return`, re-fetch nodes by id in every call, load fonts
before any text edit, and measure in a later call than the one that builds. If it is not available, perform the
steps with your own canvas tools and say which path you took.
<!-- /target -->

<!-- target:mcp -->
## MCP execution (Claude Code, Cursor, Codex)
Load the `figma-use` skill before any `use_figma` call. Start with `create_session` for the file
key, read with `get_design_context` or `get_screenshot`, and write with `use_figma`. Run the collect
helper in Helper scripts through `use_figma` without its `(async () => {` and `})();` wrapper lines.
<!-- /target -->
```

Neither runtime reads the markers, and Figma keeps HTML comments as visible text, so markers must
never ship. `scripts/build-skill-editions.mjs` strips them.

## What the skeleton leaves out on purpose

- `## Purpose` or `## Operating Role` preambles: filler that restates the description.
- Long API reference: the signature of the zero-user skill.
- A second frontmatter block: reproduces a defect in Figma's own example.
- Links to sibling files: there are no files in-app.
- Mid-run invocation of other skills: only the first skill in a prompt runs.

## Size

Aim under 500 lines in every edition; about 5,000 tokens is the coding-agent guidance, while Figma
enforces no body limit and its longest first-party skill is about 12,000 tokens. That skill earns
its length with deterministic output; a long skill also costs more credits per run. Split into two
named skills rather than exceed the target without a reason.
