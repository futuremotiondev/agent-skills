# Modify and extend an existing shader

Editing a live shader is the common case, not the exception. The risks are different from creation:
layers and styles already store values by definition id and version, and the repo copy may be
stale. Follow this order every time.

## 1. Re-pull the live source

```text
list_shaders            -> find the id (or use the known id from HANDOFF)
get_shader({ id, includeSource: true })
```

Compare the live `main.ts` with the repo copy (`diff --strip-trailing-cr`). If they differ, the
shader was edited in Figma since the last push; the live version is the source of truth. Update the
repo copy and note the version SHA before touching anything.

Read every file returned, including `features.json`, so `isAnimated` and `usesMouse` are known.

## 2. Classify the change

| Change | Touches | Compatibility risk |
| --- | --- | --- |
| Tweak a constant, fix a bug, change a label or range | WGSL or JS only | None, if keys and ids stay |
| Add a factory preset | `preset.options`, `factoryPresets` | None; new id only |
| Add a control | `defineProperties`, `defaults`, `live`, WGSL struct, uniform packing, layout comments | Existing presets inherit the new default; choose it so old renders are unchanged |
| Add a mode to a select | `options`, WGSL decode, encoding comment | None if the new value is unused so far |
| Change what an existing control means | Semantics | High: every layer and style keeps its stored number. Avoid; add a new control instead |
| Rename a control key | Definition id | Breaks every applied layer and style. Never. Change the label only |
| Remove a control or preset | Definition id or preset id | Never delete; hide by relabeling "(legacy)" and ignoring the value |
| Convert a string select to numeric | Stored string values orphaned | Never on a shipped shader |
| Change alpha handling or output | Rendering of every layer | Only to fix a verified bug; re-screenshot existing layers |
| Upgrade for render scale | Geometry | Behaviour changes at non-1x scales by design; keep the 1x render identical |

## 3. Make the change in the repo copy

- Keep the header, banners, and comment standard; update the header's pipeline list and preset
  list when they change.
- Extending the uniform buffer: grow the WGSL struct, grow the `createBuffer` size (multiple of 16),
  extend the packing array at the same index, and update both layout comments. The validator
  cross-checks the buffer size against the number of floats written.
- Adding a control: add it to `defineProperties`, `defaults`, and `live` in one edit; the validator
  checks the three agree.
- Adding presets: see factory-presets.md. Harvest deltas from configured layers with the script in
  mcp-workflow.md.

## 4. Validate, push, record

```bash
node scripts/validate-shader.mjs shaders/<name>/main.ts --kind effect
```

Then `update_shader` with the whole file, the existing kind, metadata flags that match the new
source, and a commit message that names the change ("Add Riso and Screen-print presets (ids 8, 9)").
Record the returned SHA in HANDOFF and SHADER-NOTES.

## 5. Verify on existing layers

Layers keep rendering the version they were applied with. To see the new build:

- In the app: select a layer, use "Update to latest version" on the effect or fill.
- Programmatically: reapply with the new `listAvailableShaders()` id and copy `properties` across by
  definition name (mcp-workflow.md).

Screenshot before and after at 1x and 0.5x. For preset work, select each preset on a test layer and
compare with the screenshots taken during harvesting. For a render-scale fix, the 0.5x screenshot is
the test: dots or cells should keep their design size.

## 6. Update the notes

`SHADER-NOTES.md`: passes, uniform layout, mode ids, presets, limits. `HANDOFF.md`: id, current SHA,
what changed, open questions.

## Worked example: fm-halftone-shader

Current state (2026-11-02): id `67dde794-7313-401f-909f-094a89ebde53`, kind `effect`, version-2
manifest, 53 controls, 7 factory presets (ids 1..7), 480-byte uniform buffer in 16 `vec4f` slots plus
gradient and glyph arrays. Two known issues to fix when it is next touched, both flagged by this
research:

1. **Render scale.** It sizes cells in raw pixels against `frame.output.width` and never reads
   `frame.renderScale`, so at a 0.5x export the cells are twice their design size relative to the
   artwork, and the reverse at high render scales. Fix: in `render()`, compute
   `renderScale = Math.max(Number(frame.renderScale) || 1, 1e-6)`, derive `outW/outH` in points as
   `(frame.output.physicalWidth ?? frame.output.width) / renderScale`, keep `cellPx` in points, and
   multiply blur radii back by `renderScale` where they are converted to texels. The 1x render must
   stay pixel-identical; verify with a before/after screenshot at 1x and 0.5x.
2. **Fallback drift guard.** `defaults` is already the single fallback source; keep it that way when
   adding controls.

Adding presets to it: next free id is 8. Harvest deltas from the layers on the "FM-Halftone-Shader-Test"
board (they all have `preset: 0`), convert to delta format, add options and entries, validate, push
with a commit message naming the presets, and re-screenshot.
