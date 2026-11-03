---
name: fm-make-<artifact>
description: Builds <the artifact: e.g. "a type-scale specimen frame", "a presentation frame with a generated background", "an anatomy diagram"> from the selection as a new frame placed next to the source, asking one question at a time for the choices that change the result. Use whenever the user asks to "make a <artifact>", "build a <artifact>", "generate a <artifact>", or selects <the input> and asks for <artifact>. Not for editing the selected layers themselves (use /fm-<edit-skill>).
metadata:
  version: "1.0"
  author: "Futuremotion Studio"
  category: "<one of the six Community categories>"
  tags: "<comma-separated, lowercase>"
  applies-to: "<pattern and surface>"
  runtimes: "figma-design, figma-make, mcp"
---

# Make a <artifact>

Builds a new artifact next to the selection. The source is never moved, edited, or deleted; it is read, and where needed cloned. The build is deterministic: every dimension is computed from inputs the user confirmed, and the result is read back before the skill reports.

Run this as a series of prompts: P1 → P2 → A1 → P3 → A2 → A3. Ask one question, wait for the answer, act, then move on. Every prompt offers numbered options and stops. Do not batch questions, do not answer your own question, and do not guess when a reply is ambiguous; ask again, more narrowly.

## When to use

- The user asks to make, build, or generate <artifact>.
- The user selects <the input> and wants <artifact> derived from it.
- **Do not** restyle existing layers; this skill produces a new frame and changes nothing already on the canvas.

## Before you start

1. **Check the surface.** Figma Design: build on canvas. Figma Make: return the artifact spec as structured text instead of layers.
2. **Resolve the input (P1).**

   | Selection | Do this |
   | --- | --- |
   | Nothing selected | Ask: "Select the <the input> to build from." **Stop.** |
   | No <the input type> in the selection | Say what is selected instead; ask for <the input type>. **Stop.** |
   | Exactly one <the input> | Use it |
   | Several | **Do not pick for them.** List each by name and size, numbered, and ask which one. **Stop.** |

3. **Confirm inputs.** Fonts and library components the build needs. If a font fails to load, report the family and style that failed; never substitute.

## Instructions

### P2: Choose <the first option set>

Ask, verbatim, with numbered options:
> Which <option>? **1. <A>** · **2. <B>** · **3. <C>**
Wait.

### A1: Compute

From the input and the answers, compute every dimension: <e.g. padding = 18 percent of the longer side; frame = 16:9 containing the input plus padding; position = 80 px right of the source>. Write the numbers down in chat before building.

### P3: Confirm placement

> Build it as a new frame **1. to the right of the source** or **2. on a new page named "<artifact>"**?
Wait.

### A2: Build

1. Create the container frame with the computed size; name it `<artifact> / <source name>`.
2. Clone the source into it when the artifact composites the source; never reparent the original.
3. Add the parts in order: <part 1>, <part 2>, <part 3>. Use auto layout for stacks and rows; use the library's components and variables when connected.
4. Load every font before creating or editing text; size text nodes by width first, then enable height auto-resize, then set characters.

### A3: Verify and report

Read the finished frame back: size, position, child count, fonts resolved, bindings applied. Compare to the computed numbers. Fix any mismatch, then report.

## Output contract

Report only:

- Name and position of the new frame
- The confirmed choices (P2, P3)
- Fonts or components that failed to load, if any
- Confirmation that the source was not moved, edited, or deleted

## Do and do not

### Compute, then build

- **Do:** "Frame 1,440 × 810 at (2,340, 120); padding 194; clone centred at (623, 97)."
- **Do not:** Eyeballing sizes or placing "roughly to the right".

### Never substitute

- **Do:** "Font 'Söhne Buch' failed to load; the specimen is unbuilt until it is available."
- **Do not:** Building the specimen in Inter and mentioning it later.

## Examples

**Request:** "Make a <artifact> from this" with one frame selected.
**Result:** P2 question, computed numbers, P3 question, the build, the read-back, the report.

**Request:** Same, with three frames selected.
**Result:** A numbered list of the three and the question "Which one?"; nothing built until answered.

## Common edge cases

- **Source is an instance or a component.** Clone the instance; never detach or edit the main component.
- **Library not connected.** Build with local styles and say which library components were skipped.
- **Image generation unavailable.** Build the frame with a solid or gradient fill and say the background is a placeholder.
- **Make file.** Return the spec (sizes, order, text) as a table; do not attempt canvas layers.

## Final gate: do not finish until every line is true

Check against the canvas, not from memory.

- [ ] Every prompt was asked alone and answered before its action
- [ ] The frame's size and position match the computed numbers
- [ ] Every font loaded; nothing was substituted
- [ ] The source is unchanged

<!-- target:figma-app -->
## In-app execution (Figma agent)

If a script-execution tool such as `evaluate_script` is available, build with it: one call to read the source and compute, one call to build, one call to verify. Use `figma.createAutoLayout()` for stacks; load fonts with `figma.loadFontAsync` in every call that touches text; re-fetch the source by id in every call; measure in the verify call, not the build call. Keep each call under about 150 lines and return plain objects. If a background image is needed, use Figma's AI image creation capability for the prompt below and apply it as a fill. If no script tool is available, build with your own canvas tools and say which path you took.
<!-- /target -->

<!-- target:mcp -->
## MCP execution (Claude Code, Cursor, Codex)

Load the `figma-use` skill before any `use_figma` call. Use `create_session`, read the source with `get_design_context`, build with `use_figma` (pass `skillNames: "fm-make-<artifact>"`), verify with `get_screenshot` and a read-back script. For generated backgrounds use `generate_image` and `upload_assets`.
<!-- /target -->
