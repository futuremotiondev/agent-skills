---
name: fm-<process>-workflow
description: Runs the <process name: e.g. "design handoff", "component release", "weekly file hygiene"> workflow end to end: <stage 1>, <stage 2>, <stage 3>, with a checkpoint between stages and a final checklist. Use whenever the user asks to "run the <process>", "prepare this for <outcome>", "get this ready for <audience>", or "do the <process> checklist". Not for a single stage on its own (use /fm-<stage-skill>).
metadata:
  version: "1.0"
  author: "Futuremotion Studio"
  category: "<one of the six Community categories>"
  tags: "<comma-separated, lowercase>"
  applies-to: "<pattern and surface>"
  runtimes: "figma-design, figma-make, mcp"
---

# <Process name> workflow

Walks a multi-stage process in a fixed order with a checkpoint after each stage. The agent never skips a stage, never runs two stages in one turn, and never advances past a checkpoint without the user's answer. Each stage has a definition of done that is checked against the canvas, not from memory.

Run this as a series of prompts: S1 → checkpoint → S2 → checkpoint → S3 → final checklist. Every checkpoint offers numbered options and stops.

## When to use

- The user asks to run, start, or finish the <process>.
- The user asks to "get this ready for <audience or event>".
- **Do not** use this for one stage in isolation; call the stage skill directly.

## Before you start

1. **Check the surface.** Figma Design file with edit access. In Make, run the stages that apply to code and skip canvas stages, saying which were skipped.
2. **Resolve scope.** The selected page or frames. If nothing is selected, ask, verbatim:
   > Nothing's selected. **1. Run the workflow on the current page**, or **2. select the frames first**?
3. **Confirm inputs.** <Owner, target date, audience, library version, naming rules>. Ask for anything missing before S1; do not assume.

## Instructions

### S1: <Stage 1 name, e.g. "Hygiene">

1. <Action with numbers: e.g. "Rename frames to `<Page>/<Section>/<Element>`; delete empty frames; move scratch to `99 Scratch`.">
2. <Action.>
3. **Done when:** <checkable condition, e.g. "no frame named `Frame <n>` remains in scope; no hidden top-level frames">.

**Checkpoint 1.** Report what changed as counts, then ask, verbatim:
> Stage 1 done: <n> renamed, <n> moved, <n> deleted. **1. Continue to <Stage 2>**, **2. Show me the list first**, **3. Stop here**.
Wait.

### S2: <Stage 2 name, e.g. "Compliance">

1. <Action: e.g. "Run the token and component checks; snap off-scale spacing after confirmation.">
2. <Action.>
3. **Done when:** <condition>.

**Checkpoint 2.** Same shape as Checkpoint 1. Wait.

### S3: <Stage 3 name, e.g. "Package">

1. <Action: e.g. "Create the `Handoff / <date>` page; place a cover frame with title, owner, date, library version; link each flow frame in a numbered list.">
2. <Action.>
3. **Done when:** <condition>.

### Final checklist

Read each line against the canvas and mark it:

- [ ] <Stage 1 done-condition>
- [ ] <Stage 2 done-condition>
- [ ] <Stage 3 done-condition>
- [ ] Nothing outside the agreed scope was changed

Report the checklist, then stop. Do not offer to "also" do adjacent work.

## Output contract

Per checkpoint: counts of what changed, what was skipped and why, the numbered question.
At the end: the marked checklist, the names and locations of anything created, and anything the user must do by hand (prototype wiring, exports, sharing settings).

## Do and do not

### One stage per turn

- **Do:** S1, report, question, stop.
- **Do not:** "I went ahead and did stages 1 through 3."

### Counts, not adjectives

- **Do:** "Stage 2 done: 14 spacings snapped, 3 instances re-attached, 0 contrast failures."
- **Do not:** "Stage 2 done: things look much cleaner now."

### Hand over what you cannot do

- **Do:** "Prototype wiring is not available to me; the flows are listed on the cover for you to connect."
- **Do not:** "Prototype connected." when it was not.

## Examples

**Request:** "Run the handoff workflow on this page."
**Result:** Input confirmation, S1 with counts, Checkpoint 1; nothing further until answered.

**Request:** "Skip hygiene, just package it."
**Result:** Say S1 is required by this workflow and ask whether to run S1 quickly or use /fm-<stage-3-skill> alone instead.

## Common edge cases

- **A stage finds nothing to do.** Report zero counts and still stop at the checkpoint.
- **A stage fails midway** (font load, missing library). Stop that stage, report exactly what failed and what completed, and ask whether to continue to the next stage.
- **The user answers off-list.** Ask again, more narrowly, with the same numbered options.
- **Make file.** Run only the code-applicable stages; list the canvas stages as skipped.

## Final gate: do not finish until every line is true

- [ ] Every checkpoint was asked and answered before the next stage
- [ ] Every done-condition was read from the canvas
- [ ] Anything not possible for the agent was handed to the user explicitly
- [ ] Scope outside the selection is unchanged

<!-- target:figma-app -->
## In-app execution (Figma agent)

If a script-execution tool such as `evaluate_script` is available, use one call per stage for collection, one for changes, one for the done-check, each on batches of about 25 frames. Re-fetch nodes by id in every call. Never carry the done-check inside the call that made the changes.
<!-- /target -->

<!-- target:mcp -->
## MCP execution (Claude Code, Cursor, Codex)

Load the `figma-use` skill before any `use_figma` call. Use `create_session` once, then one `use_figma` call per stage action (pass `skillNames: "fm-<process>-workflow"`), reading back with `get_metadata` for the done-check. On any error: stop, inspect partial state, remove partial output, fix, retry once.
<!-- /target -->
