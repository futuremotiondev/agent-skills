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
3. **Confirm the scale.** Default rhythm: a value is on-grid when it is 0, a multiple of 4 below 48, or a multiple of 8 at 48 and above. If the user names a different scale, or the file's library guidelines document one, use that instead and state it in the report.

## Instructions

Ask one question at a time, wait for the answer, then act. Every question offers numbered options and stops.

1. **Collect.** For every visible frame in scope that has auto layout, read padding top, right, bottom, left, and gap; read the row gap only when the frame wraps. Skip hidden layers and count them. Do not measure absolute-positioned children; count them as not measurable.
2. **Fold inherited values.** An instance whose value equals its main component's value is inheriting it. Report that value once, on the main component's row, with a note "inherited by N instances"; if the main component is outside the selection, still list it once and say so. Only a value that differs from the main component gets its own row, marked as an override.
3. **Classify each value.** On-grid values pass. For an off-grid value compute the nearest on-grid value and the delta. When two on-grid values are equally near, prefer the multiple of 8; if neither or both are, prefer the lower value. Example: 18 becomes 16, 14 becomes 16, 50 becomes 48. Under a 4 pt grid the largest possible delta below 48 is 2, so severity keys on 2 versus 1.
4. **Rank.** Assign a priority from the location and the delta:
   - **P0**: delta of 2 or more on a main component or component set, or inside one.
   - **P1**: delta of 2 or more on any other frame; delta of 1 on a main component; or any override inside an instance, because the lasting fix belongs in the main component.
   - **P2**: delta of 1 on a plain frame; or any value bound to a variable (change the variable, not the layer).
   - **P3**: fractional deltas below 1, and anything on a page named Scratch, Archive, or Playground.
5. **Report** using the output contract. If the user asked a yes-or-no question, answer it in one line first ("Not entirely. I found 10 off-grid values. Nothing was changed."). List at most 30 rows, highest priority first, then largest delta. Summarise the rest by count per priority.
6. **Offer the fix.** Ask, verbatim and as plain text:
   > Apply the snaps listed above? 1. All, 2. P0 and P1 only, 3. Pick by row number, 4. None.
   Wait. Apply only the chosen rows, only on those layers, by setting the named property to the nearest on-grid value. Never touch a variable binding, a layer's structure, constraints, or layout mode, and never set a width or height. A hug-sized frame that grows or shrinks because its padding or gap changed is the expected result, not a size change; never revert a confirmed snap for that reason. For rows inside an instance, apply only if the user confirmed that creating an override is acceptable; otherwise point at the main component. If you believe a confirmed row is unsafe to apply, leave it unapplied, say why, and ask; never revert silently.
7. **Verify.** Re-read every changed property from the canvas and compare it with the target. Report mismatches as not fixed, with the value actually read.

## Output contract

Use the Figma UI names for properties: Padding top, Padding right, Padding bottom, Padding left, Gap, Row gap. Show deltas signed (−2 means the value comes down by 2). Where the surface supports it, make each layer reference a clickable node link.

```markdown
<One-line answer if the user asked a question.>

## Spacing rhythm audit: <scope name>
- Scale: 4 pt below 48, 8 pt from 48 (or the stated scale)
- Frames measured: <n> · Hidden skipped: <n> · Not measurable (absolute children): <n>
- Off-grid values: P0 <n> · P1 <n> · P2 <n> · P3 <n>
- No changes applied.

| # | Layer (path) | Property | Current | Nearest | Delta | Priority | Note |
| --- | --- | --- | --- | --- | --- | --- | --- |

## After fixes (only if applied)
- Changed: <n> properties on <n> layers · Verified: <n> of <n>
- Not changed: <rows and reasons: bound variable, override not approved, user excluded>
- Structure, constraints, layout mode, and explicit sizes: unchanged
```

Say "no off-grid values in" followed by the frame count instead of producing an empty table.

## Do and do not

### Snap, do not nudge

- **Do:** "Padding left 18 → 16 (nearest on-grid). Delta −2."
- **Do not:** "Padding left 18 → 20 (looks more balanced)."

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

## Examples

**Request:** "Check the spacing on these cards" with four card instances selected.
**Result:** A table where inherited values appear once on the main component row and only true overrides get their own row, then the verbatim fix question.

