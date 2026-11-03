---
name: fm-spacing-rhythm-audit
description: Audits the selected frames against a 4/8 pt spacing rhythm and lists every off-grid padding and gap with the exact value, the nearest on-grid value, and a severity from P0 to P3; it snaps values only after the user confirms. Use whenever the user asks to check the spacing, audit spacing, find off-grid padding or gaps, clean up the spacing, or asks whether a layout follows the 8 pt grid or the spacing scale. Not for restructuring layouts or converting frames to auto layout; it measures and snaps auto-layout padding and gaps only.
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
3. **Confirm the scale.** Default rhythm: a value is on-grid when it is 0, a multiple of 4 below 48, or a multiple of 8 at 48 and above. A gap of exactly 2 is a half-step that many systems allow; report it at P3 unless the user says 2 is disallowed. If the user names a different scale, or the file's library guidelines document one, use that instead and state it in the report.

## Instructions

Ask one question at a time, wait for the answer, then act. Every question offers numbered options and stops.

1. **Collect.** For every visible node in scope that has auto layout (frames, components, variants, instances, and slots all count as frames here), read padding top, right, bottom, left, and gap; read the row gap only when the frame wraps. Skip hidden layers and count them. Do not measure absolute-positioned children; count them as not measurable. Stop at 2,000 frames, say the scope was truncated, and ask whether to continue by section.
2. **Fold inherited values and merge twins.** An instance whose value equals its main component's value is inheriting it. Report that value once, on the main component's row, with a note "inherited by N instances". If the main component sits outside the selection or on another page, still list it once and say where it is. Only a value that differs from the main component gets its own row, marked as an override. Distinct frames that read identically (same component, path, property, and value, such as four nested "Block" frames) merge into one row noted "in N frames"; a fix on that row applies to all of them.
3. **Classify each value.** On-grid values pass. For an off-grid value compute the nearest on-grid value and the delta. When two on-grid values are equally near, prefer the multiple of 8; if neither or both are, prefer the lower value. Example: 18 becomes 16, 14 becomes 16, 50 becomes 48. Under a 4 pt grid the largest possible delta below 48 is 2, so severity keys on 2 versus 1.
4. **Rank.** Assign a priority from the location and the delta. Inside a component, depth counts: the component itself or its direct child frames are what designers see; deeper frames are internals.
   - **P0**: delta of 2 or more on a main component, a component set, or a direct child frame of one.
   - **P1**: delta of 2 or more deeper inside a component, or on any plain frame; delta of 1 anywhere inside a component; or any override inside an instance, because the lasting fix belongs in the main component.
   - **P2**: delta of 1 on a plain frame; or any value bound to a variable, on the layer itself or on the main component it inherits from (change the variable, not the layer). Name the token. When bound values reveal a token outside the rhythm, such as a 6 pt step, say so in the report: that is a scale decision for the system owner, not a defect to snap.
   - **P3**: fractional deltas below 1, gaps of exactly 2, and anything on a page named Scratch, Archive, or Playground.
5. **Report** using the output contract. If the user asked a yes-or-no question, answer it in one line first ("Not entirely. I found 10 off-grid values. Nothing was changed."). Rows are sorted by priority, then by largest delta. When there are more than 30 rows, show the group summary first (one line per component or top-level frame with its row counts by priority), then the top 30 rows, then the remaining count per priority.
6. **Offer the fix.** Ask, verbatim and as plain text:
   > Apply the snaps listed above? 1. All, 2. P0 and P1 only, 3. Pick by row number, 4. None.
   Wait. If any chosen row is a main component outside the selection or on another page, say so in one line before applying ("Rows 3 to 5 change main components on Inputs and AI Chat, so every instance in the file updates"), then apply. Apply only the chosen rows, only on those layers, by setting the named property to the nearest on-grid value. Never touch a variable binding, a layer's structure, constraints, or layout mode, and never set a width or height. A hug-sized frame that grows or shrinks because its padding or gap changed is the expected result, not a size change; never revert a confirmed snap for that reason. For rows inside an instance, apply only if the user confirmed that creating an override is acceptable; otherwise point at the main component. If you believe a confirmed row is unsafe to apply, leave it unapplied, say why, and ask; never revert silently.
7. **Verify.** Re-read every changed property from the canvas and compare it with the target. Report mismatches as not fixed, with the value actually read.

## Output contract

Use the Figma UI names for properties: Padding top, Padding right, Padding bottom, Padding left, Gap, Row gap. Show deltas signed (−2 means the value comes down by 2). Put Priority second so it stays visible in a narrow panel. Where the surface supports it, make each layer reference a clickable node link.

