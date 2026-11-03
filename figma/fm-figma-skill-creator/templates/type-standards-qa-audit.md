---
name: fm-<standard>-audit
description: Audits the selected frames against <the standard: e.g. "the 4/8 pt spacing rhythm", "AA contrast and 44 px targets", "layer naming conventions"> and lists every violation with the exact value and the exact fix, ranked by severity, fixing only after confirmation. Use whenever the user asks to "check <standard>", "audit <standard>", "find <violations>", or asks whether the selection follows <standard>. Not for restructuring layouts (use /fm-<layout-skill>).
metadata:
  version: "1.0"
---

# <Standard> audit

Measures the selection against a numeric standard and reports violations as a ranked list with fixes. Default is chat first, canvas on request: the audit never changes layers; fixes are applied only after the user confirms, and only on the layers they confirm.

## When to use

- The user asks to check, audit, lint, or verify <standard> on selected layers.
- The user asks whether the selection "follows the grid", "is consistent", "meets <standard>".
- **Do not** use this to redesign. This skill measures and snaps; it never restructures.

## Before you start

1. **Check the surface.** Figma Design only. In Make, return the standard as a checklist for the code instead.
2. **Resolve the scope.** Use the selection. If nothing is selected, ask, verbatim:
   > Nothing's selected. **1. Audit the current page** (this can be slow and costly on large pages), or **2. select the frames you want audited**?
3. **Confirm the standard.** Allowed values: <e.g. 0, 4, 8, 12, 16, 24, 32, 40, 48, 64, 80, 96>. Tolerance: <e.g. none; 1 px rounding counts as a violation>. If the file has a documented scale in its library guidelines, use that instead and say so.

## Instructions

1. **Collect.** For every frame in scope with auto layout, read <padding top/right/bottom/left, item spacing, counter-axis spacing>. For absolute children, read <the gap to the nearest sibling edge>. Skip hidden layers.
2. **Classify.** A value is compliant when it is in the allowed set. Otherwise compute the nearest allowed value and the delta.
3. **Rank.** P0: <e.g. value off by 3 px or more on a component>; P1: <off by 1 to 2 px on a component, or any amount on a top-level frame>; P2: <on a nested utility frame>; P3: <inside detached or scratch frames>.
4. **Report** using the contract. Cap at <20> rows; summarise the rest by count.
5. **Offer the fix.** Ask, verbatim:
   > Apply the <N> snaps listed above? **1. All**, **2. P0 and P1 only**, **3. Pick by number**, **4. None**.
   Wait. Apply only what was chosen, on the listed layers, by setting the property to the nearest allowed value. Never change layer structure, constraints, or sizes beyond the property named.
6. **Verify.** Re-read every changed property and compare to the target value.

## Output contract

```markdown
## <Standard> audit: <scope>
- Frames checked: <n> · Hidden skipped: <n>
- Violations: P0 <n> · P1 <n> · P2 <n> · P3 <n>

| # | Layer (path) | Property | Current | Nearest allowed | Delta | Priority |
| --- | --- | --- | --- | --- | --- | --- |

## After fixes (only if applied)
- Changed: <n> properties on <n> layers · Verified: <n>/<n>
- Not changed: <reasons>
- Source structure unchanged: yes
```

## Do and do not

### Snap, do not nudge

- **Do:** "Padding 18 → 16 (nearest allowed). Delta 2."
- **Do not:** "Padding 18 → 20 (looks better)."

### Report, then wait

- **Do:** The ranked table, then the verbatim fix question, then nothing until the answer.
- **Do not:** Applying "obvious" fixes in the same turn as the audit.

### Numbers, not adjectives

- **Do:** "Gap 13 px between 'Price' and 'Buy' in Card/Default."
- **Do not:** "Spacing feels uneven in the cards."

## Examples

**Request:** "Check the spacing on these cards" with four component instances selected.
**Result:** The table with each off-grid padding and gap, then the fix question.

**Request:** "Audit the grid" with nothing selected.
**Result:** The verbatim scope question; if the user picks the page, a note that large pages are slow, then the audit.

## Common edge cases

- **Mixed units or percentages.** Report them separately; do not snap percentages.
- **Values bound to variables.** Report the variable name and value; do not override a binding. Suggest changing the variable instead.
- **Instances with overrides.** Report the override; fixing may need the main component. Say so.
- **No violations.** Say "no violations in <n> frames" and stop.

## Final gate: do not finish until every line is true

- [ ] Every row's current value was read from the canvas
- [ ] No fix was applied without the user's numbered answer
- [ ] Every applied fix was re-read and matches the target
- [ ] Structure, constraints, and sizes outside the named property are unchanged

<!-- target:figma-app -->
## In-app execution (Figma agent)

If a script-execution tool such as `evaluate_script` is available, use it to collect values and to apply confirmed snaps. Collect in one call per <25> frames, apply in a separate call, and verify in a third. Return plain objects; nothing persists between calls. If it is not available, read the properties with your own canvas tools and apply fixes one layer at a time, reporting each.

```javascript
// Collect auto-layout spacing for the selection (read-only).
(async () => {
  const allowed = [0, 4, 8, 12, 16, 24, 32, 40, 48, 64, 80, 96];
  const nearest = (v) => allowed.reduce((a, b) => Math.abs(b - v) < Math.abs(a - v) ? b : a);
  const rows = [];
  const walk = (n, path) => {
    if (n.visible === false) return;
    const p = path ? path + " / " + n.name : n.name;
    if ("layoutMode" in n && n.layoutMode !== "NONE") {
      for (const k of ["paddingTop", "paddingRight", "paddingBottom", "paddingLeft", "itemSpacing", "counterAxisSpacing"]) {
        const v = n[k];
        if (typeof v === "number" && !allowed.includes(v)) rows.push({ id: n.id, path: p, property: k, current: v, nearest: nearest(v), delta: Math.abs(nearest(v) - v) });
      }
    }
    if ("children" in n) for (const c of n.children) walk(c, p);
  };
  for (const n of figma.currentPage.selection) walk(n, "");
  return { count: rows.length, rows: rows.slice(0, 200) };
})();
```
<!-- /target -->

<!-- target:mcp -->
## MCP execution (Claude Code, Cursor, Codex)

Load the `figma-use` skill before any `use_figma` call. Use `create_session` for the file key, run the collection script above through `use_figma` (pass `skillNames: "fm-<standard>-audit"`), present the table, and apply confirmed snaps in a second `use_figma` call that sets only the named properties by node id, then re-reads them.
<!-- /target -->