**Request:** "Is this on the 8pt grid?" with nothing selected.
**Result:** The verbatim scope question in plain text. If the user picks the page, a one-line answer, then the audit.

**Request:** "Fix all of them" after the report.
**Result:** Snaps applied only to the listed rows, each re-read, then the "After fixes" block with verified counts. Hug frames that changed height are reported, not reverted.

**Request:** "Also make these frames auto layout" during the audit.
**Result:** Say that converting frames is outside this skill and finish the audit; no frames converted.

## Common edge cases

- **Nothing selected, or no auto-layout frames in the selection.** Say what is selected and ask. Do not invent a target.
- **Values bound to variables.** Report the variable name and its resolved value at P2; never overwrite the binding. Suggest changing the variable.
- **Percentages or mixed values.** Report them in the Note column; do not snap them.
- **Instances with overrides.** Report the override; the lasting fix is the main component. Apply an override only on explicit confirmation.
- **Main component outside the selection.** List it once with the inherited count and say it is outside the selection; the fix still goes there.
- **Fractional values such as 15.5.** Treat as off-grid; nearest on-grid is 16; rank P3 and note the fraction.
- **Large scope.** Above 400 frames, stop collecting, report the first 400, and ask whether to continue in batches.
- **Figma Make.** Return the allowed-value list as a checklist and stop.

## Final gate: do not finish until every line is true

Check against the canvas, not from memory.

- [ ] Every Current value in the table was read from a layer
- [ ] Inherited instance values appear once, on the main component row
- [ ] No snap was applied before the user answered the numbered fix question
- [ ] Every confirmed snap was applied or explicitly declined with a reason; none was reverted silently
- [ ] Every applied snap was re-read and equals the Nearest value
- [ ] No variable binding, structure, constraint, layout mode, or explicit size was changed

## In-app execution (Figma agent)

If a script-execution tool such as `evaluate_script` is available, use the three helpers below in order: collect, apply, verify. Each is self-contained; nothing persists between calls, so re-fetch nodes by id every time and keep the apply list to about 25 rows per call. Return values with `return`. If no script tool is available, read the properties with your own canvas tools and apply confirmed fixes one layer at a time, reporting each.