```markdown
<One-line answer if the user asked a question.>

## Spacing rhythm audit: <scope name>
- Scale: 4 pt below 48, 8 pt from 48 (or the stated scale)
- Frames measured: <n> · Hidden skipped: <n> · Not measurable (absolute children): <n>
- Off-grid values: P0 <n> · P1 <n> · P2 <n> · P3 <n> (<n> values in <n> rows)
- Bound to variables: <n> values using <token names>; left to a variable-level decision
- No changes applied.

## By component (only when more than 30 rows)
| Component or frame | Rows | P0 | P1 | P2 | P3 |
| --- | --- | --- | --- | --- | --- |

| # | Priority | Layer (path) | Property | Current | Nearest | Delta | Note |
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
- **Values bound to variables.** Report the variable name and its resolved value at P2; never overwrite the binding. Suggest changing the variable.
- **Percentages or mixed values.** Report them in the Note column; do not snap them.
- **Instances with overrides.** Report the override; the lasting fix is the main component. Apply an override only on explicit confirmation.
- **Main component outside the selection or on another page.** List it once with the inherited count and name the page; the fix still goes there.
- **Gap of 2.** Half-step; P3 with a note, unless the user disallows 2.
- **Fractional values such as 15.5.** Treat as off-grid; nearest on-grid is 16; rank P3 and note the fraction.
- **Large scope.** Above 2,000 frames, stop collecting, report what was measured, and ask whether to continue by section.
- **Figma Make.** Return the allowed-value list as a checklist and stop.

## Final gate: do not finish until every line is true

Check against the canvas, not from memory.

- [ ] Every Current value in the table was read from a layer
- [ ] Inherited instance values appear once, on the main component row
- [ ] More than 30 rows means a "By component" summary came first
- [ ] No snap was applied before the user answered the numbered fix question
- [ ] Every confirmed snap was applied or explicitly declined with a reason; none was reverted silently
- [ ] Every applied snap was re-read and equals the Nearest value
- [ ] No variable binding, structure, constraint, layout mode, or explicit size was changed

## In-app execution (Figma agent)

If a script-execution tool such as `evaluate_script` is available, use the three helpers below in order: collect, apply, verify. Each is self-contained; nothing persists between calls, so re-fetch nodes by id every time and keep the apply list to about 25 rows per call. Return values with `return`. If no script tool is available, read the properties with your own canvas tools and apply confirmed fixes one layer at a time, reporting each.

```javascript
// Collect: read auto-layout padding and gaps in the selection, fold inherited instance values into
// their main component, rank every off-grid value, and group rows by component. Read-only.
(async () => {
  const MAX_FRAMES = 2000, MAX_ROWS = 60;
  const onGrid = (v) => v === 0 || (v < 48 ? v % 4 === 0 : v % 8 === 0);
  const nearest = (v) => {
    if (onGrid(v)) return v;
    const step = v < 48 ? 4 : 8;
    const lo = Math.floor(v / step) * step, hi = lo + step;
    if (v - lo !== hi - v) return v - lo < hi - v ? lo : hi;
    return hi % 8 === 0 && lo % 8 !== 0 ? hi : lo;
  };
  const LABEL = { paddingTop: "Padding top", paddingRight: "Padding right", paddingBottom: "Padding bottom", paddingLeft: "Padding left", itemSpacing: "Gap", counterAxisSpacing: "Row gap" };
  const page = figma.currentPage;
  const scratch = /scratch|archive|playground/i.test(page.name);
  const pageOf = (n) => { let p = n; while (p && p.type !== "PAGE") p = p.parent; return p; };
  // Path: skip unnamed ancestors, keep the last four segments, name the page when it differs.
  const pathOf = (n) => {
    const parts = [];
    for (let p = n; p && p.type !== "PAGE"; p = p.parent) if (p.name && p.name.trim()) parts.unshift(p.name.trim());
    const short = parts.length > 4 ? "… / " + parts.slice(-4).join(" / ") : parts.join(" / ");
    const pg = pageOf(n);
    return pg && pg !== page ? short + " (page: " + pg.name + ")" : short;
  };
  // Component context: outermost component ancestor (for grouping) and depth below the nearest one.
  const compInfo = (n) => {
    let root = null, depth = null, d = 0;
    for (let p = n; p && p.type !== "PAGE"; p = p.parent, d++) {
      if (p.type === "COMPONENT" || p.type === "COMPONENT_SET") { root = p; if (depth === null) depth = d; }
    }
    return { root, depth };
  };
  const topOf = (n) => { let p = n, t = n; while (p && p.type !== "PAGE") { t = p; p = p.parent; } return t; };
  const rank = (delta, info, inst, bound, half) => {
    if (scratch || half || delta < 1) return "P3";
    if (bound) return "P2";
    if (inst) return "P1";
    if (info.root) return delta >= 2 && info.depth <= 1 ? "P0" : "P1";
    return delta >= 2 ? "P1" : "P2";
  };
  const rows = new Map(), inherited = new Map();
  let frames = 0, hidden = 0, absolute = 0, truncated = false;
  const measure = (n, inst, twin) => {
    frames++;
    const props = ["paddingTop", "paddingRight", "paddingBottom", "paddingLeft", "itemSpacing"];
    if (n.layoutWrap === "WRAP") props.push("counterAxisSpacing");
    for (const k of props) {
      const v = n[k];
      if (typeof v !== "number" || onGrid(v)) continue;
      const target = nearest(v), delta = Math.abs(target - v), signed = +(target - v).toFixed(2);
      const half = v === 2 && (k === "itemSpacing" || k === "counterAxisSpacing");
      if (inst && twin && twin[k] === v) {
        // Inherited from the main component: count it there instead of repeating the row.
        const key = twin.id + "|" + k;
        inherited.set(key, (inherited.get(key) || 0) + 1);
        if (!rows.has(key)) {
          const ti = compInfo(twin);
          const where = pageOf(twin) === page ? " (main component, outside selection)" : " (main component)";
          // The binding that matters is the main component's: an inherited value is bound there.
          const tb = twin.boundVariables && twin.boundVariables[k] ? twin.boundVariables[k].id : null;
          rows.set(key, { id: twin.id, path: pathOf(twin) + where, group: ti.root ? ti.root.name : topOf(twin).name, property: LABEL[k], current: v, nearest: target, delta: signed, priority: rank(delta, ti, false, !!tb, half), boundId: tb, note: half ? "2 px half-step" : "" });
        }
        continue;
      }
      const info = compInfo(n);
      const boundId = n.boundVariables && n.boundVariables[k] ? n.boundVariables[k].id : null;
      const notes = [];
      if (inst) notes.push("instance override; main component uses " + (twin ? twin[k] : "?"));
      if (half) notes.push("2 px half-step");
      if (v % 1) notes.push("fractional");
      rows.set(n.id + "|" + k, { id: n.id, path: pathOf(n), group: info.root ? info.root.name : topOf(n).name, property: LABEL[k], current: v, nearest: target, delta: signed, priority: rank(delta, info, inst, !!boundId, half), boundId, note: notes.join("; ") });
    }
    for (const c of n.children) if (c.layoutPositioning === "ABSOLUTE") absolute++;
  };
  const walk = async (n, inst, twin) => {
    if (truncated) return;
    if (n.visible === false) { hidden++; return; }
    let isInst = inst, t = twin;
    if (n.type === "INSTANCE") { isInst = true; t = n.getMainComponentAsync ? await n.getMainComponentAsync() : n.mainComponent; }
    if ("layoutMode" in n && n.layoutMode !== "NONE") {
      if (frames >= MAX_FRAMES) { truncated = true; return; }
      measure(n, isInst, t);
    }
    if ("children" in n) for (let i = 0; i < n.children.length; i++) await walk(n.children[i], isInst, t && t.children ? t.children[i] : null);
  };
  for (const n of page.selection) await walk(n, false, null);
  for (const [key, count] of inherited) {
    const r = rows.get(key);
    if (r) r.note = (r.note ? r.note + "; " : "") + "inherited by " + count + " instance" + (count === 1 ? "" : "s");
  }
  // Resolve variable names once so bound rows can name the token.
  const varNames = new Map();
  for (const r of rows.values()) {
    if (!r.boundId) continue;
    if (!varNames.has(r.boundId)) { const v = await figma.variables.getVariableByIdAsync(r.boundId); varNames.set(r.boundId, v ? v.name : r.boundId); }
    r.note = "bound to " + varNames.get(r.boundId) + "; change the variable" + (r.note ? "; " + r.note : "");
  }
  // Merge rows that read identically (same group, path, property, value): distinct nested frames with
  // the same names become one row with every id, so the table stays short and the fix still hits all.
  const merged = new Map();
  for (const r of rows.values()) {
    const key = [r.group, r.path, r.property, r.current].join("|");
    const m = merged.get(key);
    if (m) { m.ids.push(r.id); m.count++; } else merged.set(key, { ...r, ids: [r.id], count: 1 });
  }
  const order = { P0: 0, P1: 1, P2: 2, P3: 3 };
  const list = [...merged.values()].sort((a, b) => order[a.priority] - order[b.priority] || Math.abs(b.delta) - Math.abs(a.delta));
  const byPriority = { P0: 0, P1: 0, P2: 0, P3: 0 };
  const groups = new Map();
  for (const r of list) {
    if (r.count > 1) r.note = (r.note ? r.note + "; " : "") + "in " + r.count + " frames";
    byPriority[r.priority] += r.count;
    const g = groups.get(r.group) || { group: r.group, rows: 0, P0: 0, P1: 0, P2: 0, P3: 0 };
    g.rows += r.count; g[r.priority] += r.count; groups.set(r.group, g);
  }
  const byGroup = [...groups.values()].sort((a, b) => b.rows - a.rows).slice(0, 15);
  const boundValues = list.filter((r) => r.boundId).reduce((s, r) => s + r.count, 0);
  return { framesMeasured: frames, hiddenSkipped: hidden, notMeasurable: absolute, truncated, values: rows.size, tableRows: list.length, byPriority, byGroup, boundValues, boundTokens: [...new Set(varNames.values())], rows: list.slice(0, MAX_ROWS) };
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
