---
name: fm-<verb>-<object>
description: <Third-person capability naming the output, e.g. "Audits the selected frames against a 4/8 pt spacing rhythm and lists every off-grid padding or gap with the exact fix.">. Use whenever the user asks to "<phrase 1>", "<phrase 2>" or "<phrase 3>", or selects <object> and asks to <verb> it. Not for <nearest wrong task> (use /<other-skill>).
metadata:
  version: "1.0"
  author: "Futuremotion Studio"
  category: "<one of the six Community categories>"
  tags: "<comma-separated, lowercase>"
  applies-to: "<pattern and surface>"
  runtimes: "figma-design, figma-make, mcp"
---

# <Title in plain words>

<One paragraph: what this produces, where it lands (chat, a new frame next to the selection, variables, a comment), and the two or three principles that matter more than the template.>

## When to use

- The user asks to <trigger written as a requirement>.
- The user selects <object> and wants <outcome>.
- The user asks "<quoted phrase>".
- **Do not** use this to <adjacent task>; this skill <reads / builds / changes> only <scope>. For <adjacent task> use /<other-skill>.

## Before you start

1. **Check the surface.** In a Figma Design file, work on canvas layers. In a Figma Make file, <edit project code / return a spec> instead. If the request needs prototyping, vector editing, slots, asset export, or diagrams, produce a plan only and say so; those are not available to the agent today.
2. **Resolve the scope.** Use the current selection. If nothing is selected, ask, verbatim (through a structured question tool when the runtime has one; plain text otherwise):
   > Nothing's selected. 1. <Option, e.g. Audit the current page>, or 2. select the layers you want first?
   Wait for the answer. Do not expand to the whole page or file without asking.
3. **Confirm inputs.** <Library, variable collection, connector, brand rules the skill needs>. If one is missing, say exactly what is missing and ask for the source of truth. Do not invent values.

## Instructions

Run this as a series of prompts when a question is needed: ask one question, wait for the answer, act, then move on. Every question offers numbered options and stops, through a structured question tool when the runtime has one, in plain text otherwise. A follow-up that needs free text, such as row numbers, is asked as free text with no preset options. Never ask two questions in one message, never answer your own question, and never guess at an ambiguous reply; ask again, more narrowly.

1. **<Step name>.** <Direct instruction with numbers, names, and thresholds, not adjectives. Example: "Snap each value to the nearest of 0, 4, 8, 12, 16, 24, 32, 40, 48, 64.">
2. **<Step name>.** <Instruction.> Work on a duplicate or a new frame placed <80 px to the right of> the source. Never move, edit, or delete the source.
3. **<Step name>.** <Instruction.>
4. **Verify.** Read the result back from the canvas in a separate step, not from memory: <what to re-read and compare>.

## Output contract

Report only:

- <Item 1, e.g. number of findings by severity P0 to P3>
- <Item 2, e.g. name and position of the new frame, or "no canvas changes">
- Anything skipped, and why
- Confirmation that the source layers were not changed

Cap the output at <N> findings, ordered by impact. Say "no supported findings" rather than padding.

## Do and do not

### <Named rule 1, e.g. "Snap, do not nudge">

- **Do:** <Concrete example of the right output, with real values or strings>
- **Do not:** <Concrete example of the wrong output>

### <Named rule 2>

- **Do:** <example>
- **Do not:** <example>

## Examples

**Request:** "<sample prompt>" with <selection state>.
**Result:** <what appears in chat, and what appears on canvas, with names and positions>.

**Request:** "<second sample>" with nothing selected.
**Result:** The verbatim scope question, then the run once answered.

## Common edge cases

- **Nothing selected, or the wrong node type.** Say what is selected and ask. Do not invent a target.
- **Several candidates.** List them numbered and ask which one. Picking silently is how the wrong one ends up everywhere.
- **A capability is missing** (font fails to load, library not connected, connector absent). Report exactly what failed and stop that item. Never substitute.
- **The request needs a feature the agent does not have** (prototyping, vectors, slots, export, diagrams). Produce the plan and hand that step to the user.
- **The surface is Figma Make, FigJam, or Slides.** <Branch or plan-only behaviour.>

## Helper scripts

<Keep this section only when the skill runs code; delete it otherwise.> One fenced `javascript` block per helper, with `// helper: <name>` as its first line (lowercase and hyphenated, such as `collect` or `apply-fixes`). Each helper is self-contained and returns a plain object; nothing persists between calls. Both target sections below run the helpers by name; the build inlines them in the Figma editions and moves each to `scripts/<name>.js` in the coding-agent edition.

```javascript
// helper: collect
// Collect: <one line on what it reads or builds>. Self-contained; nothing persists between calls.
(async () => {
  const sel = figma.currentPage.selection;
  if (sel.length === 0) return { error: "nothing selected" };
  // ...
  return { ok: true };
})();
```

## Final gate: do not finish until every line is true

Check against the canvas, not from memory.

- [ ] Every question was asked on its own and answered
- [ ] Only the agreed scope was touched; the source is unchanged
- [ ] Every number in the report was read back, not assumed
- [ ] The output matches the contract above

<!-- target:figma-app -->
## In-app execution (Figma agent)

If a structured question tool such as `ask_user_question` is available, ask every numbered question through it with the same options; the plain-text wording is the fallback and the record of what was asked. If a script-execution tool such as `evaluate_script` is available, run the collect helper in Helper scripts for steps <2 and 3>. Return values with `return`, re-fetch nodes by id in every call, load fonts before any text edit, keep each call to a small batch, and measure in a later call than the one that builds. If it is not available, perform the steps with your own canvas tools and say which path you took.
<!-- /target -->

<!-- target:mcp -->
## MCP execution (Claude Code, Cursor, Codex)

Load the `figma-use` skill before any `use_figma` call. Start with `create_session` for the file key, read with `get_design_context` or `get_screenshot`, and write with `use_figma`, passing `skillNames: "fm-<verb>-<object>"`. Run the collect helper in Helper scripts through `use_figma` without its wrapper: drop the `(async () => {` line and the closing `})();` line. On any `use_figma` error: stop, inspect partial state with `get_metadata`, remove partial output, fix the root cause, then retry once.
<!-- /target -->
