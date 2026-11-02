# Factory presets: give any shader a built-in set of looks

Figma has no native preset API for shaders. The platform offers two adjacent mechanisms:

- **Styles**: any shader fill or effect configuration can be saved as a style and published to the
  team library. This is the mechanism for *user* presets, which the user can edit.
- **Motion keyframes**: individual controls can be keyframed in Motion mode.

The house model is therefore split. **Factory presets live in the shader source, are selected from
a dropdown, and cannot be edited by the user. User presets are Figma styles.** The pattern below is
the standard for every Futuremotion shader and must be present, unchanged in mechanism, whenever a
shader ships presets.

## The invariant

A preset must render identically on every layer, regardless of where the live sliders sit. That
holds only because the resolver applies the preset delta to the `defaults` table, never to the live
panel values.

## The seven parts

1. A `preset` control: `type: "number"`, `control: "select"`, `defaultValue: 0`. Option 0 is
   "Custom (use controls)" and renders the live panel. Options 1..N are factory presets.
2. A `defaults` table **inside `render()`**, never at module scope (the build strips module-scope
   data). It mirrors every control's `defaultValue` exactly, in the same key names and in the value
   formats the readers return.
3. A `live` object built from the param readers with the same shape as `defaults`.
4. A `factoryPresets` map `{ [id]: { ...only the keys that differ from defaults } }`, each entry
   commented with its label.
5. The three-line resolver, after which every later line reads `v.*` and never `frame.params`.
6. A comment block in the file stating the two-step recipe and the delta format rules.
7. Editable presets delegated to Figma styles, not to source.

## The template

Readers are the block from controls.md. Control names are placeholders.

```ts
export function render(device, frame) {
  var p = frame.params || {}
  // ---- Param readers (see controls.md) -------------------------------------
  function fin(x, fb) { var n = Number(x); return Number.isFinite(n) ? n : fb }
  function num(name, fb) { return fin(p[name], fb) }
  function bool(name, fb) { return typeof p[name] === "boolean" ? (p[name] ? 1 : 0) : (fb ? 1 : 0) }
  function color(name, fb) { var c = p[name] || {}; return [fin(c.r, fb[0]), fin(c.g, fb[1]), fin(c.b, fb[2]), fin(c.a, fb[3])] }
  function point(name, fb) { var q = p[name] || {}; return [fin(q.x, fb[0]), fin(q.y, fb[1])] }
  function stops(name, fb) { var g = p[name] || {}; return Array.isArray(g.stops) && g.stops.length > 0 ? g.stops : fb }

  // ---------------------------------------------------------------------------
  // Control defaults. MUST mirror the defaultValue of every control in
  // defineProperties() below (module-scope constants are stripped by the build, so
  // the table lives here). Presets are applied on top of these, never on top of the
  // live sliders; that is what makes a preset render identically everywhere.
  // ---------------------------------------------------------------------------
  var defaults = {
    amount: 50, mode: 0, tint: [1, 1, 1, 1], center: [50, 50], invert: 0,
    ramp: [{ position: 0, color: { r: 0, g: 0, b: 0, a: 1 } }, { position: 1, color: { r: 1, g: 1, b: 1, a: 1 } }],
  }

  // Live values from the panel, in the same shape as `defaults`.
  var live = {
    amount: num("amount", defaults.amount),
    mode: num("mode", defaults.mode),
    tint: color("tint", defaults.tint),
    center: point("center", defaults.center),
    invert: bool("invert", defaults.invert),
    ramp: stops("ramp", defaults.ramp),
  }

  // ---------------------------------------------------------------------------
  // Factory presets. Each entry is a delta applied to `defaults`.
  //
  // To add a preset:
  //   1. Add { value: N, label: "Name" } to the `preset` options in defineProperties().
  //   2. Add factoryPresets[N] = { ...only the controls that differ from defaults... }.
  // Keys and value formats match `defaults` exactly (colors are [r,g,b,a] in 0..1,
  // points are [x%, y%], booleans are 0/1, selects use numeric ids, gradients are
  // stop arrays). Anything not listed renders at its default, never at the live slider.
  // Ids are permanent: styles store them. Never renumber or reuse an id.
  // ---------------------------------------------------------------------------
  var factoryPresets = {
    1: { // Soft
      amount: 20, tint: [1, 0.95, 0.9, 1],
    },
    2: { // Punchy
      amount: 90, mode: 2, invert: 1,
    },
  }

  // Resolve the effective control set: a preset fully replaces the live panel.
  var presetId = num("preset", 0)
  var v = live
  if (presetId > 0 && factoryPresets[presetId]) {
    v = Object.assign({}, defaults, factoryPresets[presetId])
  }

  // ... everything below reads v.amount, v.tint, v.center ... never frame.params.
}

defineProperties(Effect, {
  // ---- Presets ----
  // "Custom" renders the live controls below. Any other entry renders the preset exactly
  // (defaults + delta in render()); the sliders are ignored while a preset is selected.
  preset: {
    type: "number", label: "Presets", defaultValue: 0, control: "select",
    options: [
      { value: 0, label: "Custom (use controls)" },
      { value: 1, label: "Soft" },
      { value: 2, label: "Punchy" },
    ],
  },
  amount: { type: "number", label: "Amount", defaultValue: 50, control: "slider", min: 0, max: 100, step: 1, unit: "%" },
  // ... every remaining control, each defaultValue identical to the `defaults` table
})
```

