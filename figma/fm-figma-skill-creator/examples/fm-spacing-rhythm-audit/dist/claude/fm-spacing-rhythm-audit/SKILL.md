---
name: fm-spacing-rhythm-audit
description: Audits the selected frames against a 4/8 pt spacing rhythm and lists every off-grid padding and gap with the exact value, the nearest on-grid value, and a severity from P0 to P3; it snaps values only after the user confirms. With spacing tokens in the file it audits against those tokens and binds values to the matching variable. Use whenever the user asks to check the spacing, audit spacing, find off-grid padding or gaps, clean up the spacing, or asks whether a layout follows the 8 pt grid or the spacing scale. Not for restructuring layouts or converting frames to auto layout; it measures and snaps auto-layout padding and gaps only.
metadata:
  version: "2.0"
  author: Futuremotion Studio
  category: "Design systems"
  tags: "spacing, audit, 8pt, padding, auto layout, tokens, variables"
  applies-to: "audit, variables, layout"
  runtimes: "figma-design, figma-make, mcp"
  target: mcp
license: MIT
compatibility: Requires the Figma MCP server (use_figma, create_session, get_metadata) and the figma-use skill.
---

# Spacing rhythm audit

Measures auto-layout padding and gaps in the selection against a 4/8 pt rhythm and returns a ranked list of every off-grid value with the exact fix. The audit itself changes nothing. Snapping happens only after the user picks what to apply, only on the listed layers, and only on the named property. Numbers come from the canvas, never from memory.

## When to use

- The user asks to check, audit, lint, or clean up spacing, padding, or gaps.
- The user asks whether the selection is on the 8 pt grid, follows the spacing scale, or has consistent rhythm.
- The user is preparing frames for handoff or a design-system review and wants spacing verified first.
- **Do not** use this to restructure layouts, add auto layout to plain frames, or change sizes. It measures and snaps padding and gaps on frames that already have auto layout. Say so and stop if the user asks for more.

## Before you start

1. **Check the surface.** In a Figma Design file, audit canvas layers. In a Figma Make file, return the scale below as a checklist of allowed spacing values for the code and stop; do not attempt layers. In FigJam or Slides, say there are no auto-layout frames to audit and stop.
2. **Resolve the scope.** Use the current selection. If nothing is selected, ask, verbatim and as plain text (the question card does not render Markdown):
   > Nothing's selected. 1. Audit the current page (slow and credit-hungry on large pages), or 2. select the frames you want audited?
   Wait for the answer. Never expand to the whole file.
3. **Confirm the scale.** Default rhythm: a value is on-grid when it is 0, a multiple of 4 below 48, or a multiple of 8 at 48 and above. A gap of exactly 2 is a half-step that many systems allow; report it at P3 unless the user says 2 is disallowed. If the user names a different scale, or the file's library guidelines document one, use that instead and state it in the report. Token mode: when spacing tokens exist, the spacing collection's Default-mode values are added to the on-grid set in rhythm mode.
4. **Token mode: discover spacing tokens.** Run the collect script in discover mode first; it reads the file's local FLOAT variables whose scopes include GAP or WIDTH_HEIGHT, or whose name contains "space" or "spacing" (case-insensitive). The default ALL_SCOPES does not satisfy the scope rule, but the name rule still applies, so unscoped `Space/*` variables count. Group by collection; the collection with the most matches is the spacing collection, and only its tokens are bind or snap candidates; matched variables in other collections still make a bound value pass but are never offered. Resolve aliases to their final value (at most three hops) and remember which variables are aliases. Record one token entry per variable per mode of its collection. If the runtime exposes team-library variable collections, report "library tokens present, not audited" once; their values cannot be read without importing them into the file, which this skill never does before confirmation.
5. **Token mode: choose the mode once.** If any spacing tokens exist, ask, verbatim and as plain text (through a structured question tool when the runtime has one), with `spacingCollection.min` and `spacingCollection.max` filled in:
   > This file has spacing tokens (4 to 16 px). Audit against 1. the system's tokens (fixes bind values to tokens), or 2. the 4/8 pt rhythm (fixes snap numbers; the token values also count as on-grid)?
   Wait for the answer, then collect again in the chosen mode. Default to 1 when the user says "just audit". If no tokens exist, use rhythm mode and do not mention modes.