```javascript
// Collect: read auto-layout padding and gaps in the selection, fold inherited instance values into
// their main component, and rank every off-grid value. Read-only.
(async () => {
  const onGrid = (v) => v === 0 || (v < 48 ? v % 4 === 0 : v % 8 === 0);
  const nearest = (v) => {
    if (onGrid(v)) return v;
    const step = v < 48 ? 4 : 8;
    const lo = Math.floor(v / step) * step, hi = lo + step;
    if (v - lo !== hi - v) return v - lo < hi - v ? lo : hi;
    return hi % 8 === 0 && lo % 8 !== 0 ? hi : lo;
  };
  const LABEL = { paddingTop: "Padding top", paddingRight: "Padding right", paddingBottom: "Padding bottom", paddingLeft: "Padding left", itemSpacing: "Gap", counterAxisSpacing: "Row gap" };
  const scratch = /scratch|archive|playground/i.test(figma.currentPage.name);
  const pathOf = (n) => { const parts = []; for (let p = n; p && p.type !== "PAGE"; p = p.parent) parts.unshift(p.name); return parts.join(" / "); };
  const rank = (delta, comp, inst, bound) => {
    if (scratch || delta < 1) return "P3";
    if (bound) return "P2";
    if (inst) return "P1";
    if (comp) return delta >= 2 ? "P0" : "P1";
    return delta >= 2 ? "P1" : "P2";
  };
  const rows = new Map(), inherited = new Map();
  let frames = 0, hidden = 0, absolute = 0;
  const measure = (n, comp, inst, twin) => {
    frames++;
    const props = ["paddingTop", "paddingRight", "paddingBottom", "paddingLeft", "itemSpacing"];
    if (n.layoutWrap === "WRAP") props.push("counterAxisSpacing");
    for (const k of props) {
      const v = n[k];
      if (typeof v !== "number" || onGrid(v)) continue;
      const target = nearest(v), delta = Math.abs(target - v), signed = +(target - v).toFixed(2);
      if (inst && twin && twin[k] === v) {
        // Inherited from the main component: count it there instead of repeating the row.
        const key = twin.id + "|" + k;
        inherited.set(key, (inherited.get(key) || 0) + 1);
        if (!rows.has(key)) rows.set(key, { id: twin.id, path: pathOf(twin) + " (main component, outside selection)", property: LABEL[k], current: v, nearest: target, delta: signed, priority: rank(delta, true, false, false), note: "" });
        continue;
      }
      const bound = !!(n.boundVariables && n.boundVariables[k]);
      const notes = [];
      if (bound) notes.push("bound to variable; change the variable");
      if (inst) notes.push("instance override; main component uses " + (twin ? twin[k] : "?"));
      if (v % 1) notes.push("fractional");
      rows.set(n.id + "|" + k, { id: n.id, path: pathOf(n), property: LABEL[k], current: v, nearest: target, delta: signed, priority: rank(delta, comp, inst, bound), note: notes.join("; ") });
    }
    for (const c of n.children) if (c.layoutPositioning === "ABSOLUTE") absolute++;
  };
  const walk = async (n, comp, inst, twin) => {
    if (n.visible === false) { hidden++; return; }
    const isComp = comp || n.type === "COMPONENT" || n.type === "COMPONENT_SET";
    let isInst = inst, t = twin;
    if (n.type === "INSTANCE") { isInst = true; t = n.getMainComponentAsync ? await n.getMainComponentAsync() : n.mainComponent; }
    if ("layoutMode" in n && n.layoutMode !== "NONE") measure(n, isComp, isInst, t);
    if ("children" in n) for (let i = 0; i < n.children.length; i++) await walk(n.children[i], isComp, isInst, t && t.children ? t.children[i] : null);
  };
  for (const n of figma.currentPage.selection) await walk(n, false, false, null);
  for (const [key, count] of inherited) {
    const r = rows.get(key);
    if (r) r.note = (r.note ? r.note + "; " : "") + "inherited by " + count + " instance" + (count === 1 ? "" : "s");
  }
  const order = { P0: 0, P1: 1, P2: 2, P3: 3 };
  const list = [...rows.values()].sort((a, b) => order[a.priority] - order[b.priority] || Math.abs(b.delta) - Math.abs(a.delta));
  return { framesMeasured: frames, hiddenSkipped: hidden, notMeasurable: absolute, total: list.length, rows: list.slice(0, 400) };
})();
```

```javascript
// Apply: set only the confirmed properties to their target values. Fill `fixes` from the confirmed rows;
// set `override: true` on a row only when the user approved creating an instance override.
(async () => {
  const fixes = [/* { id: "12:34", property: "paddingLeft", value: 16, override: false } */];
  const get = (id) => figma.getNodeByIdAsync ? figma.getNodeByIdAsync(id) : Promise.resolve(figma.getNodeById(id));
  const insideInstance = (n) => { for (let p = n; p && p.type !== "PAGE"; p = p.parent) if (p.type === "INSTANCE") return true; return false; };
  const applied = [], skipped = [];
  for (const f of fixes) {
    const n = await get(f.id);
    if (!n || !(f.property in n)) { skipped.push({ ...f, reason: "node or property missing" }); continue; }
    if (n.boundVariables && n.boundVariables[f.property]) { skipped.push({ ...f, reason: "bound to variable" }); continue; }
    if (insideInstance(n) && !f.override) { skipped.push({ ...f, reason: "override not approved" }); continue; }
    try { n[f.property] = f.value; applied.push(f); } catch (e) { skipped.push({ ...f, reason: String(e) }); }
  }
  return { applied: applied.length, skipped };
})();
```

```javascript
// Verify: re-read each applied property and compare with the target. Run after Apply, never inside it.
(async () => {
  const fixes = [/* the same list that was applied */];
  const get = (id) => figma.getNodeByIdAsync ? figma.getNodeByIdAsync(id) : Promise.resolve(figma.getNodeById(id));
  const results = [];
  for (const f of fixes) {
    const n = await get(f.id);
    const actual = n ? n[f.property] : null;
    results.push({ ...f, actual, ok: actual === f.value });
  }
  return { verified: results.filter((r) => r.ok).length, total: results.length, mismatches: results.filter((r) => !r.ok) };
})();
```