A ready-to-copy version lives in `templates/preset-block.ts`.

## Exempt controls: keyframable motion stays live

A preset describes a look, not a moment in time. Any control whose purpose is to be keyframed or
driven per layer (a `phase`, `scroll`, `travel`, `progress`, or `seed` control, and a mouse or
time speed) is **exempt** from the invariant: it is read from `live` even while a preset is
selected. Otherwise a preset layer could never loop in Motion. Implement it as one extra line after
the resolver, and list the exempt keys in the preset comment block and the header:

```ts
  var presetId = num("preset", 0)
  var v = live
  if (presetId > 0 && factoryPresets[presetId]) {
    v = Object.assign({}, defaults, factoryPresets[presetId], { phase: live.phase })  // exempt: phase
  }
```

Exempt controls never appear in a delta. Everything else obeys the invariant.

## Delta format rules

| Control type | Format in `defaults` and deltas |
| --- | --- |
| number, slider, input, select | plain number; selects use the numeric option `value`, never the label |
| boolean | `0` or `1` |
| color | `[r, g, b, a]` array, 0..1 |
| point | `[x, y]` in the control's unit (percent stays 0..100) |
| point-angle-radius, point-radius | `{ x, y, radius, angle }` object matching the reader |
| gradient | stops array `[{ position, color: { r, g, b, a } }]` (keeps object form) |
| string | string |

## Maintenance rules

Changing anything near presets has consequences the platform never enforces:

| Change | Consequence | Rule |
| --- | --- | --- |
| Change a control's `defaultValue` | Every preset that does not override that key changes look | Copy the old value into each affected preset's delta first |
| Add a control | Every existing preset inherits its default | The new default must reproduce the previous render (0 for an added offset, 1 for a multiplier) |
| Remove a preset entry | Styles storing that id fall through to "Custom" with whatever slider values the style captured | Never delete. Keep the entry and relabel the option "(legacy) Name", or reserve the id with a comment |
| Reorder options | Nothing breaks; ids are what is stored | Order options for humans; ids stay |
| Reuse an id | Old styles jump to the new look | Never |
| Mutate `v` | `Object.assign` is shallow; mutating `v.ramp` corrupts the shared `defaults` array for that frame | Treat `v` as read-only |

Two UX facts belong in the file header: while a preset is selected the non-exempt sliders do
nothing (Figma has no conditional UI), and in Motion mode keyframing `preset` jumps discretely
between looks while exempt controls keep animating.

Choosing preset values without a render: derive them from the control semantics (a "Subtle" look
sits near the low end of strength and amount, "Heavy" near the high end but off the range edge),
then verify on a layer after the push and tune. Say in the report which values were tuned by eye
and which are untested.

## Checklist

| Step | Add a preset | Retire a preset | Add a control |
| --- | --- | --- | --- |
| 1 | Pick the next unused id | Never delete the id; relabel "(legacy)" | Add the `defineProperties` entry with a neutral `defaultValue` |
| 2 | Add `{ value: N, label }` to `preset.options` | Keep `factoryPresets[N]` | Add the key to `defaults` with the identical value and format |
| 3 | Add `factoryPresets[N]` with only differing keys, commented with its label | Note the retirement in the header comment | Add the key to `live` through the right reader |
| 4 | Derive the delta by diffing a configured layer against `defaults` (see mcp-workflow.md) | Re-check styles that used it | Extend the WGSL struct, the CPU packing block, and the layout comments together |
| 5 | Push the complete `main.ts` with `update_shader` and a specific `commitMessage` | Same | Verify every existing preset renders unchanged |
| 6 | Screenshot a test layer with the preset selected and compare | Same | Same |

Run `node scripts/validate-shader.mjs main.ts` before pushing; it checks that every `defaults`
key has a matching control, every control has a `defaults` entry, every preset id has an option,
and every delta key exists in `defaults`.