## Instructions

Ask one question at a time, wait for the answer, then act. Every question offers numbered options and stops.

1. **Collect.** For every visible node in scope that has auto layout (frames, components, variants, instances, and slots all count as frames here), read padding top, right, bottom, left, and gap; read the row gap only when the frame wraps. Skip hidden layers and count them. Do not measure absolute-positioned children; count them as not measurable. Stop at 2,000 frames, say the scope was truncated, and ask whether to continue by section.
2. **Fold inherited values and merge twins.** An instance whose value equals its main component's value is inheriting it. Report that value once, on the main component's row, with a note "inherited by N instances". If the main component sits outside the selection or on another page, still list it once and say where it is. Only a value that differs from the main component gets its own row, marked as an override. Distinct frames that read identically (same component, path, property, and value, such as four nested "Block" frames) merge into one row noted "in N frames"; a fix on that row applies to all of them.
3. **Classify each value.** On-grid values pass. For an off-grid value compute the nearest on-grid value and the delta. When two on-grid values are equally near, prefer the multiple of 8; if neither or both are, prefer the lower value. Example: 18 becomes 16, 14 becomes 16, 50 becomes 48. Under a 4 pt grid the largest possible delta below 48 is 2, so severity keys on 2 versus 1.

   Token mode: (a) a bound value passes, in any collection, and is counted in `boundPassed`; tokens whose value is off the 4/8 rhythm are listed once each in the "Tokens off the 4/8 rhythm" header line with how many bound values use them. (b) 0 passes and is never a bind suggestion. (c) An unbound value equal to a spacing-collection token value (in the mode applied to the node's collection, else the Default mode) is a bind opportunity, not a defect: it is counted per token in a "Bind opportunities" table (token, count, one example layer), excluded from the priority counts and the "Off-grid values" line, and listed as an individual P3 row "unbound; bind to Space/200" only when `framesMeasured` is 50 or fewer; on larger selections the fix question's "All" covers listed rows only, and the report says "to bind these, select 50 frames or fewer and run again". (d) An unbound value with no equal token snaps to the nearest token value when that value is within 4 of it, delta measured to the token, severity by the existing depth and delta rules, fix is a binding carrying the mode name; beyond 4, if the value is on the rhythm it passes and is counted as "on rhythm, no matching token", otherwise the fix is the rhythm-nearest number with the reason "no token within 4"; ties go to the lower token. (e) When several variables share the value, never offer an alias when a non-alias variable resolves to the same value; among the rest prefer one already bound in the same top-level frame, then the shortest name, and list the alternatives in the note. (f) The 2 px half-step rule applies in rhythm mode only.
4. **Rank.** Assign a priority from the location and the delta. Inside a component, depth counts: the component itself or its direct child frames are what designers see; deeper frames are internals.
   - **P0**: delta of 2 or more on a main component, a component set, or a direct child frame of one.
   - **P1**: delta of 2 or more deeper inside a component, or on any plain frame; delta of 1 anywhere inside a component; or any override inside an instance, because the lasting fix belongs in the main component.
   - **P2**: delta of 1 on a plain frame; or any value bound to a variable, on the layer itself or on the main component it inherits from (change the variable, not the layer). Name the token. When bound values reveal a token outside the rhythm, such as a 6 pt step, say so in the report: that is a scale decision for the system owner, not a defect to snap.
   - **P3**: fractional deltas below 1, gaps of exactly 2, and anything on a page named Scratch, Archive, or Playground.
5. **Report** using the output contract. If the user asked a yes-or-no question, answer it in one line first ("Not entirely. I found 10 off-grid values. Nothing was changed."). Rows are sorted by priority, then by largest delta. When there are more than 30 rows, show the group summary first (one line per component or top-level frame with its row counts by priority), then the top 30 rows, then the remaining count per priority.
6. **Offer the fix.** Ask, verbatim and as plain text:
   > Apply the snaps listed above? 1. All, 2. P0 and P1 only, 3. Pick by row number, 4. None.
   Wait. If any chosen row is a main component outside the selection or on another page, say so in one line before applying ("Rows 3 to 5 change main components on Inputs and AI Chat, so every instance in the file updates"), then apply. Apply only the chosen rows, only on those layers, by setting the named property to the nearest on-grid value. Never change or remove an existing binding, a layer's structure, constraints, or layout mode, and never set a width or height. Token mode: a binding is added only on confirmed unbound rows; the fix binds the property to the named variable; when the fix is `set`, set the number and state the reason. A hug-sized frame that grows or shrinks because its padding or gap changed is the expected result, not a size change; never revert a confirmed snap for that reason. For rows inside an instance, apply only if the user confirmed that creating an override is acceptable; otherwise point at the main component. If you believe a confirmed row is unsafe to apply, leave it unapplied, say why, and ask; never revert silently.
7. **Verify.** Re-read every changed property from the canvas and compare it with the target. Report mismatches as not fixed, with the value actually read.

## Output contract

Use the Figma UI names for properties: Padding top, Padding right, Padding bottom, Padding left, Gap, Row gap. Show deltas signed (−2 means the value comes down by 2). Put Priority second so it stays visible in a narrow panel. Where the surface supports it, make each layer reference a clickable node link. Token mode adds these lines: Mode (printed in both modes whenever the file has spacing tokens), Bound values (in place of Bound to variables, which rhythm mode keeps), Tokens off the 4/8 rhythm (omitted when none), Bind opportunities, and On rhythm, no matching token; the Bind opportunities table before the main table; and the main table's Fix column after Nearest, reading "bind Space/200" or "set 8".

```markdown
<One-line answer if the user asked a question.>

## Spacing rhythm audit: <scope name>
- Mode: tokens (<spacingCollection.name>) | rhythm
- Scale: 4 pt below 48, 8 pt from 48 (or the stated scale)
- Frames measured: <n> · Hidden skipped: <n> · Not measurable (absolute children): <n>
- Off-grid values: P0 <n> · P1 <n> · P2 <n> · P3 <n> (<n> values in <n> rows)
- Bound to variables: <n> values using <token names>; left to a variable-level decision
- Bound values: <n> passed
- Tokens off the 4/8 rhythm: Space/150 = 6 (12 values); a scale decision, not a defect
- Bind opportunities: <n> values across <n> tokens (table below when any)
- On rhythm, no matching token: <n>
- No changes applied.

## Bind opportunities (token mode, when any)
| Token (mode) | Values | Example layer |
| --- | --- | --- |

## By component (only when more than 30 rows)
| Component or frame | Rows | P0 | P1 | P2 | P3 |
| --- | --- | --- | --- | --- | --- |

| # | Priority | Layer (path) | Property | Current | Nearest | Fix | Delta | Note |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |

## After fixes (only if applied)
- Changed: <n> properties on <n> layers · Verified: <n> of <n>
- Not changed: <rows and reasons: existing binding, override not approved, user excluded>
- Structure, constraints, layout mode, and explicit sizes: unchanged
```

Say "no off-grid values in" followed by the frame count instead of producing an empty table.

## Do and do not

### Snap, do not nudge

- **Do:** "Padding left 18 → 16 (nearest on-grid). Delta −2."
- **Do not:** "Padding left 18 → 20 (looks more balanced)."

### Token mode: bind, do not hard-code

- **Do:** "Padding left 10 → bind Space/300 (Compact)."
- **Do not:** "Padding left 10 → set 8."

### Report, then wait

- **Do:** The ranked table, the verbatim fix question, then nothing until the answer arrives.
- **Do not:** Applying the "obvious" P0 snaps in the same turn as the audit.

### Numbers, not adjectives

- **Do:** "Gap 13 between 'Price' and 'Buy' in Card / Default."
- **Do not:** "The cards feel a little uneven."

### Fix at the source

- **Do:** "Card: Gap 13 → 12, inherited by 3 instances. Card / Compact: Gap 15 is an override; fix needs your approval."
- **Do not:** Nine identical rows, one per instance, for a value that lives in the main component.

### Apply what was confirmed

- **Do:** "Hero: Gap 14 → 16 applied; the frame grew from 96 to 98 px because it hugs its content."
- **Do not:** "Hero remains at 14. Snapping increased its height, so I reverted it."

### Summarise before you list

- **Do:** "AI Sidebar: 8 values (Padding left and right 6 → 8 in four nested Block frames). Checkbox: 1 value, inherited by 9."
- **Do not:** Thirty rows of "Block / Block / Block" with the rest of the page cut off.

## Examples

**Request:** "Check the spacing on these cards" with four card instances selected.
**Result:** A table where inherited values appear once on the main component row and only true overrides get their own row, then the verbatim fix question.

**Request:** "Is this on the 8pt grid?" with nothing selected.
**Result:** The verbatim scope question in plain text. If the user picks the page, a one-line answer, then the audit.

**Request:** "Audit spacing" with a design-system section of 300 frames selected.
**Result:** The header counts, a "By component" summary, the top 30 rows, the remaining counts, then the fix question.

**Request:** "Fix all of them" after the report.
**Result:** Snaps applied only to the listed rows, each re-read, then the "After fixes" block with verified counts. Hug frames that changed height are reported, not reverted.

**Request:** "Also make these frames auto layout" during the audit.
**Result:** Say that converting frames is outside this skill and finish the audit; no frames converted.

## Common edge cases

- **Nothing selected, or no auto-layout frames in the selection.** Say what is selected and ask. Do not invent a target.
- **In rhythm mode, values bound to variables.** Report the variable name and its resolved value at P2; never overwrite an existing binding. Suggest changing the variable.
- **Token mode: a bound value passes and is counted on the Bound values line.**
- **Token mode: alias tokens.** An alias resolves to its final value (at most three hops) for matching but is never offered; bind to the non-alias variable with that value, or snap to the nearest non-alias token.
- **Token mode: multi-mode collections.** Match against the token values of the mode applied to the node's collection, else the Default mode, and name that mode in the fix: "bind Space/300 (Compact)".
- **Token mode: library tokens present but not audited.** Say "library tokens present, not audited" once, on the Mode line; never import a library variable to read its value.
- **Token mode: a value far from every token.** More than 4 from every token, a value on the rhythm passes as "on rhythm, no matching token"; otherwise the fix is the rhythm-nearest number with the reason "no token within 4".
- **Percentages or mixed values.** Report them in the Note column; do not snap them.
- **Instances with overrides.** Report the override; the lasting fix is the main component. Apply an override only on explicit confirmation.
- **Main component outside the selection or on another page.** List it once with the inherited count and name the page; the fix still goes there.
- **Gap of 2.** Half-step; P3 with a note, unless the user disallows 2.
- **Fractional values such as 15.5.** Treat as off-grid; nearest on-grid is 16; rank P3 and note the fraction.
- **Large scope.** Above 2,000 frames, stop collecting, report what was measured, and ask whether to continue by section.
- **Figma Make.** Return the allowed-value list as a checklist and stop.

## Helper scripts

The scripts below run through whichever script path the runtime offers; each is self-contained and returns a plain object.

Run `scripts/collect.js` (in this folder) through your script path.

Run `scripts/apply.js` (in this folder) through your script path.

Run `scripts/verify.js` (in this folder) through your script path.

## Final gate: do not finish until every line is true

Check against the canvas, not from memory.

- [ ] Every Current value in the table was read from a layer
- [ ] Inherited instance values appear once, on the main component row
- [ ] More than 30 rows means a "By component" summary came first
- [ ] No snap was applied before the user answered the numbered fix question
- [ ] Every confirmed snap was applied or explicitly declined with a reason; none was reverted silently
- [ ] Every applied snap was re-read and equals the Nearest value
- [ ] No existing binding was changed or removed, and no structure, constraint, layout mode, or explicit size was changed
- [ ] Token mode: every bind fix names a non-alias spacing-collection variable within 4 of the value, and every bound value passed

## MCP execution (Claude Code, Cursor, Codex)

Load the `figma-use` skill before any `use_figma` call. Start with `create_session` for the file key. Run the collect, apply, and verify scripts in Helper scripts through `use_figma` (pass `skillNames: "fm-spacing-rhythm-audit"`): collect first, then present the table; after the user answers the fix question, apply in a second `use_figma` call with the confirmed rows, then verify in a third. Token mode: run collect in discover mode first, then with the chosen mode. `use_figma` runs top-level `await` and takes the result from `return`, so send each script without its wrapper (drop the `(async () => {` line and the closing `})();` line, or send the body as-is if a script has none), and set the `let MODE` line of the collect script before each run. On any `use_figma` error, stop, read the partial state with `get_metadata`, and report before retrying once.
