---
name: fm-<system>-conventions
description: Applies the <System name> design system conventions when designing or editing in Figma: tokens, spacing, type scale, components, naming, and accessibility rules. Always use this skill when the user asks to "use <System>", "follow <System>", "make this on-brand", "apply the design system", or builds or edits anything in a file connected to the <System> library. Not for publishing or restructuring the library itself (use /fm-<system>-library-admin).
metadata:
  version: "1.0"
---

# <System name> conventions

Use these rules whenever you design, build, or edit in a <System>-connected file. They encode what the library enforces and what it cannot: the library gives you components and variables, and this skill tells you which ones to pick and how to combine them. When a rule here conflicts with a published library property, the library wins; report the conflict.

## When to use

- The user asks to build, edit, or review anything while the <System> library is connected.
- The user says "on-brand", "follow the system", "use our components".
- **Do not** restructure or publish the library from this skill. For library edits use /fm-<system>-library-admin.

## Before you start

1. **Check the library is connected.** Confirm the <System> library (team: <team>, file: <library file name>) is enabled in this file. If not, say so and stop; do not recreate tokens locally.
2. **Check the mode.** Variable modes: <e.g. Light, Dark, High contrast>. Default to <Light> unless the frame already uses another mode.
3. **Resolve scope.** Apply to the selection only. If nothing is selected and the user asks for a review, ask, verbatim:
   > Nothing's selected. **1. Review the current page**, or **2. select the frames to review**?

## Instructions

### Tokens over raw values

1. Colours: bind to `<collection>/<group>/<token>` variables; never type a hex. Semantic first (`surface/primary`, `text/secondary`), primitives only inside components you own.
2. Spacing: bind padding and gaps to `space/<n>` variables: <e.g. 0, 4, 8, 12, 16, 24, 32, 48, 64>. A value not in the scale is a violation; snap to the nearest token.
3. Radius: `radius/<name>`: <e.g. none 0, sm 4, md 8, lg 12, full 999>.
4. Type: use text styles `<Family>/<Role>/<Size>`: <list the roles: Display, Headline, Title, Body, Label, and their sizes>. Never set font size directly.
5. Elevation: effect styles `elevation/<level>`; no custom shadows.

### Components over drawing

1. Search the library before drawing anything: button, input, card, nav, modal, toast, table row, avatar, badge, tag. If a component exists, use it and set its properties; never detach.
2. Variants: pick by property, never by swapping fills. Primary action: `Button` with `variant=Primary, size=Medium`. Destructive: `variant=Danger`. Only one Primary button per view.
3. Icons: use `Icon/<name>` instances at 16, 20, or 24; never import an SVG when the icon exists.
4. When a component does not exist, build it from primitives with auto layout, name it `_Local/<Name>`, and list it in the report as a library gap.

### Layout

1. Auto layout on every container; no absolutely positioned children unless they are decorations.
2. Grid: <e.g. 12 columns, 24 gutter, 80 margin at 1440; 4 columns, 16 gutter, 16 margin at 390>.
3. Minimum touch target 44 × 44 on mobile frames, 32 × 32 on desktop.

### Naming

1. Frames: `<Page>/<Section>/<Element>` in Title Case. Example: `Checkout/Summary/Line item`.
2. Layers inside components keep the library's names; do not rename instance children.
3. Pages: `01 Cover`, `02 Flows`, `03 Components`, `99 Scratch`.

### Accessibility

1. Text contrast 4.5:1 for body, 3:1 for 24 px+ or 19 px bold; check against the resolved mode colour, not the primitive.
2. Every icon-only control has a visible label or a documented accessible name in the layer description.
3. Focus and disabled states exist for every interactive component in the view.

### Verify

Read back the edited frames: list unbound fills, unbound spacing, detached instances, off-scale sizes, and contrast failures. Fix what you introduced; report what you found.

## Output contract

Report only:

- Components used (name and variant) and any `_Local/` components created
- Variables and styles bound; any raw values that remain, with the reason
- Library gaps found
- Contrast and target-size checks: pass or the failing pairs

## Do and do not

### Bind, do not type

- **Do:** Fill → `color/surface/primary`; padding → `space/16`.
- **Do not:** Fill `#1A1A1A`; padding 15.

### Use the component, do not redraw it

- **Do:** `Button` instance, `variant=Secondary, size=Small, icon=Leading`.
- **Do not:** A rectangle with a text layer named "button".

### Report the gap, do not fake the component

- **Do:** "`_Local/Stepper` built from primitives; no Stepper in <System>. Library gap."
- **Do not:** A detached `Input` restyled into a stepper.

## Examples

**Request:** "Make this settings page on-brand" with the page frame selected.
**Result:** Instances swapped in for hand-drawn controls, fills and spacing bound, naming fixed, a report listing two library gaps and one contrast failure.

**Request:** "Add a danger button here" with a card selected.
**Result:** A `Button` instance with `variant=Danger` placed in the card's action row, bound spacing, nothing else changed.

## Common edge cases

- **Library not connected.** Stop and say so; do not create local copies of tokens.
- **Mode mismatch.** If the frame mixes modes, report it and ask which mode to normalise to.
- **Instance override conflicts.** Keep text overrides; reset colour and size overrides to the variant defaults and say which were reset.
- **Make file.** Return the token and component mapping as a table for the code instead of editing layers.

## Final gate: do not finish until every line is true

- [ ] No raw colour, spacing, radius, or type value remains that a token could cover
- [ ] No detached instances were created
- [ ] Every `_Local/` component is listed as a gap
- [ ] Contrast and target sizes were checked against resolved colours, not primitives

<!-- target:figma-app -->
## In-app execution (Figma agent)

If a script-execution tool such as `evaluate_script` is available, use it for the verify step: walk the selection, collect fills without `boundVariables`, padding and gap values not bound to `space/*`, and instances whose `mainComponent` is null (detached). Return a plain list; apply fixes in a later call; re-read in a third. Keep each call to about 25 frames.
<!-- /target -->

<!-- target:mcp -->
## MCP execution (Claude Code, Cursor, Codex)

Load the `figma-use` skill before any `use_figma` call. Use `create_session`, then `search_design_system` to resolve component and variable ids by name before building, `get_variable_defs` to confirm token values, and `use_figma` (pass `skillNames: "fm-<system>-conventions"`) to bind and swap. Verify with `get_design_context` on the edited frame.
<!-- /target -->
